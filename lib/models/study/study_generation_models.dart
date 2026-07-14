import 'package:cloud_firestore/cloud_firestore.dart';

import 'study_enums.dart';
import 'study_generation_enums.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _str(dynamic v, [String d = '']) =>
    (v is String ? v : v?.toString() ?? d).trim();

class StudyLesson {
  const StudyLesson({
    required this.id,
    required this.courseId,
    required this.chapterId,
    required this.title,
    this.courseVersionId = '',
    this.lessonNumber = 1,
    this.description = '',
    this.learningObjectives = const [],
    this.estimatedMinutes = 0,
    this.difficulty = StudyDifficulty.beginner,
    this.lessonType = StudyLessonType.theory,
    this.status = StudyLessonStatus.draft,
    this.contentBlocks = const [],
    this.practiceIds = const [],
    this.quizIds = const [],
    this.prerequisiteLessonIds = const [],
    this.keywords = const [],
    this.displayOrder = 0,
    this.isPublished = false,
    this.generationStatus = StudyGenerationStatus.draft,
    this.validationStatus = StudyValidationStatus.notChecked,
    this.completionPolicy = StudyCompletionPolicy.contentOnly,
    this.intro = '',
    this.coreConcept = '',
    this.simpleExplanation = '',
    this.practicalExplanation = '',
    this.summary = '',
    this.warnings = '',
    this.commonMistakes = '',
    this.nextLessonHint = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String courseVersionId;
  final String chapterId;
  final int lessonNumber;
  final String title;
  final String description;
  final List<String> learningObjectives;
  final int estimatedMinutes;
  final String difficulty;
  final String lessonType;
  final String status;
  final List<Map<String, dynamic>> contentBlocks;
  final List<String> practiceIds;
  final List<String> quizIds;
  final List<String> prerequisiteLessonIds;
  final List<String> keywords;
  final int displayOrder;
  final bool isPublished;
  final String generationStatus;
  final String validationStatus;
  final String completionPolicy;
  final String intro;
  final String coreConcept;
  final String simpleExplanation;
  final String practicalExplanation;
  final String summary;
  final String warnings;
  final String commonMistakes;
  final String nextLessonHint;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get countsTowardProgress =>
      isPublished && status != StudyLessonStatus.draft;

  bool get hasBody =>
      intro.trim().isNotEmpty ||
      coreConcept.trim().isNotEmpty ||
      simpleExplanation.trim().isNotEmpty ||
      contentBlocks.isNotEmpty;

  factory StudyLesson.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyLesson(
      id: doc.id,
      courseId: _str(d['courseId']),
      courseVersionId: _str(d['courseVersionId']),
      chapterId: _str(d['chapterId']),
      lessonNumber: (d['lessonNumber'] as num?)?.toInt() ?? 1,
      title: _str(d['title'], doc.id),
      description: _str(d['description']),
      learningObjectives: ((d['learningObjectives'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 0,
      difficulty: _str(d['difficulty'], StudyDifficulty.beginner),
      lessonType: _str(d['lessonType'], StudyLessonType.theory),
      status: _str(d['status'], StudyLessonStatus.draft),
      contentBlocks: ((d['contentBlocks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      practiceIds: ((d['practiceIds'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      quizIds: ((d['quizIds'] as List?) ?? const []).map((e) => '$e').toList(),
      prerequisiteLessonIds: ((d['prerequisiteLessonIds'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      keywords: ((d['keywords'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      displayOrder: (d['displayOrder'] as num?)?.toInt() ?? 0,
      isPublished: d['isPublished'] == true,
      generationStatus: _str(
        d['generationStatus'],
        StudyGenerationStatus.draft,
      ),
      validationStatus: _str(
        d['validationStatus'],
        StudyValidationStatus.notChecked,
      ),
      completionPolicy: _str(
        d['completionPolicy'],
        StudyCompletionPolicy.contentOnly,
      ),
      intro: _str(d['intro']),
      coreConcept: _str(d['coreConcept']),
      simpleExplanation: _str(d['simpleExplanation']),
      practicalExplanation: _str(d['practicalExplanation']),
      summary: _str(d['summary']),
      warnings: _str(d['warnings']),
      commonMistakes: _str(d['commonMistakes']),
      nextLessonHint: _str(d['nextLessonHint']),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'courseVersionId': courseVersionId,
    'chapterId': chapterId,
    'lessonNumber': lessonNumber,
    'title': title,
    'description': description,
    'learningObjectives': learningObjectives,
    'estimatedMinutes': estimatedMinutes,
    'difficulty': difficulty,
    'lessonType': lessonType,
    'status': status,
    'contentBlocks': contentBlocks,
    'practiceIds': practiceIds,
    'quizIds': quizIds,
    'prerequisiteLessonIds': prerequisiteLessonIds,
    'keywords': keywords,
    'displayOrder': displayOrder,
    'isPublished': isPublished,
    'generationStatus': generationStatus,
    'validationStatus': validationStatus,
    'completionPolicy': completionPolicy,
    'intro': intro,
    'coreConcept': coreConcept,
    'simpleExplanation': simpleExplanation,
    'practicalExplanation': practicalExplanation,
    'summary': summary,
    'warnings': warnings,
    'commonMistakes': commonMistakes,
    'nextLessonHint': nextLessonHint,
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyCourseVersion {
  const StudyCourseVersion({
    required this.id,
    required this.courseId,
    required this.versionNumber,
    this.title = '',
    this.description = '',
    this.generationPrompt = '',
    this.generationSettings = const {},
    this.chapterCount = 0,
    this.lessonCount = 0,
    this.status = StudyGenerationStatus.draft,
    this.isPublished = false,
    this.previousVersionId = '',
    this.createdAt,
    this.approvedAt,
    this.approvedBy = '',
  });

  final String id;
  final String courseId;
  final int versionNumber;
  final String title;
  final String description;
  final String generationPrompt;
  final Map<String, dynamic> generationSettings;
  final int chapterCount;
  final int lessonCount;
  final String status;
  final bool isPublished;
  final String previousVersionId;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String approvedBy;

  factory StudyCourseVersion.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return StudyCourseVersion(
      id: doc.id,
      courseId: _str(d['courseId']),
      versionNumber: (d['versionNumber'] as num?)?.toInt() ?? 1,
      title: _str(d['title']),
      description: _str(d['description']),
      generationPrompt: _str(d['generationPrompt']),
      generationSettings: Map<String, dynamic>.from(
        (d['generationSettings'] as Map?) ?? const {},
      ),
      chapterCount: (d['chapterCount'] as num?)?.toInt() ?? 0,
      lessonCount: (d['lessonCount'] as num?)?.toInt() ?? 0,
      status: _str(d['status'], StudyGenerationStatus.draft),
      isPublished: d['isPublished'] == true,
      previousVersionId: _str(d['previousVersionId']),
      createdAt: _ts(d['createdAt']),
      approvedAt: _ts(d['approvedAt']),
      approvedBy: _str(d['approvedBy']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'versionNumber': versionNumber,
    'title': title,
    'description': description,
    'generationPrompt': generationPrompt,
    'generationSettings': generationSettings,
    'chapterCount': chapterCount,
    'lessonCount': lessonCount,
    'status': status,
    'isPublished': isPublished,
    'previousVersionId': previousVersionId,
    'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
    'approvedBy': approvedBy,
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyLearningRun {
  const StudyLearningRun({
    required this.id,
    required this.courseId,
    required this.runNumber,
    this.courseVersionId = '',
    this.status = StudyLearningRunStatus.notStarted,
    this.startedAt,
    this.completedAt,
    this.currentChapterId = '',
    this.currentLessonId = '',
    this.completedLessonCount = 0,
    this.totalLessonCount = 0,
    this.progress,
    this.totalStudyMinutes = 0,
    this.averageUnderstanding = '',
    this.averageQuizScore,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String courseVersionId;
  final int runNumber;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String currentChapterId;
  final String currentLessonId;
  final int completedLessonCount;
  final int totalLessonCount;
  final int? progress;
  final int totalStudyMinutes;
  final String averageUnderstanding;
  final double? averageQuizScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudyLearningRun.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyLearningRun(
      id: doc.id,
      courseId: _str(d['courseId']),
      courseVersionId: _str(d['courseVersionId']),
      runNumber: (d['runNumber'] as num?)?.toInt() ?? 1,
      status: _str(d['status'], StudyLearningRunStatus.notStarted),
      startedAt: _ts(d['startedAt']),
      completedAt: _ts(d['completedAt']),
      currentChapterId: _str(d['currentChapterId']),
      currentLessonId: _str(d['currentLessonId']),
      completedLessonCount: (d['completedLessonCount'] as num?)?.toInt() ?? 0,
      totalLessonCount: (d['totalLessonCount'] as num?)?.toInt() ?? 0,
      progress: (d['progress'] as num?)?.toInt(),
      totalStudyMinutes: (d['totalStudyMinutes'] as num?)?.toInt() ?? 0,
      averageUnderstanding: _str(d['averageUnderstanding']),
      averageQuizScore: (d['averageQuizScore'] as num?)?.toDouble(),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'courseVersionId': courseVersionId,
    'runNumber': runNumber,
    'status': status,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'currentChapterId': currentChapterId,
    'currentLessonId': currentLessonId,
    'completedLessonCount': completedLessonCount,
    'totalLessonCount': totalLessonCount,
    'progress': progress,
    'totalStudyMinutes': totalStudyMinutes,
    'averageUnderstanding': averageUnderstanding,
    'averageQuizScore': averageQuizScore,
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyLessonProgress {
  const StudyLessonProgress({
    required this.id,
    required this.learningRunId,
    required this.courseId,
    required this.lessonId,
    this.chapterId = '',
    this.status = StudyLessonStatus.ready,
    this.startedAt,
    this.completedAt,
    this.studyMinutes = 0,
    this.understandingLevel = StudyUnderstanding.notRated,
    this.needsReview = false,
    this.quizScore,
    this.attemptCount = 0,
    this.lastStudiedAt,
    this.nextAction = '',
    this.isCompleted = false,
  });

  final String id;
  final String learningRunId;
  final String courseId;
  final String chapterId;
  final String lessonId;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int studyMinutes;
  final String understandingLevel;
  final bool needsReview;
  final int? quizScore;
  final int attemptCount;
  final DateTime? lastStudiedAt;
  final String nextAction;
  final bool isCompleted;

  factory StudyLessonProgress.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return StudyLessonProgress(
      id: doc.id,
      learningRunId: _str(d['learningRunId']),
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      lessonId: _str(d['lessonId']),
      status: _str(d['status'], StudyLessonStatus.ready),
      startedAt: _ts(d['startedAt']),
      completedAt: _ts(d['completedAt']),
      studyMinutes: (d['studyMinutes'] as num?)?.toInt() ?? 0,
      understandingLevel: _str(
        d['understandingLevel'],
        StudyUnderstanding.notRated,
      ),
      needsReview: d['needsReview'] == true,
      quizScore: (d['quizScore'] as num?)?.toInt(),
      attemptCount: (d['attemptCount'] as num?)?.toInt() ?? 0,
      lastStudiedAt: _ts(d['lastStudiedAt']),
      nextAction: _str(d['nextAction']),
      isCompleted: d['isCompleted'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'learningRunId': learningRunId,
    'courseId': courseId,
    'chapterId': chapterId,
    'lessonId': lessonId,
    'status': status,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'studyMinutes': studyMinutes,
    'understandingLevel': understandingLevel,
    'needsReview': needsReview,
    'quizScore': quizScore,
    'attemptCount': attemptCount,
    'lastStudiedAt': lastStudiedAt == null
        ? null
        : Timestamp.fromDate(lastStudiedAt!),
    'nextAction': nextAction,
    'isCompleted': isCompleted,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class StudyGenerationJob {
  const StudyGenerationJob({
    required this.id,
    required this.courseId,
    this.courseVersionId = '',
    this.jobType = 'outline_and_lessons',
    this.status = StudyJobStatus.draft,
    this.requestedLessonCount = 30,
    this.completedLessonCount = 0,
    this.failedLessonCount = 0,
    this.passedValidationCount = 0,
    this.needsReviewCount = 0,
    this.currentItemId = '',
    this.progress,
    this.generationSettings = const {},
    this.interestField = '',
    this.learningGoal = '',
    this.currentLevel = '',
    this.targetLevel = '',
    this.lastError = '',
    this.createdBy = '',
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String courseVersionId;
  final String jobType;
  final String status;
  final int requestedLessonCount;
  final int completedLessonCount;
  final int failedLessonCount;
  final int passedValidationCount;
  final int needsReviewCount;
  final String currentItemId;
  final int? progress;
  final Map<String, dynamic> generationSettings;
  final String interestField;
  final String learningGoal;
  final String currentLevel;
  final String targetLevel;
  final String lastError;
  final String createdBy;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudyGenerationJob.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return StudyGenerationJob(
      id: doc.id,
      courseId: _str(d['courseId']),
      courseVersionId: _str(d['courseVersionId']),
      jobType: _str(d['jobType'], 'outline_and_lessons'),
      status: _str(d['status'], StudyJobStatus.draft),
      requestedLessonCount: (d['requestedLessonCount'] as num?)?.toInt() ?? 30,
      completedLessonCount: (d['completedLessonCount'] as num?)?.toInt() ?? 0,
      failedLessonCount: (d['failedLessonCount'] as num?)?.toInt() ?? 0,
      passedValidationCount: (d['passedValidationCount'] as num?)?.toInt() ?? 0,
      needsReviewCount: (d['needsReviewCount'] as num?)?.toInt() ?? 0,
      currentItemId: _str(d['currentItemId']),
      progress: (d['progress'] as num?)?.toInt(),
      generationSettings: Map<String, dynamic>.from(
        (d['generationSettings'] as Map?) ?? const {},
      ),
      interestField: _str(d['interestField']),
      learningGoal: _str(d['learningGoal']),
      currentLevel: _str(d['currentLevel']),
      targetLevel: _str(d['targetLevel']),
      lastError: _str(d['lastError']),
      createdBy: _str(d['createdBy']),
      startedAt: _ts(d['startedAt']),
      completedAt: _ts(d['completedAt']),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'courseVersionId': courseVersionId,
    'jobType': jobType,
    'status': status,
    'requestedLessonCount': requestedLessonCount,
    'completedLessonCount': completedLessonCount,
    'failedLessonCount': failedLessonCount,
    'passedValidationCount': passedValidationCount,
    'needsReviewCount': needsReviewCount,
    'currentItemId': currentItemId,
    'progress': progress,
    'generationSettings': generationSettings,
    'interestField': interestField,
    'learningGoal': learningGoal,
    'currentLevel': currentLevel,
    'targetLevel': targetLevel,
    'lastError': lastError,
    'createdBy': createdBy,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyAiMessage {
  const StudyAiMessage({
    required this.id,
    required this.courseId,
    required this.role,
    required this.content,
    this.lessonId = '',
    this.chapterId = '',
    this.learningRunId = '',
    this.mode = StudyAiLessonMode.basic,
    this.source = 'user',
    this.createdAt,
  });

  final String id;
  final String courseId;
  final String lessonId;
  final String chapterId;
  final String learningRunId;
  final String role;
  final String content;
  final String mode;
  final String source;
  final DateTime? createdAt;

  factory StudyAiMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyAiMessage(
      id: doc.id,
      courseId: _str(d['courseId']),
      lessonId: _str(d['lessonId']),
      chapterId: _str(d['chapterId']),
      learningRunId: _str(d['learningRunId']),
      role: _str(d['role'], 'user'),
      content: _str(d['content']),
      mode: _str(d['mode'], StudyAiLessonMode.basic),
      source: _str(d['source'], 'user'),
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'lessonId': lessonId,
    'chapterId': chapterId,
    'learningRunId': learningRunId,
    'role': role,
    'content': content,
    'mode': mode,
    'source': source,
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

/// 관심분야 입력 → 생성 요청 (AI 호출 전 저장용)
class StudyCourseGenerationRequest {
  const StudyCourseGenerationRequest({
    required this.interestField,
    this.courseTitle = '',
    this.learningGoal = '',
    this.currentLevel = '',
    this.targetLevel = '',
    this.difficulty = StudyDifficulty.beginner,
    this.requestedLessonCount = 30,
    this.studyPeriod = '',
    this.weeklyHours = '',
    this.theoryPracticeRatio = '40/60',
    this.includeTopics = '',
    this.excludeTopics = '',
    this.finalDeliverable = '',
    this.relatedBusinessUnitId = '',
    this.relatedProjectId = '',
    this.references = '',
    this.memo = '',
  });

  final String interestField;
  final String courseTitle;
  final String learningGoal;
  final String currentLevel;
  final String targetLevel;
  final String difficulty;
  final int requestedLessonCount;
  final String studyPeriod;
  final String weeklyHours;
  final String theoryPracticeRatio;
  final String includeTopics;
  final String excludeTopics;
  final String finalDeliverable;
  final String relatedBusinessUnitId;
  final String relatedProjectId;
  final String references;
  final String memo;

  Map<String, dynamic> toSettingsMap() => {
    'interestField': interestField,
    'courseTitle': courseTitle,
    'learningGoal': learningGoal,
    'currentLevel': currentLevel,
    'targetLevel': targetLevel,
    'difficulty': difficulty,
    'requestedLessonCount': requestedLessonCount,
    'studyPeriod': studyPeriod,
    'weeklyHours': weeklyHours,
    'theoryPracticeRatio': theoryPracticeRatio,
    'includeTopics': includeTopics,
    'excludeTopics': excludeTopics,
    'finalDeliverable': finalDeliverable,
    'relatedBusinessUnitId': relatedBusinessUnitId,
    'relatedProjectId': relatedProjectId,
    'references': references,
    'memo': memo,
  };
}
