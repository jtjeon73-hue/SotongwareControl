/// 개별 강의·생성·수강회차 상태
class StudyLessonStatus {
  static const draft = 'draft';
  static const ready = 'ready';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const reviewNeeded = 'review_needed';

  static String labelKo(String code) {
    switch (code) {
      case draft:
        return '작성 중';
      case ready:
        return '학습 준비';
      case inProgress:
        return '학습 중';
      case completed:
        return '완료';
      case reviewNeeded:
        return '복습 필요';
      default:
        return '확인 필요';
    }
  }
}

class StudyLessonType {
  static const theory = 'theory';
  static const practice = 'practice';
  static const review = 'review';
  static const assessment = 'assessment';
  static const project = 'project';

  static String labelKo(String code) {
    switch (code) {
      case theory:
        return '이론';
      case practice:
        return '실습';
      case review:
        return '복습';
      case assessment:
        return '평가';
      case project:
        return '프로젝트';
      default:
        return code.isEmpty ? '일반' : code;
    }
  }
}

class StudyGenerationStatus {
  static const draft = 'draft';
  static const reviewing = 'reviewing';
  static const approved = 'approved';
  static const generating = 'generating';
  static const readyToPublish = 'ready_to_publish';
  static const published = 'published';
  static const onHold = 'on_hold';
  static const failed = 'failed';

  static String labelKo(String code) {
    switch (code) {
      case draft:
        return '초안';
      case reviewing:
        return '검토 중';
      case approved:
        return '승인';
      case generating:
        return '생성 중';
      case readyToPublish:
        return '공개 준비';
      case published:
        return '공개';
      case onHold:
        return '보류';
      case failed:
        return '실패';
      default:
        return '확인 필요';
    }
  }
}

class StudyValidationStatus {
  static const passed = 'passed';
  static const needsReview = 'needs_review';
  static const failed = 'failed';
  static const regenerate = 'regenerate';
  static const notChecked = 'not_checked';

  static String labelKo(String code) {
    switch (code) {
      case passed:
        return '검증 통과';
      case needsReview:
        return '검토 필요';
      case failed:
        return '생성 실패';
      case regenerate:
        return '재생성 필요';
      case notChecked:
        return '미검증';
      default:
        return '확인 필요';
    }
  }
}

class StudyJobStatus {
  static const draft = 'draft';
  static const waitingApproval = 'waiting_approval';
  static const queued = 'queued';
  static const running = 'running';
  static const paused = 'paused';
  static const completed = 'completed';
  static const partiallyCompleted = 'partially_completed';
  static const failed = 'failed';
  static const cancelled = 'cancelled';

  static String labelKo(String code) {
    switch (code) {
      case draft:
        return '초안';
      case waitingApproval:
        return '승인 대기';
      case queued:
        return '대기열';
      case running:
        return '실행 중';
      case paused:
        return '일시정지';
      case completed:
        return '완료';
      case partiallyCompleted:
        return '부분 완료';
      case failed:
        return '실패';
      case cancelled:
        return '취소';
      default:
        return '확인 필요';
    }
  }
}

class StudyLearningRunStatus {
  static const notStarted = 'not_started';
  static const inProgress = 'in_progress';
  static const paused = 'paused';
  static const completed = 'completed';
  static const abandoned = 'abandoned';

  static String labelKo(String code) {
    switch (code) {
      case notStarted:
        return '시작 전';
      case inProgress:
        return '수강 중';
      case paused:
        return '일시 중지';
      case completed:
        return '완료';
      case abandoned:
        return '중단';
      default:
        return '확인 필요';
    }
  }
}

class StudyCompletionPolicy {
  static const contentOnly = 'content_only';
  static const practiceRequired = 'practice_required';
  static const quizRequired = 'quiz_required';
  static const practiceAndQuiz = 'practice_and_quiz';
  static const adminApproval = 'admin_approval';

  static String labelKo(String code) {
    switch (code) {
      case contentOnly:
        return '본문 확인만';
      case practiceRequired:
        return '실습 필수';
      case quizRequired:
        return '퀴즈 필수';
      case practiceAndQuiz:
        return '실습과 퀴즈 모두 필수';
      case adminApproval:
        return '관리자 승인 필요';
      default:
        return '본문 확인만';
    }
  }
}

class StudyAiLessonMode {
  static const basic = 'basic';
  static const simple = 'simple';
  static const detailed = 'detailed';
  static const practical = 'practical';
  static const review = 'review';
  static const quiz = 'quiz';
  static const exam = 'exam';
  static const project = 'project';

  static String labelKo(String code) {
    switch (code) {
      case basic:
        return '기본 강의';
      case simple:
        return '쉬운 설명';
      case detailed:
        return '상세 설명';
      case practical:
        return '실무 중심';
      case review:
        return '복습 중심';
      case quiz:
        return '문제 풀이';
      case exam:
        return '시험 준비';
      case project:
        return '프로젝트 실습';
      default:
        return code;
    }
  }
}
