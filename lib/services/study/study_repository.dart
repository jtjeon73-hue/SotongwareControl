import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/ops_models.dart';
import '../../models/study/study_models.dart';

class StudyRepository {
  StudyRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _courses =>
      _db.collection('study_courses');
  CollectionReference<Map<String, dynamic>> get _chapters =>
      _db.collection('study_chapters');
  CollectionReference<Map<String, dynamic>> get _blocks =>
      _db.collection('study_content_blocks');
  CollectionReference<Map<String, dynamic>> get _progress =>
      _db.collection('study_progress');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('study_sessions');
  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('study_notes');
  CollectionReference<Map<String, dynamic>> get _questions =>
      _db.collection('study_questions');
  CollectionReference<Map<String, dynamic>> get _assignments =>
      _db.collection('study_assignments');
  CollectionReference<Map<String, dynamic>> get _quizzes =>
      _db.collection('study_quizzes');
  CollectionReference<Map<String, dynamic>> get _attempts =>
      _db.collection('study_quiz_attempts');
  CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection('study_review_items');
  CollectionReference<Map<String, dynamic>> get _goals =>
      _db.collection('study_goals');
  CollectionReference<Map<String, dynamic>> get _activity =>
      _db.collection('activity_logs');
  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings');

  Future<void> _log({
    required String action,
    required String collection,
    required String documentId,
    required String summary,
  }) async {
    final u = _auth.currentUser;
    await _activity.add(
      ActivityLogDoc(
        id: '',
        action: action,
        collection: collection,
        documentId: documentId,
        summary: summary,
        actorUid: u?.uid ?? '',
        actorEmail: u?.email ?? '',
      ).toMap(),
    );
  }

  // —— courses ——
  Stream<List<StudyCourse>> watchCourses() {
    return _courses.snapshots().map(
      (s) => s.docs.map(StudyCourse.fromDoc).toList(),
    );
  }

  Stream<StudyCourse?> watchCourse(String id) {
    return _courses.doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return StudyCourse.fromDoc(d);
    });
  }

  Future<String> upsertCourse(StudyCourse course, {bool isNew = false}) async {
    final ref = course.id.isEmpty ? _courses.doc() : _courses.doc(course.id);
    final data = course.toMap(includeCreated: isNew || course.id.isEmpty);
    if (isNew || course.id.isEmpty) {
      data['createdBy'] = _auth.currentUser?.uid ?? course.createdBy;
    }
    await ref.set(data, SetOptions(merge: true));
    await _log(
      action: isNew || course.id.isEmpty ? 'create' : 'update',
      collection: 'study_courses',
      documentId: ref.id,
      summary: '강의방 저장: ${course.title}',
    );
    return ref.id;
  }

  Future<void> archiveCourse(String id) async {
    await _courses.doc(id).set({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log(
      action: 'archive',
      collection: 'study_courses',
      documentId: id,
      summary: '강의방 보관',
    );
  }

  Future<void> deleteCourseHard(String id) async {
    await _courses.doc(id).delete();
    await _log(
      action: 'delete',
      collection: 'study_courses',
      documentId: id,
      summary: '강의방 영구 삭제',
    );
  }

  Future<String> duplicateCourse(StudyCourse source) async {
    final copy = StudyCourse(
      id: '',
      title: '${source.title} (복사본)',
      category: source.category,
      description: source.description,
      learningGoal: source.learningGoal,
      targetLevel: source.targetLevel,
      difficulty: source.difficulty,
      status: 'draft',
      iconName: source.iconName,
      tags: source.tags,
      referenceLinks: source.referenceLinks,
      nextAction: '첫 챕터를 등록하십시오.',
      estimatedChapterCount: source.estimatedChapterCount,
    );
    return upsertCourse(copy, isNew: true);
  }

  // —— chapters ——
  Stream<List<StudyChapter>> watchChapters(String courseId) {
    return _chapters
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(StudyChapter.fromDoc).toList()
            ..sort((a, b) {
              final o = a.displayOrder.compareTo(b.displayOrder);
              if (o != 0) return o;
              return a.chapterNumber.compareTo(b.chapterNumber);
            });
          return list;
        });
  }

  Future<List<StudyChapter>> fetchChapters(String courseId) async {
    final s = await _chapters.where('courseId', isEqualTo: courseId).get();
    final list = s.docs.map(StudyChapter.fromDoc).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  Future<String> upsertChapter(
    StudyChapter chapter, {
    bool isNew = false,
  }) async {
    final ref = chapter.id.isEmpty ? _chapters.doc() : _chapters.doc(chapter.id);
    await ref.set(
      chapter.toMap(includeCreated: isNew || chapter.id.isEmpty),
      SetOptions(merge: true),
    );
    await _log(
      action: isNew || chapter.id.isEmpty ? 'create' : 'update',
      collection: 'study_chapters',
      documentId: ref.id,
      summary: '챕터 저장: ${chapter.title}',
    );
    return ref.id;
  }

  Future<void> deleteChapter(String id) async {
    await _chapters.doc(id).delete();
    await _log(
      action: 'delete',
      collection: 'study_chapters',
      documentId: id,
      summary: '챕터 삭제',
    );
  }

  Future<void> reorderChapters(List<StudyChapter> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.set(_chapters.doc(ordered[i].id), {
        'displayOrder': i,
        'chapterNumber': i + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    await _log(
      action: 'reorder',
      collection: 'study_chapters',
      documentId: ordered.isEmpty ? '' : ordered.first.courseId,
      summary: '챕터 순서 변경 ${ordered.length}건',
    );
  }

  // —— content blocks ——
  Stream<List<StudyContentBlock>> watchBlocks(String chapterId) {
    return _blocks.where('chapterId', isEqualTo: chapterId).snapshots().map((
      s,
    ) {
      final list = s.docs.map(StudyContentBlock.fromDoc).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    });
  }

  Future<String> upsertBlock(StudyContentBlock block, {bool isNew = false}) async {
    final ref = block.id.isEmpty ? _blocks.doc() : _blocks.doc(block.id);
    await ref.set(
      block.toMap(includeCreated: isNew || block.id.isEmpty),
      SetOptions(merge: true),
    );
    return ref.id;
  }

  Future<void> deleteBlock(String id) async {
    await _blocks.doc(id).delete();
  }

  // —— progress / sessions ——
  Stream<List<StudyProgress>> watchProgress({String? courseId}) {
    Query<Map<String, dynamic>> q = _progress;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map(
      (s) => s.docs.map(StudyProgress.fromDoc).toList(),
    );
  }

  Future<void> upsertProgress(StudyProgress progress) async {
    final id = progress.id.isEmpty
        ? '${progress.courseId}_${progress.chapterId}'
        : progress.id;
    await _progress.doc(id).set(progress.toMap(), SetOptions(merge: true));
    await _log(
      action: 'upsert',
      collection: 'study_progress',
      documentId: id,
      summary: progress.isCompleted ? '챕터 완료 기록' : '진도 업데이트',
    );
  }

  Stream<List<StudySession>> watchSessions({int limit = 80}) {
    return _sessions
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(StudySession.fromDoc).toList());
  }

  Future<String> upsertSession(
    StudySession session, {
    bool isNew = false,
  }) async {
    final ref = session.id.isEmpty ? _sessions.doc() : _sessions.doc(session.id);
    await ref.set(
      session.toMap(includeCreated: isNew || session.id.isEmpty),
      SetOptions(merge: true),
    );
    await _log(
      action: isNew || session.id.isEmpty ? 'create' : 'update',
      collection: 'study_sessions',
      documentId: ref.id,
      summary: '학습 세션 저장',
    );
    return ref.id;
  }

  // —— notes / questions ——
  Stream<List<StudyNote>> watchNotes({String? courseId}) {
    Query<Map<String, dynamic>> q = _notes;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map((s) {
      final list = s.docs.map(StudyNote.fromDoc).toList()
        ..sort((a, b) {
          final aa = a.updatedAt ?? a.createdAt ?? DateTime(1970);
          final bb = b.updatedAt ?? b.createdAt ?? DateTime(1970);
          return bb.compareTo(aa);
        });
      return list;
    });
  }

  Future<String> upsertNote(StudyNote note, {bool isNew = false}) async {
    final ref = note.id.isEmpty ? _notes.doc() : _notes.doc(note.id);
    await ref.set(
      note.toMap(includeCreated: isNew || note.id.isEmpty),
      SetOptions(merge: true),
    );
    return ref.id;
  }

  Future<void> deleteNote(String id) async {
    await _notes.doc(id).delete();
  }

  Stream<List<StudyQuestion>> watchQuestions({String? courseId}) {
    Query<Map<String, dynamic>> q = _questions;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map(
      (s) => s.docs.map(StudyQuestion.fromDoc).toList(),
    );
  }

  Future<String> upsertQuestion(
    StudyQuestion q, {
    bool isNew = false,
  }) async {
    final ref = q.id.isEmpty ? _questions.doc() : _questions.doc(q.id);
    await ref.set(
      q.toMap(includeCreated: isNew || q.id.isEmpty),
      SetOptions(merge: true),
    );
    return ref.id;
  }

  // —— assignments / quizzes ——
  Stream<List<StudyAssignment>> watchAssignments({String? courseId}) {
    Query<Map<String, dynamic>> q = _assignments;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map(
      (s) => s.docs.map(StudyAssignment.fromDoc).toList(),
    );
  }

  Future<String> upsertAssignment(
    StudyAssignment a, {
    bool isNew = false,
  }) async {
    final ref = a.id.isEmpty ? _assignments.doc() : _assignments.doc(a.id);
    await ref.set(
      a.toMap(includeCreated: isNew || a.id.isEmpty),
      SetOptions(merge: true),
    );
    await _log(
      action: 'upsert',
      collection: 'study_assignments',
      documentId: ref.id,
      summary: '과제 저장: ${a.title}',
    );
    return ref.id;
  }

  Stream<List<StudyQuiz>> watchQuizzes({String? courseId}) {
    Query<Map<String, dynamic>> q = _quizzes;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map((s) => s.docs.map(StudyQuiz.fromDoc).toList());
  }

  Future<String> upsertQuiz(StudyQuiz quiz, {bool isNew = false}) async {
    final ref = quiz.id.isEmpty ? _quizzes.doc() : _quizzes.doc(quiz.id);
    await ref.set(
      quiz.toMap(includeCreated: isNew || quiz.id.isEmpty),
      SetOptions(merge: true),
    );
    return ref.id;
  }

  Future<void> deleteQuiz(String id) async {
    await _quizzes.doc(id).delete();
  }

  Stream<List<StudyQuizAttempt>> watchAttempts({String? courseId}) {
    Query<Map<String, dynamic>> q = _attempts;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map(
      (s) => s.docs.map(StudyQuizAttempt.fromDoc).toList(),
    );
  }

  Future<String> addAttempt(StudyQuizAttempt attempt) async {
    final ref = _attempts.doc();
    await ref.set(attempt.toMap());
    await _log(
      action: 'create',
      collection: 'study_quiz_attempts',
      documentId: ref.id,
      summary: '퀴즈 응시 기록',
    );
    return ref.id;
  }

  Stream<List<StudyReviewItem>> watchReviews({String? courseId}) {
    Query<Map<String, dynamic>> q = _reviews;
    if (courseId != null && courseId.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseId);
    }
    return q.snapshots().map(
      (s) => s.docs.map(StudyReviewItem.fromDoc).toList(),
    );
  }

  Future<String> upsertReview(StudyReviewItem item, {bool isNew = false}) async {
    final ref = item.id.isEmpty ? _reviews.doc() : _reviews.doc(item.id);
    await ref.set(
      item.toMap(includeCreated: isNew || item.id.isEmpty),
      SetOptions(merge: true),
    );
    return ref.id;
  }

  Stream<List<StudyGoal>> watchGoals() {
    return _goals.snapshots().map((s) => s.docs.map(StudyGoal.fromDoc).toList());
  }

  Future<String> upsertGoal(StudyGoal goal, {bool isNew = false}) async {
    final ref = goal.id.isEmpty ? _goals.doc() : _goals.doc(goal.id);
    await ref.set(
      goal.toMap(includeCreated: isNew || goal.id.isEmpty),
      SetOptions(merge: true),
    );
    return ref.id;
  }

  Future<Map<String, dynamic>> exportStudySnapshot() async {
    Future<List<Map<String, dynamic>>> dump(
      CollectionReference<Map<String, dynamic>> col,
    ) async {
      final s = await col.get();
      return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }

    return {
      'study_courses': await dump(_courses),
      'study_chapters': await dump(_chapters),
      'study_content_blocks': await dump(_blocks),
      'study_progress': await dump(_progress),
      'study_sessions': await dump(_sessions),
      'study_notes': await dump(_notes),
      'study_questions': await dump(_questions),
      'study_assignments': await dump(_assignments),
      'study_quizzes': await dump(_quizzes),
      'study_quiz_attempts': await dump(_attempts),
      'study_review_items': await dump(_reviews),
      'study_goals': await dump(_goals),
      'study_lessons': await dump(_db.collection('study_lessons')),
      'study_course_versions': await dump(
        _db.collection('study_course_versions'),
      ),
      'study_learning_runs': await dump(_db.collection('study_learning_runs')),
      'study_lesson_progress': await dump(
        _db.collection('study_lesson_progress'),
      ),
      'study_generation_jobs': await dump(
        _db.collection('study_generation_jobs'),
      ),
      'study_ai_messages': await dump(_db.collection('study_ai_messages')),
      'study_ai_usage': await dump(_db.collection('study_ai_usage')),
    };
  }

  Future<Map<String, dynamic>> loadStudySettings() async {
    final snap = await _settings.doc('study').get();
    return snap.data() ??
        {
          'reviewDaysThreshold': 14,
          'lowQuizScoreThreshold': 60,
        };
  }

  Future<void> saveStudySettings(Map<String, dynamic> data) async {
    await _settings.doc('study').set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
