import 'package:flutter/material.dart';
import '../data/sample_business_data.dart';
import '../data/sample_operational_data.dart';
import '../models/action_item.dart';
import '../models/business_division.dart';
import '../models/department.dart';
import '../state/control_scope.dart';
import '../state/control_state.dart';
import '../utils/due_text_helper.dart';
import '../data/promo_sites_data.dart';
import '../theme/control_theme.dart';
import '../widgets/action_item_card.dart';
import '../widgets/ai_daily_summary_panel.dart';
import '../widgets/business_status_card.dart';
import '../widgets/control_section_title.dart';
import '../widgets/department_status_card.dart';
import '../widgets/operational_metric_card.dart';
import '../widgets/promo_site_card.dart';
import '../widgets/sidebar_navigation.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final stats = state.dashboardStats;
        final divisions = SampleBusinessData.divisions;
        final departments = SampleBusinessData.departments
            .where((d) => d.id != 'ai_agent_room')
            .toList();
        final allActions = state.actionsWithEffectiveStatus;
        final todayFocus = allActions
            .where((a) => !a.isDone && a.dueText.contains('오늘'))
            .take(3)
            .toList();
        final weeklyPriorities = allActions
            .where((a) => !a.isDone && a.dueText.contains('이번 주'))
            .take(3)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommandHero(stats: stats),
              const SizedBox(height: 24),
              AiDailySummaryPanel(
                summary: SampleOperationalData.aiDailySummary,
                onViewAiRoom: () => onNavigate(ControlDestination.aiAgentRoom),
              ),
              const SizedBox(height: 32),
              const ControlSectionTitle(
                title: '사업 관제 현황',
                subtitle: 'ActionItem · BusinessIssue 기반 실시간 집계',
              ),
              _OperationalMetricsGrid(stats: stats, onNavigate: onNavigate),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _FocusSection(
                                title: '오늘 집중해야 할 일',
                                items: todayFocus,
                                onViewAll: () =>
                                    onNavigate(ControlDestination.actions),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _FocusSection(
                                title: '이번 주 우선순위',
                                items: weeklyPriorities,
                                onViewAll: () =>
                                    onNavigate(ControlDestination.actions),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _FocusSection(
                              title: '오늘 집중해야 할 일',
                              items: todayFocus,
                              onViewAll: () =>
                                  onNavigate(ControlDestination.actions),
                            ),
                            const SizedBox(height: 16),
                            _FocusSection(
                              title: '이번 주 우선순위',
                              items: weeklyPriorities,
                              onViewAll: () =>
                                  onNavigate(ControlDestination.actions),
                            ),
                          ],
                        );
                },
              ),
              const SizedBox(height: 32),
              const ControlSectionTitle(
                title: '사업부 운영 현황',
                subtitle: '클릭 시 상세 · 문제 · 수익 흐름 확인',
              ),
              _BusinessGrid(divisions: divisions, onNavigate: onNavigate),
              const SizedBox(height: 32),
              const ControlSectionTitle(title: '부서 현황'),
              _DepartmentGrid(departments: departments, onNavigate: onNavigate),
              const SizedBox(height: 32),
              ControlSectionTitle(
                title: '사업 홍보사이트 링크맵',
                subtitle: 'PUBLIC 사업 총괄 4개 · URL 등록 가능',
                trailing: TextButton.icon(
                  onPressed: () => onNavigate(ControlDestination.projectLinks),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('전체'),
                ),
              ),
              _PromoHubPreview(),
              const SizedBox(height: 24),
              const _PrivacyBanner(),
            ],
          ),
        );
      },
    );
  }
}

class _CommandHero extends StatelessWidget {
  const _CommandHero({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final healthColor = stats.healthScore < 75
        ? ControlColors.accentWarm
        : ControlColors.teal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ControlColors.charcoal,
            ControlColors.slate.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                SampleBusinessData.siteTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ControlColors.accentWarm.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 10, color: ControlColors.accentWarm),
                    SizedBox(width: 4),
                    Text(
                      'PRIVATE',
                      style: TextStyle(
                        fontSize: 10,
                        color: ControlColors.accentWarm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '사업 운영 관제센터 — 판단 · 지시 · 대응 · 수익 연결',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ControlColors.teal),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: healthColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${stats.healthScore}',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: healthColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '건강도',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: healthColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.healthLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: healthColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats.healthDetail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationalMetricsGrid extends StatelessWidget {
  const _OperationalMetricsGrid({
    required this.stats,
    required this.onNavigate,
  });

  final DashboardStats stats;
  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final items =
        <(String, String, IconData, String?, ControlDestination, bool)>[
          (
            '${stats.inProgressCount}건',
            '진행 중 작업',
            Icons.play_circle_outline,
            null,
            ControlDestination.actions,
            false,
          ),
          (
            '${stats.doneCount}건',
            '완료 작업',
            Icons.check_circle_outline,
            null,
            ControlDestination.actions,
            false,
          ),
          (
            '${stats.delayedCount}건',
            '지연 작업',
            Icons.schedule_outlined,
            null,
            ControlDestination.actions,
            true,
          ),
          (
            '${stats.unresolvedIssueCount}건',
            '미해결 문제',
            Icons.warning_amber_outlined,
            null,
            ControlDestination.issues,
            true,
          ),
          (
            '${stats.urgentIssueCount}건',
            '긴급 문제',
            Icons.priority_high,
            null,
            ControlDestination.issues,
            true,
          ),
          (
            '${stats.aiReportNeededCount}건',
            'AI 보고 필요',
            Icons.smart_toy_outlined,
            null,
            ControlDestination.aiAgentRoom,
            false,
          ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 700
            ? 2
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 130,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final dest = item.$5;
            return OperationalMetricCard(
              value: item.$1,
              label: item.$2,
              icon: item.$3,
              subtitle: item.$4,
              alert: item.$6,
              onTap: () => onNavigate(dest),
            );
          },
        );
      },
    );
  }
}

class _FocusSection extends StatelessWidget {
  const _FocusSection({
    required this.title,
    required this.items,
    required this.onViewAll,
  });

  final String title;
  final List<ActionItem> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ControlSectionTitle(
          title: title,
          trailing: TextButton(onPressed: onViewAll, child: const Text('전체')),
        ),
        ...items.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionItemCard(
              item: action.copyWith(
                status: DueTextHelper.resolveEffectiveStatus(action),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessGrid extends StatelessWidget {
  const _BusinessGrid({required this.divisions, required this.onNavigate});

  final List<BusinessDivision> divisions;
  final ValueChanged<ControlDestination> onNavigate;

  static const _routes = {
    'industrial_automation': ControlDestination.industrialAutomation,
    'app_development': ControlDestination.appDevelopment,
    'youtube_content': ControlDestination.youtubeContent,
    'ebook': ControlDestination.ebook,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 280,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: divisions.length,
          itemBuilder: (context, index) {
            final division = divisions[index];
            return BusinessStatusCard(
              division: division,
              onTap: () {
                final route = _routes[division.id];
                if (route != null) onNavigate(route);
              },
            );
          },
        );
      },
    );
  }
}

class _DepartmentGrid extends StatelessWidget {
  const _DepartmentGrid({required this.departments, required this.onNavigate});

  final List<Department> departments;
  final ValueChanged<ControlDestination> onNavigate;

  static const _routes = {
    'tax_accounting': ControlDestination.finance,
    'planning': ControlDestination.planning,
    'online_sales': ControlDestination.onlineSales,
    'sales': ControlDestination.sales,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 200,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: departments.length,
          itemBuilder: (context, index) {
            final dept = departments[index];
            return DepartmentStatusCard(
              department: dept,
              onTap: () {
                final route = _routes[dept.id];
                if (route != null) onNavigate(route);
              },
            );
          },
        );
      },
    );
  }
}

class _PromoHubPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);
    final sites = PromoSitesData.businessHubSites;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1100 ? 2 : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisExtent: 300,
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
      },
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 14,
            color: ControlColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              SampleBusinessData.privacyNotice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: ControlColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
