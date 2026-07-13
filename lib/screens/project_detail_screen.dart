import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../services/firebase_ready.dart';
import '../services/github_service.dart';
import '../services/ops_repository.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../widgets/deployment_checklist.dart';
import '../widgets/ops_ui.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  OpsRepository? _repo;
  final _gh = GithubService();
  List<GithubCommitInfo> _commits = const [];
  String? _ghError;
  DateTime? _ghFetchedAt;
  bool _ghLoading = false;

  OpsRepository get repo => _repo ??= OpsRepository();

  Future<void> _loadCommits(String? repoUrl) async {
    if (repoUrl == null || repoUrl.trim().isEmpty) {
      setState(() {
        _commits = const [];
        _ghError = '저장소 주소가 등록되지 않았습니다.';
        _ghFetchedAt = DateTime.now();
      });
      return;
    }
    final parsed = GithubService.parseGithubUrl(repoUrl);
    if (parsed == null) {
      setState(() {
        _commits = const [];
        _ghError = '저장소 주소 형식이 올바르지 않습니다.';
        _ghFetchedAt = DateTime.now();
      });
      return;
    }
    setState(() {
      _ghLoading = true;
      _ghError = null;
    });
    try {
      final list = await _gh.fetchRecentCommits(
        owner: parsed.owner,
        repo: parsed.repo,
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _commits = list;
        _ghFetchedAt = DateTime.now();
        _ghLoading = false;
        if (list.isEmpty) {
          _ghError = '조회된 공개 커밋이 없습니다.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ghLoading = false;
        _ghFetchedAt = DateTime.now();
        _ghError =
            '비공개 저장소이거나 조회에 실패했습니다. '
            '브라우저에 GitHub Token을 넣지 않습니다.\n$e';
        _commits = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return Scaffold(
        appBar: AppBar(title: const Text('프로젝트 상세')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStatePanel(
            title: 'Firebase 미연결',
            message: '로그인 후 프로젝트 상세를 확인할 수 있습니다.',
          ),
        ),
      );
    }

    return StreamBuilder<ProjectDoc?>(
      stream: repo.watchProject(widget.projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('프로젝트 상세')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final p = snap.data;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('프로젝트 상세')),
            body: const Padding(
              padding: EdgeInsets.all(24),
              child: EmptyStatePanel(
                title: '프로젝트를 찾을 수 없습니다',
                message: '삭제되었거나 ID가 올바르지 않습니다.',
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(p.name, overflow: TextOverflow.ellipsis),
            actions: [
              if (p.isStale)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: StatusBadge(
                      label: '상태 확인 필요',
                      color: ControlColors.accentWarm,
                    ),
                  ),
                ),
            ],
          ),
          body: StreamBuilder<List<WorkLogDoc>>(
            stream: repo.watchWorkLogs(limit: 80),
            builder: (context, logSnap) {
              return StreamBuilder<List<DeploymentDoc>>(
                stream: repo.watchDeployments(projectId: p.id),
                builder: (context, depSnap) {
                  return StreamBuilder<List<IssueDoc>>(
                    stream: repo.watchIssues(projectId: p.id),
                    builder: (context, issueSnap) {
                      final logs = (logSnap.data ?? const [])
                          .where((l) => l.projectId == p.id)
                          .toList();
                      final deps = depSnap.data ?? const [];
                      final issues = issueSnap.data ?? const [];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusBadge(
                                  label: ProjectStatus.labelKo(p.status),
                                ),
                                StatusBadge(label: '우선순위 ${p.priority}'),
                                if (p.needsCeoReview)
                                  const StatusBadge(
                                    label: '대표 확인 필요',
                                    color: ControlColors.accentWarm,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _Section(
                              title: '기본정보',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _kv('프로젝트명', p.name),
                                  _kv('사업부', p.businessUnitId),
                                  _kv(
                                    '유형',
                                    p.projectType.isEmpty
                                        ? '미등록'
                                        : p.projectType,
                                  ),
                                  _kv(
                                    '상태',
                                    ProjectStatus.labelKo(p.status),
                                  ),
                                  _kv('우선순위', p.priority),
                                  _kv('시작일', _fmtDate(p.startedAt)),
                                  _kv('목표일', _fmtDate(p.targetDate)),
                                  _kv('최근 작업일', _fmtDate(p.lastWorkedAt)),
                                  _kv(
                                    '최근 업데이트',
                                    _fmtDate(p.updatedAt),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: '개발 진행',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ProgressLabel(
                                    progress: p.computedProgress,
                                  ),
                                  const SizedBox(height: 8),
                                  _kv(
                                    '전체 단계',
                                    p.totalStages == 0
                                        ? '미등록'
                                        : '${p.totalStages}',
                                  ),
                                  _kv(
                                    '완료 단계',
                                    '${p.completedStages}',
                                  ),
                                  _kv(
                                    '현재 단계',
                                    p.currentStage.isEmpty
                                        ? '확인 필요'
                                        : p.currentStage,
                                  ),
                                  _kv(
                                    '다음 작업',
                                    p.nextAction.isEmpty
                                        ? '실제 상태 확인'
                                        : p.nextAction,
                                  ),
                                  _kv(
                                    '보류 사유',
                                    p.holdReason.isEmpty
                                        ? '없음'
                                        : p.holdReason,
                                  ),
                                  _kv(
                                    '최근 작업',
                                    logs.isEmpty
                                        ? '기록 없음'
                                        : logs.first.title,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: '관련 주소',
                              child: Column(
                                children: [
                                  _link('GitHub', p.repositoryUrl),
                                  _link('운영 사이트', p.websiteUrl),
                                  _link('프로모', p.promoUrl),
                                  _link('Firebase', p.firebaseUrl),
                                  _link('APK', p.apkUrl),
                                  _link('PDF', p.pdfUrl),
                                  _link('기타', p.otherUrl),
                                  if ([
                                    p.repositoryUrl,
                                    p.websiteUrl,
                                    p.promoUrl,
                                    p.firebaseUrl,
                                    p.apkUrl,
                                    p.pdfUrl,
                                    p.otherUrl,
                                  ].every((e) => e.isEmpty))
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('등록된 주소 없음'),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: '다음 행동',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _kv(
                                    '다음 작업',
                                    p.nextAction.isEmpty
                                        ? '등록된 정보 없음'
                                        : p.nextAction,
                                  ),
                                  _kv('담당 사업부', p.businessUnitId),
                                  _kv('우선순위', p.priority),
                                  _kv('목표일', _fmtDate(p.targetDate)),
                                  _kv(
                                    '대표 확인',
                                    p.needsCeoReview ? '필요' : '해당 없음',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: '최근 Cursor 작업',
                              child: logs.isEmpty
                                  ? const Text('등록된 기록 없음')
                                  : Column(
                                      children: logs
                                          .take(5)
                                          .map(
                                            (l) => ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(l.title),
                                              subtitle: Text(
                                                '${_fmtDate(l.workedAt)} · ${WorkLogSource.labelKo(l.source)}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: 'GitHub 최근 커밋',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: _ghLoading
                                            ? null
                                            : () =>
                                                _loadCommits(p.repositoryUrl),
                                        child: Text(
                                          _ghLoading ? '조회 중…' : '새로고침',
                                        ),
                                      ),
                                      if (_ghFetchedAt != null)
                                        Text(
                                          '최근 조회: ${_fmtDate(_ghFetchedAt)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ControlColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_ghError != null) Text(_ghError!),
                                  ..._commits.map(
                                    (c) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        c.message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${c.author} · ${c.sha} · ${_fmtDate(c.date)}',
                                      ),
                                      trailing: c.url.isEmpty
                                          ? null
                                          : IconButton(
                                              icon: const Icon(
                                                Icons.open_in_new,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  ExternalUrl.open(c.url),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: '배포 기록',
                              child: deps.isEmpty
                                  ? const Text('등록된 배포 기록 없음')
                                  : Column(
                                      children: deps
                                          .map(
                                            (d) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: DeploymentChecklistCard(
                                                deployment: d,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: '문제',
                              child: issues.isEmpty
                                  ? const Text('등록된 문제 없음')
                                  : Column(
                                      children: issues
                                          .map(
                                            (i) => ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(i.title),
                                              subtitle: Text(
                                                '${i.status} · ${i.severity}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!isFirebaseReady()) return;
      final p = await repo.getProject(widget.projectId);
      if (p != null) await _loadCommits(p.repositoryUrl);
    });
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: const TextStyle(color: ControlColors.textMuted),
          ),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );

  Widget _link(String label, String url) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new, size: 18),
        onPressed: () => ExternalUrl.open(url),
      ),
    );
  }

  String _fmtDate(DateTime? d) =>
      d == null ? '미등록' : DateFormat('yyyy-MM-dd HH:mm').format(d);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
