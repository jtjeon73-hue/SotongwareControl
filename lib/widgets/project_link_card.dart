import 'package:flutter/material.dart';
import '../models/project_item.dart';
import '../theme/control_theme.dart';

class ProjectLinkCard extends StatelessWidget {
  const ProjectLinkCard({super.key, required this.item});

  final ProjectLinkItem item;

  Color get _typeColor {
    switch (item.type) {
      case ProjectLinkType.internal:
        return ControlColors.teal;
      case ProjectLinkType.publicPromo:
        return ControlColors.accentWarm;
      case ProjectLinkType.commerce:
        return ControlColors.sandBeige;
    }
  }

  String get _typeLabel {
    switch (item.type) {
      case ProjectLinkType.internal:
        return 'INTERNAL';
      case ProjectLinkType.publicPromo:
        return 'PUBLIC PROMO';
      case ProjectLinkType.commerce:
        return 'COMMERCE';
    }
  }

  IconData get _typeIcon {
    switch (item.type) {
      case ProjectLinkType.internal:
        return Icons.lock_outline;
      case ProjectLinkType.publicPromo:
        return Icons.public_outlined;
      case ProjectLinkType.commerce:
        return Icons.storefront_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ControlColors.slate.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ControlColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_off_outlined,
                    size: 14,
                    color: ControlColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.urlPlaceholder,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ControlColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
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
