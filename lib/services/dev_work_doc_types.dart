/// DevWorkDoc 저장 결과·마이그레이션 판정 (폴더 성공 ≠ 다운로드).
library;

/// folder | download | failed
class DevWorkDocState {
  const DevWorkDocState({
    required this.supported,
    required this.hasRoot,
    this.rootFolderName,
    this.permissionGranted = false,
    this.selectionKind = DevWorkDocSelectionKind.none,
    this.structureOk = false,
    this.readyToWrite = false,
    this.statusMessage = '',
  });

  final bool supported;
  final bool hasRoot;
  final String? rootFolderName;
  final bool permissionGranted;
  final DevWorkDocSelectionKind selectionKind;
  final bool structureOk;
  final bool readyToWrite;
  final String statusMessage;
}

enum DevWorkDocSelectionKind {
  none,

  /// 사용자가 DevWorkDoc 루트를 직접 선택 (권장).
  devWorkDocRoot,

  /// 저장소 루트 등 — 하위에 DevWorkDoc 이 감지됨.
  repoRootWithDevWorkDoc,

  /// 구조가 애매함.
  ambiguous,
}

enum DevWorkDocSaveOutcome {
  /// Active + Versions 모두 쓰기·재읽기 검증 완료.
  completeSuccess,

  /// Active 또는 Versions 중 한쪽만 성공.
  partialSuccess,

  /// Versions 확인 후 Active 복구 완료.
  recoveredFromPartial,

  /// 동일 checksum 파일이 이미 존재.
  alreadyExists,

  /// 다른 내용의 파일이 있어 덮어쓰지 않음.
  conflict,

  /// 브라우저 다운로드만 (폴더 저장 아님).
  downloadOnly,

  /// 권한 재승인 필요.
  permissionNeeded,

  /// 유형 미선택 등.
  awaitingArtifact,
  failed,
}

class DevWorkDocWriteResult {
  const DevWorkDocWriteResult({
    required this.ok,
    required this.mode,
    required this.outcome,
    this.activePathHint,
    this.versionPathHint,
    this.message,
    this.errorCode,
    this.checksum,
    this.fileName,
    this.activeVerified = false,
    this.versionsVerified = false,
    this.activeBytes = 0,
    this.versionsBytes = 0,
    this.instructionId,
    this.version,
    this.operationId,
    this.conflictIsMetadataOnly = false,
    this.conflictDiffSummary,
  });

  /// folder | download | failed
  final String mode;

  /// 폴더 완전 성공일 때만 true. 다운로드·부분성공·실패는 false.
  final bool ok;
  final DevWorkDocSaveOutcome outcome;
  final String? activePathHint;
  final String? versionPathHint;
  final String? message;
  final String? errorCode;
  final String? checksum;
  final String? fileName;
  final bool activeVerified;
  final bool versionsVerified;
  final int activeBytes;
  final int versionsBytes;
  final String? instructionId;
  final int? version;
  final String? operationId;
  final bool conflictIsMetadataOnly;
  final String? conflictDiffSummary;

  bool get isFolderCompleteSuccess =>
      ok &&
      mode == 'folder' &&
      (outcome == DevWorkDocSaveOutcome.completeSuccess ||
          outcome == DevWorkDocSaveOutcome.recoveredFromPartial) &&
      activeVerified &&
      versionsVerified;

  factory DevWorkDocWriteResult.failed({
    required String message,
    String errorCode = 'failed',
    String? activePathHint,
    String? versionPathHint,
    DevWorkDocSaveOutcome outcome = DevWorkDocSaveOutcome.failed,
    String? instructionId,
    int? version,
    String? operationId,
    bool conflictIsMetadataOnly = false,
    String? conflictDiffSummary,
    String? checksum,
  }) => DevWorkDocWriteResult(
    ok: false,
    mode: 'failed',
    outcome: outcome,
    message: message,
    errorCode: errorCode,
    activePathHint: activePathHint,
    versionPathHint: versionPathHint,
    instructionId: instructionId,
    version: version,
    operationId: operationId,
    conflictIsMetadataOnly: conflictIsMetadataOnly,
    conflictDiffSummary: conflictDiffSummary,
    checksum: checksum,
  );

  factory DevWorkDocWriteResult.download({
    required String fileName,
    required String message,
    required String activePathHint,
    required String versionPathHint,
    String errorCode = 'download_only',
  }) => DevWorkDocWriteResult(
    ok: false,
    mode: 'download',
    outcome: DevWorkDocSaveOutcome.downloadOnly,
    fileName: fileName,
    message: message,
    errorCode: errorCode,
    activePathHint: activePathHint,
    versionPathHint: versionPathHint,
  );
}

class DevWorkDocMigrateItemResult {
  const DevWorkDocMigrateItemResult({
    required this.title,
    required this.instructionId,
    required this.artifactType,
    required this.outcome,
    required this.summary,
    this.activeResult = '',
    this.versionsResult = '',
    this.verifyResult = '',
    this.failureReason = '',
    this.nextAction = '',
  });

  final String title;
  final String instructionId;
  final String artifactType;
  final DevWorkDocSaveOutcome outcome;
  final String summary;
  final String activeResult;
  final String versionsResult;
  final String verifyResult;
  final String failureReason;
  final String nextAction;
}

class DevWorkDocMigrateReport {
  const DevWorkDocMigrateReport({required this.items});

  final List<DevWorkDocMigrateItemResult> items;

  int get completeSuccessCount => items
      .where((e) => e.outcome == DevWorkDocSaveOutcome.completeSuccess)
      .length;
  int get partialSuccessCount => items
      .where((e) => e.outcome == DevWorkDocSaveOutcome.partialSuccess)
      .length;
  int get alreadyExistsCount => items
      .where((e) => e.outcome == DevWorkDocSaveOutcome.alreadyExists)
      .length;
  int get awaitingCount => items
      .where((e) => e.outcome == DevWorkDocSaveOutcome.awaitingArtifact)
      .length;
  int get permissionCount => items
      .where((e) => e.outcome == DevWorkDocSaveOutcome.permissionNeeded)
      .length;
  int get failedCount =>
      items.where((e) => e.outcome == DevWorkDocSaveOutcome.failed).length;
  int get downloadOnlyCount => items
      .where((e) => e.outcome == DevWorkDocSaveOutcome.downloadOnly)
      .length;
  int get conflictCount =>
      items.where((e) => e.outcome == DevWorkDocSaveOutcome.conflict).length;
}
