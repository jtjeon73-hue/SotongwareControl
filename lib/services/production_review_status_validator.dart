import '../models/commercial/production_review_status_envelope.dart';

/// Validation outcome for a production review status envelope.
class ProductionReviewValidationResult {
  const ProductionReviewValidationResult({
    required this.ok,
    this.duplicate = false,
    this.rejected = false,
    this.code = '',
    this.message = '',
    this.strippedFields = const [],
  });

  final bool ok;
  final bool duplicate;
  final bool rejected;
  final String code;
  final String message;
  final List<String> strippedFields;

  static const accepted = ProductionReviewValidationResult(ok: true);
}

/// Validates and sanitizes [ProductionReviewStatusEnvelope] updates (dry-run safe).
class ProductionReviewStatusValidator {
  ProductionReviewStatusValidator._();

  static final _sensitiveKeyPattern = RegExp(
    r'^(token|apiKey|api_key|stackTrace|stack_trace|env|environment|secret|password)$',
    caseSensitive: false,
  );

  static final _windowsPathPattern = RegExp(
    r'^[A-Za-z]:\\|^\\\\',
  );

  /// Known forbidden productionStatus transitions (from → to).
  static const _forbiddenProductionTransitions = {
    'completed': {'draft', 'in_progress', 'prelaunch_review'},
    'registration_ready': {'draft', 'in_progress'},
    'failed': {'completed', 'registration_ready'},
  };

  /// Validates [incoming] against optional [stored] envelope.
  static ProductionReviewValidationResult validate({
    required ProductionReviewStatusEnvelope incoming,
    ProductionReviewStatusEnvelope? stored,
    Set<String> seenEventIds = const {},
  }) {
    if (incoming.schemaVersion != ProductionReviewStatusEnvelope.kSchemaVersion) {
      return const ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_SCHEMA_VERSION',
        message: '지원하지 않는 schemaVersion 입니다.',
      );
    }

    if (incoming.eventId.trim().isEmpty ||
        incoming.instructionId.trim().isEmpty) {
      return const ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_MISSING_IDS',
        message: 'eventId와 instructionId는 필수입니다.',
      );
    }

    if (seenEventIds.contains(incoming.eventId)) {
      return const ProductionReviewValidationResult(
        ok: true,
        duplicate: true,
        code: 'PRSE_DUPLICATE_EVENT',
        message: '이미 처리된 eventId 입니다.',
      );
    }

    final sensitive = _findSensitiveFields(incoming.toJson());
    if (sensitive.isNotEmpty) {
      return ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_SENSITIVE_FIELD',
        message: '민감 필드가 포함되어 있습니다.',
        strippedFields: sensitive,
      );
    }

    if (stored != null) {
      if (incoming.revisionRank < stored.revisionRank) {
        return const ProductionReviewValidationResult(
          ok: false,
          rejected: true,
          code: 'PRSE_REVISION_ROLLBACK',
          message: 'revision 롤백은 허용되지 않습니다.',
        );
      }

      if (incoming.isStaleVs(stored)) {
        return const ProductionReviewValidationResult(
          ok: false,
          rejected: true,
          code: 'PRSE_STALE_EVENT',
          message: '더 최신 상태가 이미 저장되어 있습니다.',
        );
      }

      final transitionError = _checkForbiddenTransition(stored, incoming);
      if (transitionError != null) return transitionError;
    }

    final consistencyError = _checkDecisionConsistency(incoming);
    if (consistencyError != null) return consistencyError;

    return ProductionReviewValidationResult.accepted;
  }

  /// Returns sanitized copy with sensitive leaf values removed.
  static ProductionReviewStatusEnvelope sanitize(
    ProductionReviewStatusEnvelope envelope,
  ) {
    final json = _stripSensitiveValues(envelope.toJson());
    return ProductionReviewStatusEnvelope.fromJson(json);
  }

  static ProductionReviewValidationResult? _checkDecisionConsistency(
    ProductionReviewStatusEnvelope e,
  ) {
    if (e.ownerReview.decision != 'changes_requested') return null;

    if (e.readiness.externalPublicationAllowed) {
      return const ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_CHANGES_EXTERNAL',
        message: 'changes_requested 상태에서는 externalPublicationAllowed가 true일 수 없습니다.',
      );
    }
    if (e.readiness.registrationEligible) {
      return const ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_CHANGES_REGISTRATION',
        message: 'changes_requested 상태에서는 registrationEligible이 true일 수 없습니다.',
      );
    }
    if (!e.ownerReview.step16Blocked) {
      return const ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_CHANGES_STEP16',
        message: 'changes_requested 상태에서는 step16Blocked가 true여야 합니다.',
      );
    }
    return null;
  }

  static ProductionReviewValidationResult? _checkForbiddenTransition(
    ProductionReviewStatusEnvelope stored,
    ProductionReviewStatusEnvelope incoming,
  ) {
    if (incoming.revisionRank > stored.revisionRank) return null;

    final from = stored.productionStatus.trim();
    final to = incoming.productionStatus.trim();
    if (from.isEmpty || to.isEmpty || from == to) return null;

    final forbidden = _forbiddenProductionTransitions[from];
    if (forbidden != null && forbidden.contains(to)) {
      return ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_FORBIDDEN_TRANSITION',
        message: 'productionStatus $from → $to 전환은 허용되지 않습니다.',
      );
    }

    if (stored.ownerReview.decision == 'approved' &&
        incoming.ownerReview.decision == 'pending' &&
        incoming.revisionRank == stored.revisionRank) {
      return const ProductionReviewValidationResult(
        ok: false,
        rejected: true,
        code: 'PRSE_OWNER_REOPEN',
        message: '승인된 revision을 pending으로 되돌릴 수 없습니다.',
      );
    }

    return null;
  }

  static List<String> _findSensitiveFields(Map<String, dynamic> json, [String prefix = '']) {
    final found = <String>[];
    for (final entry in json.entries) {
      final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (_sensitiveKeyPattern.hasMatch(entry.key)) {
        found.add(path);
        continue;
      }
      final value = entry.value;
      if (value is String) {
        if (_windowsPathPattern.hasMatch(value)) {
          found.add(path);
        }
        if (value.contains('stackTrace') || value.contains('apiKey')) {
          found.add(path);
        }
      } else if (value is Map) {
        found.addAll(
          _findSensitiveFields(Map<String, dynamic>.from(value), path),
        );
      }
    }
    return found;
  }

  static Map<String, dynamic> _stripSensitiveValues(Map<String, dynamic> json) {
    final out = <String, dynamic>{};
    for (final entry in json.entries) {
      if (_sensitiveKeyPattern.hasMatch(entry.key)) continue;
      final value = entry.value;
      if (value is Map) {
        out[entry.key] = _stripSensitiveValues(Map<String, dynamic>.from(value));
      } else if (value is String && _windowsPathPattern.hasMatch(value)) {
        continue;
      } else {
        out[entry.key] = value;
      }
    }
    return out;
  }
}
