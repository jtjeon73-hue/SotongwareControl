import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/business_analysis.dart';
import '../models/ops_models.dart';

class OpsRepository {
  OpsRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _units =>
      _db.collection('business_units');
  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');
  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');
  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection('work_logs');
  CollectionReference<Map<String, dynamic>> get _deployments =>
      _db.collection('deployments');
  CollectionReference<Map<String, dynamic>> get _issues =>
      _db.collection('issues');
  CollectionReference<Map<String, dynamic>> get _aiReports =>
      _db.collection('ai_reports');
  CollectionReference<Map<String, dynamic>> get _activity =>
      _db.collection('activity_logs');
  CollectionReference<Map<String, dynamic>> get _ideas =>
      _db.collection('ideas');
  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings');
  CollectionReference<Map<String, dynamic>> get _businessAnalysisReports =>
      _db.collection('business_analysis_reports');

  User? get currentUser => _auth.currentUser;

  Future<void> _logActivity({
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

  Stream<List<BusinessUnitDoc>> watchBusinessUnits() {
    return _units
        .orderBy('displayOrder')
        .snapshots()
        .map((s) => s.docs.map(BusinessUnitDoc.fromDoc).toList());
  }

  Stream<List<ProjectDoc>> watchProjects({String? businessUnitId}) {
    Query<Map<String, dynamic>> q = _projects;
    if (businessUnitId != null && businessUnitId.isNotEmpty) {
      q = q.where('businessUnitId', isEqualTo: businessUnitId);
    }
    return q.snapshots().map((s) => s.docs.map(ProjectDoc.fromDoc).toList());
  }

  Stream<ProjectDoc?> watchProject(String id) {
    return _projects.doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return ProjectDoc.fromDoc(d);
    });
  }

  Future<ProjectDoc?> getProject(String id) async {
    final d = await _projects.doc(id).get();
    if (!d.exists) return null;
    return ProjectDoc.fromDoc(d);
  }

  Future<bool> projectExists(String id) async {
    final d = await _projects.doc(id).get();
    return d.exists;
  }

  Stream<List<TaskDoc>> watchTasks({
    String? businessUnitId,
    String? projectId,
  }) {
    Query<Map<String, dynamic>> q = _tasks;
    if (projectId != null && projectId.isNotEmpty) {
      q = q.where('projectId', isEqualTo: projectId);
    } else if (businessUnitId != null && businessUnitId.isNotEmpty) {
      q = q.where('businessUnitId', isEqualTo: businessUnitId);
    }
    return q.snapshots().map((s) => s.docs.map(TaskDoc.fromDoc).toList());
  }

  Stream<List<WorkLogDoc>> watchWorkLogs({int limit = 100}) {
    return _logs
        .orderBy('workedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(WorkLogDoc.fromDoc).toList());
  }

  Future<List<WorkLogDoc>> fetchWorkLogsOnce({int limit = 500}) async {
    final s = await _logs
        .orderBy('workedAt', descending: true)
        .limit(limit)
        .get();
    return s.docs.map(WorkLogDoc.fromDoc).toList();
  }

  Future<bool> hasCommitHash(String commitHash, {String? excludeId}) async {
    final hash = commitHash.trim();
    if (hash.isEmpty) return false;
    final s = await _logs.where('commitHash', isEqualTo: hash).limit(5).get();
    return s.docs.any((d) => d.id != excludeId);
  }

  Stream<List<DeploymentDoc>> watchDeployments({String? projectId}) {
    Query<Map<String, dynamic>> q = _deployments;
    if (projectId != null && projectId.isNotEmpty) {
      q = q.where('projectId', isEqualTo: projectId);
    }
    return q.snapshots().map((s) => s.docs.map(DeploymentDoc.fromDoc).toList());
  }

  Stream<List<IssueDoc>> watchIssues({String? projectId}) {
    Query<Map<String, dynamic>> q = _issues;
    if (projectId != null && projectId.isNotEmpty) {
      q = q.where('projectId', isEqualTo: projectId);
    }
    return q.snapshots().map((s) => s.docs.map(IssueDoc.fromDoc).toList());
  }

  Stream<List<AiReportDoc>> watchAiReports({String? departmentId}) {
    Query<Map<String, dynamic>> q = _aiReports;
    if (departmentId != null) {
      q = q.where('departmentId', isEqualTo: departmentId);
    }
    return q.snapshots().map((s) => s.docs.map(AiReportDoc.fromDoc).toList());
  }

  Stream<List<ActivityLogDoc>> watchActivityLogs({int limit = 40}) {
    return _activity
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(ActivityLogDoc.fromDoc).toList());
  }

  Stream<List<IdeaDoc>> watchIdeas() {
    return _ideas.snapshots().map((s) => s.docs.map(IdeaDoc.fromDoc).toList());
  }

  Stream<List<BusinessAnalysisReport>> watchBusinessAnalysisReports({
    int limit = 20,
  }) {
    return _businessAnalysisReports
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(BusinessAnalysisReport.fromDoc).toList(),
        );
  }

  Future<BusinessAnalysisReport?> latestBusinessAnalysisReport() async {
    final snapshot = await _businessAnalysisReports
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return BusinessAnalysisReport.fromDoc(snapshot.docs.first);
  }

  Future<String> saveBusinessAnalysisReport(
    BusinessAnalysisReport report,
  ) async {
    final reference = report.id.isEmpty
        ? _businessAnalysisReports.doc()
        : _businessAnalysisReports.doc(report.id);
    await reference.set(
      report.toMap(includeCreatedAt: report.id.isEmpty),
      SetOptions(merge: true),
    );
    await _logActivity(
      action: 'create',
      collection: 'business_analysis_reports',
      documentId: reference.id,
      summary: '전체 사업 규칙 기반 분석 저장: ${report.overallStatus}',
    );
    return reference.id;
  }

  Future<bool> isStructureSeeded() async {
    final snap = await _settings.doc('structure').get();
    return snap.exists && snap.data()?['seeded'] == true;
  }

  Future<void> markStructureSeeded() async {
    await _settings.doc('structure').set({
      'seeded': true,
      'seededAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertBusinessUnit(BusinessUnitDoc unit) async {
    await _units.doc(unit.id).set(unit.toMap(), SetOptions(merge: true));
    await _logActivity(
      action: 'upsert',
      collection: 'business_units',
      documentId: unit.id,
      summary: '사업부 저장: ${unit.name}',
    );
  }

  Future<void> upsertProject(ProjectDoc project, {bool isNew = false}) async {
    await _projects
        .doc(project.id)
        .set(project.toMap(includeCreatedAt: isNew), SetOptions(merge: true));
    await _logActivity(
      action: isNew ? 'create' : 'update',
      collection: 'projects',
      documentId: project.id,
      summary: '프로젝트 저장: ${project.name}',
    );
  }

  Future<void> upsertTask(TaskDoc task) async {
    final ref = task.id.isEmpty ? _tasks.doc() : _tasks.doc(task.id);
    await ref.set(task.toMap(), SetOptions(merge: true));
    await _logActivity(
      action: 'upsert',
      collection: 'tasks',
      documentId: ref.id,
      summary: '업무 저장: ${task.title}',
    );
  }

  Future<String> upsertWorkLog(WorkLogDoc log) async {
    final ref = log.id.isEmpty ? _logs.doc() : _logs.doc(log.id);
    await ref.set(log.toMap(), SetOptions(merge: true));
    await _logActivity(
      action: log.id.isEmpty ? 'create' : 'update',
      collection: 'work_logs',
      documentId: ref.id,
      summary: '작업 로그 저장: ${log.title}',
    );
    return ref.id;
  }

  Future<void> addWorkLog(WorkLogDoc log) async {
    await upsertWorkLog(log);
  }

  Future<void> upsertIssue(IssueDoc issue) async {
    final ref = issue.id.isEmpty ? _issues.doc() : _issues.doc(issue.id);
    await ref.set(issue.toMap(), SetOptions(merge: true));
    await _logActivity(
      action: 'upsert',
      collection: 'issues',
      documentId: ref.id,
      summary: '문제 저장: ${issue.title}',
    );
  }

  Future<void> upsertDeployment(DeploymentDoc dep) async {
    final ref = dep.id.isEmpty ? _deployments.doc() : _deployments.doc(dep.id);
    await ref.set(dep.toMap(), SetOptions(merge: true));
    await _logActivity(
      action: 'upsert',
      collection: 'deployments',
      documentId: ref.id,
      summary: '배포 기록 저장: ${dep.projectId}',
    );
  }

  Future<void> upsertAiReport(AiReportDoc report) async {
    final ref = report.id.isEmpty
        ? _aiReports.doc()
        : _aiReports.doc(report.id);
    await ref.set(report.toMap(), SetOptions(merge: true));
    await _logActivity(
      action: 'upsert',
      collection: 'ai_reports',
      documentId: ref.id,
      summary: 'AI 보고서 저장: ${report.title}',
    );
  }

  Future<void> upsertIdea(IdeaDoc idea) async {
    final ref = idea.id.isEmpty ? _ideas.doc() : _ideas.doc(idea.id);
    await ref.set(idea.toMap(), SetOptions(merge: true));
    await _logActivity(
      action: 'upsert',
      collection: 'ideas',
      documentId: ref.id,
      summary: '아이디어 저장: ${idea.title}',
    );
  }

  Future<void> deleteDoc(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
    await _logActivity(
      action: 'delete',
      collection: collection,
      documentId: id,
      summary: '문서 삭제',
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> exportSnapshot() async {
    Future<List<Map<String, dynamic>>> dump(
      CollectionReference<Map<String, dynamic>> col,
    ) async {
      final s = await col.get();
      return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }

    return {
      'business_units': await dump(_units),
      'projects': await dump(_projects),
      'tasks': await dump(_tasks),
      'work_logs': await dump(_logs),
      'deployments': await dump(_deployments),
      'issues': await dump(_issues),
      'ai_reports': await dump(_aiReports),
      'business_analysis_reports': await dump(_businessAnalysisReports),
      'ideas': await dump(_ideas),
    };
  }
}
