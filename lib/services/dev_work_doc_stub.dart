import 'dev_work_doc_paths.dart';
import 'dev_work_doc_types.dart';

Future<DevWorkDocState> currentState() async {
  return const DevWorkDocState(supported: false, hasRoot: false);
}

Future<DevWorkDocState> pickRootFolder() async {
  return const DevWorkDocState(supported: false, hasRoot: false);
}

Future<DevWorkDocWriteResult> ensureStructure() async {
  return const DevWorkDocWriteResult(
    ok: false,
    mode: 'failed',
    message: '이 환경에서는 DevWorkDoc 폴더 구조를 만들 수 없습니다.',
    errorCode: 'unsupported',
  );
}

Future<DevWorkDocWriteResult> downloadInstructionJson({
  required String artifactType,
  required String instructionId,
  required int version,
  required String jsonText,
}) async {
  final fileName =
      '${DevWorkDocPaths.wiBaseName(instructionId)}_v$version.json';
  return DevWorkDocWriteResult(
    ok: true,
    mode: 'download',
    fileName: fileName,
    activePathHint: DevWorkDocPaths.activeRelative(artifactType, instructionId),
    versionPathHint: DevWorkDocPaths.versionRelative(
      artifactType,
      instructionId,
      version,
    ),
    message:
        '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님). '
        '폴더에 배치하려면 DevWorkDoc에 저장을 사용하세요.',
    errorCode: 'download_only',
  );
}

Future<DevWorkDocWriteResult> saveInstruction({
  required String artifactType,
  required String instructionId,
  required int version,
  required String jsonText,
  bool isNewVersion = false,
}) async {
  final fileName =
      '${DevWorkDocPaths.wiBaseName(instructionId)}_v$version.json';
  return DevWorkDocWriteResult(
    ok: true,
    mode: 'download',
    fileName: fileName,
    activePathHint: DevWorkDocPaths.activeRelative(artifactType, instructionId),
    versionPathHint: DevWorkDocPaths.versionRelative(
      artifactType,
      instructionId,
      version,
    ),
    message:
        '이 환경에서는 폴더 직접 저장을 지원하지 않습니다. '
        'JSON 다운로드로 대체합니다. DevWorkDoc 폴더에 수동으로 배치하세요.',
    errorCode: 'unsupported',
  );
}

Future<String?> readActive(String artifactType, String instructionId) async =>
    null;

Future<DevWorkDocWriteResult> archiveInstruction({
  required String artifactType,
  required String instructionId,
  required int version,
}) async {
  return const DevWorkDocWriteResult(
    ok: false,
    mode: 'failed',
    message: '이 환경에서는 보관 작업을 지원하지 않습니다.',
    errorCode: 'unsupported',
  );
}

Future<DevWorkDocWriteResult> restoreInstruction({
  required String artifactType,
  required String instructionId,
}) async {
  return const DevWorkDocWriteResult(
    ok: false,
    mode: 'failed',
    message: '이 환경에서는 복원 작업을 지원하지 않습니다.',
    errorCode: 'unsupported',
  );
}

Future<DevWorkDocWriteResult> permanentDelete({
  required String artifactType,
  required String instructionId,
}) async {
  return const DevWorkDocWriteResult(
    ok: false,
    mode: 'failed',
    message: '이 환경에서는 삭제 작업을 지원하지 않습니다.',
    errorCode: 'unsupported',
  );
}
