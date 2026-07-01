import 'package:flutter/material.dart';
import '../models/finance_item.dart';
import '../theme/control_theme.dart';

class FinanceItemCard extends StatelessWidget {
  const FinanceItemCard({super.key, required this.item});

  final FinanceItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (item.amountHint != null)
                  Text(
                    item.amountHint!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ControlColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ControlColors.slate.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '상태: ${item.statusText}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.arrow_right,
                  size: 14,
                  color: ControlColors.teal,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.actionNeeded,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ControlColors.teal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (item.cautionNote != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ControlColors.warningBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ControlColors.accentWarm.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: ControlColors.accentWarm,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.cautionNote!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: ControlColors.accentWarm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
