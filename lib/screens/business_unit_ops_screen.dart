import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/business/business_catalog.dart';
import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../screens/project_detail_screen.dart';
import '../services/dashboard_service.dart';
import '../services/firebase_ready.dart';
import '../services/github_service.dart';
import '../services/ops_repository.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';

class BusinessUnitOpsScreen extends StatelessWidget {
  const BusinessUnitOpsScreen({
    super.key,
    required this.businessUnitId,
    required this.fallbackTitle,
    this.recommendedPlan = const [],
  });

  final String businessUnitId;
  final String fallbackTitle;
  final List<String> recommendedPlan;

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: fallbackTitle,
          message: 'Firebase 연결 후 사업부 데이터를 확인할 수 있습니다.',
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
                    return StreamBuilder<List<IssueDoc>>(
                      stream: repo.watchIssues(),
                      builder: (context, issueSnap) {
                        if (projectSnap.hasError || unitSnap.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyStatePanel(
                              title: '데이터 로딩 오류',
                              message: '${projectSnap.error ?? unitSnap.error}',
                            ),
                          );
                        }

                        BusinessUnitDoc? unit;
                        for (final u
                            in unitSnap.data ?? const <BusinessUnitDoc>[]) {
                          if (u.id == businessUnitId) {
                            unit = u;
                            break;
                          }
                        }
                        final business = BusinessCatalog.byId(businessUnitId);
                        final projects = (projectSnap.data ?? const [])
                            .where(
                              (p) =>
                                  business?.matches(p.businessUnitId) ??
                                  p.businessUnitId == businessUnitId,
                            )
                            .toList();
                        final tasks = (taskSnap.data ?? const [])
                            .where(
                              (t) =>
                                  business?.matches(t.businessUnitId) ??
                                  t.businessUnitId == businessUnitId,
                            )
                            .toList();
                        final logs = (logSnap.data ?? const [])
                            .where(
                              (l) =>
                                  business?.matches(l.businessUnitId) ??
                                  l.businessUnitId == businessUnitId,
                            )
                            .toList();
                        final issues = (issueSnap.data ?? const []).where((i) {
                          return projects.any((p) => p.id == i.projectId) ||
                              i.projectId.isEmpty;
                        }).toList();

                        final title =
                            business?.name ?? unit?.name ?? fallbackTitle;
                        final inProgress = projects
                            .where(
                              (p) =>
                                  p.status == ProjectStatus.inProgress ||
                                  p.status == ProjectStatus.testing ||
                                  p.status == ProjectStatus.planning,
                            )
                            .length;
                        final completed = projects
                            .where((p) => p.status == ProjectStatus.completed)
                            .length;
                        final onHold = projects
                            .where((p) => p.status == ProjectStatus.onHold)
                            .length;
                        final blocked = projects
                            .where((p) => p.status == ProjectStatus.blocked)
                            .length;
                        final avg = dash.averageProgress(projects);

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PageHero(
                                title: title,
                                subtitle: unit?.description.isNotEmpty == true
                                    ? unit!.description
                                    : 'Firestore에 등록된 실제 현황만 표시합니다.',
                                badge: unit?.status ?? '확인 필요',
                              ),
                              const SizedBox(height: 16),
                              if (business != null) ...[
                                _InfoCard(
                                  title: '사업 방향',
                                  lines: [
                                    '목적: ${business.purpose}',
                                    '방향: ${business.direction}',
                                    '주요 고객: ${business.customers}',
                                    '수익 방식: ${business.revenueModel}',
                                  ],
                                  note: '수익 금액은 실제 데이터가 연결되기 전까지 표시하지 않습니다.',
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (unit == null && projects.isEmpty)
                                EmptyStatePanel(
                                  title: '아직 등록된 정보가 없습니다',
                                  message:
                                      '데이터 관리에서 기본 구조를 생성하거나 프로젝트를 등록하십시오.',
                                )
                              else ...[
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    KpiCard(
                                      label: '전체 프로젝트',
                                      value: '${projects.length}건',
                                    ),
                                    KpiCard(
                                      label: '진행 중',
                                      value: '$inProgress건',
                                    ),
                                    KpiCard(label: '완료', value: '$completed건'),
                                    KpiCard(label: '보류', value: '$onHold건'),
                                    KpiCard(label: '문제', value: '$blocked건'),
                                    KpiCard(
                                      label: '평균 진행률',
                                      value: avg == null ? '미설정' : '$avg%',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _InfoCard(
                                  title: '사업부 상태',
                                  lines: [
                                    '상태: ${unit?.status ?? '확인 필요'}',
                                    '현재 핵심 작업: ${_orEmpty(unit?.currentFocus)}',
                                    '다음 진행: ${_orEmpty(unit?.nextAction)}',
                                    '최근 업데이트: ${_fmt(unit?.updatedAt)}',
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (recommendedPlan.isNotEmpty)
                                  _InfoCard(
                                    title: '권장 진행 절차 (다음 진행 계획)',
                                    lines: recommendedPlan
                                        .asMap()
                                        .entries
                                        .map((e) => '${e.key + 1}. ${e.value}')
                                        .toList(),
                                    note: '이 목록은 완료된 작업이 아닙니다. 앞으로 진행할 절차입니다.',
                                  ),
                                if (recommendedPlan.isNotEmpty)
                                  const SizedBox(height: 12),
                                if (business != null) ...[
                                  _InfoCard(
                                    title: '사업 기본 지식',
                                    lines: business.knowledge
                                        .map((item) => '• $item')
                                        .toList(),
                                    note:
                                        '기술·영업·품질·유지관리 지식을 실제 프로젝트와 연결해 확인합니다.',
                                  ),
                                  const SizedBox(height: 12),
                                  _InfoCard(
                                    title: '오늘의 학습',
                                    lines: [business.todayKnowledge],
                                    note:
                                        '소통웨어 적용: 현재 프로젝트 하나를 선택해 이 지식의 실행 항목을 작업 로그에 남기십시오.',
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  '프로젝트',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                if (projects.isEmpty)
                                  EmptyStatePanel(
                                    title: '아직 등록된 프로젝트가 없습니다',
                                    message: '첫 프로젝트를 등록하여 사업부 관리를 시작하십시오.',
                                  )
                                else
                                  ...projects.map(
                                    (p) => InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ProjectDetailScreen(
                                              projectId: p.id,
                                            ),
                                          ),
                                        );
                                      },
                                      child: _ProjectTile(project: p),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                _InfoCard(
                                  title: '할 일 / 다음 작업',
                                  lines: tasks.isEmpty
                                      ? ['등록된 정보 없음']
                                      : tasks
                                            .take(12)
                                            .map(
                                              (t) =>
                                                  '${TaskStatus.labelKo(t.status)} · ${t.title}'
                                                  '${t.description.isEmpty ? '' : ' — ${t.description}'}',
                                            )
                                            .toList(),
                                ),
                                const SizedBox(height: 12),
                                _InfoCard(
                                  title: '해결해야 할 문제',
                                  lines:
                                      issues
                                          .where((i) => i.status == 'open')
                                          .isEmpty
                                      ? ['등록된 문제 없음']
                                      : issues
                                            .where((i) => i.status == 'open')
                                            .map(
                                              (i) =>
                                                  '[${i.severity}] ${i.title}',
                                            )
                                            .toList(),
                                ),
                                const SizedBox(height: 12),
                                _InfoCard(
                                  title: '최근 Cursor / GitHub 작업',
                                  lines: logs.isEmpty
                                      ? [
                                          '등록된 기록 없음',
                                          '작업 완료 후 작업 로그를 등록하거나 JSON을 가져오십시오.',
                                        ]
                                      : logs
                                            .take(8)
                                            .map(
                                              (l) =>
                                                  '${_fmt(l.workedAt)} · ${l.title} (${WorkLogSource.labelKo(l.source)})',
                                            )
                                            .toList(),
                                ),
                                const SizedBox(height: 12),
                                _RepoSection(projects: projects),
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
  }

  static String _orEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? '등록된 정보 없음' : v.trim();

  static String _fmt(DateTime? d) =>
      d == null ? '미등록' : DateFormat('yyyy-MM-dd HH:mm').format(d);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines, this.note});

  final String title;
  final List<String> lines;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: ControlColors.accentWarm,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final ProjectDoc project;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                StatusBadge(label: ProjectStatus.labelKo(project.status)),
              ],
            ),
            const SizedBox(height: 8),
            ProgressLabel(progress: project.computedProgress),
            const SizedBox(height: 8),
            Text(
              '현재 단계: ${project.currentStage.isEmpty ? '확인 필요' : project.currentStage}',
            ),
            Text(
              '다음 작업: ${project.nextAction.isEmpty ? '등록된 정보 없음' : project.nextAction}',
            ),
            if (project.repositoryUrl.isNotEmpty)
              Text(
                '저장소: ${project.repositoryUrl}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (project.websiteUrl.isNotEmpty ||
                project.firebaseUrl.isNotEmpty ||
                project.promoUrl.isNotEmpty)
              Text(
                '웹사이트: ${[project.websiteUrl, project.firebaseUrl, project.promoUrl].where((e) => e.isNotEmpty).join(' · ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _RepoSection extends StatefulWidget {
  const _RepoSection({required this.projects});

  final List<ProjectDoc> projects;

  @override
  State<_RepoSection> createState() => _RepoSectionState();
}

class _RepoSectionState extends State<_RepoSection> {
  String? _message;
  List<GithubCommitInfo> _commits = const [];
  bool _loading = false;

  Future<void> _load() async {
    final withRepo = widget.projects
        .where((p) => p.repositoryUrl.trim().isNotEmpty)
        .toList();
    if (withRepo.isEmpty) {
      setState(() {
        _message = '관련 저장소가 등록되지 않았습니다.';
        _commits = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    final gh = GithubService();
    final all = <GithubCommitInfo>[];
    for (final p in withRepo.take(3)) {
      final parsed = GithubService.parseGithubUrl(p.repositoryUrl);
      if (parsed == null) continue;
      try {
        final list = await gh.fetchRecentCommits(
          owner: parsed.owner,
          repo: parsed.repo,
          limit: 3,
        );
        all.addAll(list);
      } catch (e) {
        setState(() {
          _message =
              '비공개 저장소 자동 조회는 아직 연결되지 않았거나 조회에 실패했습니다.\n'
              '수동 작업 기록 또는 관리자용 동기화 기능을 사용하십시오.\n($e)';
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _commits = all;
      if (all.isEmpty && _message == null) {
        _message = '조회된 공개 커밋이 없습니다.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '관련 저장소 · 최근 커밋',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _load,
                  child: Text(_loading ? '조회 중…' : '공개 저장소 조회'),
                ),
              ],
            ),
            ...widget.projects
                .where((p) => p.repositoryUrl.isNotEmpty)
                .map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(p.name),
                    subtitle: Text(
                      p.repositoryUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => ExternalUrl.open(p.repositoryUrl),
                    ),
                  ),
                ),
            if (_message != null) Text(_message!),
            ..._commits.map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${c.repo} · ${c.author} · ${c.sha}'),
                trailing: c.url.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.link, size: 18),
                        onPressed: () => ExternalUrl.open(c.url),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
