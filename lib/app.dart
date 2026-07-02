import 'package:flutter/material.dart';
import 'data/sample_business_data.dart';
import 'screens/action_items_screen.dart';
import 'screens/ai_agent_room_screen.dart';
import 'screens/ai_ceo_control_screens.dart';
import 'screens/business_division_screen.dart';
import 'screens/department_screen.dart';
import 'screens/expansion_dashboard_screen.dart';
import 'screens/finance_dashboard_screen.dart';
import 'screens/issues_dashboard_screen.dart';
import 'screens/overall_command_screen.dart';
import 'screens/project_link_screen.dart';
import 'screens/promotion_dashboard_screen.dart';
import 'screens/revenue_dashboard_screen.dart';
import 'state/control_scope.dart';
import 'state/control_state.dart';
import 'theme/control_theme.dart';
import 'widgets/sidebar_navigation.dart';

class SotongWareControlApp extends StatelessWidget {
  const SotongWareControlApp({super.key, required this.controlState});

  final ControlState controlState;

  @override
  Widget build(BuildContext context) {
    return ControlScope(
      notifier: controlState,
      child: MaterialApp(
        title: SampleBusinessData.siteEnglishName,
        debugShowCheckedModeBanner: false,
        theme: ControlTheme.lightTheme,
        home: const ControlCenterShell(),
      ),
    );
  }
}

class ControlCenterShell extends StatefulWidget {
  const ControlCenterShell({super.key});

  @override
  State<ControlCenterShell> createState() => _ControlCenterShellState();
}

class _ControlCenterShellState extends State<ControlCenterShell> {
  ControlDestination _selected = ControlDestination.aiRepresentative;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onDestinationSelected(ControlDestination destination) {
    setState(() => _selected = destination);
  }

  String get _pageTitle => _selected.label;

  Widget _buildContent() {
    switch (_selected) {
      case ControlDestination.dashboard:
        return OverallCommandScreen(onNavigate: _onDestinationSelected);
      case ControlDestination.aiRepresentative:
        return const AiCeoOfficeScreen();
      case ControlDestination.aiStrategyMeeting:
        return const AiStrategyMeetingScreen();
      case ControlDestination.aiIdeaMeeting:
        return const AiIdeaMeetingScreen();
      case ControlDestination.aiWorkOrder:
        return const AiExecutiveWorkspaceScreen(
          title: 'AI업무지시',
          description:
              'AI대표가 각 AI부서에 내려야 할 다음 작업, 실행 조건, 보류 기준을 정리하는 업무지시 화면입니다.',
          icon: Icons.assignment_outlined,
        );
      case ControlDestination.aiProgressReport:
        return const AiExecutiveWorkspaceScreen(
          title: 'AI진행보고',
          description:
              '각 사업부와 관리부서의 진행률, 자동 보고 대기, 실행 완료, 실패/주의 항목을 대표에게 보고합니다.',
          icon: Icons.summarize_outlined,
        );
      case ControlDestination.aiDecisionProposal:
        return const AiExecutiveWorkspaceScreen(
          title: 'AI의사결정제안',
          description: '대표 승인, 보류, 재검토 요청이 필요한 안건을 AI대표가 판단 근거와 함께 제안합니다.',
          icon: Icons.rule_outlined,
        );
      case ControlDestination.aiRiskAnalysis:
        return const AiExecutiveWorkspaceScreen(
          title: 'AI리스크분석',
          description: '개발 지연, 광고비 손실, 고객 문의 증가, 세무 일정 누락, 시스템 오류 가능성을 점검합니다.',
          icon: Icons.health_and_safety_outlined,
        );
      case ControlDestination.aiFutureStrategy:
        return const AiExecutiveWorkspaceScreen(
          title: 'AI미래전략',
          description: '신규 사업, 투자/재테크, 앱·전자책·산업자동화 확장 방향을 장기 전략 후보로 정리합니다.',
          icon: Icons.auto_graph_outlined,
        );
      case ControlDestination.aiNotifications:
        return const AiNotificationCenterScreen();
      case ControlDestination.aiProductDevelopmentDept:
        return const AiDepartmentControlScreen(departmentId: 'product');
      case ControlDestination.aiMarketingDept:
        return const AiDepartmentControlScreen(departmentId: 'marketing');
      case ControlDestination.aiSalesDept:
        return const AiDepartmentControlScreen(departmentId: 'sales');
      case ControlDestination.aiCustomerSupportDept:
        return const AiDepartmentControlScreen(departmentId: 'support');
      case ControlDestination.aiTaxAccountingDept:
        return const AiDepartmentControlScreen(departmentId: 'tax');
      case ControlDestination.aiInvestmentDept:
        return const AiDepartmentControlScreen(departmentId: 'investment');
      case ControlDestination.aiOperationsDept:
        return const AiDepartmentControlScreen(departmentId: 'operations');
      case ControlDestination.actions:
        return const ActionItemsScreen();
      case ControlDestination.issues:
        return const IssuesDashboardScreen();
      case ControlDestination.revenue:
        return const RevenueDashboardScreen();
      case ControlDestination.promotion:
        return const PromotionDashboardScreen();
      case ControlDestination.finance:
        final dept = SampleBusinessData.departmentById('finance');
        if (dept != null) return DepartmentScreen(department: dept);
        return const FinanceDashboardScreen();
      case ControlDestination.expansion:
        return const ExpansionDashboardScreen();
      case ControlDestination.aiAgentRoom:
        return const AiAgentRoomScreen();
      case ControlDestination.projectLinks:
        return const ProjectLinkScreen();
      default:
        break;
    }

    final divisionId = _selected.divisionId;
    if (divisionId != null) {
      final division = SampleBusinessData.divisionById(divisionId);
      if (division != null) {
        return BusinessDivisionScreen(division: division);
      }
    }

    final departmentId = _selected.departmentId;
    if (departmentId != null) {
      final department = SampleBusinessData.departmentById(departmentId);
      if (department != null) {
        return DepartmentScreen(department: department);
      }
    }

    return OverallCommandScreen(onNavigate: _onDestinationSelected);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                SidebarNavigation(
                  selected: _selected,
                  onDestinationSelected: _onDestinationSelected,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _ControlHeader(title: _pageTitle),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            backgroundColor: ControlColors.surface,
            child: SidebarNavigation(
              selected: _selected,
              onDestinationSelected: _onDestinationSelected,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            children: [
              _ControlHeader(
                title: _pageTitle,
                showMenuButton: true,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        );
      },
    );
  }
}

class _ControlHeader extends StatelessWidget {
  const _ControlHeader({
    required this.title,
    this.showMenuButton = false,
    this.onMenuPressed,
  });

  final String title;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showStatusBadge = screenWidth >= 420;
    final showSiteName = screenWidth >= 560;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: ControlColors.surface,
        border: Border(
          bottom: BorderSide(color: ControlColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuPressed,
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showStatusBadge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ControlColors.tealSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: ControlColors.teal),
                  SizedBox(width: 6),
                  Text(
                    '비공개 본사 관제',
                    style: TextStyle(
                      fontSize: 12,
                      color: ControlColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showSiteName) ...[
            const SizedBox(width: 12),
            Text(
              SampleBusinessData.siteEnglishName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
