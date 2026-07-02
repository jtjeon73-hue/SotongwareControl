import 'package:flutter/material.dart';
import '../data/management_hub_data.dart';
import '../theme/control_theme.dart';

class HubStatusCard extends StatelessWidget {
  const HubStatusCard({super.key, required this.item});

  final HubStatusItem item;

  Color get _progressColor {
    if (item.progress >= 70) return ControlColors.accentGreen;
    if (item.progress >= 45) return ControlColors.teal;
    return ControlColors.accentWarm;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ControlColors.sandLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.tag!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ControlColors.sandBeige,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress / 100,
                      minHeight: 8,
                      backgroundColor: ControlColors.slate,
                      color: _progressColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${item.progress}%',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: _progressColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(context, '상태', item.status),
            _row(context, '우선순위', item.priority),
            const SizedBox(height: 4),
            Text(
              '다음: ${item.nextAction}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: ControlColors.teal,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class HubListSection extends StatelessWidget {
  const HubListSection({
    super.key,
    required this.title,
    required this.items,
    this.icon = Icons.check_circle_outline,
    this.iconColor = ControlColors.teal,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
