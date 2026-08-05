/// 저장 검증·마이그레이션 판정 (순수 Dart, FSA 어댑터와 분리).
library;

import 'dart:convert';

import 'dev_work_doc_types.dart';
import 'work_instruction_validator.dart';

class DevWorkDocVerifyInput {
  const DevWorkDocVerifyInput({
    required this.expectedJson,
    required this.activeText,
    required this.versionsText,
    required this.instructionId,
    required this.version,
  });

  final String expectedJson;
  final String? activeText;
  final String? versionsText;
  final String instructionId;
  final int version;
}

class DevWorkDocVerifyResult {
  const DevWorkDocVerifyResult({
    required this.outcome,
    required this.activeVerified,
    required this.versionsVerified,
    required this.activeBytes,
    required this.versionsBytes,
    required this.checksum,
    required this.message,
    this.errorCode,
  });

  final DevWorkDocSaveOutcome outcome;
  final bool activeVerified;
  final bool versionsVerified;
  final int activeBytes;
  final int versionsBytes;
  final String checksum;
  final String message;
  final String? errorCode;

  bool get isComplete =>
      outcome == DevWorkDocSaveOutcome.completeSuccess &&
      activeVerified &&
      versionsVerified;
}

/// Active/Versions 재읽기 텍스트를 검증한다.
DevWorkDocVerifyResult verifyWrittenPair(DevWorkDocVerifyInput input) {
  final expectedChecksum = contentChecksum(input.expectedJson);
  final active = _checkFile(
    label: 'Active',
    text: input.activeText,
    expectedJson: input.expectedJson,
    expectedChecksum: expectedChecksum,
    instructionId: input.instructionId,
    version: input.version,
  );
  final versions = _checkFile(
    label: 'Versions',
    text: input.versionsText,
    expectedJson: input.expectedJson,
    expectedChecksum: expectedChecksum,
    instructionId: input.instructionId,
    version: input.version,
  );

  if (active.ok && versions.ok) {
    return DevWorkDocVerifyResult(
      outcome: DevWorkDocSaveOutcome.completeSuccess,
      activeVerified: true,
      versionsVerified: true,
      activeBytes: active.bytes,
      versionsBytes: versions.bytes,
      checksum: expectedChecksum,
      message: 'Active·Versions 저장·재읽기 검증 완료',
    );
  }

  if (active.ok || versions.ok) {
    return DevWorkDocVerifyResult(
      outcome: DevWorkDocSaveOutcome.partialSuccess,
      activeVerified: active.ok,
      versionsVerified: versions.ok,
      activeBytes: active.bytes,
      versionsBytes: versions.bytes,
      checksum: expectedChecksum,
      message:
          '부분 성공: ${[if (!active.ok) active.error, if (!versions.ok) versions.error].join(' / ')}',
      errorCode: 'partial',
    );
  }

  return DevWorkDocVerifyResult(
    outcome: DevWorkDocSaveOutcome.failed,
    activeVerified: false,
    versionsVerified: false,
    activeBytes: active.bytes,
    versionsBytes: versions.bytes,
    checksum: expectedChecksum,
    message: [
      active.error,
      versions.error,
    ].where((e) => e.isNotEmpty).join(' / '),
    errorCode: 'verify_failed',
  );
}

/// 기존 파일과 비교.
DevWorkDocSaveOutcome compareExistingFile({
  required String? existingText,
  required String expectedJson,
}) {
  if (existingText == null || existingText.isEmpty) {
    return DevWorkDocSaveOutcome.failed;
  }
  try {
    jsonDecode(existingText);
  } catch (_) {
    return DevWorkDocSaveOutcome.conflict;
  }
  if (contentChecksum(existingText) == contentChecksum(expectedJson)) {
    return DevWorkDocSaveOutcome.alreadyExists;
  }
  return DevWorkDocSaveOutcome.conflict;
}

class _FileCheck {
  const _FileCheck({
    required this.ok,
    required this.bytes,
    required this.error,
  });
  final bool ok;
  final int bytes;
  final String error;
}

_FileCheck _checkFile({
  required String label,
  required String? text,
  required String expectedJson,
  required String expectedChecksum,
  required String instructionId,
  required int version,
}) {
  if (text == null) {
    return _FileCheck(ok: false, bytes: 0, error: '$label 없음');
  }
  final bytes = text.length;
  if (bytes <= 0) {
    return _FileCheck(ok: false, bytes: 0, error: '$label 빈 파일');
  }

  late final Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      return _FileCheck(ok: false, bytes: bytes, error: '$label JSON 객체 아님');
    }
    map = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return _FileCheck(ok: false, bytes: bytes, error: '$label JSON 파싱 실패');
  }

  final id = '${map['instructionId'] ?? ''}';
  final ver = '${map['instructionVersion'] ?? ''}';
  if (id != instructionId) {
    return _FileCheck(
      ok: false,
      bytes: bytes,
      error: '$label instructionId 불일치',
    );
  }
  if (ver != '$version') {
    return _FileCheck(ok: false, bytes: bytes, error: '$label version 불일치');
  }

  final fileChecksum = contentChecksum(text);
  if (fileChecksum != expectedChecksum && text != expectedJson) {
    final field = '${map['checksum'] ?? ''}';
    final expectedMap = _tryMap(expectedJson);
    final expectedField = '${expectedMap?['checksum'] ?? ''}';
    if (expectedField.isNotEmpty && field != expectedField) {
      return _FileCheck(ok: false, bytes: bytes, error: '$label checksum 불일치');
    }
    if (expectedField.isEmpty && fileChecksum != expectedChecksum) {
      return _FileCheck(ok: false, bytes: bytes, error: '$label 내용 해시 불일치');
    }
  }

  return _FileCheck(ok: true, bytes: bytes, error: '');
}

Map<String, dynamic>? _tryMap(String json) {
  try {
    final d = jsonDecode(json);
    if (d is Map) return Map<String, dynamic>.from(d);
  } catch (_) {}
  return null;
}

/// 선택 폴더 이름·하위 엔트리로 기준 판정.
DevWorkDocSelectionKind classifySelection({
  required String folderName,
  required List<String> childNames,
}) {
  final lower = folderName.trim().toLowerCase();
  final children = childNames.map((e) => e.toLowerCase()).toSet();
  final hasDevWorkDocChild = children.contains('devworkdoc');
  final hasArtifactChildren =
      children.contains('ebook') ||
      children.contains('app') ||
      children.contains('site') ||
      children.contains('contents') ||
      children.contains('promosite');

  if (lower == 'devworkdoc' || hasArtifactChildren) {
    return DevWorkDocSelectionKind.devWorkDocRoot;
  }
  if (hasDevWorkDocChild) {
    return DevWorkDocSelectionKind.repoRootWithDevWorkDoc;
  }
  if (lower.contains('sotongwarecontrol') || lower.contains('sotongware')) {
    return DevWorkDocSelectionKind.ambiguous;
  }
  return DevWorkDocSelectionKind.ambiguous;
}

String outcomeLabelKo(DevWorkDocSaveOutcome o) {
  switch (o) {
    case DevWorkDocSaveOutcome.completeSuccess:
      return '완전 성공';
    case DevWorkDocSaveOutcome.partialSuccess:
      return '부분 성공';
    case DevWorkDocSaveOutcome.alreadyExists:
      return '기존 파일 확인';
    case DevWorkDocSaveOutcome.conflict:
      return '충돌';
    case DevWorkDocSaveOutcome.downloadOnly:
      return '다운로드만 (폴더 저장 아님)';
    case DevWorkDocSaveOutcome.permissionNeeded:
      return '권한 재승인 필요';
    case DevWorkDocSaveOutcome.awaitingArtifact:
      return '유형 선택 대기';
    case DevWorkDocSaveOutcome.failed:
      return '실패';
  }
}
