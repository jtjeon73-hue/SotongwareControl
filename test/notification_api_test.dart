import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';

void main() {
  test(
    'notification device registration sends auth and stable device mapping',
    () async {
      final api = RemoteControlApi(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/control/register-notification-token');
          expect(request.headers['Authorization'], 'Bearer id-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'fcm-token-with-more-than-twenty-characters');
          expect(body['deviceId'], 'device_0123456789abcdef0123456789abcdef');
          expect(body['platform'], 'web');
          return http.Response('{"ok":true}', 200);
        }),
        baseUrl: () => 'https://sotongware-control.web.app',
        idTokenProvider: () async => 'id-token',
      );

      await api.registerNotificationToken(
        token: 'fcm-token-with-more-than-twenty-characters',
        deviceId: 'device_0123456789abcdef0123456789abcdef',
      );
    },
  );

  test(
    'notification diagnostics and test push remain authenticated APIs',
    () async {
      final paths = <String>[];
      final api = RemoteControlApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer id-token');
          if (request.url.path.endsWith('notification-diagnostics')) {
            return http.Response(
              '{"ok":true,"deliveryMode":"fcm","registeredDeviceCount":1}',
              200,
            );
          }
          return http.Response(
            '{"ok":true,"notificationEventId":"event_1","queued":true}',
            200,
          );
        }),
        baseUrl: () => 'https://sotongware-control.web.app',
        idTokenProvider: () async => 'id-token',
      );

      final diagnostics = await api.notificationDiagnostics();
      final test = await api.sendTestNotification();
      expect(diagnostics['deliveryMode'], 'fcm');
      expect(test['notificationEventId'], 'event_1');
      expect(paths, [
        '/api/control/notification-diagnostics',
        '/api/control/send-test-notification',
      ]);
    },
  );
}
