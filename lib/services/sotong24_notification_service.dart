import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_browser_bridge.dart';
import 'remote_control_api.dart';

enum NotificationPermissionState {
  authorized,
  provisional,
  denied,
  notDetermined,
  unsupported,
  notConfigured,
}

enum NotificationSetupState {
  checking,
  unsupported,
  permissionNotRequested,
  permissionGranted,
  permissionDenied,
  serviceWorkerChecking,
  tokenCreating,
  deviceRegistering,
  registered,
  apiError,
  serviceWorkerError,
  tokenError,
  deviceError,
}

class NotificationSetupException implements Exception {
  const NotificationSetupException({
    required this.state,
    required this.userMessage,
    required this.code,
  });

  final NotificationSetupState state;
  final String userMessage;
  final String code;

  @override
  String toString() => userMessage;
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
    this.setupState = NotificationSetupState.permissionNotRequested,
    this.errorMessage = '',
    this.errorCode = '',
  });

  final NotificationPermissionState permission;
  final bool configured;
  final String deliveryMode;
  final bool currentDeviceRegistered;
  final int registeredDeviceCount;
  final List<NotificationHistoryItem> recentNotifications;
  final NotificationSetupState setupState;
  final String errorMessage;
  final String errorCode;
}

abstract interface class NotificationController {
  bool get isConfigured;
  NotificationSetupState get setupState;
  Stream<NotificationSetupState> get setupStates;

  Future<bool> enable();
  Future<void> disable();
  Future<NotificationDiagnostics> diagnostics();
  Future<String> sendTestNotification();
}

abstract interface class NotificationMessagingClient {
  Future<RemoteMessage?> getInitialMessage();
  Stream<RemoteMessage> get onMessageOpenedApp;
  Stream<RemoteMessage> get onMessage;
  Stream<String> get onTokenRefresh;
  Future<AuthorizationStatus> authorizationStatus();
  Future<AuthorizationStatus> requestPermission();
  Future<String?> getToken({String? vapidKey});
  Future<void> deleteToken();
}

class FirebaseNotificationMessagingClient
    implements NotificationMessagingClient {
  FirebaseNotificationMessagingClient(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<AuthorizationStatus> authorizationStatus() async =>
      (await _messaging.getNotificationSettings()).authorizationStatus;

  @override
  Future<AuthorizationStatus> requestPermission() async =>
      (await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      )).authorizationStatus;

  @override
  Future<String?> getToken({String? vapidKey}) =>
      _messaging.getToken(vapidKey: vapidKey);

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}

class Sotong24NotificationService implements NotificationController {
  Sotong24NotificationService({
    FirebaseMessaging? messaging,
    NotificationMessagingClient? messagingClient,
    NotificationBrowserBridge? browserBridge,
    RemoteControlApi? api,
    this._deviceIdProvider,
    bool? isWebOverride,
    String? webVapidKeyOverride,
  }) : _messaging =
           messagingClient ??
           FirebaseNotificationMessagingClient(
             messaging ?? FirebaseMessaging.instance,
           ),
       _browserBridge = browserBridge ?? createNotificationBrowserBridge(),
       _api = api ?? RemoteControlApi(),
       _isWeb = isWebOverride ?? kIsWeb,
       _vapidKey = webVapidKeyOverride ?? webVapidKey;

  static const webVapidKey = String.fromEnvironment('SOTONG_FCM_WEB_VAPID_KEY');
  static const _deviceIdKey = 'sotong_notification_device_id_v1';

  final NotificationMessagingClient _messaging;
  final NotificationBrowserBridge _browserBridge;
  final RemoteControlApi _api;
  final Future<String> Function()? _deviceIdProvider;
  final bool _isWeb;
  final String _vapidKey;
  final _setupStateController =
      StreamController<NotificationSetupState>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  void Function(Uri uri)? _onOpen;
  void Function(RemoteMessage message)? _onForeground;
  NotificationSetupState _setupState = NotificationSetupState.checking;

  @override
  bool get isConfigured => !_isWeb || _vapidKey.trim().isNotEmpty;

  @override
  NotificationSetupState get setupState => _setupState;

  @override
  Stream<NotificationSetupState> get setupStates =>
      _setupStateController.stream;

  void _setSetupState(NotificationSetupState value) {
    _setupState = value;
    if (!_setupStateController.isClosed) _setupStateController.add(value);
  }

  Future<void> initialize({
    required void Function(Uri uri) onOpen,
    void Function(RemoteMessage message)? onForeground,
  }) async {
    _onOpen = onOpen;
    _onForeground = onForeground;
    _openedSubscription = _messaging.onMessageOpenedApp.listen(_openMessage);
    _foregroundSubscription = _messaging.onMessage.listen((message) {
      _onForeground?.call(message);
    });
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _openMessage(initial);
    } catch (_) {
      // A notification startup failure must not block the authenticated app.
    }
    if (!isConfigured) {
      _setSetupState(NotificationSetupState.unsupported);
      return;
    }
    try {
      final permission = await _currentPermission();
      _setSetupState(_stateForPermission(permission));
      if (_isAllowed(permission)) await _registerCurrentToken();
    } catch (_) {
      // Diagnostics exposes the actionable stage and supports a manual retry.
    }
  }

  @override
  Future<bool> enable() async {
    if (!isConfigured) {
      _setSetupState(NotificationSetupState.unsupported);
      return false;
    }

    late NotificationPermissionState permission;
    if (_isWeb) {
      final capabilities = _browserBridge.capabilities();
      if (!capabilities.supported) {
        _setSetupState(NotificationSetupState.unsupported);
        throw const NotificationSetupException(
          state: NotificationSetupState.unsupported,
          userMessage: '이 브라우저에서는 Web Push 알림을 사용할 수 없습니다.',
          code: 'notification_unsupported',
        );
      }
      // Keep this as the first async browser operation so Android Chrome
      // retains the button's user-activation context.
      final permissionFuture = _browserBridge.requestPermission();
      final rawPermission = await permissionFuture;
      permission = _browserPermission(rawPermission);
    } else {
      permission = _permission(await _messaging.requestPermission());
    }

    _setSetupState(_stateForPermission(permission));
    if (!_isAllowed(permission)) return false;

    if (_isWeb) {
      _setSetupState(NotificationSetupState.serviceWorkerChecking);
      try {
        await _browserBridge.waitForServiceWorkerReady();
      } catch (_) {
        _setSetupState(NotificationSetupState.serviceWorkerError);
        throw const NotificationSetupException(
          state: NotificationSetupState.serviceWorkerError,
          userMessage: 'Push 서비스 워커를 준비하지 못했습니다. 페이지를 새로고침해 주세요.',
          code: 'service_worker_not_ready',
        );
      }
    }
    return _registerCurrentToken();
  }

  Future<bool> _registerCurrentToken() async {
    _setSetupState(NotificationSetupState.tokenCreating);
    late String? token;
    try {
      token = await _messaging.getToken(vapidKey: _isWeb ? _vapidKey : null);
    } catch (_) {
      _setSetupState(NotificationSetupState.tokenError);
      throw const NotificationSetupException(
        state: NotificationSetupState.tokenError,
        userMessage: 'FCM 기기 토큰을 생성하지 못했습니다.',
        code: 'fcm_token_failed',
      );
    }
    if (token == null || token.isEmpty) {
      _setSetupState(NotificationSetupState.tokenError);
      throw const NotificationSetupException(
        state: NotificationSetupState.tokenError,
        userMessage: 'FCM 기기 토큰이 비어 있습니다.',
        code: 'fcm_token_empty',
      );
    }

    _setSetupState(NotificationSetupState.deviceRegistering);
    late String deviceId;
    try {
      deviceId = await _deviceId();
    } catch (_) {
      _setSetupState(NotificationSetupState.deviceError);
      throw const NotificationSetupException(
        state: NotificationSetupState.deviceError,
        userMessage: '이 브라우저의 기기 ID를 저장하지 못했습니다.',
        code: 'device_id_failed',
      );
    }
    try {
      await _api.registerNotificationToken(
        token: token,
        deviceId: deviceId,
        platform: _isWeb ? 'web' : defaultTargetPlatform.name,
      );
    } on RemoteControlApiException catch (error) {
      _setSetupState(NotificationSetupState.apiError);
      throw NotificationSetupException(
        state: NotificationSetupState.apiError,
        userMessage: error.userMessage,
        code: error.code ?? 'device_registration_api_failed',
      );
    }
    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await _api.registerNotificationToken(
          token: newToken,
          deviceId: deviceId,
          platform: _isWeb ? 'web' : defaultTargetPlatform.name,
        );
      } catch (_) {
        _setSetupState(NotificationSetupState.apiError);
      }
    });
    _setSetupState(NotificationSetupState.registered);
    return true;
  }

  @override
  Future<void> disable() async {
    final deviceId = await _deviceId();
    await _api.unregisterNotificationToken(deviceId: deviceId);
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    await _messaging.deleteToken();
    _setSetupState(NotificationSetupState.permissionGranted);
  }

  @override
  Future<NotificationDiagnostics> diagnostics() async {
    if (!isConfigured) {
      _setSetupState(NotificationSetupState.unsupported);
      return const NotificationDiagnostics(
        permission: NotificationPermissionState.notConfigured,
        configured: false,
        deliveryMode: 'outbox_only',
        currentDeviceRegistered: false,
        registeredDeviceCount: 0,
        recentNotifications: [],
        setupState: NotificationSetupState.unsupported,
      );
    }
    _setSetupState(NotificationSetupState.checking);

    var permission = NotificationPermissionState.unsupported;
    try {
      permission = await _currentPermission();
    } catch (_) {
      permission = NotificationPermissionState.unsupported;
    }

    late Map<String, dynamic> raw;
    try {
      raw = await _api.notificationDiagnostics();
    } on RemoteControlApiException catch (error) {
      _setSetupState(NotificationSetupState.apiError);
      return NotificationDiagnostics(
        permission: permission,
        configured: true,
        deliveryMode: 'unknown',
        currentDeviceRegistered: false,
        registeredDeviceCount: 0,
        recentNotifications: const [],
        setupState: NotificationSetupState.apiError,
        errorMessage: error.userMessage,
        errorCode: error.code ?? 'diagnostics_api_failed',
      );
    } catch (_) {
      _setSetupState(NotificationSetupState.apiError);
      return NotificationDiagnostics(
        permission: permission,
        configured: true,
        deliveryMode: 'unknown',
        currentDeviceRegistered: false,
        registeredDeviceCount: 0,
        recentNotifications: const [],
        setupState: NotificationSetupState.apiError,
        errorMessage: '알림 진단 API에 연결하지 못했습니다.',
        errorCode: 'diagnostics_api_failed',
      );
    }

    String? deviceId;
    try {
      deviceId = await _deviceId();
    } catch (_) {
      _setSetupState(NotificationSetupState.deviceError);
    }
    final devices = raw['devices'];
    var currentRegistered = false;
    if (deviceId != null && devices is List) {
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
    final state = deviceId == null
        ? NotificationSetupState.deviceError
        : currentRegistered
        ? NotificationSetupState.registered
        : _stateForPermission(permission);
    _setSetupState(state);
    return NotificationDiagnostics(
      permission: permission,
      configured: true,
      deliveryMode: '${raw['deliveryMode'] ?? 'unknown'}',
      currentDeviceRegistered: currentRegistered,
      registeredDeviceCount: countValue is num ? countValue.toInt() : 0,
      recentNotifications: recent,
      setupState: state,
      errorMessage: deviceId == null ? '이 브라우저의 기기 ID를 저장하지 못했습니다.' : '',
      errorCode: deviceId == null ? 'device_id_failed' : '',
    );
  }

  @override
  Future<String> sendTestNotification() async {
    final raw = await _api.sendTestNotification();
    return '${raw['notificationEventId'] ?? ''}';
  }

  Future<NotificationPermissionState> _currentPermission() async {
    if (_isWeb) {
      final capabilities = _browserBridge.capabilities();
      if (!capabilities.supported) {
        return NotificationPermissionState.unsupported;
      }
      return _browserPermission(capabilities.permission);
    }
    return _permission(await _messaging.authorizationStatus());
  }

  NotificationPermissionState _browserPermission(String value) {
    return switch (value) {
      'granted' => NotificationPermissionState.authorized,
      'denied' => NotificationPermissionState.denied,
      'default' => NotificationPermissionState.notDetermined,
      _ => NotificationPermissionState.unsupported,
    };
  }

  NotificationSetupState _stateForPermission(
    NotificationPermissionState permission,
  ) {
    return switch (permission) {
      NotificationPermissionState.authorized ||
      NotificationPermissionState.provisional =>
        NotificationSetupState.permissionGranted,
      NotificationPermissionState.denied =>
        NotificationSetupState.permissionDenied,
      NotificationPermissionState.notDetermined =>
        NotificationSetupState.permissionNotRequested,
      NotificationPermissionState.unsupported ||
      NotificationPermissionState.notConfigured =>
        NotificationSetupState.unsupported,
    };
  }

  bool _isAllowed(NotificationPermissionState status) {
    return status == NotificationPermissionState.authorized ||
        status == NotificationPermissionState.provisional;
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
    final provider = _deviceIdProvider;
    if (provider != null) return provider();
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
    await _setupStateController.close();
  }
}
