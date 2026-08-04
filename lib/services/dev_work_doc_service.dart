import 'dev_work_doc_stub.dart'
    if (dart.library.js_interop) 'dev_work_doc_web.dart'
    as impl;
import 'dev_work_doc_types.dart';

export 'dev_work_doc_types.dart';

/// DevWorkDoc 로컬 JSON 실작업 저장 (웹: File System Access API / 대체 다운로드).
class DevWorkDocService {
  DevWorkDocService();

  Future<DevWorkDocState> currentState() => impl.currentState();

  Future<DevWorkDocState> pickRootFolder() => impl.pickRootFolder();

  Future<DevWorkDocWriteResult> ensureStructure() => impl.ensureStructure();

  Future<DevWorkDocWriteResult> saveInstruction({
    required String artifactType,
    required String instructionId,
    required int version,
    required String jsonText,
    bool isNewVersion = false,
  }) => impl.saveInstruction(
    artifactType: artifactType,
    instructionId: instructionId,
    version: version,
    jsonText: jsonText,
    isNewVersion: isNewVersion,
  );

  Future<String?> readActive(String artifactType, String instructionId) =>
      impl.readActive(artifactType, instructionId);

  Future<DevWorkDocWriteResult> archiveInstruction({
    required String artifactType,
    required String instructionId,
    required int version,
  }) => impl.archiveInstruction(
    artifactType: artifactType,
    instructionId: instructionId,
    version: version,
  );

  Future<DevWorkDocWriteResult> restoreInstruction({
    required String artifactType,
    required String instructionId,
  }) => impl.restoreInstruction(
    artifactType: artifactType,
    instructionId: instructionId,
  );

  Future<DevWorkDocWriteResult> permanentDelete({
    required String artifactType,
    required String instructionId,
  }) => impl.permanentDelete(
    artifactType: artifactType,
    instructionId: instructionId,
  );
}
