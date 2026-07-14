import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/known_projects_catalog.dart';
import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../screens/project_detail_screen.dart';
import '../services/firebase_ready.dart';
import '../services/known_projects_seed_service.dart';
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
  String _filterProject = '';
  String _filterUnit = '';
  final _selectedKnown = <String>{};

  OpsRepository get repo => _repo ??= OpsRepository();

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final msg = await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _confirmDelete(
    String label,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('$label 을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() async {
        await action();
        return '삭제했습니다.';
      });
    }
  }

  Future<void> _showKnownPreview() async {
    final specs = KnownProjectsCatalog.all;
    _selectedKnown
      ..clear()
      ..addAll(specs.map((e) => e.id));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('실제 프로젝트 기본 목록 미리보기'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: ListView(
                children: [
                  const Text(
                    '확인된 주소·존재 항목만 포함합니다. '
                    '미확인 필드는 상태=확인 필요, 진행률=미설정으로 저장됩니다.',
                  ),
                  const SizedBox(height: 8),
                  ...specs.map(
                    (s) => CheckboxListTile(
                      dense: true,
                      value: _selectedKnown.contains(s.id),
                      title: Text(s.name),
                      subtitle: Text(
                        '${s.group} · ${s.businessUnitId}'
                        '${s.promoUrl.isEmpty && s.repositoryUrl.isEmpty && s.firebaseUrl.isEmpty ? ' · 주소 미등록' : ''}',
                      ),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            _selectedKnown.add(s.id);
                          } else {
                            _selectedKnown.remove(s.id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('선택 ${_selectedKnown.length}건 생성'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || _selectedKnown.isEmpty) return;
    await _run(() async {
      final r = await KnownProjectsSeedService(
        repo,
      ).createSelected(_selectedKnown.toList());
      return r.message;
    });
  }

  Future<void> _workLogDialog({WorkLogDoc? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final request = TextEditingController(text: existing?.requestSummary ?? '');
    final result = TextEditingController(text: existing?.resultSummary ?? '');
    final projectId = TextEditingController(text: existing?.projectId ?? '');
    final unitId = TextEditingController(
      text: existing?.businessUnitId ?? 'sotong24work',
    );
    final next = TextEditingController(text: existing?.nextAction ?? '');
    final files = TextEditingController(
      text: existing?.changedFiles.join(', ') ?? '',
    );
    final analyze = TextEditingController(text: existing?.analyzeResult ?? '');
    final test = TextEditingController(text: existing?.testResult ?? '');
    final build = TextEditingController(text: existing?.buildResult ?? '');
    final commitMsg = TextEditingController(
      text: existing?.commitMessage ?? '',
    );
    final commitHash = TextEditingController(text: existing?.commitHash ?? '');
    final issues = TextEditingController(text: existing?.issuesNote ?? '');
    var gitPushed = existing?.gitPushed ?? false;
    var firebaseDeployed = existing?.firebaseDeployed ?? false;
    var siteVerified = existing?.siteVerified ?? false;
    var workDate = existing?.workedAt ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'Cursor 작업 로그 등록' : '작업 로그 수정'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '작업일: ${DateFormat('yyyy-MM-dd').format(workDate)}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: workDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                          );
                          if (d != null) setLocal(() => workDate = d);
                        },
                        child: const Text('변경'),
                      ),
                    ),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: '작업 제목'),
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
                      decoration: const InputDecoration(labelText: 'Cursor 요청'),
                      maxLines: 2,
                    ),
                    TextField(
                      controller: result,
                      decoration: const InputDecoration(labelText: '작업 결과'),
                      maxLines: 2,
                    ),
                    TextField(
                      controller: files,
                      decoration: const InputDecoration(
                        labelText: '변경 파일 (쉼표)',
                      ),
                    ),
                    TextField(
                      controller: analyze,
                      decoration: const InputDecoration(
                        labelText: 'Flutter 검사',
                      ),
                    ),
                    TextField(
                      controller: test,
                      decoration: const InputDecoration(labelText: '테스트'),
                    ),
                    TextField(
                      controller: build,
                      decoration: const InputDecoration(labelText: '빌드'),
                    ),
                    TextField(
                      controller: commitMsg,
                      decoration: const InputDecoration(labelText: '커밋 메시지'),
                    ),
                    TextField(
                      controller: commitHash,
                      decoration: const InputDecoration(labelText: '커밋 해시'),
                    ),
                    CheckboxListTile(
                      value: gitPushed,
                      onChanged: (v) => setLocal(() => gitPushed = v ?? false),
                      title: const Text('GitHub 푸시'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: firebaseDeployed,
                      onChanged: (v) =>
                          setLocal(() => firebaseDeployed = v ?? false),
                      title: const Text('Firebase 배포'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: siteVerified,
                      onChanged: (v) =>
                          setLocal(() => siteVerified = v ?? false),
                      title: const Text('실제 사이트 확인'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    TextField(
                      controller: next,
                      decoration: const InputDecoration(labelText: '다음 작업'),
                    ),
                    TextField(
                      controller: issues,
                      decoration: const InputDecoration(labelText: '문제 사항'),
                      maxLines: 2,
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
          );
        },
      ),
    );

    if (ok != true || !mounted) return;
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목을 입력하십시오.')));
      return;
    }

    final hash = commitHash.text.trim();
    if (hash.isNotEmpty) {
      final dup = await repo.hasCommitHash(hash, excludeId: existing?.id);
      if (dup && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('중복 커밋 경고'),
            content: Text('커밋 해시 $hash 가 이미 등록되어 있습니다. 계속할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('계속 저장'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    await _run(() async {
      await repo.upsertWorkLog(
        WorkLogDoc(
          id: existing?.id ?? '',
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
          analyzeResult: analyze.text.trim(),
          testResult: test.text.trim(),
          buildResult: build.text.trim(),
          commitMessage: commitMsg.text.trim(),
          commitHash: hash,
          gitPushed: gitPushed,
          firebaseDeployed: firebaseDeployed,
          siteVerified: siteVerified,
          issuesNote: issues.text.trim(),
          nextAction: next.text.trim(),
          source: existing?.source ?? WorkLogSource.manual,
          workedAt: workDate,
        ),
      );
      return existing == null ? '작업 로그를 저장했습니다.' : '작업 로그를 수정했습니다.';
    });
  }

  Future<void> _importJsonWithPreview({required bool sotong24Mode}) async {
    final controller = TextEditingController(
      text: sotong24Mode
          ? '{\n  "projectId": "",\n  "moduleId": "",\n  "workTitle": "",\n'
                '  "requestSummary": "",\n  "resultSummary": "",\n'
                '  "changedFiles": [],\n  "commitHash": "",\n'
                '  "nextAction": "",\n  "workedAt": ""\n}'
          : '[\n  {\n    "title": "",\n    "projectId": "",\n'
                '    "businessUnitId": "",\n    "commitHash": ""\n  }\n]',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sotong24Mode ? '소통24워크 JSON 가져오기(승인형)' : '작업 로그 JSON 가져오기'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sotong24Mode)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '소통24워크 직접 자동 전송: 준비 중\n현재 사용 가능 방식: JSON 가져오기',
                    style: TextStyle(color: ControlColors.accentWarm),
                  ),
                ),
              TextField(
                controller: controller,
                maxLines: 14,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('검증·미리보기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final decoded = jsonDecode(controller.text);
      final items = <Map<String, dynamic>>[];
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) {
            items.add(e.map((k, v) => MapEntry('$k', v)));
          }
        }
      } else if (decoded is Map) {
        items.add(decoded.map((k, v) => MapEntry('$k', v)));
      } else {
        throw Exception('JSON은 객체 또는 배열이어야 합니다.');
      }

      final preview = <String>[];
      final valid = <WorkLogDoc>[];
      for (final m in items) {
        final mapped = Map<String, dynamic>.from(m);
        if (sotong24Mode) {
          mapped['title'] = mapped['title'] ?? mapped['workTitle'] ?? '';
          mapped['projectId'] = mapped['projectId'] ?? mapped['moduleId'] ?? '';
          mapped['businessUnitId'] = mapped['businessUnitId'] ?? 'sotong24work';
          mapped['source'] = WorkLogSource.sotong24;
        }
        final errs = WorkLogUtils.validateImportItem(mapped);
        if (errs.isNotEmpty) {
          preview.add('거부: ${errs.join(', ')}');
          continue;
        }
        final log = WorkLogDoc.fromJsonMap(mapped);
        final dup =
            log.commitHash.isNotEmpty &&
            await repo.hasCommitHash(log.commitHash);
        preview.add('${dup ? '[중복커밋] ' : ''}${log.title} · ${log.projectId}');
        if (!dup || sotong24Mode) {
          valid.add(log);
        }
      }

      if (!mounted) return;
      final approve = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('가져오기 미리보기 · 승인'),
          content: SizedBox(
            width: 480,
            height: 320,
            child: ListView(
              children: [
                Text('유효 ${valid.length}건 / 전체 ${items.length}건'),
                const SizedBox(height: 8),
                ...preview.map((e) => Text('• $e')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: valid.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('승인 후 저장'),
            ),
          ],
        ),
      );
      if (approve != true) return;

      await _run(() async {
        for (final l in valid) {
          await repo.upsertWorkLog(l);
        }
        return 'JSON ${valid.length}건을 저장했습니다.';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('검증 실패: $e')));
      }
    }
  }

  Future<void> _exportBackup() async {
    await _run(() async {
      final data = await repo.exportSnapshot();
      final text = const JsonEncoder.withIndent('  ').convert({
        'exportedAt': DateTime.now().toIso8601String(),
        'note': '인증 정보·토큰·비밀번호는 포함하지 않습니다.',
        'data': data.map(
          (k, v) => MapEntry(
            k,
            v.map((row) {
              final copy = Map<String, dynamic>.from(row);
              copy.removeWhere(
                (key, _) =>
                    key.toLowerCase().contains('password') ||
                    key.toLowerCase().contains('token') ||
                    key.toLowerCase().contains('secret'),
              );
              return copy;
            }).toList(),
          ),
        ),
      });
      await Clipboard.setData(ClipboardData(text: text));
      return '백업 JSON을 클립보드에 복사했습니다. (${text.length}자)';
    });
  }

  Future<void> _exportWorkLogs(List<WorkLogDoc> logs) async {
    final filtered = WorkLogUtils.filterLogs(
      logs: logs,
      projectId: _filterProject,
      businessUnitId: _filterUnit,
    );
    final text = const JsonEncoder.withIndent(
      '  ',
    ).convert(filtered.map((e) => e.toJsonExport()).toList());
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('작업 로그 ${filtered.length}건을 클립보드에 복사했습니다.')),
      );
    }
  }

  Future<void> _addDeploymentDialog() async {
    final projectId = TextEditingController(text: 'control_center');
    final siteUrl = TextEditingController(
      text: 'https://sotongware-control.web.app',
    );
    final commit = TextEditingController();
    final msg = TextEditingController();
    final note = TextEditingController();
    var analyze = DeployStepStatus.notChecked;
    var test = DeployStepStatus.notChecked;
    var build = DeployStepStatus.notChecked;
    var commitS = DeployStepStatus.notChecked;
    var push = DeployStepStatus.notChecked;
    var firebase = DeployStepStatus.notChecked;
    var site = DeployStepStatus.notChecked;

    String? pick(String cur) => cur;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget step(String label, String value, void Function(String) set) {
            return DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: DeployStepStatus.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(DeployStepStatus.labelKo(e)),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setLocal(() => set(v ?? DeployStepStatus.notChecked)),
            );
          }

          return AlertDialog(
            title: const Text('배포 결과 등록'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: projectId,
                      decoration: const InputDecoration(labelText: '프로젝트 ID'),
                    ),
                    step('Analyze', analyze, (v) => analyze = pick(v)!),
                    step('Test', test, (v) => test = pick(v)!),
                    step('Build', build, (v) => build = pick(v)!),
                    step('Commit', commitS, (v) => commitS = pick(v)!),
                    step('Push', push, (v) => push = pick(v)!),
                    step('Firebase', firebase, (v) => firebase = pick(v)!),
                    step('사이트 확인', site, (v) => site = pick(v)!),
                    TextField(
                      controller: commit,
                      decoration: const InputDecoration(labelText: '커밋 해시'),
                    ),
                    TextField(
                      controller: msg,
                      decoration: const InputDecoration(labelText: '커밋 메시지'),
                    ),
                    TextField(
                      controller: siteUrl,
                      decoration: const InputDecoration(labelText: '사이트 URL'),
                    ),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(labelText: '확인 메모'),
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
          );
        },
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await repo.upsertDeployment(
        DeploymentDoc(
          id: '',
          projectId: projectId.text.trim(),
          flutterAnalyze: analyze,
          flutterTest: test,
          flutterBuildWeb: build,
          gitCommit: commitS,
          gitPush: push,
          firebaseDeploy: firebase,
          siteVerified: site,
          commitHash: commit.text.trim(),
          commitMessage: msg.text.trim(),
          siteUrl: siteUrl.text.trim(),
          verificationNote: note.text.trim(),
          deployedAt: DateTime.now(),
        ),
      );
      return '배포 기록을 저장했습니다.';
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
                '실제 확인된 데이터만 등록합니다. 가상 매출·완료 수치는 생성하지 않습니다. '
                '소통24워크 직접 자동 전송: 준비 중 · 현재 방식: JSON 가져오기',
            badge: '관리자',
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => OpsSeedService(repo).ensureStructure()),
                child: const Text('기본 구조 데이터 생성'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _showKnownPreview,
                child: const Text('실제 프로젝트 기본 목록'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _workLogDialog(),
                child: const Text('작업 로그 등록'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _importJsonWithPreview(sotong24Mode: false),
                child: const Text('JSON 가져오기'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _importJsonWithPreview(sotong24Mode: true),
                child: const Text('소통24 JSON 승인 가져오기'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _addDeploymentDialog,
                child: const Text('배포 결과 등록'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _exportBackup,
                child: const Text('운영 데이터 백업(JSON)'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<ProjectDoc>>(
            stream: repo.watchProjects(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final projects = snap.data ?? const [];
              if (projects.isEmpty) {
                return const EmptyStatePanel(
                  title: '등록된 프로젝트가 없습니다',
                  message: '기본 구조 또는 실제 프로젝트 기본 목록을 생성하십시오.',
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
                      ...projects.map(
                        (p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(child: Text(p.name)),
                              if (p.isStale)
                                const StatusBadge(
                                  label: '상태 확인 필요',
                                  color: ControlColors.accentWarm,
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${p.businessUnitId} · ${ProjectStatus.labelKo(p.status)} · '
                            '진행률 ${p.computedProgress == null ? '미설정' : '${p.computedProgress}%'}',
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ProjectDetailScreen(projectId: p.id),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy
                                ? null
                                : () => _confirmDelete(p.name, () async {
                                    await repo.deleteDoc('projects', p.id);
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
            stream: repo.watchWorkLogs(limit: 100),
            builder: (context, snap) {
              final logs = snap.data ?? const [];
              final filtered = WorkLogUtils.filterLogs(
                logs: logs,
                projectId: _filterProject,
                businessUnitId: _filterUnit,
              );
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
                              '작업 로그 (${filtered.length}건)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _exportWorkLogs(logs),
                            child: const Text('JSON 내보내기'),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _filterProject = '';
                              _filterUnit = '';
                            }),
                            child: const Text('필터 초기화'),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: '프로젝트 ID 필터',
                              ),
                              onChanged: (v) =>
                                  setState(() => _filterProject = v.trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: '사업부 ID 필터',
                              ),
                              onChanged: (v) =>
                                  setState(() => _filterUnit = v.trim()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        const Text('Cursor 작업 기록이 없습니다.')
                      else
                        ...filtered
                            .take(30)
                            .map(
                              (l) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l.title),
                                subtitle: Text(
                                  '${l.workedAt == null ? '일시 미등록' : DateFormat('yyyy-MM-dd').format(l.workedAt!)}'
                                  ' · ${l.projectId} · ${WorkLogSource.labelKo(l.source)}',
                                ),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: _busy
                                          ? null
                                          : () => _workLogDialog(existing: l),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: _busy
                                          ? null
                                          : () => _confirmDelete(
                                              l.title,
                                              () async {
                                                await repo.deleteDoc(
                                                  'work_logs',
                                                  l.id,
                                                );
                                              },
                                            ),
                                    ),
                                  ],
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
          StreamBuilder<List<ActivityLogDoc>>(
            stream: repo.watchActivityLogs(),
            builder: (context, snap) {
              final acts = snap.data ?? const [];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '최근 활동 기록',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (acts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('활동 기록이 없습니다.'),
                        )
                      else
                        ...acts.map(
                          (a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(a.summary),
                            subtitle: Text(
                              '${a.action} · ${a.collection}/${a.documentId} · '
                              '${a.actorEmail.isEmpty ? 'UID ${a.actorUid}' : a.actorEmail}'
                              '${a.createdAt == null ? '' : ' · ${DateFormat('MM-dd HH:mm').format(a.createdAt!)}'}',
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
