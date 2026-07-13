import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../screens/project_detail_screen.dart';
import '../services/dashboard_service.dart';
import '../services/firebase_ready.dart';
import '../services/ops_repository.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';

class Sotong24WorkScreen extends StatelessWidget {
  const Sotong24WorkScreen({super.key});

  static const unitId = 'sotong24work';

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '소통24워크',
          message: 'Firebase 연결 후 개발 영역 상태를 확인할 수 있습니다.',
        ),
      );
    }

    final repo = OpsRepository();
    final dash = DashboardService();

    return StreamBuilder<List<BusinessUnitDoc>>(
      stream: repo.watchBusinessUnits(),
      builder: (context, unitSnap) {
        return StreamBuilder<List<ProjectDoc>>(
          stream: repo.watchProjects(businessUnitId: unitId),
          builder: (context, projectSnap) {
            return StreamBuilder<List<WorkLogDoc>>(
              stream: repo.watchWorkLogs(),
              builder: (context, logSnap) {
                return StreamBuilder<List<IssueDoc>>(
                  stream: repo.watchIssues(),
                  builder: (context, issueSnap) {
                    if (projectSnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyStatePanel(
                          title: '데이터 로딩 오류',
                          message: '${projectSnap.error}',
                        ),
                      );
                    }

                    BusinessUnitDoc? unit;
                    for (final u in unitSnap.data ?? const <BusinessUnitDoc>[]) {
                      if (u.id == unitId) {
                        unit = u;
                        break;
                      }
                    }
                    final modules = projectSnap.data ?? const [];
                    final logs = (logSnap.data ?? const [])
                        .where((l) => l.businessUnitId == unitId)
                        .toList();
                    final openIssues = (issueSnap.data ?? const [])
                        .where(
                          (i) =>
                              i.status == 'open' &&
                              modules.any((m) => m.id == i.projectId),
                        )
                        .length;

                    final avg = dash.averageProgress(modules);
                    final completedCount = modules
                        .where((m) => m.status == ProjectStatus.completed)
                        .length;
                    final inProgressCount = modules
                        .where(
                          (m) =>
                              m.status == ProjectStatus.inProgress ||
                              m.status == ProjectStatus.testing ||
                              m.status == ProjectStatus.planning,
                        )
                        .length;
                    final nextActions = modules
                        .where((m) => m.nextAction.trim().isNotEmpty)
                        .length;
                    DateTime? lastWork;
                    for (final m in modules) {
                      if (m.lastWorkedAt == null) continue;
                      if (lastWork == null ||
                          m.lastWorkedAt!.isAfter(lastWork)) {
                        lastWork = m.lastWorkedAt;
                      }
                    }
                    for (final l in logs) {
                      if (l.workedAt == null) continue;
                      if (lastWork == null || l.workedAt!.isAfter(lastWork)) {
                        lastWork = l.workedAt;
                      }
                    }

                    final currentPage = modules
                        .where(
                          (m) =>
                              m.status == ProjectStatus.inProgress ||
                              m.status == ProjectStatus.testing,
                        )
                        .map((m) => m.name)
                        .join(', ');

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PageHero(
                            title: '소통24워크',
                            subtitle:
                                'MFC 기반 자동화 개발 프로그램 — 앱·전자책·마케팅·유튜브·MFC 개발 및 유지관리. '
                                '확인되지 않은 상태는 완료로 표시하지 않습니다.',
                            badge: unit?.status ?? '확인 필요',
                          ),
                          const SizedBox(height: 16),
                          if (unit == null && modules.isEmpty)
                            const EmptyStatePanel(
                              title: '소통24워크 데이터가 없습니다',
                              message:
                                  '데이터 관리에서 기본 구조를 생성하면 5개 개발 영역 카드가 준비됩니다.',
                            )
                          else ...[
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                KpiCard(
                                  label: '전체 개발 진행률',
                                  value: avg == null ? '미설정' : '$avg%',
                                ),
                                KpiCard(
                                  label: '현재 개발 상태',
                                  value: unit?.status ?? '확인 필요',
                                ),
                                KpiCard(
                                  label: '최근 작업일',
                                  value: lastWork == null
                                      ? '미등록'
                                      : DateFormat('yyyy-MM-dd')
                                          .format(lastWork),
                                ),
                                KpiCard(
                                  label: '현재 작업 페이지',
                                  value: currentPage.isEmpty
                                      ? '없음'
                                      : currentPage,
                                ),
                                KpiCard(
                                  label: '완료 기능',
                                  value: '$completedCount건',
                                ),
                                KpiCard(
                                  label: '진행 중 기능',
                                  value: '$inProgressCount건',
                                ),
                                KpiCard(
                                  label: '다음 우선 작업',
                                  value: '$nextActions건',
                                ),
                                KpiCard(
                                  label: '확인 필요 문제',
                                  value: '$openIssues건',
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '개발 영역별 상태',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: modules.isEmpty
                                  ? [
                                      const SizedBox(
                                        width: 320,
                                        child: EmptyStatePanel(
                                          title: '모듈 미등록',
                                          message: '기본 구조 데이터 생성이 필요합니다.',
                                        ),
                                      ),
                                    ]
                                  : modules
                                        .map(
                                          (m) => _ModuleCard(
                                            module: m,
                                            logs: logs
                                                .where(
                                                  (l) => l.projectId == m.id,
                                                )
                                                .toList(),
                                          ),
                                        )
                                        .toList(),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '소통24워크 작업 내역',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (logs.isEmpty)
                              const EmptyStatePanel(
                                title: 'Cursor 작업 기록이 없습니다',
                                message:
                                    '작업 완료 후 작업 로그를 등록하거나 JSON 기록을 가져오십시오.\n'
                                    '현재 상태: 확인 필요 · 최근 Cursor 작업: 등록된 기록 없음',
                              )
                            else
                              ...logs.map((l) => _WorkLogDetail(log: l)),
                            const SizedBox(height: 16),
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '자동 연동 상태',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '소통24워크 → Firestore 자동 연동은 아직 구현되지 않았습니다. '
                                      '연동 스키마는 docs/sotong24work_integration.md 를 참고하십시오.',
                                    ),
                                  ],
                                ),
                              ),
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
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.logs});

  final ProjectDoc module;
  final List<WorkLogDoc> logs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      module.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  StatusBadge(label: ProjectStatus.labelKo(module.status)),
                ],
              ),
              const SizedBox(height: 10),
              ProgressLabel(progress: module.computedProgress),
              const SizedBox(height: 8),
              Text(
                '현재 단계: ${module.currentStage.isEmpty ? '확인 필요' : module.currentStage}',
              ),
              Text(
                '다음 작업: ${module.nextAction.isEmpty ? '현재 프로젝트 소스 및 진행 단계 확인' : module.nextAction}',
              ),
              Text(
                '최근 Cursor 작업: ${logs.isEmpty ? '등록된 기록 없음' : logs.first.title}',
              ),
              Text(
                '최근 수정일: ${module.lastWorkedAt == null ? '미등록' : DateFormat('yyyy-MM-dd').format(module.lastWorkedAt!)}',
              ),
              if (module.repositoryUrl.isNotEmpty)
                Text(
                  'Git: ${module.repositoryUrl}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textMuted,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '대표 확인: ${module.needsCeoReview ? '필요' : '해당 없음'}',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProjectDetailScreen(projectId: module.id),
                      ),
                    );
                  },
                  child: const Text('상세보기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkLogDetail extends StatelessWidget {
  const _WorkLogDetail({required this.log});

  final WorkLogDoc log;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(log.title),
        subtitle: Text(
          '${log.workedAt == null ? '일시 미등록' : DateFormat('yyyy-MM-dd HH:mm').format(log.workedAt!)}'
          ' · ${WorkLogSource.labelKo(log.source)}'
          '${log.workType.isEmpty ? '' : ' · ${log.workType}'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _row('작업 요청', log.requestSummary),
          _row('수정 내용', log.resultSummary),
          _row(
            '수정 파일',
            log.changedFiles.isEmpty
                ? '등록된 정보 없음'
                : log.changedFiles.join(', '),
          ),
          _row('테스트', log.testResult.isEmpty ? '미등록' : log.testResult),
          _row('빌드', log.buildResult.isEmpty ? '미등록' : log.buildResult),
          _row(
            'Git 커밋',
            log.commitHash.isEmpty ? '미등록' : log.commitHash,
          ),
          _row(
            '다음 작업',
            log.nextAction.isEmpty ? '등록된 정보 없음' : log.nextAction,
          ),
          _row('기록 출처', WorkLogSource.labelKo(log.source)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
