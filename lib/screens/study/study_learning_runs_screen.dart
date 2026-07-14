import 'package:flutter/material.dart';

import '../../models/study/study_generation_enums.dart';
import '../../models/study/study_generation_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_generation_logic.dart';
import '../../services/study/study_generation_service.dart';
import '../../theme/control_theme.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';

class StudyLearningRunsScreen extends StatefulWidget {
  const StudyLearningRunsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<StudyLearningRunsScreen> createState() =>
      _StudyLearningRunsScreenState();
}

class _StudyLearningRunsScreenState extends State<StudyLearningRunsScreen> {
  final _svc = StudyGenerationService();
  bool _busy = false;

  Future<void> _startNewRun(List<StudyLesson> lessons) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 학습 회차 시작'),
        content: const Text(
          '처음부터 다시 수강합니다. 기존 회차의 진도·퀴즈·기록은 삭제되지 않습니다.\n'
          '새 회차는 진도 0%로 시작합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('새 회차 시작'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final published = lessons.where((l) => l.countsTowardProgress).length;
      await _svc.startNewLearningRun(
        courseId: widget.courseId,
        totalLessonCount: published > 0 ? published : lessons.length,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('새 학습 회차를 시작했습니다. 진도 0%')));
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

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Scaffold(body: Center(child: Text('Firebase 미연결')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('수강 회차')),
      body: StreamBuilder<List<StudyLearningRun>>(
        stream: _svc.watchLearningRuns(widget.courseId),
        builder: (context, snap) {
          final runs = snap.data ?? const [];
          return StreamBuilder<List<StudyLesson>>(
            stream: _svc.watchLessons(widget.courseId),
            builder: (context, lesSnap) {
              final lessons = lesSnap.data ?? const [];
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const PageHero(
                    title: '처음부터 다시 수강',
                    subtitle: '회차별로 진도와 기록이 분리됩니다. 이전 회차는 보존됩니다.',
                    badge: '회차',
                  ),
                  const SizedBox(height: 12),
                  if (_busy) const LinearProgressIndicator(),
                  FilledButton(
                    onPressed: _busy ? null : () => _startNewRun(lessons),
                    child: const Text('새 학습 회차 시작'),
                  ),
                  const SizedBox(height: 16),
                  if (runs.isEmpty)
                    const EmptyStatePanel(
                      title: '수강 회차 없음',
                      message: '강의를 열면 1회차가 자동 생성되거나, 여기서 새 회차를 시작할 수 있습니다.',
                    )
                  else ...[
                    ...runs.map(
                      (r) => Card(
                        child: ListTile(
                          title: Text('${r.runNumber}회차'),
                          subtitle: Text(
                            '${StudyLearningRunStatus.labelKo(r.status)} · '
                            '진도 ${r.progress ?? 0}% · '
                            '완료 ${r.completedLessonCount}/${r.totalLessonCount} · '
                            '학습 ${r.totalStudyMinutes}분'
                            '${r.averageQuizScore == null ? '' : ' · 퀴즈 평균 ${r.averageQuizScore}'}',
                          ),
                        ),
                      ),
                    ),
                    if (runs.length >= 2) ...[
                      const SizedBox(height: 16),
                      Text(
                        '회차 비교 (최근 2회)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Builder(
                        builder: (context) {
                          final a = runs[1];
                          final b = runs[0];
                          final c = StudyLearningRunComparer.compare(
                            a: a,
                            b: b,
                          );
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${c.runA}회차 vs ${c.runB}회차'),
                                  Text(
                                    '진도: ${c.progressA ?? 0}% → ${c.progressB ?? 0}%',
                                  ),
                                  Text(
                                    '학습 시간: ${c.minutesA}분 → ${c.minutesB}분',
                                  ),
                                  Text(
                                    '완료 강의: ${c.completedLessonsA} → ${c.completedLessonsB}',
                                  ),
                                  Text(
                                    '퀴즈 평균: ${c.quizA ?? '—'} → ${c.quizB ?? '—'}',
                                  ),
                                  Text(
                                    '완료 여부: ${c.completedA} → ${c.completedB}',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'AI 학습 개선 분석은 AI 연결 후 이용할 수 있습니다. 현재는 수치 비교만 표시합니다.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
