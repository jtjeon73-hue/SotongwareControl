import 'dart:convert';

import '../models/business_planning.dart';

export 'instruction_content_checksum.dart'
    show
        contentChecksum,
        contentChecksumRaw,
        stableContentChecksum,
        compareInstructionContent,
        diffInstructionContent,
        formatConflictDiagnosis,
        withCanonicalChecksumFields,
        storedChecksumOf,
        storedAlgorithmOf,
        normalizeInstructionMap,
        InstructionContentRelation,
        InstructionContentDiff,
        InstructionDiffEntry,
        instructionVolatileKeys,
        canonicalContentMap,
        checksumAlgorithmCanonicalV2,
        checksumAlgorithmLegacyFullJson;

class ValidationIssue {
  const ValidationIssue({
    required this.field,
    required this.reason,
    required this.fix,
  });

  final String field;
  final String reason;
  final String fix;

  Map<String, dynamic> toJson() => {
    'field': field,
    'reason': reason,
    'fix': fix,
  };
}

class InstructionValidationResult {
  const InstructionValidationResult({required this.ok, required this.issues});

  final bool ok;
  final List<ValidationIssue> issues;
}

/// 소통24워크 전달용 JSON 스키마·필수항목 검증.
class WorkInstructionValidator {
  static const requiredTopLevel = [
    'schemaVersion',
    'instructionId',
    'projectId',
    'instructionVersion',
    'createdAt',
    'updatedAt',
    'businessIdea',
    'customerProblem',
    'targetCustomer',
    'businessPurpose',
    'deliverableTypes',
    'workflowSteps',
    'executionStatus',
  ];

  InstructionValidationResult validate({
    required BusinessPlanInput input,
    required WorkInstruction instruction,
  }) {
    final issues = <ValidationIssue>[];

    for (final label in input.missingRequiredLabels) {
      issues.add(
        ValidationIssue(
          field: label,
          reason: '필수 입력이 비어 있습니다.',
          fix: '기획 입력에서 「$label」을(를) 채운 뒤 다시 저장하세요.',
        ),
      );
    }

    final json = instruction.toJson();
    for (final key in requiredTopLevel) {
      final value = json[key];
      if (value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty && key == 'deliverableTypes')) {
        issues.add(
          ValidationIssue(
            field: key,
            reason: 'JSON 필수 필드가 비어 있습니다.',
            fix: '작업지시서를 다시 생성하세요.',
          ),
        );
      }
    }

    if (!isSupportedInstructionSchema(instruction.schemaVersion)) {
      issues.add(
        ValidationIssue(
          field: 'schemaVersion',
          reason: '지원하지 않는 schemaVersion 입니다.',
          fix:
              'schemaVersion을 $instructionSchemaVersionCurrent 또는 $instructionSchemaVersionLegacy 로 생성하세요.',
        ),
      );
    }

    if (instruction.instructionId.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          field: 'instructionId',
          reason: '지시서 ID가 없습니다.',
          fix: '기획을 저장한 뒤 작업지시서를 다시 생성하세요.',
        ),
      );
    }

    if (!RegExp(r'^\d+$').hasMatch(instruction.instructionVersion.trim())) {
      issues.add(
        ValidationIssue(
          field: 'instructionVersion',
          reason: 'version이 숫자가 아닙니다: ${instruction.instructionVersion}',
          fix: '정수 version으로 다시 생성하세요.',
        ),
      );
    }

    if (DateTime.tryParse(instruction.createdAt) == null) {
      issues.add(
        const ValidationIssue(
          field: 'createdAt',
          reason: 'ISO 8601 날짜가 아닙니다.',
          fix: '작업지시서를 다시 생성하세요.',
        ),
      );
    }

    if (instruction.workflowSteps.length != 18) {
      issues.add(
        ValidationIssue(
          field: 'workflowSteps',
          reason: '표준 18단계가 아닙니다 (${instruction.workflowSteps.length}개).',
          fix: '표준 워크플로로 작업지시서를 다시 생성하세요.',
        ),
      );
    }

    final expectedTrack = input.primaryTrack;
    if (instruction.primaryTrack.isNotEmpty &&
        instruction.primaryTrack != expectedTrack) {
      issues.add(
        ValidationIssue(
          field: 'primaryTrack',
          reason:
              '제작 형태의 주 트랙이 ${ArtifactType.primaryTrack(input.resolvedArtifactType)}(이)가 아닙니다.',
          fix: '작업지시서를 다시 생성하세요.',
        ),
      );
    }

    final artifact = input.resolvedArtifactType;
    if (artifact != ArtifactType.undecided &&
        instruction.artifactType.isNotEmpty &&
        ArtifactType.normalize(instruction.artifactType) != artifact) {
      issues.add(
        ValidationIssue(
          field: 'artifactType',
          reason: '지시서 artifactType이 기획과 일치하지 않습니다.',
          fix: '작업지시서를 다시 생성하세요.',
        ),
      );
    }

    if (instruction.executionStatus.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          field: 'executionStatus',
          reason: '실행 상태가 비어 있습니다.',
          fix: '지시서 준비 상태로 다시 생성하세요.',
        ),
      );
    }

    // round-trip JSON
    try {
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        issues.add(
          const ValidationIssue(
            field: 'json',
            reason: 'JSON 객체가 아닙니다.',
            fix: '작업지시서를 다시 생성하세요.',
          ),
        );
      } else {
        WorkInstruction.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      issues.add(
        ValidationIssue(
          field: 'json',
          reason: '직렬화/역직렬화 실패: $e',
          fix: '작업지시서를 다시 생성하세요.',
        ),
      );
    }

    return InstructionValidationResult(ok: issues.isEmpty, issues: issues);
  }
}
