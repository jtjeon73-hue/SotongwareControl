import '../models/business_planning.dart';
import 'plan_execution_status.dart';

/// 제작소 메인에 노출하는 사용자용 기획/실행 상태.
class PlanUserFacingStatus {
  PlanUserFacingStatus._();

  static const planning = '기획중';
  static const instructionDesign = '작업지시 제작중';
  static const instructionReady = '작업지시 준비완료';
  static const transferPending = '전달대기';
  static const deliveredNotRun = '전달됨 · 미실행';
  static const pcReceivedNotStarted = 'PC 수신 · 미시작';
  static const working = '작업중';
  static const awaitingApproval = '승인대기';
  static const revisionRequested = '보완요청';
  static const reworking = '재작업중';
  static const completed = '완료';
  static const deferred = '보류';
  static const archived = '보관';
  static const cleanup = '정리대상';
  static const error = '오류';
  static const stopped = '중지';

  /// 운영 작업지시 — 실제 실행 증거 있을 때 강한 보호.
  static const protectedInstructionIds = <String>{'wi_plan_1785905165067'};

  static bool isProtectedInstruction(String? instructionId) {
    final id = (instructionId ?? '').trim();
    return id.isNotEmpty && protectedInstructionIds.contains(id);
  }

  /// 카드 배지 — [execution] 있으면 전달 후 실행 상태 우선.
  static String label(
    BusinessPlanDocument plan, {
    PlanExecutionSnapshot? execution,
  }) {
    if (plan.isLibraryTrashed) return cleanup;
    if (plan.tags.contains('정리대상') || plan.tags.contains('cleanup')) {
      return cleanup;
    }
    if (plan.isLibraryArchived ||
        PlanningStatus.normalize(plan.status) == PlanningStatus.archived) {
      return archived;
    }

    final exec = execution ?? PlanExecutionStatusResolver.resolve(plan);

    if (exec.isPostTransfer) {
      return exec.primaryStatusLabel;
    }

    // --- 전달 전: 기획/작업지시 제작 상태만 ---
    if (plan.tags.contains('보류') ||
        plan.tags.contains('deferred') ||
        plan.tags.contains('hold')) {
      return deferred;
    }
    if (plan.analysis?.verdict == PlanningVerdict.hold) {
      return deferred;
    }

    if (!plan.hasInstruction) {
      if (exec.instructionDesignStep < exec.instructionDesignTotal) {
        return instructionDesign;
      }
      return planning;
    }

    final s = PlanningStatus.normalize(plan.status);
    if (s == PlanningStatus.readyToTransfer ||
        s == PlanningStatus.downloadedPendingImport) {
      return transferPending;
    }
    if (s == PlanningStatus.instructionReady ||
        s == PlanningStatus.validationRequired) {
      return instructionReady;
    }
    return planning;
  }

  /// 일괄 보관/삭제 보호 — transferred 단독으로는 보호하지 않는다.
  static bool isOperationallyProtected(
    BusinessPlanDocument plan, {
    PlanExecutionSnapshot? execution,
  }) {
    if (plan.isProtected) return true;

    final exec = execution ?? PlanExecutionStatusResolver.resolve(plan);

    if (isProtectedInstruction(plan.stableInstructionId)) {
      return exec.hasActualExecution;
    }

    if (!exec.isPostTransfer) return false;

    if (exec.isDeliveredOnly) return false;

    return exec.hasActualExecution &&
        (exec.isActivelyRunning ||
            exec.isAwaitingApproval ||
            exec.runState == PlanRunState.completed ||
            exec.runState == PlanRunState.revisionRequested);
  }

  /// 상단 기본 필터 id.
  static const primaryFilters = <String>[
    'all',
    'not_delivered',
    'working',
    'waiting',
    'completed',
    'archived',
  ];

  static String primaryFilterLabel(String id) {
    switch (id) {
      case 'all':
        return '현재';
      case 'not_delivered':
        return '미전달';
      case 'working':
        return '작업중';
      case 'waiting':
        return '승인대기';
      case 'completed':
        return '완료';
      case 'archived':
        return '보관';
      case 'active':
        return '진행중';
      default:
        return id;
    }
  }

  /// 상세/관리 필터 id.
  static const advancedFilters = <String>[
    'instruction_created',
    'delivered_not_run',
    'pc_not_received',
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
      case 'delivered_not_run':
        return '전달됨·미실행';
      case 'pc_not_received':
        return 'PC 미수신';
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

  static String diagnosticTransferLine(BusinessPlanDocument plan) {
    final exec = PlanExecutionStatusResolver.resolve(plan);
    return exec.transferLine;
  }
}
