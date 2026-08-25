import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sotong_ware_control/services/notification_browser_bridge.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/sotong24_notification_service.dart';

const vapidKey = 'test_public_vapid_key';
const deviceId = 'device_0123456789abcdef0123456789abcdef';
const token = 'fcm-token-with-more-than-twenty-characters';

void main() {
  test(
    'diagnostics reports permission default after authenticated API success',
    () async {
      final events = <String>[];
      final service = _service(
        events: events,
        permission: 'default',
        diagnosticsResponse: {
          'ok': true,
          'deliveryMode': 'fcm',
          'registeredDeviceCount': 0,
          'devices': <Object>[],
          'recentNotifications': <Object>[],
        },
      );

      final diagnostics = await service.diagnostics();

      expect(diagnostics.permission, NotificationPermissionState.notDetermined);
      expect(
        diagnostics.setupState,
        NotificationSetupState.permissionNotRequested,
      );
      expect(diagnostics.deliveryMode, 'fcm');
      expect(events, contains('api:notification-diagnostics'));
    },
  );

  test(
    'enable click calls permission first then service worker, token and device API',
    () async {
      final events = <String>[];
      final service = _service(
        events: events,
        permission: 'default',
        requestedPermission: 'granted',
        token: token,
      );

      final enabled = await service.enable();

      expect(enabled, isTrue);
      expect(service.setupState, NotificationSetupState.registered);
      expect(events, [
        'permission:request',
        'service-worker:ready',
        'fcm:get-token:$vapidKey',
        'device-id',
        'api:register-notification-token',
      ]);
    },
  );

  test(
    'permission denied stops before service worker and FCM token creation',
    () async {
      final events = <String>[];
      final service = _service(
        events: events,
        permission: 'default',
        requestedPermission: 'denied',
      );

      final enabled = await service.enable();

      expect(enabled, isFalse);
      expect(service.setupState, NotificationSetupState.permissionDenied);
      expect(events, ['permission:request']);
    },
  );

  test(
    'service worker failure has explicit terminal state and no token request',
    () async {
      final events = <String>[];
      final service = _service(
        events: events,
        permission: 'default',
        requestedPermission: 'granted',
        serviceWorkerFails: true,
      );

      await expectLater(
        service.enable(),
        throwsA(
          isA<NotificationSetupException>()
              .having(
                (error) => error.state,
                'state',
                NotificationSetupState.serviceWorkerError,
              )
              .having(
                (error) => error.code,
                'code',
                'service_worker_not_ready',
              ),
        ),
      );
      expect(events, ['permission:request', 'service-worker:ready']);
    },
  );

  test(
    'diagnostics API auth failure returns API error instead of staying checking',
    () async {
      final events = <String>[];
      final service = _service(
        events: events,
        permission: 'granted',
        diagnosticsStatus: 401,
        diagnosticsResponse: {'error': 'unauthorized'},
      );

      final diagnostics = await service.diagnostics();

      expect(diagnostics.setupState, NotificationSetupState.apiError);
      expect(diagnostics.errorCode, 'unauthorized');
      expect(diagnostics.errorMessage, contains('인증'));
      expect(service.setupState, NotificationSetupState.apiError);
    },
  );

  test('registered diagnostics activates current device mapping', () async {
    final events = <String>[];
    final service = _service(
      events: events,
      permission: 'granted',
      diagnosticsResponse: {
        'ok': true,
        'deliveryMode': 'fcm',
        'registeredDeviceCount': 1,
        'devices': [
          {'deviceId': deviceId, 'enabled': true},
        ],
        'recentNotifications': <Object>[],
      },
    );

    final diagnostics = await service.diagnostics();

    expect(diagnostics.currentDeviceRegistered, isTrue);
    expect(diagnostics.registeredDeviceCount, 1);
    expect(diagnostics.setupState, NotificationSetupState.registered);
  });
}

Sotong24NotificationService _service({
  required List<String> events,
  required String permission,
  String requestedPermission = 'granted',
  String? token,
  bool serviceWorkerFails = false,
  int diagnosticsStatus = 200,
  Map<String, dynamic>? diagnosticsResponse,
}) {
  final bridge = _FakeBrowserBridge(
    events: events,
    permission: permission,
    requestedPermission: requestedPermission,
    serviceWorkerFails: serviceWorkerFails,
  );
  final messaging = _FakeMessagingClient(events: events, token: token);
  final api = RemoteControlApi(
    httpClient: MockClient((request) async {
      final endpoint = request.url.path.split('/').last;
      events.add('api:$endpoint');
      if (endpoint == 'notification-diagnostics') {
        return http.Response(
          jsonEncode(
            diagnosticsResponse ??
                {
                  'ok': true,
                  'deliveryMode': 'fcm',
                  'registeredDeviceCount': 0,
                  'devices': <Object>[],
                  'recentNotifications': <Object>[],
                },
          ),
          diagnosticsStatus,
        );
      }
      expect(endpoint, 'register-notification-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['deviceId'], deviceId);
      expect(body['token'], token);
      return http.Response('{"ok":true}', 200);
    }),
    baseUrl: () => 'https://sotongware-control.web.app',
    idTokenProvider: () async => 'id-token',
  );
  return Sotong24NotificationService(
    messagingClient: messaging,
    browserBridge: bridge,
    api: api,
    deviceIdProvider: () async {
      events.add('device-id');
      return deviceId;
    },
    isWebOverride: true,
    webVapidKeyOverride: vapidKey,
  );
}

class _FakeBrowserBridge implements NotificationBrowserBridge {
  _FakeBrowserBridge({
    required this.events,
    required this.permission,
    required this.requestedPermission,
    required this.serviceWorkerFails,
  });

  final List<String> events;
  final String permission;
  final String requestedPermission;
  final bool serviceWorkerFails;

  @override
  BrowserPushCapabilities capabilities() => BrowserPushCapabilities(
    notificationSupported: true,
    serviceWorkerSupported: true,
    secureContext: true,
    permission: permission,
  );

  @override
  Future<String> requestPermission() {
    events.add('permission:request');
    return Future.value(requestedPermission);
  }

  @override
  Future<void> waitForServiceWorkerReady() async {
    events.add('service-worker:ready');
    if (serviceWorkerFails) throw StateError('service worker failed');
  }
}

class _FakeMessagingClient implements NotificationMessagingClient {
  _FakeMessagingClient({required this.events, this.token});

  final List<String> events;
  final String? token;

  @override
  Future<AuthorizationStatus> authorizationStatus() async =>
      AuthorizationStatus.notDetermined;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<String?> getToken({String? vapidKey}) async {
    events.add('fcm:get-token:$vapidKey');
    return token;
  }

  @override
  Stream<RemoteMessage> get onMessage => const Stream.empty();

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<AuthorizationStatus> requestPermission() async =>
      AuthorizationStatus.authorized;
}
