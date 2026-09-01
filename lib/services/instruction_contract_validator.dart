/// Inbox 전달 전 Contract 검증 — VALID / WARNING / BLOCKED.
library;

import '../models/business_planning.dart';
import 'work_instruction_validator.dart';

enum ContractValidationLevel { valid, warning, blocked }

class ContractValidationIssue {
  const ContractValidationIssue({
    required this.field,
    required this.reason,
    required this.fix,
    required this.level,
  });

  final String field;
  final String reason;
  final String fix;
  final ContractValidationLevel level;

  Map<String, dynamic> toJson() => {
    'field': field,
    'reason': reason,
    'fix': fix,
    'level': level.name.toUpperCase(),
  };
}

class ContractValidationResult {
  const ContractValidationResult({required this.level, required this.issues});

  final ContractValidationLevel level;
  final List<ContractValidationIssue> issues;

  bool get isBlocked => level == ContractValidationLevel.blocked;
  bool get canTransfer => level != ContractValidationLevel.blocked;
  bool get ok => level == ContractValidationLevel.valid;

  List<ContractValidationIssue> get blockers =>
      issues.where((e) => e.level == ContractValidationLevel.blocked).toList();

  List<ContractValidationIssue> get warnings =>
      issues.where((e) => e.level == ContractValidationLevel.warning).toList();

  String get levelLabel {
    switch (level) {
      case ContractValidationLevel.valid:
        return 'VALID';
      case ContractValidationLevel.warning:
        return 'WARNING';
      case ContractValidationLevel.blocked:
        return 'BLOCKED';
    }
  }
}

/// 표준 Contract + 레거시 필수 필드 통합 검증.
class InstructionContractValidator {
  InstructionContractValidator({WorkInstructionValidator? legacy})
    : _legacy = legacy ?? WorkInstructionValidator();

  final WorkInstructionValidator _legacy;

  ContractValidationResult validate({
    required BusinessPlanInput input,
    required WorkInstruction instruction,
  }) {
    final issues = <ContractValidationIssue>[];

    // 1) 레거시 필수 — 실패 시 BLOCKED
    final legacy = _legacy.validate(input: input, instruction: instruction);
    for (final issue in legacy.issues) {
      issues.add(
        ContractValidationIssue(
          field: issue.field,
          reason: issue.reason,
          fix: issue.fix,
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    // 2) schema
    if (!isSupportedInstructionSchema(instruction.schemaVersion)) {
      issues.add(
        ContractValidationIssue(
          field: 'schemaVersion',
          reason: '지원하지 않는 schemaVersion: ${instruction.schemaVersion}',
          fix:
              'schemaVersion을 $instructionSchemaVersionCurrent 또는 $instructionSchemaVersionLegacy 로 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    // 3) identity / core canonical
    final artifact = ArtifactType.normalize(
      instruction.artifactType.isNotEmpty
          ? instruction.artifactType
          : input.resolvedArtifactType,
    );
    if (artifact == ArtifactType.undecided || artifact.isEmpty) {
      issues.add(
        const ContractValidationIssue(
          field: 'artifactType',
          reason: '결과물 유형이 미정입니다.',
          fix: '전자책·앱·콘텐츠·지식사이트·홍보사이트 중 하나를 선택하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    _requireNonEmpty(
      issues,
      field: 'title',
      value: instruction.businessIdea,
      reason: '제목(businessIdea/title)이 비어 있습니다.',
    );
    _requireNonEmpty(
      issues,
      field: 'targetCustomers',
      value: instruction.targetCustomer,
      reason: '대상 고객이 비어 있습니다.',
    );
    _requireNonEmpty(
      issues,
      field: 'coreProblem',
      value: instruction.customerProblem,
      reason: '핵심 문제가 비어 있습니다.',
    );
    _requireNonEmpty(
      issues,
      field: 'expectedOutcome',
      value: instruction.businessPurpose,
      reason: '기대 결과/목적이 비어 있습니다.',
    );
    _requireNonEmpty(
      issues,
      field: 'instructionId',
      value: instruction.instructionId,
      reason: 'instructionId가 없습니다.',
    );

    if (artifact == ArtifactType.contents) {
      final sub = ContentSubtype.normalize(
        instruction.contentSubtype.isEmpty
            ? input.contentSubtype
            : instruction.contentSubtype,
      );
      if (sub == ContentSubtype.undecided) {
        issues.add(
          const ContractValidationIssue(
            field: 'artifactSubtype',
            reason: '콘텐츠 하위 유형이 미정입니다.',
            fix: '노래·쇼츠·영상·기타 중 하나를 선택하세요.',
            level: ContractValidationLevel.blocked,
          ),
        );
      }
    }

    // 4) Contract 블록 (1.1)
    final contract = instruction.contract;
    if (contract == null) {
      if (instruction.schemaVersion == instructionSchemaVersionCurrent) {
        issues.add(
          const ContractValidationIssue(
            field: 'contract',
            reason: 'schema 1.1인데 Contract 블록이 없습니다.',
            fix: '작업지시서를 다시 생성하세요.',
            level: ContractValidationLevel.blocked,
          ),
        );
      } else {
        issues.add(
          const ContractValidationIssue(
            field: 'contract',
            reason: '레거시 지시서입니다. Contract 블록이 없어 일부 검증을 건너뜁니다.',
            fix: '가능하면 작업지시서를 다시 생성해 schema 1.1로 업그레이드하세요.',
            level: ContractValidationLevel.warning,
          ),
        );
      }
    } else {
      _validateContract(issues, contract, instruction);
    }

    // 5) UI ↔ JSON 일치
    if (input.topic.trim().isNotEmpty &&
        instruction.businessIdea.trim() != input.topic.trim()) {
      issues.add(
        ContractValidationIssue(
          field: 'canonical.title',
          reason: 'UI 확정 제목과 JSON businessIdea가 일치하지 않습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (input.customerProblem.trim().isNotEmpty &&
        instruction.customerProblem.trim() != input.customerProblem.trim()) {
      issues.add(
        const ContractValidationIssue(
          field: 'canonical.coreProblem',
          reason: 'UI 확정 문제와 JSON customerProblem이 일치하지 않습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (input.targetCustomer.trim().isNotEmpty &&
        instruction.targetCustomer.trim() != input.targetCustomer.trim()) {
      issues.add(
        const ContractValidationIssue(
          field: 'canonical.targetCustomers',
          reason: 'UI 확정 고객과 JSON targetCustomer가 일치하지 않습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (input.desiredOutcome.trim().isNotEmpty &&
        instruction.businessPurpose.trim() != input.desiredOutcome.trim()) {
      issues.add(
        const ContractValidationIssue(
          field: 'canonical.expectedOutcome',
          reason: 'UI 확정 목적과 JSON businessPurpose가 일치하지 않습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    // 5.5) AI execution mode contract (continuous vs hold)
    _validateAiExecutionMode(issues, instruction);

    // 6) generic 오염 휴리스틱 (warning)
    final genericHints = [
      '일반 독자',
      '템플릿 제목',
      '샘플 주제',
      '예시 고객',
      'TODO',
      'TBD',
      'placeholder',
    ];
    for (final hint in genericHints) {
      if (instruction.businessIdea.contains(hint) ||
          instruction.targetCustomer.contains(hint)) {
        issues.add(
          ContractValidationIssue(
            field: 'canonical.generic',
            reason: 'generic/template 의심 문구가 포함되어 있습니다: $hint',
            fix: '확정된 제목·고객으로 수정한 뒤 다시 생성하세요.',
            level: ContractValidationLevel.warning,
          ),
        );
      }
    }

    final level = issues.any((e) => e.level == ContractValidationLevel.blocked)
        ? ContractValidationLevel.blocked
        : issues.any((e) => e.level == ContractValidationLevel.warning)
        ? ContractValidationLevel.warning
        : ContractValidationLevel.valid;

    return ContractValidationResult(level: level, issues: issues);
  }

  void _validateContract(
    List<ContractValidationIssue> issues,
    InstructionContract contract,
    WorkInstruction instruction,
  ) {
    final def = contract.projectDefinition;
    if (def.title.pending || def.title.isBlank) {
      issues.add(
        const ContractValidationIssue(
          field: 'projectDefinition.title',
          reason: 'canonical title이 pending/빈 값입니다.',
          fix: '제목을 확정하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (def.coreProblem.pending || def.coreProblem.isBlank) {
      issues.add(
        const ContractValidationIssue(
          field: 'projectDefinition.coreProblem',
          reason: 'canonical coreProblem이 pending/빈 값입니다.',
          fix: '핵심 문제를 확정하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (def.expectedOutcome.pending || def.expectedOutcome.isBlank) {
      issues.add(
        const ContractValidationIssue(
          field: 'projectDefinition.expectedOutcome',
          reason: 'canonical expectedOutcome이 pending/빈 값입니다.',
          fix: '기대 결과를 확정하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (def.targetCustomers.isEmpty && def.targetCustomerDescription.isBlank) {
      issues.add(
        const ContractValidationIssue(
          field: 'projectDefinition.targetCustomers',
          reason: '대상 고객 목록이 비어 있습니다.',
          fix: '대상 고객을 선택하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    // template이 user 값을 덮었는지
    if (def.title.source == FieldSource.template) {
      issues.add(
        const ContractValidationIssue(
          field: 'canonical.title.source',
          reason: '제목 source가 template입니다. 사용자 확정값이어야 합니다.',
          fix: '제목을 다시 확정하고 지시서를 재생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    if (contract.workflow.stages.isEmpty) {
      issues.add(
        const ContractValidationIssue(
          field: 'workflow',
          reason: 'workflow.stages가 비어 있습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    } else if (contract.workflow.workflowId.trim().isEmpty) {
      issues.add(
        const ContractValidationIssue(
          field: 'workflow.workflowId',
          reason: 'workflowId가 비어 있습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    if (contract.qualityCriteria.isEmpty) {
      issues.add(
        const ContractValidationIssue(
          field: 'qualityCriteria',
          reason: '품질 계약이 비어 있습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (contract.aiGuards.isEmpty) {
      issues.add(
        const ContractValidationIssue(
          field: 'aiGuards',
          reason: 'AI Guard 규칙이 비어 있습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }

    final approval = contract.approval;
    for (final entry in {
      'planning': approval.planning,
      'instructionGeneration': approval.instructionGeneration,
      'production': approval.production,
      'publishing': approval.publishing,
      'deployment': approval.deployment,
    }.entries) {
      if (!_isValidApproval(entry.value)) {
        issues.add(
          ContractValidationIssue(
            field: 'approval.${entry.key}',
            reason: '알 수 없는 승인 상태: ${entry.value}',
            fix:
                'pending/approved/rejected/revision_requested/not_required 중 하나로 설정하세요.',
            level: ContractValidationLevel.blocked,
          ),
        );
      }
    }

    if (contract.productionSpec.artifactType.trim().isEmpty) {
      issues.add(
        const ContractValidationIssue(
          field: 'productionSpec',
          reason: 'productionSpec.artifactType이 비어 있습니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    } else if (contract.productionSpec.undecidedKeys.isNotEmpty) {
      issues.add(
        ContractValidationIssue(
          field: 'productionSpec.undecidedKeys',
          reason:
              '미정 제작 옵션: ${contract.productionSpec.undecidedKeys.join(', ')}',
          fix: '가능하면 제작 정보를 선택한 뒤 재생성하세요. 경고만으로는 전달 가능합니다.',
          level: ContractValidationLevel.warning,
        ),
      );
    }

    // flat ↔ nested title sync
    final nestedTitle = def.title.value.trim();
    if (nestedTitle.isNotEmpty &&
        nestedTitle != instruction.businessIdea.trim()) {
      issues.add(
        const ContractValidationIssue(
          field: 'canonical.title.sync',
          reason: 'nested title과 flat businessIdea가 불일치합니다.',
          fix: '작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
  }

  bool _isValidApproval(String status) {
    return status == ApprovalStatus.pending ||
        status == ApprovalStatus.approved ||
        status == ApprovalStatus.rejected ||
        status == ApprovalStatus.revisionRequested ||
        status == ApprovalStatus.notRequired;
  }

  void _requireNonEmpty(
    List<ContractValidationIssue> issues, {
    required String field,
    required String value,
    required String reason,
  }) {
    if (value.trim().isEmpty) {
      issues.add(
        ContractValidationIssue(
          field: field,
          reason: reason,
          fix: '필수 값을 채운 뒤 작업지시서를 다시 생성하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
  }

  void _validateAiExecutionMode(
    List<ContractValidationIssue> issues,
    WorkInstruction instruction,
  ) {
    final ai = instruction.aiExecution;
    if (ai == null || !ai.enabled) return;

    final wantsContinuous = ai.approvalMode == 'auto' || ai.autoAdvance;
    final isContinuous = ai.executionMode == 'continuous';
    final isHold = ai.executionMode == 'hold' ||
        ai.executionMode == 'single' ||
        ai.executionMode == 'single_step';

    if (wantsContinuous && !isContinuous) {
      issues.add(
        const ContractValidationIssue(
          field: 'aiExecution.executionMode',
          reason:
              '자동 승인/연속 실행 선택 시 executionMode=continuous 가 필요합니다.',
          fix: '작업지시서를 다시 생성하거나 executionMode를 continuous로 설정하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (!wantsContinuous && isContinuous) {
      issues.add(
        const ContractValidationIssue(
          field: 'aiExecution.executionMode',
          reason: '수동 승인(hold) 모드에서는 continuous 실행이 허용되지 않습니다.',
          fix: 'executionMode를 hold로 설정하세요.',
          level: ContractValidationLevel.blocked,
        ),
      );
    }
    if (wantsContinuous && isHold && ai.executionMode != 'hold') {
      // explicit contradictory combo already covered above
    }
  }
}
