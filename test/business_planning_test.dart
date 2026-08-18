import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/core/business/business_catalog.dart';
import 'package:sotong_ware_control/core/business/display_names.dart';
import 'package:sotong_ware_control/data/planning_choice_catalog.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/ops_models.dart';
import 'package:sotong_ware_control/models/planning_wizard_state.dart';
import 'package:sotong_ware_control/screens/ai_business_analysis_screen.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/dashboard_service.dart';
import 'package:sotong_ware_control/services/planning_sentence_composer.dart';
import 'package:sotong_ware_control/services/work_instruction_filename.dart';
import 'package:sotong_ware_control/services/work_instruction_validator.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('메뉴 라벨은 작업지시 제작소이다', () {
    expect(ControlDestination.aiBusinessAnalysis.label, '작업지시 제작소');
  });

  test('사업부 숫자는 카탈로그에서 자동 계산된다', () {
    expect(BusinessCatalog.businesses.length, 6);
  });

  test('내부 ID는 한글 표시명으로 변환된다', () {
    expect(DisplayNames.project('control_center'), '소통총관제');
    final items = DashboardService().attentionItems(
      projects: const [],
      tasks: const [],
      issues: const [],
      deployments: [const DeploymentDoc(id: 'd1', projectId: 'control_center')],
    );
    expect(items.any((e) => e.contains('소통총관제')), isTrue);
  });

  test('필수 입력과 제작 형태 검증', () {
    const empty = BusinessPlanInput();
    expect(empty.hasRequiredFields, isFalse);
    expect(empty.missingRequiredLabels, contains('사업 주제'));
    expect(empty.missingRequiredLabels, contains('제작 형태'));

    final filled = empty.copyWith(
      topic: '주제',
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '결과',
      artifactType: ArtifactType.ebook,
      deliverableTypes: [ArtifactType.ebook],
    );
    expect(filled.hasRequiredFields, isTrue);
    expect(filled.primaryTrack, 'ebook_dev');
  });

  test('전자책 선택 시 관련 선택지·추천이 동작한다', () {
    final problems = optionsFor(
      PlanningChoiceSteps.problems,
      deliverable: PlanningDeliverables.ebook,
      domains: {'rural_life', 'online_income'},
      audiences: {'return_prep', 'sidejob_40_60'},
    );
    expect(problems.any((o) => o.id == 'productize_unknown'), isTrue);

    var state = PlanningWizardState(
      deliverable: PlanningDeliverables.ebook,
      domains: ['rural_life', 'online_income'],
      audiences: ['return_prep', 'sidejob_40_60'],
    );
    state = applyRecommendations(state);
    expect(state.problems, isNotEmpty);
    expect(state.scale, 'basic_40_60');
    expect(state.salesMode, 'cheap_validate');
    expect(state.followUpDeliverables, contains('youtube_shorts'));
  });

  test('추천 기획 자동 완성과 문장 조립', () {
    const composer = PlanningSentenceComposer();
    var state = PlanningWizardState(
      deliverable: PlanningDeliverables.ebook,
      domains: ['rural_life', 'online_income'],
    );
    state = composer.applyAutoComplete(state);
    expect(state.topic, isNotEmpty);
    expect(state.customerProblem, isNotEmpty);
    expect(state.targetCustomer, isNotEmpty);
    expect(state.desiredOutcome, isNotEmpty);

    var withTopic = state.copyWith(topic: '사용자 수정 주제');
    withTopic = composer.applyAutoComplete(withTopic);
    expect(withTopic.topic, '사용자 수정 주제');

    final locked = state.copyWith(
      sentencesManuallyEdited: true,
      topic: '사용자 수정 주제',
    );
    final again = composer.applyAutoComplete(locked);
    expect(again.topic, '사용자 수정 주제');

    final forced = composer.regenerateSentences(locked, force: true);
    expect(forced.topic, isNot(equals('사용자 수정 주제')));
  });

  test('샘플은 원본을 변경하지 않고 복제된다', () {
    final sample = planningSamples.first;
    final originalTopic = sample.seed.topic;
    final clone = cloneSampleSeed(sample.id);
    clone.topic = '변경된 주제';
    expect(sample.seed.topic, originalTopic);
    expect(clone.topic, '변경된 주제');
  });

  test('선택형 데이터 저장·재로드와 기존 직접입력 호환', () async {
    final store = BusinessPlanningStore();
    final now = DateTime.utc(2026, 8, 4).toIso8601String();
    final wizard = PlanningWizardState(
      deliverable: PlanningDeliverables.ebook,
      domains: ['rural_life'],
      topic: '선택형 주제',
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '결과',
    );
    final composed = const PlanningSentenceComposer().toBusinessPlanInput(
      wizard,
    );
    expect(composed.wizardSelections, isNotNull);

    await store.upsertPlan(
      BusinessPlanDocument(
        id: 'plan_wizard',
        input: composed,
        status: PlanningStatus.draft,
        createdAt: now,
        updatedAt: now,
        instructionId: 'wi_plan_wizard',
        version: 1,
      ),
    );
    await store.upsertPlan(
      BusinessPlanDocument(
        id: 'plan_legacy',
        input: const BusinessPlanInput(
          topic: '레거시 주제',
          customerProblem: '문제',
          targetCustomer: '고객',
          desiredOutcome: '결과',
          deliverableTypes: [DeliverableType.ebook],
        ),
        status: PlanningStatus.idea,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final loaded = await store.loadPlans();
    expect(loaded.length, 2);
    expect(loaded.any((p) => p.input.wizardSelections != null), isTrue);
    expect(PlanningStatus.normalize(PlanningStatus.idea), PlanningStatus.draft);
  });

  test('instructionId 유지·version 증가·JSON 검증·파일명', () {
    final service = BusinessPlanningService();
    final input = BusinessPlanInput(
      topic: '시골에서 월수익 300만원을 만드는 현실적인 방법',
      customerProblem:
          '농촌이나 시골에 거주하면서 온라인 수익을 만들고 싶지만, 자신의 경험과 기술을 어떤 상품으로 만들고 어떻게 판매해야 하는지 모른다.',
      targetCustomer: '귀농·귀촌인, 은퇴 준비자, 농촌 거주자, 부업을 원하는 40~60대',
      desiredOutcome: '실제 경험과 실행 단계를 정리한 전자책을 먼저 만들고, 이후 홍보 콘텐츠와 판매 활동으로 연결',
      deliverableTypes: const [DeliverableType.ebook],
    );
    final analysis = service.analyze(input);
    final v1 = service.buildInstruction(
      planId: 'plan_rural',
      input: input,
      analysis: analysis,
      instructionId: 'wi_plan_rural',
      version: 1,
      now: DateTime.utc(2026, 8, 4, 1, 2, 3),
    );
    expect(v1.instructionId, 'wi_plan_rural');
    expect(v1.primaryTrack, 'ebook_dev');
    expect(v1.schemaVersion, '1.1');
    expect(v1.workflowSteps.length, 18);
    expect(v1.contract, isNotNull);

    final v2 = service.buildInstruction(
      planId: 'plan_rural',
      input: input,
      analysis: analysis,
      instructionId: 'wi_plan_rural',
      version: 2,
      createdAt: v1.createdAt,
    );
    expect(v2.instructionId, 'wi_plan_rural');
    expect(v2.instructionVersion, '2');

    final validation = WorkInstructionValidator().validate(
      input: input,
      instruction: v1,
    );
    expect(validation.ok, isTrue);

    final name = WorkInstructionFilename.build(
      now: DateTime(2026, 8, 4),
      sequence: 1,
      topic: input.topic,
      deliverableType: 'ebook',
      version: 1,
    );
    expect(name.startsWith('WI_20260804_001_'), isTrue);
    expect(name.endsWith('_ebook_v1.json'), isTrue);
    expect(name.contains(':'), isFalse);

    final json = v1.toJson();
    expect(WorkInstruction.fromJson(json).instructionId, 'wi_plan_rural');
    expect(contentChecksum(jsonEncode(json)), isNotEmpty);
  });

  test('최신 버전만 목록에 표시', () {
    final a1 = BusinessPlanDocument(
      id: 'a1',
      input: const BusinessPlanInput(topic: '동일'),
      status: PlanningStatus.draft,
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-01T00:00:00Z',
      instructionId: 'wi_same',
      version: 1,
    );
    final a2 = a1.copyWith(
      status: PlanningStatus.instructionReady,
      updatedAt: '2026-08-04T00:00:00Z',
      version: 2,
    );
    final latest = BusinessPlanningStore.latestByInstructionId([a1, a2]);
    expect(latest.length, 1);
    expect(latest.single.version, 2);
  });

  testWidgets('화면 제목과 단계형 wizard 기본 진입', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('작업지시 제작소'), findsOneWidget);
    expect(find.text('사업유형 선택'), findsOneWidget);
    expect(find.text('전자책'), findsWidgets);
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('이전'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('설계 엔진'), findsNothing);
    expect(find.text('사업 주제 *'), findsNothing);
  });

  testWidgets('직접 입력 모드로 전환 가능', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 입력으로 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 입력'));
    await tester.pumpAndSettle();
    expect(find.text('사업 주제 *'), findsOneWidget);
  });

  for (final width in [360.0, 768.0, 1366.0, 1440.0]) {
    testWidgets('오버플로 없음 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('artifact-ebook')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
