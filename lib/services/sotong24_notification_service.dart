import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'remote_control_api.dart';

class Sotong24NotificationService {
  Sotong24NotificationService({
    FirebaseMessaging? messaging,
    RemoteControlApi? api,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _api = api ?? RemoteControlApi();

  static const webVapidKey = String.fromEnvironment('SOTONG_FCM_WEB_VAPID_KEY');

  final FirebaseMessaging _messaging;
  final RemoteControlApi _api;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  void Function(Uri uri)? _onOpen;

  bool get isConfigured => !kIsWeb || webVapidKey.trim().isNotEmpty;

  Future<void> initialize({required void Function(Uri uri) onOpen}) async {
    _onOpen = onOpen;
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _openMessage(initial);
  }

  Future<bool> enable() async {
    if (!isConfigured) return false;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? webVapidKey : null,
    );
    if (token == null || token.isEmpty) return false;
    await _api.registerNotificationToken(
      token: token,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
    );
    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      await _api.registerNotificationToken(
        token: newToken,
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      );
    });
    return true;
  }

  void _openMessage(RemoteMessage message) {
    final raw = '${message.data['deepLink'] ?? ''}'.trim();
    final uri = Uri.tryParse(raw);
    if (uri != null) _onOpen?.call(uri);
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
