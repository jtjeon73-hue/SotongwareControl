import '../models/artifact_type.dart';
import '../models/commercial/production_review_status_envelope.dart';
import '../models/instruction_contract.dart';
import '../models/sotong24_remote_models.dart';

/// Merge Firestore workshops with production_review_status envelopes.
class ProductionReviewWorkshopMerge {
  ProductionReviewWorkshopMerge._();

  /// One card per instructionId.
  /// - Both present → project fields + latest valid envelope
  /// - Envelope only → synthetic project card
  /// - Project only → legacy display unchanged
  static List<Sotong24RemoteProject> merge({
    required Iterable<Sotong24RemoteProject> projects,
    required Iterable<ProductionReviewStatusEnvelope> envelopes,
  }) {
    final latestByInstruction = <String, ProductionReviewStatusEnvelope>{};
    for (final e in envelopes) {
      final id = e.instructionId.trim();
      if (id.isEmpty) continue;
      final prev = latestByInstruction[id];
      if (prev == null || _prefer(e, prev)) {
        latestByInstruction[id] = e;
      }
    }

    final used = <String>{};
    final out = <Sotong24RemoteProject>[];

    for (final p in projects) {
      final key = _projectInstructionKey(p);
      final env = latestByInstruction[key] ?? p.productionReviewStatus;
      used.add(key);
      if (env == null) {
        out.add(p);
        continue;
      }
      final preferred = _preferEnvelope(p.productionReviewStatus, env);
      out.add(p.copyWith(productionReviewStatus: preferred));
    }

    for (final entry in latestByInstruction.entries) {
      if (used.contains(entry.key)) continue;
      out.add(projectFromEnvelope(entry.value));
    }

    return out;
  }

  /// Primary envelope for dashboard (prefer preferredId, then changes_requested).
  static ProductionReviewStatusEnvelope? pickPrimary({
    required Iterable<ProductionReviewStatusEnvelope> envelopes,
    String preferredInstructionId = '',
  }) {
    final preferred = preferredInstructionId.trim();
    ProductionReviewStatusEnvelope? hitPreferred;
    ProductionReviewStatusEnvelope? changes;
    ProductionReviewStatusEnvelope? any;
    for (final e in envelopes) {
      any ??= e;
      if (preferred.isNotEmpty && e.instructionId == preferred) {
        hitPreferred = e;
      }
      if (e.ownerReview.decision == 'changes_requested') {
        changes ??= e;
      }
    }
    return hitPreferred ?? changes ?? any;
  }

  /// Envelopes that need owner attention (dashboard "지금 확인할 결과물").
  static List<ProductionReviewStatusEnvelope> awaitingOwnerReview(
    Iterable<ProductionReviewStatusEnvelope> envelopes,
  ) {
    final list = envelopes.where((e) {
      final d = e.ownerReview.decision;
      return d == 'changes_requested' ||
          d == 'pending' ||
          e.readiness.ownerReviewRequired ||
          e.readiness.revisionRequired;
    }).toList();
    list.sort((a, b) => b.revisionRank.compareTo(a.revisionRank));
    return list;
  }

  static Sotong24RemoteProject projectFromEnvelope(
    ProductionReviewStatusEnvelope e,
  ) {
    final title = e.displayTitle.trim().isNotEmpty
        ? e.displayTitle.trim()
        : '(제목 없음)';
    final stage = e.stageOrder > 0 ? e.stageOrder : e.verifiedThroughStep;
    final total = stage > 0 ? (stage < 18 ? 18 : stage) : 18;
    final isTest = e.instructionId.startsWith('wi_test_');
    final status = _statusFromEnvelope(e);
    final revision = e.revisionRank > 0 ? e.revisionRank : 1;
    return Sotong24RemoteProject(
      projectId: e.instructionId,
      title: title,
      productType: ArtifactType.normalize(
        e.artifactType.isNotEmpty ? e.artifactType : ArtifactType.app,
      ),
      contentSubtype: e.contentSubtype,
      currentStage: stage,
      totalStages: total,
      progress: e.readiness.technicalValidationCompleted
          ? ((stage / total) * 100).round().clamp(0, 99)
          : 0,
      status: status,
      approvalStatus: e.ownerReview.decision == 'changes_requested'
          ? ApprovalStatus.revisionRequested
          : ApprovalStatus.notRequired,
      updatedAt: e.updatedAt.isNotEmpty ? e.updatedAt : e.emittedAt,
      lastActivityAt: e.updatedAt.isNotEmpty ? e.updatedAt : e.emittedAt,
      environment: isTest ? 'test' : 'production',
      isTest: isTest,
      productionStatus: e.productionStatus.isNotEmpty
          ? e.productionStatus
          : 'ai_production',
      finalRevision: revision,
      externalPublished: e.readiness.externalPublicationAllowed,
      productionReviewStatus: e,
      stages: const [],
    );
  }

  static String _projectInstructionKey(Sotong24RemoteProject p) {
    final fromEnvelope = p.productionReviewStatus?.instructionId.trim() ?? '';
    if (fromEnvelope.isNotEmpty) return fromEnvelope;
    return p.projectId.trim();
  }

  static bool _prefer(
    ProductionReviewStatusEnvelope a,
    ProductionReviewStatusEnvelope b,
  ) {
    if (a.revisionRank != b.revisionRank) {
      return a.revisionRank > b.revisionRank;
    }
    return !a.isStaleVs(b);
  }

  static ProductionReviewStatusEnvelope _preferEnvelope(
    ProductionReviewStatusEnvelope? existing,
    ProductionReviewStatusEnvelope incoming,
  ) {
    if (existing == null) return incoming;
    return _prefer(incoming, existing) ? incoming : existing;
  }

  static String _statusFromEnvelope(ProductionReviewStatusEnvelope e) {
    if (e.ownerReview.decision == 'changes_requested') {
      return Sotong24WorkStatus.revision;
    }
    if (e.readiness.ownerReviewRequired ||
        e.ownerReview.decision == 'pending') {
      return Sotong24WorkStatus.awaitingApproval;
    }
    if (e.execution.paused) return Sotong24WorkStatus.inProgress;
    if (e.productionStatus.contains('failed')) {
      return Sotong24WorkStatus.error;
    }
    return Sotong24WorkStatus.inProgress;
  }
}
