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

  testWidgets('최종 확인 데스크톱에서 섹션 카드 표시', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = PlanningWizardState(
      mode: 'quick',
      step: 4,
      artifactType: 'ebook',
      topic: '시골에서 AI를 활용해 온라인 수익 기반을 만드는 방법',
      customerProblem: '가능한 수익 모델과 실행 순서를 모름',
      targetCustomer: '농촌 거주 중장년',
      desiredOutcome: '90일 실행',
      sentencesManuallyEdited: true,
      artifactAnswers: {
        'outputFormat': ['both'],
        'ebookKind': ['guide'],
      },
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

    expect(find.text('기본 기획'), findsOneWidget);
    expect(find.text('주요 결과물'), findsOneWidget);
    expect(find.text('전자책 구성'), findsOneWidget);
    expect(find.textContaining('전자책'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('최종 확인 모바일 1열·오버플로 없음', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = PlanningWizardState(
      mode: 'quick',
      step: 4,
      artifactType: 'ebook',
      topic: '[TEST] 모바일 요약',
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '결과',
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

    expect(find.text('기본 기획'), findsOneWidget);
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
