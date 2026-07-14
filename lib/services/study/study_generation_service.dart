import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/ops_models.dart';
import '../../models/study/study_enums.dart';
import '../../models/study/study_generation_enums.dart';
import '../../models/study/study_generation_models.dart';
import '../../models/study/study_models.dart';
import 'study_ai_providers.dart';
import 'study_generation_logic.dart';
import 'study_repository.dart';

/// 강의 생성·버전·수강회차 오케스트레이션
class StudyGenerationService {
  StudyGenerationService({
    StudyRepository? repository,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    StudyAiProvider? aiProvider,
    StudyCourseGenerator? courseGenerator,
    StudyLessonGenerator? lessonGenerator,
  }) : _repo = repository ?? StudyRepository(db: db, auth: auth),
       _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _aiProvider = aiProvider ?? DisconnectedStudyAiProvider(),
       _courseGenerator = courseGenerator ?? DisconnectedStudyCourseGenerator(),
       _lessonGenerator = lessonGenerator ?? DisconnectedStudyLessonGenerator();

  final StudyRepository _repo;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final StudyAiProvider _aiProvider;
  final StudyCourseGenerator _courseGenerator;
  final StudyLessonGenerator _lessonGenerator;

  StudyAiProvider get aiProvider => _aiProvider;
  bool get isAiConnected => _aiProvider.isConnected;

  CollectionReference<Map<String, dynamic>> get _lessons =>
      _db.collection('study_lessons');
  CollectionReference<Map<String, dynamic>> get _versions =>
      _db.collection('study_course_versions');
  CollectionReference<Map<String, dynamic>> get _runs =>
      _db.collection('study_learning_runs');
  CollectionReference<Map<String, dynamic>> get _lessonProgress =>
      _db.collection('study_lesson_progress');
  CollectionReference<Map<String, dynamic>> get _jobs =>
      _db.collection('study_generation_jobs');
  CollectionReference<Map<String, dynamic>> get _aiMessages =>
      _db.collection('study_ai_messages');
  CollectionReference<Map<String, dynamic>> get _usage =>
      _db.collection('study_ai_usage');
  CollectionReference<Map<String, dynamic>> get _activity =>
      _db.collection('activity_logs');

  Future<void> _log(String summary, {String collection = 'study'}) async {
    final u = _auth.currentUser;
    await _activity.add(
      ActivityLogDoc(
        id: '',
        action: 'study_generation',
        collection: collection,
        documentId: '',
        summary: summary,
        actorUid: u?.uid ?? '',
        actorEmail: u?.email ?? '',
      ).toMap(),
    );
  }

  // —— lessons ——
  Stream<List<StudyLesson>> watchLessons(String courseId) {
    return _lessons.where('courseId', isEqualTo: courseId).snapshots().map((s) {
      final list = s.docs.map(StudyLesson.fromDoc).toList()
        ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
      return list;
    });
  }

  Stream<StudyLesson?> watchLesson(String id) {
    return _lessons.doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return StudyLesson.fromDoc(d);
    });
  }

  Future<List<StudyLesson>> fetchLessons(String courseId) async {
    final s = await _lessons.where('courseId', isEqualTo: courseId).get();
    final list = s.docs.map(StudyLesson.fromDoc).toList()
      ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
    return list;
  }

  Future<String> upsertLesson(StudyLesson lesson, {bool isNew = false}) async {
    final ref = lesson.id.isEmpty ? _lessons.doc() : _lessons.doc(lesson.id);
    await ref.set(
      lesson.toMap(includeCreated: isNew || lesson.id.isEmpty),
      SetOptions(merge: true),
    );
    await _log('개별 강의 저장: ${lesson.title}', collection: 'study_lessons');
    return ref.id;
  }

  Future<void> deleteLesson(String id) async {
    await _lessons.doc(id).delete();
  }

  // —— jobs ——
  Stream<List<StudyGenerationJob>> watchJobs({String? courseId}) {
    Query<Map<String, dynamic>> q = _jobs;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map((s) {
      final list = s.docs.map(StudyGenerationJob.fromDoc).toList()
        ..sort((a, b) {
          final aa = a.createdAt ?? DateTime(1970);
          final bb = b.createdAt ?? DateTime(1970);
          return bb.compareTo(aa);
        });
      return list;
    });
  }

  Stream<StudyGenerationJob?> watchJob(String id) {
    return _jobs.doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return StudyGenerationJob.fromDoc(d);
    });
  }

  /// 관심분야 입력 저장 — AI 미연결 시 조건만 저장
  Future<String> createGenerationRequest({
    required StudyCourseGenerationRequest request,
    String? existingCourseId,
  }) async {
    final lessonCount = request.requestedLessonCount < 30
        ? 30
        : request.requestedLessonCount;

    String courseId = existingCourseId ?? '';
    if (courseId.isEmpty) {
      final title = request.courseTitle.trim().isEmpty
          ? '${request.interestField.trim()} 과정'
          : request.courseTitle.trim();
      courseId = await _repo.upsertCourse(
        StudyCourse(
          id: '',
          title: title,
          category: request.interestField.trim(),
          description: request.learningGoal,
          learningGoal: request.learningGoal,
          targetLevel: request.targetLevel,
          difficulty: request.difficulty,
          status: StudyCourseStatus.draft,
          relatedBusinessUnitId: request.relatedBusinessUnitId,
          relatedProjectId: request.relatedProjectId,
          estimatedChapterCount: 0,
          nextAction: 'AI 강의 생성 요청 검토',
          tags: request.interestField.trim().isEmpty
              ? const []
              : [request.interestField.trim()],
          referenceLinks: request.references
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
        isNew: true,
      );
    }

    final versionRef = _versions.doc();
    await versionRef.set({
      'courseId': courseId,
      'versionNumber': 1,
      'title': request.courseTitle.isEmpty
          ? '${request.interestField} 과정'
          : request.courseTitle,
      'description': request.learningGoal,
      'generationPrompt': request.memo,
      'generationSettings': request.toSettingsMap(),
      'chapterCount': 0,
      'lessonCount': lessonCount,
      'status': StudyGenerationStatus.draft,
      'isPublished': false,
      'previousVersionId': '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final jobRef = _jobs.doc();
    final job = StudyGenerationJob(
      id: jobRef.id,
      courseId: courseId,
      courseVersionId: versionRef.id,
      jobType: 'outline_and_lessons',
      status: StudyJobStatus.waitingApproval,
      requestedLessonCount: lessonCount,
      generationSettings: request.toSettingsMap(),
      interestField: request.interestField,
      learningGoal: request.learningGoal,
      currentLevel: request.currentLevel,
      targetLevel: request.targetLevel,
      createdBy: _auth.currentUser?.uid ?? '',
      lastError: isAiConnected
          ? ''
          : 'AI 미연결 — 조건만 저장됨. 빈 목차 골격은 관리자가 수동 생성할 수 있습니다.',
    );
    await jobRef.set(job.toMap(includeCreated: true), SetOptions(merge: true));

    await _usage.add({
      'courseId': courseId,
      'jobId': jobRef.id,
      'requestedLessonCount': lessonCount,
      'estimatedAiRequests': lessonCount + 1,
      'actualRequests': 0,
      'costLabel': '비용 미설정',
      'providerConnected': isAiConnected,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _log(
      'AI 강의 생성 요청 저장: ${request.interestField} ($lessonCount강)',
      collection: 'study_generation_jobs',
    );
    return jobRef.id;
  }

  Future<void> updateJobStatus(
    String jobId,
    String status, {
    String? error,
  }) async {
    await _jobs.doc(jobId).set({
      'status': status,
      if (error != null) 'lastError': error,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> approveJob(String jobId) async {
    await _jobs.doc(jobId).set({
      'status': StudyJobStatus.queued,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final jobSnap = await _jobs.doc(jobId).get();
    final versionId = '${jobSnap.data()?['courseVersionId'] ?? ''}';
    if (versionId.isNotEmpty) {
      await _versions.doc(versionId).set({
        'status': StudyGenerationStatus.approved,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid ?? '',
      }, SetOptions(merge: true));
    }
    await _log('생성 작업 승인: $jobId');
  }

  Future<void> pauseJob(String jobId) async {
    await updateJobStatus(jobId, StudyJobStatus.paused);
  }

  Future<void> resumeJob(String jobId) async {
    await updateJobStatus(jobId, StudyJobStatus.queued);
  }

  Future<void> cancelJob(String jobId) async {
    await updateJobStatus(jobId, StudyJobStatus.cancelled);
  }

  /// AI 목차 생성 시도 — 미연결이면 예외
  Future<OutlineScaffoldResult> requestAiOutline(
    StudyCourseGenerationRequest request,
  ) {
    return _courseGenerator.generateOutline(request);
  }

  /// 관리자 명시 액션: 빈 목차 골격 생성 (AI 본문 아님, Mock 완료 강의 아님)
  Future<String> createEmptyOutlineScaffold({
    required String courseId,
    required String jobId,
    required String interestField,
    required int lessonCount,
    String difficulty = StudyDifficulty.beginner,
    String? versionId,
    bool allowDuplicate = false,
  }) async {
    final existingLessons = await fetchLessons(courseId);
    if (existingLessons.isNotEmpty && !allowDuplicate) {
      throw StateError(
        '이미 ${existingLessons.length}개 강의가 있습니다. '
        '중복 골격을 만들려면 새 버전으로 재생성하십시오.',
      );
    }

    final outline = StudyOutlineScaffoldBuilder.build(
      interestField: interestField,
      requestedLessonCount: lessonCount < 30 ? 30 : lessonCount,
      difficulty: difficulty,
    );

    String courseVersionId = versionId ?? '';
    if (courseVersionId.isEmpty) {
      final versions = await _versions
          .where('courseId', isEqualTo: courseId)
          .get();
      final nums = versions.docs
          .map((d) => (d.data()['versionNumber'] as num?)?.toInt() ?? 0)
          .toList();
      final next = nums.isEmpty ? 1 : nums.reduce((a, b) => a > b ? a : b) + 1;
      final prev = versions.docs.isEmpty
          ? ''
          : versions.docs.map((d) => d.id).first;
      final vRef = _versions.doc();
      await vRef.set({
        'courseId': courseId,
        'versionNumber': next,
        'title': outline.title,
        'description': outline.description,
        'generationSettings': {'scaffold': true, 'ai': false},
        'chapterCount': outline.chapterCount,
        'lessonCount': outline.lessonCount,
        'status': StudyGenerationStatus.reviewing,
        'isPublished': false,
        'previousVersionId': prev,
        'createdAt': FieldValue.serverTimestamp(),
      });
      courseVersionId = vRef.id;
    } else {
      await _versions.doc(courseVersionId).set({
        'chapterCount': outline.chapterCount,
        'lessonCount': outline.lessonCount,
        'status': StudyGenerationStatus.reviewing,
        'title': outline.title,
        'description': outline.description,
      }, SetOptions(merge: true));
    }

    // 기존 초안 강의가 있으면 번호 충돌 방지: 이번 골격만 추가하지 않고 job 범위로 기록
    final batch = _db.batch();
    var written = 0;
    for (final ch in outline.chapters) {
      final chRef = _db.collection('study_chapters').doc();
      batch.set(chRef, {
        'courseId': courseId,
        'title': ch.title,
        'description': ch.description,
        'chapterNumber': ch.chapterNumber,
        'displayOrder': ch.displayOrder,
        'status': StudyChapterStatus.draft,
        'isPublished': false,
        'estimatedMinutes': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final les in ch.lessons) {
        final lRef = _lessons.doc();
        batch.set(lRef, {
          'courseId': courseId,
          'courseVersionId': courseVersionId,
          'chapterId': chRef.id,
          'lessonNumber': les.lessonNumber,
          'title': les.title,
          'description': les.description,
          'difficulty': les.difficulty,
          'lessonType': les.lessonType,
          'status': StudyLessonStatus.draft,
          'displayOrder': les.displayOrder,
          'isPublished': false,
          'generationStatus': StudyGenerationStatus.draft,
          'validationStatus': StudyValidationStatus.needsReview,
          'completionPolicy': StudyCompletionPolicy.contentOnly,
          'learningObjectives': <String>[],
          'contentBlocks': <Map>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        written++;
      }
    }
    await batch.commit();

    final pct = StudyGenerationJobCalculator.progressPercent(
      requested: outline.lessonCount,
      completed: 0,
    );
    await _jobs.doc(jobId).set({
      'status': StudyJobStatus.waitingApproval,
      'courseVersionId': courseVersionId,
      'requestedLessonCount': outline.lessonCount,
      'completedLessonCount': 0,
      'progress': pct,
      'lastError':
          '빈 목차 골격 $written강 생성됨 (AI 본문 아님). 제목·본문은 검토 후 입력하거나 AI 연결 후 생성하십시오.',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('study_courses').doc(courseId).set({
      'title': outline.title,
      'category': interestField,
      'description': outline.description,
      'estimatedChapterCount': outline.chapterCount,
      'chapterCount': outline.chapterCount,
      'nextAction': '목차 검토 및 승인',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _log('빈 목차 골격 생성: $written강', collection: 'study_lessons');
    return courseVersionId;
  }

  /// AI 본문 생성 시작 — 미연결이면 상태만 기록
  Future<void> startLessonBodyGeneration(String jobId) async {
    if (!isAiConnected) {
      await updateJobStatus(
        jobId,
        StudyJobStatus.paused,
        error: 'AI 강의 자동 생성 기능은 아직 연결되지 않았습니다. 본문 자동 생성을 시작할 수 없습니다.',
      );
      return;
    }
    await updateJobStatus(jobId, StudyJobStatus.running);
    // 실제 공급자 연결 시 배치 생성 루프를 여기에 연결
  }

  Future<StudyLesson> generateSingleLessonBody({
    required StudyLesson outline,
    required StudyCourseGenerationRequest request,
  }) {
    return _lessonGenerator.generateLessonBody(
      outlineLesson: outline,
      request: request,
    );
  }

  // —— versions ——
  Stream<List<StudyCourseVersion>> watchVersions(String courseId) {
    return _versions.where('courseId', isEqualTo: courseId).snapshots().map((
      s,
    ) {
      final list = s.docs.map(StudyCourseVersion.fromDoc).toList()
        ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
      return list;
    });
  }

  Future<String> createNewVersionPreservingOld({
    required String courseId,
    required String reason,
    Map<String, dynamic> settings = const {},
  }) async {
    final versions = await _versions
        .where('courseId', isEqualTo: courseId)
        .get();
    final nums = versions.docs
        .map((d) => (d.data()['versionNumber'] as num?)?.toInt() ?? 0)
        .toList();
    final next = nums.isEmpty ? 1 : nums.reduce((a, b) => a > b ? a : b) + 1;
    String previousId = '';
    for (final d in versions.docs) {
      if (d.data()['isPublished'] == true) {
        previousId = d.id;
        break;
      }
    }
    if (previousId.isEmpty && versions.docs.isNotEmpty) {
      previousId = versions.docs.first.id;
    }
    final ref = _versions.doc();
    await ref.set({
      'courseId': courseId,
      'versionNumber': next,
      'title': '버전 $next',
      'description': reason,
      'generationSettings': settings,
      'chapterCount': 0,
      'lessonCount': 0,
      'status': StudyGenerationStatus.draft,
      'isPublished': false,
      'previousVersionId': previousId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _log('새 강의 버전 생성: v$next (이전 보존)');
    return ref.id;
  }

  // —— learning runs ——
  Stream<List<StudyLearningRun>> watchLearningRuns(String courseId) {
    return _runs.where('courseId', isEqualTo: courseId).snapshots().map((s) {
      final list = s.docs.map(StudyLearningRun.fromDoc).toList()
        ..sort((a, b) => b.runNumber.compareTo(a.runNumber));
      return list;
    });
  }

  Future<StudyLearningRun?> getActiveRun(String courseId) async {
    final s = await _runs.where('courseId', isEqualTo: courseId).get();
    final list = s.docs.map(StudyLearningRun.fromDoc).toList()
      ..sort((a, b) => b.runNumber.compareTo(a.runNumber));
    for (final r in list) {
      if (r.status == StudyLearningRunStatus.inProgress ||
          r.status == StudyLearningRunStatus.notStarted ||
          r.status == StudyLearningRunStatus.paused) {
        return r;
      }
    }
    return list.isEmpty ? null : list.first;
  }

  Future<String> ensureFirstLearningRun({
    required String courseId,
    String courseVersionId = '',
    int totalLessonCount = 0,
  }) async {
    final existing = await _runs.where('courseId', isEqualTo: courseId).get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }
    return startNewLearningRun(
      courseId: courseId,
      courseVersionId: courseVersionId,
      totalLessonCount: totalLessonCount,
    );
  }

  /// 새 수강회차 — 기존 회차 보존, 진도 0%
  Future<String> startNewLearningRun({
    required String courseId,
    String courseVersionId = '',
    int totalLessonCount = 0,
  }) async {
    final existing = await _runs.where('courseId', isEqualTo: courseId).get();
    final maxRun = existing.docs.fold<int>(
      0,
      (m, d) => ((d.data()['runNumber'] as num?)?.toInt() ?? 0) > m
          ? (d.data()['runNumber'] as num).toInt()
          : m,
    );
    // 기존 in_progress → paused (삭제하지 않음)
    final batch = _db.batch();
    for (final d in existing.docs) {
      final st = '${d.data()['status'] ?? ''}';
      if (st == StudyLearningRunStatus.inProgress) {
        batch.set(d.reference, {
          'status': StudyLearningRunStatus.paused,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    final ref = _runs.doc();
    batch.set(ref, {
      'courseId': courseId,
      'courseVersionId': courseVersionId,
      'runNumber': maxRun + 1,
      'status': StudyLearningRunStatus.inProgress,
      'startedAt': FieldValue.serverTimestamp(),
      'completedLessonCount': 0,
      'totalLessonCount': totalLessonCount,
      'progress': 0,
      'totalStudyMinutes': 0,
      'averageUnderstanding': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _log(
      '새 학습 회차 시작: ${maxRun + 1}회차',
      collection: 'study_learning_runs',
    );
    return ref.id;
  }

  Stream<List<StudyLessonProgress>> watchLessonProgress({
    required String learningRunId,
  }) {
    return _lessonProgress
        .where('learningRunId', isEqualTo: learningRunId)
        .snapshots()
        .map((s) => s.docs.map(StudyLessonProgress.fromDoc).toList());
  }

  Future<void> upsertLessonProgress(StudyLessonProgress p) async {
    final id = p.id.isEmpty ? '${p.learningRunId}_${p.lessonId}' : p.id;
    await _lessonProgress.doc(id).set({
      ...p.toMap(),
      if (p.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markLessonComplete({
    required String learningRunId,
    required StudyLesson lesson,
    String understanding = StudyUnderstanding.notRated,
    int studyMinutes = 0,
  }) async {
    await upsertLessonProgress(
      StudyLessonProgress(
        id: '${learningRunId}_${lesson.id}',
        learningRunId: learningRunId,
        courseId: lesson.courseId,
        chapterId: lesson.chapterId,
        lessonId: lesson.id,
        status: StudyLessonStatus.completed,
        isCompleted: true,
        completedAt: DateTime.now(),
        lastStudiedAt: DateTime.now(),
        understandingLevel: understanding,
        studyMinutes: studyMinutes,
        attemptCount: 1,
      ),
    );
    final progressList = await _lessonProgress
        .where('learningRunId', isEqualTo: learningRunId)
        .get();
    final done = progressList.docs
        .where((d) => d.data()['isCompleted'] == true)
        .length;
    final runSnap = await _runs.doc(learningRunId).get();
    final total = (runSnap.data()?['totalLessonCount'] as num?)?.toInt() ?? 0;
    final pct = total <= 0
        ? null
        : ((done / total) * 100).round().clamp(0, 100);
    await _runs.doc(learningRunId).set({
      'completedLessonCount': done,
      'progress': pct ?? 0,
      'currentLessonId': lesson.id,
      'currentChapterId': lesson.chapterId,
      'status': StudyLearningRunStatus.inProgress,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 현재 회차 복습 — 완료 유지, 시도 횟수 증가
  Future<void> recordReviewAttempt({
    required String learningRunId,
    required String lessonId,
    int addedMinutes = 0,
  }) async {
    final id = '${learningRunId}_$lessonId';
    final snap = await _lessonProgress.doc(id).get();
    final prev = snap.data() ?? {};
    await _lessonProgress.doc(id).set({
      ...prev,
      'learningRunId': learningRunId,
      'lessonId': lessonId,
      'attemptCount': ((prev['attemptCount'] as num?)?.toInt() ?? 0) + 1,
      'studyMinutes':
          ((prev['studyMinutes'] as num?)?.toInt() ?? 0) + addedMinutes,
      'needsReview': true,
      'lastStudiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> saveAiMessage(StudyAiMessage msg) async {
    final ref = _aiMessages.doc();
    await ref.set(msg.toMap(includeCreated: true));
    return ref.id;
  }

  Stream<List<StudyAiMessage>> watchAiMessages({
    required String courseId,
    String? lessonId,
  }) {
    Query<Map<String, dynamic>> q = _aiMessages.where(
      'courseId',
      isEqualTo: courseId,
    );
    if (lessonId != null && lessonId.isNotEmpty) {
      q = q.where('lessonId', isEqualTo: lessonId);
    }
    return q.snapshots().map((s) {
      final list = s.docs.map(StudyAiMessage.fromDoc).toList()
        ..sort((a, b) {
          final aa = a.createdAt ?? DateTime(1970);
          final bb = b.createdAt ?? DateTime(1970);
          return aa.compareTo(bb);
        });
      return list;
    });
  }
}
