import 'package:flutter/material.dart';

import '../data/promo_sites_data.dart';
import '../models/promo_site_link.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/private_public_notice.dart';
import '../widgets/promo_site_card.dart';

class ProjectLinkScreen extends StatelessWidget {
  const ProjectLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: 16),
              const PrivatePublicNotice(),
              const SizedBox(height: 24),
              _VisibilityLegend(),
              const SizedBox(height: 28),
              const ControlSectionTitle(
                title: 'PRIVATE · 내부 관제센터',
                subtitle: '외부 공개하지 않는 개인용 사이트',
              ),
              ...PromoSitesData.privateSites.map(
                (site) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PromoSiteCard(site: site),
                ),
              ),
              const SizedBox(height: 28),
              const ControlSectionTitle(
                title: 'PUBLIC · 사업 총괄 홍보사이트',
                subtitle: '4개 사업부 공개 홍보 허브 · URL 연결·사이트 열기',
              ),
              _BusinessHubGrid(sites: PromoSitesData.businessHubSites),
              const SizedBox(height: 28),
              _LinkMapDiagram(),
              const SizedBox(height: 28),
              const ControlSectionTitle(
                title: '앱별 개별 프로모 사이트',
                subtitle: 'SotongAppsPromo 하위 · 6개 앱 프로모 URL 연결',
              ),
              _ChildSitesGrid(sites: PromoSitesData.appChildSites),
              const SizedBox(height: 28),
              const ControlSectionTitle(
                title: '판매·커머스 연결',
                subtitle: '공개 판매 채널',
              ),
              ...PromoSitesData.commerceSites.map(
                (site) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PromoSiteCard(site: site),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ControlColors.charcoal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사업 홍보사이트 링크맵',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'PRIVATE 내부 관제센터와 PUBLIC 사업 총괄 홍보사이트의 관계·상태·URL을 관리합니다.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'URL은 GitHub Pages 배포 후 등록할 수 있으며, 로컬에 저장됩니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: ControlColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _legendItem(
          Icons.lock_outline,
          'PRIVATE',
          '내부 관제·비공개',
          ControlColors.teal,
        ),
        _legendItem(
          Icons.public_outlined,
          'PUBLIC',
          'GitHub Pages 공개 홍보',
          ControlColors.sandBeige,
        ),
        _legendItem(
          Icons.check_circle_outline,
          '연결됨',
          '내부 관제센터 URL 연결 완료',
          ControlColors.teal,
        ),
      ],
    );
  }

  Widget _legendItem(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 10,
                  color: ControlColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessHubGrid extends StatelessWidget {
  const _BusinessHubGrid({required this.sites});

  final List<PromoSiteLink> sites;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 420,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: sites.length,
          itemBuilder: (context, index) {
            return PromoSiteCard(site: sites[index]);
          },
        );
      },
    );
  }
}

class _ChildSitesGrid extends StatelessWidget {
  const _ChildSitesGrid({required this.sites});

  final List<PromoSiteLink> sites;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 400,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: sites.length,
          itemBuilder: (context, index) {
            return PromoSiteCard(site: sites[index], compact: true);
          },
        );
      },
    );
  }
}

class _LinkMapDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사이트 관계도', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            Center(
              child: _DiagramNode(
                label: 'SotongWare Control Center',
                subtitle: 'PRIVATE',
                color: ControlColors.teal,
                isCenter: true,
              ),
            ),
            const SizedBox(height: 16),
            _connectorLabel('관리 · 연결'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _DiagramNode(
                  label: 'SotongAutomationPromo',
                  subtitle: '산업자동화',
                  color: ControlColors.accentWarm,
                ),
                _DiagramNode(
                  label: 'SotongAppsPromo',
                  subtitle: '앱개발',
                  color: ControlColors.accentWarm,
                ),
                _DiagramNode(
                  label: 'SotongContentsPromo',
                  subtitle: '콘텐츠',
                  color: ControlColors.accentWarm,
                ),
                _DiagramNode(
                  label: 'SotongEbookPromo',
                  subtitle: '전자책',
                  color: ControlColors.accentWarm,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _connectorLabel('SotongAppsPromo 하위'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children:
                  [
                        'SotongTravelPromo',
                        'SotongSajuPromo',
                        'FarmjigiPromo',
                        'SotongHealthPromo',
                        'SotongAIPromo',
                        'SotongSamaePromo',
                      ]
                      .map(
                        (name) => _DiagramNode(
                          label: name,
                          compact: true,
                          color: ControlColors.slate,
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectorLabel(String text) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: ControlColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: ControlColors.textMuted,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: ControlColors.border)),
      ],
    );
  }
}

class _DiagramNode extends StatelessWidget {
  const _DiagramNode({
    required this.label,
    this.subtitle,
    required this.color,
    this.isCenter = false,
    this.compact = false,
  });

  final String label;
  final String? subtitle;
  final Color color;
  final bool isCenter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: isCenter ? color.withValues(alpha: 0.12) : ControlColors.slate,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCenter ? color : ControlColors.border,
          width: isCenter ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              color: isCenter ? color : ControlColors.textSecondary,
              fontWeight: isCenter ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                color: isCenter ? color : ControlColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
