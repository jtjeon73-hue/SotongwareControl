import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/business/business_catalog.dart';
import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../services/dashboard_service.dart';
import '../services/firebase_ready.dart';
import '../services/ops_repository.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';
import '../widgets/sidebar_navigation.dart';

class BusinessOverviewScreen extends StatelessWidget {
  const BusinessOverviewScreen({super.key, required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: 'Firebase 미연결',
          message: '실제 사업 현황은 Firebase 연결 후 확인할 수 있습니다.',
        ),
      );
    }
    final repository = OpsRepository();
    return StreamBuilder<List<ProjectDoc>>(
      stream: repository.watchProjects(),
      builder: (context, projectSnapshot) {
        return StreamBuilder<List<TaskDoc>>(
          stream: repository.watchTasks(),
          builder: (context, taskSnapshot) {
            return StreamBuilder<List<WorkLogDoc>>(
              stream: repository.watchWorkLogs(),
              builder: (context, logSnapshot) {
                return StreamBuilder<List<DeploymentDoc>>(
                  stream: repository.watchDeployments(),
                  builder: (context, deploymentSnapshot) {
                    return StreamBuilder<List<IssueDoc>>(
                      stream: repository.watchIssues(),
                      builder: (context, issueSnapshot) {
                        if (projectSnapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyStatePanel(
                              title: '사업 데이터를 불러오지 못했습니다',
                              message: '${projectSnapshot.error}',
                            ),
                          );
                        }
                        final projects = projectSnapshot.data ?? const [];
                        final tasks = taskSnapshot.data ?? const [];
                        final logs = logSnapshot.data ?? const [];
                        final deployments = deploymentSnapshot.data ?? const [];
                        final issues = issueSnapshot.data ?? const [];
                        return _OverviewBody(
                          projects: projects,
                          tasks: tasks,
                          logs: logs,
                          deployments: deployments,
                          issues: issues,
                          onNavigate: onNavigate,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.projects,
    required this.tasks,
    required this.logs,
    required this.deployments,
    required this.issues,
    required this.onNavigate,
  });

  final List<ProjectDoc> projects;
  final List<TaskDoc> tasks;
  final List<WorkLogDoc> logs;
  final List<DeploymentDoc> deployments;
  final List<IssueDoc> issues;
  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final active = projects.where(_isActive).length;
    final completed = projects
        .where((p) => p.status == ProjectStatus.completed)
        .length;
    final needsAttention = projects.where((p) {
      return p.status == ProjectStatus.blocked ||
          p.status == ProjectStatus.onHold ||
          p.needsCeoReview ||
          issues.any((i) => i.projectId == p.id && i.status == 'open');
    }).length;
    final recentProjectIds = logs
        .where((l) => l.workedAt?.isAfter(weekAgo) == true)
        .map((l) => l.projectId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final deployed = deployments.where((d) => d.isFullyComplete).length;
    final githubActivities = logs
        .where(
          (l) =>
              l.commitHash.isNotEmpty && l.workedAt?.isAfter(weekAgo) == true,
        )
        .length;
    final risks = issues
        .where(
          (i) =>
              i.status == 'open' &&
              (i.severity == 'high' || i.severity == 'critical'),
        )
        .length;
    final attention = DashboardService().attentionItems(
      projects: projects,
      tasks: tasks,
      issues: issues,
      deployments: deployments,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: '전체 사업 현황',
            subtitle: '5개 핵심 사업의 개발·운영·성장 준비도를 실제 프로젝트, 작업 로그, 배포 기록으로 확인합니다.',
            badge: '통합 사업 관제',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const KpiCard(label: '핵심 사업', value: '5개'),
              KpiCard(label: '전체 프로젝트', value: '${projects.length}건'),
              KpiCard(label: '진행 중', value: '$active건'),
              KpiCard(label: '완료', value: '$completed건'),
              KpiCard(label: '보완 필요', value: '$needsAttention건'),
              KpiCard(label: '최근 7일 활동', value: '${recentProjectIds.length}개'),
              KpiCard(label: '배포 완료 기록', value: '$deployed건'),
              KpiCard(label: 'GitHub 활동 기록', value: '$githubActivities건'),
              KpiCard(label: '위험·주의', value: '$risks건'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: ControlColors.warningBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 확인할 사항',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in attention.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $item'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '5개 사업 비교',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    onNavigate(ControlDestination.aiBusinessAnalysis),
                icon: const Icon(Icons.auto_graph_outlined),
                label: const Text('전체 사업 분석'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1180
                  ? 3
                  : constraints.maxWidth >= 720
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final business in BusinessCatalog.businesses)
                    SizedBox(
                      width: width,
                      child: _BusinessCard(
                        business: business,
                        projects: projects
                            .where((p) => business.matches(p.businessUnitId))
                            .toList(),
                        tasks: tasks
                            .where((t) => business.matches(t.businessUnitId))
                            .toList(),
                        logs: logs
                            .where((l) => business.matches(l.businessUnitId))
                            .toList(),
                        deployments: deployments,
                        issues: issues,
                        onOpenDivision: () =>
                            onNavigate(_destinationFor(business.id)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '사업 연결 구조',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '산업자동화 → 앱·웹 모니터링 → 마케팅 사이트 → 고객 확보\n'
                    '앱개발 → 프로모 사이트 → 콘텐츠 홍보 → 전자책·교육 연결\n'
                    '전자책 ↔ 콘텐츠 제작 → 웹마케팅 → 모든 사업의 고객 유입',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('오늘의 사업 지식'),
              subtitle: Text(
                BusinessCatalog.businesses[now.day % 5].todayKnowledge,
              ),
              trailing: TextButton(
                onPressed: () => onNavigate(ControlDestination.businessStudy),
                child: const Text('학습하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isActive(ProjectDoc project) =>
      project.status == ProjectStatus.inProgress ||
      project.status == ProjectStatus.testing ||
      project.status == ProjectStatus.planning;

  static ControlDestination _destinationFor(String businessId) {
    switch (businessId) {
      case 'industrial_automation':
        return ControlDestination.industrialAutomation;
      case 'app_development':
        return ControlDestination.appDevelopment;
      case 'ebook':
        return ControlDestination.ebook;
      case 'content_music':
        return ControlDestination.youtubeContent;
      case 'web_marketing':
        return ControlDestination.webMarketing;
      default:
        return ControlDestination.divisionProgress;
    }
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.projects,
    required this.tasks,
    required this.logs,
    required this.deployments,
    required this.issues,
    required this.onOpenDivision,
  });

  final BusinessDefinition business;
  final List<ProjectDoc> projects;
  final List<TaskDoc> tasks;
  final List<WorkLogDoc> logs;
  final List<DeploymentDoc> deployments;
  final List<IssueDoc> issues;
  final VoidCallback onOpenDivision;

  @override
  Widget build(BuildContext context) {
    final active = projects.where(_OverviewBody._isActive).length;
    final completed = projects
        .where((p) => p.status == ProjectStatus.completed)
        .length;
    final problem = projects.where((p) {
      return p.status == ProjectStatus.blocked ||
          p.status == ProjectStatus.onHold ||
          issues.any((i) => i.projectId == p.id && i.status == 'open');
    }).length;
    final values = projects
        .map((p) => p.computedProgress)
        .whereType<int>()
        .toList();
    final progress = values.isEmpty
        ? null
        : (values.reduce((a, b) => a + b) / values.length).round();
    final sortedLogs = [...logs]
      ..sort(
        (a, b) => (b.workedAt ?? DateTime(1970)).compareTo(
          a.workedAt ?? DateTime(1970),
        ),
      );
    final latestLog = sortedLogs.firstOrNull;
    final relatedDeployments = deployments
        .where((d) => projects.any((p) => p.id == d.projectId))
        .toList();
    final importantTasks = tasks
        .where(
          (t) =>
              t.status != TaskStatus.completed &&
              t.status != TaskStatus.cancelled,
        )
        .toList();
    final repositoryUrl = projects
        .map((p) => p.repositoryUrl.trim())
        .where((url) => url.isNotEmpty)
        .firstOrNull;
    final deploymentUrl =
        relatedDeployments
            .map((d) => d.siteUrl.trim())
            .where((url) => url.isNotEmpty)
            .firstOrNull ??
        projects
            .expand((p) => [p.firebaseUrl, p.websiteUrl, p.promoUrl])
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .firstOrNull;
    final biggestGap = projects.isEmpty
        ? '등록된 프로젝트 없음'
        : problem > 0
        ? '주의·보완 프로젝트 $problem건'
        : relatedDeployments.isEmpty
        ? '배포 상태 기록 없음'
        : '등록 근거에서 큰 문제 없음';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              business.shortName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              business.purpose,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress == null ? 0 : progress / 100,
            ),
            const SizedBox(height: 4),
            Text('진행률: ${progress == null ? '미설정' : '$progress%'}'),
            Text('프로젝트 ${projects.length} · 진행 $active · 완료 $completed'),
            Text('최근 작업: ${_date(latestLog?.workedAt)}'),
            Text(
              '최근 GitHub: ${latestLog?.commitHash.isNotEmpty == true ? latestLog!.commitMessage : '내부 기록 없음'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '최근 배포: ${relatedDeployments.firstOrNull?.statusLabel ?? '기록 없음'}',
            ),
            const SizedBox(height: 8),
            Text(
              '중요 작업: ${importantTasks.firstOrNull?.title ?? '등록 필요'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '미흡 사항: $biggestGap',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '다음 권장: ${importantTasks.firstOrNull?.title ?? projects.map((p) => p.nextAction).where((e) => e.isNotEmpty).firstOrNull ?? '다음 작업 등록'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: onOpenDivision,
                  child: const Text('관련 프로젝트'),
                ),
                TextButton.icon(
                  onPressed: () => ExternalUrl.open(business.site.url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('대표 사이트'),
                ),
                if (repositoryUrl != null)
                  TextButton.icon(
                    onPressed: () => ExternalUrl.open(repositoryUrl),
                    icon: const Icon(Icons.code, size: 16),
                    label: const Text('GitHub'),
                  ),
                if (deploymentUrl != null)
                  TextButton.icon(
                    onPressed: () => ExternalUrl.open(deploymentUrl),
                    icon: const Icon(Icons.rocket_launch_outlined, size: 16),
                    label: const Text('배포 사이트'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime? date) =>
      date == null ? '기록 없음' : DateFormat('yyyy-MM-dd').format(date);
}
