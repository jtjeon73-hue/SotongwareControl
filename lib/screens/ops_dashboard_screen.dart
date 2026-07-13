import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../services/dashboard_service.dart';
import '../services/firebase_ready.dart';
import '../services/ops_repository.dart';
import '../services/ops_seed_service.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';
import '../widgets/sidebar_navigation.dart';

class OpsDashboardScreen extends StatelessWidget {
  const OpsDashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: 'Firebase 미연결',
          message: '관제 데이터는 Firebase 초기화 후 로그인하여 확인합니다.',
        ),
      );
    }

    final repo = OpsRepository();
    final dash = DashboardService();

    return StreamBuilder<List<BusinessUnitDoc>>(
      stream: repo.watchBusinessUnits(),
      builder: (context, unitSnap) {
        return StreamBuilder<List<ProjectDoc>>(
          stream: repo.watchProjects(),
          builder: (context, projectSnap) {
            return StreamBuilder<List<TaskDoc>>(
              stream: repo.watchTasks(),
              builder: (context, taskSnap) {
                return StreamBuilder<List<WorkLogDoc>>(
                  stream: repo.watchWorkLogs(),
                  builder: (context, logSnap) {
                    return StreamBuilder<List<DeploymentDoc>>(
                      stream: repo.watchDeployments(),
                      builder: (context, depSnap) {
                        return StreamBuilder<List<IssueDoc>>(
                          stream: repo.watchIssues(),
                          builder: (context, issueSnap) {
                            if (unitSnap.hasError ||
                                projectSnap.hasError ||
                                taskSnap.hasError) {
                              return _ErrorBody(
                                message:
                                    'Firestore 데이터를 불러오지 못했습니다. 로그인·보안 규칙·네트워크를 확인하세요.',
                                detail:
                                    '${unitSnap.error ?? projectSnap.error ?? taskSnap.error}',
                              );
                            }

                            final units = unitSnap.data ?? const [];
                            final projects = projectSnap.data ?? const [];
                            final tasks = taskSnap.data ?? const [];
                            final logs = logSnap.data ?? const [];
                            final deps = depSnap.data ?? const [];
                            final issues = issueSnap.data ?? const [];

                            final kpis = dash.computeKpis(
                              units: units,
                              projects: projects,
                              tasks: tasks,
                              logs: logs,
                              deployments: deps,
                            );
                            final attention = dash.attentionItems(
                              projects: projects,
                              tasks: tasks,
                              issues: issues,
                              deployments: deps,
                            );

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PageHero(
                                    title: '소통총괄관제',
                                    subtitle:
                                        '실제 Firestore 데이터 기준 운영 관제입니다. '
                                        '확인되지 않은 수치는 표시하지 않습니다.',
                                    badge: '데이터 기반 · 관리자 전용',
                                  ),
                                  const SizedBox(height: 16),
                                  if (units.isEmpty)
                                    EmptyStatePanel(
                                      title: '기본 구조 데이터가 없습니다',
                                      message:
                                          '사업부·확인된 프로젝트 골격을 생성한 뒤 관제를 시작하십시오.',
                                      actionLabel: '기본 구조 데이터 생성',
                                      onAction: () async {
                                        final msg = await OpsSeedService(
                                          repo,
                                        ).ensureStructure();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(msg)),
                                          );
                                        }
                                      },
                                    )
                                  else ...[
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        KpiCard(
                                          label: '사업부',
                                          value: '${kpis.unitCount}',
                                        ),
                                        KpiCard(
                                          label: '전체 프로젝트',
                                          value: '${kpis.projectCount}건',
                                        ),
                                        KpiCard(
                                          label: '진행 중',
                                          value: '${kpis.inProgress}건',
                                        ),
                                        KpiCard(
                                          label: '완료',
                                          value: '${kpis.completed}건',
                                        ),
                                        KpiCard(
                                          label: '보류',
                                          value: '${kpis.onHold}건',
                                        ),
                                        KpiCard(
                                          label: '문제',
                                          value: '${kpis.blocked}건',
                                        ),
                                        KpiCard(
                                          label: '오늘 할 일',
                                          value: '${kpis.todayTodos}건',
                                        ),
                                        KpiCard(
                                          label: '기한 초과',
                                          value: '${kpis.overdue}건',
                                        ),
                                        KpiCard(
                                          label: '배포 확인 필요',
                                          value: '${kpis.deployNeedsCheck}건',
                                        ),
                                        KpiCard(
                                          label: '최근 7일 작업',
                                          value: '${kpis.workLogs7d}건',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    _Section(
                                      title: '지금 확인할 사항',
                                      child: _BulletList(items: attention),
                                    ),
                                    const SizedBox(height: 16),
                                    _Section(
                                      title: '현재 진행 중 프로젝트',
                                      child: projects
                                              .where(
                                                (p) =>
                                                    p.status ==
                                                        ProjectStatus
                                                            .inProgress ||
                                                    p.status ==
                                                        ProjectStatus.testing ||
                                                    p.status ==
                                                        ProjectStatus.planning,
                                              )
                                              .isEmpty
                                          ? const Text(
                                              '등록된 진행 중 프로젝트가 없습니다.',
                                            )
                                          : Column(
                                              children: projects
                                                  .where(
                                                    (p) =>
                                                        p.status ==
                                                            ProjectStatus
                                                                .inProgress ||
                                                        p.status ==
                                                            ProjectStatus
                                                                .testing ||
                                                        p.status ==
                                                            ProjectStatus
                                                                .planning,
                                                  )
                                                  .take(8)
                                                  .map(
                                                    (p) => ListTile(
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      title: Text(p.name),
                                                      subtitle: Text(
                                                        '${ProjectStatus.labelKo(p.status)} · ${p.currentStage.isEmpty ? '단계 미등록' : p.currentStage}',
                                                      ),
                                                      trailing: Text(
                                                        p.computedProgress ==
                                                                null
                                                            ? '진행률 미설정'
                                                            : '${p.computedProgress}%',
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                    ),
                                    const SizedBox(height: 16),
                                    _Section(
                                      title: '앞으로 진행할 작업',
                                      child: tasks
                                              .where(
                                                (t) =>
                                                    t.status ==
                                                        TaskStatus.todo ||
                                                    t.status ==
                                                        TaskStatus.inProgress,
                                              )
                                              .isEmpty
                                          ? const Text(
                                              '등록된 다음 작업이 없습니다.',
                                            )
                                          : Column(
                                              children: tasks
                                                  .where(
                                                    (t) =>
                                                        t.status ==
                                                            TaskStatus.todo ||
                                                        t.status ==
                                                            TaskStatus
                                                                .inProgress,
                                                  )
                                                  .take(10)
                                                  .map(
                                                    (t) => ListTile(
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      title: Text(t.title),
                                                      subtitle: Text(
                                                        '${TaskStatus.labelKo(t.status)} · ${t.source}',
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                    ),
                                    const SizedBox(height: 16),
                                    _Section(
                                      title: '최근 Cursor·GitHub 작업',
                                      child: logs.isEmpty
                                          ? const Text(
                                              'Cursor 작업 기록이 없습니다. 작업 완료 후 로그를 등록하거나 JSON을 가져오십시오.',
                                            )
                                          : Column(
                                              children: logs.take(8).map((l) {
                                                final when = l.workedAt == null
                                                    ? '일시 미등록'
                                                    : DateFormat(
                                                        'yyyy-MM-dd HH:mm',
                                                      ).format(l.workedAt!);
                                                return ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(l.title),
                                                  subtitle: Text(
                                                    '$when · ${WorkLogSource.labelKo(l.source)}',
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                    ),
                                    const SizedBox(height: 16),
                                    _Section(
                                      title: '배포 상태',
                                      child: deps.isEmpty
                                          ? const Text(
                                              '등록된 배포 기록이 없습니다.',
                                            )
                                          : Column(
                                              children: deps.take(8).map((d) {
                                                return ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(d.projectId),
                                                  subtitle: Text(
                                                    '검사 ${d.analyzePassed ? '✓' : '·'} / '
                                                    '테스트 ${d.testPassed ? '✓' : '·'} / '
                                                    '빌드 ${d.buildPassed ? '✓' : '·'} / '
                                                    '커밋 ${d.gitCommitted ? '✓' : '·'} / '
                                                    '푸시 ${d.gitPushed ? '✓' : '·'} / '
                                                    'Firebase ${d.firebaseDeployed ? '✓' : '·'} / '
                                                    '실확인 ${d.siteVerified ? '✓' : '·'}',
                                                  ),
                                                  trailing: StatusBadge(
                                                    label: d.statusLabel,
                                                    color: d.isFullyComplete
                                                        ? ControlColors
                                                              .accentGreen
                                                        : ControlColors
                                                              .accentWarm,
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        FilledButton.tonal(
                                          onPressed: () => onNavigate(
                                            ControlDestination.sotong24work,
                                          ),
                                          child: const Text('소통24워크'),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: () => onNavigate(
                                            ControlDestination.adminData,
                                          ),
                                          child: const Text('데이터 관리'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
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
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: ControlColors.teal)),
                  Expanded(child: Text(e)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.detail});

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: EmptyStatePanel(
        title: '데이터 로딩 오류',
        message: '$message\n$detail',
      ),
    );
  }
}
