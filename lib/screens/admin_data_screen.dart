import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../services/firebase_ready.dart';
import '../services/ops_repository.dart';
import '../services/ops_seed_service.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';

class AdminDataScreen extends StatefulWidget {
  const AdminDataScreen({super.key});

  @override
  State<AdminDataScreen> createState() => _AdminDataScreenState();
}

class _AdminDataScreenState extends State<AdminDataScreen> {
  OpsRepository? _repo;
  bool _busy = false;

  OpsRepository get repo => _repo ??= OpsRepository();

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final msg = await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: ControlColors.accentWarm,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seed() async {
    await _run(() => OpsSeedService(repo).ensureStructure());
  }

  Future<void> _addWorkLogDialog() async {
    final title = TextEditingController();
    final request = TextEditingController();
    final result = TextEditingController();
    final projectId = TextEditingController();
    final unitId = TextEditingController(text: 'sotong24work');
    final next = TextEditingController();
    final files = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cursor 작업 로그 등록'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                TextField(
                  controller: unitId,
                  decoration: const InputDecoration(labelText: '사업부 ID'),
                ),
                TextField(
                  controller: projectId,
                  decoration: const InputDecoration(labelText: '프로젝트 ID'),
                ),
                TextField(
                  controller: request,
                  decoration: const InputDecoration(labelText: '요청 요약'),
                  maxLines: 2,
                ),
                TextField(
                  controller: result,
                  decoration: const InputDecoration(labelText: '결과 요약'),
                  maxLines: 2,
                ),
                TextField(
                  controller: files,
                  decoration: const InputDecoration(
                    labelText: '수정 파일 (쉼표 구분)',
                  ),
                ),
                TextField(
                  controller: next,
                  decoration: const InputDecoration(labelText: '다음 작업'),
                ),
              ],
            ),
          ),
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
    );

    if (ok != true) return;
    if (!mounted) return;
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력하십시오.')),
      );
      return;
    }

    await _run(() async {
      await repo.addWorkLog(
        WorkLogDoc(
          id: '',
          title: title.text.trim(),
          businessUnitId: unitId.text.trim(),
          projectId: projectId.text.trim(),
          requestSummary: request.text.trim(),
          resultSummary: result.text.trim(),
          changedFiles: files.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          nextAction: next.text.trim(),
          source: WorkLogSource.manual,
          workedAt: DateTime.now(),
        ),
      );
      return '작업 로그를 저장했습니다.';
    });
  }

  Future<void> _importJsonDialog() async {
    final controller = TextEditingController(
      text: '[\n  {\n    "title": "",\n    "projectId": "",\n'
          '    "businessUnitId": "",\n    "requestSummary": "",\n'
          '    "resultSummary": "",\n    "changedFiles": [],\n'
          '    "testResult": "",\n    "buildResult": "",\n'
          '    "commitHash": "",\n    "nextAction": "",\n'
          '    "source": "json_import"\n  }\n]',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('JSON 작업 로그 가져오기'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 16,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '배열 JSON',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _run(() async {
      final decoded = jsonDecode(controller.text);
      if (decoded is! List) {
        throw Exception('최상위는 배열이어야 합니다.');
      }
      var count = 0;
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final m = raw.map((k, v) => MapEntry('$k', v));
        await repo.addWorkLog(
          WorkLogDoc(
            id: '',
            title: '${m['title'] ?? ''}'.trim(),
            projectId: '${m['projectId'] ?? ''}',
            businessUnitId: '${m['businessUnitId'] ?? ''}',
            requestSummary: '${m['requestSummary'] ?? ''}',
            resultSummary: '${m['resultSummary'] ?? ''}',
            changedFiles: ((m['changedFiles'] as List?) ?? const [])
                .map((e) => '$e')
                .toList(),
            testResult: '${m['testResult'] ?? ''}',
            buildResult: '${m['buildResult'] ?? ''}',
            commitHash: '${m['commitHash'] ?? ''}',
            nextAction: '${m['nextAction'] ?? ''}',
            source: '${m['source'] ?? WorkLogSource.jsonImport}',
            workedAt: DateTime.tryParse('${m['workDate'] ?? ''}') ??
                DateTime.now(),
          ),
        );
        count++;
      }
      return 'JSON 작업 로그 $count건을 가져왔습니다.';
    });
  }

  Future<void> _addIssueDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final projectId = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문제 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: projectId,
              decoration: const InputDecoration(labelText: '프로젝트 ID'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: '설명'),
              maxLines: 3,
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
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _run(() async {
      await repo.upsertIssue(
        IssueDoc(
          id: '',
          title: title.text.trim(),
          projectId: projectId.text.trim(),
          description: desc.text.trim(),
          severity: 'medium',
          status: 'open',
          detectedAt: DateTime.now(),
        ),
      );
      return '문제를 등록했습니다.';
    });
  }

  Future<void> _addProjectDialog() async {
    final name = TextEditingController();
    final unitId = TextEditingController(text: 'app_development');
    final stage = TextEditingController();
    final next = TextEditingController();
    final repoUrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('프로젝트 등록'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '프로젝트명'),
                ),
                TextField(
                  controller: unitId,
                  decoration: const InputDecoration(labelText: '사업부 ID'),
                ),
                TextField(
                  controller: stage,
                  decoration: const InputDecoration(labelText: '현재 단계'),
                ),
                TextField(
                  controller: next,
                  decoration: const InputDecoration(labelText: '다음 작업'),
                ),
                TextField(
                  controller: repoUrl,
                  decoration: const InputDecoration(labelText: 'GitHub URL'),
                ),
              ],
            ),
          ),
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
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final id = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    await _run(() async {
      await repo.upsertProject(
        ProjectDoc(
          id: id,
          businessUnitId: unitId.text.trim(),
          name: name.text.trim(),
          status: ProjectStatus.notStarted,
          currentStage:
              stage.text.trim().isEmpty ? '확인 필요' : stage.text.trim(),
          nextAction: next.text.trim(),
          repositoryUrl: repoUrl.text.trim(),
        ),
      );
      return '프로젝트를 등록했습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '데이터 관리',
          message: 'Firebase 연결 후 관리 기능을 사용할 수 있습니다.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: '데이터 관리',
            subtitle:
                '관리자 전용. 모든 저장은 Firestore에 반영됩니다. '
                '가상 데모 수치는 자동 생성하지 않습니다.',
            badge: '관리자',
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: _busy ? null : _seed,
                child: const Text('기본 구조 데이터 생성'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _addProjectDialog,
                child: const Text('프로젝트 등록'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _addWorkLogDialog,
                child: const Text('Cursor 작업 로그 등록'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _importJsonDialog,
                child: const Text('JSON 가져오기'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _addIssueDialog,
                child: const Text('문제 등록'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<ProjectDoc>>(
            stream: repo.watchProjects(),
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyStatePanel(
                  title: '데이터 로딩 오류',
                  message: '${snap.error}',
                );
              }
              final projects = snap.data ?? const [];
              if (projects.isEmpty) {
                return const EmptyStatePanel(
                  title: '등록된 프로젝트가 없습니다',
                  message: '기본 구조를 생성하거나 프로젝트를 등록하십시오.',
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '프로젝트 (${projects.length}건)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...projects.map(
                        (p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name),
                          subtitle: Text(
                            '${p.businessUnitId} · ${ProjectStatus.labelKo(p.status)}',
                          ),
                          trailing: IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await repo.deleteDoc('projects', p.id);
                                    return '프로젝트 ${p.name}을(를) 삭제했습니다.';
                                  }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<WorkLogDoc>>(
            stream: repo.watchWorkLogs(limit: 20),
            builder: (context, snap) {
              final logs = snap.data ?? const [];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '최근 작업 로그',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (logs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('등록된 기록 없음'),
                        )
                      else
                        ...logs.map(
                          (l) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l.title),
                            subtitle: Text(WorkLogSource.labelKo(l.source)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await repo.deleteDoc(
                                        'work_logs',
                                        l.id,
                                      );
                                      return '작업 로그를 삭제했습니다.';
                                    }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
