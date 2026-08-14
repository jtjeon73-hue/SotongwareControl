import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/plan_execution_index.dart';
import 'package:sotong_ware_control/services/plan_execution_status.dart';
import 'package:sotong_ware_control/services/plan_library_management.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/plan_user_facing_status.dart';

BusinessPlanDocument _plan({
  required String id,
  String instructionId = '',
  String status = PlanningStatus.draft,
  String topic = '가이드 전자책개발',
  bool hasWi = false,
  String? lastTransferMode,
  PlanningAnalysisResult? analysis,
}) {
  return BusinessPlanDocument(
    id: id,
    input: BusinessPlanInput(
      topic: topic,
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [ArtifactType.ebook],
      targetCustomer: '50대 초보',
      customerProblem: '문제',
      desiredOutcome: '결과',
      wizardSelections: hasWi ? null : const {'step': 3, 'mode': 'quick'},
    ),
    status: status,
    createdAt: '2026-08-05T04:46:05.067Z',
    updatedAt: '2026-08-05T04:48:33.242Z',
    instructionId: instructionId.isEmpty ? 'wi_$id' : instructionId,
    instruction: hasWi
        ? WorkInstruction(
            schemaVersion: '1.0',
            instructionId: instructionId.isEmpty ? 'wi_$id' : instructionId,
            projectId: id,
            instructionVersion: '1',
            createdAt: '2026-08-05T04:46:05.067Z',
            updatedAt: '2026-08-05T04:46:05.067Z',
            businessIdea: '가이드 전자책개발',
            businessPurpose: '목적',
            customerProblem: '문제',
            targetCustomer: '50대',
            deliverableTypes: const ['ebook'],
            recommendedSequence: const ['ebook'],
            valueProposition: 'v',
            requiredMaterials: const [],
            workflowSteps: const [],
            completionCriteria: const [],
            qualityChecks: const [],
            risks: const [],
            monetizationOptions: const [],
            deploymentTargets: const [],
            promotionChannels: const [],
            approvalItems: const [],
            executionStatus: '지시서 준비',
            artifactType: ArtifactType.ebook,
            primaryTrack: 'ebook_dev',
          )
        : null,
    lastTransferMode: lastTransferMode,
    analysis: analysis,
  );
}

Sotong24RemoteProject _remoteOpsProject() {
  return Sotong24RemoteProject(
    projectId: 'wi_plan_1785905165067',
    title: '50대 초보도 따라 하는 AI 전자책 첫 출간',
    productType: ArtifactType.ebook,
    currentStage: 18,
    totalStages: 18,
    progress: 95,
    status: Sotong24WorkStatus.awaitingApproval,
    approvalStatus: ApprovalStatus.pending,
    pcStatus: Sotong24PcLinkStatus.online,
    lastHeartbeat: DateTime.now().toUtc().toIso8601String(),
    startedAt: '2026-08-06T10:10:00+09:00',
    updatedAt: '2026-08-12T12:50:07+09:00',
    stages: const [
      Sotong24RemoteStage(
        stageId: 'maintain',
        stageNumber: 18,
        stageName: '유지관리',
        status: Sotong24WorkStatus.awaitingApproval,
        approvalRequired: true,
        approvalStatus: ApprovalStatus.pending,
      ),
    ],
  );
}

void main() {
  group('PlanExecutionStatusResolver', () {
    test('전달 전 — 작업지시 제작 n/7 · 미전달', () {
      final plan = _plan(id: 'plan_new', hasWi: false);
      final exec = PlanExecutionStatusResolver.resolve(plan);
      expect(exec.isPostTransfer, isFalse);
      expect(exec.instructionProgressLine, '작업지시 4/7');
      expect(exec.productionProgressLine, '소통24워크: 미전달');
      expect(
        PlanUserFacingStatus.label(plan, execution: exec),
        PlanUserFacingStatus.instructionDesign,
      );
    });

    test('전달됨·미실행 잔재 — operational protect 아님', () {
      final plan = _plan(
        id: 'plan_1785904827934',
        instructionId: 'wi_plan_1785904827934',
        status: PlanningStatus.transferred,
        hasWi: true,
        lastTransferMode: PlanProgressStatus.folderMode,
      );
      final exec = PlanExecutionStatusResolver.resolve(plan);
      expect(exec.isDeliveredOnly, isTrue);
      expect(exec.hasActualExecution, isFalse);
      expect(exec.primaryStatusLabel, '전달됨 · 미실행');
      expect(
        PlanUserFacingStatus.isOperationallyProtected(plan, execution: exec),
        isFalse,
      );
      expect(
        PlanLibraryManagement.isBulkArchiveBlocked(plan, execution: exec),
        isFalse,
      );
    });

    test('운영 wi_plan_1785905165067 — mirror 기반 표시', () {
      final plan = _plan(
        id: 'plan_1785905165067',
        instructionId: 'wi_plan_1785905165067',
        status: PlanningStatus.transferred,
        hasWi: true,
        lastTransferMode: PlanProgressStatus.folderMode,
      );
      final remote = _remoteOpsProject();
      final exec = PlanExecutionStatusResolver.resolve(plan, remoteProject: remote);
      expect(exec.displayTitle, '50대 초보도 따라 하는 AI 전자책 첫 출간');
      expect(exec.instructionProgressLine, '작업지시 완료');
      expect(exec.productionProgressLine, '제작 18/18 · 승인대기');
      expect(
        PlanUserFacingStatus.label(plan, execution: exec),
        PlanUserFacingStatus.awaitingApproval,
      );
      expect(
        PlanUserFacingStatus.isOperationallyProtected(plan, execution: exec),
        isTrue,
      );
      expect(
        PlanLibraryManagement.isBulkArchiveBlocked(plan, execution: exec),
        isTrue,
      );
    });

    test('hold verdict는 전달 후 실행 중이면 보류로 덮지 않음', () {
      final plan = _plan(
        id: 'plan_1785905165067',
        instructionId: 'wi_plan_1785905165067',
        status: PlanningStatus.transferred,
        hasWi: true,
        lastTransferMode: PlanProgressStatus.folderMode,
        analysis: const PlanningAnalysisResult(
          verdict: PlanningVerdict.hold,
          averageScore: 2.5,
          summary: 'hold',
          criteria: [],
          recommendations: [],
        ),
      );
      final exec = PlanExecutionStatusResolver.resolve(
        plan,
        remoteProject: _remoteOpsProject(),
      );
      expect(PlanUserFacingStatus.label(plan, execution: exec), '승인대기');
    });
  });

  group('PlanExecutionIndex', () {
    test('instructionId로 remote project 연결', () {
      final plan = _plan(
        id: 'plan_1785905165067',
        instructionId: 'wi_plan_1785905165067',
        status: PlanningStatus.transferred,
        hasWi: true,
        lastTransferMode: PlanProgressStatus.folderMode,
      );
      final index = PlanExecutionIndex.fromRemoteProjects([_remoteOpsProject()]);
      final exec = index.snapshotFor(plan);
      expect(exec.productionCurrentStage, 18);
      expect(exec.currentStageLabel, isNotEmpty);
    });
  });
}
