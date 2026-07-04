import 'package:flutter/material.dart';

import '../data/ai_control_center_data.dart';
import '../data/management_hub_data.dart';
import '../models/ai_control_center.dart';
import '../state/control_scope.dart';
import '../state/control_state.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/hub_status_card.dart';
import '../widgets/page_hero.dart';
import '../widgets/public_demo_notice.dart';
import '../widgets/sidebar_navigation.dart';

class OverallCommandScreen extends StatelessWidget {
  const OverallCommandScreen({super.key, required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final stats = state.dashboardStats;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHero(
                title: '소통총괄관제',
                subtitle:
                    '소통웨어 전체 사업을 AI가 총괄 관제합니다. '
                    '대표·사업부·수익화·실행 우선순위를 한눈에 확인하세요.',
                badge: 'AI 총괄 관제 · 대시보드',
                trailing: _HealthBadge(stats: stats),
              ),
              const SizedBox(height: 16),
              const PublicDemoNotice(compact: true),
              const SizedBox(height: 24),
              _SummaryCards(stats: stats, onNavigate: onNavigate),
              const SizedBox(height: 28),
              ControlSectionTitle(
                title: '소통사업부 진행상태',
                subtitle: '5개 사업부 · 진행률 · 다음 액션',
              ),
              _StatusGrid(items: ManagementHubData.divisionStatuses),
              const SizedBox(height: 28),
              ControlSectionTitle(
                title: 'AI부서 역할 요약',
                subtitle: '소통AI대표부 7개 부서',
              ),
              _AiRoleGrid(onNavigate: onNavigate),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 1000;
                  final left = [
                    _DashboardPanel(
                      title: '현재 수익화 단계',
                      icon: Icons.paid_outlined,
                      iconColor: ControlColors.accentGreen,
                      items: ManagementHubData.revenueStageItems,
                      onMore: () =>
                          onNavigate(ControlDestination.revenueProgress),
                    ),
                    const SizedBox(height: 16),
                    _DashboardPanel(
                      title: '해야 할 일 TOP 5',
                      icon: Icons.task_alt_outlined,
                      iconColor: ControlColors.teal,
                      items: ManagementHubData.topTasks,
                      onMore: () => onNavigate(ControlDestination.nextPriority),
                    ),
                  ];
                  final right = [
                    _DashboardPanel(
                      title: '지연/문제/검토 필요',
                      icon: Icons.warning_amber_outlined,
                      iconColor: ControlColors.accentRose,
                      items: ManagementHubData.priorityItems,
                      onMore: () => onNavigate(ControlDestination.issuesCheck),
                    ),
                    const SizedBox(height: 16),
                    _DashboardPanel(
                      title: '다음 실행 추천',
                      icon: Icons.rocket_launch_rounded,
                      iconColor: ControlColors.sandBeige,
                      items: ManagementHubData.nextActions,
                      onMore: () => onNavigate(ControlDestination.nextPriority),
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: left)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(children: right)),
                      ],
                    );
                  }
                  return Column(
                    children: [...left, const SizedBox(height: 8), ...right],
                  );
                },
              ),
              const SizedBox(height: 28),
              ControlSectionTitle(
                title: 'AI대표 종합 보고',
                subtitle:
                    'AI홍보.마케팅부 피드백 반영 · 소통총괄관제 수신 보고 ${AiControlCenterData.ceoHubReports.length}건',
              ),
              ...AiControlCenterData.ceoHubReports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CeoHubReportPanel(
                    report: report,
                    onDetail: () =>
                        onNavigate(ControlDestination.aiRepresentative),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _DashboardPanel(
                title: '대표 확인 필요 항목',
                icon: Icons.approval_outlined,
                iconColor: ControlColors.accentWarm,
                items: ManagementHubData.ceoReviewItems,
                onMore: () => onNavigate(ControlDestination.aiRepresentative),
              ),
              const SizedBox(height: 20),
              _AiLinkBanner(onNavigate: onNavigate),
            ],
          ),
        );
      },
    );
  }
}

class DivisionProgressScreen extends StatelessWidget {
  const DivisionProgressScreen({super.key, required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  static const _divisionLinks = [
    (ControlDestination.industrialAutomation, '소통자동화'),
    (ControlDestination.appDevelopment, '소통앱개발'),
    (ControlDestination.youtubeContent, '소통콘텐츠'),
    (ControlDestination.ebook, '소통전자책'),
    (ControlDestination.onlineExpansion, '온라인판매/확장'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: '사업부별 진행상태',
            subtitle: '소통사업부 5개 영역의 진행률, 우선순위, 다음 액션을 확인합니다.',
            badge: '소통총괄관제',
          ),
          const SizedBox(height: 24),
          _StatusGrid(items: ManagementHubData.divisionStatuses),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _divisionLinks
                .map(
                  (link) => ActionChip(
                    avatar: const Icon(Icons.arrow_forward, size: 16),
                    label: Text('${link.$2} 상세'),
                    onPressed: () => onNavigate(link.$1),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.stats, required this.onNavigate});

  final DashboardStats stats;
  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('진행 작업', '${stats.inProgressCount}건', ControlDestination.nextPriority),
      (
        '미해결 문제',
        '${stats.unresolvedIssueCount}건',
        ControlDestination.issuesCheck,
      ),
      ('지연', '${stats.delayedCount}건', ControlDestination.issuesCheck),
      (
        'AI 보고',
        '${stats.aiReportNeededCount}건',
        ControlDestination.aiRepresentative,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tiles.map((t) {
        return InkWell(
          onTap: () => onNavigate(t.$3),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ControlColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ControlColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.$2,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ControlColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.$1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: ControlColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.items});

  final List<HubStatusItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth > 700 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisExtent: 210,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => HubStatusCard(item: items[index]),
        );
      },
    );
  }
}

class _AiRoleGrid extends StatelessWidget {
  const _AiRoleGrid({required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisExtent: 130,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: ManagementHubData.aiDepartmentRoles.length,
          itemBuilder: (context, index) {
            final role = ManagementHubData.aiDepartmentRoles[index];
            return InkWell(
              onTap: () => onNavigate(role.destination),
              borderRadius: BorderRadius.circular(14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(role.icon, size: 18, color: ControlColors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              role.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          role.summary,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    this.onMore,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;
  final VoidCallback? onMore;

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
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onMore != null)
                  TextButton(onPressed: onMore, child: const Text('더보기')),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: ControlColors.teal),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 13),
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

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final color = stats.healthScore >= 75
        ? ControlColors.accentGreen
        : ControlColors.accentWarm;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        children: [
          Text(
            '${stats.healthScore}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(stats.healthLabel, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _CeoHubReportPanel extends StatelessWidget {
  const _CeoHubReportPanel({required this.report, required this.onDetail});

  final CeoHubReport report;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 13);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.summarize_outlined,
                  color: ControlColors.teal,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.sourceDepartment} · ${report.reportedAt}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _ReportStatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(report.summary, style: bodyStyle),
            const SizedBox(height: 12),
            Text(
              '핵심 포인트',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...report.keyPoints.map((p) => Text('• $p', style: bodyStyle)),
            const SizedBox(height: 10),
            Text(
              '대표 확인·실행 항목',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...report.actionsRequired.map(
              (a) => Text('• $a', style: bodyStyle),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDetail,
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('AI대표 상세 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportStatusChip extends StatelessWidget {
  const _ReportStatusChip({required this.status});

  final AiSystemStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AiSystemStatus.monitoring => ('관제 중', ControlColors.teal),
      AiSystemStatus.automaticReportPending => ('보고 대기', ControlColors.accentWarm),
      AiSystemStatus.approvalRequired => ('승인 필요', ControlColors.accentRose),
      _ => (status.label, ControlColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _AiLinkBanner extends StatelessWidget {
  const _AiLinkBanner({required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            ControlColors.heroGradientStart,
            ControlColors.heroGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.teal.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: ControlColors.teal,
            size: 28,
          ),
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI대표 종합 브리핑',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  ManagementHubData.visionNote,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => onNavigate(ControlDestination.aiRepresentative),
            icon: const Icon(Icons.psychology_outlined, size: 18),
            label: const Text('AI대표 보기'),
          ),
        ],
      ),
    );
  }
}
