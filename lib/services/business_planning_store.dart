import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_planning.dart';
import 'business_plan_mirror.dart';
import 'plan_library_management.dart';
import 'plan_progress_status.dart';
import 'plan_sync_meta.dart';

/// 사업 기획안·작업지시서 로컬 저장 (SharedPreferences) + Firestore soft mirror.
/// Sync winner = revision + sync metadata (never updatedAt strings).
class BusinessPlanningStore {
  BusinessPlanningStore({BusinessPlanMirrorService? mirror})
    : _mirror = mirror ?? BusinessPlanMirrorService();

  static const plansKey = 'business_planning_plans_v1';
  static const draftInputKey = 'business_planning_draft_input_v1';
  static const cleanupAppliedKey = 'business_planning_cleanup_dup_v4';
  static const backfillAppliedKey = 'business_planning_cloud_backfill_v1';
  static const deletedIdsKey = 'business_planning_deleted_ids_v1';
  static const activePlanIdKey = 'business_planning_active_plan_id_v1';
  static const syncMetaKey = 'business_planning_sync_meta_v1';
  static const conflictSnapshotsKey = 'business_planning_conflict_snapshots_v1';
  static const failedTransferListCleanupKey =
      'business_planning_failed_transfer_list_cleanup_v1';
  static const parkedDraftInputKey = 'business_planning_parked_draft_input_v1';

  final BusinessPlanMirrorService _mirror;

  BusinessPlanMirrorService get mirror => _mirror;

  Future<List<BusinessPlanDocument>> _readLocalPlans(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(plansKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map(
          (e) => BusinessPlanDocument.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<Map<String, PlanSyncMeta>> _readSyncMeta(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(syncMetaKey);
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(
        k,
        PlanSyncMeta.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
  }

  Future<void> _writeSyncMeta(
    SharedPreferences prefs,
    Map<String, PlanSyncMeta> meta,
  ) async {
    await prefs.setString(
      syncMetaKey,
      jsonEncode(meta.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> _saveConflictSnapshot(
    SharedPreferences prefs,
    BusinessPlanDocument plan,
  ) async {
    final raw = prefs.getString(conflictSnapshotsKey);
    final map = raw == null || raw.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map[plan.id] = plan.toJson();
    await prefs.setString(conflictSnapshotsKey, jsonEncode(map));
  }

  Future<Set<String>> _localDeletedIds(SharedPreferences prefs) async {
    final list = prefs.getStringList(deletedIdsKey) ?? const [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> _addLocalDeletedIds(
    SharedPreferences prefs,
    Iterable<String> ids,
  ) async {
    final next = await _localDeletedIds(prefs);
    next.addAll(ids.map((e) => e.trim()).where((e) => e.isNotEmpty));
    await prefs.setStringList(deletedIdsKey, next.toList());
  }

  Future<String?> loadPersistedActivePlanId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = (prefs.getString(activePlanIdKey) ?? '').trim();
    return id.isEmpty ? null : id;
  }

  Future<void> persistActivePlanId(String? planId) async {
    final prefs = await SharedPreferences.getInstance();
    final id = (planId ?? '').trim();
    if (id.isEmpty) {
      await prefs.remove(activePlanIdKey);
    } else {
      await prefs.setString(activePlanIdKey, id);
    }
  }

  Future<PlanSyncMeta> syncMetaFor(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readSyncMeta(prefs);
    return all[planId] ?? PlanSyncMeta.defaults;
  }

  Future<List<BusinessPlanDocument>> loadPlans({
    String? activePlanId,
    bool activeContextReady = false,
    bool runCleanup = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var plans = await _readLocalPlans(prefs);
    var syncMeta = await _readSyncMeta(prefs);

    final cloudDeleted = await _mirror.listDeletedPlanIds();
    final localDeleted = await _localDeletedIds(prefs);
    final deleted = {...cloudDeleted, ...localDeleted};

    for (final id in localDeleted) {
      if (!cloudDeleted.contains(id)) {
        unawaited(_mirror.markDeleted(id));
      }
      syncMeta[id] = PlanSyncMeta(
        baseRevision: syncMeta[id]?.baseRevision ?? 0,
        state: PlanSyncMeta.deleted,
      );
    }

    final beforeTombstone = plans.length;
    if (deleted.isNotEmpty) {
      plans = plans.where((p) => !deleted.contains(p.id)).toList();
    }

    final cloudList = await _mirror.listPlansWithRevisions();
    if (cloudList.plans.isNotEmpty || cloudList.revisions.isNotEmpty) {
      // Preserve local snapshots before accepting cloud on conflict.
      for (final local in plans) {
        final cloudRev = cloudList.revisions[local.id];
        if (cloudRev == null) continue;
        final meta = syncMeta[local.id] ?? PlanSyncMeta.defaults;
        if (meta.isConflict ||
            (meta.isDirty && meta.baseRevision != cloudRev)) {
          await _saveConflictSnapshot(prefs, local);
        }
      }
      final cloudActive = cloudList.plans
          .where((c) => !deleted.contains(c.id))
          .toList();
      final merged = _mergeLocalAndCloud(
        local: plans,
        cloud: cloudActive,
        cloudRevisions: cloudList.revisions,
        syncMeta: syncMeta,
      );
      plans = merged.plans;
      syncMeta = merged.syncMeta;
      for (final e in merged.acceptedRevisions.entries) {
        _mirror.acceptCloudRevision(e.key, e.value);
      }
    }

    if (deleted.isNotEmpty) {
      plans = plans.where((p) => !deleted.contains(p.id)).toList();
    }

    await _writeSyncMeta(prefs, syncMeta);

    final reconciled = PlanProgressStatus.reconcileAll(plans);
    var deduped = dedupeById(reconciled);

    final resolvedActive =
        (activePlanId ?? await loadPersistedActivePlanId())?.trim() ?? '';
    final canCleanup =
        runCleanup &&
        activeContextReady &&
        prefs.getBool(cleanupAppliedKey) != true;

    if (canCleanup) {
      if (resolvedActive.isNotEmpty) {
        deduped = deduped.map((p) {
          if (p.id != resolvedActive) return p;
          if (!p.isLibraryArchived) return p;
          if (!p.tags.contains('정리대상') && !p.tags.contains('cleanup')) {
            return p;
          }
          return PlanLibraryManagement.restore(
            p,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          );
        }).toList();
      }

      final cleaned = PlanLibraryManagement.softMarkDuplicateCleanup(
        deduped,
        activePlanId: resolvedActive.isEmpty ? null : resolvedActive,
      );
      final changedCleanup = !_sameLibraryMeta(deduped, cleaned);
      if (changedCleanup) {
        deduped = cleaned;
        await savePlans(deduped);
      }
      await prefs.setBool(cleanupAppliedKey, true);
    }

    if (runCleanup &&
        activeContextReady &&
        prefs.getBool(failedTransferListCleanupKey) != true) {
      var changedFailed = false;
      deduped = deduped.map((p) {
        if (p.wasTransferred) return p;
        final status = PlanningStatus.normalize(p.status);
        final failedAttempt =
            status == PlanningStatus.transferFailed ||
            ((p.lastTransferAt ?? '').trim().isNotEmpty &&
                !p.hasRemoteDelivery);
        if (!failedAttempt) return p;
        changedFailed = true;
        final tags = List<String>.from(p.tags);
        if (!tags.contains('cleanup:failed_transfer_hidden')) {
          tags.add('cleanup:failed_transfer_hidden');
        }
        return p.copyWith(libraryState: PlanLibraryState.archived, tags: tags);
      }).toList();
      if (changedFailed) {
        await savePlans(deduped);
      }
      await prefs.setBool(failedTransferListCleanupKey, true);
    }

    if (prefs.getBool(backfillAppliedKey) != true) {
      // Only backfill synced/clean locals without cloud (meta base 0, not conflict).
      final candidates = deduped.where((p) {
        final m = syncMeta[p.id] ?? PlanSyncMeta.defaults;
        return !m.isConflict && !m.isDeleted;
      }).toList();
      final result = await _mirror.backfillMissing(candidates);
      if (!result.signedIn) {
        // Retry next load after sign-in.
      } else if (result.failed == 0) {
        await prefs.setBool(backfillAppliedKey, true);
      }
    }

    final changed =
        deduped.length != beforeTombstone ||
        deduped.length != plans.length ||
        !_sameStatuses(plans, deduped) ||
        (beforeTombstone != plans.length);
    if (changed || beforeTombstone != deduped.length) {
      await savePlans(deduped);
    }
    return deduped;
  }

  static Future<({List<BusinessPlanDocument> plans, String? activePlanId})>
  bootstrapSession(BusinessPlanningStore store) async {
    final persisted = await store.loadPersistedActivePlanId();
    var plans = await store.loadPlans(
      activePlanId: persisted,
      activeContextReady: false,
      runCleanup: false,
    );
    String? active = persisted;
    if (active != null && !plans.any((p) => p.id == active)) {
      active = null;
      await store.persistActivePlanId(null);
    }
    plans = await store.loadPlans(
      activePlanId: active,
      activeContextReady: true,
      runCleanup: true,
    );
    return (plans: plans, activePlanId: active);
  }

  /// Merge by revision + sync metadata. updatedAt is never the winner.
  /// Exposed for unit tests.
  static ({
    List<BusinessPlanDocument> plans,
    Map<String, PlanSyncMeta> syncMeta,
    Map<String, int> acceptedRevisions,
  })
  mergeLocalAndCloudForTest({
    required List<BusinessPlanDocument> local,
    required List<BusinessPlanDocument> cloud,
    required Map<String, int> cloudRevisions,
    required Map<String, PlanSyncMeta> syncMeta,
  }) => _mergeLocalAndCloud(
    local: local,
    cloud: cloud,
    cloudRevisions: cloudRevisions,
    syncMeta: syncMeta,
  );

  static ({
    List<BusinessPlanDocument> plans,
    Map<String, PlanSyncMeta> syncMeta,
    Map<String, int> acceptedRevisions,
  })
  _mergeLocalAndCloud({
    required List<BusinessPlanDocument> local,
    required List<BusinessPlanDocument> cloud,
    required Map<String, int> cloudRevisions,
    required Map<String, PlanSyncMeta> syncMeta,
  }) {
    final localById = {for (final p in local) p.id: p};
    final cloudById = {for (final p in cloud) p.id: p};
    final ids = {...localById.keys, ...cloudById.keys};
    final out = <String, BusinessPlanDocument>{};
    final metaOut = Map<String, PlanSyncMeta>.from(syncMeta);
    final accepted = <String, int>{};

    for (final id in ids) {
      final l = localById[id];
      final c = cloudById[id];
      final cloudRev = cloudRevisions[id] ?? 0;
      final meta = metaOut[id] ?? PlanSyncMeta.defaults;

      if (c == null && l != null) {
        // E: local only → keep (backfill candidate)
        out[id] = l;
        continue;
      }
      if (l == null && c != null) {
        // A: cloud only
        out[id] = c;
        metaOut[id] = PlanSyncMeta(
          baseRevision: cloudRev,
          state: PlanSyncMeta.synced,
        );
        accepted[id] = cloudRev;
        continue;
      }
      if (l == null || c == null) continue;

      if (meta.isConflict || (meta.isDirty && meta.baseRevision != cloudRev)) {
        // C: conflict — accept cloud into working set; local snapshot preserved separately.
        out[id] = c;
        metaOut[id] = PlanSyncMeta(
          baseRevision: cloudRev,
          state: PlanSyncMeta.synced,
        );
        accepted[id] = cloudRev;
        continue;
      }

      if (meta.isDirty && meta.baseRevision == cloudRev) {
        // B: pending local edit matching cloud base
        out[id] = l;
        continue;
      }

      // A: clean/synced → cloud wins
      out[id] = c;
      metaOut[id] = PlanSyncMeta(
        baseRevision: cloudRev,
        state: PlanSyncMeta.synced,
      );
      accepted[id] = cloudRev;
    }

    return (
      plans: out.values.toList(),
      syncMeta: metaOut,
      acceptedRevisions: accepted,
    );
  }

  static bool _sameLibraryMeta(
    List<BusinessPlanDocument> a,
    List<BusinessPlanDocument> b,
  ) {
    if (a.length != b.length) return false;
    final map = {for (final p in b) p.id: p};
    for (final p in a) {
      final o = map[p.id];
      if (o == null) return false;
      if (o.libraryState != p.libraryState) return false;
      if (o.tags.join('|') != p.tags.join('|')) return false;
    }
    return true;
  }

  static bool _sameStatuses(
    List<BusinessPlanDocument> a,
    List<BusinessPlanDocument> b,
  ) {
    if (a.length != b.length) return false;
    final map = {for (final p in b) p.id: p.status};
    for (final p in a) {
      if (map[p.id] != p.status) return false;
    }
    return true;
  }

  /// Dedupe identical planIds — keeps first; display sort uses updatedAt only.
  static List<BusinessPlanDocument> dedupeById(
    List<BusinessPlanDocument> plans,
  ) {
    final byId = <String, BusinessPlanDocument>{};
    for (final plan in plans) {
      byId.putIfAbsent(plan.id, () => plan);
    }
    return byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> savePlans(List<BusinessPlanDocument> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      plansKey,
      jsonEncode(dedupeById(plans).map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsertPlan(BusinessPlanDocument plan) async {
    final prefs = await SharedPreferences.getInstance();
    final deleted = {
      ...await _localDeletedIds(prefs),
      ...await _mirror.listDeletedPlanIds(),
    };
    if (deleted.contains(plan.id)) {
      return;
    }

    // Conflict blocks cloud push; local snapshot still saved to avoid data loss.
    final syncMeta = await _readSyncMeta(prefs);
    final prev = syncMeta[plan.id] ?? PlanSyncMeta.defaults;
    if (prev.isConflict || _mirror.isWriteBlocked(plan.id)) {
      await _saveConflictSnapshot(prefs, plan);
      // Do not enqueue stale/blocked writes.
      final plans = await _readLocalPlans(prefs);
      final filtered = plans.where((p) => !deleted.contains(p.id)).toList();
      final index = filtered.indexWhere((p) => p.id == plan.id);
      if (index >= 0) {
        filtered[index] = plan;
      } else {
        filtered.insert(0, plan);
      }
      await savePlans(filtered);
      return;
    }

    final plans = await _readLocalPlans(prefs);
    final filtered = plans.where((p) => !deleted.contains(p.id)).toList();
    final index = filtered.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      filtered[index] = plan;
    } else {
      filtered.insert(0, plan);
    }
    await savePlans(filtered);
    await persistActivePlanId(plan.id);

    syncMeta[plan.id] = PlanSyncMeta(
      baseRevision: prev.baseRevision,
      state: PlanSyncMeta.dirty,
    );
    await _writeSyncMeta(prefs, syncMeta);

    unawaited(
      _mirror.enqueueUpsert(plan).then((result) async {
        final prefs2 = await SharedPreferences.getInstance();
        final meta2 = await _readSyncMeta(prefs2);
        if (result.succeeded && result.revision != null) {
          meta2[plan.id] = PlanSyncMeta(
            baseRevision: result.revision!,
            state: PlanSyncMeta.synced,
          );
          await _writeSyncMeta(prefs2, meta2);
        } else if (result.status == MirrorWriteStatus.conflict ||
            result.status == MirrorWriteStatus.tombstoned) {
          final localPlans = await _readLocalPlans(prefs2);
          final snap = localPlans.where((p) => p.id == plan.id);
          if (snap.isNotEmpty) {
            await _saveConflictSnapshot(prefs2, snap.first);
          }
          meta2[plan.id] = PlanSyncMeta(
            baseRevision: prev.baseRevision,
            state: PlanSyncMeta.conflict,
          );
          await _writeSyncMeta(prefs2, meta2);
        }
      }),
    );
  }

  Future<void> upsertPlans(Iterable<BusinessPlanDocument> updates) async {
    for (final u in updates) {
      await upsertPlan(u);
    }
  }

  static List<BusinessPlanDocument> latestByInstructionId(
    List<BusinessPlanDocument> plans, {
    bool includeArchived = false,
    bool includeTrashed = false,
  }) {
    final map = <String, BusinessPlanDocument>{};
    for (final plan in plans) {
      if (!includeTrashed && plan.isLibraryTrashed) continue;
      final status = PlanningStatus.normalize(plan.status);
      if (!includeArchived &&
          (status == PlanningStatus.archived || plan.isLibraryArchived)) {
        continue;
      }
      final key = plan.stableInstructionId;
      final existing = map[key];
      if (existing == null || plan.version > existing.version) {
        map[key] = plan;
      } else if (plan.version == existing.version) {
        // Display tie-break only.
        if (plan.updatedAt.compareTo(existing.updatedAt) >= 0) {
          map[key] = plan;
        }
      }
    }
    return map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> deletePlan(String id) async {
    await deletePlans([id]);
  }

  Future<void> deletePlans(Iterable<String> ids) async {
    final idSet = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (idSet.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    await _addLocalDeletedIds(prefs, idSet);
    final syncMeta = await _readSyncMeta(prefs);
    for (final id in idSet) {
      syncMeta[id] = PlanSyncMeta(
        baseRevision: syncMeta[id]?.baseRevision ?? 0,
        state: PlanSyncMeta.deleted,
      );
      await _mirror.markDeleted(id);
    }
    await _writeSyncMeta(prefs, syncMeta);

    final plans = await _readLocalPlans(prefs);
    plans.removeWhere((p) => idSet.contains(p.id));
    await savePlans(plans);

    final active = await loadPersistedActivePlanId();
    if (active != null && idSet.contains(active)) {
      await persistActivePlanId(null);
    }
  }

  Future<void> deletePlansIntentOnlyForTest(Iterable<String> ids) async {
    final idSet = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (idSet.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await _addLocalDeletedIds(prefs, idSet);
  }

  Future<BusinessPlanInput?> loadDraftInput() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftInputKey);
    if (raw == null || raw.isEmpty) return null;
    return BusinessPlanInput.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> saveDraftInput(BusinessPlanInput input) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(draftInputKey, jsonEncode(input.toJson()));
  }

  Future<BusinessPlanInput?> loadParkedDraftInput() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(parkedDraftInputKey);
    if (raw == null || raw.isEmpty) return null;
    return BusinessPlanInput.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> saveParkedDraftInput(BusinessPlanInput? input) async {
    final prefs = await SharedPreferences.getInstance();
    if (input == null) {
      await prefs.remove(parkedDraftInputKey);
      return;
    }
    await prefs.setString(parkedDraftInputKey, jsonEncode(input.toJson()));
  }

  static String newPlanId([DateTime? now]) {
    final stamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return 'plan_$stamp';
  }
}
