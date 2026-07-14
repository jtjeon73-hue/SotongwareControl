import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_generation_enums.dart';
import '../../models/study/study_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_generation_service.dart';
import '../../services/study/study_repository.dart';
import '../../theme/control_theme.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';
import '../../widgets/study/study_widgets.dart';
import 'study_ai_course_creator_screen.dart';
import 'study_course_detail_screen.dart';
import 'study_generation_job_screen.dart';

class StudyAdminScreen extends StatefulWidget {
  const StudyAdminScreen({super.key});

  @override
  State<StudyAdminScreen> createState() => _StudyAdminScreenState();
}

class _StudyAdminScreenState extends State<StudyAdminScreen> {
  StudyRepository? _repo;
  StudyRepository get repo => _repo ??= StudyRepository();
  bool _busy = false;

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

  Future<void> _createCourse() async {
    final title = TextEditingController();
    final category = TextEditingController();
    final desc = TextEditingController();
    final goal = TextEditingController();
    var difficulty = StudyDifficulty.beginner;
    var status = StudyCourseStatus.draft;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('강의방 생성'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: '강의명'),
                  ),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(labelText: '분야 (자유 입력)'),
                  ),
                  TextField(
                    controller: desc,
                    decoration: const InputDecoration(labelText: '설명'),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: goal,
                    decoration: const InputDecoration(labelText: '학습 목적'),
                    maxLines: 2,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: difficulty,
                    decoration: const InputDecoration(labelText: '난이도'),
                    items:
                        [
                              StudyDifficulty.beginner,
                              StudyDifficulty.intermediate,
                              StudyDifficulty.advanced,
                            ]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(StudyDifficulty.labelKo(e)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) =>
                        setLocal(() => difficulty = v ?? difficulty),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: '상태'),
                    items:
                        [
                              StudyCourseStatus.draft,
                              StudyCourseStatus.ready,
                              StudyCourseStatus.inProgress,
                            ]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(StudyCourseStatus.labelKo(e)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setLocal(() => status = v ?? status),
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
              child: const Text('생성'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;

    await _run(() async {
      final id = await repo.upsertCourse(
        StudyCourse(
          id: '',
          title: title.text.trim(),
          category: category.text.trim(),
          description: desc.text.trim(),
          learningGoal: goal.text.trim(),
          difficulty: difficulty,
          status: status,
          chapterCount: 0,
          completedChapterCount: 0,
          nextAction: '첫 챕터를 등록하십시오.',
        ),
        isNew: true,
      );
      return '강의방을 생성했습니다. (ID: $id) · 챕터 0 · 진행률 미설정';
    });
  }

  Future<void> _export() async {
    await _run(() async {
      final data = await repo.exportStudySnapshot();
      final text = const JsonEncoder.withIndent('  ').convert({
        'exportedAt': DateTime.now().toIso8601String(),
        'note': '인증 정보·API Key는 포함하지 않습니다.',
        'data': data,
      });
      await Clipboard.setData(ClipboardData(text: text));
      return '스터디 백업 JSON을 클립보드에 복사했습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '스터디 관리',
          message: 'Firebase 연결 후 관리할 수 있습니다.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: '스터디 관리',
            subtitle:
                '강의방·챕터·개별 강의·AI 생성 요청을 관리합니다. '
                '관심 분야를 코드에 고정하지 않습니다. '
                'AI 미연결 시 가짜 본문을 자동 생성하지 않습니다.',
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
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const StudyAiCourseCreatorScreen(),
                          ),
                        );
                      },
                child: const Text('AI 강의 만들기'),
              ),
              FilledButton(
                onPressed: _busy ? null : _createCourse,
                child: const Text('강의방 생성'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _export,
                child: const Text('스터디 JSON 내보내기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder(
            stream: StudyGenerationService().watchJobs(),
            builder: (context, jobSnap) {
              final jobs = jobSnap.data ?? const [];
              if (jobs.isEmpty) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '최근 생성 작업',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      ...jobs
                          .take(5)
                          .map(
                            (j) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                j.interestField.isEmpty
                                    ? j.id
                                    : j.interestField,
                              ),
                              subtitle: Text(
                                '${StudyJobStatus.labelKo(j.status)} · '
                                '${j.requestedLessonCount}강',
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StudyGenerationJobScreen(
                                      jobId: j.id,
                                      courseId: j.courseId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<StudyCourse>>(
            stream: repo.watchCourses(),
            builder: (context, snap) {
              final courses = snap.data ?? const [];
              if (courses.isEmpty) {
                return EmptyStatePanel(
                  title: '아직 등록된 강의방이 없습니다',
                  message: '스터디 관리에서 첫 강의방을 생성하십시오.',
                  actionLabel: '강의방 생성',
                  onAction: _busy ? null : _createCourse,
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '강의방 ${courses.length}건',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...courses.map(
                        (c) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(c.title),
                          subtitle: Text(
                            '${StudyCourseStatus.labelKo(c.status)} · '
                            '${c.category.isEmpty ? '분야 미등록' : c.category} · '
                            '챕터 ${c.chapterCount} · '
                            '진도 ${c.progress == null ? '미설정' : '${c.progress}%'}',
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    StudyCourseDetailScreen(courseId: c.id),
                              ),
                            );
                          },
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: '복제',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                        await repo.duplicateCourse(c);
                                        return '강의방을 복제했습니다.';
                                      }),
                              ),
                              IconButton(
                                tooltip: '보관',
                                icon: const Icon(Icons.archive_outlined),
                                onPressed: _busy
                                    ? null
                                    : () => showStudyConfirm(
                                        context,
                                        title: '강의방 보관',
                                        message:
                                            '${c.title}을(를) 보관할까요? 관련 챕터는 유지됩니다.',
                                        onConfirm: () => _run(() async {
                                          await repo.archiveCourse(c.id);
                                          return '보관 처리했습니다.';
                                        }),
                                      ),
                              ),
                              IconButton(
                                tooltip: '영구 삭제',
                                icon: const Icon(Icons.delete_forever_outlined),
                                onPressed: _busy
                                    ? null
                                    : () => showStudyConfirm(
                                        context,
                                        title: '영구 삭제',
                                        message:
                                            '강의방만 삭제합니다. 챕터·기록은 자동 연쇄 삭제되지 않습니다.',
                                        onConfirm: () => _run(() async {
                                          await repo.deleteCourseHard(c.id);
                                          return '강의방을 삭제했습니다.';
                                        }),
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
        ],
      ),
    );
  }
}
