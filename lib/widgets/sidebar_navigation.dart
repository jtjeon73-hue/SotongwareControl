import 'package:flutter/material.dart';
import '../theme/control_theme.dart';
import 'sotong_brand_icon.dart';

enum ControlDestination {
  dashboardOverview,
  divisionProgress,
  revenueProgress,
  issuesCheck,
  nextPriority,
  aiRepresentative,
  aiWorkOrderDept,
  aiStrategyDept,
  aiIdeaPlanningDept,
  aiMarketingDept,
  aiTaxAccountingDept,
  industrialAutomation,
  appDevelopment,
  youtubeContent,
  ebook,
  onlineExpansion,
}

extension ControlDestinationX on ControlDestination {
  String get label {
    switch (this) {
      case ControlDestination.dashboardOverview:
        return '전체 사업 현황';
      case ControlDestination.divisionProgress:
        return '사업부별 진행상태';
      case ControlDestination.revenueProgress:
        return '수익화 진행상태';
      case ControlDestination.issuesCheck:
        return '문제/지연/체크사항';
      case ControlDestination.nextPriority:
        return '다음 실행 우선순위';
      case ControlDestination.aiRepresentative:
        return 'AI대표';
      case ControlDestination.aiWorkOrderDept:
        return 'AI지시진행부';
      case ControlDestination.aiStrategyDept:
        return 'AI전략부';
      case ControlDestination.aiIdeaPlanningDept:
        return 'AI기획.아이디어부';
      case ControlDestination.aiMarketingDept:
        return 'AI홍보.마케팅부';
      case ControlDestination.aiTaxAccountingDept:
        return 'AI세무회계부';
      case ControlDestination.industrialAutomation:
        return '소통자동화사업부';
      case ControlDestination.appDevelopment:
        return '소통앱개발사업부';
      case ControlDestination.youtubeContent:
        return '소통콘텐츠사업부';
      case ControlDestination.ebook:
        return '소통전자책사업부';
      case ControlDestination.onlineExpansion:
        return '소통온라인판매/확장사업부';
    }
  }

  IconData get icon {
    switch (this) {
      case ControlDestination.dashboardOverview:
        return Icons.dashboard_outlined;
      case ControlDestination.divisionProgress:
        return Icons.business_outlined;
      case ControlDestination.revenueProgress:
        return Icons.paid_outlined;
      case ControlDestination.issuesCheck:
        return Icons.warning_amber_outlined;
      case ControlDestination.nextPriority:
        return Icons.playlist_add_check_outlined;
      case ControlDestination.aiRepresentative:
        return Icons.psychology_outlined;
      case ControlDestination.aiWorkOrderDept:
        return Icons.assignment_outlined;
      case ControlDestination.aiStrategyDept:
        return Icons.auto_graph_outlined;
      case ControlDestination.aiIdeaPlanningDept:
        return Icons.tips_and_updates_outlined;
      case ControlDestination.aiMarketingDept:
        return Icons.campaign_outlined;
      case ControlDestination.aiTaxAccountingDept:
        return Icons.receipt_long_outlined;
      case ControlDestination.industrialAutomation:
        return Icons.precision_manufacturing_outlined;
      case ControlDestination.appDevelopment:
        return Icons.phone_android_outlined;
      case ControlDestination.youtubeContent:
        return Icons.play_circle_outline;
      case ControlDestination.ebook:
        return Icons.menu_book_outlined;
      case ControlDestination.onlineExpansion:
        return Icons.storefront_outlined;
    }
  }

  String? get divisionId {
    switch (this) {
      case ControlDestination.industrialAutomation:
        return 'industrial_automation';
      case ControlDestination.appDevelopment:
        return 'app_development';
      case ControlDestination.youtubeContent:
        return 'youtube_content';
      case ControlDestination.ebook:
        return 'ebook';
      case ControlDestination.onlineExpansion:
        return 'online_expansion';
      default:
        return null;
    }
  }

  String? get aiDepartmentId {
    switch (this) {
      case ControlDestination.aiRepresentative:
        return 'ceo';
      case ControlDestination.aiWorkOrderDept:
        return 'workorder';
      case ControlDestination.aiStrategyDept:
        return 'strategy';
      case ControlDestination.aiIdeaPlanningDept:
        return 'idea';
      case ControlDestination.aiMarketingDept:
        return 'marketing';
      case ControlDestination.aiTaxAccountingDept:
        return 'tax';
      default:
        return null;
    }
  }
}

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    this.onClose,
  });

  final ControlDestination selected;
  final ValueChanged<ControlDestination> onDestinationSelected;
  final VoidCallback? onClose;

  static const _commandHub = [
    ControlDestination.dashboardOverview,
    ControlDestination.divisionProgress,
    ControlDestination.revenueProgress,
    ControlDestination.issuesCheck,
    ControlDestination.nextPriority,
  ];

  static const _aiDepartments = [
    ControlDestination.aiRepresentative,
    ControlDestination.aiWorkOrderDept,
    ControlDestination.aiStrategyDept,
    ControlDestination.aiIdeaPlanningDept,
    ControlDestination.aiMarketingDept,
    ControlDestination.aiTaxAccountingDept,
  ];

  static const _divisions = [
    ControlDestination.industrialAutomation,
    ControlDestination.appDevelopment,
    ControlDestination.youtubeContent,
    ControlDestination.ebook,
    ControlDestination.onlineExpansion,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      decoration: const BoxDecoration(
        color: ControlColors.surface,
        border: Border(
          right: BorderSide(color: ControlColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SotongBrandIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '소통총관제',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI 총괄 관제 · 디지털 프로모',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 11,
                                  color: ControlColors.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                const _SectionLabel(label: '소통총괄관제'),
                ..._commandHub.map(
                  (d) => _NavItem(
                    destination: d,
                    isSelected: d == selected,
                    onTap: () {
                      onDestinationSelected(d);
                      onClose?.call();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const _SectionLabel(label: '소통AI대표부'),
                ..._aiDepartments.map(
                  (d) => _NavItem(
                    destination: d,
                    isSelected: d == selected,
                    onTap: () {
                      onDestinationSelected(d);
                      onClose?.call();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const _SectionLabel(label: '소통사업부'),
                ..._divisions.map(
                  (d) => _NavItem(
                    destination: d,
                    isSelected: d == selected,
                    onTap: () {
                      onDestinationSelected(d);
                      onClose?.call();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: ControlColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sotong Control · AI 관제',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10,
                      color: ControlColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 10,
          color: ControlColors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final ControlDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? ControlColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 18,
                  color: isSelected
                      ? ControlColors.teal
                      : ControlColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? ControlColors.textPrimary
                          : ControlColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
