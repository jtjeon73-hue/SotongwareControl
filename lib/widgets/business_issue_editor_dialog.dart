import 'package:flutter/material.dart';

import '../models/business_issue.dart';
import '../theme/control_theme.dart';

class BusinessIssueEditorDialog extends StatefulWidget {
  const BusinessIssueEditorDialog({super.key, this.issue});

  final BusinessIssue? issue;

  static Future<BusinessIssue?> show(
    BuildContext context, {
    BusinessIssue? issue,
  }) {
    return showDialog<BusinessIssue>(
      context: context,
      builder: (_) => BusinessIssueEditorDialog(issue: issue),
    );
  }

  @override
  State<BusinessIssueEditorDialog> createState() =>
      _BusinessIssueEditorDialogState();
}

class _BusinessIssueEditorDialogState extends State<BusinessIssueEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _division;
  late final TextEditingController _problem;
  late final TextEditingController _cause;
  late final TextEditingController _responsePlan;
  late final TextEditingController _assignedAi;
  late final TextEditingController _nextAction;
  late final TextEditingController _memo;
  late ImpactLevel _impact;
  late UrgencyLevel _urgency;
  late IssueStatus _status;

  bool get isEditing => widget.issue != null;

  @override
  void initState() {
    super.initState();
    final issue = widget.issue;
    _title = TextEditingController(text: issue?.title ?? '');
    _division = TextEditingController(text: issue?.divisionName ?? '');
    _problem = TextEditingController(text: issue?.problem ?? '');
    _cause = TextEditingController(text: issue?.cause ?? '');
    _responsePlan = TextEditingController(text: issue?.responsePlan ?? '');
    _assignedAi = TextEditingController(text: issue?.assignedAiRole ?? '');
    _nextAction = TextEditingController(text: issue?.nextAction ?? '');
    _memo = TextEditingController(text: issue?.memo ?? '');
    _impact = issue?.impactLevel ?? ImpactLevel.medium;
    _urgency = issue?.urgencyLevel ?? UrgencyLevel.medium;
    _status = issue?.status ?? IssueStatus.unresolved;
  }

  @override
  void dispose() {
    _title.dispose();
    _division.dispose();
    _problem.dispose();
    _cause.dispose();
    _responsePlan.dispose();
    _assignedAi.dispose();
    _nextAction.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ControlColors.cardBg,
      title: Text(isEditing ? '문제 수정' : '새 문제 등록'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('제목', _title),
              _field('사업부', _division),
              _field('현재 문제', _problem, maxLines: 2),
              _field('문제 원인', _cause, maxLines: 2),
              _field('대응 방안', _responsePlan, maxLines: 2),
              _field('담당 AI', _assignedAi),
              _field('다음 액션', _nextAction),
              _field('메모', _memo, maxLines: 2),
              _dropdown<ImpactLevel>(
                '영향도',
                _impact,
                ImpactLevel.values,
                (v) => v.label,
                (v) => setState(() => _impact = v!),
              ),
              _dropdown<UrgencyLevel>(
                '긴급도',
                _urgency,
                UrgencyLevel.values,
                (v) => v.label,
                (v) => setState(() => _urgency = v!),
              ),
              _dropdown<IssueStatus>(
                '상태',
                _status,
                IssueStatus.values,
                (v) => v.label,
                (v) => setState(() => _status = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: Text(isEditing ? '저장' : '등록')),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> items,
    String Function(T) labelBuilder,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(value: e, child: Text(labelBuilder(e))),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final id =
        widget.issue?.id ?? 'issue_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
      context,
      BusinessIssue(
        id: id,
        title: _title.text.trim(),
        divisionName: _division.text.trim(),
        problem: _problem.text.trim(),
        cause: _cause.text.trim(),
        impactLevel: _impact,
        urgencyLevel: _urgency,
        responsePlan: _responsePlan.text.trim(),
        assignedAiRole: _assignedAi.text.trim(),
        nextAction: _nextAction.text.trim(),
        status: _status,
        memo: _memo.text.trim(),
      ),
    );
  }
}
