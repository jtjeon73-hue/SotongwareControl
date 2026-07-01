import 'package:flutter/material.dart';
import '../theme/control_theme.dart';

enum ControlDestination {
  dashboard,
  issues,
  revenue,
  promotion,
  finance,
  expansion,
  aiAgentRoom,
  industrialAutomation,
  appDevelopment,
  youtubeContent,
  ebook,
  planning,
  onlineSales,
  sales,
  projectLinks,
}

extension ControlDestinationX on ControlDestination {
  String get label {
    switch (this) {
      case ControlDestination.dashboard:
        return '전체 사업 관제';
      case ControlDestination.issues:
        return '문제점 파악·대응';
      case ControlDestination.revenue:
        return '수익화 흐름';
      case ControlDestination.promotion:
        return '영업·홍보 관리';
      case ControlDestination.finance:
        return '재무·세금 관리';
      case ControlDestination.expansion:
        return '사업 확장 로드맵';
      case ControlDestination.aiAgentRoom:
        return 'AI 직원실';
      case ControlDestination.industrialAutomation:
        return '산업자동화 사업부';
      case ControlDestination.appDevelopment:
        return '앱개발 사업부';
      case ControlDestination.youtubeContent:
        return '유튜브/콘텐츠 사업부';
      case ControlDestination.ebook:
        return '전자책 사업부';
      case ControlDestination.planning:
        return '기획·아이디어';
      case ControlDestination.onlineSales:
        return '온라인영업·고객대응';
      case ControlDestination.sales:
        return '판매·고객대응';
      case ControlDestination.projectLinks:
        return '프로젝트 링크맵';
    }
  }

  IconData get icon {
    switch (this) {
      case ControlDestination.dashboard:
        return Icons.radar_outlined;
      case ControlDestination.issues:
        return Icons.warning_amber_outlined;
      case ControlDestination.revenue:
        return Icons.paid_outlined;
      case ControlDestination.promotion:
        return Icons.campaign_outlined;
      case ControlDestination.finance:
        return Icons.account_balance_wallet_outlined;
      case ControlDestination.expansion:
        return Icons.rocket_launch_outlined;
      case ControlDestination.aiAgentRoom:
        return Icons.smart_toy_outlined;
      case ControlDestination.industrialAutomation:
        return Icons.precision_manufacturing_outlined;
      case ControlDestination.appDevelopment:
        return Icons.phone_android_outlined;
      case ControlDestination.youtubeContent:
        return Icons.play_circle_outline;
      case ControlDestination.ebook:
        return Icons.menu_book_outlined;
      case ControlDestination.planning:
        return Icons.lightbulb_outline;
      case ControlDestination.onlineSales:
        return Icons.handshake_outlined;
      case ControlDestination.sales:
        return Icons.shopping_bag_outlined;
      case ControlDestination.projectLinks:
        return Icons.hub_outlined;
    }
  }

  bool get isOperational {
    return this == ControlDestination.dashboard ||
        this == ControlDestination.issues ||
        this == ControlDestination.revenue ||
        this == ControlDestination.promotion ||
        this == ControlDestination.finance ||
        this == ControlDestination.expansion ||
        this == ControlDestination.aiAgentRoom;
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
      default:
        return null;
    }
  }

  String? get departmentId {
    switch (this) {
      case ControlDestination.planning:
        return 'planning';
      case ControlDestination.onlineSales:
        return 'online_sales';
      case ControlDestination.sales:
        return 'sales';
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

  static const _operational = [
    ControlDestination.dashboard,
    ControlDestination.issues,
    ControlDestination.revenue,
    ControlDestination.promotion,
    ControlDestination.finance,
    ControlDestination.expansion,
    ControlDestination.aiAgentRoom,
  ];

  static const _divisions = [
    ControlDestination.industrialAutomation,
    ControlDestination.appDevelopment,
    ControlDestination.youtubeContent,
    ControlDestination.ebook,
  ];

  static const _departments = [
    ControlDestination.planning,
    ControlDestination.onlineSales,
    ControlDestination.sales,
    ControlDestination.projectLinks,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: ControlColors.charcoal,
        border: Border(
          right: BorderSide(color: ControlColors.border, width: 0.5),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ControlColors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.radar,
                        color: ControlColors.teal,
                        size: 20,
                      ),
                    ),
                    if (onClose != null) ...[
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '소통웨어 디지털랩',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '사업 운영 관제센터',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: ControlColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                _SectionLabel(label: '관제 · 운영'),
                ..._operational.map(
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
                _SectionLabel(label: '사업부'),
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
                const SizedBox(height: 8),
                _SectionLabel(label: '부서 · 링크'),
                ..._departments.map(
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
                  Icons.lock_outline,
                  size: 12,
                  color: ControlColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PRIVATE · 내부 운영용',
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
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isSelected
            ? ControlColors.teal.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
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
