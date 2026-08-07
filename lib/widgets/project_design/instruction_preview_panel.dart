import 'package:flutter/material.dart';

import '../../models/business_planning.dart';
import '../../services/instruction_contract_validator.dart';
import '../../theme/control_theme.dart';

/// 작업지시서 최종 검토 — 사람이 읽기 쉬운 Contract 요약.
class InstructionPreviewPanel extends StatelessWidget {
  const InstructionPreviewPanel({
    super.key,
    required this.instruction,
    this.validation,
  });

  final WorkInstruction instruction;
  final ContractValidationResult? validation;

  @override
  Widget build(BuildContext context) {
    final c = instruction.contract;
    final level = validation?.levelLabel ?? (c == null ? 'LEGACY' : '—');
    final levelColor = switch (validation?.level) {
      ContractValidationLevel.blocked => ControlColors.accentWarm,
      ContractValidationLevel.warning => ControlColors.sandBeige,
      ContractValidationLevel.valid => ControlColors.accentGreen,
      null => ControlColors.textMuted,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '작업지시서 최종 검토',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: levelColor),
              ),
              child: Text(
                level,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: levelColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'schema ${instruction.schemaVersion} · v${instruction.instructionVersion}',
          style: const TextStyle(fontSize: 12, color: ControlColors.textMuted),
        ),
        const SizedBox(height: 12),
        _section('기본', [
          _kv('결과물', _artifactLabel()),
          _kv('제목', instruction.businessIdea),
          _kv('대상 고객', instruction.targetCustomer),
          _kv('핵심 문제', instruction.customerProblem),
          _kv('목적', instruction.businessPurpose),
        ]),
        if (c != null) ...[
          const SizedBox(height: 12),
          _section('선택 주제', [
            _kv(
              '주제',
              c.projectDefinition.selectedTopics.isEmpty
                  ? '(없음)'
                  : c.projectDefinition.selectedTopics.join(', '),
            ),
            if (c.projectDefinition.userMemo.trim().isNotEmpty)
              _kv('메모', c.projectDefinition.userMemo),
          ]),
          const SizedBox(height: 12),
          _section('제작 조건', [
            for (final e in c.productionSpec.spec.entries.take(10))
              _kv(e.key, '${e.value}'),
            if (c.productionSpec.undecidedKeys.isNotEmpty)
              _kv('미정', c.productionSpec.undecidedKeys.join(', ')),
          ]),
          const SizedBox(height: 12),
          _section('범위', [
            _kv('포함', c.scope.included.take(6).join(' · ')),
            _kv('제외', c.scope.excluded.take(4).join(' · ')),
          ]),
          const SizedBox(height: 12),
          _section('품질 기준', [
            _kv(
              '필수',
              c.qualityCriteria
                  .where((q) => q.required)
                  .map((q) => q.label)
                  .join(', '),
            ),
          ]),
          const SizedBox(height: 12),
          _section('AI 규칙', [
            _kv(
              '공통',
              c.aiGuards
                  .where((g) => g.scope == 'common')
                  .take(5)
                  .map((g) => g.rule)
                  .join(' · '),
            ),
          ]),
          const SizedBox(height: 12),
          _section('승인 정책', [
            _kv('기획', c.approval.planning),
            _kv('지시서', c.approval.instructionGeneration),
            _kv('제작', c.approval.production),
            _kv('공개', c.approval.publishing),
            _kv('배포', c.approval.deployment),
            _kv('워크플로', c.workflow.workflowId),
          ]),
        ],
        if (validation != null && validation!.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('검증 이슈', [
            for (final issue in validation!.issues.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '[${issue.level.name.toUpperCase()}] ${issue.field}: ${issue.reason}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: issue.level == ContractValidationLevel.blocked
                        ? ControlColors.accentWarm
                        : ControlColors.textSecondary,
                  ),
                ),
              ),
          ]),
        ],
      ],
    );
  }

  String _artifactLabel() {
    final a = ArtifactType.labelKo(instruction.artifactType);
    if (instruction.contentSubtype.trim().isEmpty) return a;
    return '$a · ${ContentSubtype.labelKo(instruction.contentSubtype)}';
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ControlColors.border),
        borderRadius: BorderRadius.circular(10),
        color: ControlColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    final text = v.trim().isEmpty ? '(미정)' : v.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
