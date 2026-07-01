import 'package:flutter/material.dart';

import '../data/promo_sites_data.dart';
import '../theme/control_theme.dart';

class AppDevelopmentPromoSummary extends StatelessWidget {
  const AppDevelopmentPromoSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '개별 프로모 연결 현황',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final tiles = [
                  _Tile(
                    value: '${PromoSitesData.appPromoCount}개',
                    label: '총 관리 앱',
                  ),
                  _Tile(
                    value: '${PromoSitesData.linkedAppPromoUrlCount}개',
                    label: '연결된 개별 프로모 URL',
                    color: ControlColors.teal,
                  ),
                  _Tile(
                    value: PromoSitesData.appsNeedingDeploymentCheck.join(', '),
                    label: '실제 배포 확인 필요',
                    color: ControlColors.accentWarm,
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: tiles
                        .map(
                          (t) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: t,
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return Column(
                  children: tiles
                      .map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: t,
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

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: color ?? ControlColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
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
