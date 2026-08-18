import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/business_planning.dart';
import '../../services/instruction_contract_validator.dart';
import '../../services/work_instruction_document_presentation.dart';
import '../../services/work_instruction_workshop_presentation.dart';
import '../../theme/control_theme.dart';

Future<void> showWorkInstructionViewer(
  BuildContext context, {
  required WorkInstruction instruction,
  ContractValidationResult? validation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        key: const Key('instruction_viewer_sheet'),
        height: h * 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '작업지시 내용',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: WorkInstructionDocumentPresentation.copyText(
                            instruction,
                          ),
                        ),
                      );
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('작업지시 내용을 복사했습니다.')),
                      );
                    },
                    child: const Text('내용 복사'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: InstructionPreviewPanel(
                  instruction: instruction,
                  validation: validation,
                  showCopyButton: false,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// 작업지시서 — 모바일 우선 단일 열 문서형 상세 (raw JSON은 고급 원문).
class InstructionPreviewPanel extends StatefulWidget {
  const InstructionPreviewPanel({
    super.key,
    required this.instruction,
    this.validation,
    this.showQualityHints = true,
    this.showCopyButton = true,
  });

  final WorkInstruction instruction;
  final ContractValidationResult? validation;
  final bool showQualityHints;
  final bool showCopyButton;

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
    final quality = widget.showQualityHints
        ? WorkInstructionWorkshopPresentation.qualityHints(instruction)
        : const <InstructionQualityHint>[];
    final sections = WorkInstructionDocumentPresentation.sections(instruction);

    return Column(
      key: const Key('instruction_preview_doc'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showCopyButton) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('instruction_copy_content'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                await Clipboard.setData(
                  ClipboardData(
                    text: WorkInstructionDocumentPresentation.copyText(
                      instruction,
                    ),
                  ),
                );
                if (!mounted) return;
                messenger?.showSnackBar(
                  const SnackBar(content: Text('작업지시 내용을 복사했습니다.')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('내용 복사'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _section(sections[i].title, [
            for (final field in sections[i].fields)
              _kv(field.label, field.value),
          ]),
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
              color: ControlColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ControlColors.border),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(instruction.toJson()),
              style: const TextStyle(fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ],
    );
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
    final text = v.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            k,
            style: const TextStyle(
              fontSize: 12,
              color: ControlColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            softWrap: true,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
        ],
      ),
    );
  }
}
