import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/concept_candidate.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/ai_business_analysis_screen.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/work_instruction_concept_occupancy.dart';
import 'package:sotong_ware_control/services/work_instruction_wizard_session.dart';
import 'package:sotong_ware_control/widgets/project_design/concept_picker_panel.dart';
import 'package:sotong_ware_control/widgets/project_design/project_design_wizard.dart';

BusinessPlanInput _draftInput({
  String topic = '중장년 건강 습관 설계',
  String artifact = ArtifactType.ebook,
  List<String> audiences = const ['age_40_60'],
  List<String> concepts = const ['health_habit__ebook'],
  String sessionId = 'wiz_prev',
}) {
  return BusinessPlanInput(
    topic: topic,
    customerProblem: '습관이 흔들림',
    targetCustomer: audiences.first,
    desiredOutcome: '루틴 정착',
    artifactType: artifact,
    deliverableTypes: [artifact],
    wizardSelections: {
      'mode': 'quick',
      'step': 0,
      'artifactType': artifact,
      'wizardSessionId': sessionId,
      'artifactAnswers': {
        'targetCustomer': audiences,
        'designConcepts': concepts,
      },
      'topic': topic,
      'customerProblem': '습관이 흔들림',
      'targetCustomer': audiences.first,
      'desiredOutcome': '루틴 정착',
      'customTexts': {'designStep': '2', 'wizardSessionId': sessionId},
    },
  );
}

BusinessPlanDocument _transferredPlan({
  required String id,
  required BusinessPlanInput input,
  String status = PlanningStatus.transferred,
  String libraryState = PlanLibraryState.active,
  List<String> tags = const [],
}) {
  return BusinessPlanDocument(
    id: id,
    status: status,
    libraryState: libraryState,
    version: 1,
    createdAt: '2026-08-01T00:00:00.000Z',
    updatedAt: '2026-08-01T00:00:00.000Z',
    instructionId: 'wi_$id',
    lastTransferAt: '2026-08-18T00:00:00.000Z',
    lastTransferMode: 'remote',
    lastRemoteJobId: 'job_$id',
    lastRemoteCommandId: 'cmd_$id',
    tags: tags,
    input: input,
  );
}

ConceptCandidate _candidate({required String id, required String title}) {
  return ConceptCandidate(
    id: id,
    title: title,
    shortDescription: '설명',
    category: ConceptCategory.health,
    targetCustomers: const ['age_40_60'],
    compatibleArtifacts: const [ArtifactType.ebook],
    aiRelevanceScore: 4,
    customerNeedScore: 4,
    businessPotentialScore: 4,
    differentiationScore: 4,
    practicalValueScore: 4,
    beginnerFitScore: 4,
    longevityScore: 4,
    totalScore: 4,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkInstructionWizardSession', () {
    test('새 작업 emptyDesign — STEP 1~3 선택 없음', () {
      final empty = WorkInstructionWizardSession.emptyDesign();
      expect(empty.artifactType, isNull);
      expect(empty.selectedAudiences, isEmpty);
      expect(empty.selectedConceptIds, isEmpty);
      expect(empty.topic, isEmpty);
      expect(empty.step, ProjectDesignStep.artifact);
      expect(empty.hasWizardProgress, isFalse);
    });

    test('이전 draft가 있어도 새 작업 세션은 복원하지 않음', () {
      final draft = _draftInput();
      expect(WorkInstructionWizardSession.hasProgress(draft), isTrue);
      final empty = WorkInstructionWizardSession.emptyDesign();
      expect(empty.selectedConceptIds, isEmpty);
      expect(empty.artifactType, isNot(ArtifactType.ebook));
    });

    test('이어하기는 기존 선택·STEP을 복원', () {
      final restored = WorkInstructionWizardSession.restoreDesign(
        _draftInput(),
      );
      expect(restored.artifactType, ArtifactType.ebook);
      expect(restored.selectedAudiences, contains('age_40_60'));
      expect(restored.selectedConceptIds, contains('health_habit__ebook'));
      expect(restored.step, ProjectDesignStep.topics);
      expect(restored.wizardSessionId, 'wiz_prev');
    });

    test('전송된 leftover draft는 이어하기 대상이 아님', () {
      final draft = _draftInput();
      final plans = [_transferredPlan(id: 'p1', input: draft)];
      expect(
        WorkInstructionWizardSession.isUnsentResumable(draft, plans),
        isFalse,
      );
    });

    test('미전송 draft는 이어하기 대상', () {
      final draft = _draftInput();
      expect(
        WorkInstructionWizardSession.isUnsentResumable(draft, const []),
        isTrue,
      );
    });
  });

  group('ConceptOccupancyIndex', () {
    test('진행 중 동일 컨셉 — 제작 중 / 선택 불가', () {
      final plans = [_transferredPlan(id: 'p1', input: _draftInput())];
      final index = ConceptOccupancyIndex.build(plans: plans);
      final view = index.viewFor(
        conceptId: 'health_habit__ebook',
        artifactType: ArtifactType.ebook,
        title: '중장년 건강 습관 설계',
      );
      expect(view.state, ConceptWorkState.inProgress);
      expect(view.selectable, isFalse);
      expect(view.badgeLabel, '제작 중');
    });

    test('완료 컨셉 — 제작 완료 / 선택 불가', () {
      final plans = [
        _transferredPlan(
          id: 'p1',
          input: _draftInput(),
          status: PlanningStatus.completed,
        ),
      ];
      final index = ConceptOccupancyIndex.build(plans: plans);
      final view = index.viewFor(
        conceptId: 'health_habit__ebook',
        artifactType: ArtifactType.ebook,
        title: '중장년 건강 습관 설계',
      );
      expect(view.state, ConceptWorkState.completed);
      expect(view.selectable, isFalse);
      expect(view.badgeLabel, '제작 완료');
    });

    test('다른 컨셉은 선택 가능', () {
      final plans = [_transferredPlan(id: 'p1', input: _draftInput())];
      final index = ConceptOccupancyIndex.build(plans: plans);
      final view = index.viewFor(
        conceptId: 'sleep_reset__ebook',
        artifactType: ArtifactType.ebook,
        title: '수면 리셋 가이드',
      );
      expect(view.state, ConceptWorkState.available);
      expect(view.selectable, isTrue);
    });

    test('backend entity 삭제 후 stale local transfer는 제작 중을 표시하지 않음', () {
      final plans = [
        _transferredPlan(
          id: 'p1',
          input: _draftInput(),
          tags: const ['stale_remote_missing'],
        ),
      ];
      final index = ConceptOccupancyIndex.build(plans: plans);
      final view = index.viewFor(
        conceptId: 'health_habit__ebook',
        artifactType: ArtifactType.ebook,
        title: '중장년 건강 습관 설계',
      );
      expect(view.state, ConceptWorkState.available);
      expect(view.selectable, isTrue);
      expect(view.badgeLabel, isEmpty);
    });

    test('stale local tag가 있어도 실제 active Project는 해당 카드만 제작 중', () {
      final plan = _transferredPlan(
        id: 'p1',
        input: _draftInput(),
        tags: const ['stale_remote_missing'],
      );
      final project = Sotong24RemoteProject(
        projectId: 'wi_p1',
        title: '중장년 건강 습관 설계',
        productType: ArtifactType.ebook,
        currentStage: 2,
        totalStages: 18,
        progress: 6,
        status: Sotong24WorkStatus.inProgress,
      );
      final index = ConceptOccupancyIndex.build(
        plans: [plan],
        projects: [project],
      );
      expect(
        index
            .viewFor(
              conceptId: 'health_habit__ebook',
              artifactType: ArtifactType.ebook,
              title: '중장년 건강 습관 설계',
            )
            .state,
        ConceptWorkState.inProgress,
      );
      expect(
        index
            .viewFor(
              conceptId: 'sleep_reset__ebook',
              artifactType: ArtifactType.ebook,
              title: '수면 리셋 가이드',
            )
            .state,
        ConceptWorkState.available,
      );
    });

    test('archived/trashed 는 중복 차단에서 제외', () {
      final plans = [
        _transferredPlan(
          id: 'p1',
          input: _draftInput(),
          libraryState: PlanLibraryState.archived,
        ),
        _transferredPlan(
          id: 'p2',
          input: _draftInput(sessionId: 'wiz_trash'),
          libraryState: PlanLibraryState.trashed,
        ),
      ];
      final index = ConceptOccupancyIndex.build(plans: plans);
      final view = index.viewFor(
        conceptId: 'health_habit__ebook',
        artifactType: ArtifactType.ebook,
        title: '중장년 건강 습관 설계',
      );
      expect(view.selectable, isTrue);
    });

    test('원격 프로젝트 제목으로 catalog 컨셉 매칭', () {
      final projects = [
        Sotong24RemoteProject(
          projectId: 'wi_remote',
          title: '중장년 건강 습관 설계',
          productType: ArtifactType.ebook,
          currentStage: 3,
          totalStages: 18,
          progress: 20,
          status: Sotong24WorkStatus.inProgress,
        ),
      ];
      final index = ConceptOccupancyIndex.build(
        plans: const [],
        projects: projects,
      );
      final view = index.viewFor(
        conceptId: 'health_habit__ebook',
        artifactType: ArtifactType.ebook,
        title: '중장년 건강 습관 설계',
      );
      expect(view.state, ConceptWorkState.inProgress);
    });

    test('완료 원격 프로젝트는 제작 완료', () {
      final projects = [
        Sotong24RemoteProject(
          projectId: 'wi_done',
          title: '중장년 건강 습관 설계',
          productType: ArtifactType.ebook,
          currentStage: 18,
          totalStages: 18,
          progress: 100,
          status: Sotong24WorkStatus.completed,
        ),
      ];
      final index = ConceptOccupancyIndex.build(
        plans: const [],
        projects: projects,
      );
      expect(
        index
            .viewFor(
              conceptId: 'health_habit__ebook',
              artifactType: ArtifactType.ebook,
              title: '중장년 건강 습관 설계',
            )
            .state,
        ConceptWorkState.completed,
      );
    });

    test('제목 normalization — 공백·문장부호 차이만 동일 취급', () {
      expect(
        ConceptOccupancyIndex.normalizeTopic('  중장년  건강 습관 설계! '),
        ConceptOccupancyIndex.normalizeTopic('중장년 건강 습관 설계'),
      );
      expect(
        ConceptOccupancyIndex.normalizeTopic('Hello  World'),
        'hello world',
      );
    });

    test('custom 제목 exact match만 차단', () {
      final plans = [
        _transferredPlan(
          id: 'p1',
          input: _draftInput(topic: '우리 마을 건강 모임', concepts: const []),
        ),
      ];
      final index = ConceptOccupancyIndex.build(plans: plans);
      expect(
        index
            .viewFor(artifactType: ArtifactType.ebook, title: '우리 마을 건강 모임')
            .selectable,
        isFalse,
      );
      expect(
        index
            .viewFor(artifactType: ArtifactType.ebook, title: '우리 마을 건강')
            .selectable,
        isTrue,
      );
    });
  });

  group('STEP 7 계약', () {
    test('wasTransferred 성공 목록 계약은 occupancy와 독립', () {
      final fail = BusinessPlanDocument(
        id: 'fail',
        status: PlanningStatus.transferFailed,
        createdAt: '2026-08-01T00:00:00.000Z',
        updatedAt: '2026-08-01T00:00:00.000Z',
        input: _draftInput(topic: '실패'),
      );
      expect(fail.wasTransferred, isFalse);
      final index = ConceptOccupancyIndex.build(plans: [fail]);
      expect(
        index
            .viewFor(
              conceptId: 'health_habit__ebook',
              artifactType: ArtifactType.ebook,
              title: '실패',
            )
            .selectable,
        isTrue,
      );
    });
  });

  testWidgets('새 작업 시작 — 이전 draft 선택을 자동 복원하지 않음', (tester) async {
    SharedPreferences.setMockInitialValues({
      BusinessPlanningStore.draftInputKey: jsonEncode(_draftInput().toJson()),
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('사업유형 선택'), findsOneWidget);
    expect(
      find.byKey(const Key('planning_artifact_ebook_selected')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('planning_resume_draft_banner')),
      findsOneWidget,
    );
    expect(find.text('이전에 작성하던 작업이 있습니다.'), findsOneWidget);
  });

  testWidgets('이어하기 — 기존 draft 선택 복원', (tester) async {
    SharedPreferences.setMockInitialValues({
      BusinessPlanningStore.draftInputKey: jsonEncode(_draftInput().toJson()),
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('planning_resume_draft_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('planning_resume_draft_banner')), findsNothing);
    expect(find.text('핵심 내용'), findsOneWidget);
    expect(find.textContaining('중장년 건강 습관'), findsWidgets);
  });

  testWidgets('새 작업 시작 버튼 — STEP 1 선택 없음 유지', (tester) async {
    SharedPreferences.setMockInitialValues({
      BusinessPlanningStore.draftInputKey: jsonEncode(_draftInput().toJson()),
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planning_new_work_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('planning_resume_draft_banner')), findsNothing);
    expect(find.text('사업유형 선택'), findsOneWidget);
    expect(
      find.byKey(const Key('planning_artifact_ebook_selected')),
      findsNothing,
    );
  });

  testWidgets('ConceptPickerPanel — 제작 중 카드 선택 불가 + 안내', (tester) async {
    final occupancy = ConceptOccupancyIndex.build(
      plans: [_transferredPlan(id: 'p1', input: _draftInput())],
    );
    var selected = <String>[];
    ConceptOccupancyView? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConceptPickerPanel(
              candidates: [
                _candidate(id: 'health_habit__ebook', title: '중장년 건강 습관 설계'),
                _candidate(id: 'sleep_reset__ebook', title: '수면 리셋 가이드'),
              ],
              selectedIds: selected,
              occupancy: occupancy,
              artifactType: ArtifactType.ebook,
              audiences: const ['age_40_60'],
              onOccupiedTap: (v) => tapped = v,
              onSelectionChanged: (ids) => selected = ids,
              onAddUserConcept: (title, memo) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('제작 중'), findsOneWidget);
    await tester.tap(find.textContaining('중장년 건강 습관 설계'));
    await tester.pump();
    expect(selected, isEmpty);
    expect(tapped?.state, ConceptWorkState.inProgress);

    await tester.tap(find.textContaining('수면 리셋 가이드'));
    await tester.pump();
    expect(selected, contains('sleep_reset__ebook'));
  });

  testWidgets('ConceptPickerPanel — 제작 완료 배지', (tester) async {
    final occupancy = ConceptOccupancyIndex.build(
      plans: [
        _transferredPlan(
          id: 'p1',
          input: _draftInput(),
          status: PlanningStatus.completed,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConceptPickerPanel(
            candidates: [
              _candidate(id: 'health_habit__ebook', title: '중장년 건강 습관 설계'),
            ],
            selectedIds: const [],
            occupancy: occupancy,
            artifactType: ArtifactType.ebook,
            onSelectionChanged: (_) {},
            onAddUserConcept: (title, memo) {},
          ),
        ),
      ),
    );
    expect(find.text('제작 완료'), findsOneWidget);
    expect(
      find.byKey(const Key('planning_concept_badge_completed')),
      findsOneWidget,
    );
  });

  testWidgets('ProjectDesignWizard 390px overflow 없음', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final occupancy = ConceptOccupancyIndex.build(
      plans: [_transferredPlan(id: 'p1', input: _draftInput())],
    );
    var state = ProjectDesignState(
      wizardSessionId: 'wiz_test',
      artifactType: ArtifactType.ebook,
      selectedAudiences: const ['age_40_60'],
      step: ProjectDesignStep.topics,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectDesignWizard(
              initial: state,
              occupancy: occupancy,
              onChanged: (s) => state = s,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('핵심 내용'), findsOneWidget);
  });
}
