import 'instruction_transfer_types.dart';

Future<FolderPermissionState> currentState() async {
  return const FolderPermissionState(supported: false, hasHandle: false);
}

Future<FolderPermissionState> pickFolder() async {
  return const FolderPermissionState(supported: false, hasHandle: false);
}

Future<TransferWriteResult> writeJsonFile({
  required String fileName,
  required String jsonText,
}) async {
  return TransferWriteResult(
    ok: true,
    mode: 'download',
    fileName: fileName,
    message:
        '이 환경에서는 폴더 직접 저장을 지원하지 않습니다. JSON 다운로드로 대체합니다. '
        r'파일을 Documents\Sotong24Work\Instructions\Inbox 로 옮기세요.',
    errorCode: 'unsupported',
  );
}

Future<String?> readBackFile(String fileName) async => null;
