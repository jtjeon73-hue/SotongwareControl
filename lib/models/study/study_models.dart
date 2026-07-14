import 'package:cloud_firestore/cloud_firestore.dart';

import 'study_enums.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _str(dynamic v, [String d = '']) =>
    (v is String ? v : v?.toString() ?? d).trim();

class StudyCourse {
  const StudyCourse({
    required this.id,
    required this.title,
    this.category = '',
    this.description = '',
    this.learningGoal = '',
    this.targetLevel = '',
    this.difficulty = StudyDifficulty.beginner,
    this.status = StudyCourseStatus.draft,
    this.imageUrl = '',
    this.iconName = 'school',
    this.isFavorite = false,
    this.relatedBusinessUnitId = '',
    this.relatedProjectId = '',
    this.estimatedChapterCount = 0,
    this.chapterCount = 0,
    this.completedChapterCount = 0,
    this.progress,
    this.nextAction = '',
    this.tags = const [],
    this.referenceLinks = const [],
    this.startedAt,
    this.targetDate,
    this.lastStudiedAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String learningGoal;
  final String targetLevel;
  final String difficulty;
  final String status;
  final String imageUrl;
  final String iconName;
  final bool isFavorite;
  final String relatedBusinessUnitId;
  final String relatedProjectId;
  final int estimatedChapterCount;
  final int chapterCount;
  final int completedChapterCount;
  final int? progress;
  final String nextAction;
  final List<String> tags;
  final List<String> referenceLinks;
  final DateTime? startedAt;
  final DateTime? targetDate;
  final DateTime? lastStudiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  factory StudyCourse.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyCourse(
      id: doc.id,
      title: _str(d['title'], doc.id),
      category: _str(d['category']),
      description: _str(d['description']),
      learningGoal: _str(d['learningGoal']),
      targetLevel: _str(d['targetLevel']),
      difficulty: _str(d['difficulty'], StudyDifficulty.beginner),
      status: _str(d['status'], StudyCourseStatus.draft),
      imageUrl: _str(d['imageUrl']),
      iconName: _str(d['iconName'], 'school'),
      isFavorite: d['isFavorite'] == true,
      relatedBusinessUnitId: _str(d['relatedBusinessUnitId']),
      relatedProjectId: _str(d['relatedProjectId']),
      estimatedChapterCount: (d['estimatedChapterCount'] as num?)?.toInt() ?? 0,
      chapterCount: (d['chapterCount'] as num?)?.toInt() ?? 0,
      completedChapterCount: (d['completedChapterCount'] as num?)?.toInt() ?? 0,
      progress: (d['progress'] as num?)?.toInt(),
      nextAction: _str(d['nextAction']),
      tags: ((d['tags'] as List?) ?? const []).map((e) => '$e').toList(),
      referenceLinks: ((d['referenceLinks'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      startedAt: _ts(d['startedAt']),
      targetDate: _ts(d['targetDate']),
      lastStudiedAt: _ts(d['lastStudiedAt']),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
      createdBy: _str(d['createdBy']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'title': title,
    'category': category,
    'description': description,
    'learningGoal': learningGoal,
    'targetLevel': targetLevel,
    'difficulty': difficulty,
    'status': status,
    'imageUrl': imageUrl,
    'iconName': iconName,
    'isFavorite': isFavorite,
    'relatedBusinessUnitId': relatedBusinessUnitId,
    'relatedProjectId': relatedProjectId,
    'estimatedChapterCount': estimatedChapterCount,
    'chapterCount': chapterCount,
    'completedChapterCount': completedChapterCount,
    'progress': progress,
    'nextAction': nextAction,
    'tags': tags,
    'referenceLinks': referenceLinks,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
    'lastStudiedAt': lastStudiedAt == null
        ? null
        : Timestamp.fromDate(lastStudiedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    'createdBy': createdBy,
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyChapter {
  const StudyChapter({
    required this.id,
    required this.courseId,
    required this.title,
    this.chapterNumber = 1,
    this.description = '',
    this.learningObjectives = const [],
    this.estimatedMinutes = 0,
    this.difficulty = StudyDifficulty.beginner,
    this.status = StudyChapterStatus.draft,
    this.prerequisiteChapterIds = const [],
    this.displayOrder = 0,
    this.isPublished = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String title;
  final int chapterNumber;
  final String description;
  final List<String> learningObjectives;
  final int estimatedMinutes;
  final String difficulty;
  final String status;
  final List<String> prerequisiteChapterIds;
  final int displayOrder;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 진도 계산에 포함할지 (초안 제외)
  bool get countsTowardProgress =>
      status != StudyChapterStatus.draft && isPublished;

  factory StudyChapter.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyChapter(
      id: doc.id,
      courseId: _str(d['courseId']),
      title: _str(d['title'], doc.id),
      chapterNumber: (d['chapterNumber'] as num?)?.toInt() ?? 1,
      description: _str(d['description']),
      learningObjectives: ((d['learningObjectives'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 0,
      difficulty: _str(d['difficulty'], StudyDifficulty.beginner),
      status: _str(d['status'], StudyChapterStatus.draft),
      prerequisiteChapterIds:
          ((d['prerequisiteChapterIds'] as List?) ?? const [])
              .map((e) => '$e')
              .toList(),
      displayOrder: (d['displayOrder'] as num?)?.toInt() ?? 0,
      isPublished: d['isPublished'] == true,
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'title': title,
    'chapterNumber': chapterNumber,
    'description': description,
    'learningObjectives': learningObjectives,
    'estimatedMinutes': estimatedMinutes,
    'difficulty': difficulty,
    'status': status,
    'prerequisiteChapterIds': prerequisiteChapterIds,
    'displayOrder': displayOrder,
    'isPublished': isPublished,
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyContentBlock {
  const StudyContentBlock({
    required this.id,
    required this.chapterId,
    required this.type,
    this.courseId = '',
    this.title = '',
    this.content = '',
    this.language = '',
    this.code = '',
    this.description = '',
    this.url = '',
    this.source = '',
    this.displayOrder = 0,
    this.checkedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String chapterId;
  final String courseId;
  final String type;
  final String title;
  final String content;
  final String language;
  final String code;
  final String description;
  final String url;
  final String source;
  final int displayOrder;
  final DateTime? checkedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudyContentBlock.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return StudyContentBlock(
      id: doc.id,
      chapterId: _str(d['chapterId']),
      courseId: _str(d['courseId']),
      type: _str(d['type'], StudyContentBlockType.paragraph),
      title: _str(d['title']),
      content: _str(d['content']),
      language: _str(d['language']),
      code: _str(d['code']),
      description: _str(d['description']),
      url: _str(d['url']),
      source: _str(d['source']),
      displayOrder: (d['displayOrder'] as num?)?.toInt() ?? 0,
      checkedAt: _ts(d['checkedAt']),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'chapterId': chapterId,
    'courseId': courseId,
    'type': type,
    'title': title,
    'content': content,
    'language': language,
    'code': code,
    'description': description,
    'url': url,
    'source': source,
    'displayOrder': displayOrder,
    'checkedAt': checkedAt == null ? null : Timestamp.fromDate(checkedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyProgress {
  const StudyProgress({
    required this.id,
    required this.courseId,
    required this.chapterId,
    this.status = StudyChapterStatus.ready,
    this.understandingLevel = StudyUnderstanding.notRated,
    this.isCompleted = false,
    this.needsReview = false,
    this.difficultyNote = '',
    this.nextAction = '',
    this.lastStudiedAt,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String status;
  final String understandingLevel;
  final bool isCompleted;
  final bool needsReview;
  final String difficultyNote;
  final String nextAction;
  final DateTime? lastStudiedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  factory StudyProgress.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyProgress(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      status: _str(d['status'], StudyChapterStatus.ready),
      understandingLevel: _str(
        d['understandingLevel'],
        StudyUnderstanding.notRated,
      ),
      isCompleted: d['isCompleted'] == true,
      needsReview: d['needsReview'] == true,
      difficultyNote: _str(d['difficultyNote']),
      nextAction: _str(d['nextAction']),
      lastStudiedAt: _ts(d['lastStudiedAt']),
      completedAt: _ts(d['completedAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'courseId': courseId,
    'chapterId': chapterId,
    'status': status,
    'understandingLevel': understandingLevel,
    'isCompleted': isCompleted,
    'needsReview': needsReview,
    'difficultyNote': difficultyNote,
    'nextAction': nextAction,
    'lastStudiedAt': lastStudiedAt == null
        ? null
        : Timestamp.fromDate(lastStudiedAt!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class StudySession {
  const StudySession({
    required this.id,
    required this.courseId,
    required this.chapterId,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes = 0,
    this.status = StudySessionStatus.inProgress,
    this.understandingLevel = StudyUnderstanding.notRated,
    this.memo = '',
    this.createdAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMinutes;
  final String status;
  final String understandingLevel;
  final String memo;
  final DateTime? createdAt;

  factory StudySession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudySession(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      startedAt: _ts(d['startedAt']) ?? DateTime.now(),
      endedAt: _ts(d['endedAt']),
      durationMinutes: (d['durationMinutes'] as num?)?.toInt() ?? 0,
      status: _str(d['status'], StudySessionStatus.inProgress),
      understandingLevel: _str(
        d['understandingLevel'],
        StudyUnderstanding.notRated,
      ),
      memo: _str(d['memo']),
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'chapterId': chapterId,
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
    'durationMinutes': durationMinutes,
    'status': status,
    'understandingLevel': understandingLevel,
    'memo': memo,
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyNote {
  const StudyNote({
    required this.id,
    required this.courseId,
    required this.title,
    this.chapterId = '',
    this.content = '',
    this.tags = const [],
    this.isImportant = false,
    this.needsReview = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String title;
  final String content;
  final List<String> tags;
  final bool isImportant;
  final bool needsReview;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJsonExport() => {
    'id': id,
    'courseId': courseId,
    'chapterId': chapterId,
    'title': title,
    'content': content,
    'tags': tags,
    'isImportant': isImportant,
    'needsReview': needsReview,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory StudyNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyNote(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      title: _str(d['title']),
      content: _str(d['content']),
      tags: ((d['tags'] as List?) ?? const []).map((e) => '$e').toList(),
      isImportant: d['isImportant'] == true,
      needsReview: d['needsReview'] == true,
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'chapterId': chapterId,
    'title': title,
    'content': content,
    'tags': tags,
    'isImportant': isImportant,
    'needsReview': needsReview,
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyQuestion {
  const StudyQuestion({
    required this.id,
    required this.courseId,
    required this.question,
    this.chapterId = '',
    this.personalMemo = '',
    this.status = StudyQuestionStatus.open,
    this.isImportant = false,
    this.aiAnswer = '',
    this.answerSource = '',
    this.createdAt,
    this.answeredAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String question;
  final String personalMemo;
  final String status;
  final bool isImportant;
  final String aiAnswer;
  final String answerSource;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? updatedAt;

  factory StudyQuestion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyQuestion(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      question: _str(d['question']),
      personalMemo: _str(d['personalMemo']),
      status: _str(d['status'], StudyQuestionStatus.open),
      isImportant: d['isImportant'] == true,
      aiAnswer: _str(d['aiAnswer']),
      answerSource: _str(d['answerSource']),
      createdAt: _ts(d['createdAt']),
      answeredAt: _ts(d['answeredAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'chapterId': chapterId,
    'question': question,
    'personalMemo': personalMemo,
    'status': status,
    'isImportant': isImportant,
    'aiAnswer': aiAnswer,
    'answerSource': answerSource,
    'answeredAt': answeredAt == null ? null : Timestamp.fromDate(answeredAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyAssignment {
  const StudyAssignment({
    required this.id,
    required this.courseId,
    required this.title,
    this.chapterId = '',
    this.description = '',
    this.assignmentType = 'practice',
    this.difficulty = StudyDifficulty.beginner,
    this.submissionFormat = '',
    this.status = StudyAssignmentStatus.todo,
    this.userAnswer = '',
    this.attachmentUrl = '',
    this.evaluation = '',
    this.improvementNote = '',
    this.dueDate,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String title;
  final String description;
  final String assignmentType;
  final String difficulty;
  final String submissionFormat;
  final String status;
  final String userAnswer;
  final String attachmentUrl;
  final String evaluation;
  final String improvementNote;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudyAssignment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyAssignment(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      title: _str(d['title']),
      description: _str(d['description']),
      assignmentType: _str(d['assignmentType'], 'practice'),
      difficulty: _str(d['difficulty'], StudyDifficulty.beginner),
      submissionFormat: _str(d['submissionFormat']),
      status: _str(d['status'], StudyAssignmentStatus.todo),
      userAnswer: _str(d['userAnswer']),
      attachmentUrl: _str(d['attachmentUrl']),
      evaluation: _str(d['evaluation']),
      improvementNote: _str(d['improvementNote']),
      dueDate: _ts(d['dueDate']),
      completedAt: _ts(d['completedAt']),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'chapterId': chapterId,
    'title': title,
    'description': description,
    'assignmentType': assignmentType,
    'difficulty': difficulty,
    'submissionFormat': submissionFormat,
    'status': status,
    'userAnswer': userAnswer,
    'attachmentUrl': attachmentUrl,
    'evaluation': evaluation,
    'improvementNote': improvementNote,
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyQuiz {
  const StudyQuiz({
    required this.id,
    required this.courseId,
    required this.question,
    this.chapterId = '',
    this.quizType = StudyQuizType.single,
    this.choices = const [],
    this.correctAnswer = '',
    this.explanation = '',
    this.difficulty = StudyDifficulty.beginner,
    this.points = 1,
    this.source = '',
    this.generationMethod = 'manual',
    this.reviewed = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String question;
  final String quizType;
  final List<String> choices;
  final String correctAnswer;
  final String explanation;
  final String difficulty;
  final int points;
  final String source;
  final String generationMethod;
  final bool reviewed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudyQuiz.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyQuiz(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      question: _str(d['question']),
      quizType: _str(d['quizType'], StudyQuizType.single),
      choices: ((d['choices'] as List?) ?? const []).map((e) => '$e').toList(),
      correctAnswer: _str(d['correctAnswer']),
      explanation: _str(d['explanation']),
      difficulty: _str(d['difficulty'], StudyDifficulty.beginner),
      points: (d['points'] as num?)?.toInt() ?? 1,
      source: _str(d['source']),
      generationMethod: _str(d['generationMethod'], 'manual'),
      reviewed: d['reviewed'] != false,
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'chapterId': chapterId,
    'question': question,
    'quizType': quizType,
    'choices': choices,
    'correctAnswer': correctAnswer,
    'explanation': explanation,
    'difficulty': difficulty,
    'points': points,
    'source': source,
    'generationMethod': generationMethod,
    'reviewed': reviewed,
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyQuizAttempt {
  const StudyQuizAttempt({
    required this.id,
    required this.quizId,
    required this.courseId,
    this.chapterId = '',
    this.selectedAnswer = '',
    this.isCorrect = false,
    this.score = 0,
    this.wrongNote = '',
    this.needsReview = false,
    this.isRetry = false,
    this.attemptedAt,
  });

  final String id;
  final String quizId;
  final String courseId;
  final String chapterId;
  final String selectedAnswer;
  final bool isCorrect;
  final int score;
  final String wrongNote;
  final bool needsReview;
  final bool isRetry;
  final DateTime? attemptedAt;

  factory StudyQuizAttempt.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyQuizAttempt(
      id: doc.id,
      quizId: _str(d['quizId']),
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      selectedAnswer: _str(d['selectedAnswer']),
      isCorrect: d['isCorrect'] == true,
      score: (d['score'] as num?)?.toInt() ?? 0,
      wrongNote: _str(d['wrongNote']),
      needsReview: d['needsReview'] == true,
      isRetry: d['isRetry'] == true,
      attemptedAt: _ts(d['attemptedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'quizId': quizId,
    'courseId': courseId,
    'chapterId': chapterId,
    'selectedAnswer': selectedAnswer,
    'isCorrect': isCorrect,
    'score': score,
    'wrongNote': wrongNote,
    'needsReview': needsReview,
    'isRetry': isRetry,
    'attemptedAt': FieldValue.serverTimestamp(),
  };
}

class StudyReviewItem {
  const StudyReviewItem({
    required this.id,
    required this.courseId,
    this.chapterId = '',
    this.sourceType = 'manual',
    this.sourceId = '',
    this.reason = '',
    this.priority = 'normal',
    this.reviewStatus = 'pending',
    this.scheduledAt,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String sourceType;
  final String sourceId;
  final String reason;
  final String priority;
  final String reviewStatus;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  factory StudyReviewItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyReviewItem(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      sourceType: _str(d['sourceType'], 'manual'),
      sourceId: _str(d['sourceId']),
      reason: _str(d['reason']),
      priority: _str(d['priority'], 'normal'),
      reviewStatus: _str(d['reviewStatus'], 'pending'),
      scheduledAt: _ts(d['scheduledAt']),
      completedAt: _ts(d['completedAt']),
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'chapterId': chapterId,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'reason': reason,
    'priority': priority,
    'reviewStatus': reviewStatus,
    'scheduledAt': scheduledAt == null
        ? null
        : Timestamp.fromDate(scheduledAt!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class StudyGoal {
  const StudyGoal({
    required this.id,
    required this.courseId,
    this.chapterId = '',
    this.title = '',
    this.targetDate,
    this.isDone = false,
    this.createdAt,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String title;
  final DateTime? targetDate;
  final bool isDone;
  final DateTime? createdAt;

  factory StudyGoal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StudyGoal(
      id: doc.id,
      courseId: _str(d['courseId']),
      chapterId: _str(d['chapterId']),
      title: _str(d['title']),
      targetDate: _ts(d['targetDate']),
      isDone: d['isDone'] == true,
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreated = false}) => {
    'courseId': courseId,
    'chapterId': chapterId,
    'title': title,
    'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
    'isDone': isDone,
    if (includeCreated) 'createdAt': FieldValue.serverTimestamp(),
  };
}
