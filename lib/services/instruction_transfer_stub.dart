import 'instruction_content_checksum.dart';
import 'instruction_transfer_core.dart';
import 'instruction_transfer_types.dart';

Future<FolderPermissionState> currentState() async {
  return buildInboxFolderState(
    supported: false,
    hasHandle: false,
    permissionGranted: false,
  );
}

Future<FolderPermissionState> pickFolder() async {
  return buildInboxFolderState(
    supported: false,
    hasHandle: false,
    permissionGranted: false,
  );
}

/// Inbox 직접 전달 — stub에서는 실패만 반환 (다운로드 대체 금지).
Future<TransferWriteResult> writeJsonFile({
  required String fileName,
  required String jsonText,
  String? instructionId,
  int? version,
  String? expectedChecksum,
}) async {
  return TransferWriteResult.failed(
    message:
        '이 환경에서는 폴더 직접 저장을 지원하지 않습니다.\n'
        '다음 행동: 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
    errorCode: 'unsupported',
    fileName: fileName,
  );
}

/// 수동 다운로드만 기록 (실제 브라우저 다운로드는 웹 전용).
Future<TransferWriteResult> downloadJsonFile({
  required String fileName,
  required String jsonText,
}) async {
  recordInstructionTransferManualDownloadCall();
  return TransferWriteResult.downloadOnly(
    fileName: fileName,
    checksum: stableContentChecksum(jsonText),
    message: 'JSON 다운로드 완료 · 수동 가져오기 대기',
  );
}

Future<String?> readBackFile(String fileName) async => null;
