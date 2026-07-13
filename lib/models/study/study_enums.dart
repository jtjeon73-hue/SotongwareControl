/// 소통스터디부 상태·유형 코드
class StudyCourseStatus {
  static const draft = 'draft';
  static const ready = 'ready';
  static const inProgress = 'in_progress';
  static const paused = 'paused';
  static const completed = 'completed';
  static const archived = 'archived';

  static String labelKo(String code) {
    switch (code) {
      case draft:
        return '작성 중';
      case ready:
        return '학습 준비';
      case inProgress:
        return '수강 중';
      case paused:
        return '일시 중지';
      case completed:
        return '완료';
      case archived:
        return '보관';
      default:
        return '확인 필요';
    }
  }
}

class StudyChapterStatus {
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

class StudyUnderstanding {
  static const notRated = 'not_rated';
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const mastered = 'mastered';

  static String labelKo(String code) {
    switch (code) {
      case notRated:
        return '미평가';
      case low:
        return '이해 부족';
      case medium:
        return '보통';
      case high:
        return '잘 이해함';
      case mastered:
        return '숙달';
      default:
        return '미평가';
    }
  }
}

class StudyDifficulty {
  static const beginner = 'beginner';
  static const intermediate = 'intermediate';
  static const advanced = 'advanced';

  static String labelKo(String code) {
    switch (code) {
      case beginner:
        return '입문';
      case intermediate:
        return '중급';
      case advanced:
        return '고급';
      default:
        return code.isEmpty ? '미설정' : code;
    }
  }
}

class StudyContentBlockType {
  static const heading = 'heading';
  static const paragraph = 'paragraph';
  static const summary = 'summary';
  static const example = 'example';
  static const code = 'code';
  static const checklist = 'checklist';
  static const warning = 'warning';
  static const tip = 'tip';
  static const image = 'image';
  static const link = 'link';
  static const practice = 'practice';
  static const assignment = 'assignment';
  static const quiz = 'quiz';
}

class StudyAssignmentStatus {
  static const todo = 'todo';
  static const inProgress = 'in_progress';
  static const submitted = 'submitted';
  static const reviewed = 'reviewed';
  static const completed = 'completed';
  static const onHold = 'on_hold';

  static String labelKo(String code) {
    switch (code) {
      case todo:
        return '할 일';
      case inProgress:
        return '진행 중';
      case submitted:
        return '제출됨';
      case reviewed:
        return '검토됨';
      case completed:
        return '완료';
      case onHold:
        return '보류';
      default:
        return '확인 필요';
    }
  }
}

class StudySessionStatus {
  static const inProgress = 'in_progress';
  static const ended = 'ended';
  static const needsEndConfirm = 'needs_end_confirm';

  static String labelKo(String code) {
    switch (code) {
      case inProgress:
        return '진행 중';
      case ended:
        return '종료';
      case needsEndConfirm:
        return '종료 확인 필요';
      default:
        return '확인 필요';
    }
  }
}

class StudyQuestionStatus {
  static const open = 'open';
  static const answered = 'answered';
  static const deferred = 'deferred';

  static String labelKo(String code) {
    switch (code) {
      case open:
        return '미해결';
      case answered:
        return '해결';
      case deferred:
        return '나중에';
      default:
        return '확인 필요';
    }
  }
}

class StudyQuizType {
  static const single = 'single';
  static const multi = 'multi';
  static const trueFalse = 'true_false';
  static const short = 'short';
  static const codeBlank = 'code_blank';
  static const findError = 'find_error';
  static const scenario = 'scenario';

  static String labelKo(String code) {
    switch (code) {
      case single:
        return '객관식';
      case multi:
        return '복수 선택';
      case trueFalse:
        return '참·거짓';
      case short:
        return '주관식';
      case codeBlank:
        return '코드 빈칸';
      case findError:
        return '오류 찾기';
      case scenario:
        return '실무 상황';
      default:
        return code;
    }
  }
}
