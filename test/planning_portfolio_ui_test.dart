import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/planning_wizard_state.dart';
import 'package:sotong_ware_control/screens/portfolio_hub_screen.dart';
import 'package:sotong_ware_control/theme/control_theme.dart';
import 'package:sotong_ware_control/widgets/planning_wizard_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('기획 3단계 다음 버튼은 기획안 완성', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = PlanningWizardState(
      mode: 'quick',
      step: 3,
      artifactType: 'ebook',
      topic: '[TEST] 주제',
      customerProblem: '[TEST] 문제',
      targetCustomer: '[TEST] 고객',
      desiredOutcome: '[TEST] 결과',
      sentencesManuallyEdited: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ControlTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanningWizardPanel(
              initial: state,
              onChanged: (_) {},
              onSavePlan: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('기획안 완성'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('포트폴리오 허브 모바일 오버플로 없음', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ControlTheme.lightTheme,
        home: const PortfolioHubScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('제작 포트폴리오'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
