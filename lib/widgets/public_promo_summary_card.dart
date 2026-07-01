import 'package:flutter/material.dart';

import '../data/promo_sites_data.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';

class PublicPromoSummaryCard extends StatelessWidget {
  const PublicPromoSummaryCard({super.key, this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);
    final linkedCount = PromoSitesData.businessHubSites
        .where((s) => state.hasPromoUrl(s.id))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ControlColors.sandBeige.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.public,
                    color: ControlColors.sandBeige,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Public 사업 홍보사이트',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '4개 사업부 총괄 홍보 허브 연결 현황',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewAll != null)
                  TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('링크맵'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final items = [
                  _MetricTile(
                    value: '${PromoSitesData.hubCount}개',
                    label: '총괄 홍보사이트',
                  ),
                  _MetricTile(
                    value: '$linkedCount개',
                    label: '연결 완료 URL',
                    color: ControlColors.teal,
                  ),
                  _MetricTile(
                    value: '${PromoSitesData.deploymentCheckNeededCount}개',
                    label: '배포 확인 필요',
                    color: ControlColors.accentWarm,
                  ),
                  const _MetricTile(
                    value: 'SotongAppsPromo',
                    label: '개별 앱 프로모 관리',
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: items
                        .map(
                          (item) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: item,
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: (constraints.maxWidth - 8) / 2,
                          child: item,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.slate.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color ?? ControlColors.textPrimary,
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              color: ControlColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
