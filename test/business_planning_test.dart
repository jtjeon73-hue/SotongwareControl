import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/core/business/business_catalog.dart';
import 'package:sotong_ware_control/core/business/display_names.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/ops_models.dart';
import 'package:sotong_ware_control/screens/ai_business_analysis_screen.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/dashboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('사업부 숫자는 카탈로그에서 자동 계산된다', () {
    expect(BusinessCatalog.businesses.length, 6);
  });

  test('내부 ID는 한글 표시명으로 변환된다', () {
    expect(DisplayNames.project('control_center'), '소통총관제');
    expect(
      DisplayNames.replaceIdsInMessage('배포 확인 미완료: control_center'),
      '배포 확인 미완료: 소통총관제',
    );
    final items = DashboardService().attentionItems(
      projects: const [],
      tasks: const [],
      issues: const [],
      deployments: [const DeploymentDoc(id: 'd1', projectId: 'control_center')],
    );
    expect(items.any((e) => e.contains('소통총관제')), isTrue);
    expect(items.any((e) => e.contains('control_center')), isFalse);
  });

  test('필수 입력 검증과 제작 형태 규칙', () {
    const empty = BusinessPlanInput();
    expect(empty.hasRequiredFields, isFalse);

    final filled = empty.copyWith(
      topic: '주제',
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '결과',
      deliverableTypes: [DeliverableType.app, DeliverableType.ebook],
    );
    expect(filled.hasRequiredFields, isTrue);

    final undecided = filled.copyWith(
      deliverableTypes: [DeliverableType.undecided],
    );
    expect(undecided.deliverableTypes, [DeliverableType.undecided]);
  });

  test('규칙 기반 평가·작업지시서·JSON schema', () {
    final service = BusinessPlanningService();
    final input = BusinessPlanInput(
      topic: '시골에서 월수익을 만드는 현실 방법',
      customerProblem: '지역 소상공인이 온라인 홍보와 상품화를 어디서부터 해야 할지 모른다',
      targetCustomer: '인구 5만 이하 읍면 소상공인·1인 사업자',
      desiredOutcome: '전자책과 쇼츠로 문의·판매 경로를 검증한다',
      experienceSkills: '산업자동화 현장 경험, Flutter 앱, 웹마케팅',
      existingMaterials: '현장 사례 노트',
      revenueModel: '전자책 단품과 상담 연계',
      monthlyGoal: '검증 단계',
      expectedDuration: '6주',
      deliverableTypes: const [DeliverableType.undecided],
    );

    final analysis = service.analyze(input);
    expect(analysis.criteria.length, 12);
    expect(
      analysis.criteria.every((c) => c.score >= 1 && c.score <= 5),
      isTrue,
    );
    expect([
      PlanningVerdict.readyToBuild,
      PlanningVerdict.validateFirst,
      PlanningVerdict.needsRefine,
      PlanningVerdict.hold,
    ], contains(analysis.verdict));
    expect(analysis.recommendations.length, 5);
    expect(analysis.summary.contains('외부 AI'), isTrue);

    final planId = BusinessPlanningStore.newPlanId(DateTime.utc(2026, 8, 4));
    final instruction = service.buildInstruction(
      planId: planId,
      input: input,
      analysis: analysis,
      now: DateTime.utc(2026, 8, 4, 1, 2, 3),
    );
    expect(instruction.schemaVersion, '1.0');
    expect(instruction.executionStatus, '지시서 준비');
    expect(instruction.createdAt.contains('T'), isTrue);
    expect(instruction.workflowSteps.length, 18);
    expect(
      instruction.workflowSteps.any((s) => !s.applicable && s.notes == '해당 없음'),
      isTrue,
    );

    final json = instruction.toJson();
    expect(json['schemaVersion'], '1.0');
    expect(json['instructionId'], isNotEmpty);
    expect(json['businessIdea'], input.topic);
    expect(WorkInstruction.fromJson(json).schemaVersion, '1.0');

    final cursor = service.buildCursorPrompt(
      input: input,
      instruction: instruction,
    );
    expect(cursor.contains(instruction.instructionId), isTrue);
    expect(cursor.contains('자동 실행 금지'), isTrue);
  });

  test('저장·수정·복제·보관', () async {
    final store = BusinessPlanningStore();
    final now = DateTime.utc(2026, 8, 4).toIso8601String();
    final plan = BusinessPlanDocument(
      id: 'plan_test',
      input: const BusinessPlanInput(
        topic: '테스트 주제',
        customerProblem: '문제',
        targetCustomer: '고객',
        desiredOutcome: '결과',
      ),
      status: PlanningStatus.idea,
      createdAt: now,
      updatedAt: now,
    );
    await store.upsertPlan(plan);
    expect((await store.loadPlans()).length, 1);

    final cloned = plan.copyWith(
      status: PlanningStatus.archived,
      updatedAt: DateTime.utc(2026, 8, 5).toIso8601String(),
    );
    await store.upsertPlan(
      BusinessPlanDocument(
        id: 'plan_clone',
        input: cloned.input.copyWith(topic: '테스트 주제 복제'),
        status: PlanningStatus.idea,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await store.upsertPlan(cloned);
    final plans = await store.loadPlans();
    expect(plans.length, 2);
    expect(plans.any((p) => p.status == PlanningStatus.archived), isTrue);
  });

  testWidgets('운영 분석 / 사업 기획 탭 전환', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('운영 분석'), findsWidgets);
    expect(find.text('사업 기획·작업지시'), findsWidgets);
    expect(find.textContaining('사업 운영 준비도를 점검'), findsOneWidget);

    await tester.tap(find.text('사업 기획·작업지시'));
    await tester.pumpAndSettle();
    expect(find.textContaining('표준 작업지시서를 준비'), findsOneWidget);
    expect(find.textContaining('로컬 규칙 기반 기획 도우미'), findsWidgets);
    // 탭 전환 후 기획 입력 시작 영역이 보인다.
    expect(find.text('기획 입력'), findsOneWidget);
    expect(find.text('사업 기획안 분석'), findsOneWidget);
  });

  testWidgets('분석 후 입력 요약·펼치기·데스크톱 2열', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사업 기획·작업지시'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '사업 주제 *'), '테스트 주제');
    await tester.enterText(find.widgetWithText(TextField, '고객 문제 *'), '고객 문제');
    await tester.enterText(find.widgetWithText(TextField, '대상 고객 *'), '대상 고객');
    await tester.enterText(
      find.widgetWithText(TextField, '원하는 결과 *'),
      '원하는 결과',
    );

    await tester.ensureVisible(find.text('사업 기획안 분석'));
    await tester.tap(find.text('사업 기획안 분석'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('분석 결과'), findsOneWidget);
    expect(find.text('기획 요약'), findsOneWidget);
    expect(find.text('입력 내용 펼치기'), findsOneWidget);
    expect(find.text('입력 수정'), findsOneWidget);
    // 분석 후 기본은 요약(전체 양식 제목 숨김)
    expect(find.text('기획 입력'), findsNothing);

    await tester.tap(find.text('입력 내용 펼치기'));
    await tester.pumpAndSettle();
    expect(find.text('기획 입력'), findsOneWidget);
    expect(find.text('입력 내용 접기'), findsOneWidget);

    await tester.tap(find.text('입력 내용 접기'));
    await tester.pumpAndSettle();
    expect(find.text('기획 요약'), findsOneWidget);
  });

  testWidgets('모바일에서는 분석 후 1열 요약 구조를 쓴다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사업 기획·작업지시'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '사업 주제 *'), '모바일 주제');
    await tester.enterText(find.widgetWithText(TextField, '고객 문제 *'), '문제');
    await tester.enterText(find.widgetWithText(TextField, '대상 고객 *'), '고객');
    await tester.enterText(find.widgetWithText(TextField, '원하는 결과 *'), '결과');
    await tester.ensureVisible(find.text('사업 기획안 분석'));
    await tester.tap(find.text('사업 기획안 분석'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('분석 결과'), findsOneWidget);
    expect(find.text('기획 요약'), findsOneWidget);
  });

  testWidgets('새로고침 후 임시 저장 데이터가 유지된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = BusinessPlanningStore();
    final now = DateTime.utc(2026, 8, 4).toIso8601String();
    await store.upsertPlan(
      BusinessPlanDocument(
        id: 'plan_persist',
        input: const BusinessPlanInput(
          topic: '유지 주제',
          customerProblem: '문제',
          targetCustomer: '고객',
          desiredOutcome: '결과',
        ),
        status: PlanningStatus.idea,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await store.saveDraftInput(
      const BusinessPlanInput(
        topic: '유지 주제',
        customerProblem: '문제',
        targetCustomer: '고객',
        desiredOutcome: '결과',
      ),
    );

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사업 기획·작업지시'));
    await tester.pumpAndSettle();

    expect(find.text('유지 주제'), findsWidgets);
    expect(find.text('저장된 기획안'), findsOneWidget);
    expect(find.text('새 기획'), findsOneWidget);
  });

  test('동일 id 기획안은 로드 시 1건으로 정리된다', () async {
    final older = BusinessPlanDocument(
      id: 'plan_dup',
      input: const BusinessPlanInput(topic: '옛 주제'),
      status: PlanningStatus.idea,
      createdAt: DateTime.utc(2026, 8, 1).toIso8601String(),
      updatedAt: DateTime.utc(2026, 8, 1).toIso8601String(),
    );
    final newer = BusinessPlanDocument(
      id: 'plan_dup',
      input: const BusinessPlanInput(topic: '새 주제'),
      status: PlanningStatus.idea,
      createdAt: DateTime.utc(2026, 8, 1).toIso8601String(),
      updatedAt: DateTime.utc(2026, 8, 4).toIso8601String(),
    );
    SharedPreferences.setMockInitialValues({
      BusinessPlanningStore.plansKey: jsonEncode([
        older.toJson(),
        newer.toJson(),
      ]),
    });
    final store = BusinessPlanningStore();
    final plans = await store.loadPlans();
    expect(plans.length, 1);
    expect(plans.single.input.topic, '새 주제');
    expect(BusinessPlanningStore.dedupeById([older, newer, older]).length, 1);
  });

  testWidgets('페이지는 단일 스크롤이며 탭이 스크롤 문서 안에 있다', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사업 기획·작업지시'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AiBusinessAnalysisScreen),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(SegmentedButton<int>),
      ),
      findsOneWidget,
    );
  });

  testWidgets('동일 id면 저장된 기획안 카드는 1개만 렌더링된다', (tester) async {
    final now = DateTime.utc(2026, 8, 4).toIso8601String();
    final plan = BusinessPlanDocument(
      id: 'plan_one',
      input: const BusinessPlanInput(
        topic: '단일 카드 주제',
        customerProblem: '문제',
        targetCustomer: '고객',
        desiredOutcome: '결과',
      ),
      status: PlanningStatus.idea,
      createdAt: now,
      updatedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      BusinessPlanningStore.plansKey: jsonEncode([
        plan.toJson(),
        plan.toJson(),
      ]),
    });

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사업 기획·작업지시'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('saved-plan-plan_one')), findsOneWidget);
    expect(find.text('새 기획'), findsOneWidget);
    expect(find.text('저장된 기획안'), findsOneWidget);
  });

  for (final width in [360.0, 768.0, 1366.0, 1440.0]) {
    testWidgets('AI 사업분석 오버플로 없음 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('사업 기획·작업지시'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 분석 전·후에도 오버플로 없음
      if (width >= 360) {
        await tester.enterText(
          find.widgetWithText(TextField, '사업 주제 *'),
          '오버플로 검사 주제',
        );
        await tester.enterText(find.widgetWithText(TextField, '고객 문제 *'), '문제');
        await tester.enterText(find.widgetWithText(TextField, '대상 고객 *'), '고객');
        await tester.enterText(
          find.widgetWithText(TextField, '원하는 결과 *'),
          '결과',
        );
        await tester.ensureVisible(find.text('사업 기획안 분석'));
        await tester.tap(find.text('사업 기획안 분석'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('분석 결과'), findsOneWidget);
      }
    });
  }
}
