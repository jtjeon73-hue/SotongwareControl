import 'package:flutter/material.dart';

import '../../data/business_departments/business_department_config.dart';
import '../../theme/control_theme.dart';
import '../../utils/external_url.dart';

/// 사업부 공통 화면: A~F 섹션.
class BusinessDepartmentScreen extends StatelessWidget {
  const BusinessDepartmentScreen({super.key, required this.config});

  final BusinessDepartmentConfig config;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          config.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          config.purpose,
          style: const TextStyle(color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: '연동 사이트'),
        const SizedBox(height: 8),
        _LinkedSites(sites: config.linkedSites),
        const SizedBox(height: 18),
        _SectionTitle(title: '사업 기본지식'),
        const SizedBox(height: 8),
        ...config.knowledge.map(
          (k) => _AccordCard(title: k.title, body: k.body),
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: '연동 사이트 현재상태 요약'),
        const SizedBox(height: 8),
        ...config.linkedSites.map(_SiteStatusCard.new),
        const SizedBox(height: 18),
        _SectionTitle(title: '기술트렌드 요약'),
        const SizedBox(height: 8),
        _TrendBlock(trends: config.trends),
        const SizedBox(height: 18),
        _SectionTitle(title: '영업전략 요약'),
        const SizedBox(height: 8),
        _SalesBlock(sales: config.sales),
        const SizedBox(height: 18),
        _SectionTitle(title: '수익구조 요약'),
        const SizedBox(height: 8),
        _ChipWrap(items: config.revenue.items),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LinkedSites extends StatelessWidget {
  const _LinkedSites({required this.sites});
  final List<LinkedSiteSummary> sites;

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) {
      return const Text('등록된 연동 사이트가 없습니다.',
          style: TextStyle(color: ControlColors.textMuted));
    }
    if (sites.length == 1) {
      final s = sites.first;
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => ExternalUrl.open(s.url),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text('연동 사이트 열기 · ${s.name}'),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in sites)
          OutlinedButton.icon(
            onPressed: () => ExternalUrl.open(s.url),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(s.name),
          ),
      ],
    );
  }
}

class _AccordCard extends StatelessWidget {
  const _AccordCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: ControlColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ControlColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(body),
          ),
        ],
      ),
    );
  }
}

class _SiteStatusCard extends StatelessWidget {
  const _SiteStatusCard(this.site);
  final LinkedSiteSummary site;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ControlColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(site.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${site.serviceName} · ${site.status}',
              style: const TextStyle(
                  fontSize: 12, color: ControlColors.textMuted)),
          if (site.lastChecked.isNotEmpty)
            Text('마지막 확인: ${site.lastChecked}',
                style: const TextStyle(fontSize: 12)),
          if (site.contentStatus.isNotEmpty)
            Text('콘텐츠: ${site.contentStatus}',
                style: const TextStyle(fontSize: 12)),
          if (site.mainFeatures.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('주요 기능: ${site.mainFeatures.join(', ')}',
                style: const TextStyle(fontSize: 12)),
          ],
          if (site.improvements.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('개선 필요: ${site.improvements.join(', ')}',
                style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ExternalUrl.open(site.url),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('사이트 열기'),
          ),
        ],
      ),
    );
  }
}

class _TrendBlock extends StatelessWidget {
  const _TrendBlock({required this.trends});
  final TrendSummary trends;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AccordCard(title: '현재 핵심 기술', body: trends.coreTech.join(' · ')),
        _AccordCard(title: '변화하는 기술', body: trends.changingTech.join(' · ')),
        _AccordCard(title: 'AI 활용 포인트', body: trends.aiPoints.join(' · ')),
        _AccordCard(title: '앞으로 주목할 기술', body: trends.watchlist.join(' · ')),
        _AccordCard(title: '우리 사업에 적용할 것', body: trends.applyNow.join(' · ')),
      ],
    );
  }
}

class _SalesBlock extends StatelessWidget {
  const _SalesBlock({required this.sales});
  final SalesStrategySummary sales;

  @override
  Widget build(BuildContext context) {
    Widget row(String t, List<String> items) =>
        _AccordCard(title: t, body: items.isEmpty ? '-' : items.join(' · '));
    return Column(
      children: [
        row('고객군', sales.customerGroups),
        row('고객을 찾을 장소', sales.whereToFind),
        row('영업 방식', sales.methods),
        row('제안 방법', sales.proposal),
        row('무료→유료 전환', sales.freeToPaid),
        row('기존 고객 관리', sales.existingCustomers),
        row('소개 영업', sales.referral),
        row('온라인 영업', sales.online),
        row('오프라인 영업', sales.offline),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in items)
          Chip(
            label: Text(i),
            backgroundColor: ControlColors.surfaceMuted,
            side: const BorderSide(color: ControlColors.border),
          ),
      ],
    );
  }
}
