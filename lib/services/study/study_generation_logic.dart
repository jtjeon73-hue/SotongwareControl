import '../../models/study/study_enums.dart';
import '../../models/study/study_generation_enums.dart';
import '../../models/study/study_generation_models.dart';

/// 생성 작업 진행률·상태 집계 (순수)
class StudyGenerationJobCalculator {
  static int? progressPercent({
    required int requested,
    required int completed,
  }) {
    if (requested <= 0) return null;
    return ((completed / requested) * 100).round().clamp(0, 100);
  }

  static String deriveStatus({
    required String current,
    required int requested,
    required int completed,
    required int failed,
    bool cancelled = false,
    bool paused = false,
  }) {
    if (cancelled) return StudyJobStatus.cancelled;
    if (paused) return StudyJobStatus.paused;
    if (current == StudyJobStatus.draft ||
        current == StudyJobStatus.waitingApproval ||
        current == StudyJobStatus.queued) {
      return current;
    }
    if (completed >= requested && failed == 0) {
      return StudyJobStatus.completed;
    }
    if (completed > 0 && completed < requested && failed > 0) {
      return StudyJobStatus.partiallyCompleted;
    }
    if (completed == 0 && failed > 0) return StudyJobStatus.failed;
    if (completed > 0 && completed < requested) {
      return StudyJobStatus.running;
    }
    return current;
  }
}

/// AI 없이 빈 목차 골격만 설계 (제목 플레이스홀더, 본문 없음)
class StudyOutlineScaffoldBuilder {
  /// [requestedLessonCount] 최소 30 권장. 분야명 하드코딩 없음.
  static OutlineScaffoldResult build({
    required String interestField,
    required int requestedLessonCount,
    int? chapterCount,
    String difficulty = StudyDifficulty.beginner,
  }) {
    final field =
        interestField.trim().isEmpty ? '관심 분야' : interestField.trim();
    final total = requestedLessonCount < 1 ? 30 : requestedLessonCount;
    final chaptersN = chapterCount ?? _suggestChapterCount(total);
    final perChapter = _distribute(total, chaptersN);

    final chapters = <OutlineChapterDraft>[];
    var lessonNo = 1;
    for (var c = 0; c < chaptersN; c++) {
      final lessons = <OutlineLessonDraft>[];
      final count = perChapter[c];
      for (var i = 0; i < count; i++) {
        lessons.add(
          OutlineLessonDraft(
            lessonNumber: lessonNo,
            title: '$lessonNo강. (제목 입력 필요)',
            description: '$field 과정 — 챕터 ${c + 1} 개별 강의 $lessonNo',
            difficulty: difficulty,
            lessonType: _lessonTypeFor(lessonNo, total),
            displayOrder: i,
          ),
        );
        lessonNo++;
      }
      chapters.add(
        OutlineChapterDraft(
          chapterNumber: c + 1,
          title: '챕터 ${c + 1}. (제목 입력 필요)',
          description: '$field 학습 단계 ${c + 1}',
          lessonCount: count,
          displayOrder: c,
          lessons: lessons,
        ),
      );
    }

    return OutlineScaffoldResult(
      title: '$field 과정',
      description:
          '$field 관심 분야에 대한 빈 목차 골격입니다. AI 생성 본문이 아닙니다.',
      chapterCount: chaptersN,
      lessonCount: total,
      chapters: chapters,
      isAiGenerated: false,
    );
  }

  static int _suggestChapterCount(int lessons) {
    if (lessons <= 24) return 4;
    if (lessons <= 40) return 6;
    if (lessons <= 56) return 7;
    return 8;
  }

  static List<int> _distribute(int total, int chapters) {
    final base = total ~/ chapters;
    var rem = total % chapters;
    return List.generate(chapters, (i) {
      final extra = rem > 0 ? 1 : 0;
      if (rem > 0) rem--;
      return base + extra;
    });
  }

  static String _lessonTypeFor(int n, int total) {
    if (n == total) return StudyLessonType.assessment;
    if (n % 5 == 0) return StudyLessonType.practice;
    if (n % 8 == 0) return StudyLessonType.review;
    return StudyLessonType.theory;
  }
}

class OutlineLessonDraft {
  const OutlineLessonDraft({
    required this.lessonNumber,
    required this.title,
    this.description = '',
    this.difficulty = StudyDifficulty.beginner,
    this.lessonType = StudyLessonType.theory,
    this.displayOrder = 0,
  });

  final int lessonNumber;
  final String title;
  final String description;
  final String difficulty;
  final String lessonType;
  final int displayOrder;
}

class OutlineChapterDraft {
  const OutlineChapterDraft({
    required this.chapterNumber,
    required this.title,
    required this.lessons,
    this.description = '',
    this.lessonCount = 0,
    this.displayOrder = 0,
  });

  final int chapterNumber;
  final String title;
  final String description;
  final int lessonCount;
  final int displayOrder;
  final List<OutlineLessonDraft> lessons;
}

class OutlineScaffoldResult {
  const OutlineScaffoldResult({
    required this.title,
    required this.description,
    required this.chapterCount,
    required this.lessonCount,
    required this.chapters,
    this.isAiGenerated = false,
  });

  final String title;
  final String description;
  final int chapterCount;
  final int lessonCount;
  final List<OutlineChapterDraft> chapters;
  final bool isAiGenerated;
}

/// 강의 콘텐츠 검증 (순수)
class StudyLessonValidator {
  static LessonValidationResult validate(StudyLesson lesson) {
    final issues = <String>[];
    if (lesson.lessonNumber < 1) issues.add('강의 번호 누락');
    if (lesson.title.trim().isEmpty || lesson.title.contains('제목 입력 필요')) {
      issues.add('강의 제목 미입력');
    }
    if (!lesson.hasBody && lesson.isPublished) {
      issues.add('빈 본문');
    }
    final bodyLen =
        lesson.intro.length +
        lesson.coreConcept.length +
        lesson.simpleExplanation.length +
        lesson.summary.length;
    if (lesson.hasBody && bodyLen < 40) {
      issues.add('너무 짧은 강의');
    }
    if (lesson.contentBlocks.any((b) {
      final t = '${b['body'] ?? b['content'] ?? ''}';
      return t.toLowerCase().contains('<script') ||
          t.toLowerCase().contains('javascript:');
    })) {
      issues.add('금지된 HTML 또는 스크립트');
    }

    if (issues.isEmpty && lesson.hasBody) {
      return const LessonValidationResult(
        status: StudyValidationStatus.passed,
        issues: [],
      );
    }
    if (issues.isEmpty) {
      return const LessonValidationResult(
        status: StudyValidationStatus.needsReview,
        issues: ['본문 미생성 — 검토 필요'],
      );
    }
    if (issues.any((e) => e.contains('스크립트') || e.contains('빈 본문'))) {
      return LessonValidationResult(
        status: StudyValidationStatus.failed,
        issues: issues,
      );
    }
    return LessonValidationResult(
      status: StudyValidationStatus.needsReview,
      issues: issues,
    );
  }

  static List<String> findDuplicateTitles(List<StudyLesson> lessons) {
    final seen = <String>{};
    final dups = <String>[];
    for (final l in lessons) {
      final key = l.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (!seen.add(key)) dups.add(l.title);
    }
    return dups;
  }
}

class LessonValidationResult {
  const LessonValidationResult({required this.status, required this.issues});
  final String status;
  final List<String> issues;
}

/// 수강회차 비교
class StudyLearningRunComparer {
  static LearningRunComparison compare({
    required StudyLearningRun a,
    required StudyLearningRun b,
  }) {
    return LearningRunComparison(
      runA: a.runNumber,
      runB: b.runNumber,
      progressA: a.progress,
      progressB: b.progress,
      minutesA: a.totalStudyMinutes,
      minutesB: b.totalStudyMinutes,
      quizA: a.averageQuizScore,
      quizB: b.averageQuizScore,
      completedLessonsA: a.completedLessonCount,
      completedLessonsB: b.completedLessonCount,
      completedA: a.status == StudyLearningRunStatus.completed,
      completedB: b.status == StudyLearningRunStatus.completed,
    );
  }
}

class LearningRunComparison {
  const LearningRunComparison({
    required this.runA,
    required this.runB,
    this.progressA,
    this.progressB,
    this.minutesA = 0,
    this.minutesB = 0,
    this.quizA,
    this.quizB,
    this.completedLessonsA = 0,
    this.completedLessonsB = 0,
    this.completedA = false,
    this.completedB = false,
  });

  final int runA;
  final int runB;
  final int? progressA;
  final int? progressB;
  final int minutesA;
  final int minutesB;
  final double? quizA;
  final double? quizB;
  final int completedLessonsA;
  final int completedLessonsB;
  final bool completedA;
  final bool completedB;
}

/// 완료 정책 확인
class StudyLessonCompletionChecker {
  static bool canComplete({
    required StudyLesson lesson,
    required bool contentConfirmed,
    required bool practiceDone,
    required bool quizDone,
    required bool adminApproved,
  }) {
    switch (lesson.completionPolicy) {
      case StudyCompletionPolicy.practiceRequired:
        return contentConfirmed && practiceDone;
      case StudyCompletionPolicy.quizRequired:
        return contentConfirmed && quizDone;
      case StudyCompletionPolicy.practiceAndQuiz:
        return contentConfirmed && practiceDone && quizDone;
      case StudyCompletionPolicy.adminApproval:
        return adminApproved;
      case StudyCompletionPolicy.contentOnly:
      default:
        return contentConfirmed;
    }
  }
}

/// 중복 생성 방지 키
class StudyGenerationDeduper {
  static String itemKey({
    required String jobId,
    required int lessonNumber,
  }) => '$jobId#$lessonNumber';

  static bool alreadyCompleted({
    required Set<String> completedKeys,
    required String jobId,
    required int lessonNumber,
  }) =>
      completedKeys.contains(
        itemKey(jobId: jobId, lessonNumber: lessonNumber),
      );
}
