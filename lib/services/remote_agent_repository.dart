import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/remote_agent_models.dart';
import 'firebase_ready.dart';

/// Firestore streams for agents / jobs (ownerUid scoped when possible).
class RemoteAgentRepository {
  RemoteAgentRepository({
    this._db,
    bool? forceMemory,
    List<RemoteAgentDoc>? memoryAgents,
    List<RemoteJobDoc>? memoryJobs,
    Map<String, List<RemoteStageDoc>>? memoryStages,
  }) : _forceMemory = forceMemory ?? false,
       _memoryAgents = List<RemoteAgentDoc>.from(memoryAgents ?? const []),
       _memoryJobs = List<RemoteJobDoc>.from(memoryJobs ?? const []),
       _memoryStages = Map<String, List<RemoteStageDoc>>.from(
         memoryStages ?? const {},
       );

  final FirebaseFirestore? _db;
  final bool _forceMemory;
  List<RemoteAgentDoc> _memoryAgents;
  List<RemoteJobDoc> _memoryJobs;
  final Map<String, List<RemoteStageDoc>> _memoryStages;

  bool get usesMemory => _forceMemory || !isFirebaseReady();

  FirebaseFirestore get _fs => _db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? get _agents =>
      usesMemory ? null : _fs.collection('agents');

  CollectionReference<Map<String, dynamic>>? get _jobs =>
      usesMemory ? null : _fs.collection('jobs');

  Stream<List<RemoteAgentDoc>> watchAgents({String? ownerUid}) {
    if (usesMemory || _agents == null) {
      return Stream.value(
        ownerUid == null || ownerUid.isEmpty
            ? List.of(_memoryAgents)
            : _memoryAgents.where((a) => a.ownerUid == ownerUid).toList(),
      );
    }
    Query<Map<String, dynamic>> q = _agents!;
    if (ownerUid != null && ownerUid.isNotEmpty) {
      q = q.where('ownerUid', isEqualTo: ownerUid);
    }
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => RemoteAgentDoc.fromMap(d.data(), id: d.id))
          .where((a) => a.agentId.isNotEmpty)
          .toList();
      list.sort((a, b) => a.deviceName.compareTo(b.deviceName));
      return list;
    });
  }

  Stream<List<RemoteJobDoc>> watchJobs({String? ownerUid}) {
    if (usesMemory || _jobs == null) {
      return Stream.value(
        ownerUid == null || ownerUid.isEmpty
            ? List.of(_memoryJobs)
            : _memoryJobs.where((j) => j.ownerUid == ownerUid).toList(),
      );
    }
    Query<Map<String, dynamic>> q = _jobs!;
    if (ownerUid != null && ownerUid.isNotEmpty) {
      q = q.where('ownerUid', isEqualTo: ownerUid);
    }
    return q.orderBy('updatedAt', descending: true).snapshots().map((snap) {
      return snap.docs
          .map((d) => RemoteJobDoc.fromMap(d.data(), id: d.id))
          .where((j) => j.jobId.isNotEmpty)
          .toList();
    });
  }

  Stream<RemoteJobDoc?> watchJob(String jobId) {
    if (usesMemory || _jobs == null) {
      RemoteJobDoc? found;
      for (final j in _memoryJobs) {
        if (j.jobId == jobId) found = j;
      }
      return Stream.value(found);
    }
    return _jobs!.doc(jobId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return RemoteJobDoc.fromMap(snap.data()!, id: snap.id);
    });
  }

  Stream<List<RemoteStageDoc>> watchStages(String jobId) {
    if (usesMemory || _jobs == null) {
      return Stream.value(List.of(_memoryStages[jobId] ?? const []));
    }
    return _jobs!.doc(jobId).collection('stages').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => RemoteStageDoc.fromMap(d.data(), id: d.id))
          .toList();
      list.sort((a, b) => a.stageNumber.compareTo(b.stageNumber));
      return list;
    });
  }

  Stream<RemoteAgentDoc?> watchPairingCompletion({required String sessionId}) {
    if (usesMemory) {
      return Stream.value(null);
    }
    final db = _fs;
    return db.collection('pairingSessions').doc(sessionId).snapshots().asyncMap(
      (snap) async {
        if (!snap.exists) return null;
        final data = snap.data()!;
        if (data['used'] != true) return null;
        final agentId = '${data['agentId'] ?? ''}';
        if (agentId.isEmpty) return null;
        final a = await db.collection('agents').doc(agentId).get();
        if (!a.exists) return null;
        return RemoteAgentDoc.fromMap(a.data()!, id: a.id);
      },
    );
  }

  /// Test helper.
  void seedMemory({
    List<RemoteAgentDoc>? agents,
    List<RemoteJobDoc>? jobs,
    Map<String, List<RemoteStageDoc>>? stages,
  }) {
    if (agents != null) _memoryAgents = List.of(agents);
    if (jobs != null) _memoryJobs = List.of(jobs);
    if (stages != null) {
      _memoryStages
        ..clear()
        ..addAll(stages);
    }
  }
}
