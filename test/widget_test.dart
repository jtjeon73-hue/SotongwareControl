import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/app.dart';

void main() {
  testWidgets('Control center app loads', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SotongWareControlApp());
    await tester.pumpAndSettle();

    expect(find.text('소통웨어 디지털랩'), findsWidgets);
    expect(find.text('오늘의 AI 종합 보고'), findsOneWidget);
  });
}
