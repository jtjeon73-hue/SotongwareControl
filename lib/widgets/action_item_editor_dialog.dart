import 'package:flutter/material.dart';

import '../models/action_item.dart';
import '../theme/control_theme.dart';

class ActionItemEditorDialog extends StatefulWidget {
  const ActionItemEditorDialog({super.key, this.item});

  final ActionItem? item;

  static Future<ActionItem?> show(BuildContext context, {ActionItem? item}) {
    return showDialog<ActionItem>(
      context: context,
      builder: (_) => ActionItemEditorDialog(item: item),
    );
  }

  @override
  State<ActionItemEditorDialog> createState() => _ActionItemEditorDialogState();
}

class _ActionItemEditorDialogState extends State<ActionItemEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _department;
  late final TextEditingController _dueText;
  late final TextEditingController _expectedResult;
  late final TextEditingController _memo;
  late ActionPriority _priority;
  late ActionStatus _status;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _department = TextEditingController(text: item?.department ?? '앱개발');
    _dueText = TextEditingController(text: item?.dueText ?? '오늘');
    _expectedResult = TextEditingController(text: item?.expectedResult ?? '');
    _memo = TextEditingController(text: item?.memo ?? '');
    _priority = item?.priority ?? ActionPriority.medium;
    _status = item?.status ?? ActionStatus.scheduled;
  }

  @override
  void dispose() {
    _title.dispose();
    _department.dispose();
    _dueText.dispose();
    _expectedResult.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ControlColors.cardBg,
      title: Text(isEditing ? '작업 수정' : '새 작업 추가'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('제목', _title),
              _field('부서', _department),
              _field('기한 텍스트', _dueText, hint: '오늘 / 이번 주 / 지연'),
              _field('기대 결과', _expectedResult, maxLines: 2),
              _field('메모', _memo, maxLines: 3),
              const SizedBox(height: 12),
              _dropdown<ActionPriority>(
                label: '우선순위',
                value: _priority,
                items: ActionPriority.values,
                labelBuilder: (v) => v.label,
                onChanged: (v) => setState(() => _priority = v!),
              ),
              _dropdown<ActionStatus>(
                label: '상태',
                value: _status,
                items: ActionStatus.values,
                labelBuilder: (v) => v.label,
                onChanged: (v) => setState(() => _status = v!),
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
        FilledButton(onPressed: _save, child: Text(isEditing ? '저장' : '추가')),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
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
        widget.item?.id ?? 'action_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
      context,
      ActionItem(
        id: id,
        title: _title.text.trim(),
        department: _department.text.trim(),
        priority: _priority,
        status: _status,
        dueText: _dueText.text.trim(),
        expectedResult: _expectedResult.text.trim(),
        memo: _memo.text.trim(),
        dueDateIso: widget.item?.dueDateIso,
      ),
    );
  }
}
