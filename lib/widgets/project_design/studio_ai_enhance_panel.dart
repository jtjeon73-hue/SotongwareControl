import 'package:flutter/material.dart';

import '../../models/project_design_state.dart';
import '../../services/work_instruction_requirement_enhancer.dart';
import '../../theme/control_theme.dart';

/// STEP C — AI 요구사항 보완 (로컬 규칙 기반, 즉시 제작 시작 없음).
class StudioAiEnhancePanel extends StatefulWidget {
  const StudioAiEnhancePanel({
    super.key,
    required this.state,
    required this.onApply,
    required this.onKeepOriginal,
  });

  final ProjectDesignState state;
  final void Function(RequirementEnhancementResult result) onApply;
  final VoidCallback onKeepOriginal;

  @override
  State<StudioAiEnhancePanel> createState() => _StudioAiEnhancePanelState();
}

class _StudioAiEnhancePanelState extends State<StudioAiEnhancePanel> {
  RequirementEnhancementResult? _result;
  bool _editing = false;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _runEnhance() {
    final result = WorkInstructionRequirementEnhancer.enhance(widget.state);
    setState(() {
      _result = result;
      _editing = false;
      _notesCtrl.text = result.suggestedNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ControlColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI 요구사항 보완',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '입력하신 내용을 구조화·보완합니다. 적용 전 반드시 확인하세요.',
              style: TextStyle(
                fontSize: 12.5,
                color: ControlColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (_result == null) ...[
              OutlinedButton.icon(
                key: const Key('studio_ai_enhance_run'),
                onPressed: _runEnhance,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('AI로 제작 요구사항 보완'),
              ),
            ] else ...[
              for (final section in _result!.sections) ...[
                Text(
                  section.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                for (final bullet in section.bullets)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('· ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            bullet,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              if (_editing) ...[
                TextField(
                  controller: _notesCtrl,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '보완 내용 수정',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const Key('studio_ai_enhance_apply'),
                    onPressed: () {
                      final applied = RequirementEnhancementResult(
                        sections: _result!.sections,
                        suggestedNotes: _notesCtrl.text.trim().isEmpty
                            ? _result!.suggestedNotes
                            : _notesCtrl.text.trim(),
                        suggestedProblem: _result!.suggestedProblem,
                        suggestedOutcome: _result!.suggestedOutcome,
                      );
                      widget.onApply(applied);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('보완 내용을 적용했습니다.')),
                      );
                    },
                    child: const Text('적용'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('수정'),
                  ),
                  OutlinedButton(
                    key: const Key('studio_ai_enhance_retry'),
                    onPressed: _runEnhance,
                    child: const Text('다시 보완'),
                  ),
                  TextButton(
                    key: const Key('studio_ai_enhance_keep'),
                    onPressed: () {
                      setState(() => _result = null);
                      widget.onKeepOriginal();
                    },
                    child: const Text('원래 내용 유지'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
