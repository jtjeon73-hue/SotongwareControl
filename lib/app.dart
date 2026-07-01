import 'package:flutter/material.dart';
import 'data/sample_business_data.dart';
import 'screens/ai_agent_room_screen.dart';
import 'screens/business_division_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/department_screen.dart';
import 'screens/expansion_dashboard_screen.dart';
import 'screens/finance_dashboard_screen.dart';
import 'screens/issues_dashboard_screen.dart';
import 'screens/project_link_screen.dart';
import 'screens/promotion_dashboard_screen.dart';
import 'screens/revenue_dashboard_screen.dart';
import 'theme/control_theme.dart';
import 'widgets/sidebar_navigation.dart';

class SotongWareControlApp extends StatelessWidget {
  const SotongWareControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SampleBusinessData.siteEnglishName,
      debugShowCheckedModeBanner: false,
      theme: ControlTheme.darkTheme,
      home: const ControlCenterShell(),
    );
  }
}

class ControlCenterShell extends StatefulWidget {
  const ControlCenterShell({super.key});

  @override
  State<ControlCenterShell> createState() => _ControlCenterShellState();
}

class _ControlCenterShellState extends State<ControlCenterShell> {
  ControlDestination _selected = ControlDestination.dashboard;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onDestinationSelected(ControlDestination destination) {
    setState(() => _selected = destination);
  }

  String get _pageTitle => _selected.label;

  Widget _buildContent() {
    switch (_selected) {
      case ControlDestination.dashboard:
        return DashboardScreen(onNavigate: _onDestinationSelected);
      case ControlDestination.issues:
        return const IssuesDashboardScreen();
      case ControlDestination.revenue:
        return const RevenueDashboardScreen();
      case ControlDestination.promotion:
        return const PromotionDashboardScreen();
      case ControlDestination.finance:
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

    return DashboardScreen(onNavigate: _onDestinationSelected);
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
            backgroundColor: ControlColors.charcoal,
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
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: ControlColors.charcoal,
        border: Border(
          bottom: BorderSide(color: ControlColors.border, width: 0.5),
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
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ControlColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 6, color: ControlColors.teal),
                const SizedBox(width: 6),
                Text(
                  '관제 중',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: ControlColors.teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            SampleBusinessData.siteEnglishName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: ControlColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
