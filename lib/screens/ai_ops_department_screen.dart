import 'package:flutter/material.dart';

import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../services/dashboard_service.dart';
import '../services/firebase_ready.dart';
import '../services/ops_repository.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';

/// Firestore 기반 규칙 요약. AI 자동 생성은 미연결 표시.
class AiOpsDepartmentScreen extends StatelessWidget {
  const AiOpsDepartmentScreen({
    super.key,
    required this.departmentId,
    required this.title,
    required this.roleSummary,
  });

  final String departmentId;
  final String title;
  final String roleSummary;

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: title,
          message: 'Firebase 연결 후 AI 부서 요약을 확인할 수 있습니다.\nAI 자동 분석 미연결',
        ),
      );
    }

    final repo = OpsRepository();
    final dash = DashboardService();

    return StreamBuilder<List<ProjectDoc>>(
      stream: repo.watchProjects(),
      builder: (context, projectSnap) {
        return StreamBuilder<List<TaskDoc>>(
          stream: repo.watchTasks(),
          builder: (context, taskSnap) {
            return StreamBuilder<List<IssueDoc>>(
              stream: repo.watchIssues(),
              builder: (context, issueSnap) {
                return StreamBuilder<List<BusinessUnitDoc>>(
                  stream: repo.watchBusinessUnits(),
                  builder: (context, unitSnap) {
                    return StreamBuilder<List<AiReportDoc>>(
                      stream: repo.watchAiReports(departmentId: departmentId),
                      builder: (context, reportSnap) {
                        final projects = projectSnap.data ?? const [];
                        final tasks = taskSnap.data ?? const [];
                        final issues = issueSnap.data ?? const [];
                        final units = unitSnap.data ?? const [];
                        final reports = reportSnap.data ?? const [];
                        final kpis = dash.computeKpis(
                          units: units,
                          projects: projects,
                          tasks: tasks,
                          logs: const [],
                          deployments: const [],
                        );

                        final facts = <String>[
                          '사업부 ${kpis.unitCount}개 · 프로젝트 ${kpis.projectCount}건',
                          '진행 중 ${kpis.inProgress}건 · 완료 ${kpis.completed}건 · 보류 ${kpis.onHold}건 · 문제 ${kpis.blocked}건',
                          '오늘 할 일 ${kpis.todayTodos}건 · 기한 초과 ${kpis.overdue}건',
                        ];
                        final risks = dash.attentionItems(
                          projects: projects,
                          tasks: tasks,
                          issues: issues,
                          deployments: const [],
                        );
                        final priorities = tasks
                            .where(
                              (t) =>
                                  t.status == TaskStatus.todo ||
                                  t.status == TaskStatus.inProgress,
                            )
                            .take(8)
                            .map(
                              (t) =>
                                  '${t.title} (${TaskStatus.labelKo(t.status)}'
                                  '${t.approved ? ' · 승인됨' : ''}'
                                  ' · 출처: ${t.source})',
                            )
                            .toList();
                        final approvals = tasks
                            .where(
                              (t) =>
                                  !t.approved &&
                                  t.status != TaskStatus.completed &&
                                  t.status != TaskStatus.cancelled,
                            )
                            .take(8)
                            .map((t) => t.title)
                            .toList();

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PageHero(
                                title: title,
                                subtitle: roleSummary,
                                badge: '규칙 기반 요약',
                              ),
                              const SizedBox(height: 12),
                              const StatusBadge(
                                label: 'AI 자동 분석 미연결',
                                color: ControlColors.accentWarm,
                              ),
                              const SizedBox(height: 16),
                              _Block(title: '현재 사실', items: facts),
                              const SizedBox(height: 12),
                              _Block(
                                title: '문제 및 위험',
                                items: risks,
                              ),
                              const SizedBox(height: 12),
                              _Block(
                                title: '추천 우선순위',
                                items: priorities.isEmpty
                                    ? ['등록된 다음 작업이 없습니다.']
                                    : priorities,
                              ),
                              const SizedBox(height: 12),
                              _Block(
                                title: '대표 승인 필요',
                                items: approvals.isEmpty
                                    ? ['승인 대기 항목이 없습니다.']
                                    : approvals,
                              ),
                              const SizedBox(height: 12),
                              _DepartmentExtras(
                                departmentId: departmentId,
                                projects: projects,
                                tasks: tasks,
                                units: units,
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '등록된 AI 보고서',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      if (reports.isEmpty)
                                        const Text(
                                          '등록된 보고서가 없습니다. 관리자가 확인한 내용만 등록하십시오.',
                                        )
                                      else
                                        ...reports.map(
                                          (r) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(r.title),
                                            subtitle: Text(
                                              r.aiConnected
                                                  ? r.summary
                                                  : '${r.summary}\n(AI 자동 분석 미연결 · 수동/규칙 기반)',
                                            ),
                                            trailing: StatusBadge(
                                              label: r.approved
                                                  ? '승인됨'
                                                  : '미승인',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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
            );
          },
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.items});

  final String title;
  final List<String> items;

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
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentExtras extends StatelessWidget {
  const _DepartmentExtras({
    required this.departmentId,
    required this.projects,
    required this.tasks,
    required this.units,
  });

  final String departmentId;
  final List<ProjectDoc> projects;
  final List<TaskDoc> tasks;
  final List<BusinessUnitDoc> units;

  @override
  Widget build(BuildContext context) {
    switch (departmentId) {
      case 'workorder':
        return _Block(
          title: '지시·진행 업무',
          items: tasks.isEmpty
              ? ['등록된 업무가 없습니다.']
              : tasks
                    .take(15)
                    .map(
                      (t) =>
                          '${t.title} · ${TaskStatus.labelKo(t.status)} · '
                          '${t.source == 'manual' ? '회장/수동' : 'AI/시스템 제안'} · '
                          '승인 ${t.approved ? '예' : '아니오'}',
                    )
                    .toList(),
        );
      case 'idea':
        return _IdeaPanel(repo: OpsRepository());
      case 'marketing':
        return _Block(
          title: '홍보·고객 대응',
          items: [
            '프로모 있는 프로젝트: ${projects.where((p) => p.promoUrl.isNotEmpty).length}건',
            '프로모 없는 프로젝트: ${projects.where((p) => p.promoUrl.isEmpty && p.projectType.contains('app')).length}건',
            '홍보 완료로 단정하지 않습니다. 고객 문의·후속 연락: 미등록',
          ],
        );
      case 'strategy':
        final near = projects
            .where(
              (p) =>
                  (p.computedProgress ?? 0) >= 70 ||
                  p.status == ProjectStatus.testing,
            )
            .map((p) => '출시 근접 후보: ${p.name}')
            .toList();
        final stale = projects
            .where((p) => p.isStale)
            .map((p) => '장기 정체(30일+): ${p.name}')
            .toList();
        final unknown = projects
            .where((p) => p.computedProgress == null)
            .map((p) => '데이터 부족으로 판단 불가: ${p.name}')
            .toList();
        return _Block(
          title: '전략 검토 (근거 있는 항목만)',
          items: [
            ...near,
            ...stale,
            ...unknown,
            if (near.isEmpty && stale.isEmpty && unknown.isEmpty)
              '판단 가능한 등록 데이터가 부족합니다. 임의 시장 전망은 생성하지 않습니다.',
          ],
        );
      case 'tax':
        return const _Block(
          title: '세무·회계 (관리 참고 정보)',
          items: [
            '등록 매출: 0원 (미등록)',
            '등록 비용: 0원 (미등록)',
            '미수금: 미등록',
            '세금 일정: 미등록',
            '확정 신고 결과가 아닙니다. 관리 참고 정보입니다.',
          ],
        );
      case 'productdev':
        return _Block(
          title: '상품·프로젝트 개발 후보',
          items: projects.isEmpty
              ? ['등록된 프로젝트 없음']
              : projects
                    .take(10)
                    .map(
                      (p) =>
                          '${p.name} · ${ProjectStatus.labelKo(p.status)} · '
                          '진행률 ${p.computedProgress == null ? '미설정' : '${p.computedProgress}%'}',
                    )
                    .toList(),
        );
      case 'ceo':
      default:
        return _Block(
          title: '사업부별 핵심 상태',
          items: units.isEmpty
              ? ['사업부 미등록']
              : units
                    .map(
                      (u) =>
                          '${u.name}: ${u.status} · 초점 ${u.currentFocus.isEmpty ? '미등록' : u.currentFocus}',
                    )
                    .toList(),
        );
    }
  }
}

class _IdeaPanel extends StatefulWidget {
  const _IdeaPanel({required this.repo});

  final OpsRepository repo;

  @override
  State<_IdeaPanel> createState() => _IdeaPanelState();
}

class _IdeaPanelState extends State<_IdeaPanel> {
  Future<void> _add() async {
    final title = TextEditingController();
    final summary = TextEditingController();
    var status = IdeaStatus.idea;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('아이디어 등록'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              TextField(
                controller: summary,
                decoration: const InputDecoration(labelText: '요약'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: [
                  IdeaStatus.idea,
                  IdeaStatus.reviewing,
                  IdeaStatus.selected,
                  IdeaStatus.onHold,
                  IdeaStatus.rejected,
                  IdeaStatus.inDevelopment,
                ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(IdeaStatus.labelKo(e)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => status = v ?? IdeaStatus.idea),
                decoration: const InputDecoration(labelText: '상태'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await widget.repo.upsertIdea(
      IdeaDoc(
        id: '',
        title: title.text.trim(),
        summary: summary.text.trim(),
        status: status,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아이디어를 등록했습니다.')));
    }
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
                    '아이디어 관리',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _add,
                  child: const Text('아이디어 등록'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '아이디어를 진행 중인 프로젝트처럼 표시하지 않습니다.',
              style: TextStyle(fontSize: 12, color: ControlColors.textMuted),
            ),
            StreamBuilder<List<IdeaDoc>>(
              stream: widget.repo.watchIdeas(),
              builder: (context, snap) {
                final ideas = snap.data ?? const [];
                if (ideas.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('등록된 아이디어가 없습니다.'),
                  );
                }
                return Column(
                  children: ideas
                      .map(
                        (i) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(i.title),
                          subtitle: Text(
                            '${IdeaStatus.labelKo(i.status)}'
                            '${i.summary.isEmpty ? '' : ' · ${i.summary}'}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
