import 'package:flutter/material.dart';

import '../models/action_item.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import '../utils/due_text_helper.dart';
import '../widgets/action_item_editor_dialog.dart';
import '../widgets/control_section_title.dart';

class ActionItemsScreen extends StatelessWidget {
  const ActionItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final items = state.actionsWithEffectiveStatus;
        final active = items.where((a) => !a.isDone).toList();
        final done = items.where((a) => a.isDone).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: ControlSectionTitle(
                      title: '작업 관리',
                      subtitle: '추가 · 수정 · 완료 · 상태 변경 · 로컬 저장',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('새 작업'),
                  ),
                ],
              ),
              _SummaryRow(
                active: active.length,
                done: done.length,
                delayed: active
                    .where(
                      (a) =>
                          DueTextHelper.resolveEffectiveStatus(a) ==
                          ActionStatus.delayed,
                    )
                    .length,
              ),
              const SizedBox(height: 16),
              ControlSectionTitle(
                title: '미완료 작업',
                subtitle: '${active.length}건',
              ),
              if (active.isEmpty)
                const _EmptyHint(text: '미완료 작업이 없습니다.')
              else
                ...active.map((item) => _ActionManageCard(item: item)),
              const SizedBox(height: 24),
              ControlSectionTitle(title: '완료된 작업', subtitle: '${done.length}건'),
              if (done.isEmpty)
                const _EmptyHint(text: '완료된 작업이 없습니다.')
              else
                ...done.map((item) => _ActionManageCard(item: item)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final state = ControlScope.of(context);
    final item = await ActionItemEditorDialog.show(context);
    if (item != null) await state.addAction(item);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.active,
    required this.done,
    required this.delayed,
  });

  final int active;
  final int done;
  final int delayed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        _chip('미완료 $active', ControlColors.teal),
        _chip('완료 $done', ControlColors.textMuted),
        _chip('지연 $delayed', ControlColors.accentWarm),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

class _ActionManageCard extends StatelessWidget {
  const _ActionManageCard({required this.item});

  final ActionItem item;

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);
    final effective = DueTextHelper.resolveEffectiveStatus(item);
    final isDone = effective == ActionStatus.done;
    final isDelayed = effective == ActionStatus.delayed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isDone,
                  onChanged: (_) => state.toggleActionDone(item.id),
                  activeColor: ControlColors.teal,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? ControlColors.textMuted
                                  : ControlColors.textPrimary,
                            ),
                      ),
                      Text(
                        '${item.department} · ${item.dueText}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: effective, isDelayed: isDelayed),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        final updated = await ActionItemEditorDialog.show(
                          context,
                          item: item,
                        );
                        if (updated != null) await state.updateAction(updated);
                      case 'delete':
                        await state.deleteAction(item.id);
                      case 'done':
                        await state.toggleActionDone(item.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'done', child: Text('완료 토글')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ],
            ),
            if (item.expectedResult.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '기대 결과: ${item.expectedResult}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (item.memo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '메모: ${item.memo}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: ControlColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _quickStatus(context, ActionStatus.scheduled, '예정'),
                _quickStatus(context, ActionStatus.inProgress, '진행중'),
                _quickStatus(context, ActionStatus.delayed, '지연'),
                _priorityMenu(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStatus(BuildContext context, ActionStatus status, String label) {
    final state = ControlScope.of(context);
    final current = DueTextHelper.resolveEffectiveStatus(item);
    final selected = current == status;

    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: selected
          ? ControlColors.teal.withValues(alpha: 0.2)
          : ControlColors.slate,
      onPressed: () => state.updateAction(item.copyWith(status: status)),
    );
  }

  Widget _priorityMenu(BuildContext context) {
    final state = ControlScope.of(context);
    return PopupMenuButton<ActionPriority>(
      tooltip: '우선순위',
      child: Chip(
        label: Text(
          '우선순위: ${item.priority.label}',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      onSelected: (p) => state.updateAction(item.copyWith(priority: p)),
      itemBuilder: (_) => ActionPriority.values
          .map((p) => PopupMenuItem(value: p, child: Text(p.label)))
          .toList(),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isDelayed});

  final ActionStatus status;
  final bool isDelayed;

  @override
  Widget build(BuildContext context) {
    final color = isDelayed
        ? ControlColors.accentWarm
        : status == ActionStatus.done
        ? ControlColors.textMuted
        : ControlColors.teal;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
