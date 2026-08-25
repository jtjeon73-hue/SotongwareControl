import 'package:flutter/material.dart';

import '../core/constants/external_site_links.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../services/sotong24_notification_service.dart';
import '../widgets/notification_diagnostics_card.dart';
import '../widgets/sidebar_navigation.dart';
import 'admin_data_screen.dart';
import 'deployed_sites_screen.dart';
import 'public_services_screen.dart';

/// 시스템 설정 허브 — 기존 관리 화면을 섹션으로 흡수.
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({
    super.key,
    required this.onNavigate,
    this.notificationController,
  });

  final ValueChanged<ControlDestination> onNavigate;
  final NotificationController? notificationController;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시스템 설정',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  '소통총관제 운영에 필요한 설정·연결·점검 정보를 모읍니다.',
                  style: TextStyle(color: ControlColors.textSecondary),
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '일반'),
              Tab(text: '데이터 관리'),
              Tab(text: '사이트 연결'),
              Tab(text: '기능 상태'),
              Tab(text: '레거시'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _GeneralTab(
                  onNavigate: onNavigate,
                  notificationController: notificationController,
                ),
                const AdminDataScreen(),
                const _SitesTab(),
                _StatusTab(onNavigate: onNavigate),
                _LegacyTab(onNavigate: onNavigate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({required this.onNavigate, this.notificationController});
  final ValueChanged<ControlDestination> onNavigate;
  final NotificationController? notificationController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (notificationController != null) ...[
          NotificationDiagnosticsCard(controller: notificationController!),
          const SizedBox(height: 12),
        ],
        const ListTile(
          title: Text('DevWorkDoc 연결'),
          subtitle: Text('작업지시 제작소에서 폴더 권한·경로를 설정합니다.'),
        ),
        const ListTile(
          title: Text('Inbox 연결'),
          subtitle: Text('Sotong24Work Inbox 전달은 작업지시 제작소에서 수행합니다.'),
        ),
        ListTile(
          title: const Text('작업지시 제작소 열기'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onNavigate(ControlDestination.aiBusinessAnalysis),
        ),
        const Divider(),
        const ListTile(
          title: Text('배포 정보'),
          subtitle: Text('Host: sotongware-control.web.app'),
        ),
        const ListTile(
          title: Text('버전'),
          subtitle: Text('Flutter Web · Firebase Hosting'),
        ),
        const ListTile(
          title: Text('브라우저 권한'),
          subtitle: Text(
            'File System Access는 Chromium 계열에서 DevWorkDoc/Inbox에 사용',
          ),
        ),
      ],
    );
  }
}

class _SitesTab extends StatelessWidget {
  const _SitesTab();

  @override
  Widget build(BuildContext context) {
    final sites = ExternalSiteLinks.hubSites;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in sites)
          ListTile(
            title: Text(s.title),
            subtitle: Text('${s.subtitle} · ${s.statusLabel}\n${s.url}'),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => ExternalUrl.open(s.url),
            ),
          ),
        const Divider(),
        const Text(
          '전체 배포사이트 화면',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 360, child: DeployedSitesScreen()),
      ],
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.onNavigate});
  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    Widget row(String name, String status, Color color) {
      return ListTile(
        title: Text(name),
        trailing: Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        row('작업지시 제작소', '정상', ControlColors.accentGreen),
        row('Planning Library', '정상', ControlColors.accentGreen),
        row('DevWorkDoc / Inbox', '주의(브라우저 권한)', ControlColors.accentWarm),
        row('실시간 수익·세무', '점검 필요(미연동)', ControlColors.accentRose),
        row('알람 이벤트 소스', '점검 필요(미연동)', ControlColors.accentRose),
        const Divider(),
        ListTile(
          title: const Text('운영 분석'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onNavigate(ControlDestination.operationsAnalysis),
        ),
        ListTile(
          title: const Text('전체 사업 현황'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onNavigate(ControlDestination.dashboardOverview),
        ),
      ],
    );
  }
}

class _LegacyTab extends StatelessWidget {
  const _LegacyTab({required this.onNavigate});
  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '사이드바에서 제거된 화면은 여기서 열 수 있습니다. 데이터는 삭제되지 않습니다.',
          style: TextStyle(color: ControlColors.textMuted),
        ),
        const SizedBox(height: 8),
        for (final d in [
          ControlDestination.dashboardOverview,
          ControlDestination.divisionProgress,
          ControlDestination.deployedSites,
          ControlDestination.operationsAnalysis,
          ControlDestination.portfolioHub,
          ControlDestination.adminData,
          ControlDestination.publicServices,
          ControlDestination.revenueProgress,
          ControlDestination.issuesCheck,
          ControlDestination.nextPriority,
          ControlDestination.sotong24work,
        ])
          ListTile(
            leading: Icon(d.icon, size: 20),
            title: Text(d.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onNavigate(d),
          ),
        const SizedBox(height: 12),
        const Text('공개 서비스', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 240, child: PublicServicesScreen()),
      ],
    );
  }
}
