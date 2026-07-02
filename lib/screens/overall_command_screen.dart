import 'package:flutter/material.dart';

import '../data/management_hub_data.dart';
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
                title: '전체사업관리관제',
                subtitle:
                    '소통웨어 4개 사업부·4개 관리부서의 운영 비전, 우선순위, '
                    '수익·발전 포인트를 한 화면에서 체험할 수 있는 데모 대시보드입니다.',
                badge: '통합 컨트롤 · 데모',
                trailing: _HealthBadge(stats: stats),
              ),
              const SizedBox(height: 16),
              const PublicDemoNotice(compact: true),
              const SizedBox(height: 24),
              _QuickMetrics(stats: stats, onNavigate: onNavigate),
              const SizedBox(height: 28),
              ControlSectionTitle(
                title: '사업부 진행현황',
                subtitle: '4개 사업부 · 진행률 · 다음 액션',
              ),
              _StatusGrid(items: ManagementHubData.divisionStatuses),
              const SizedBox(height: 28),
              ControlSectionTitle(
                title: '관리부서 진행현황',
                subtitle: '기획 · 홍보 · 재무 · 고객대응',
              ),
              _StatusGrid(items: ManagementHubData.departmentStatuses),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 1000;
                  final left = [
                    HubListSection(
                      title: '최근 체크포인트',
                      items: ManagementHubData.checkPoints
                          .map((c) => '[${c.area}] ${c.title}')
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    HubListSection(
                      title: '우선 처리 필요',
                      items: ManagementHubData.priorityItems,
                      icon: Icons.priority_high,
                      iconColor: ControlColors.accentRose,
                    ),
                  ];
                  final right = [
                    HubListSection(
                      title: '수익 연결 가능',
                      items: ManagementHubData.revenueItems,
                      icon: Icons.trending_up,
                      iconColor: ControlColors.accentGreen,
                    ),
                    const SizedBox(height: 16),
                    HubListSection(
                      title: '발전 가능 항목',
                      items: ManagementHubData.growthItems,
                      icon: Icons.rocket_launch_outlined,
                      iconColor: ControlColors.sandBeige,
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
              const SizedBox(height: 16),
              HubListSection(
                title: '다음 액션 제안',
                items: ManagementHubData.nextActions,
                icon: Icons.play_arrow_rounded,
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

class _QuickMetrics extends StatelessWidget {
  const _QuickMetrics({required this.stats, required this.onNavigate});

  final DashboardStats stats;
  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('진행 작업', '${stats.inProgressCount}건', ControlDestination.actions),
      ('미해결 문제', '${stats.unresolvedIssueCount}건', ControlDestination.issues),
      ('지연', '${stats.delayedCount}건', ControlDestination.actions),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: ControlColors.teal),
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
        final cross = constraints.maxWidth > 1100
            ? 2
            : constraints.maxWidth > 700
            ? 2
            : 1;

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

class _AiLinkBanner extends StatelessWidget {
  const _AiLinkBanner({required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.teal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: ControlColors.teal),
          const SizedBox(width: 14),
          Expanded(
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
          FilledButton(
            onPressed: () => onNavigate(ControlDestination.aiRepresentative),
            child: const Text('AI대표 보기'),
          ),
        ],
      ),
    );
  }
}
