import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/app.dart';
import 'package:sotong_ware_control/state/control_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Control center app loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controlState = ControlState();
    await controlState.initialize();

    await tester.pumpWidget(SotongWareControlApp(controlState: controlState));
    // pumpAndSettle은 일부 환경에서 프레임이 끝나지 않아 10분 타임아웃 발생 가능
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('소통웨어 디지털랩'), findsWidgets);
    expect(find.text('전체사업관리관제'), findsWidgets);
  });

  testWidgets('AI CEO screens navigate on wide web without layout errors', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controlState = ControlState();
    await controlState.initialize();

    await tester.pumpWidget(SotongWareControlApp(controlState: controlState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('AI대표실'), findsWidgets);
    expect(tester.takeException(), isNull);

    for (final label in ['AI전략회의실', 'AI아이디어회의실', '알림센터', 'AI운영관리부']) {
      await tester.tap(find.text(label).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(label), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('AI CEO office fits mobile width without layout errors', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controlState = ControlState();
    await controlState.initialize();

    await tester.pumpWidget(SotongWareControlApp(controlState: controlState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('AI대표실'), findsWidgets);
    expect(find.text('24시간 운영 상태'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
