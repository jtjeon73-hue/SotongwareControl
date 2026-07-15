import 'package:flutter/material.dart';
import 'data/sample_business_data.dart';
import 'screens/action_items_screen.dart';
import 'screens/admin_data_screen.dart';
import 'screens/ai_business_analysis_screen.dart';
import 'screens/ai_ops_department_screen.dart';
import 'screens/business_division_progress_screen.dart';
import 'screens/business_overview_screen.dart';
import 'screens/business_study_screen.dart';
import 'screens/business_unit_ops_screen.dart';
import 'screens/issues_dashboard_screen.dart';
import 'screens/public_services_screen.dart';
import 'screens/revenue_dashboard_screen.dart';
import 'screens/sotong24work_screen.dart';
import 'screens/study/study_admin_screen.dart';
import 'screens/study/study_ai_teacher_screen.dart';
import 'screens/study/study_courses_screen.dart';
import 'screens/study/study_dashboard_screen.dart';
import 'screens/study/study_notes_and_more_screens.dart';
import 'services/auth_service.dart';
import 'state/control_scope.dart';
import 'state/control_state.dart';
import 'theme/control_theme.dart';
import 'widgets/auth_gate.dart';
import 'widgets/sidebar_navigation.dart';
import 'widgets/sotong_brand_icon.dart';

class SotongWareControlApp extends StatelessWidget {
  const SotongWareControlApp({
    super.key,
    required this.controlState,
    required this.authService,
  });

  final ControlState controlState;
  final AuthClient authService;

  @override
  Widget build(BuildContext context) {
    return ControlScope(
      notifier: controlState,
      child: MaterialApp(
        title: SampleBusinessData.siteTitle,
        debugShowCheckedModeBanner: false,
        theme: ControlTheme.lightTheme,
        home: AuthGate(
          authService: authService,
          authenticatedBuilder: (_) =>
              ControlCenterShell(authService: authService),
        ),
      ),
    );
  }
}

class ControlCenterShell extends StatefulWidget {
  const ControlCenterShell({super.key, required this.authService});

  final AuthClient authService;

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

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하고 로그인 화면으로 돌아갈까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _selected = ControlDestination.dashboardOverview);
      await widget.authService.signOut();
    }
  }

  static const _ebookPlan = [
    '전자책 주제 선정',
    '목표 독자 설정',
    '제목 후보 작성',
    '목차 구성',
    '자료 수집',
    '본문 초안 작성',
    'AI 검토 및 보완',
    '표지 제작',
    'PDF 및 EPUB 제작',
    '가격 및 판매 채널 결정',
    '상품 소개 페이지 제작',
    '판매 등록 및 홍보',
  ];

  Widget _buildContent() {
    switch (_selected) {
      case ControlDestination.dashboardOverview:
        return BusinessOverviewScreen(onNavigate: _onDestinationSelected);
      case ControlDestination.divisionProgress:
        return const BusinessDivisionProgressScreen();
      case ControlDestination.revenueProgress:
        return const RevenueDashboardScreen();
      case ControlDestination.issuesCheck:
        return const IssuesDashboardScreen();
      case ControlDestination.nextPriority:
        return const ActionItemsScreen();
      case ControlDestination.adminData:
        return const AdminDataScreen();
      case ControlDestination.aiRepresentative:
        return const AiOpsDepartmentScreen(
          departmentId: 'ceo',
          title: 'AI대표',
          roleSummary: '전체 사업 현황·긴급 확인·오늘 우선 작업·승인 필요 사항을 규칙 기반으로 요약합니다.',
        );
      case ControlDestination.aiProductDevDept:
        return const AiOpsDepartmentScreen(
          departmentId: 'productdev',
          title: 'AI상품개발부',
          roleSummary: '등록된 프로젝트·개발 후보 상태를 사실 기준으로 정리합니다.',
        );
      case ControlDestination.aiWorkOrderDept:
        return const AiOpsDepartmentScreen(
          departmentId: 'workorder',
          title: 'AI지시진행부',
          roleSummary: '할 일·우선순위·승인·지연을 관리합니다. AI 제안과 수동 등록을 구분합니다.',
        );
      case ControlDestination.aiStrategyDept:
        return const AiOpsDepartmentScreen(
          departmentId: 'strategy',
          title: 'AI전략부',
          roleSummary: '근거 데이터 없는 매출 예측은 만들지 않습니다. 등록된 사업부 상태만 검토합니다.',
        );
      case ControlDestination.aiIdeaPlanningDept:
        return const AiOpsDepartmentScreen(
          departmentId: 'idea',
          title: 'AI기획.아이디어부',
          roleSummary: '아이디어는 프로젝트 진행처럼 표시하지 않습니다.',
        );
      case ControlDestination.aiMarketingDept:
        return const AiOpsDepartmentScreen(
          departmentId: 'marketing',
          title: 'AI홍보.마케팅부',
          roleSummary: '미홍보 내용을 완료처럼 표시하지 않습니다. 프로모 URL 등록 현황만 표시합니다.',
        );
      case ControlDestination.aiTaxAccountingDept:
        return const AiOpsDepartmentScreen(
          departmentId: 'tax',
          title: 'AI세무회계부',
          roleSummary: '실제 등록 금액만 표시합니다. 확정 신고 결과가 아닌 관리 참고 정보입니다.',
        );
      case ControlDestination.aiBusinessAnalysis:
        return const AiBusinessAnalysisScreen();
      case ControlDestination.studyDashboard:
        return StudyDashboardScreen(onNavigate: _onDestinationSelected);
      case ControlDestination.studyCourses:
        return const StudyCoursesScreen();
      case ControlDestination.studyAiTeacher:
        return const StudyAiTeacherScreen();
      case ControlDestination.studyAssignments:
        return const StudyAssignmentsScreen();
      case ControlDestination.studyQuizzes:
        return const StudyQuizzesScreen();
      case ControlDestination.studyNotes:
        return const StudyNotesScreen();
      case ControlDestination.studyHistory:
        return const StudyHistoryScreen();
      case ControlDestination.studyAdmin:
        return const StudyAdminScreen();
      case ControlDestination.sotong24work:
        return const Sotong24WorkScreen();
      case ControlDestination.industrialAutomation:
        return const BusinessUnitOpsScreen(
          businessUnitId: 'industrial_automation',
          fallbackTitle: '산업자동화사업부',
        );
      case ControlDestination.appDevelopment:
        return const BusinessUnitOpsScreen(
          businessUnitId: 'app_development',
          fallbackTitle: '앱개발사업부',
        );
      case ControlDestination.youtubeContent:
        return const BusinessUnitOpsScreen(
          businessUnitId: 'content_music',
          fallbackTitle: '콘텐츠·음악사업부',
        );
      case ControlDestination.ebook:
        return const BusinessUnitOpsScreen(
          businessUnitId: 'ebook',
          fallbackTitle: '전자책사업부',
          recommendedPlan: _ebookPlan,
        );
      case ControlDestination.onlineExpansion:
        return const BusinessUnitOpsScreen(
          businessUnitId: 'online_expansion',
          fallbackTitle: '온라인판매/확장',
        );
      case ControlDestination.webMarketing:
        return const BusinessUnitOpsScreen(
          businessUnitId: 'web_marketing',
          fallbackTitle: '웹마케팅제작사업부',
        );
      case ControlDestination.businessStudy:
        return const BusinessStudyScreen();
      case ControlDestination.publicServices:
        return const PublicServicesScreen();
    }
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
                      _ControlHeader(
                        title: _pageTitle,
                        onSignOut: _confirmSignOut,
                      ),
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
                onSignOut: _confirmSignOut,
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
    required this.onSignOut,
    this.showMenuButton = false,
    this.onMenuPressed,
  });

  final String title;
  final VoidCallback onSignOut;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showStatusBadge = screenWidth >= 420;
    final showSiteName = screenWidth >= 720;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  SotongBrandIcon(compact: true, size: 18, padding: 0),
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
            const SizedBox(width: 8),
          ],
          if (showSiteName) ...[
            Text(
              '관리자',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
          ],
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('로그아웃'),
            style: TextButton.styleFrom(
              foregroundColor: ControlColors.textSecondary,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
