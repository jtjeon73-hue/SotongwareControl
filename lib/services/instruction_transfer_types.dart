/// 소통24워크 Inbox 전달 상태·결과 유형.
library;

/// Inbox 폴더 선택·권한·전달 준비 상태.
class FolderPermissionState {
  const FolderPermissionState({
    required this.supported,
    required this.hasHandle,
    this.folderName,
    this.permissionGranted = false,
    this.readyToWrite = false,
    this.statusMessage = '',
    this.needsReselect = false,
  });

  final bool supported;
  final bool hasHandle;
  final String? folderName;

  /// queryPermission / requestPermission 결과.
  final bool permissionGranted;

  /// 핸들 존재 + 쓰기 권한 허용 (직접 전달 가능).
  final bool readyToWrite;

  /// 화면에 표시할 준비 상태 설명.
  final String statusMessage;

  /// 핸들 없음·권한 만료 등으로 다시 선택이 필요함.
  final bool needsReselect;
}

/// 전달 결과 세부 분류.
enum TransferOutcome {
  /// Inbox에 직접 쓰기·재검증 성공.
  transferred,

  /// 동일 instructionId·version·핵심 checksum 파일이 이미 있음.
  alreadyExists,

  /// 동일 버전이지만 핵심 내용이 달라 덮어쓰지 않음.
  conflict,

  /// 브라우저 다운로드만 (직접 전달 아님).
  downloadOnly,

  /// 직접 전달 실패 (다운로드로 대체하지 않음).
  failed,
}

class TransferWriteResult {
  const TransferWriteResult({
    required this.ok,
    required this.mode,
    required this.outcome,
    this.fileName,
    this.message,
    this.errorCode,
    this.checksum,
    this.instructionId,
    this.version,
    this.verified = false,
    this.bytes = 0,
    this.conflictDiffSummary,
    this.pathId,
    this.folderName,
    this.downloadCallsDuringTransfer = 0,
  });

  /// folder | download | failed
  final String mode;

  /// 직접 Inbox 쓰기 성공(또는 기존 파일 확인)일 때만 true.
  /// 다운로드·실패는 false.
  final bool ok;
  final TransferOutcome outcome;
  final String? fileName;
  final String? message;
  final String? errorCode;
  final String? checksum;
  final String? instructionId;
  final int? version;
  final bool verified;
  final int bytes;
  final String? conflictDiffSummary;

  /// 예: inbox_fsa_typed_v1
  final String? pathId;
  final String? folderName;
  final int downloadCallsDuringTransfer;

  bool get isFolderSuccess =>
      ok &&
      mode == 'folder' &&
      (outcome == TransferOutcome.transferred ||
          outcome == TransferOutcome.alreadyExists);

  factory TransferWriteResult.failed({
    required String message,
    String? errorCode,
    String? fileName,
    String mode = 'failed',
  }) {
    return TransferWriteResult(
      ok: false,
      mode: mode,
      outcome: TransferOutcome.failed,
      fileName: fileName,
      message: message,
      errorCode: errorCode,
    );
  }

  factory TransferWriteResult.downloadOnly({
    required String fileName,
    String? message,
    String? checksum,
  }) {
    return TransferWriteResult(
      ok: false,
      mode: 'download',
      outcome: TransferOutcome.downloadOnly,
      fileName: fileName,
      checksum: checksum,
      message: message ?? 'JSON 다운로드 완료 · 수동 가져오기 대기',
      pathId: 'browser_download',
    );
  }
}
