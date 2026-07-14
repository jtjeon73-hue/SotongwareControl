import '../../models/study/study_enums.dart';
import '../../models/study/study_generation_models.dart';
import '../../models/study/study_models.dart';

class StudyDashboardKpis {
  const StudyDashboardKpis({
    required this.courseCount,
    required this.inProgressCourses,
    required this.completedCourses,
    required this.totalChapters,
    required this.completedChapters,
    required this.averageProgress,
    required this.reviewNeeded,
    required this.openAssignments,
    required this.sessionsLast7Days,
    required this.studyMinutesThisWeek,
  });

  final int courseCount;
  final int inProgressCourses;
  final int completedCourses;
  final int totalChapters;
  final int completedChapters;
  final int? averageProgress;
  final int reviewNeeded;
  final int openAssignments;
  final int sessionsLast7Days;
  final int studyMinutesThisWeek;
}

/// 순수 계산 로직 — 테스트 가능
class StudyProgressCalculator {
  /// 초안·미공개 챕터는 분모에서 제외. 학습 가능 챕터 없으면 null(미설정).
  static int? courseProgressPercent({
    required List<StudyChapter> chapters,
    required List<StudyProgress> progress,
  }) {
    final eligible = chapters.where((c) => c.countsTowardProgress).toList();
    if (eligible.isEmpty) return null;
    final completedIds = progress
        .where((p) => p.isCompleted)
        .map((p) => p.chapterId)
        .toSet();
    final done = eligible.where((c) => completedIds.contains(c.id)).length;
    return ((done / eligible.length) * 100).round().clamp(0, 100);
  }

  static int completedEligibleCount({
    required List<StudyChapter> chapters,
    required List<StudyProgress> progress,
  }) {
    final eligibleIds = chapters
        .where((c) => c.countsTowardProgress)
        .map((c) => c.id)
        .toSet();
    return progress
        .where((p) => p.isCompleted && eligibleIds.contains(p.chapterId))
        .length;
  }

  /// 공개·비초안 강의가 있으면 강의 기준, 없으면 챕터 기준.
  static int? resolveCourseProgressPercent({
    required List<StudyChapter> chapters,
    required List<StudyProgress> chapterProgress,
    required List<StudyLesson> lessons,
    required List<StudyLessonProgress> lessonProgress,
  }) {
    final eligibleLessons = lessons
        .where((l) => l.countsTowardProgress)
        .toList();
    if (eligibleLessons.isNotEmpty) {
      return lessonProgressPercent(lessons: lessons, progress: lessonProgress);
    }
    return courseProgressPercent(chapters: chapters, progress: chapterProgress);
  }

  static int? lessonProgressPercent({
    required List<StudyLesson> lessons,
    required List<StudyLessonProgress> progress,
  }) {
    final eligible = lessons.where((l) => l.countsTowardProgress).toList();
    if (eligible.isEmpty) return null;
    final completedIds = progress
        .where((p) => p.isCompleted)
        .map((p) => p.lessonId)
        .toSet();
    final done = eligible.where((l) => completedIds.contains(l.id)).length;
    return ((done / eligible.length) * 100).round().clamp(0, 100);
  }

  static int completedEligibleLessons({
    required List<StudyLesson> lessons,
    required List<StudyLessonProgress> progress,
  }) {
    final eligibleIds = lessons
        .where((l) => l.countsTowardProgress)
        .map((l) => l.id)
        .toSet();
    return progress
        .where((p) => p.isCompleted && eligibleIds.contains(p.lessonId))
        .length;
  }
}

class StudyDashboardService {
  StudyDashboardKpis compute({
    required List<StudyCourse> courses,
    required List<StudyChapter> allChapters,
    required List<StudyProgress> progress,
    required List<StudySession> sessions,
    required List<StudyAssignment> assignments,
    required List<StudyReviewItem> reviews,
    required List<StudyQuizAttempt> attempts,
    int reviewDaysThreshold = 14,
    int lowQuizScoreThreshold = 60,
  }) {
    final activeCourses = courses
        .where((c) => c.status != StudyCourseStatus.archived)
        .toList();
    final inProgress = activeCourses
        .where((c) => c.status == StudyCourseStatus.inProgress)
        .length;
    final completed = activeCourses
        .where((c) => c.status == StudyCourseStatus.completed)
        .length;

    final eligibleChapters = allChapters
        .where((c) => c.countsTowardProgress)
        .toList();
    final completedChapters = StudyProgressCalculator.completedEligibleCount(
      chapters: allChapters,
      progress: progress,
    );

    final progressValues = <int>[];
    for (final course in activeCourses) {
      final ch = allChapters.where((c) => c.courseId == course.id).toList();
      final pr = progress.where((p) => p.courseId == course.id).toList();
      final pct = StudyProgressCalculator.courseProgressPercent(
        chapters: ch,
        progress: pr,
      );
      if (pct != null) progressValues.add(pct);
    }
    final avg = progressValues.isEmpty
        ? null
        : (progressValues.reduce((a, b) => a + b) / progressValues.length)
              .round();

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final dayStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final sessions7d = sessions
        .where((s) => s.startedAt.isAfter(weekAgo))
        .length;
    final minutesWeek = sessions
        .where(
          (s) =>
              s.startedAt.isAfter(dayStart) &&
              s.status == StudySessionStatus.ended,
        )
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);

    final openAssign = assignments
        .where(
          (a) =>
              a.status != StudyAssignmentStatus.completed &&
              a.status != StudyAssignmentStatus.onHold,
        )
        .length;

    var reviewCount = reviews.where((r) => r.reviewStatus == 'pending').length;
    reviewCount += progress.where((p) => p.needsReview).length;
    reviewCount += progress
        .where(
          (p) =>
              p.understandingLevel == StudyUnderstanding.low && !p.needsReview,
        )
        .length;
    reviewCount += attempts
        .where(
          (a) =>
              a.needsReview ||
              (!a.isCorrect && a.score < lowQuizScoreThreshold),
        )
        .length;

    // 장기 미학습 (설정 일수)
    for (final p in progress.where((e) => e.lastStudiedAt != null)) {
      if (now.difference(p.lastStudiedAt!).inDays >= reviewDaysThreshold) {
        reviewCount++;
      }
    }

    return StudyDashboardKpis(
      courseCount: activeCourses.length,
      inProgressCourses: inProgress,
      completedCourses: completed,
      totalChapters: eligibleChapters.length,
      completedChapters: completedChapters,
      averageProgress: avg,
      reviewNeeded: reviewCount,
      openAssignments: openAssign,
      sessionsLast7Days: sessions7d,
      studyMinutesThisWeek: minutesWeek,
    );
  }
}

/// AI 미연결 서비스 — 가짜 답변을 반환하지 않음
abstract class StudyAiService {
  bool get isConnected;
  Future<String> explainLesson({
    required String courseTitle,
    required String chapterTitle,
    required String question,
  });
  Future<String> simplifyExplanation(String text);
  Future<String> generateExample(String topic);
  Future<String> generateQuiz(String topic);
  Future<String> evaluateAnswer({
    required String question,
    required String answer,
  });
  Future<String> summarizeChapter(String content);
  Future<String> recommendNextLesson(String context);
}

class DisconnectedStudyAiService implements StudyAiService {
  @override
  bool get isConnected => false;

  Never _fail() => throw StateError('AI선생 자동 대화 기능은 아직 연결되지 않았습니다.');

  @override
  Future<String> explainLesson({
    required String courseTitle,
    required String chapterTitle,
    required String question,
  }) async => _fail();

  @override
  Future<String> simplifyExplanation(String text) async => _fail();

  @override
  Future<String> generateExample(String topic) async => _fail();

  @override
  Future<String> generateQuiz(String topic) async => _fail();

  @override
  Future<String> evaluateAnswer({
    required String question,
    required String answer,
  }) async => _fail();

  @override
  Future<String> summarizeChapter(String content) async => _fail();

  @override
  Future<String> recommendNextLesson(String context) async => _fail();
}

class StudyCourseFilter {
  static List<StudyCourse> apply({
    required List<StudyCourse> courses,
    String query = '',
    String? category,
    String? status,
    String? difficulty,
    String sort = 'recent',
  }) {
    var list = courses
        .where((c) => c.status != StudyCourseStatus.archived)
        .toList();
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.category.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q) ||
                c.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      list = list.where((c) => c.category == category).toList();
    }
    if (status != null && status.isNotEmpty) {
      list = list.where((c) => c.status == status).toList();
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      list = list.where((c) => c.difficulty == difficulty).toList();
    }
    switch (sort) {
      case 'name':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'progress':
        list.sort((a, b) => (b.progress ?? -1).compareTo(a.progress ?? -1));
        break;
      case 'favorite':
        list.sort((a, b) {
          if (a.isFavorite == b.isFavorite) {
            return a.title.compareTo(b.title);
          }
          return a.isFavorite ? -1 : 1;
        });
        break;
      case 'recent':
      default:
        list.sort((a, b) {
          final aa = a.lastStudiedAt ?? a.updatedAt ?? DateTime(1970);
          final bb = b.lastStudiedAt ?? b.updatedAt ?? DateTime(1970);
          return bb.compareTo(aa);
        });
    }
    return list;
  }
}
