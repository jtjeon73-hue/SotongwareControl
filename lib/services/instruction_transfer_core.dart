/// Inbox 전달 순수 로직 (파일명·재검증·중복 판정). VM 테스트 가능.
library;

import 'dart:convert';

import 'dev_work_doc_paths.dart';
import 'instruction_content_checksum.dart';
import 'instruction_transfer_types.dart';

/// 테스트에서 수동 다운로드 호출 횟수를 집계한다.
@pragma('vm:entry-point')
int instructionTransferManualDownloadCalls = 0;

@pragma('vm:entry-point')
void resetInstructionTransferManualDownloadCalls() {
  instructionTransferManualDownloadCalls = 0;
}

@pragma('vm:entry-point')
void recordInstructionTransferManualDownloadCall() {
  instructionTransferManualDownloadCalls++;
}

/// Inbox 루트 직하 파일명: `WI_<instructionId>_v<version>.json`
String inboxTransferFileName({
  required String instructionId,
  required int version,
  String? artifactType,
}) {
  final base = DevWorkDocPaths.wiBaseName(instructionId);
  final art = (artifactType ?? '').trim();
  if (art.isEmpty) return '${base}_v$version.json';
  final safeArt = DevWorkDocPaths.sanitizeInstructionId(art);
  return '${base}_v${version}_$safeArt.json';
}

class InboxReadBackExpectation {
  const InboxReadBackExpectation({
    required this.instructionId,
    required this.version,
    required this.contentChecksum,
  });

  final String instructionId;
  final int version;
  final String contentChecksum;
}

class InboxReadBackVerification {
  const InboxReadBackVerification({
    required this.ok,
    required this.message,
    this.parsed,
    this.bytes = 0,
    this.errorCode,
  });

  final bool ok;
  final String message;
  final Map<String, dynamic>? parsed;
  final int bytes;
  final String? errorCode;
}

/// 재읽기 텍스트를 instructionId / version / canonical checksum으로 검증.
InboxReadBackVerification verifyInboxReadBack({
  required String? text,
  required int size,
  required InboxReadBackExpectation expected,
}) {
  if (text == null) {
    return const InboxReadBackVerification(
      ok: false,
      message: 'Inbox 파일을 다시 읽지 못했습니다.',
      errorCode: 'readback_missing',
    );
  }
  if (size <= 0 || text.trim().isEmpty) {
    return InboxReadBackVerification(
      ok: false,
      message: 'Inbox 파일 크기가 0입니다.',
      bytes: size,
      errorCode: 'readback_empty',
    );
  }

  Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      return InboxReadBackVerification(
        ok: false,
        message: 'Inbox JSON 파싱 실패 (객체가 아님).',
        bytes: size,
        errorCode: 'readback_parse',
      );
    }
    map = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return InboxReadBackVerification(
      ok: false,
      message: 'Inbox JSON 파싱 실패.',
      bytes: size,
      errorCode: 'readback_parse',
    );
  }

  final id = '${map['instructionId'] ?? ''}'.trim();
  if (id != expected.instructionId.trim()) {
    return InboxReadBackVerification(
      ok: false,
      message: 'instructionId 불일치 (전달 검증 실패).',
      parsed: map,
      bytes: size,
      errorCode: 'id_mismatch',
    );
  }

  final verRaw = '${map['instructionVersion'] ?? map['version'] ?? ''}'.trim();
  final ver = int.tryParse(verRaw) ?? -1;
  if (ver != expected.version) {
    return InboxReadBackVerification(
      ok: false,
      message: 'version 불일치 (전달 검증 실패).',
      parsed: map,
      bytes: size,
      errorCode: 'version_mismatch',
    );
  }

  final stable = stableContentChecksum(map);
  if (stable != expected.contentChecksum.trim()) {
    return InboxReadBackVerification(
      ok: false,
      message: 'contentChecksum 불일치 (전달 검증 실패).',
      parsed: map,
      bytes: size,
      errorCode: 'checksum_mismatch',
    );
  }

  return InboxReadBackVerification(
    ok: true,
    message: 'Inbox 재읽기 검증 통과',
    parsed: map,
    bytes: size,
  );
}

/// 기존 Inbox 파일과 현재 스냅샷 비교.
TransferWriteResult decideExistingInboxFile({
  required String existingText,
  required String currentJsonText,
  required String fileName,
  required String instructionId,
  required int version,
  required String expectedChecksum,
}) {
  Map<String, dynamic>? existingMap;
  try {
    final decoded = jsonDecode(existingText);
    if (decoded is Map) {
      existingMap = Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    existingMap = null;
  }

  if (existingMap == null) {
    return TransferWriteResult.failed(
      message:
          'Inbox에 동일 파일명이 있으나 JSON이 아닙니다. 덮어쓰지 않았습니다.\n'
          '다음 행동: 전달 폴더를 확인하거나 수동 다운로드를 사용하세요.',
      errorCode: 'inbox_corrupt',
      fileName: fileName,
    );
  }

  final existingId = '${existingMap['instructionId'] ?? ''}'.trim();
  final existingVer =
      int.tryParse(
        '${existingMap['instructionVersion'] ?? existingMap['version'] ?? ''}'
            .trim(),
      ) ??
      -1;

  // 다른 버전 파일명이 우연히 같으면 충돌로 보호
  if (existingId.isNotEmpty &&
      existingId != instructionId.trim() &&
      existingVer == version) {
    return TransferWriteResult(
      ok: false,
      mode: 'failed',
      outcome: TransferOutcome.conflict,
      fileName: fileName,
      instructionId: instructionId,
      version: version,
      message:
          'Inbox 충돌: 다른 instructionId의 동일 버전 파일이 있습니다. 덮어쓰지 않았습니다.\n'
          '다음 행동: 새 버전을 생성하거나 파일명을 확인하세요.',
      errorCode: 'inbox_conflict',
      conflictDiffSummary: 'instructionId',
    );
  }

  final diff = diffInstructionContent(existingMap, currentJsonText);
  if (diff.isSameCore || diff.coreDiffFieldCount == 0) {
    return TransferWriteResult(
      ok: true,
      mode: 'folder',
      outcome: TransferOutcome.alreadyExists,
      fileName: fileName,
      instructionId: instructionId,
      version: version,
      checksum: expectedChecksum,
      verified: true,
      bytes: existingText.length,
      message: '기존 Inbox 파일 확인',
    );
  }

  final fields = diff.entries
      .where((e) => !e.isMetadata)
      .map((e) => e.label)
      .take(8)
      .join(', ');
  return TransferWriteResult(
    ok: false,
    mode: 'failed',
    outcome: TransferOutcome.conflict,
    fileName: fileName,
    instructionId: instructionId,
    version: version,
    checksum: expectedChecksum,
    message:
        'Inbox 충돌: 동일 버전인데 핵심 내용이 다릅니다. 덮어쓰지 않았습니다.\n'
        '차이 필드: ${fields.isEmpty ? '(목록 없음)' : fields}\n'
        '다음 행동: 사용자 승인 후 새 버전을 생성하세요.',
    errorCode: 'inbox_conflict',
    conflictDiffSummary: formatConflictDiagnosis(diff),
  );
}

/// Active 스냅샷과 현재 선택 기획 일치 여부.
class ActiveTransferGate {
  const ActiveTransferGate({
    required this.allowed,
    required this.message,
    this.jsonText,
    this.checksum,
  });

  final bool allowed;
  final String message;
  final String? jsonText;
  final String? checksum;
}

ActiveTransferGate gateActiveSnapshotForTransfer({
  required String? activeText,
  required String selectedInstructionId,
  required int selectedVersion,
  required String selectedArtifactType,
}) {
  if (activeText == null || activeText.trim().isEmpty) {
    return const ActiveTransferGate(
      allowed: false,
      message:
          '확정 Active 스냅샷이 없습니다. 전달을 차단합니다.\n'
          '다음 행동: DevWorkDoc에 저장하거나 「기존 버전 확인 및 복구」로 Active를 복구하세요.',
    );
  }

  Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(activeText);
    if (decoded is! Map) {
      return const ActiveTransferGate(
        allowed: false,
        message: 'Active JSON이 올바르지 않습니다. 전달을 차단합니다.',
      );
    }
    map = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return const ActiveTransferGate(
      allowed: false,
      message: 'Active JSON 파싱 실패. 전달을 차단합니다.',
    );
  }

  final id = '${map['instructionId'] ?? ''}'.trim();
  if (id != selectedInstructionId.trim()) {
    return const ActiveTransferGate(
      allowed: false,
      message:
          '현재 선택 기획과 Active instructionId가 일치하지 않습니다. 전달을 차단합니다.\n'
          '다음 행동: 올바른 기획안을 선택하거나 Active를 복구하세요.',
    );
  }

  final ver =
      int.tryParse(
        '${map['instructionVersion'] ?? map['version'] ?? ''}'.trim(),
      ) ??
      -1;
  if (ver != selectedVersion) {
    return ActiveTransferGate(
      allowed: false,
      message:
          '현재 선택 버전(v$selectedVersion)과 Active(v$ver)가 일치하지 않습니다. 전달을 차단합니다.\n'
          '다음 행동: DevWorkDoc에 다시 저장하거나 Active를 복구하세요.',
    );
  }

  final art = '${map['artifactType'] ?? ''}'.trim().toLowerCase();
  final selected = selectedArtifactType.trim().toLowerCase();
  if (selected.isNotEmpty && art.isNotEmpty && art != selected) {
    return const ActiveTransferGate(
      allowed: false,
      message:
          '현재 선택 artifactType과 Active가 일치하지 않습니다. 전달을 차단합니다.\n'
          '다음 행동: 올바른 기획안을 선택하세요.',
    );
  }

  final withSums = withCanonicalChecksumFields(map);
  final encoded = const JsonEncoder.withIndent('  ').convert(withSums);
  final sum = '${withSums['contentChecksum'] ?? ''}';
  return ActiveTransferGate(
    allowed: true,
    message: 'Active 스냅샷 전달 준비 완료',
    jsonText: encoded,
    checksum: sum,
  );
}

FolderPermissionState buildInboxFolderState({
  required bool supported,
  required bool hasHandle,
  String? folderName,
  required bool permissionGranted,
}) {
  if (!supported) {
    return FolderPermissionState(
      supported: false,
      hasHandle: false,
      folderName: folderName,
      permissionGranted: false,
      readyToWrite: false,
      needsReselect: true,
      statusMessage:
          '이 브라우저는 폴더 직접 저장을 지원하지 않습니다. 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
    );
  }
  if (!hasHandle) {
    final nameOnly = (folderName ?? '').trim().isNotEmpty;
    return FolderPermissionState(
      supported: true,
      hasHandle: false,
      folderName: folderName,
      permissionGranted: false,
      readyToWrite: false,
      needsReselect: true,
      statusMessage: nameOnly
          ? '폴더 이름만 있고 실제 핸들이 없습니다. 「전달 폴더 다시 선택」이 필요합니다.'
          : 'Inbox 폴더 미선택',
    );
  }
  if (!permissionGranted) {
    return FolderPermissionState(
      supported: true,
      hasHandle: true,
      folderName: folderName,
      permissionGranted: false,
      readyToWrite: false,
      needsReselect: true,
      statusMessage: '쓰기 권한 재승인이 필요합니다. 「전달 폴더 다시 선택」을 누르세요.',
    );
  }
  return FolderPermissionState(
    supported: true,
    hasHandle: true,
    folderName: folderName,
    permissionGranted: true,
    readyToWrite: true,
    needsReselect: false,
    statusMessage: '선택 기준: Inbox 폴더 · 쓰기 권한: 허용 · 실제 전달 준비: 완료',
  );
}

/// Inbox 직접 전달 오케스트레이션 (다운로드 호출 없음).
Future<TransferWriteResult> performInboxDirectTransfer({
  required String fileName,
  required String jsonText,
  required String instructionId,
  required int version,
  required String expectedChecksum,
  required Future<({String? text, int size})> Function(String fileName)
  readExisting,
  required Future<void> Function(String fileName, String content) writeFile,
  String folderLabel = 'Inbox',
}) async {
  final id = instructionId.trim();
  final checksum = expectedChecksum.trim().isNotEmpty
      ? expectedChecksum.trim()
      : stableContentChecksum(jsonText);

  final existing = await readExisting(fileName);
  if (existing.text != null && existing.text!.trim().isNotEmpty) {
    return decideExistingInboxFile(
      existingText: existing.text!,
      currentJsonText: jsonText,
      fileName: fileName,
      instructionId: id.isNotEmpty ? id : 'unknown',
      version: version,
      expectedChecksum: checksum,
    );
  }

  try {
    await writeFile(fileName, jsonText);
  } catch (e) {
    return TransferWriteResult.failed(
      message:
          '직접 전달 실패: $e\n'
          '다운로드로 대체하지 않았습니다.\n'
          '다음 행동: 「전달 폴더 다시 선택」 또는 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
      errorCode: 'write_failed',
      fileName: fileName,
    );
  }

  final readBack = await readExisting(fileName);
  final verification = verifyInboxReadBack(
    text: readBack.text,
    size: readBack.size,
    expected: InboxReadBackExpectation(
      instructionId: id,
      version: version,
      contentChecksum: checksum,
    ),
  );
  if (!verification.ok) {
    return TransferWriteResult.failed(
      message:
          '직접 전달 실패: ${verification.message}\n'
          '다음 행동: 「전달 폴더 다시 선택」 또는 수동 다운로드 화면으로 이동하세요.',
      errorCode: verification.errorCode ?? 'verify_failed',
      fileName: fileName,
    );
  }

  return TransferWriteResult(
    ok: true,
    mode: 'folder',
    outcome: TransferOutcome.transferred,
    fileName: fileName,
    instructionId: id,
    version: version,
    checksum: checksum,
    verified: true,
    bytes: readBack.size,
    message: '전달됨 · Inbox「$folderLabel」에 저장·검증 완료',
  );
}
