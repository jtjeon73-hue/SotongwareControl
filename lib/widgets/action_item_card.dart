import 'package:flutter/material.dart';

import '../models/action_item.dart';
import '../theme/control_theme.dart';
import '../utils/due_text_helper.dart';

class ActionItemCard extends StatelessWidget {
  const ActionItemCard({super.key, required this.item});

  final ActionItem item;

  Color get _priorityColor {
    switch (item.priority) {
      case ActionPriority.high:
        return ControlColors.accentWarm;
      case ActionPriority.medium:
        return ControlColors.teal;
      case ActionPriority.low:
        return ControlColors.textMuted;
    }
  }

  Color get _statusColor {
    final status = DueTextHelper.resolveEffectiveStatus(item);
    switch (status) {
      case ActionStatus.done:
        return ControlColors.textMuted;
      case ActionStatus.delayed:
        return ControlColors.accentWarm;
      case ActionStatus.inProgress:
        return ControlColors.teal;
      case ActionStatus.scheduled:
        return ControlColors.sandBeige;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effective = DueTextHelper.resolveEffectiveStatus(item);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: _priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration: item.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ),
                      _Badge(label: item.priority.label, color: _priorityColor),
                      const SizedBox(width: 6),
                      _Badge(label: effective.label, color: _statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.department} · ${item.dueText}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: ControlColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '기대 결과: ${item.expectedResult}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
