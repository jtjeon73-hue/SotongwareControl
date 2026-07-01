import 'package:flutter/material.dart';
import '../models/promotion_channel.dart';
import '../theme/control_theme.dart';

class PromotionChannelCard extends StatelessWidget {
  const PromotionChannelCard({super.key, required this.channel});

  final PromotionChannel channel;

  Color get _statusColor {
    switch (channel.status) {
      case PromotionStatus.notStarted:
        return ControlColors.textMuted;
      case PromotionStatus.inProgress:
        return ControlColors.sandBeige;
      case PromotionStatus.ready:
        return ControlColors.teal;
      case PromotionStatus.active:
        return ControlColors.teal;
    }
  }

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
                    channel.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    channel.status.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              channel.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: ControlColors.teal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    channel.nextAction,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ControlColors.teal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PromoSiteCard extends StatelessWidget {
  const PromoSiteCard({super.key, required this.site});

  final PromoSiteStatus site;

  Color get _statusColor {
    switch (site.status) {
      case PromotionStatus.notStarted:
        return ControlColors.textMuted;
      case PromotionStatus.inProgress:
        return ControlColors.sandBeige;
      case PromotionStatus.ready:
      case PromotionStatus.active:
        return ControlColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.projectName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        site.siteName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    site.status.label,
                    style: TextStyle(fontSize: 10, color: _statusColor),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 8),
            Text(
              site.nextAction,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: ControlColors.teal,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.link_off,
                  size: 12,
                  color: ControlColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  site.urlPlaceholder,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: ControlColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
