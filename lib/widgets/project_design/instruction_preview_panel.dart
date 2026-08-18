import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/business_planning.dart';
import '../../services/instruction_contract_validator.dart';
import '../../services/work_instruction_workshop_presentation.dart';
import '../../theme/control_theme.dart';

/// 작업지시서 — 사용자 친화 상세 (raw JSON은 고급 원문).
class InstructionPreviewPanel extends StatefulWidget {
  const InstructionPreviewPanel({
    super.key,
    required this.instruction,
    this.validation,
    this.showQualityHints = true,
  });

  final WorkInstruction instruction;
  final ContractValidationResult? validation;
  final bool showQualityHints;

  @override
  State<InstructionPreviewPanel> createState() =>
      _InstructionPreviewPanelState();
}

class _InstructionPreviewPanelState extends State<InstructionPreviewPanel> {
  bool _advancedOpen = false;

  WorkInstruction get instruction => widget.instruction;
  ContractValidationResult? get validation => widget.validation;

  @override
  Widget build(BuildContext context) {
    final c = instruction.contract;
    final quality = widget.showQualityHints
        ? WorkInstructionWorkshopPresentation.qualityHints(instruction)
        : const <InstructionQualityHint>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('기본', [
          _kv('사업유형', _artifactLabel()),
          _kv('작업 제목', instruction.businessIdea),
          _kv(
            '대상 고객',
            WorkInstructionWorkshopPresentation.humanizeAudienceOrField(
              instruction.targetCustomer,
            ),
          ),
          _kv('해결하려는 문제', instruction.customerProblem),
          _kv('제작 목적', instruction.businessPurpose),
          _kv('핵심 가치', instruction.valueProposition),
        ]),
        if (c != null) ...[
          const SizedBox(height: 12),
          _section('요구·구성', [
            if (c.projectDefinition.selectedTopics.isNotEmpty)
              _kv(
                '선택 주제',
                c.projectDefinition.selectedTopics
                    .map(
                      WorkInstructionWorkshopPresentation
                          .humanizeAudienceOrField,
                    )
                    .join(' · '),
              ),
            if (c.projectDefinition.userMemo.trim().isNotEmpty)
              _kv('추가 메모', c.projectDefinition.userMemo),
            for (final e in c.productionSpec.spec.entries)
              _kv(_humanSpecKey(e.key), _humanSpecValue('${e.value}')),
            if (c.productionSpec.undecidedKeys.isNotEmpty)
              _kv('미정 항목', c.productionSpec.undecidedKeys.join(', ')),
          ]),
          const SizedBox(height: 12),
          _section('범위·품질', [
            if (c.scope.included.isNotEmpty)
              _kv('포함', c.scope.included.take(8).join(' · ')),
            if (c.scope.excluded.isNotEmpty)
              _kv('제외', c.scope.excluded.take(6).join(' · ')),
            if (c.qualityCriteria.isNotEmpty)
              _kv('품질 요구', c.qualityCriteria.map((q) => q.label).join(', ')),
          ]),
          const SizedBox(height: 12),
          _section('승인·진행', [
            _kv('기획 승인', c.approval.planning),
            _kv('제작 승인', c.approval.production),
            _kv('공개·배포', '${c.approval.publishing} / ${c.approval.deployment}'),
          ]),
        ] else ...[
          const SizedBox(height: 12),
          _section('추가 정보', [
            if (instruction.requiredMaterials.isNotEmpty)
              _kv('필요 자료', instruction.requiredMaterials.join(', ')),
            if (instruction.qualityChecks.isNotEmpty)
              _kv('품질 확인', instruction.qualityChecks.join(', ')),
          ]),
        ],
        if (instruction.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('추가 사용자 요구', [_kv('메모', instruction.notes)]),
        ],
        if (quality.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('작업지시 품질 점검 (요약)', [
            for (final q in quality)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${q.area}: ${q.status}${q.note != null ? ' (${q.note})' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              '향후 결과물 검토 시 작업지시 충분성 판단에 사용합니다.',
              style: TextStyle(fontSize: 11.5, color: ControlColors.textMuted),
            ),
          ]),
        ],
        if (validation != null && validation!.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('확인 필요', [
            Text(
              WorkInstructionWorkshopPresentation.validationHeadline(
                validation!,
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final line
                in WorkInstructionWorkshopPresentation.validationProblemLines(
                  validation!,
                ))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ControlColors.textSecondary,
                  ),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _advancedOpen = !_advancedOpen),
          child: Text(_advancedOpen ? '고급 원문 닫기' : '고급 원문 보기'),
        ),
        if (_advancedOpen) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ControlColors.surface,
              border: Border.all(color: ControlColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(instruction.toJson()),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _artifactLabel() {
    final a = ArtifactType.labelKo(instruction.artifactType);
    if (instruction.contentSubtype.trim().isEmpty) return a;
    return '$a · ${ContentSubtype.labelKo(instruction.contentSubtype)}';
  }

  String _humanSpecKey(String key) {
    const map = {
      'format': '파일 형식',
      'pages': '분량',
      'tone': '문체',
      'level': '난이도',
      'pricing': '가격 정책',
      'platform': '플랫폼',
      'monetization': '수익 모델',
      'language': '제작 언어',
      'locale': '출시 지역',
    };
    return map[key] ?? key;
  }

  String _humanSpecValue(String raw) {
    final token = raw.trim();
    if (token.isEmpty) return '(미정)';
    return WorkInstructionWorkshopPresentation.humanizeAudienceOrField(token);
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
            width: 100,
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
