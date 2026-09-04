import '../models/commercial/production_review_status_envelope.dart';
import 'production_review_status_validator.dart';

/// Result of applying an envelope to the in-memory dry-run store.
class ProductionReviewApplyResult {
  const ProductionReviewApplyResult({
    required this.ok,
    this.applied = false,
    this.duplicate = false,
    this.rejected = false,
    this.code = '',
    this.message = '',
    this.envelope,
    this.sideEffectCount = 0,
    this.notificationWouldEnqueue = false,
  });

  final bool ok;
  final bool applied;
  final bool duplicate;
  final bool rejected;
  final String code;
  final String message;
  final ProductionReviewStatusEnvelope? envelope;
  final int sideEffectCount;

  /// Dry-run parity: true when a live transition would enqueue a notification.
  /// Never actually enqueues — [sideEffectCount] stays 0.
  final bool notificationWouldEnqueue;
}

/// In-memory only store for production review status (no Firestore).
class ProductionReviewStatusStore {
  ProductionReviewStatusStore();

  final Map<String, ProductionReviewStatusEnvelope> _byInstruction = {};
  final Set<String> _seenEventIds = {};

  ProductionReviewStatusEnvelope? get(String instructionId) =>
      _byInstruction[instructionId];

  Iterable<ProductionReviewStatusEnvelope> get all => _byInstruction.values;

  int get count => _byInstruction.length;

  /// Applies [envelope] after validation. Never touches external systems.
  ProductionReviewApplyResult apply(ProductionReviewStatusEnvelope envelope) {
    final stored = _byInstruction[envelope.instructionId];
    final validation = ProductionReviewStatusValidator.validate(
      incoming: envelope,
      stored: stored,
      seenEventIds: _seenEventIds,
    );

    if (!validation.ok) {
      return ProductionReviewApplyResult(
        ok: false,
        rejected: validation.rejected,
        code: validation.code,
        message: validation.message,
      );
    }

    if (validation.duplicate) {
      return ProductionReviewApplyResult(
        ok: true,
        duplicate: true,
        code: validation.code,
        message: validation.message,
        envelope: stored ?? envelope,
        sideEffectCount: 0,
        notificationWouldEnqueue: false,
      );
    }

    final sanitized = ProductionReviewStatusValidator.sanitize(envelope);
    _seenEventIds.add(sanitized.eventId);
    _byInstruction[sanitized.instructionId] = sanitized;

    final isBaseline =
        sanitized.initialSync || sanitized.syncKind == 'baseline';
    final identicalFingerprint =
        stored != null &&
        sanitized.contentFingerprint.isNotEmpty &&
        stored.contentFingerprint == sanitized.contentFingerprint;
    final wouldEnqueue = !isBaseline &&
        !identicalFingerprint &&
        sanitized.syncKind != 'baseline' &&
        _wouldNotify(sanitized, stored);

    return ProductionReviewApplyResult(
      ok: true,
      applied: true,
      envelope: sanitized,
      sideEffectCount: 0,
      notificationWouldEnqueue: wouldEnqueue,
    );
  }

  bool _wouldNotify(
    ProductionReviewStatusEnvelope incoming,
    ProductionReviewStatusEnvelope? stored,
  ) {
    if (incoming.ownerReview.decision == 'changes_requested') return true;
    if (incoming.readiness.revisionReady &&
        (stored == null || !stored.readiness.revisionReady)) {
      return true;
    }
    if (incoming.readiness.registrationEligible &&
        (stored == null || !stored.readiness.registrationEligible)) {
      return true;
    }
    if (incoming.readiness.technicalValidationCompleted &&
        (stored == null || !stored.readiness.technicalValidationCompleted)) {
      return true;
    }
    return false;
  }

  void clear() {
    _byInstruction.clear();
    _seenEventIds.clear();
  }
}
