import 'package:flutter/material.dart';
import 'data/sample_business_data.dart';
import 'screens/action_items_screen.dart';
import 'screens/ai_ceo_control_screens.dart';
import 'screens/business_division_screen.dart';
import 'screens/issues_dashboard_screen.dart';
import 'screens/overall_command_screen.dart';
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
        title: SampleBusinessData.siteTitle,
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
  ControlDestination _selected = ControlDestination.dashboardOverview;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onDestinationSelected(ControlDestination destination) {
    setState(() => _selected = destination);
  }

  String get _pageTitle => _selected.label;

  Widget _buildContent() {
    switch (_selected) {
      case ControlDestination.dashboardOverview:
        return OverallCommandScreen(onNavigate: _onDestinationSelected);
      case ControlDestination.divisionProgress:
        return DivisionProgressScreen(onNavigate: _onDestinationSelected);
      case ControlDestination.revenueProgress:
        return const RevenueDashboardScreen();
      case ControlDestination.issuesCheck:
        return const IssuesDashboardScreen();
      case ControlDestination.nextPriority:
        return const ActionItemsScreen();
      case ControlDestination.aiRepresentative:
        return const AiCeoOfficeScreen();
      case ControlDestination.aiWorkOrderDept:
        return const AiDepartmentControlScreen(departmentId: 'workorder');
      case ControlDestination.aiStrategyDept:
        return const AiDepartmentControlScreen(departmentId: 'strategy');
      case ControlDestination.aiIdeaPlanningDept:
        return const AiDepartmentControlScreen(departmentId: 'idea');
      case ControlDestination.aiMarketingDept:
        return const AiDepartmentControlScreen(departmentId: 'marketing');
      case ControlDestination.aiTaxAccountingDept:
        return const AiDepartmentControlScreen(departmentId: 'tax');
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
              maxLines: 2,
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
                    '소통총관제',
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
