import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/screens/system_settings_screen.dart';
import 'package:sotong_ware_control/services/sotong24_notification_service.dart';
import 'package:sotong_ware_control/widgets/notification_diagnostics_card.dart';

void main() {
  const history = NotificationHistoryItem(
    eventId: 'event_1',
    eventType: 'production_completed',
    title: '전자책 제작 완료',
    body: '전자책 제작이 완료되었습니다. 결과를 확인해 주세요.',
    status: 'delivered',
    createdAt: '2026-08-25T00:00:00.000Z',
    deepLink: '/?screen=ai-production&projectId=wi_plan_1',
  );

  testWidgets('mobile diagnostics shows permission, device, FCM and history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FakeNotificationController(
      value: const NotificationDiagnostics(
        permission: NotificationPermissionState.authorized,
        configured: true,
        deliveryMode: 'fcm',
        currentDeviceRegistered: true,
        registeredDeviceCount: 2,
        recentNotifications: [history],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NotificationDiagnosticsCard(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('브라우저 권한'), findsOneWidget);
    expect(find.text('허용'), findsOneWidget);
    expect(find.text('FCM 활성'), findsWidgets);
    expect(find.text('등록됨'), findsOneWidget);
    expect(find.text('2대'), findsOneWidget);
    expect(find.text('전자책 제작 완료'), findsOneWidget);
    final testButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('notification_test_button')),
    );
    expect(testButton.onPressed, isNotNull);
  });

  testWidgets('enable registers current device then test push is explicit', (
    tester,
  ) async {
    final controller = _FakeNotificationController(
      value: const NotificationDiagnostics(
        permission: NotificationPermissionState.notDetermined,
        configured: true,
        deliveryMode: 'fcm',
        currentDeviceRegistered: false,
        registeredDeviceCount: 0,
        recentNotifications: [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationDiagnosticsCard(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.testCalls, 0);

    await tester.tap(find.byKey(const Key('notification_enable_button')));
    await tester.pumpAndSettle();
    expect(controller.enableCalls, 1);
    expect(find.text('등록됨'), findsOneWidget);
    expect(controller.testCalls, 0);

    await tester.tap(find.byKey(const Key('notification_test_button')));
    await tester.pumpAndSettle();
    expect(controller.testCalls, 1);
    expect(find.text('테스트 알림을 전송 대기열에 등록했습니다.'), findsOneWidget);
  });

  testWidgets(
    'system settings keeps notification controls in diagnostics area',
    (tester) async {
      final controller = _FakeNotificationController(
        value: const NotificationDiagnostics(
          permission: NotificationPermissionState.denied,
          configured: true,
          deliveryMode: 'fcm',
          currentDeviceRegistered: false,
          registeredDeviceCount: 0,
          recentNotifications: [],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SystemSettingsScreen(
              onNavigate: (_) {},
              notificationController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('시스템 설정'), findsOneWidget);
      expect(
        find.byKey(const Key('notification_diagnostics_card')),
        findsOneWidget,
      );
      expect(find.text('차단됨'), findsOneWidget);
      final testButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('notification_test_button')),
      );
      expect(testButton.onPressed, isNull);
    },
  );

  testWidgets(
    'diagnostics API failure exits loading and shows explicit error',
    (tester) async {
      final controller = _FakeNotificationController(
        value: const NotificationDiagnostics(
          permission: NotificationPermissionState.notDetermined,
          configured: true,
          deliveryMode: 'unknown',
          currentDeviceRegistered: false,
          registeredDeviceCount: 0,
          recentNotifications: [],
          setupState: NotificationSetupState.apiError,
          errorMessage: '인증이 만료되었습니다. 다시 로그인해 주세요.',
          errorCode: 'auth',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationDiagnosticsCard(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('API 오류'), findsNWidgets(2));
      expect(find.textContaining('(auth)'), findsOneWidget);
    },
  );

  testWidgets(
    'unsupported in-app browser exits checking and directs to Chrome',
    (tester) async {
      final controller = _FakeNotificationController(
        value: const NotificationDiagnostics(
          permission: NotificationPermissionState.unsupported,
          configured: true,
          deliveryMode: 'fcm',
          currentDeviceRegistered: false,
          registeredDeviceCount: 0,
          recentNotifications: [],
          setupState: NotificationSetupState.unsupported,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationDiagnosticsCard(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('알림 지원 안 됨'), findsOneWidget);
      expect(
        find.byKey(const Key('notification_unsupported_guidance')),
        findsOneWidget,
      );
      final enableButton = tester.widget<FilledButton>(
        find.byKey(const Key('notification_enable_button')),
      );
      expect(enableButton.onPressed, isNull);
    },
  );
}

class _FakeNotificationController implements NotificationController {
  _FakeNotificationController({required this.value});

  NotificationDiagnostics value;
  int enableCalls = 0;
  int disableCalls = 0;
  int testCalls = 0;

  @override
  NotificationSetupState get setupState => value.setupState;

  @override
  Stream<NotificationSetupState> get setupStates => const Stream.empty();

  @override
  bool get isConfigured => value.configured;

  @override
  Future<NotificationDiagnostics> diagnostics() async => value;

  @override
  Future<bool> enable() async {
    enableCalls += 1;
    value = NotificationDiagnostics(
      permission: NotificationPermissionState.authorized,
      configured: true,
      deliveryMode: value.deliveryMode,
      currentDeviceRegistered: true,
      registeredDeviceCount: 1,
      recentNotifications: value.recentNotifications,
    );
    return true;
  }

  @override
  Future<void> disable() async {
    disableCalls += 1;
  }

  @override
  Future<String> sendTestNotification() async {
    testCalls += 1;
    return 'event_test';
  }
}
