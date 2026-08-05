/// 기획·작업지시·DevWorkDoc·소통24워크 전달 진행 상태 (단일 판정 소스).
library;

import '../models/business_planning.dart';

/// 사용자에게 보여줄 진행 단계 (거짓 없는 표시용).
class PlanProgressKind {
  static const planOnly = 'plan_only';
  static const instructionReady = 'instruction_ready';
  static const jsonDownloaded = 'json_downloaded';
  static const devWorkDocSaved = 'dev_work_doc_saved';
  static const transferFolderMissing = 'transfer_folder_missing';
  static const transferReady = 'transfer_ready';
  static const inboxTransferred = 'inbox_transferred';
  static const importPending = 'import_pending';
  static const imported = 'imported';
  static const archived = 'archived';
  static const failed = 'failed';
}

class PlanProgressView {
  const PlanProgressView({
    required this.kind,
    required this.badgeLabel,
    required this.statusLine,
    required this.transferLine,
    required this.devWorkDocLine,
    required this.nextAction,
    required this.isTrulyTransferred,
    this.failureReason,
  });

  final String kind;
  final String badgeLabel;
  final String statusLine;
  final String transferLine;
  final String devWorkDocLine;
  final String nextAction;
  final bool isTrulyTransferred;
  final String? failureReason;
}

/// Inbox 실제 쓰기 성공만 「전달됨」으로 본다.
class PlanProgressStatus {
  PlanProgressStatus._();

  static const folderMode = 'folder';
  static const downloadMode = 'download';

  /// 레거시 데이터 안전 재판정 (파괴적 삭제 없음, status만 교정).
  static BusinessPlanDocument reconcile(BusinessPlanDocument plan) {
    final status = PlanningStatus.normalize(plan.status);
    final mode = (plan.lastTransferMode ?? '').trim();

    // transferred 인데 폴더 쓰기 근거가 없으면 다운로드·가져오기 대기로 강등
    if (status == PlanningStatus.transferred && mode != folderMode) {
      return plan.copyWith(status: PlanningStatus.downloadedPendingImport);
    }

    // imported 는 유지
    if (status == PlanningStatus.imported) return plan;

    // lastTransferAt 만 있고 mode 가 download 인데 status 가 transferred 인 경우 위와 동일
    if (mode == downloadMode && status == PlanningStatus.transferred) {
      return plan.copyWith(status: PlanningStatus.downloadedPendingImport);
    }

    return plan;
  }

  static List<BusinessPlanDocument> reconcileAll(
    List<BusinessPlanDocument> plans,
  ) => plans.map(reconcile).toList();

  /// Inbox 폴더 쓰기 성공 여부 (배지 「전달됨」 전용).
  static bool isTrulyTransferred(BusinessPlanDocument plan) {
    final status = PlanningStatus.normalize(plan.status);
    if (status == PlanningStatus.imported) return true;
    if (status != PlanningStatus.transferred) return false;
    return (plan.lastTransferMode ?? '') == folderMode;
  }

  static bool isDownloadOnlyPending(BusinessPlanDocument plan) {
    final status = PlanningStatus.normalize(plan.status);
    final mode = plan.lastTransferMode ?? '';
    if (status == PlanningStatus.downloadedPendingImport) return true;
    if (mode == downloadMode && status != PlanningStatus.imported) {
      return true;
    }
    // 레거시: transferred + download mode (reconcile 전)
    if (status == PlanningStatus.transferred && mode != folderMode) {
      return true;
    }
    return false;
  }

  static PlanProgressView resolve(
    BusinessPlanDocument? plan, {
    bool hasDevWorkDocRoot = false,
    bool hasTransferFolder = false,
    String? lastDevWorkDocMode,
    String? failureReason,
  }) {
    if (failureReason != null && failureReason.isNotEmpty) {
      return PlanProgressView(
        kind: PlanProgressKind.failed,
        badgeLabel: '실패',
        statusLine: '실패',
        transferLine: '소통24워크에 아직 전달되지 않음',
        devWorkDocLine: '확인 필요',
        nextAction: failureReason,
        isTrulyTransferred: false,
        failureReason: failureReason,
      );
    }

    if (plan == null) {
      return const PlanProgressView(
        kind: PlanProgressKind.planOnly,
        badgeLabel: '기획안만',
        statusLine: '기획안만 저장됨',
        transferLine: '소통24워크에 아직 전달되지 않음',
        devWorkDocLine: '저장 전',
        nextAction: '기획안을 완성한 뒤 작업지시서를 생성하세요.',
        isTrulyTransferred: false,
      );
    }

    final reconciled = reconcile(plan);
    final status = PlanningStatus.normalize(reconciled.status);

    if (status == PlanningStatus.archived) {
      return const PlanProgressView(
        kind: PlanProgressKind.archived,
        badgeLabel: '보관됨',
        statusLine: '보관됨',
        transferLine: '보관됨',
        devWorkDocLine: '보관됨',
        nextAction: '필요하면 보관함에서 복원하세요.',
        isTrulyTransferred: false,
      );
    }

    if (status == PlanningStatus.imported) {
      return PlanProgressView(
        kind: PlanProgressKind.imported,
        badgeLabel: '가져오기 완료',
        statusLine: '소통24워크 가져오기 완료',
        transferLine: '소통24워크 가져오기 완료',
        devWorkDocLine: _devDocLine(lastDevWorkDocMode, hasDevWorkDocRoot),
        nextAction: '소통24워크에서 작업 진행을 확인하세요.',
        isTrulyTransferred: true,
      );
    }

    if (isTrulyTransferred(reconciled)) {
      return PlanProgressView(
        kind: PlanProgressKind.inboxTransferred,
        badgeLabel: '전달됨',
        statusLine: '소통24워크 Inbox에 전달 완료',
        transferLine: '소통24워크 Inbox에 실제 파일 쓰기 완료',
        devWorkDocLine: _devDocLine(lastDevWorkDocMode, hasDevWorkDocRoot),
        nextAction: '소통24워크에서 가져오기를 확인하세요.',
        isTrulyTransferred: true,
      );
    }

    if (isDownloadOnlyPending(reconciled)) {
      return PlanProgressView(
        kind: PlanProgressKind.jsonDownloaded,
        badgeLabel: 'JSON 다운로드 완료',
        statusLine: 'JSON 다운로드 완료 · 수동 가져오기 대기',
        transferLine: '소통24워크에 아직 전달되지 않음',
        devWorkDocLine: lastDevWorkDocMode == folderMode
            ? '로컬 DevWorkDoc 저장 완료'
            : 'DevWorkDoc 직접 저장 아님 (브라우저 다운로드)',
        nextAction: '전달 폴더를 선택하거나 소통24워크에서 다운로드 파일을 가져오세요.',
        isTrulyTransferred: false,
      );
    }

    if (!reconciled.hasInstruction) {
      return const PlanProgressView(
        kind: PlanProgressKind.planOnly,
        badgeLabel: '기획안만',
        statusLine: '기획안만 저장됨',
        transferLine: '소통24워크에 아직 전달되지 않음',
        devWorkDocLine: '작업지시서 미생성',
        nextAction: '작업지시서를 생성하세요.',
        isTrulyTransferred: false,
      );
    }

    // 지시서 있음
    final devLine = _devDocLine(lastDevWorkDocMode, hasDevWorkDocRoot);
    if (!hasTransferFolder) {
      return PlanProgressView(
        kind: PlanProgressKind.transferFolderMissing,
        badgeLabel: '지시서 v${reconciled.version}',
        statusLine: '작업지시서 생성됨 · 소통24워크 전달 폴더 미설정',
        transferLine: '소통24워크 전달 폴더 미설정',
        devWorkDocLine: devLine,
        nextAction: '소통24워크 전달 폴더(Inbox)를 설정한 뒤 전달하세요.',
        isTrulyTransferred: false,
      );
    }

    return PlanProgressView(
      kind: PlanProgressKind.transferReady,
      badgeLabel: '지시서 v${reconciled.version}',
      statusLine: '소통24워크 전달 준비 완료',
      transferLine: '소통24워크 전달 준비',
      devWorkDocLine: devLine,
      nextAction: '「소통24워크 Inbox로 전달」을 누르세요.',
      isTrulyTransferred: false,
    );
  }

  static String _devDocLine(String? lastMode, bool hasRoot) {
    if (lastMode == folderMode) {
      return '로컬 DevWorkDoc 저장 완료 (Active·Versions)';
    }
    if (lastMode == downloadMode) {
      return '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님)';
    }
    if (!hasRoot) return '저장 폴더 미설정';
    return '저장 준비 완료';
  }

  /// 전달 시도 결과에 따른 상태 문자열.
  static String statusAfterTransferAttempt({required String mode}) {
    if (mode == folderMode) return PlanningStatus.transferred;
    return PlanningStatus.downloadedPendingImport;
  }
}
