/// Local transferred-plan metadata ↔ remote operational state reconcile.
library;

import '../models/business_planning.dart';
import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import 'plan_execution_index.dart';
import 'plan_execution_status.dart';
import 'work_instruction_workshop_presentation.dart';

/// Remote entities that justify showing a transferred work in operational UI.
class RemoteOperationalEvidence {
  const RemoteOperationalEvidence({
    this.jobInstructionIds = const {},
    this.projectIds = const {},
    this.cloudPlanIds = const {},
    this.cloudInstructionIds = const {},
    this.remoteLoaded = false,
  });

  final Set<String> jobInstructionIds;
  final Set<String> projectIds;
  final Set<String> cloudPlanIds;
  final Set<String> cloudInstructionIds;
  final bool remoteLoaded;

  static const staleRemoteMissingTag = 'stale_remote_missing';

  factory RemoteOperationalEvidence.fromRemote({
    required List<RemoteJobDoc> jobs,
    required List<Sotong24RemoteProject> projects,
    Iterable<BusinessPlanDocument> cloudPlans = const [],
    bool remoteLoaded = true,
  }) {
    final jobIds = <String>{};
    for (final j in jobs) {
      final iid = j.instructionId.trim();
      if (iid.isNotEmpty) jobIds.add(iid);
    }

    final projectIds = <String>{};
    for (final p in projects) {
      if (p.isDemo) continue;
      final id = p.projectId.trim();
      if (id.isNotEmpty) projectIds.add(id);
    }

    final cloudPlanIds = <String>{};
    final cloudInstructionIds = <String>{};
    for (final p in cloudPlans) {
      cloudPlanIds.add(p.id.trim());
      final iid = p.stableInstructionId.trim();
      if (iid.isNotEmpty) cloudInstructionIds.add(iid);
    }

    return RemoteOperationalEvidence(
      jobInstructionIds: jobIds,
      projectIds: projectIds,
      cloudPlanIds: cloudPlanIds,
      cloudInstructionIds: cloudInstructionIds,
      remoteLoaded: remoteLoaded,
    );
  }

  bool get backendIsClean =>
      remoteLoaded &&
      jobInstructionIds.isEmpty &&
      projectIds.isEmpty &&
      cloudPlanIds.isEmpty;

  bool hasEvidenceFor(String instructionId) {
    final id = instructionId.trim();
    if (id.isEmpty) return false;
    return jobInstructionIds.contains(id) ||
        projectIds.contains(id) ||
        cloudInstructionIds.contains(id);
  }

  bool hasJobFor(String instructionId) =>
      jobInstructionIds.contains(instructionId.trim());

  bool hasProjectFor(String instructionId) =>
      projectIds.contains(instructionId.trim());
}

class TransferredWorkReconciliation {
  TransferredWorkReconciliation._();

  static bool isStaleLocalTransfer(
    BusinessPlanDocument plan,
    RemoteOperationalEvidence evidence,
  ) {
    if (!evidence.remoteLoaded) return false;
    if (!plan.wasTransferred) return false;
    return !evidence.hasEvidenceFor(plan.stableInstructionId);
  }

  static bool hasRemoteDeliveryEvidence(
    BusinessPlanDocument plan,
    RemoteOperationalEvidence evidence,
  ) {
    if (!plan.wasTransferred) return false;
    if (!evidence.remoteLoaded) return false;
    return evidence.hasJobFor(plan.stableInstructionId);
  }

  /// Tag stale local-only transfers; remove tag when remote evidence returns.
  static ({List<BusinessPlanDocument> plans, bool changed, int staleCount})
  reconcilePlans(
    List<BusinessPlanDocument> plans,
    RemoteOperationalEvidence evidence,
  ) {
    if (!evidence.remoteLoaded) {
      return (plans: plans, changed: false, staleCount: 0);
    }

    var changed = false;
    var staleCount = 0;
    final out = plans.map((plan) {
      final stale = isStaleLocalTransfer(plan, evidence);
      final tags = List<String>.from(plan.tags);
      final hadTag = tags.contains(
        RemoteOperationalEvidence.staleRemoteMissingTag,
      );

      if (stale) {
        staleCount++;
        if (!hadTag) {
          tags.add(RemoteOperationalEvidence.staleRemoteMissingTag);
          changed = true;
        }
        return plan.copyWith(tags: tags);
      }

      if (hadTag) {
        tags.remove(RemoteOperationalEvidence.staleRemoteMissingTag);
        changed = true;
        return plan.copyWith(tags: tags);
      }
      return plan;
    }).toList();

    return (plans: out, changed: changed, staleCount: staleCount);
  }

  /// Operational list: remote evidence required; stale local records excluded.
  static List<BusinessPlanDocument> operationalTransfers(
    List<BusinessPlanDocument> all, {
    required RemoteOperationalEvidence evidence,
    PlanExecutionIndex? execution,
  }) {
    final latest = <String, BusinessPlanDocument>{};
    for (final plan in all) {
      if (plan.isLibraryTrashed) continue;
      if (plan.tags.contains(RemoteOperationalEvidence.staleRemoteMissingTag)) {
        continue;
      }
      if (!plan.wasTransferred) continue;
      if (!evidence.remoteLoaded) continue;
      if (!evidence.hasEvidenceFor(plan.stableInstructionId)) continue;

      final key = plan.stableInstructionId;
      final existing = latest[key];
      if (existing == null || plan.version > existing.version) {
        latest[key] = plan;
      }
    }

    final sent = latest.values.toList()
      ..sort((a, b) {
        final ta =
            DateTime.tryParse(a.lastTransferAt ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb =
            DateTime.tryParse(b.lastTransferAt ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    return sent;
  }

  static String transferListStatusLabel({
    required PlanExecutionSnapshot exec,
    required RemoteOperationalEvidence evidence,
    required String instructionId,
  }) {
    if (!evidence.remoteLoaded) return '상태 확인 중';
    if (!evidence.hasEvidenceFor(instructionId)) {
      return '원격 기록 없음';
    }
    if (exec.hasActualExecution) {
      return WorkInstructionWorkshopPresentation.transferListBriefStatus(exec);
    }
    if (evidence.hasProjectFor(instructionId)) {
      return WorkInstructionWorkshopPresentation.transferListBriefStatus(exec);
    }
    if (evidence.hasJobFor(instructionId)) {
      return '제작공정 준비 중';
    }
    return '전송 완료';
  }
}
