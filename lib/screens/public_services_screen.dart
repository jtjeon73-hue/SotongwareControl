import 'package:flutter/material.dart';

import '../core/constants/external_site_links.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../widgets/page_hero.dart';

/// 로그인 후 전용 — 소통웨어 공개 사이트 허브
class PublicServicesScreen extends StatelessWidget {
  const PublicServicesScreen({super.key});

  IconData _iconFor(String key) {
    switch (key) {
      case 'apps':
        return Icons.phone_android_outlined;
      case 'ebook':
        return Icons.auto_stories_outlined;
      case 'contents':
        return Icons.play_circle_outline;
      case 'ai_story':
        return Icons.auto_awesome_outlined;
      case 'marketing':
        return Icons.campaign_outlined;
      case 'industrial':
        return Icons.precision_manufacturing_outlined;
      default:
        return Icons.public_outlined;
    }
  }

  Future<void> _open(BuildContext context, ExternalSiteLink site) async {
    final ok = await ExternalUrl.open(site.url);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${site.title} 사이트를 열 수 없습니다. 네트워크를 확인해 주세요.'),
          backgroundColor: ControlColors.accentWarm,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100
        ? 3
        : width >= 700
        ? 2
        : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: '소통웨어 공개 서비스',
            subtitle:
                '소통웨어에서 운영 중인 각 사업·정보 서비스의 공개 사이트를 '
                '한 곳에서 확인하고 새 탭으로 이동합니다.',
            badge: '공개 허브',
          ),
          const SizedBox(height: 8),
          Text(
            '링크는 새 브라우저 탭에서 열리며, 현재 소통총관제 로그인 세션은 유지됩니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ControlColors.textMuted),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final sites = ExternalSiteLinks.hubSites;
              if (crossAxisCount == 1) {
                return Column(
                  children: [
                    for (final site in sites) ...[
                      _SiteCard(
                        site: site,
                        icon: _iconFor(site.icon),
                        onOpen: () => _open(context, site),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final site in sites)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (crossAxisCount - 1) * 12) /
                          crossAxisCount,
                      child: _SiteCard(
                        site: site,
                        icon: _iconFor(site.icon),
                        onOpen: () => _open(context, site),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.icon,
    required this.onOpen,
  });

  final ExternalSiteLink site;
  final IconData icon;
  final VoidCallback onOpen;

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ControlColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: ControlColors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        site.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              site.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(site.statusLabel),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: ControlColors.tealSoft,
                ),
                const Chip(
                  label: Text('Firebase Hosting'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('사이트 열기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 대시보드용 요약 바로가기
class PublicServicesSummaryStrip extends StatelessWidget {
  const PublicServicesSummaryStrip({super.key, required this.onOpenHub});

  final VoidCallback onOpenHub;

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
                  child: Text(
                    '공개 서비스 운영',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: onOpenHub, child: const Text('전체 보기')),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '소통웨어 공개 사이트로 바로 이동합니다. (새 탭)',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ControlColors.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final site in ExternalSiteLinks.requiredSites)
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 16),
                    label: Text(site.title.replaceFirst('소통웨어 ', '')),
                    onPressed: () async {
                      final ok = await ExternalUrl.open(site.url);
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('사이트를 열 수 없습니다.')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
