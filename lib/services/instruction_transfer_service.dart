import 'instruction_transfer_stub.dart'
    if (dart.library.js_interop) 'instruction_transfer_web.dart'
    as impl;
import 'instruction_transfer_types.dart';

export 'instruction_transfer_types.dart';

/// 소통24워크 Inbox 폴더 전달 (웹: File System Access API / 대체 다운로드).
class InstructionTransferService {
  InstructionTransferService();

  Future<FolderPermissionState> currentState() => impl.currentState();

  Future<FolderPermissionState> pickFolder() => impl.pickFolder();

  Future<TransferWriteResult> writeJsonFile({
    required String fileName,
    required String jsonText,
  }) => impl.writeJsonFile(fileName: fileName, jsonText: jsonText);

  Future<String?> readBackFile(String fileName) => impl.readBackFile(fileName);
}
