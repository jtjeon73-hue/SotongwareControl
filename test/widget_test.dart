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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('소통총관제'), findsWidgets);
    expect(find.text('전체 사업 현황'), findsWidgets);
  });

  testWidgets('AI departments navigate on wide web without layout errors', (
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

    expect(find.text('소통총괄관제'), findsWidgets);
    expect(tester.takeException(), isNull);

    for (final label in ['AI대표', 'AI상품개발부', 'AI지시진행부', 'AI전략부', 'AI홍보.마케팅부']) {
      await tester.tap(find.text(label).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(label), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Dashboard fits mobile width without layout errors', (
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

    expect(find.text('소통총괄관제'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
