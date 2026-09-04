import 'package:sotong_ware_control/models/commercial/production_review_status_envelope.dart';

/// Test fixtures for production review status envelope contract tests.
class ProductionReviewFixtures {
  ProductionReviewFixtures._();

  static const appR1InstructionId = 'wi_test_cursor_app_step15_1788441053773';
  static const ebookInstructionId = 'wi_plan_ebook_r1_ok';
  static const siteInstructionId = 'wi_plan_site_r1_ok';
  static const contentInstructionId = 'wi_plan_content_r1_ok';

  static const liveApkSha256 =
      '6c151c739ca1fd9eb9ff7ac631396db677083004af48d67344c9785fa120c481';

  static Map<String, dynamic> _baseJson({
    required String eventId,
    required String instructionId,
    required String artifactType,
    String contentSubtype = '',
    String siteSubtype = '',
    String revision = 'R1',
    int sequence = 1,
    String emittedAt = '2026-09-04T04:00:00.000Z',
    Map<String, dynamic>? ownerReview,
    Map<String, dynamic>? readiness,
    Map<String, dynamic>? technicalValidation,
    String userLabelKo = '',
    String nextActionKo = '',
    String productionStatus = 'prelaunch_review',
  }) {
    return {
      'schemaVersion': 1,
      'eventId': eventId,
      'instructionId': instructionId,
      'projectId': 'proj_$instructionId',
      'jobId': 'job_$instructionId',
      'artifactType': artifactType,
      'contentSubtype': contentSubtype,
      'siteSubtype': siteSubtype,
      'displayTitle': _titleFor(artifactType, instructionId),
      'revision': revision,
      'sourceRevision': revision == 'R1' ? '' : 'R1',
      'stageId': _stageFor(artifactType),
      'stageOrder': 15,
      'stageStatus': 'awaiting_owner_review',
      'verifiedThroughStep': 15,
      'lastVerifiedStage': 'owner_review',
      'productionStatus': productionStatus,
      'updatedAt': emittedAt,
      'emittedAt': emittedAt,
      'sequence': sequence,
      'technicalValidation': technicalValidation ??
          {
            'status': 'passed',
            'completed': true,
            'validatorResult': 'pass',
            'artifactKind': artifactType,
            'artifactSha256': 'a' * 64,
            'completedAt': emittedAt,
          },
      'ownerReview': ownerReview ??
          {
            'decision': 'pending',
            'revision': revision,
            'step16Blocked': false,
            'nextAllowedAction': 'owner_review',
            'findingCount': 0,
            'blockerCount': 0,
            'highCount': 0,
            'decisionRef': '',
            'reviewedAt': '',
          },
      'execution': {
        'agentState': 'waiting_approval',
        'currentJobId': 'job_$instructionId',
        'paused': false,
        'recoveryState': '',
        'permitState': 'owner_review',
        'worker': 'cursor',
        'heartbeatAt': emittedAt,
        'terminalBlockCount': 0,
      },
      'readiness': readiness ??
          {
            'technicalValidationCompleted': true,
            'ownerReviewRequired': true,
            'revisionRequired': false,
            'revisionReady': false,
            'registrationEligible': false,
            'externalPublicationAllowed': false,
          },
      'problem': {
        'code': '',
        'severity': '',
        'userSummary': '',
        'recommendedActions': [],
        'occurredAt': '',
      },
      'userLabelKo': userLabelKo,
      'nextActionKo': nextActionKo,
      'initialSync': false,
      'syncKind': '',
      'contentFingerprint': '',
    };
  }

  /// App R1 with technical validation passed and owner changes_requested.
  /// Aligned with live Work baseline (farm_safety_check / STEP15).
  static ProductionReviewStatusEnvelope appR1ChangesRequested() {
    return ProductionReviewStatusEnvelope.fromJson(appR1LiveAlignedJson());
  }

  /// Same shape as Work `scripts/fixtures/production_review_status/app_r1_changes_requested.json`.
  static Map<String, dynamic> appR1LiveAlignedJson() {
    return {
      'schemaVersion': 1,
      'eventId':
          'prse_wi_test_cursor_app_step15_1788441053773_R1_app_device_review_prep',
      'instructionId': appR1InstructionId,
      'projectId': 'farm_safety_check',
      'jobId': '',
      'artifactType': 'app',
      'contentSubtype': '',
      'siteSubtype': '',
      'displayTitle': '농작업 안전 점검',
      'revision': 'R1',
      'sourceRevision': '',
      'stageId': 'app_device_review_prep',
      'stageOrder': 15,
      'stageStatus': 'completed',
      'verifiedThroughStep': 15,
      'lastVerifiedStage': 'app_device_review_prep',
      'productionStatus':
          'technical_validation_completed_owner_changes_requested',
      'updatedAt': '2026-09-04T12:00:00.000Z',
      'emittedAt': '2026-09-04T12:00:00.000Z',
      'sequence': 15,
      'technicalValidation': {
        'status': 'completed',
        'completed': true,
        'validatorResult': 'pass',
        'artifactKind': 'apk',
        'artifactSha256': liveApkSha256,
        'completedAt': '2026-09-04T08:00:00+09:00',
      },
      'ownerReview': {
        'decision': 'changes_requested',
        'revision': 'R1',
        'step16Blocked': true,
        'nextAllowedAction': 'R2 revision only',
        'findingCount': 11,
        'blockerCount': 0,
        'highCount': 5,
        'decisionRef': 'owner_review_decisions/R1_changes_requested.json',
        'reviewedAt': '2026-09-04T08:00:00+09:00',
      },
      'execution': {
        'agentState': 'paused',
        'currentJobId': '',
        'paused': true,
        'recoveryState': 'test_completed_preserved',
        'permitState': 'none',
        'worker': 'cursor',
        'heartbeatAt': '2026-09-04T08:00:00+09:00',
        'terminalBlockCount': 3,
      },
      'readiness': {
        'technicalValidationCompleted': true,
        'ownerReviewRequired': false,
        'revisionRequired': true,
        'revisionReady': true,
        'registrationEligible': false,
        'externalPublicationAllowed': false,
      },
      'problem': {
        'code': '',
        'severity': '',
        'userSummary': '',
        'recommendedActions': const <String>[],
        'occurredAt': '',
      },
      'userLabelKo': '기술검증 완료 · 사용자 보완요청 · R2 준비 대기',
      'nextActionKo': '보완 내용을 확인하고 R2 작업지시 초안을 준비하세요 (자동 전송 없음)',
      'initialSync': false,
      'syncKind': 'transition',
      'contentFingerprint':
          'fp_wi_test_cursor_app_step15_1788441053773_R1_changes_requested',
    };
  }

  static ProductionReviewStatusEnvelope ebookR1Approved() {
    return ProductionReviewStatusEnvelope.fromJson(
      _baseJson(
        eventId: 'prse_ebook_r1_001',
        instructionId: ebookInstructionId,
        artifactType: 'ebook',
        ownerReview: {
          'decision': 'approved',
          'revision': 'R1',
          'step16Blocked': false,
          'nextAllowedAction': 'registration',
          'findingCount': 0,
          'blockerCount': 0,
          'highCount': 0,
          'decisionRef': 'dec_ebook_r1',
          'reviewedAt': '2026-09-04T04:00:00.000Z',
        },
        readiness: {
          'technicalValidationCompleted': true,
          'ownerReviewRequired': false,
          'revisionRequired': false,
          'revisionReady': false,
          'registrationEligible': true,
          'externalPublicationAllowed': false,
        },
        userLabelKo: '기술검증 완료 · 승인 · R1',
        nextActionKo: '등록(16단계)을 진행할 수 있습니다.',
        productionStatus: 'registration_ready',
      ),
    );
  }

  static ProductionReviewStatusEnvelope siteR1Pending() {
    return ProductionReviewStatusEnvelope.fromJson(
      _baseJson(
        eventId: 'prse_site_r1_001',
        instructionId: siteInstructionId,
        artifactType: 'site',
        siteSubtype: 'marketing_site',
        ownerReview: {
          'decision': 'pending',
          'revision': 'R1',
          'step16Blocked': false,
          'nextAllowedAction': 'owner_review',
          'findingCount': 0,
          'blockerCount': 0,
          'highCount': 0,
          'decisionRef': '',
          'reviewedAt': '',
        },
        userLabelKo: '기술검증 완료 · 소유자 검토 대기',
        nextActionKo: '소유자 검토를 진행하세요.',
      ),
    );
  }

  static ProductionReviewStatusEnvelope contentR1Pending() {
    return ProductionReviewStatusEnvelope.fromJson(
      _baseJson(
        eventId: 'prse_content_r1_001',
        instructionId: contentInstructionId,
        artifactType: 'contents',
        contentSubtype: 'shorts_video',
        ownerReview: {
          'decision': 'pending',
          'revision': 'R1',
          'step16Blocked': false,
          'nextAllowedAction': 'owner_review',
          'findingCount': 0,
          'blockerCount': 0,
          'highCount': 0,
          'decisionRef': '',
          'reviewedAt': '',
        },
        userLabelKo: '기술검증 완료 · 소유자 검토 대기',
      ),
    );
  }

  static ProductionReviewStatusEnvelope staleAppR1() {
    return appR1ChangesRequested().copyWith(
      eventId: 'prse_app_r1_stale',
      sequence: 5,
      emittedAt: '2026-09-04T03:00:00.000Z',
    );
  }

  static ProductionReviewStatusEnvelope duplicateAppR1() {
    return appR1ChangesRequested();
  }

  static ProductionReviewStatusEnvelope malformedMissingIds() {
    return ProductionReviewStatusEnvelope.fromJson({
      'schemaVersion': 1,
      'eventId': '',
      'instructionId': '',
    });
  }

  static ProductionReviewStatusEnvelope malformedBadSchema() {
    return ProductionReviewStatusEnvelope.fromJson({
      'schemaVersion': 99,
      'eventId': 'prse_bad',
      'instructionId': 'wi_bad',
    });
  }

  static ProductionReviewStatusEnvelope malformedSensitivePath() {
    final json = _baseJson(
      eventId: 'prse_sensitive',
      instructionId: 'wi_sensitive',
      artifactType: 'app',
      technicalValidation: {
        'status': 'passed',
        'completed': true,
        'validatorResult': 'C:\\Users\\secret\\project\\build.log',
        'artifactKind': 'app',
        'artifactSha256': 'a' * 64,
        'completedAt': '2026-09-04T04:00:00.000Z',
      },
    );
    return ProductionReviewStatusEnvelope.fromJson(json);
  }

  static ProductionReviewStatusEnvelope revisionRollbackR1() {
    return appR1ChangesRequested().copyWith(
      eventId: 'prse_rollback',
      revision: 'R0',
      sequence: 20,
      emittedAt: '2026-09-04T05:00:00.000Z',
    );
  }

  static String _titleFor(String artifactType, String id) {
    switch (artifactType) {
      case 'app':
        return '농작업 안전 점검 앱';
      case 'ebook':
        return '일상 AI 활용 입문';
      case 'site':
        return '마케팅 랜딩 사이트';
      case 'contents':
        return '숏폼 홍보 영상';
      default:
        return id;
    }
  }

  static String _stageFor(String artifactType) {
    switch (artifactType) {
      case 'app':
        return 'app_android_release';
      case 'site':
        return 'site_production_complete';
      case 'contents':
        return 'content_production_complete';
      default:
        return 'ebook_production_complete';
    }
  }
}
