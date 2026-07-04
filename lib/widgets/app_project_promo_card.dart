import 'package:flutter/material.dart';

import '../data/promo_sites_data.dart';
import '../models/business_division.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import 'result_link_button.dart';

class AppProjectPromoCard extends StatelessWidget {
  const AppProjectPromoCard({super.key, required this.project});

  final DivisionProject project;

  String _resolveUrl(BuildContext context) {
    if (project.promoSiteId != null) {
      final fromState = ControlScope.of(
        context,
      ).promoUrlFor(project.promoSiteId!);
      if (fromState.isNotEmpty) return fromState;
    }
    return project.promoUrl?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl(context);
    final hasUrl = url.isNotEmpty;
    final showNotice = project.needsDeploymentNotice;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (project.englishName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          project.englishName!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 12,
                                color: ControlColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (project.promoStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: project.promoStatus!.contains('운영')
                          ? ControlColors.teal.withValues(alpha: 0.15)
                          : ControlColors.accentWarm.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      project.promoStatus!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: project.promoStatus!.contains('운영')
                            ? ControlColors.teal
                            : ControlColors.accentWarm,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _Row(label: '현재 단계', value: project.currentStage),
            _Row(label: '다음 작업', value: project.nextTask),
            if (project.promoRepositoryName != null)
              _Row(label: '저장소', value: project.promoRepositoryName!),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ControlColors.slate.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ControlColors.border),
              ),
              child: Text(
                hasUrl ? url : '프로모 URL 미등록',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: hasUrl ? ControlColors.teal : ControlColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showNotice) ...[
              const SizedBox(height: 8),
              Text(
                PromoSitesData.appPromoNotDeployedNotice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 10,
                  color: ControlColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
            const Spacer(),
            ResultLinkButton.explore(
              url: url,
              label: hasUrl ? '프로모 사이트 보기' : '프로모 URL 미등록',
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
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
            ),
          ),
        ],
      ),
    );
  }
}
