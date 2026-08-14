import '../models/business_planning.dart';
import 'plan_progress_status.dart';

/// 제작소 메인에 노출하는 사용자용 기획 상태 (내부 전달 구현 세부 제외).
class PlanUserFacingStatus {
  PlanUserFacingStatus._();

  static const planning = '기획중';
  static const instructionReady = '작업지시 준비';
  static const delivered = '전달완료';
  static const working = '작업중';
  static const awaitingApproval = '승인대기';
  static const completed = '완료';
  static const deferred = '보류';
  static const archived = '보관';
  static const cleanup = '정리대상';

  /// 보호할 운영 작업지시 (절대 정리/훼손 대상에서 제외).
  static const protectedInstructionIds = <String>{'wi_plan_1785905165067'};

  static bool isProtectedInstruction(String? instructionId) {
    final id = (instructionId ?? '').trim();
    return id.isNotEmpty && protectedInstructionIds.contains(id);
  }

  static String label(BusinessPlanDocument plan) {
    if (plan.isLibraryTrashed) return cleanup;
    if (plan.tags.contains('정리대상') || plan.tags.contains('cleanup')) {
      return cleanup;
    }
    if (plan.isLibraryArchived ||
        PlanningStatus.normalize(plan.status) == PlanningStatus.archived) {
      return archived;
    }
    // Explicit user tags (must remain reachable via label()).
    if (plan.tags.contains('보류') ||
        plan.tags.contains('deferred') ||
        plan.tags.contains('hold')) {
      return deferred;
    }
    // Analysis verdict hold → 보류 (제품 분석 경로; 별도 UI 토글 없음).
    if (plan.analysis?.verdict == PlanningVerdict.hold) {
      return deferred;
    }
    if (plan.tags.contains('승인대기') ||
        plan.tags.contains('awaiting_approval')) {
      return awaitingApproval;
    }

    final s = PlanningStatus.normalize(plan.status);
    switch (s) {
      case PlanningStatus.draft:
        return planning;
      case PlanningStatus.validationRequired:
        // 「승인대기」필터와 동일하게 노출
        return awaitingApproval;
      case PlanningStatus.instructionReady:
      case PlanningStatus.readyToTransfer:
      case PlanningStatus.downloadedPendingImport:
        // JSON 다운로드·Inbox 미전달 등 내부 상태는 「작업지시 준비」로 통합
        return instructionReady;
      case PlanningStatus.transferred:
      case PlanningStatus.imported:
        return delivered;
      case PlanningStatus.inProgress:
        return working;
      case PlanningStatus.completed:
        return completed;
      default:
        return planning;
    }
  }

  /// 자동 보관이 위험한 운영 진행 상태 (작업중/승인대기/전달완료 등).
  static bool isOperationallyProtected(BusinessPlanDocument plan) {
    if (isProtectedInstruction(plan.stableInstructionId)) return true;
    if (plan.isProtected) return true;
    final facing = label(plan);
    if (facing == working ||
        facing == awaitingApproval ||
        facing == delivered) {
      return true;
    }
    final s = PlanningStatus.normalize(plan.status);
    return s == PlanningStatus.inProgress ||
        s == PlanningStatus.transferred ||
        s == PlanningStatus.imported ||
        s == PlanningStatus.validationRequired;
  }

  /// 상단 기본 필터 id.
  static const primaryFilters = <String>[
    'all',
    'active',
    'waiting',
    'completed',
    'archived',
  ];

  static String primaryFilterLabel(String id) {
    switch (id) {
      case 'all':
        return '현재';
      case 'active':
        return '진행중';
      case 'waiting':
        return '승인대기';
      case 'completed':
        return '완료';
      case 'archived':
        return '보관';
      default:
        return id;
    }
  }

  /// 상세/관리 필터 id.
  static const advancedFilters = <String>[
    'instruction_created',
    'transferred',
    'trashed',
    'duplicate_candidates',
    'stale',
    'cleanup',
    'ebook',
    'app',
    'contents',
    'site',
    'promo_site',
    'favorite',
  ];

  static String advancedFilterLabel(String id) {
    switch (id) {
      case 'instruction_created':
        return '작업지시 준비';
      case 'transferred':
        return '전달완료';
      case 'trashed':
        return '휴지통';
      case 'duplicate_candidates':
        return '유사/중복 후보';
      case 'stale':
        return '오래된 항목';
      case 'cleanup':
        return '정리대상';
      case 'ebook':
        return '전자책';
      case 'app':
        return '앱';
      case 'contents':
        return '콘텐츠';
      case 'site':
        return '지식사이트';
      case 'promo_site':
        return '홍보사이트';
      case 'favorite':
        return '즐겨찾기';
      default:
        return id;
    }
  }

  /// 진단용 — 메인 카드에는 쓰지 않음.
  static String diagnosticTransferLine(BusinessPlanDocument plan) {
    final view = PlanProgressStatus.resolve(plan);
    return view.transferLine;
  }
}
