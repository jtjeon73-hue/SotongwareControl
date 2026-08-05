import 'browser_json_download_service.dart';
import 'instruction_content_checksum.dart';
import 'instruction_transfer_core.dart';
import 'instruction_transfer_types.dart';

Future<FolderPermissionState> currentState() async {
  ensureBrowserJsonDownloadRegistered();
  return buildInboxFolderState(
    supported: false,
    hasHandle: false,
    permissionGranted: false,
  );
}

Future<FolderPermissionState> pickFolder() async {
  ensureBrowserJsonDownloadRegistered();
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
  ensureBrowserJsonDownloadRegistered();
  final before = browserJsonDownloadCallCount;
  final result = TransferWriteResult.failed(
    message:
        '이 환경에서는 폴더 직접 저장을 지원하지 않습니다.\n'
        '다음 행동: 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
    errorCode: 'unsupported',
    fileName: fileName,
  );
  if (browserJsonDownloadCallCount != before) {
    return TransferWriteResult.failed(
      message: '직접 전달 경로에서 다운로드가 감지되어 차단했습니다.',
      errorCode: 'download_guard',
      fileName: fileName,
    );
  }
  return result;
}

/// 수동 다운로드만 기록.
Future<TransferWriteResult> downloadJsonFile({
  required String fileName,
  required String jsonText,
}) async {
  ensureBrowserJsonDownloadRegistered();
  triggerBrowserJsonDownload(fileName: fileName, jsonText: jsonText);
  return TransferWriteResult.downloadOnly(
    fileName: fileName,
    checksum: stableContentChecksum(jsonText),
    message: 'JSON 다운로드 완료 · 수동 가져오기 대기',
  );
}

Future<String?> readBackFile(String fileName) async => null;
