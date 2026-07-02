import 'package:flutter/material.dart';
import '../theme/control_theme.dart';

enum ControlDestination {
  dashboard,
  aiRepresentative,
  aiStrategyMeeting,
  aiIdeaMeeting,
  aiWorkOrder,
  aiProgressReport,
  aiDecisionProposal,
  aiRiskAnalysis,
  aiFutureStrategy,
  aiNotifications,
  aiProductDevelopmentDept,
  aiMarketingDept,
  aiSalesDept,
  aiCustomerSupportDept,
  aiTaxAccountingDept,
  aiInvestmentDept,
  aiOperationsDept,
  actions,
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
  marketing,
  onlineCustomer,
  projectLinks,
}

extension ControlDestinationX on ControlDestination {
  String get label {
    switch (this) {
      case ControlDestination.dashboard:
        return '전체사업관리관제';
      case ControlDestination.aiRepresentative:
        return 'AI대표실';
      case ControlDestination.aiStrategyMeeting:
        return 'AI전략회의실';
      case ControlDestination.aiIdeaMeeting:
        return 'AI아이디어회의실';
      case ControlDestination.aiWorkOrder:
        return 'AI업무지시';
      case ControlDestination.aiProgressReport:
        return 'AI진행보고';
      case ControlDestination.aiDecisionProposal:
        return 'AI의사결정제안';
      case ControlDestination.aiRiskAnalysis:
        return 'AI리스크분석';
      case ControlDestination.aiFutureStrategy:
        return 'AI미래전략';
      case ControlDestination.aiNotifications:
        return '알림센터';
      case ControlDestination.aiProductDevelopmentDept:
        return 'AI상품개발부';
      case ControlDestination.aiMarketingDept:
        return 'AI마케팅부';
      case ControlDestination.aiSalesDept:
        return 'AI영업부';
      case ControlDestination.aiCustomerSupportDept:
        return 'AI고객지원부';
      case ControlDestination.aiTaxAccountingDept:
        return 'AI세무회계부';
      case ControlDestination.aiInvestmentDept:
        return 'AI투자관리부';
      case ControlDestination.aiOperationsDept:
        return 'AI운영관리부';
      case ControlDestination.actions:
        return '작업 관리';
      case ControlDestination.issues:
        return '문제점 파악·대응';
      case ControlDestination.revenue:
        return '수익화 흐름';
      case ControlDestination.promotion:
        return '영업·홍보 관리';
      case ControlDestination.finance:
        return '재무·세금';
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
      case ControlDestination.marketing:
        return '홍보·마케팅';
      case ControlDestination.onlineCustomer:
        return '온라인 고객대응';
      case ControlDestination.projectLinks:
        return '홍보사이트 링크맵';
    }
  }

  IconData get icon {
    switch (this) {
      case ControlDestination.dashboard:
        return Icons.dashboard_outlined;
      case ControlDestination.aiRepresentative:
        return Icons.psychology_outlined;
      case ControlDestination.aiStrategyMeeting:
        return Icons.groups_2_outlined;
      case ControlDestination.aiIdeaMeeting:
        return Icons.tips_and_updates_outlined;
      case ControlDestination.aiWorkOrder:
        return Icons.assignment_outlined;
      case ControlDestination.aiProgressReport:
        return Icons.summarize_outlined;
      case ControlDestination.aiDecisionProposal:
        return Icons.rule_outlined;
      case ControlDestination.aiRiskAnalysis:
        return Icons.health_and_safety_outlined;
      case ControlDestination.aiFutureStrategy:
        return Icons.auto_graph_outlined;
      case ControlDestination.aiNotifications:
        return Icons.notifications_active_outlined;
      case ControlDestination.aiProductDevelopmentDept:
        return Icons.inventory_2_outlined;
      case ControlDestination.aiMarketingDept:
        return Icons.campaign_outlined;
      case ControlDestination.aiSalesDept:
        return Icons.handshake_outlined;
      case ControlDestination.aiCustomerSupportDept:
        return Icons.support_agent_outlined;
      case ControlDestination.aiTaxAccountingDept:
        return Icons.receipt_long_outlined;
      case ControlDestination.aiInvestmentDept:
        return Icons.trending_up_outlined;
      case ControlDestination.aiOperationsDept:
        return Icons.settings_suggest_outlined;
      case ControlDestination.actions:
        return Icons.task_alt_outlined;
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
      case ControlDestination.marketing:
        return Icons.campaign_outlined;
      case ControlDestination.onlineCustomer:
        return Icons.support_agent_outlined;
      case ControlDestination.projectLinks:
        return Icons.hub_outlined;
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
      default:
        return null;
    }
  }

  String? get departmentId {
    switch (this) {
      case ControlDestination.planning:
        return 'planning';
      case ControlDestination.marketing:
        return 'marketing';
      case ControlDestination.finance:
        return 'finance';
      case ControlDestination.onlineCustomer:
        return 'online_customer';
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

  static const _aiCommand = [ControlDestination.dashboard];

  static const _aiExecutiveRooms = [
    ControlDestination.aiRepresentative,
    ControlDestination.aiStrategyMeeting,
    ControlDestination.aiIdeaMeeting,
    ControlDestination.aiWorkOrder,
    ControlDestination.aiProgressReport,
    ControlDestination.aiDecisionProposal,
    ControlDestination.aiRiskAnalysis,
    ControlDestination.aiFutureStrategy,
    ControlDestination.aiNotifications,
  ];

  static const _aiDepartments = [
    ControlDestination.aiProductDevelopmentDept,
    ControlDestination.aiMarketingDept,
    ControlDestination.aiSalesDept,
    ControlDestination.aiCustomerSupportDept,
    ControlDestination.aiTaxAccountingDept,
    ControlDestination.aiInvestmentDept,
    ControlDestination.aiOperationsDept,
  ];

  static const _divisions = [
    ControlDestination.industrialAutomation,
    ControlDestination.appDevelopment,
    ControlDestination.youtubeContent,
    ControlDestination.ebook,
  ];

  static const _managementDepts = [
    ControlDestination.planning,
    ControlDestination.marketing,
    ControlDestination.finance,
    ControlDestination.onlineCustomer,
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ControlColors.tealSoft,
                        borderRadius: BorderRadius.circular(10),
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
                  '24시간 AI 경영 관제 · 비공개 본사 시스템',
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
                const _SectionLabel(label: '관제 · AI대표'),
                ..._aiCommand.map(
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
                const _SectionLabel(label: 'AI대표'),
                ..._aiExecutiveRooms.map(
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
                const _SectionLabel(label: 'AI부서'),
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
                const _SectionLabel(label: '기존 사업부'),
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
                const _SectionLabel(label: '기존 관리부서'),
                ..._managementDepts.map(
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
                  Icons.public_outlined,
                  size: 12,
                  color: ControlColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PRIVATE · 본사 AI 관제',
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
