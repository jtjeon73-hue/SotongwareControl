import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/artifact_type.dart';
import '../models/remote_agent_models.dart';
import 'dev_work_doc_paths.dart';
import 'instruction_content_checksum.dart';

/// Remote-control mirror of DevWorkDoc Active WorkInstruction JSON.
/// Local DevWorkDoc remains SSOT for PC; Firestore is a soft sync for mobile.
class RemoteWorkInstructionMirrorService {
  RemoteWorkInstructionMirrorService({
    this._db,
    this._auth,
    this._memory,
  });

  static const collection = 'workInstructions';
  static const statusActive = 'active';
  static const statusArchived = 'archived';

  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final Map<String, Map<String, dynamic>>? _memory;

  bool get usesMemory => _memory != null;

  FirebaseFirestore get _fs => _db ?? FirebaseFirestore.instance;
  FirebaseAuth get _fa => _auth ?? FirebaseAuth.instance;

  /// Deterministic doc id: `{uid}__{artifact}__{sanitizedInstructionId}`
  static String docId({
    required String ownerUid,
    required String artifactType,
    required String instructionId,
  }) {
    final a = ArtifactType.normalize(artifactType);
    final id = DevWorkDocPaths.sanitizeInstructionId(instructionId);
    return '${ownerUid.trim()}__${a}__$id';
  }

  String? currentUid() {
    try {
      return _fa.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Soft upsert after local Active save. Never throws to callers who ignore errors;
  /// returns false on failure.
  Future<bool> upsertActive({
    required String artifactType,
    required String instructionId,
    required String jsonText,
    String? ownerUid,
    int? version,
    String? title,
    int? totalStages,
  }) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) {
      debugPrint('[WI Mirror] skip upsert: not signed in');
      return false;
    }
    final text = jsonText.trim();
    if (text.isEmpty) return false;

    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return false;
      map = Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[WI Mirror] bad json: $e');
      return false;
    }

    final artifact = ArtifactType.normalize(
      artifactType.isEmpty
          ? '${map['artifactType'] ?? map['deliverableType'] ?? ''}'
          : artifactType,
    );
    final iid = DevWorkDocPaths.sanitizeInstructionId(
      instructionId.isEmpty
          ? '${map['instructionId'] ?? ''}'
          : instructionId,
    );
    if (iid.isEmpty || artifact == ArtifactType.undecided) return false;

    final resolvedTitle =
        (title ?? '${map['title'] ?? map['projectName'] ?? iid}').trim();
    final resolvedVersion =
        version ?? int.tryParse('${map['version'] ?? 1}') ?? 1;
    var stages = totalStages ?? 18;
    final stageList = map['stages'];
    if (totalStages == null && stageList is List && stageList.isNotEmpty) {
      stages = stageList.length;
    }
    if (totalStages == null && map['totalStages'] != null) {
      stages = int.tryParse('${map['totalStages']}') ?? stages;
    }

    final id = docId(
      ownerUid: uid,
      artifactType: artifact,
      instructionId: iid,
    );
    final now = DateTime.now().toUtc();
    final checksum = stableContentChecksum(text);

    final payload = <String, dynamic>{
      'ownerUid': uid,
      'artifactType': artifact,
      'instructionId': iid,
      'title': resolvedTitle.isEmpty ? iid : resolvedTitle,
      'version': resolvedVersion,
      'totalStages': stages,
      'status': statusActive,
      'json': map,
      'checksum': checksum,
      'updatedAt': usesMemory ? now.toIso8601String() : FieldValue.serverTimestamp(),
      'executionSummary': _executionSummaryFromMap(map, planId: '${map['projectId'] ?? ''}'),
    };

    try {
      if (usesMemory) {
        final mem = _memory!;
        final existing = mem[id];
        payload['createdAt'] =
            existing?['createdAt'] ?? now.toIso8601String();
        mem[id] = {...?existing, ...payload};
        return true;
      }
      final ref = _fs.collection(collection).doc(id);
      final snap = await ref.get();
      if (!snap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
      await ref.set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[WI Mirror] upsert failed (local kept): $e');
      return false;
    }
  }

  Future<bool> markArchived({
    required String artifactType,
    required String instructionId,
    String? ownerUid,
  }) async {
    return _setStatus(
      artifactType: artifactType,
      instructionId: instructionId,
      ownerUid: ownerUid,
      status: statusArchived,
    );
  }

  Future<bool> restoreActive({
    required String artifactType,
    required String instructionId,
    String? jsonText,
    String? ownerUid,
    int? version,
  }) async {
    if (jsonText != null && jsonText.trim().isNotEmpty) {
      return upsertActive(
        artifactType: artifactType,
        instructionId: instructionId,
        jsonText: jsonText,
        ownerUid: ownerUid,
        version: version,
      );
    }
    return _setStatus(
      artifactType: artifactType,
      instructionId: instructionId,
      ownerUid: ownerUid,
      status: statusActive,
    );
  }

  Future<bool> _setStatus({
    required String artifactType,
    required String instructionId,
    required String status,
    String? ownerUid,
  }) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) return false;
    final artifact = ArtifactType.normalize(artifactType);
    final iid = DevWorkDocPaths.sanitizeInstructionId(instructionId);
    if (iid.isEmpty) return false;
    final id = docId(ownerUid: uid, artifactType: artifact, instructionId: iid);
    final now = DateTime.now().toUtc();
    try {
      if (usesMemory) {
        final mem = _memory!;
        final existing = mem[id];
        if (existing == null) return false;
        mem[id] = {
          ...existing,
          'status': status,
          'updatedAt': now.toIso8601String(),
        };
        return true;
      }
      await _fs.collection(collection).doc(id).set({
        'ownerUid': uid,
        'artifactType': artifact,
        'instructionId': iid,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[WI Mirror] status update failed: $e');
      return false;
    }
  }

  Future<List<ActiveWorkInstructionRef>> listActive({
    String? artifactType,
    String? ownerUid,
  }) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) return const [];
    final artifactFilter = artifactType == null || artifactType.trim().isEmpty
        ? null
        : ArtifactType.normalize(artifactType);

    if (usesMemory) {
      final rows = _memory!.entries
          .map((e) => e.value)
          .where(
            (d) =>
                d['ownerUid'] == uid &&
                d['status'] == statusActive &&
                (artifactFilter == null || d['artifactType'] == artifactFilter),
          )
          .toList();
      rows.sort((a, b) {
        final at = '${a['updatedAt'] ?? ''}';
        final bt = '${b['updatedAt'] ?? ''}';
        return bt.compareTo(at);
      });
      return rows.map(_fromDoc).whereType<ActiveWorkInstructionRef>().toList();
    }

    try {
      Query<Map<String, dynamic>> q = _fs
          .collection(collection)
          .where('ownerUid', isEqualTo: uid)
          .where('status', isEqualTo: statusActive);
      if (artifactFilter != null) {
        q = q.where('artifactType', isEqualTo: artifactFilter);
      }
      q = q.orderBy('updatedAt', descending: true);
      final snap = await q.get();
      return snap.docs
          .map((d) => _fromDoc(d.data()))
          .whereType<ActiveWorkInstructionRef>()
          .toList();
    } catch (e) {
      debugPrint('[WI Mirror] listActive failed: $e');
      return const [];
    }
  }

  ActiveWorkInstructionRef? _fromDoc(Map<String, dynamic> data) {
    final artifact = ArtifactType.normalize('${data['artifactType'] ?? ''}');
    final iid = '${data['instructionId'] ?? ''}'.trim();
    if (iid.isEmpty || artifact == ArtifactType.undecided) return null;
    final jsonField = data['json'];
    String jsonText;
    if (jsonField is Map) {
      jsonText = jsonEncode(Map<String, dynamic>.from(jsonField));
    } else if (jsonField is String && jsonField.trim().isNotEmpty) {
      jsonText = jsonField;
    } else {
      return null;
    }
    return ActiveWorkInstructionRef(
      artifactType: artifact,
      instructionId: iid,
      title: '${data['title'] ?? iid}'.trim().isEmpty
          ? iid
          : '${data['title']}'.trim(),
      jsonText: jsonText,
      version: int.tryParse('${data['version'] ?? 1}') ?? 1,
      totalStages: int.tryParse('${data['totalStages'] ?? 18}') ?? 18,
    );
  }

  /// Sotong24Work state 필드가 json에 포함된 경우 중앙 mirror 요약.
  static Map<String, dynamic> _executionSummaryFromMap(
    Map<String, dynamic> map, {
    String planId = '',
  }) {
    final approval = map['approval'];
    var approvalStatus = '';
    if (approval is Map) {
      approvalStatus = '${approval['status'] ?? approval['stageDecision'] ?? ''}';
    }
    final titleDraft = '${map['titleDraft'] ?? map['title'] ?? map['businessIdea'] ?? ''}'.trim();
    final currentStage = int.tryParse('${map['currentStageOrder'] ?? map['currentStage'] ?? 0}') ?? 0;
    final stageId = '${map['currentStageId'] ?? ''}'.trim();
    return {
      'planId': planId.trim(),
      'projectTitle': titleDraft,
      'currentStage': currentStage,
      'currentStageId': stageId,
      'totalStages': int.tryParse('${map['totalStages'] ?? 18}') ?? 18,
      'workflowStarted': map['workflowStarted'] == true || currentStage > 0,
      'approvalStatus': approvalStatus,
      'hasLocalProject': map['workFolder'] != null || map['projectPath'] != null,
      'lastUpdated': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
