import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/business_planning.dart';

/// Soft mirror of BusinessPlanDocument for cross-device plan list.
/// Freshness uses server-managed integer [revision] + optimistic concurrency.
/// Conflict must NOT promote cloud revision into the write base for a stale payload.
class BusinessPlanMirrorService {
  BusinessPlanMirrorService({
    this._db,
    this._auth,
    this._memory,
    this._ownerUidResolver,
  });

  static const collection = 'businessPlans';

  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final Map<String, Map<String, dynamic>>? _memory;
  final String? Function()? _ownerUidResolver;

  /// Confirmed write bases only (successful write or accepted cloud reload).
  final Map<String, int> knownRevisions = {};

  /// Plans blocked from cloud writes until [acceptCloudRevision].
  final Set<String> writeBlocked = {};

  final Map<String, BusinessPlanDocument> _pending = {};
  final Map<String, Future<MirrorWriteResult>> _queues = {};

  bool get usesMemory => _memory != null;

  FirebaseFirestore get _fs => _db ?? FirebaseFirestore.instance;
  FirebaseAuth get _fa => _auth ?? FirebaseAuth.instance;

  static String docId({required String ownerUid, required String planId}) =>
      '${ownerUid.trim()}__${planId.trim()}';

  String? currentUid() {
    final resolved = _ownerUidResolver?.call()?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    try {
      return _fa.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  int revisionOf(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final raw = data['revision'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  /// Confirm a new write base after successful write or accepted cloud reload.
  void acceptCloudRevision(String planId, int revision) {
    final id = planId.trim();
    if (id.isEmpty) return;
    knownRevisions[id] = revision;
    writeBlocked.remove(id);
  }

  /// @deprecated Prefer [acceptCloudRevision] — kept name for call-site clarity.
  void rememberRevision(String planId, int revision) =>
      acceptCloudRevision(planId, revision);

  void _markConflict(String planId) {
    final id = planId.trim();
    if (id.isEmpty) return;
    writeBlocked.add(id);
    _pending.remove(id);
  }

  /// Applies [onCommitted] only after [run] returns successfully.
  /// Firestore txn callbacks may retry; keep local revision side effects here.
  @visibleForTesting
  static Future<T> applyAfterCommit<T>({
    required Future<T> Function() run,
    required void Function(T value) onCommitted,
  }) async {
    final value = await run();
    onCommitted(value);
    return value;
  }

  bool isWriteBlocked(String planId) => writeBlocked.contains(planId.trim());

  Future<MirrorWriteResult> upsertPlan(
    BusinessPlanDocument plan, {
    String? ownerUid,
    int? baseRevision,
  }) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) {
      debugPrint('[Plan Mirror] skip upsert: not signed in');
      return MirrorWriteResult.skipped;
    }
    if (plan.id.trim().isEmpty) return MirrorWriteResult.skipped;
    if (writeBlocked.contains(plan.id)) {
      return MirrorWriteResult.conflict();
    }
    final id = docId(ownerUid: uid, planId: plan.id);
    final base = baseRevision ?? knownRevisions[plan.id] ?? 0;
    final payload = _payload(uid: uid, plan: plan);

    try {
      if (usesMemory) {
        return _upsertMemory(
          id: id,
          uid: uid,
          plan: plan,
          base: base,
          payload: payload,
        );
      }

      final ref = _fs.collection(collection).doc(id);
      final result = await _fs.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (snap.exists) {
          final data = snap.data() ?? {};
          if (data['ownerUid'] != null && data['ownerUid'] != uid) {
            return MirrorWriteResult.skipped;
          }
          if (data['isDeleted'] == true) {
            return MirrorWriteResult.tombstoned;
          }
          final current = revisionOf(data);
          if (current != base) {
            return MirrorWriteResult.conflict(observedCloudRevision: current);
          }
          final next = current + 1;
          txn.set(ref, {
            ...payload,
            'isDeleted': false,
            'deletedAt': null,
            'revision': next,
            'syncedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return MirrorWriteResult.ok(next);
        }
        if (base != 0) {
          return MirrorWriteResult.conflict();
        }
        txn.set(ref, {
          ...payload,
          'isDeleted': false,
          'deletedAt': null,
          'revision': 1,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        return MirrorWriteResult.ok(1);
      });
      // Side effects only after successful commit return.
      if (result.succeeded && result.revision != null) {
        acceptCloudRevision(plan.id, result.revision!);
      } else if (result.status == MirrorWriteStatus.conflict ||
          result.status == MirrorWriteStatus.tombstoned) {
        _markConflict(plan.id);
      }
      return result;
    } catch (e) {
      debugPrint('[Plan Mirror] upsert failed (local kept): $e');
      return MirrorWriteResult.failed;
    }
  }

  MirrorWriteResult _upsertMemory({
    required String id,
    required String uid,
    required BusinessPlanDocument plan,
    required int base,
    required Map<String, dynamic> payload,
  }) {
    final mem = _memory!;
    final existing = mem[id];
    if (existing != null && existing['isDeleted'] == true) {
      _markConflict(plan.id);
      return MirrorWriteResult.tombstoned;
    }
    if (existing != null) {
      final current = revisionOf(existing);
      if (current != base) {
        _markConflict(plan.id);
        return MirrorWriteResult.conflict(observedCloudRevision: current);
      }
      final next = current + 1;
      mem[id] = {
        ...existing,
        ...payload,
        'isDeleted': false,
        'deletedAt': null,
        'revision': next,
      };
      acceptCloudRevision(plan.id, next);
      return MirrorWriteResult.ok(next);
    }
    if (base != 0) {
      _markConflict(plan.id);
      return MirrorWriteResult.conflict();
    }
    mem[id] = {
      ...payload,
      'isDeleted': false,
      'deletedAt': null,
      'revision': 1,
    };
    acceptCloudRevision(plan.id, 1);
    return MirrorWriteResult.ok(1);
  }

  /// Serialize per planId + coalesce. Conflict blocks further cloud pushes.
  Future<MirrorWriteResult> enqueueUpsert(
    BusinessPlanDocument plan, {
    String? ownerUid,
  }) {
    final planId = plan.id.trim();
    if (planId.isEmpty) return Future.value(MirrorWriteResult.skipped);
    if (writeBlocked.contains(planId)) {
      _pending.remove(planId);
      return Future.value(MirrorWriteResult.conflict());
    }
    _pending[planId] = plan;
    final prev = _queues[planId] ?? Future.value(MirrorWriteResult.skipped);
    final next = prev.catchError((_) => MirrorWriteResult.failed).then((
      _,
    ) async {
      if (writeBlocked.contains(planId)) {
        _pending.remove(planId);
        return MirrorWriteResult.conflict();
      }
      final latest = _pending.remove(planId);
      if (latest == null) return MirrorWriteResult.skipped;
      return upsertPlan(latest, ownerUid: ownerUid);
    });
    _queues[planId] = next;
    return next;
  }

  Future<bool> createIfAbsent(
    BusinessPlanDocument plan, {
    String? ownerUid,
  }) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) return false;
    if (plan.id.trim().isEmpty) return false;
    final id = docId(ownerUid: uid, planId: plan.id);
    final payload = _payload(uid: uid, plan: plan);

    try {
      if (usesMemory) {
        final mem = _memory!;
        if (mem.containsKey(id)) {
          // Existing (incl. tombstone) — do not promote revision for stale writes.
          return true;
        }
        mem[id] = {
          ...payload,
          'isDeleted': false,
          'deletedAt': null,
          'revision': 1,
        };
        acceptCloudRevision(plan.id, 1);
        return true;
      }

      final ref = _fs.collection(collection).doc(id);
      final created = await _fs.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (snap.exists) return false;
        txn.set(ref, {
          ...payload,
          'isDeleted': false,
          'deletedAt': null,
          'revision': 1,
          'syncedAt': FieldValue.serverTimestamp(),
          'backfilledAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (created) {
        acceptCloudRevision(plan.id, 1);
      }
      return true;
    } catch (e) {
      debugPrint('[Plan Mirror] createIfAbsent failed: $e');
      return false;
    }
  }

  Future<bool> markDeleted(String planId, {String? ownerUid}) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    final pid = planId.trim();
    if (uid.isEmpty || pid.isEmpty) return false;
    final id = docId(ownerUid: uid, planId: pid);
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      if (usesMemory) {
        final mem = _memory!;
        final existing = mem[id];
        if (existing != null && existing['ownerUid'] != uid) return false;
        final nextRev = revisionOf(existing) + 1;
        mem[id] = {
          'ownerUid': uid,
          'planId': pid,
          'isDeleted': true,
          'deletedAt': now,
          'updatedAt': now,
          'revision': nextRev,
        };
        acceptCloudRevision(pid, nextRev);
        writeBlocked.remove(pid);
        return true;
      }

      final ref = _fs.collection(collection).doc(id);
      final committedRev = await _fs.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (snap.exists) {
          final data = snap.data() ?? {};
          if (data['ownerUid'] != null && data['ownerUid'] != uid) {
            return null;
          }
          final nextRev = revisionOf(data) + 1;
          // Overwrite (no merge): tombstone allowed-keys must match Rules.
          txn.set(ref, {
            'ownerUid': uid,
            'planId': pid,
            'isDeleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'updatedAt': now,
            'revision': nextRev,
            'syncedAt': FieldValue.serverTimestamp(),
          });
          return nextRev;
        }
        txn.set(ref, {
          'ownerUid': uid,
          'planId': pid,
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': now,
          'revision': 1,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        return 1;
      });
      if (committedRev == null) return false;
      acceptCloudRevision(pid, committedRev);
      return true;
    } catch (e) {
      debugPrint('[Plan Mirror] markDeleted failed: $e');
      return false;
    }
  }

  Future<BackfillResult> backfillMissing(
    List<BusinessPlanDocument> plans, {
    String? ownerUid,
  }) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) {
      return const BackfillResult(
        attempted: 0,
        created: 0,
        skippedExisting: 0,
        failed: 0,
        signedIn: false,
      );
    }
    var created = 0;
    var skipped = 0;
    var failed = 0;
    for (final plan in plans) {
      if (plan.id.trim().isEmpty) continue;
      try {
        final id = docId(ownerUid: uid, planId: plan.id);
        final before = usesMemory
            ? _memory!.containsKey(id)
            : await _exists(id);
        if (before) {
          skipped++;
          continue;
        }
        final ok = await createIfAbsent(plan, ownerUid: uid);
        if (!ok) {
          failed++;
          continue;
        }
        created++;
      } catch (e) {
        debugPrint('[Plan Mirror] backfill item failed: $e');
        failed++;
      }
    }
    return BackfillResult(
      attempted: plans.length,
      created: created,
      skippedExisting: skipped,
      failed: failed,
      signedIn: true,
    );
  }

  Future<bool> _exists(String docIdValue) async {
    final snap = await _fs.collection(collection).doc(docIdValue).get();
    return snap.exists;
  }

  Map<String, dynamic> _payload({
    required String uid,
    required BusinessPlanDocument plan,
  }) {
    return {
      'ownerUid': uid,
      'planId': plan.id,
      'instructionId': plan.stableInstructionId,
      'title': plan.input.topic,
      'artifactType': plan.input.resolvedArtifactType,
      'status': plan.status,
      'version': plan.version,
      'updatedAt': plan.updatedAt,
      'createdAt': plan.createdAt,
      'isLibraryArchived': plan.isLibraryArchived,
      'isLibraryTrashed': plan.isLibraryTrashed,
      'tags': plan.tags,
      'plan': plan.toJson(),
    };
  }

  /// Active plans with cloud revisions. Does NOT mutate knownRevisions.
  Future<CloudPlanList> listPlansWithRevisions({String? ownerUid}) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) {
      return const CloudPlanList(plans: [], revisions: {});
    }

    try {
      final revisions = <String, int>{};
      final list = <BusinessPlanDocument>[];
      if (usesMemory) {
        for (final d in _memory!.values) {
          if (d['ownerUid'] != uid || d['isDeleted'] == true) continue;
          final plan = _fromDoc(d);
          if (plan == null) continue;
          revisions[plan.id] = revisionOf(d);
          list.add(plan);
        }
      } else {
        final snap = await _fs
            .collection(collection)
            .where('ownerUid', isEqualTo: uid)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          if (d['isDeleted'] == true) continue;
          final plan = _fromDoc(d);
          if (plan == null) continue;
          revisions[plan.id] = revisionOf(d);
          list.add(plan);
        }
      }
      // Display sort only — not a sync winner.
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return CloudPlanList(plans: list, revisions: revisions);
    } catch (e) {
      debugPrint('[Plan Mirror] list failed: $e');
      return const CloudPlanList(plans: [], revisions: {});
    }
  }

  Future<List<BusinessPlanDocument>> listPlans({String? ownerUid}) async {
    final r = await listPlansWithRevisions(ownerUid: ownerUid);
    return r.plans;
  }

  Future<Set<String>> listDeletedPlanIds({String? ownerUid}) async {
    final uid = (ownerUid ?? currentUid())?.trim() ?? '';
    if (uid.isEmpty) return {};

    try {
      if (usesMemory) {
        return _memory!.values
            .where((d) => d['ownerUid'] == uid && d['isDeleted'] == true)
            .map((d) => '${d['planId'] ?? ''}'.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
      }
      final snap = await _fs
          .collection(collection)
          .where('ownerUid', isEqualTo: uid)
          .get();
      return snap.docs
          .map((d) => d.data())
          .where((d) => d['isDeleted'] == true)
          .map((d) => '${d['planId'] ?? ''}'.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('[Plan Mirror] listDeleted failed: $e');
      return {};
    }
  }

  Map<String, dynamic>? debugMemoryDoc(String ownerUid, String planId) {
    if (!usesMemory) return null;
    return _memory![docId(ownerUid: ownerUid, planId: planId)];
  }

  BusinessPlanDocument? _fromDoc(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return null;
    final raw = data['plan'];
    if (raw is Map) {
      try {
        return BusinessPlanDocument.fromJson(Map<String, dynamic>.from(raw));
      } catch (e) {
        debugPrint('[Plan Mirror] bad plan json: $e');
        return null;
      }
    }
    return null;
  }
}

class CloudPlanList {
  const CloudPlanList({required this.plans, required this.revisions});

  final List<BusinessPlanDocument> plans;
  final Map<String, int> revisions;
}

enum MirrorWriteStatus { ok, conflict, tombstoned, skipped, failed }

class MirrorWriteResult {
  const MirrorWriteResult._(
    this.status, {
    this.revision,
    this.observedCloudRevision,
  });

  final MirrorWriteStatus status;
  final int? revision;

  /// Observed cloud revision on conflict (diagnostic only — not a write base).
  final int? observedCloudRevision;

  bool get succeeded => status == MirrorWriteStatus.ok;

  static MirrorWriteResult ok(int revision) =>
      MirrorWriteResult._(MirrorWriteStatus.ok, revision: revision);

  static MirrorWriteResult conflict({int? observedCloudRevision}) =>
      MirrorWriteResult._(
        MirrorWriteStatus.conflict,
        observedCloudRevision: observedCloudRevision,
      );

  static const tombstoned = MirrorWriteResult._(MirrorWriteStatus.tombstoned);
  static const skipped = MirrorWriteResult._(MirrorWriteStatus.skipped);
  static const failed = MirrorWriteResult._(MirrorWriteStatus.failed);
}

class BackfillResult {
  const BackfillResult({
    required this.attempted,
    required this.created,
    required this.skippedExisting,
    required this.failed,
    required this.signedIn,
  });

  final int attempted;
  final int created;
  final int skippedExisting;
  final int failed;
  final bool signedIn;

  bool get ok => signedIn && failed == 0;
}
