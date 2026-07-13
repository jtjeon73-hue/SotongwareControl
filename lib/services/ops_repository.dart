import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ops_models.dart';

class OpsRepository {
  OpsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

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
  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings');

  Stream<List<BusinessUnitDoc>> watchBusinessUnits() {
    return _units.orderBy('displayOrder').snapshots().map(
      (s) => s.docs.map(BusinessUnitDoc.fromDoc).toList(),
    );
  }

  Stream<List<ProjectDoc>> watchProjects({String? businessUnitId}) {
    Query<Map<String, dynamic>> q = _projects;
    if (businessUnitId != null && businessUnitId.isNotEmpty) {
      q = q.where('businessUnitId', isEqualTo: businessUnitId);
    }
    return q.snapshots().map(
      (s) => s.docs.map(ProjectDoc.fromDoc).toList(),
    );
  }

  Stream<List<TaskDoc>> watchTasks({String? businessUnitId}) {
    Query<Map<String, dynamic>> q = _tasks;
    if (businessUnitId != null && businessUnitId.isNotEmpty) {
      q = q.where('businessUnitId', isEqualTo: businessUnitId);
    }
    return q.snapshots().map((s) => s.docs.map(TaskDoc.fromDoc).toList());
  }

  Stream<List<WorkLogDoc>> watchWorkLogs({int limit = 50}) {
    return _logs
        .orderBy('workedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(WorkLogDoc.fromDoc).toList());
  }

  Stream<List<DeploymentDoc>> watchDeployments() {
    return _deployments.snapshots().map(
      (s) => s.docs.map(DeploymentDoc.fromDoc).toList(),
    );
  }

  Stream<List<IssueDoc>> watchIssues() {
    return _issues.snapshots().map(
      (s) => s.docs.map(IssueDoc.fromDoc).toList(),
    );
  }

  Stream<List<AiReportDoc>> watchAiReports({String? departmentId}) {
    Query<Map<String, dynamic>> q = _aiReports;
    if (departmentId != null) {
      q = q.where('departmentId', isEqualTo: departmentId);
    }
    return q.snapshots().map((s) => s.docs.map(AiReportDoc.fromDoc).toList());
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
  }

  Future<void> upsertProject(ProjectDoc project) async {
    await _projects.doc(project.id).set(project.toMap(), SetOptions(merge: true));
  }

  Future<void> upsertTask(TaskDoc task) async {
    final ref = task.id.isEmpty ? _tasks.doc() : _tasks.doc(task.id);
    await ref.set(task.toMap(), SetOptions(merge: true));
  }

  Future<void> addWorkLog(WorkLogDoc log) async {
    final ref = log.id.isEmpty ? _logs.doc() : _logs.doc(log.id);
    await ref.set(log.toMap(), SetOptions(merge: true));
  }

  Future<void> upsertIssue(IssueDoc issue) async {
    final ref = issue.id.isEmpty ? _issues.doc() : _issues.doc(issue.id);
    await ref.set(issue.toMap(), SetOptions(merge: true));
  }

  Future<void> upsertDeployment(DeploymentDoc dep) async {
    final ref = dep.id.isEmpty ? _deployments.doc() : _deployments.doc(dep.id);
    await ref.set(dep.toMap(), SetOptions(merge: true));
  }

  Future<void> upsertAiReport(AiReportDoc report) async {
    final ref = report.id.isEmpty ? _aiReports.doc() : _aiReports.doc(report.id);
    await ref.set(report.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteDoc(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
  }
}
