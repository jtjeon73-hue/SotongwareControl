import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/plan_execution_index.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/transferred_work_reconciliation.dart';
import 'package:sotong_ware_control/services/work_instruction_workshop_presentation.dart';

BusinessPlanDocument _transferredPlan({
  required String id,
  required String topic,
  String? instructionId,
}) {
  final iid = instructionId ?? 'wi_$id';
  return BusinessPlanDocument(
    id: id,
    status: PlanningStatus.transferred,
    version: 1,
    createdAt: '2026-08-18T09:00:00.000Z',
    updatedAt: '2026-08-18T09:00:00.000Z',
    lastTransferAt: '2026-08-18T09:47:00.000Z',
    lastTransferMode: PlanProgressStatus.remoteMode,
    lastRemoteJobId: 'job_$id',
    lastRemoteCommandId: 'cmd_$id',
    input: BusinessPlanInput(
      topic: topic,
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '결과',
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [ArtifactType.ebook],
    ),
    instruction: WorkInstruction(
      schemaVersion: '1.0',
      instructionId: iid,
      projectId: 'proj',
      instructionVersion: '1',
      createdAt: '2026-08-18T09:00:00.000Z',
      updatedAt: '2026-08-18T09:00:00.000Z',
      businessIdea: topic,
      businessPurpose: '목적',
      customerProblem: '문제',
      targetCustomer: '고객',
      deliverableTypes: const ['ebook'],
      recommendedSequence: const ['ebook'],
      valueProposition: '가치',
      requiredMaterials: const [],
      workflowSteps: const [],
      completionCriteria: const [],
      qualityChecks: const [],
      risks: const [],
      monetizationOptions: const [],
      deploymentTargets: const [],
      promotionChannels: const [],
      approvalItems: const [],
      executionStatus: 'draft',
      artifactType: 'ebook',
      checksum: 'abc',
    ),
  );
}

RemoteOperationalEvidence _cleanRemote() =>
    RemoteOperationalEvidence.fromRemote(
      jobs: const [],
      projects: const [],
      remoteLoaded: true,
    );

void main() {
  group('TransferredWorkReconciliation', () {
    test('backend clean + 5 local transferred → operational list 0', () {
      final plans = [
        for (var i = 1; i <= 5; i++)
          _transferredPlan(id: 'old_$i', topic: '과거 전자책 $i'),
      ];
      final evidence = _cleanRemote();

      final reconciled = TransferredWorkReconciliation.reconcilePlans(
        plans,
        evidence,
      );
      expect(reconciled.changed, isTrue);
      expect(reconciled.staleCount, 5);

      final operational = TransferredWorkReconciliation.operationalTransfers(
        reconciled.plans,
        evidence: evidence,
      );
      expect(operational, isEmpty);

      final legacy = WorkInstructionWorkshopPresentation.successfulTransfers(
        plans,
      );
      expect(legacy.length, 5);
    });

    test('remote job B without project → 제작공정 준비 중', () {
      const id = 'wi_plan_b';
      final plan = _transferredPlan(
        id: 'plan_b',
        topic: '리뷰 응대 문장 가이드 전자책',
        instructionId: id,
      );
      final evidence = RemoteOperationalEvidence.fromRemote(
        jobs: [
          RemoteJobDoc(
            jobId: 'job_b',
            ownerUid: 'u',
            title: plan.input.topic,
            type: 'ebook',
            status: 'queued',
            assignedAgentId: 'agent',
            instructionId: id,
          ),
        ],
        projects: const [],
        remoteLoaded: true,
      );
      final exec = PlanExecutionIndex.fromRemoteProjects(
        const [],
        jobs: [
          RemoteJobDoc(
            jobId: 'job_b',
            ownerUid: 'u',
            title: plan.input.topic,
            type: 'ebook',
            status: 'queued',
            assignedAgentId: 'agent',
            instructionId: id,
          ),
        ],
      ).snapshotFor(plan);

      final label = TransferredWorkReconciliation.transferListStatusLabel(
        exec: exec,
        evidence: evidence,
        instructionId: id,
      );
      expect(label, '제작공정 준비 중');
    });

    test('project B with stage → 진행 중', () {
      const id = 'wi_plan_b';
      final plan = _transferredPlan(
        id: 'plan_b',
        topic: '리뷰 응대 문장 가이드 전자책',
        instructionId: id,
      );
      final project = Sotong24RemoteProject(
        projectId: id,
        title: plan.input.topic,
        productType: 'ebook',
        currentStage: 1,
        totalStages: 18,
        progress: 0,
        status: Sotong24WorkStatus.inProgress,
        stages: [
          Sotong24RemoteStage(
            stageId: 'idea_clarify',
            stageNumber: 1,
            stageName: '아이디어 정리',
            status: Sotong24WorkStatus.inProgress,
          ),
        ],
      );
      final evidence = RemoteOperationalEvidence.fromRemote(
        jobs: [
          RemoteJobDoc(
            jobId: 'job_b',
            ownerUid: 'u',
            title: plan.input.topic,
            type: 'ebook',
            status: 'running',
            assignedAgentId: 'agent',
            instructionId: id,
          ),
        ],
        projects: [project],
        remoteLoaded: true,
      );
      final exec = PlanExecutionIndex.fromRemoteProjects(
        [project],
        jobs: [
          RemoteJobDoc(
            jobId: 'job_b',
            ownerUid: 'u',
            title: plan.input.topic,
            type: 'ebook',
            status: 'running',
            assignedAgentId: 'agent',
            instructionId: id,
          ),
        ],
      ).snapshotFor(plan);

      final label = TransferredWorkReconciliation.transferListStatusLabel(
        exec: exec,
        evidence: evidence,
        instructionId: id,
      );
      expect(label, contains('진행 중'));
    });

    test('stale tag removed when remote evidence returns', () {
      final stalePlan = _transferredPlan(
        id: 'a',
        topic: 'A',
      ).copyWith(tags: [RemoteOperationalEvidence.staleRemoteMissingTag]);
      const id = 'wi_a';
      final evidence = RemoteOperationalEvidence.fromRemote(
        jobs: [
          RemoteJobDoc(
            jobId: 'job_a',
            ownerUid: 'u',
            title: 'A',
            type: 'ebook',
            status: 'queued',
            assignedAgentId: 'agent',
            instructionId: id,
          ),
        ],
        projects: const [],
        remoteLoaded: true,
      );

      final result = TransferredWorkReconciliation.reconcilePlans([
        stalePlan,
      ], evidence);
      expect(result.changed, isTrue);
      expect(
        result.plans.first.tags,
        isNot(contains(RemoteOperationalEvidence.staleRemoteMissingTag)),
      );
    });
  });
}
