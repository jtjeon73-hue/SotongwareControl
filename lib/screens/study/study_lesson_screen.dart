import 'package:flutter/material.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_generation_enums.dart';
import '../../models/study/study_generation_models.dart';
import '../../models/study/study_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_ai_providers.dart';
import '../../services/study/study_dashboard_service.dart';
import '../../services/study/study_generation_logic.dart';
import '../../services/study/study_generation_service.dart';
import '../../services/study/study_repository.dart';
import '../../theme/control_theme.dart';

class StudyLessonScreen extends StatefulWidget {
  const StudyLessonScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
    this.learningRunId,
  });

  final String courseId;
  final String lessonId;
  final String? learningRunId;

  @override
  State<StudyLessonScreen> createState() => _StudyLessonScreenState();
}

class _StudyLessonScreenState extends State<StudyLessonScreen> {
  final _svc = StudyGenerationService();
  final _repo = StudyRepository();
  final _tutor = DisconnectedStudyAiLessonTutor();
  final _question = TextEditingController();
  var _mode = StudyAiLessonMode.basic;
  var _contentConfirmed = false;
  var _practiceDone = false;
  var _quizDone = false;
  String? _runId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _runId = widget.learningRunId;
    _ensureRun();
  }

  Future<void> _ensureRun() async {
    if (_runId != null && _runId!.isNotEmpty) return;
    final lessons = await _svc.fetchLessons(widget.courseId);
    final published = lessons.where((l) => l.countsTowardProgress).length;
    final id = await _svc.ensureFirstLearningRun(
      courseId: widget.courseId,
      totalLessonCount: published > 0 ? published : lessons.length,
    );
    if (mounted) setState(() => _runId = id);
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _askAi(StudyLesson lesson, StudyCourse? course) async {
    final msg = _question.text.trim();
    if (msg.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _svc.saveAiMessage(
        StudyAiMessage(
          id: '',
          courseId: widget.courseId,
          lessonId: lesson.id,
          chapterId: lesson.chapterId,
          learningRunId: _runId ?? '',
          role: 'user',
          content: msg,
          mode: _mode,
          source: 'user',
        ),
      );
      final reply = await _tutor.respond(
        mode: _mode,
        userMessage: msg,
        lessonContext: {
          'courseTitle': course?.title ?? '',
          'lessonTitle': lesson.title,
          'lessonNumber': '${lesson.lessonNumber}',
          'intro': lesson.intro,
          'coreConcept': lesson.coreConcept,
          'runId': _runId ?? '',
        },
      );
      await _svc.saveAiMessage(
        StudyAiMessage(
          id: '',
          courseId: widget.courseId,
          lessonId: lesson.id,
          chapterId: lesson.chapterId,
          learningRunId: _runId ?? '',
          role: 'assistant',
          content: reply,
          mode: _mode,
          source: 'ai',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: ControlColors.accentWarm,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _question.clear();
      }
    }
  }

  Future<void> _complete(StudyLesson lesson) async {
    final ok = StudyLessonCompletionChecker.canComplete(
      lesson: lesson,
      contentConfirmed: _contentConfirmed,
      practiceDone: _practiceDone,
      quizDone: _quizDone,
      adminApproved: false,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '완료 조건 미충족: ${StudyCompletionPolicy.labelKo(lesson.completionPolicy)}',
          ),
        ),
      );
      return;
    }
    if (_runId == null) await _ensureRun();
    await _svc.markLessonComplete(learningRunId: _runId!, lesson: lesson);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('강의를 완료 처리했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Scaffold(body: Center(child: Text('Firebase 미연결')));
    }

    return StreamBuilder<StudyLesson?>(
      stream: _svc.watchLesson(widget.lessonId),
      builder: (context, lesSnap) {
        final lesson = lesSnap.data;
        if (lesson == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return StreamBuilder<StudyCourse?>(
          stream: _repo.watchCourse(widget.courseId),
          builder: (context, courseSnap) {
            final course = courseSnap.data;
            return StreamBuilder<List<StudyLesson>>(
              stream: _svc.watchLessons(widget.courseId),
              builder: (context, allSnap) {
                final all = allSnap.data ?? const [];
                final idx = all.indexWhere((l) => l.id == lesson.id);
                final prev = idx > 0 ? all[idx - 1] : null;
                final next = idx >= 0 && idx < all.length - 1
                    ? all[idx + 1]
                    : null;

                return StreamBuilder<List<StudyLearningRun>>(
                  stream: _svc.watchLearningRuns(widget.courseId),
                  builder: (context, runSnap) {
                    final runs = runSnap.data ?? const [];
                    final active = runs.cast<StudyLearningRun?>().firstWhere(
                      (r) => r?.id == _runId,
                      orElse: () => runs.isEmpty ? null : runs.first,
                    );
                    final progressPct =
                        StudyProgressCalculator.lessonProgressPercent(
                          lessons: all,
                          progress: const [],
                        );

                    return Scaffold(
                      appBar: AppBar(
                        title: Text(
                          '${lesson.lessonNumber}강',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      body: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            course?.title ?? '강의방',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            lesson.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  '${lesson.lessonNumber} / ${all.isEmpty ? '—' : all.length}',
                                ),
                              ),
                              if (active != null)
                                Chip(label: Text('${active.runNumber}회차')),
                              Chip(
                                label: Text(
                                  StudyDifficulty.labelKo(lesson.difficulty),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  StudyLessonType.labelKo(lesson.lessonType),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  '진도 ${active?.progress ?? progressPct ?? '—'}%',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _section(
                            context,
                            '학습 목표',
                            lesson.learningObjectives.isEmpty
                                ? (lesson.description.isEmpty
                                      ? '등록된 학습 목표가 없습니다.'
                                      : lesson.description)
                                : lesson.learningObjectives.join('\n· '),
                          ),
                          _section(
                            context,
                            '도입',
                            lesson.intro.isEmpty
                                ? '본문이 아직 없습니다.'
                                : lesson.intro,
                          ),
                          _section(context, '핵심 개념', lesson.coreConcept),
                          _section(context, '쉬운 설명', lesson.simpleExplanation),
                          _section(
                            context,
                            '실무적 설명',
                            lesson.practicalExplanation,
                          ),
                          _section(context, '주의사항', lesson.warnings),
                          _section(context, '자주 하는 실수', lesson.commonMistakes),
                          _section(context, '핵심 요약', lesson.summary),
                          if (lesson.contentBlocks.isNotEmpty) ...[
                            Text(
                              '추가 블록',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            ...lesson.contentBlocks.map(
                              (b) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SelectableText(
                                  '${b['title'] ?? ''}\n${b['body'] ?? b['content'] ?? ''}',
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '학습 기록 · 완료',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '완료 정책: ${StudyCompletionPolicy.labelKo(lesson.completionPolicy)}',
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('본문 학습 확인'),
                                    value: _contentConfirmed,
                                    onChanged: (v) => setState(
                                      () => _contentConfirmed = v ?? false,
                                    ),
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('실습 완료'),
                                    value: _practiceDone,
                                    onChanged: (v) => setState(
                                      () => _practiceDone = v ?? false,
                                    ),
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('퀴즈 응시'),
                                    value: _quizDone,
                                    onChanged: (v) =>
                                        setState(() => _quizDone = v ?? false),
                                  ),
                                  FilledButton(
                                    onPressed: () => _complete(lesson),
                                    child: const Text('강의 완료'),
                                  ),
                                  TextButton(
                                    onPressed: _runId == null
                                        ? null
                                        : () async {
                                            await _svc.recordReviewAttempt(
                                              learningRunId: _runId!,
                                              lessonId: lesson.id,
                                              addedMinutes: 5,
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '복습 기록을 추가했습니다. (완료 상태 유지)',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text('현재 회차에서 다시 보기'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            color: ControlColors.accentWarm.withValues(
                              alpha: 0.08,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI선생',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    _tutor.isConnected
                                        ? '연결됨'
                                        : 'AI선생 자동 대화 기능은 아직 연결되지 않았습니다.',
                                  ),
                                  DropdownButtonFormField<String>(
                                    initialValue: _mode,
                                    decoration: const InputDecoration(
                                      labelText: '수업 모드',
                                    ),
                                    items:
                                        [
                                              StudyAiLessonMode.basic,
                                              StudyAiLessonMode.simple,
                                              StudyAiLessonMode.detailed,
                                              StudyAiLessonMode.practical,
                                              StudyAiLessonMode.review,
                                              StudyAiLessonMode.quiz,
                                              StudyAiLessonMode.exam,
                                              StudyAiLessonMode.project,
                                            ]
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(
                                                  StudyAiLessonMode.labelKo(e),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) =>
                                        setState(() => _mode = v ?? _mode),
                                  ),
                                  TextField(
                                    controller: _question,
                                    decoration: const InputDecoration(
                                      labelText: '질문',
                                      hintText: '더 쉽게 설명해줘',
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.tonal(
                                    onPressed: _busy
                                        ? null
                                        : () => _askAi(lesson, course),
                                    child: const Text('질문하기'),
                                  ),
                                  StreamBuilder<List<StudyAiMessage>>(
                                    stream: _svc.watchAiMessages(
                                      courseId: widget.courseId,
                                      lessonId: lesson.id,
                                    ),
                                    builder: (context, msgSnap) {
                                      final msgs = msgSnap.data ?? const [];
                                      if (msgs.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Column(
                                        children: msgs
                                            .map(
                                              (m) => ListTile(
                                                dense: true,
                                                title: Text(
                                                  m.role == 'user'
                                                      ? '나'
                                                      : 'AI선생',
                                                ),
                                                subtitle: SelectableText(
                                                  m.content,
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
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: prev == null
                                    ? null
                                    : () {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute<void>(
                                            builder: (_) => StudyLessonScreen(
                                              courseId: widget.courseId,
                                              lessonId: prev.id,
                                              learningRunId: _runId,
                                            ),
                                          ),
                                        );
                                      },
                                child: const Text('이전 강의'),
                              ),
                              OutlinedButton(
                                onPressed: next == null
                                    ? null
                                    : () {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute<void>(
                                            builder: (_) => StudyLessonScreen(
                                              courseId: widget.courseId,
                                              lessonId: next.id,
                                              learningRunId: _runId,
                                            ),
                                          ),
                                        );
                                      },
                                child: const Text('다음 강의'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('강의방으로'),
                              ),
                            ],
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
  }

  Widget _section(BuildContext context, String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          SelectableText(body),
        ],
      ),
    );
  }
}
