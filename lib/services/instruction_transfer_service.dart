import 'instruction_transfer_stub.dart'
    if (dart.library.js_interop) 'instruction_transfer_web.dart'
    as impl;
import 'instruction_transfer_types.dart';

export 'instruction_transfer_core.dart';
export 'instruction_transfer_types.dart';

/// 소통24워크 Inbox 폴더 직접 전달 (웹: File System Access API).
/// 수동 다운로드는 [downloadJsonFile]만 사용한다.
class InstructionTransferService {
  InstructionTransferService();

  Future<FolderPermissionState> currentState() => impl.currentState();

  Future<FolderPermissionState> pickFolder() => impl.pickFolder();

  /// Inbox 직접 쓰기. 실패 시 다운로드로 대체하지 않는다.
  Future<TransferWriteResult> writeJsonFile({
    required String fileName,
    required String jsonText,
    String? instructionId,
    int? version,
    String? expectedChecksum,
  }) => impl.writeJsonFile(
    fileName: fileName,
    jsonText: jsonText,
    instructionId: instructionId,
    version: version,
    expectedChecksum: expectedChecksum,
  );

  /// 수동 가져오기용 브라우저 다운로드 전용.
  Future<TransferWriteResult> downloadJsonFile({
    required String fileName,
    required String jsonText,
  }) => impl.downloadJsonFile(fileName: fileName, jsonText: jsonText);

  Future<String?> readBackFile(String fileName) => impl.readBackFile(fileName);
}
