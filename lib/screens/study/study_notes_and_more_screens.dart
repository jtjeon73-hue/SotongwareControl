import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_repository.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';

class StudyNotesScreen extends StatefulWidget {
  const StudyNotesScreen({super.key});

  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  final _repo = StudyRepository();
  String _query = '';
  String? _courseId;

  Future<void> _addNote(List<StudyCourse> courses) async {
    if (courses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 강의방을 생성하십시오.')));
      return;
    }
    final title = TextEditingController();
    final content = TextEditingController();
    var courseId = courses.first.id;
    var important = false;
    var review = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('노트 작성'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: courseId,
                  items: courses
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.title)),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => courseId = v ?? courseId),
                  decoration: const InputDecoration(labelText: '강의'),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                TextField(
                  controller: content,
                  decoration: const InputDecoration(labelText: '내용'),
                  maxLines: 4,
                ),
                CheckboxListTile(
                  value: important,
                  onChanged: (v) => setLocal(() => important = v ?? false),
                  title: const Text('중요'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: review,
                  onChanged: (v) => setLocal(() => review = v ?? false),
                  title: const Text('복습 필요'),
                  contentPadding: EdgeInsets.zero,
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
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _repo.upsertNote(
      StudyNote(
        id: '',
        courseId: courseId,
        title: title.text.trim(),
        content: content.text.trim(),
        isImportant: important,
        needsReview: review,
      ),
      isNew: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '학습 노트',
          message: 'Firebase 연결 후 사용할 수 있습니다.',
        ),
      );
    }

    return StreamBuilder<List<StudyCourse>>(
      stream: _repo.watchCourses(),
      builder: (context, courseSnap) {
        final courses = courseSnap.data ?? const [];
        return StreamBuilder<List<StudyNote>>(
          stream: _repo.watchNotes(courseId: _courseId),
          builder: (context, noteSnap) {
            var notes = noteSnap.data ?? const [];
            if (_query.trim().isNotEmpty) {
              final q = _query.toLowerCase();
              notes = notes
                  .where(
                    (n) =>
                        n.title.toLowerCase().contains(q) ||
                        n.content.toLowerCase().contains(q),
                  )
                  .toList();
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHero(
                    title: '학습 노트',
                    subtitle: '강의·챕터별 노트를 관리합니다.',
                    badge: '소통스터디부',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: '검색',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      DropdownButton<String?>(
                        value: _courseId,
                        hint: const Text('강의 필터'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('전체 강의'),
                          ),
                          ...courses.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.title),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _courseId = v),
                      ),
                      FilledButton(
                        onPressed: () => _addNote(courses),
                        child: const Text('노트 작성'),
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          final text = const JsonEncoder.withIndent('  ')
                              .convert(
                                notes.map((e) => e.toJsonExport()).toList(),
                              );
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('노트 ${notes.length}건 복사')),
                            );
                          }
                        },
                        child: const Text('JSON 내보내기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (notes.isEmpty)
                    const EmptyStatePanel(
                      title: '노트가 없습니다',
                      message: '학습 중 중요한 내용을 노트로 남기십시오.',
                    )
                  else
                    ...notes.map(
                      (n) => Card(
                        child: ListTile(
                          title: Text(n.title),
                          subtitle: Text(
                            n.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _repo.deleteNote(n.id),
                          ),
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
  }
}

class StudyAssignmentsScreen extends StatelessWidget {
  const StudyAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '실습·과제',
          message: 'Firebase 연결 후 사용할 수 있습니다.',
        ),
      );
    }
    final repo = StudyRepository();
    return StreamBuilder<List<StudyAssignment>>(
      stream: repo.watchAssignments(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHero(
                title: '실습·과제',
                subtitle: 'AI 자동 점수는 생성하지 않습니다. 관리자/자기평가만 기록합니다.',
                badge: '소통스터디부',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _add(context, repo),
                child: const Text('실습·과제 등록'),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const EmptyStatePanel(
                  title: '등록된 실습·과제가 없습니다',
                  message: '챕터 학습 후 실습을 등록하십시오.',
                )
              else
                ...items.map(
                  (a) => Card(
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text(
                        '${StudyAssignmentStatus.labelKo(a.status)} · ${a.courseId}'
                        '${a.evaluation.isEmpty ? '' : ' · 평가: ${a.evaluation}'}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _add(BuildContext context, StudyRepository repo) async {
    final title = TextEditingController();
    final courseId = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('실습·과제 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courseId,
              decoration: const InputDecoration(labelText: '강의방 ID'),
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '제목'),
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
    await repo.upsertAssignment(
      StudyAssignment(
        id: '',
        courseId: courseId.text.trim(),
        title: title.text.trim(),
      ),
      isNew: true,
    );
  }
}

class StudyQuizzesScreen extends StatelessWidget {
  const StudyQuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '복습·퀴즈',
          message: 'Firebase 연결 후 사용할 수 있습니다.',
        ),
      );
    }
    final repo = StudyRepository();
    return StreamBuilder<List<StudyQuiz>>(
      stream: repo.watchQuizzes(),
      builder: (context, snap) {
        return StreamBuilder<List<StudyQuizAttempt>>(
          stream: repo.watchAttempts(),
          builder: (context, attSnap) {
            final quizzes = snap.data ?? const [];
            final attempts = attSnap.data ?? const [];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHero(
                    title: '복습·퀴즈',
                    subtitle:
                        'AI 미연결: 관리자가 직접 퀴즈를 등록합니다. '
                        '응시하지 않은 문제에 점수를 만들지 않습니다.',
                    badge: '소통스터디부',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _addQuiz(context, repo),
                    child: const Text('퀴즈 등록'),
                  ),
                  const SizedBox(height: 12),
                  if (quizzes.isEmpty)
                    const EmptyStatePanel(
                      title: '등록된 퀴즈가 없습니다',
                      message: '복습용 문제를 직접 등록하십시오.',
                    )
                  else
                    ...quizzes.map((q) {
                      final att = attempts.where((a) => a.quizId == q.id);
                      return Card(
                        child: ListTile(
                          title: Text(q.question),
                          subtitle: Text(
                            '${StudyQuizType.labelKo(q.quizType)} · '
                            '생성: ${q.generationMethod} · '
                            '검토: ${q.reviewed ? '완료' : '관리자 검토 전'} · '
                            '응시 ${att.length}회',
                          ),
                          trailing: TextButton(
                            onPressed: () => _attempt(context, repo, q),
                            child: const Text('응시'),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _addQuiz(
    BuildContext context,
    StudyRepository repo,
  ) async {
    final question = TextEditingController();
    final answer = TextEditingController();
    final courseId = TextEditingController();
    final choices = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('퀴즈 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courseId,
              decoration: const InputDecoration(labelText: '강의방 ID'),
            ),
            TextField(
              controller: question,
              decoration: const InputDecoration(labelText: '문제'),
              maxLines: 2,
            ),
            TextField(
              controller: choices,
              decoration: const InputDecoration(labelText: '선택지(쉼표, 객관식)'),
            ),
            TextField(
              controller: answer,
              decoration: const InputDecoration(labelText: '정답'),
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
    if (ok != true || question.text.trim().isEmpty) return;
    await repo.upsertQuiz(
      StudyQuiz(
        id: '',
        courseId: courseId.text.trim(),
        question: question.text.trim(),
        choices: choices.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        correctAnswer: answer.text.trim(),
        generationMethod: 'manual',
        reviewed: true,
      ),
      isNew: true,
    );
  }

  static Future<void> _attempt(
    BuildContext context,
    StudyRepository repo,
    StudyQuiz quiz,
  ) async {
    final answer = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('퀴즈 응시'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quiz.question),
            if (quiz.choices.isNotEmpty)
              Text('선택지: ${quiz.choices.join(' / ')}'),
            TextField(
              controller: answer,
              decoration: const InputDecoration(labelText: '내 답'),
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
            child: const Text('제출'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final selected = answer.text.trim();
    final correct =
        selected.toLowerCase() == quiz.correctAnswer.trim().toLowerCase();
    await repo.addAttempt(
      StudyQuizAttempt(
        id: '',
        quizId: quiz.id,
        courseId: quiz.courseId,
        chapterId: quiz.chapterId,
        selectedAnswer: selected,
        isCorrect: correct,
        score: correct ? quiz.points : 0,
        needsReview: !correct,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(correct ? '정답입니다.' : '오답입니다. 복습 필요로 표시했습니다.')),
      );
    }
  }
}

class StudyHistoryScreen extends StatelessWidget {
  const StudyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '학습 기록',
          message: 'Firebase 연결 후 사용할 수 있습니다.',
        ),
      );
    }
    final repo = StudyRepository();
    return StreamBuilder<List<StudySession>>(
      stream: repo.watchSessions(limit: 100),
      builder: (context, snap) {
        final sessions = snap.data ?? const [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHero(
                title: '학습 기록',
                subtitle: '학습 시작을 누르지 않은 시간은 기록하지 않습니다.',
                badge: '소통스터디부',
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                const EmptyStatePanel(
                  title: '학습 기록이 없습니다',
                  message: '강의방에서 학습 시작을 눌러 기록을 남기십시오.',
                )
              else
                ...sessions.map(
                  (s) => Card(
                    child: ListTile(
                      title: Text(
                        '${s.courseId} / ${s.chapterId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormat('yyyy-MM-dd HH:mm').format(s.startedAt)} · '
                        '${StudySessionStatus.labelKo(s.status)} · '
                        '${s.durationMinutes}분'
                        '${s.endedAt == null && s.status == StudySessionStatus.inProgress ? ' · 종료 확인 필요' : ''}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
