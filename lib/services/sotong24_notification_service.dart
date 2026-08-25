import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_control_api.dart';

enum NotificationPermissionState {
  authorized,
  provisional,
  denied,
  notDetermined,
  unsupported,
  notConfigured,
}

class NotificationHistoryItem {
  const NotificationHistoryItem({
    required this.eventId,
    required this.eventType,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.deepLink,
  });

  final String eventId;
  final String eventType;
  final String title;
  final String body;
  final String status;
  final String createdAt;
  final String deepLink;

  factory NotificationHistoryItem.fromMap(Map<String, dynamic> map) {
    return NotificationHistoryItem(
      eventId: '${map['notificationEventId'] ?? ''}',
      eventType: '${map['eventType'] ?? ''}',
      title: '${map['title'] ?? ''}',
      body: '${map['body'] ?? ''}',
      status: '${map['status'] ?? ''}',
      createdAt: '${map['createdAt'] ?? ''}',
      deepLink: '${map['deepLink'] ?? ''}',
    );
  }
}

class NotificationDiagnostics {
  const NotificationDiagnostics({
    required this.permission,
    required this.configured,
    required this.deliveryMode,
    required this.currentDeviceRegistered,
    required this.registeredDeviceCount,
    required this.recentNotifications,
  });

  final NotificationPermissionState permission;
  final bool configured;
  final String deliveryMode;
  final bool currentDeviceRegistered;
  final int registeredDeviceCount;
  final List<NotificationHistoryItem> recentNotifications;
}

abstract interface class NotificationController {
  bool get isConfigured;

  Future<bool> enable();

  Future<void> disable();

  Future<NotificationDiagnostics> diagnostics();

  Future<String> sendTestNotification();
}

class Sotong24NotificationService implements NotificationController {
  Sotong24NotificationService({
    FirebaseMessaging? messaging,
    RemoteControlApi? api,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _api = api ?? RemoteControlApi();

  static const webVapidKey = String.fromEnvironment('SOTONG_FCM_WEB_VAPID_KEY');
  static const _deviceIdKey = 'sotong_notification_device_id_v1';

  final FirebaseMessaging _messaging;
  final RemoteControlApi _api;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  void Function(Uri uri)? _onOpen;
  void Function(RemoteMessage message)? _onForeground;

  @override
  bool get isConfigured => !kIsWeb || webVapidKey.trim().isNotEmpty;

  Future<void> initialize({
    required void Function(Uri uri) onOpen,
    void Function(RemoteMessage message)? onForeground,
  }) async {
    _onOpen = onOpen;
    _onForeground = onForeground;
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      _onForeground?.call(message);
    });
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _openMessage(initial);
    if (!isConfigured) return;
    final settings = await _messaging.getNotificationSettings();
    if (_isAllowed(settings.authorizationStatus)) {
      await _registerCurrentToken();
    }
  }

  @override
  Future<bool> enable() async {
    if (!isConfigured) return false;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!_isAllowed(settings.authorizationStatus)) return false;
    return _registerCurrentToken();
  }

  Future<bool> _registerCurrentToken() async {
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? webVapidKey : null,
    );
    if (token == null || token.isEmpty) return false;
    final deviceId = await _deviceId();
    await _api.registerNotificationToken(
      token: token,
      deviceId: deviceId,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
    );
    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      await _api.registerNotificationToken(
        token: newToken,
        deviceId: deviceId,
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      );
    });
    return true;
  }

  @override
  Future<void> disable() async {
    final deviceId = await _deviceId();
    await _api.unregisterNotificationToken(deviceId: deviceId);
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    await _messaging.deleteToken();
  }

  @override
  Future<NotificationDiagnostics> diagnostics() async {
    if (!isConfigured) {
      return const NotificationDiagnostics(
        permission: NotificationPermissionState.notConfigured,
        configured: false,
        deliveryMode: 'outbox_only',
        currentDeviceRegistered: false,
        registeredDeviceCount: 0,
        recentNotifications: [],
      );
    }
    final settings = await _messaging.getNotificationSettings();
    final deviceId = await _deviceId();
    final raw = await _api.notificationDiagnostics();
    final devices = raw['devices'];
    var currentRegistered = false;
    if (devices is List) {
      currentRegistered = devices.whereType<Map>().any(
        (item) =>
            '${item['deviceId'] ?? ''}' == deviceId && item['enabled'] == true,
      );
    }
    final recent = <NotificationHistoryItem>[];
    final rawRecent = raw['recentNotifications'];
    if (rawRecent is List) {
      for (final item in rawRecent.whereType<Map>()) {
        recent.add(
          NotificationHistoryItem.fromMap(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        );
      }
    }
    final countValue = raw['registeredDeviceCount'];
    return NotificationDiagnostics(
      permission: _permission(settings.authorizationStatus),
      configured: true,
      deliveryMode: '${raw['deliveryMode'] ?? 'unknown'}',
      currentDeviceRegistered: currentRegistered,
      registeredDeviceCount: countValue is num ? countValue.toInt() : 0,
      recentNotifications: recent,
    );
  }

  @override
  Future<String> sendTestNotification() async {
    final raw = await _api.sendTestNotification();
    return '${raw['notificationEventId'] ?? ''}';
  }

  bool _isAllowed(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  NotificationPermissionState _permission(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized => NotificationPermissionState.authorized,
      AuthorizationStatus.provisional =>
        NotificationPermissionState.provisional,
      AuthorizationStatus.denied => NotificationPermissionState.denied,
      AuthorizationStatus.notDetermined =>
        NotificationPermissionState.notDetermined,
    };
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim() ?? '';
    if (RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final value = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final created = 'device_$value';
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  void _openMessage(RemoteMessage message) {
    final raw = '${message.data['deepLink'] ?? ''}'.trim();
    final uri = Uri.tryParse(raw);
    if (uri != null) _onOpen?.call(uri);
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
  }
}
