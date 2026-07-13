import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_dashboard_service.dart';
import '../../services/study/study_repository.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/study/study_widgets.dart';

class StudyCourseDetailScreen extends StatefulWidget {
  const StudyCourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<StudyCourseDetailScreen> createState() =>
      _StudyCourseDetailScreenState();
}

class _StudyCourseDetailScreenState extends State<StudyCourseDetailScreen> {
  StudyRepository? _repo;
  StudyRepository get repo => _repo ??= StudyRepository();

  Future<void> _refreshCourseStats(
    StudyCourse course,
    List<StudyChapter> chapters,
    List<StudyProgress> progress,
  ) async {
    final pct = StudyProgressCalculator.courseProgressPercent(
      chapters: chapters,
      progress: progress,
    );
    final eligible = chapters.where((c) => c.countsTowardProgress).length;
    final done = StudyProgressCalculator.completedEligibleCount(
      chapters: chapters,
      progress: progress,
    );
    await repo.upsertCourse(
      StudyCourse(
        id: course.id,
        title: course.title,
        category: course.category,
        description: course.description,
        learningGoal: course.learningGoal,
        targetLevel: course.targetLevel,
        difficulty: course.difficulty,
        status: course.status,
        iconName: course.iconName,
        isFavorite: course.isFavorite,
        chapterCount: eligible,
        completedChapterCount: done,
        progress: pct,
        nextAction: course.nextAction,
        tags: course.tags,
        lastStudiedAt: course.lastStudiedAt,
        relatedBusinessUnitId: course.relatedBusinessUnitId,
        relatedProjectId: course.relatedProjectId,
      ),
    );
  }

  Future<void> _addChapter(StudyCourse course, int nextOrder) async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('챕터 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: '설명'),
              maxLines: 2,
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
    await repo.upsertChapter(
      StudyChapter(
        id: '',
        courseId: course.id,
        title: title.text.trim(),
        description: desc.text.trim(),
        chapterNumber: nextOrder + 1,
        displayOrder: nextOrder,
        status: StudyChapterStatus.draft,
        isPublished: false,
      ),
      isNew: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('챕터를 추가했습니다.')));
    }
  }

  Future<void> _startSession(StudyCourse course, StudyChapter chapter) async {
    await repo.upsertSession(
      StudySession(
        id: '',
        courseId: course.id,
        chapterId: chapter.id,
        startedAt: DateTime.now(),
        status: StudySessionStatus.inProgress,
      ),
      isNew: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습을 시작했습니다. 종료 시 세션을 닫아 주십시오.')),
      );
    }
  }

  Future<void> _completeChapter(
    StudyCourse course,
    StudyChapter chapter,
    List<StudyChapter> chapters,
    List<StudyProgress> allProgress,
  ) async {
    var understanding = StudyUnderstanding.medium;
    var needsReview = false;
    final memo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('챕터 학습 기록'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: understanding,
                decoration: const InputDecoration(labelText: '이해도'),
                items: [
                  StudyUnderstanding.low,
                  StudyUnderstanding.medium,
                  StudyUnderstanding.high,
                  StudyUnderstanding.mastered,
                ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(StudyUnderstanding.labelKo(e)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setLocal(() => understanding = v ?? understanding),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: needsReview,
                onChanged: (v) => setLocal(() => needsReview = v ?? false),
                title: const Text('복습 필요'),
              ),
              TextField(
                controller: memo,
                decoration: const InputDecoration(labelText: '메모'),
                maxLines: 2,
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
              child: const Text('완료 기록'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await repo.upsertProgress(
      StudyProgress(
        id: '${course.id}_${chapter.id}',
        courseId: course.id,
        chapterId: chapter.id,
        status: StudyChapterStatus.completed,
        understandingLevel: understanding,
        isCompleted: true,
        needsReview: needsReview,
        difficultyNote: memo.text.trim(),
        lastStudiedAt: DateTime.now(),
        completedAt: DateTime.now(),
      ),
    );

    if (needsReview) {
      await repo.upsertReview(
        StudyReviewItem(
          id: '',
          courseId: course.id,
          chapterId: chapter.id,
          reason: '사용자가 복습 필요로 지정',
          sourceType: 'progress',
        ),
        isNew: true,
      );
    }

    final updatedProgress = [
      ...allProgress.where((p) => p.chapterId != chapter.id),
      StudyProgress(
        id: '${course.id}_${chapter.id}',
        courseId: course.id,
        chapterId: chapter.id,
        isCompleted: true,
        understandingLevel: understanding,
        needsReview: needsReview,
        lastStudiedAt: DateTime.now(),
      ),
    ];
    await _refreshCourseStats(course, chapters, updatedProgress);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('챕터 완료를 기록했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return Scaffold(
        appBar: AppBar(title: const Text('강의방')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStatePanel(
            title: 'Firebase 미연결',
            message: '로그인 후 강의방을 확인할 수 있습니다.',
          ),
        ),
      );
    }

    return StreamBuilder<StudyCourse?>(
      stream: repo.watchCourse(widget.courseId),
      builder: (context, courseSnap) {
        final course = courseSnap.data;
        if (courseSnap.connectionState == ConnectionState.waiting &&
            course == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('강의방')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (course == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('강의방')),
            body: const Padding(
              padding: EdgeInsets.all(24),
              child: EmptyStatePanel(
                title: '강의방을 찾을 수 없습니다',
                message: '삭제되었거나 ID가 올바르지 않습니다.',
              ),
            ),
          );
        }

        return StreamBuilder<List<StudyChapter>>(
          stream: repo.watchChapters(course.id),
          builder: (context, chSnap) {
            return StreamBuilder<List<StudyProgress>>(
              stream: repo.watchProgress(courseId: course.id),
              builder: (context, prSnap) {
                return StreamBuilder<List<StudySession>>(
                  stream: repo.watchSessions(),
                  builder: (context, sessSnap) {
                    final chapters = chSnap.data ?? const [];
                    final progress = prSnap.data ?? const [];
                    final sessions = (sessSnap.data ?? const [])
                        .where((s) => s.courseId == course.id)
                        .toList();
                    final progressMap = {
                      for (final p in progress) p.chapterId: p,
                    };
                    final computed = StudyProgressCalculator.courseProgressPercent(
                      chapters: chapters,
                      progress: progress,
                    );
                    final openSessions = sessions
                        .where(
                          (s) =>
                              s.status == StudySessionStatus.inProgress ||
                              s.status == StudySessionStatus.needsEndConfirm,
                        )
                        .toList();

                    return Scaffold(
                      appBar: AppBar(
                        title: Text(
                          course.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                _addChapter(course, chapters.length),
                            child: const Text('챕터 추가'),
                          ),
                        ],
                      ),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusBadge(
                                  label: StudyCourseStatus.labelKo(
                                    course.status,
                                  ),
                                ),
                                StatusBadge(
                                  label: StudyDifficulty.labelKo(
                                    course.difficulty,
                                  ),
                                ),
                                if (course.category.isNotEmpty)
                                  StatusBadge(label: course.category),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '강의 개요',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      course.learningGoal.isEmpty
                                          ? '학습 목적: 미등록'
                                          : '학습 목적: ${course.learningGoal}',
                                    ),
                                    ProgressLabel(progress: computed),
                                    Text(
                                      '챕터 ${StudyProgressCalculator.completedEligibleCount(chapters: chapters, progress: progress)}/'
                                      '${chapters.where((c) => c.countsTowardProgress).length}',
                                    ),
                                    Text(
                                      '최근 학습: ${course.lastStudiedAt == null ? '없음' : DateFormat('yyyy-MM-dd HH:mm').format(course.lastStudiedAt!)}',
                                    ),
                                    Text(
                                      '다음 학습: ${course.nextAction.isEmpty ? '첫 챕터를 등록하십시오.' : course.nextAction}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (openSessions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Card(
                                child: ListTile(
                                  title: const Text('진행 중 학습 세션'),
                                  subtitle: Text(
                                    '${openSessions.length}건 · 종료 확인 필요 가능',
                                  ),
                                  trailing: FilledButton(
                                    onPressed: () async {
                                      final s = openSessions.first;
                                      final end = DateTime.now();
                                      final mins = end
                                          .difference(s.startedAt)
                                          .inMinutes
                                          .clamp(0, 24 * 60);
                                      await repo.upsertSession(
                                        StudySession(
                                          id: s.id,
                                          courseId: s.courseId,
                                          chapterId: s.chapterId,
                                          startedAt: s.startedAt,
                                          endedAt: end,
                                          durationMinutes: mins,
                                          status: StudySessionStatus.ended,
                                          understandingLevel:
                                              s.understandingLevel,
                                          memo: s.memo,
                                        ),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '세션 종료 · $mins분 기록',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('학습 종료'),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              '챕터 목록',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (chapters.isEmpty)
                              EmptyStatePanel(
                                title: '등록된 챕터가 없습니다',
                                message: '첫 챕터를 추가하여 강의를 구성하십시오.',
                                actionLabel: '챕터 추가',
                                onAction: () =>
                                    _addChapter(course, chapters.length),
                              )
                            else
                              ...chapters.map((ch) {
                                final pr = progressMap[ch.id];
                                return StudyChapterTile(
                                  chapter: ch,
                                  progress: pr,
                                  onOpen: () async {
                                    final action = await showModalBottomSheet<
                                      String
                                    >(
                                      context: context,
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              title: const Text('학습 시작'),
                                              onTap: () =>
                                                  Navigator.pop(ctx, 'start'),
                                            ),
                                            ListTile(
                                              title: const Text('완료 기록'),
                                              onTap: () => Navigator.pop(
                                                ctx,
                                                'complete',
                                              ),
                                            ),
                                            ListTile(
                                              title: const Text('공개(진도 포함)'),
                                              onTap: () =>
                                                  Navigator.pop(ctx, 'publish'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (action == 'start') {
                                      await _startSession(course, ch);
                                    } else if (action == 'complete') {
                                      await _completeChapter(
                                        course,
                                        ch,
                                        chapters,
                                        progress,
                                      );
                                    } else if (action == 'publish') {
                                      await repo.upsertChapter(
                                        StudyChapter(
                                          id: ch.id,
                                          courseId: ch.courseId,
                                          title: ch.title,
                                          chapterNumber: ch.chapterNumber,
                                          description: ch.description,
                                          estimatedMinutes: ch.estimatedMinutes,
                                          difficulty: ch.difficulty,
                                          status: StudyChapterStatus.ready,
                                          displayOrder: ch.displayOrder,
                                          isPublished: true,
                                          learningObjectives:
                                              ch.learningObjectives,
                                        ),
                                      );
                                    }
                                  },
                                );
                              }),
                            const SizedBox(height: 16),
                            Text(
                              '최근 학습 기록',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (sessions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('학습 기록 없음'),
                              )
                            else
                              ...sessions.take(8).map(
                                (s) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '챕터 ${s.chapterId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${DateFormat('yyyy-MM-dd HH:mm').format(s.startedAt)} · '
                                    '${StudySessionStatus.labelKo(s.status)} · '
                                    '${s.durationMinutes}분',
                                  ),
                                ),
                              ),
                          ],
                        ),
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
