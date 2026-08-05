import 'dev_work_doc_diagnosis.dart';
import 'dev_work_doc_paths.dart';
import 'dev_work_doc_types.dart';
import 'instruction_content_checksum.dart';

Future<DevWorkDocState> currentState() async {
  return const DevWorkDocState(
    supported: false,
    hasRoot: false,
    statusMessage: '이 환경에서는 DevWorkDoc 폴더 접근을 지원하지 않습니다.',
  );
}

Future<DevWorkDocState> pickRootFolder() async {
  return const DevWorkDocState(
    supported: false,
    hasRoot: false,
    statusMessage: '이 환경에서는 폴더 선택을 지원하지 않습니다.',
  );
}

Future<DevWorkDocState> useNestedDevWorkDocFolder() async {
  return currentState();
}

Future<DevWorkDocWriteResult> ensureStructure() async {
  return DevWorkDocWriteResult.failed(
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
  return DevWorkDocWriteResult.download(
    fileName: fileName,
    activePathHint: DevWorkDocPaths.activeRelative(artifactType, instructionId),
    versionPathHint: DevWorkDocPaths.versionRelative(
      artifactType,
      instructionId,
      version,
    ),
    message: '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님).',
  );
}

Future<DevWorkDocWriteResult> saveInstruction({
  required String artifactType,
  required String instructionId,
  required int version,
  required String jsonText,
  bool isNewVersion = false,
}) async {
  // stub: 폴더 저장 불가 — ok=false (다운로드를 성공으로 위장하지 않음)
  return DevWorkDocWriteResult.failed(
    message:
        '이 환경에서는 폴더 직접 저장을 지원하지 않습니다. '
        '「수동 가져오기용 JSON 다운로드」를 사용하세요.',
    errorCode: 'unsupported',
    activePathHint: DevWorkDocPaths.activeRelative(artifactType, instructionId),
    versionPathHint: DevWorkDocPaths.versionRelative(
      artifactType,
      instructionId,
      version,
    ),
  );
}

Future<String?> readActive(String artifactType, String instructionId) async =>
    null;

Future<DevWorkDocDiagnosis> diagnoseInstruction({
  required String artifactType,
  required String instructionId,
  int? appVersion,
  String? appJsonText,
}) async {
  return DevWorkDocDiagnosis(
    instructionId: instructionId,
    artifactType: artifactType,
    versions: const [],
    activeExists: false,
    appVersion: appVersion,
    appStableChecksum: appJsonText == null || appJsonText.isEmpty
        ? ''
        : stableContentChecksum(appJsonText),
    summary: '이 환경에서는 DevWorkDoc 폴더를 진단할 수 없습니다.',
    nextAction: '웹 브라우저에서 DevWorkDoc 폴더를 선택한 뒤 다시 시도하세요.',
  );
}

Future<DevWorkDocWriteResult> restoreActiveFromVersion({
  required String artifactType,
  required String instructionId,
  required int version,
}) async {
  return DevWorkDocWriteResult.failed(
    message: '이 환경에서는 Active 복구를 지원하지 않습니다.',
    errorCode: 'unsupported',
    instructionId: instructionId,
    version: version,
  );
}

Future<String?> readVersionFile({
  required String artifactType,
  required String instructionId,
  required int version,
}) async => null;

Future<DevWorkDocWriteResult> archiveInstruction({
  required String artifactType,
  required String instructionId,
  required int version,
}) async {
  return DevWorkDocWriteResult.failed(
    message: '이 환경에서는 보관 작업을 지원하지 않습니다.',
    errorCode: 'unsupported',
  );
}

Future<DevWorkDocWriteResult> restoreInstruction({
  required String artifactType,
  required String instructionId,
}) async {
  return DevWorkDocWriteResult.failed(
    message: '이 환경에서는 복원 작업을 지원하지 않습니다.',
    errorCode: 'unsupported',
  );
}

Future<DevWorkDocWriteResult> permanentDelete({
  required String artifactType,
  required String instructionId,
}) async {
  return DevWorkDocWriteResult.failed(
    message: '이 환경에서는 삭제 작업을 지원하지 않습니다.',
    errorCode: 'unsupported',
  );
}
