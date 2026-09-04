/// Responsive / textScale smoke for commercial studio wizard (no network).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/widgets/project_design/project_design_wizard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWizard(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectDesignWizard(
                initial: ProjectDesignState(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop / tablet / mobile + textScale no overflow', (
    tester,
  ) async {
    final cases = <(Size, double)>[
      (const Size(1280, 800), 1.0),
      (const Size(768, 1024), 1.3),
      (const Size(390, 844), 1.5),
    ];
    for (final (size, scale) in cases) {
      await pumpWizard(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('무엇을 만들까요'), findsWidgets);
      // Creation mode cards
      expect(find.textContaining('새 결과물'), findsWidgets);
    }
  });
}
