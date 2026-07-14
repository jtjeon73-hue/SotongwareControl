import '../../models/study/study_generation_models.dart';
import 'study_generation_logic.dart';

/// AI 공급자 교체 가능 인터페이스 — API Key는 Flutter에 두지 않음
abstract class StudyAiProvider {
  String get providerId;
  bool get isConnected;
  String get connectionMessage;
}

abstract class StudyCourseGenerator {
  bool get isConnected;
  Future<OutlineScaffoldResult> generateOutline(
    StudyCourseGenerationRequest request,
  );
}

abstract class StudyLessonGenerator {
  bool get isConnected;
  Future<StudyLesson> generateLessonBody({
    required StudyLesson outlineLesson,
    required StudyCourseGenerationRequest request,
  });
}

abstract class StudyQuizGenerator {
  bool get isConnected;
  Future<Map<String, dynamic>> generateQuiz({
    required String lessonTitle,
    required String lessonContent,
  });
}

abstract class StudyAnswerEvaluator {
  bool get isConnected;
  Future<String> evaluate({
    required String question,
    required String answer,
    required String lessonContext,
  });
}

/// 미연결 구현 — 가짜 강의/답변을 만들지 않음
class DisconnectedStudyAiProvider implements StudyAiProvider {
  @override
  String get providerId => 'disconnected';

  @override
  bool get isConnected => false;

  @override
  String get connectionMessage =>
      'AI 강의 자동 생성 기능은 아직 연결되지 않았습니다.\n'
      '현재는 강의 개요와 생성 조건을 저장할 수 있습니다.';
}

class DisconnectedStudyCourseGenerator implements StudyCourseGenerator {
  @override
  bool get isConnected => false;

  @override
  Future<OutlineScaffoldResult> generateOutline(
    StudyCourseGenerationRequest request,
  ) async {
    throw StateError(
      'AI 강의 자동 생성 기능은 아직 연결되지 않았습니다. '
      '현재는 강의 개요와 생성 조건을 저장할 수 있습니다.',
    );
  }
}

class DisconnectedStudyLessonGenerator implements StudyLessonGenerator {
  @override
  bool get isConnected => false;

  @override
  Future<StudyLesson> generateLessonBody({
    required StudyLesson outlineLesson,
    required StudyCourseGenerationRequest request,
  }) async {
    throw StateError('AI 개별 강의 생성 기능은 아직 연결되지 않았습니다.');
  }
}

class DisconnectedStudyQuizGenerator implements StudyQuizGenerator {
  @override
  bool get isConnected => false;

  @override
  Future<Map<String, dynamic>> generateQuiz({
    required String lessonTitle,
    required String lessonContent,
  }) async {
    throw StateError('AI 퀴즈 생성 기능은 아직 연결되지 않았습니다.');
  }
}

class DisconnectedStudyAnswerEvaluator implements StudyAnswerEvaluator {
  @override
  bool get isConnected => false;

  @override
  Future<String> evaluate({
    required String question,
    required String answer,
    required String lessonContext,
  }) async {
    throw StateError('AI 답안 평가 기능은 아직 연결되지 않았습니다.');
  }
}

abstract class StudyAiLessonTutor {
  bool get isConnected;
  Future<String> respond({
    required String mode,
    required String userMessage,
    required Map<String, String> lessonContext,
  });
}

class DisconnectedStudyAiLessonTutor implements StudyAiLessonTutor {
  @override
  bool get isConnected => false;

  @override
  Future<String> respond({
    required String mode,
    required String userMessage,
    required Map<String, String> lessonContext,
  }) async {
    throw StateError('AI선생 자동 대화 기능은 아직 연결되지 않았습니다.');
  }
}

/// 비용 표시 — 단가 없으면 미설정
class StudyAiUsageDisplay {
  static String costLabel({
    required int? inputTokens,
    required int? outputTokens,
    double? inputUnitPrice,
    double? outputUnitPrice,
  }) {
    if (inputUnitPrice == null && outputUnitPrice == null) {
      return '비용 미설정';
    }
    final inT = inputTokens ?? 0;
    final outT = outputTokens ?? 0;
    final cost = inT * (inputUnitPrice ?? 0) + outT * (outputUnitPrice ?? 0);
    if (cost <= 0 && inT == 0 && outT == 0) return '비용 미설정';
    return cost.toStringAsFixed(4);
  }
}
