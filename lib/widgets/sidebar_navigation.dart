import 'package:flutter/material.dart';

import '../data/menu_divisions.dart';
import '../theme/control_theme.dart';
import 'sotong_brand_icon.dart';

enum ControlDestination {
  dashboardOverview,
  divisionProgress,
  deployedSites,
  revenueProgress,
  issuesCheck,
  nextPriority,
  aiRepresentative,
  aiProductDevDept,
  aiWorkOrderDept,
  aiStrategyDept,
  aiIdeaPlanningDept,
  aiMarketingDept,
  aiTaxAccountingDept,
  aiBusinessAnalysis,
  operationsAnalysis,
  portfolioHub,
  studyDashboard,
  studyCourses,
  studyAiTeacher,
  studyAssignments,
  studyQuizzes,
  studyNotes,
  studyHistory,
  studyAdmin,
  sotong24work,
  industrialAutomation,
  appDevelopment,
  youtubeContent,
  ebook,
  onlineExpansion,
  webMarketing,
  siteManager,
  businessStudy,
  publicServices,
  adminData,
  // Canonical IA 재구성 — 신규
  productWorkshop,
  sotong24RemoteControl,
  autoPromotion,
  autoSales,
  autoFinance,
  systemSettings,
  alertCenter,
  ideaBank,
  standardProductionGuide,
}

extension ControlDestinationX on ControlDestination {
  String get label {
    switch (this) {
      case ControlDestination.dashboardOverview:
        return '전체 사업 현황';
      case ControlDestination.divisionProgress:
        return '사업부별 진행상태';
      case ControlDestination.deployedSites:
        return '웹 배포사이트';
      case ControlDestination.revenueProgress:
        return '수익화 진행상태';
      case ControlDestination.issuesCheck:
        return '문제/지연/체크사항';
      case ControlDestination.nextPriority:
        return '다음 실행 우선순위';
      case ControlDestination.adminData:
        return '데이터 관리';
      case ControlDestination.aiRepresentative:
        return 'AI대표';
      case ControlDestination.aiProductDevDept:
        return 'AI상품개발부';
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
      case ControlDestination.aiBusinessAnalysis:
        return '작업지시 제작소';
      case ControlDestination.operationsAnalysis:
        return '운영 분석';
      case ControlDestination.portfolioHub:
        return '제작 포트폴리오';
      case ControlDestination.studyDashboard:
        return '학습 대시보드';
      case ControlDestination.studyCourses:
        return '내 강의방';
      case ControlDestination.studyAiTeacher:
        return 'AI선생';
      case ControlDestination.studyAssignments:
        return '실습·과제';
      case ControlDestination.studyQuizzes:
        return '복습·퀴즈';
      case ControlDestination.studyNotes:
        return '학습 노트';
      case ControlDestination.studyHistory:
        return '학습 기록';
      case ControlDestination.studyAdmin:
        return '스터디 관리';
      case ControlDestination.sotong24work:
        return '소통24워크 사업부';
      case ControlDestination.industrialAutomation:
        return '산업자동화SW개발부';
      case ControlDestination.appDevelopment:
        return '앱 개발부';
      case ControlDestination.youtubeContent:
        return '컨텐츠 개발부';
      case ControlDestination.ebook:
        return '전자책 개발부';
      case ControlDestination.onlineExpansion:
        return '온라인판매/확장(보관)';
      case ControlDestination.webMarketing:
        return '마케팅사이트 개발부';
      case ControlDestination.siteManager:
        return '지식사이트 개발부';
      case ControlDestination.businessStudy:
        return '사업 전략연구실';
      case ControlDestination.publicServices:
        return '공개 서비스';
      case ControlDestination.productWorkshop:
        return 'AI 제작공정';
      case ControlDestination.sotong24RemoteControl:
        return '노트북 원격관제';
      case ControlDestination.autoPromotion:
        return '자동 홍보 전략실';
      case ControlDestination.autoSales:
        return '자동판매전략실';
      case ControlDestination.autoFinance:
        return '수익세금 자동 재무실';
      case ControlDestination.systemSettings:
        return '시스템 설정';
      case ControlDestination.alertCenter:
        return '알람센터';
      case ControlDestination.ideaBank:
        return '뉴 아이디어 뱅크';
      case ControlDestination.standardProductionGuide:
        return '표준제작 가이드';
    }
  }

  IconData get icon {
    switch (this) {
      case ControlDestination.dashboardOverview:
        return Icons.dashboard_outlined;
      case ControlDestination.divisionProgress:
        return Icons.business_outlined;
      case ControlDestination.deployedSites:
        return Icons.language_outlined;
      case ControlDestination.revenueProgress:
        return Icons.paid_outlined;
      case ControlDestination.issuesCheck:
        return Icons.warning_amber_outlined;
      case ControlDestination.nextPriority:
        return Icons.playlist_add_check_outlined;
      case ControlDestination.adminData:
        return Icons.storage_outlined;
      case ControlDestination.aiRepresentative:
        return Icons.psychology_outlined;
      case ControlDestination.aiProductDevDept:
        return Icons.inventory_2_outlined;
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
      case ControlDestination.aiBusinessAnalysis:
        return Icons.design_services_outlined;
      case ControlDestination.operationsAnalysis:
        return Icons.auto_graph_outlined;
      case ControlDestination.portfolioHub:
        return Icons.collections_bookmark_outlined;
      case ControlDestination.studyDashboard:
        return Icons.school_outlined;
      case ControlDestination.studyCourses:
        return Icons.menu_book_outlined;
      case ControlDestination.studyAiTeacher:
        return Icons.smart_toy_outlined;
      case ControlDestination.studyAssignments:
        return Icons.construction_outlined;
      case ControlDestination.studyQuizzes:
        return Icons.quiz_outlined;
      case ControlDestination.studyNotes:
        return Icons.sticky_note_2_outlined;
      case ControlDestination.studyHistory:
        return Icons.history_outlined;
      case ControlDestination.studyAdmin:
        return Icons.settings_suggest_outlined;
      case ControlDestination.sotong24work:
        return Icons.developer_board_outlined;
      case ControlDestination.industrialAutomation:
        return Icons.precision_manufacturing_outlined;
      case ControlDestination.appDevelopment:
        return Icons.phone_android_outlined;
      case ControlDestination.youtubeContent:
        return Icons.play_circle_outline;
      case ControlDestination.ebook:
        return Icons.auto_stories_outlined;
      case ControlDestination.onlineExpansion:
        return Icons.storefront_outlined;
      case ControlDestination.webMarketing:
        return Icons.language_outlined;
      case ControlDestination.siteManager:
        return Icons.hub_outlined;
      case ControlDestination.businessStudy:
        return Icons.menu_book_outlined;
      case ControlDestination.publicServices:
        return Icons.public_outlined;
      case ControlDestination.productWorkshop:
        return Icons.handyman_outlined;
      case ControlDestination.sotong24RemoteControl:
        return Icons.phonelink_setup_outlined;
      case ControlDestination.autoPromotion:
        return Icons.campaign_outlined;
      case ControlDestination.autoSales:
        return Icons.storefront_outlined;
      case ControlDestination.autoFinance:
        return Icons.account_balance_outlined;
      case ControlDestination.systemSettings:
        return Icons.settings_outlined;
      case ControlDestination.alertCenter:
        return Icons.notifications_outlined;
      case ControlDestination.ideaBank:
        return Icons.lightbulb_outline;
      case ControlDestination.standardProductionGuide:
        return Icons.library_books_outlined;
    }
  }

  String? get divisionId {
    switch (this) {
      case ControlDestination.sotong24work:
        return 'sotong24work';
      case ControlDestination.industrialAutomation:
        return 'industrial_automation';
      case ControlDestination.appDevelopment:
        return 'app_development';
      case ControlDestination.youtubeContent:
        return 'content_music';
      case ControlDestination.ebook:
        return 'ebook';
      case ControlDestination.onlineExpansion:
        return 'online_expansion';
      case ControlDestination.webMarketing:
        return 'web_marketing';
      case ControlDestination.siteManager:
        return 'site_manager';
      default:
        return null;
    }
  }

  String? get aiDepartmentId {
    switch (this) {
      case ControlDestination.aiRepresentative:
        return 'ceo';
      case ControlDestination.aiProductDevDept:
        return 'productdev';
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

class SidebarNavigation extends StatefulWidget {
  const SidebarNavigation({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    this.onClose,
  });

  final ControlDestination selected;
  final ValueChanged<ControlDestination> onDestinationSelected;
  final VoidCallback? onClose;

  /// Canonical IA — 5개 부문 순서의 flat 목록 (route/key 보존).
  static List<ControlDestination> get canonicalDestinations =>
      MenuDivisionCatalog.flattenedDestinations;

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  late Set<String> _expanded;

  @override
  void initState() {
    super.initState();
    // 기본은 전부 펼침. 사용자는 그룹을 접을 수 있고, 선택 메뉴 그룹은 닫히지 않는다.
    _expanded = {for (final d in MenuDivisionCatalog.all) d.id};
  }

  @override
  void didUpdateWidget(covariant SidebarNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      final div = MenuDivisionCatalog.divisionOf(widget.selected);
      if (div != null && !_expanded.contains(div.id)) {
        setState(() => _expanded = {..._expanded, div.id});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;

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
            padding: EdgeInsets.fromLTRB(20, isCompact ? 12 : 20, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SotongBrandIcon(size: 40),
                const SizedBox(width: 10),
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
                        'AI 사업 운영 본부',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              children: [
                for (final division in MenuDivisionCatalog.all) ...[
                  _DivisionHeader(
                    title: division.title,
                    expanded: _expanded.contains(division.id),
                    containsSelected: division.contains(widget.selected),
                    onToggle: () {
                      setState(() {
                        if (_expanded.contains(division.id)) {
                          // 선택 메뉴가 있는 그룹은 닫지 않음
                          if (division.contains(widget.selected)) return;
                          _expanded = {..._expanded}..remove(division.id);
                        } else {
                          _expanded = {..._expanded, division.id};
                        }
                      });
                    },
                  ),
                  if (_expanded.contains(division.id))
                    for (final d in division.destinations)
                      _NavItem(
                        destination: d,
                        isSelected: d == widget.selected,
                        onTap: () {
                          widget.onDestinationSelected(d);
                          widget.onClose?.call();
                        },
                      ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
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
    );
  }
}

class _DivisionHeader extends StatelessWidget {
  const _DivisionHeader({
    required this.title,
    required this.expanded,
    required this.containsSelected,
    required this.onToggle,
  });

  final String title;
  final bool expanded;
  final bool containsSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: containsSelected
                      ? ControlColors.teal
                      : ControlColors.textMuted,
                ),
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: ControlColors.textMuted,
            ),
          ],
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
        color: isSelected ? ControlColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 18,
                  color: isSelected
                      ? ControlColors.teal
                      : ControlColors.textSecondary,
                ),
                const SizedBox(width: 10),
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
