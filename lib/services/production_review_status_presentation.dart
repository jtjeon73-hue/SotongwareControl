import '../models/commercial/production_review_status_envelope.dart';

/// User-facing presentation for production review status (Korean labels).
class ProductionReviewStatusPresentation {
  ProductionReviewStatusPresentation._();

  static List<String> dashboardSummary(ProductionReviewStatusEnvelope e) {
    final lines = <String>[
      e.displayTitle.isNotEmpty ? e.displayTitle : e.instructionId,
      if (e.revision.isNotEmpty) '차수: ${e.revision}',
      e.userLabelKo.isNotEmpty ? e.userLabelKo : _defaultUserLabel(e),
    ];
    if (e.nextActionKo.isNotEmpty) {
      lines.add('다음: ${e.nextActionKo}');
    }
    lines.add(_techLine(e));
    lines.add(_ownerLine(e));
    return lines.where((l) => l.trim().isNotEmpty).toList();
  }

  static List<String> workshopCardLines(ProductionReviewStatusEnvelope e) {
    return [
      e.userLabelKo.isNotEmpty ? e.userLabelKo : _defaultUserLabel(e),
      _techLine(e),
      _ownerLine(e),
      if (e.readiness.revisionRequired) '보완 차수(R2) 준비가 필요합니다.',
      if (e.nextActionKo.isNotEmpty) e.nextActionKo,
    ].where((l) => l.trim().isNotEmpty).toList();
  }

  static List<String> recommendedActions(ProductionReviewStatusEnvelope e) {
    if (e.problem.recommendedActions.isNotEmpty) {
      return List<String>.from(e.problem.recommendedActions);
    }
    switch (e.ownerReview.decision) {
      case 'changes_requested':
        return const [
          '보완 요청 항목을 확인하세요.',
          'R2 초안을 준비하세요 (자동 전송되지 않습니다).',
          '16단계 등록은 보완 완료 후 진행하세요.',
        ];
      case 'pending':
        return const [
          '기술검증 결과를 확인하세요.',
          '소유자 검토를 진행하세요.',
        ];
      case 'approved':
        if (e.readiness.registrationEligible) {
          return const ['등록(16단계)을 진행할 수 있습니다.'];
        }
        return const ['승인된 결과를 확인하세요.'];
    }
    if (e.productionStatus == 'failed') {
      return const ['오류 원인을 확인하고 복구 조치를 검토하세요.'];
    }
    if (e.readiness.revisionReady) {
      return const ['R2 보완 결과를 검토하세요.'];
    }
    return const ['현재 상태를 확인하세요.'];
  }

  static List<String> r2DraftHints(ProductionReviewStatusEnvelope e) {
    if (!e.readiness.revisionRequired) return const [];
    return [
      '보완 요청(${e.ownerReview.findingCount}건)은 R2 초안에 반영해야 합니다.',
      '요청된 변경은 자동 전송되지 않습니다 — 준비 후 수동으로 진행하세요.',
      if (e.ownerReview.nextAllowedAction.isNotEmpty)
        '허용된 다음 작업: ${e.ownerReview.nextAllowedAction}',
      '차단: ${e.ownerReview.blockerCount} · 높음: ${e.ownerReview.highCount}',
    ];
  }

  static String _defaultUserLabel(ProductionReviewStatusEnvelope e) {
    if (e.ownerReview.decision == 'changes_requested') {
      return '기술검증 완료 · 보완요청 · ${e.revision.isNotEmpty ? e.revision : 'R1'}';
    }
    if (e.readiness.technicalValidationCompleted &&
        e.ownerReview.decision == 'pending') {
      return '기술검증 완료 · 소유자 검토 대기';
    }
    return e.productionStatus.isNotEmpty ? e.productionStatus : '상태 확인 필요';
  }

  static String _techLine(ProductionReviewStatusEnvelope e) {
    final tv = e.technicalValidation;
    if (tv.completed) {
      return '기술검증: 완료${tv.validatorResult.isNotEmpty ? ' (${tv.validatorResult})' : ''}';
    }
    return tv.status.isNotEmpty ? '기술검증: ${tv.status}' : '기술검증: 대기';
  }

  static String _ownerLine(ProductionReviewStatusEnvelope e) {
    switch (e.ownerReview.decision) {
      case 'approved':
        return '소유자 검토: 승인';
      case 'changes_requested':
        return '소유자 검토: 보완요청 (${e.ownerReview.findingCount}건)';
      case 'pending':
        return '소유자 검토: 대기';
      default:
        return e.ownerReview.decision.isNotEmpty
            ? '소유자 검토: ${e.ownerReview.decision}'
            : '소유자 검토: —';
    }
  }
}
