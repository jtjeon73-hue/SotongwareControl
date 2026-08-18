import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/services/sotong24_workshop_presentation.dart';
import 'package:sotong_ware_control/services/work_instruction_workshop_presentation.dart';
import 'package:sotong_ware_control/widgets/project_design/project_design_wizard.dart';

Sotong24RemoteProject _project({
  required String id,
  required String title,
  String status = Sotong24WorkStatus.inProgress,
}) {
  return Sotong24RemoteProject(
    projectId: id,
    title: title,
    productType: 'ebook',
    currentStage: 1,
    totalStages: 18,
    progress: 0,
    status: status,
    stages: [
      Sotong24RemoteStage(
        stageId: 'idea_clarify',
        stageNumber: 1,
        stageName: '아이디어 정리',
        status: status,
      ),
      for (var i = 2; i <= 18; i++)
        Sotong24RemoteStage(
          stageId: 's$i',
          stageNumber: i,
          stageName: '단계 $i',
          status: Sotong24WorkStatus.ready,
        ),
    ],
  );
}

ProjectDesignState _finalizeState() {
  return ProjectDesignState(
    step: ProjectDesignStep.finalize,
    artifactType: ArtifactType.ebook,
    selectedAudiences: const ['rural_resident'],
    topic: '온라인 수익 첫걸음 전자책',
    customerProblem: '시작점을 모름',
    targetCustomer: '초보 창업자',
    desiredOutcome: '첫 전자책 출간',
    planningConfirmed: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldTitle = '중장년 건강 습관 설계 전자책';
  const newTitle = '온라인 수익 첫걸음 전자책';
  const newId = 'wi_plan_1787030423574';
  const oldId = 'wi_plan_old_health';

  group('InstructionCreateUx', () {
    test('일반 생성 메시지는 JSON/수동가져오기 표현을 포함하지 않음', () {
      expect(
        InstructionCreateUx.isInternalOperatorMessage(
          InstructionCreateUx.createdMessage,
        ),
        isFalse,
      );
      expect(InstructionCreateUx.createdMessage, '작업지시서 생성 완료');
      expect(
        InstructionCreateUx.isInternalOperatorMessage(
          'JSON 다운로드 완료 · 수동 가져오기 대기 (전달됨 아님)',
        ),
        isTrue,
      );
    });

    test('생성 완료 후 버튼 비활성, 동일 내용 재생성 방지', () {
      final kind = InstructionCreateUx.kind(generated: true, stale: false);
      expect(kind, InstructionCreateButtonKind.completed);
      expect(InstructionCreateUx.label(kind), '✓ 작업지시서 생성 완료');
      expect(InstructionCreateUx.enabled(kind, canCreate: true), isFalse);
    });

    test('내용 변경 시에만 명시적 재생성', () {
      final kind = InstructionCreateUx.kind(generated: true, stale: true);
      expect(kind, InstructionCreateButtonKind.recreate);
      expect(InstructionCreateUx.label(kind), '변경사항으로 작업지시서 다시 생성');
      expect(InstructionCreateUx.enabled(kind, canCreate: true), isTrue);
    });
  });

  group('ProjectDesignWizard create button', () {
    testWidgets('생성 완료 후 버튼 비활성', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      var createCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectDesignWizard(
                initial: _finalizeState(),
                onChanged: (_) {},
                instructionGenerated: true,
                onRequestCreateInstruction: () => createCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('✓ 작업지시서 생성 완료'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('planning_create_instruction')),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.byKey(const Key('planning_create_instruction')));
      await tester.pump();
      expect(createCount, 0);
    });

    testWidgets('변경사항으로 작업지시서 다시 생성', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      var recreateCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectDesignWizard(
                initial: _finalizeState(),
                onChanged: (_) {},
                instructionGenerated: true,
                instructionStale: true,
                onRequestRecreateInstruction: () => recreateCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('변경사항으로 작업지시서 다시 생성'), findsOneWidget);
      await tester.tap(find.byKey(const Key('planning_create_instruction')));
      await tester.pump();
      expect(recreateCount, 1);
    });
  });

  group('Workshop exact instructionId', () {
    test('exact id만 선택하고 이전 project fallback 없음', () {
      final oldP = _project(id: oldId, title: oldTitle);
      final newP = _project(id: newId, title: newTitle);
      final both = [oldP, newP];

      final waiting = Sotong24WorkshopPresentation.resolveFocus(
        projects: [oldP],
        focusInstructionId: newId,
      );
      expect(waiting.waitingForExactProject, isTrue);
      expect(waiting.project, isNull);

      final found = Sotong24WorkshopPresentation.resolveFocus(
        projects: both,
        focusInstructionId: newId,
      );
      expect(found.waitingForExactProject, isFalse);
      expect(found.project?.projectId, newId);
      expect(found.project?.title, newTitle);

      final dash = Sotong24WorkshopPresentation.resolveFocus(projects: both);
      expect(dash.waitingForExactProject, isFalse);
      expect(dash.project, isNotNull);
    });

    testWidgets('B project 미생성 시 준비 중 + A fallback 없음', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [_project(id: oldId, title: oldTitle)],
      );
      addTearDown(repo.dispose);

      final agentRepo = RemoteAgentRepository(
        forceMemory: true,
        memoryJobs: [
          RemoteJobDoc(
            jobId: 'job_new',
            ownerUid: 'u',
            title: newTitle,
            type: 'ebook',
            status: 'queued',
            assignedAgentId: 'agent',
            instructionId: newId,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductWorkshopScreen(
              repository: repo,
              agentRepository: agentRepo,
              focusInstructionId: newId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workshop_preparing_card')), findsOneWidget);
      expect(find.text('AI 제작공정을 준비하고 있습니다.'), findsOneWidget);
      expect(find.byKey(const Key('workshop_agent_received')), findsOneWidget);
      expect(find.text('상태 재확인'), findsOneWidget);
      expect(find.text(oldTitle), findsNothing);
      expect(find.text(newTitle), findsNothing);
    });

    testWidgets('B project 생성 후 정확한 project 열림 + A fallback 없음', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [
          _project(id: oldId, title: oldTitle),
          _project(id: newId, title: newTitle),
        ],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductWorkshopScreen(
              repository: repo,
              focusInstructionId: newId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(newTitle), findsWidgets);
      expect(find.text(oldTitle), findsNothing);
      expect(find.text('제작 상세'), findsOneWidget);
    });
  });
}
