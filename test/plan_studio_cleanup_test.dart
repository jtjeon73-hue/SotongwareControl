import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/business_plan_mirror.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/pc_workspace_ui.dart';
import 'package:sotong_ware_control/services/plan_execution_status.dart';
import 'package:sotong_ware_control/services/plan_library_management.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/plan_sync_meta.dart';
import 'package:sotong_ware_control/services/plan_user_facing_status.dart';

BusinessPlanDocument _plan({
  required String id,
  required String topic,
  String status = PlanningStatus.draft,
  String instructionId = '',
  String checksum = '',
  List<String> tags = const [],
  String libraryState = PlanLibraryState.active,
  bool isProtected = false,
  String customer = '고객',
  String updatedAt = '2026-08-13T00:00:00.000Z',
  String? lastTransferMode,
  String? lastRemoteJobId,
  String? lastRemoteCommandId,
}) {
  return BusinessPlanDocument(
    id: id,
    status: status,
    version: 1,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    input: BusinessPlanInput(
      topic: topic,
      customerProblem: '문제',
      targetCustomer: customer,
      desiredOutcome: '목적',
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [ArtifactType.ebook],
    ),
    instructionId: instructionId.isEmpty ? 'wi_$id' : instructionId,
    instruction: instructionId.isEmpty
        ? null
        : WorkInstruction(
            schemaVersion: '1.0',
            instructionId: instructionId,
            projectId: 'proj',
            instructionVersion: '1',
            createdAt: updatedAt,
            updatedAt: updatedAt,
            businessIdea: topic,
            businessPurpose: '목적',
            customerProblem: '문제',
            targetCustomer: customer,
            deliverableTypes: const ['ebook'],
            recommendedSequence: const ['ebook'],
            valueProposition: 'v',
            requiredMaterials: const [],
            workflowSteps: const [],
            completionCriteria: const [],
            qualityChecks: const [],
            risks: const [],
            monetizationOptions: const [],
            deploymentTargets: const [],
            promotionChannels: const [],
            approvalItems: const [],
            executionStatus: 'draft',
            artifactType: 'ebook',
            checksum: checksum,
          ),
    tags: tags,
    libraryState: libraryState,
    isProtected: isProtected,
    lastTransferMode: lastTransferMode,
    lastRemoteJobId: lastRemoteJobId,
    lastRemoteCommandId: lastRemoteCommandId,
  );
}

void main() {
  test('same checksum different planId is NOT auto-archived', () {
    final a = _plan(
      id: 'plan_a',
      topic: '동일내용 A',
      instructionId: 'wi_a',
      checksum: 'same_cs',
    );
    final b = _plan(
      id: 'plan_b',
      topic: '동일내용 B',
      instructionId: 'wi_b',
      checksum: 'same_cs',
    );
    final groups = PlanLibraryManagement.findDuplicateGroups([a, b]);
    expect(groups.any((g) => g.strongChecksumMatch), isTrue);

    final out = PlanLibraryManagement.softMarkDuplicateCleanup([a, b]);
    final byId = {for (final p in out) p.id: p};
    expect(byId['plan_a']!.isLibraryArchived, isFalse);
    expect(byId['plan_b']!.isLibraryArchived, isFalse);
  });

  test('lineage + same checksum archives non-representative clone', () {
    final parent = _plan(
      id: 'plan_parent',
      topic: '원본',
      instructionId: 'wi_parent',
      checksum: 'lin_cs',
      updatedAt: '2026-08-13T02:00:00.000Z',
    );
    final clone = _plan(
      id: 'plan_clone',
      topic: '원본',
      instructionId: 'wi_clone',
      checksum: 'lin_cs',
      tags: const ['cloneOf:plan_parent', 'sourcePlanId:plan_parent'],
      updatedAt: '2026-08-12T02:00:00.000Z',
    );
    final out = PlanLibraryManagement.softMarkDuplicateCleanup([parent, clone]);
    final byId = {for (final p in out) p.id: p};
    expect(byId['plan_parent']!.isLibraryArchived, isFalse);
    expect(byId['plan_clone']!.isLibraryArchived, isTrue);
  });

  test('protected and active plan are never auto-archived', () {
    final parent = _plan(
      id: 'plan_ops',
      topic: '운영',
      instructionId: 'wi_plan_1785905165067',
      checksum: 'ops_cs',
      updatedAt: '2026-08-13T03:00:00.000Z',
    );
    final clone = _plan(
      id: 'plan_clone_ops',
      topic: '운영',
      instructionId: 'wi_clone_ops',
      checksum: 'ops_cs',
      tags: const ['sourcePlanId:plan_ops'],
      isProtected: true,
      updatedAt: '2026-08-12T03:00:00.000Z',
    );
    final activeClone = _plan(
      id: 'plan_active_clone',
      topic: '운영',
      instructionId: 'wi_active_clone',
      checksum: 'ops_cs',
      tags: const ['cloneOf:plan_ops'],
      updatedAt: '2026-08-11T03:00:00.000Z',
    );

    final out = PlanLibraryManagement.softMarkDuplicateCleanup([
      parent,
      clone,
      activeClone,
    ], activePlanId: 'plan_active_clone');
    final byId = {for (final p in out) p.id: p};
    expect(byId['plan_ops']!.isLibraryArchived, isFalse);
    expect(byId['plan_clone_ops']!.isLibraryArchived, isFalse);
    expect(byId['plan_active_clone']!.isLibraryArchived, isFalse);
  });

  test('ops instruction id is never archived even as non-representative', () {
    final newer = _plan(
      id: 'plan_newer',
      topic: '운영복제',
      instructionId: 'wi_newer',
      checksum: 'x',
      tags: const ['sourcePlanId:plan_ops2'],
      updatedAt: '2026-08-14T00:00:00.000Z',
    );
    final ops = _plan(
      id: 'plan_ops2',
      topic: '운영복제',
      instructionId: 'wi_plan_1785905165067',
      checksum: 'x',
      updatedAt: '2026-08-10T00:00:00.000Z',
    );
    final out = PlanLibraryManagement.softMarkDuplicateCleanup([newer, ops]);
    final byId = {for (final p in out) p.id: p};
    expect(byId['plan_ops2']!.isLibraryArchived, isFalse);
  });

  test('working/delivered/awaitingApproval never auto-archived', () {
    final parent = _plan(
      id: 'plan_p',
      topic: '동일',
      checksum: 'cs',
      updatedAt: '2026-08-14T00:00:00.000Z',
    );
    final working = _plan(
      id: 'plan_working',
      topic: '동일',
      checksum: 'cs',
      status: PlanningStatus.inProgress,
      tags: const ['cloneOf:plan_p'],
      updatedAt: '2026-08-10T00:00:00.000Z',
    );
    final delivered = _plan(
      id: 'plan_delivered',
      topic: '동일',
      checksum: 'cs',
      status: PlanningStatus.transferred,
      tags: const ['cloneOf:plan_p'],
      updatedAt: '2026-08-09T00:00:00.000Z',
    );
    final waiting = _plan(
      id: 'plan_waiting',
      topic: '동일',
      checksum: 'cs',
      status: PlanningStatus.validationRequired,
      tags: const ['cloneOf:plan_p'],
      updatedAt: '2026-08-08T00:00:00.000Z',
    );
    final out = PlanLibraryManagement.softMarkDuplicateCleanup([
      parent,
      working,
      delivered,
      waiting,
    ]);
    final byId = {for (final p in out) p.id: p};
    expect(byId['plan_working']!.isLibraryArchived, isFalse);
    expect(byId['plan_delivered']!.isLibraryArchived, isFalse);
    expect(byId['plan_waiting']!.isLibraryArchived, isFalse);
  });

  test(
    'backfill createIfAbsent is idempotent and does not overwrite',
    () async {
      final memory = <String, Map<String, dynamic>>{};
      final mirror = BusinessPlanMirrorService(memory: memory);
      final original = _plan(
        id: 'plan_m1',
        topic: '원본 제목',
        instructionId: 'wi_plan_m1',
      );
      final changed = _plan(
        id: 'plan_m1',
        topic: '덮어쓰면 안 됨',
        instructionId: 'wi_plan_m1',
      );

      expect(
        await mirror.createIfAbsent(original, ownerUid: 'uid_test'),
        isTrue,
      );
      expect(
        await mirror.createIfAbsent(changed, ownerUid: 'uid_test'),
        isTrue,
      );

      final listed = await mirror.listPlans(ownerUid: 'uid_test');
      expect(listed.length, 1);
      expect(listed.first.input.topic, '원본 제목');
    },
  );

  test(
    'permanent delete tombstone prevents cloud resurrection on load',
    () async {
      SharedPreferences.setMockInitialValues({});
      final memory = <String, Map<String, dynamic>>{};
      final mirror = BusinessPlanMirrorService(
        memory: memory,
        ownerUidResolver: () => 'uid_a',
      );
      final store = BusinessPlanningStore(mirror: mirror);
      final plan = _plan(
        id: 'plan_del',
        topic: '삭제대상',
        instructionId: 'wi_del',
      );

      await store.savePlans([plan]);
      expect((await mirror.upsertPlan(plan)).succeeded, isTrue);
      expect((await mirror.listPlans()).length, 1);

      await store.deletePlans(['plan_del']);
      await store.savePlans([plan]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(BusinessPlanningStore.deletedIdsKey),
        contains('plan_del'),
      );

      final loaded = await store.loadPlans(activeContextReady: true);
      expect(loaded.map((p) => p.id), isNot(contains('plan_del')));
      expect(await mirror.listDeletedPlanIds(), {'plan_del'});
      expect(await mirror.listPlans(), isEmpty);

      expect(
        (await mirror.upsertPlan(plan)).status,
        MirrorWriteStatus.tombstoned,
      );
      expect(await mirror.createIfAbsent(plan), isTrue);
      expect(await mirror.listPlans(), isEmpty);
    },
  );

  test(
    'revision OCC: reversed network completion keeps newer payload',
    () async {
      final memory = <String, Map<String, dynamic>>{};
      final mirror = BusinessPlanMirrorService(memory: memory);
      final oldPayload = _plan(
        id: 'plan_rev',
        topic: '오래된',
        updatedAt: '2026-08-13T21:00:00.000+09:00',
      );
      final newPayload = _plan(
        id: 'plan_rev',
        topic: '최신',
        updatedAt: '2026-08-13T10:00:00.000Z',
      );

      final r1 = await mirror.upsertPlan(newPayload, ownerUid: 'uid_b');
      expect(r1.succeeded, isTrue);
      expect(r1.revision, 1);

      final r2 = await mirror.upsertPlan(
        oldPayload,
        ownerUid: 'uid_b',
        baseRevision: 0,
      );
      expect(r2.status, MirrorWriteStatus.conflict);
      expect(mirror.knownRevisions['plan_rev'], 1);
      expect(mirror.isWriteBlocked('plan_rev'), isTrue);
      expect(
        (await mirror.listPlans(ownerUid: 'uid_b')).single.input.topic,
        '최신',
      );
    },
  );

  test('same-device enqueueUpsert A then B keeps B', () async {
    final memory = <String, Map<String, dynamic>>{};
    final mirror = BusinessPlanMirrorService(
      memory: memory,
      ownerUidResolver: () => 'uid_q',
    );
    final a = _plan(id: 'plan_q', topic: 'A');
    final b = _plan(id: 'plan_q', topic: 'B');

    await Future.wait([mirror.enqueueUpsert(a), mirror.enqueueUpsert(b)]);
    expect((await mirror.listPlans(ownerUid: 'uid_q')).single.input.topic, 'B');
  });

  test(
    'cross-device conflict: stale reenqueue never becomes revision 3',
    () async {
      final memory = <String, Map<String, dynamic>>{};
      final deviceA = BusinessPlanMirrorService(
        memory: memory,
        ownerUidResolver: () => 'uid_x',
      );
      final deviceB = BusinessPlanMirrorService(
        memory: memory,
        ownerUidResolver: () => 'uid_x',
      );

      expect(
        (await deviceA.upsertPlan(_plan(id: 'plan_x', topic: 'v1'))).revision,
        1,
      );
      expect(
        (await deviceA.upsertPlan(
          _plan(id: 'plan_x', topic: 'A-latest'),
          baseRevision: 1,
        )).revision,
        2,
      );

      final stale = _plan(id: 'plan_x', topic: 'B-stale');
      final lost = await deviceB.upsertPlan(stale, baseRevision: 1);
      expect(lost.status, MirrorWriteStatus.conflict);
      expect(deviceB.knownRevisions.containsKey('plan_x'), isFalse);
      expect(deviceB.isWriteBlocked('plan_x'), isTrue);

      final retry = await deviceB.enqueueUpsert(stale);
      expect(retry.status, MirrorWriteStatus.conflict);
      expect(memory['uid_x__plan_x']!['revision'], 2);
      expect(
        Map<String, dynamic>.from(
          memory['uid_x__plan_x']!['plan'] as Map,
        )['input']['topic'],
        'A-latest',
      );

      deviceB.acceptCloudRevision('plan_x', 2);
      final neu = await deviceB.upsertPlan(
        _plan(id: 'plan_x', topic: 'C-new'),
        baseRevision: 2,
      );
      expect(neu.revision, 3);
      expect(
        Map<String, dynamic>.from(
          memory['uid_x__plan_x']!['plan'] as Map,
        )['input']['topic'],
        'C-new',
      );
    },
  );

  test('store→mirror path: conflict blocks autosave overwrite', () async {
    SharedPreferences.setMockInitialValues({});
    final memory = <String, Map<String, dynamic>>{};
    final mirror = BusinessPlanMirrorService(
      memory: memory,
      ownerUidResolver: () => 'uid_s',
    );
    final store = BusinessPlanningStore(mirror: mirror);

    expect((await mirror.upsertPlan(_plan(id: 'ps', topic: 'v1'))).revision, 1);
    expect(
      (await mirror.upsertPlan(
        _plan(id: 'ps', topic: 'A'),
        baseRevision: 1,
      )).revision,
      2,
    );

    mirror.knownRevisions.remove('ps');
    final conflict = await mirror.upsertPlan(
      _plan(id: 'ps', topic: 'B-stale'),
      baseRevision: 1,
    );
    expect(conflict.status, MirrorWriteStatus.conflict);

    await store.upsertPlan(_plan(id: 'ps', topic: 'B-stale-retry'));
    await Future<void>.delayed(Duration.zero);
    expect(memory['uid_s__ps']!['revision'], 2);
    expect(
      Map<String, dynamic>.from(
        memory['uid_s__ps']!['plan'] as Map,
      )['input']['topic'],
      'A',
    );

    await store.loadPlans(activeContextReady: true, runCleanup: false);
    expect(mirror.isWriteBlocked('ps'), isFalse);
    mirror.acceptCloudRevision('ps', 2);
    expect(
      (await mirror.upsertPlan(
        _plan(id: 'ps', topic: 'C'),
        baseRevision: 2,
      )).revision,
      3,
    );
  });

  test('timestamp offset strings do not drive freshness', () async {
    final memory = <String, Map<String, dynamic>>{};
    final mirror = BusinessPlanMirrorService(memory: memory);
    final first = _plan(
      id: 'plan_tz',
      topic: 'first',
      updatedAt: '2026-08-13T00:00:00.000Z',
    );
    final spoof = _plan(
      id: 'plan_tz',
      topic: 'spoof',
      updatedAt: '2026-08-13T12:00:00.000+09:00',
    );
    expect((await mirror.upsertPlan(first, ownerUid: 'u')).succeeded, isTrue);
    final r = await mirror.upsertPlan(spoof, ownerUid: 'u', baseRevision: 0);
    expect(r.status, MirrorWriteStatus.conflict);
    expect(mirror.knownRevisions['plan_tz'], 1);
    expect((await mirror.listPlans(ownerUid: 'u')).single.input.topic, 'first');
  });

  test('merge prefers revision/sync meta over updatedAt string order', () {
    final local = _plan(
      id: 'pm',
      topic: 'local-dirty',
      updatedAt: '2026-08-13T23:00:00.000+09:00',
    );
    final cloud = _plan(
      id: 'pm',
      topic: 'cloud',
      updatedAt: '2026-08-13T01:00:00.000Z',
    );
    final merged = BusinessPlanningStore.mergeLocalAndCloudForTest(
      local: [local],
      cloud: [cloud],
      cloudRevisions: const {'pm': 5},
      syncMeta: {
        'pm': const PlanSyncMeta(baseRevision: 2, state: PlanSyncMeta.dirty),
      },
    );
    expect(merged.plans.single.input.topic, 'cloud');
    expect(merged.acceptedRevisions['pm'], 5);

    final merged2 = BusinessPlanningStore.mergeLocalAndCloudForTest(
      local: [local],
      cloud: [cloud],
      cloudRevisions: const {'pm': 2},
      syncMeta: {
        'pm': const PlanSyncMeta(baseRevision: 2, state: PlanSyncMeta.dirty),
      },
    );
    expect(merged2.plans.single.input.topic, 'local-dirty');
  });

  test(
    'applyAfterCommit: failure does not update revision side effects',
    () async {
      var accepts = 0;
      try {
        await BusinessPlanMirrorService.applyAfterCommit<int>(
          run: () async => throw StateError('txn failed'),
          onCommitted: (_) => accepts++,
        );
        fail('expected throw');
      } catch (_) {}
      expect(accepts, 0);
    },
  );

  test(
    'applyAfterCommit: success applies side effect once after commit',
    () async {
      var accepts = 0;
      var logicalPasses = 0;
      final rev = await BusinessPlanMirrorService.applyAfterCommit<int>(
        run: () async {
          // Simulate callback retry work before outer commit returns.
          logicalPasses++;
          logicalPasses++;
          return 4;
        },
        onCommitted: (v) {
          accepts++;
          expect(v, 4);
        },
      );
      expect(rev, 4);
      expect(logicalPasses, 2);
      expect(accepts, 1);
    },
  );

  test(
    'markDeleted success accepts revision; foreign namespace leaves original intact',
    () async {
      final memory = <String, Map<String, dynamic>>{};
      final mirror = BusinessPlanMirrorService(memory: memory);
      await mirror.upsertPlan(
        _plan(id: 'own', topic: 'a'),
        ownerUid: 'owner_a',
      );
      expect(mirror.knownRevisions['own'], 1);

      await mirror.markDeleted('own', ownerUid: 'owner_b');
      expect(memory['owner_a__own']!['isDeleted'], isNot(true));
      expect(memory['owner_b__own']?['isDeleted'], isTrue);

      expect(await mirror.markDeleted('own', ownerUid: 'owner_a'), isTrue);
      expect(memory['owner_a__own']!['isDeleted'], isTrue);
      expect(mirror.knownRevisions['own'], 2);
    },
  );

  test('other owner cannot markDeleted foreign document', () async {
    final memory = <String, Map<String, dynamic>>{};
    final mirror = BusinessPlanMirrorService(memory: memory);
    final plan = _plan(id: 'plan_own', topic: '소유');
    await mirror.upsertPlan(plan, ownerUid: 'owner_a');
    await mirror.markDeleted('plan_own', ownerUid: 'owner_b');
    expect(memory['owner_a__plan_own']!['isDeleted'], isNot(true));
    expect((await mirror.listPlans(ownerUid: 'owner_a')).length, 1);
    expect(memory['owner_b__plan_own']?['isDeleted'], isTrue);
  });

  test(
    'delete crash-window: intent-before-remove still filters on load',
    () async {
      SharedPreferences.setMockInitialValues({});
      final memory = <String, Map<String, dynamic>>{};
      final mirror = BusinessPlanMirrorService(
        memory: memory,
        ownerUidResolver: () => 'uid_c',
      );
      final store = BusinessPlanningStore(mirror: mirror);
      final plan = _plan(id: 'plan_crash', topic: 'crash');
      await store.savePlans([plan]);
      await mirror.upsertPlan(plan);

      // Crash after delete intent, before local list removal.
      await store.deletePlansIntentOnlyForTest(['plan_crash']);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(BusinessPlanningStore.deletedIdsKey),
        contains('plan_crash'),
      );
      final stillLocal = await store.loadPlans(
        activeContextReady: false,
        runCleanup: false,
      );
      // loadPlans filters deletedIds even if plan row still persisted.
      expect(stillLocal.map((p) => p.id), isNot(contains('plan_crash')));
    },
  );

  test('PlanUserFacingStatus.label covers all required statuses', () {
    final cases = <String, BusinessPlanDocument>{
      PlanUserFacingStatus.planning: BusinessPlanDocument(
        id: '1',
        status: PlanningStatus.draft,
        version: 1,
        createdAt: '2026-08-13T00:00:00.000Z',
        updatedAt: '2026-08-13T00:00:00.000Z',
        input: BusinessPlanInput(
          topic: 'a',
          customerProblem: '문제',
          targetCustomer: '고객',
          desiredOutcome: '목적',
          artifactType: ArtifactType.ebook,
          deliverableTypes: const [ArtifactType.ebook],
          wizardSelections: const {'step': 6},
        ),
        instructionId: 'wi_1',
      ),
      PlanUserFacingStatus.instructionDesign: _plan(id: '1b', topic: 'a'),
      PlanUserFacingStatus.instructionReady: _plan(
        id: '2',
        topic: 'a',
        status: PlanningStatus.instructionReady,
        instructionId: 'wi_2',
      ),
      PlanUserFacingStatus.deliveredNotRun: _plan(
        id: '3',
        topic: 'a',
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.remoteMode,
        lastRemoteJobId: 'job_3',
        lastRemoteCommandId: 'cmd_3',
      ),
      PlanUserFacingStatus.working: _plan(
        id: '4',
        topic: 'a',
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.folderMode,
        instructionId: 'wi_4',
      ),
      PlanUserFacingStatus.awaitingApproval: _plan(
        id: '5',
        topic: 'a',
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.folderMode,
        instructionId: 'wi_5',
      ),
      PlanUserFacingStatus.completed: _plan(
        id: '6',
        topic: 'a',
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.folderMode,
        instructionId: 'wi_6',
      ),
      PlanUserFacingStatus.deferred: _plan(
        id: '7',
        topic: 'a',
        tags: const ['보류'],
      ),
      PlanUserFacingStatus.archived: _plan(
        id: '8',
        topic: 'a',
        libraryState: PlanLibraryState.archived,
      ),
      PlanUserFacingStatus.cleanup: _plan(
        id: '9',
        topic: 'a',
        tags: const ['정리대상'],
      ),
    };
    PlanExecutionSnapshot? executionFor(
      String label,
      BusinessPlanDocument plan,
    ) {
      switch (label) {
        case PlanUserFacingStatus.working:
          return PlanExecutionStatusResolver.resolve(
            plan,
            remoteProject: Sotong24RemoteProject(
              projectId: 'wi_4',
              title: '작업중',
              productType: ArtifactType.ebook,
              currentStage: 7,
              totalStages: 18,
              progress: 40,
              status: Sotong24WorkStatus.inProgress,
              startedAt: '2026-08-06T10:10:00+09:00',
            ),
          );
        case PlanUserFacingStatus.awaitingApproval:
          return PlanExecutionStatusResolver.resolve(
            plan,
            remoteProject: Sotong24RemoteProject(
              projectId: 'wi_5',
              title: '승인대기',
              productType: ArtifactType.ebook,
              currentStage: 18,
              totalStages: 18,
              progress: 95,
              status: Sotong24WorkStatus.awaitingApproval,
              approvalStatus: ApprovalStatus.pending,
              startedAt: '2026-08-06T10:10:00+09:00',
            ),
          );
        case PlanUserFacingStatus.completed:
          return PlanExecutionStatusResolver.resolve(
            plan,
            remoteProject: Sotong24RemoteProject(
              projectId: 'wi_6',
              title: '완료',
              productType: ArtifactType.ebook,
              currentStage: 18,
              totalStages: 18,
              progress: 100,
              status: Sotong24WorkStatus.completed,
              startedAt: '2026-08-06T10:10:00+09:00',
            ),
          );
        default:
          return null;
      }
    }

    for (final entry in cases.entries) {
      expect(
        PlanUserFacingStatus.label(
          entry.value,
          execution: executionFor(entry.key, entry.value),
        ),
        entry.key,
      );
    }
    expect(
      PlanUserFacingStatus.label(
        _plan(
          id: '10',
          topic: 'a',
          status: PlanningStatus.transferred,
          lastTransferMode: PlanProgressStatus.folderMode,
          instructionId: 'wi_10',
          tags: const ['승인대기'],
        ),
        execution: PlanExecutionStatusResolver.resolve(
          _plan(
            id: '10',
            topic: 'a',
            status: PlanningStatus.transferred,
            lastTransferMode: PlanProgressStatus.folderMode,
            instructionId: 'wi_10',
            tags: const ['승인대기'],
          ),
          remoteProject: Sotong24RemoteProject(
            projectId: 'wi_10',
            title: '승인대기',
            productType: ArtifactType.ebook,
            currentStage: 18,
            totalStages: 18,
            progress: 95,
            status: Sotong24WorkStatus.awaitingApproval,
            approvalStatus: ApprovalStatus.pending,
            startedAt: '2026-08-06T10:10:00+09:00',
          ),
        ),
      ),
      PlanUserFacingStatus.awaitingApproval,
    );
  });

  test('showPcLocalFolderSettings hides on mobile platforms and narrow', () {
    expect(
      showPcLocalFolderSettings(
        fsaSupported: true,
        widthPx: 1400,
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      showPcLocalFolderSettings(
        fsaSupported: true,
        widthPx: 1200,
        isWeb: true,
        platform: TargetPlatform.windows,
      ),
      isTrue,
    );
  });

  test('PC 작업환경 상태: Agent/Relay 정상이면 DevWorkDoc·Inbox 미연결을 전체 장애로 표시하지 않음', () {
    final ok = resolvePcWorkspaceStatusCopy(
      fsaSupported: true,
      agentOnline: true,
      hasAnyAgent: true,
      devFolderReady: false,
      inboxReady: false,
    );
    expect(ok.headline, '원격 작업 전달 정상');
    expect(ok.agentLine, '소통24워크 Agent  ● 온라인');
    expect(ok.devWorkDocLine, 'DevWorkDoc  재연결 필요');
    expect(ok.showInboxUnconnectedWarning, isFalse);

    final offline = resolvePcWorkspaceStatusCopy(
      fsaSupported: true,
      agentOnline: false,
      hasAnyAgent: true,
      devFolderReady: false,
      inboxReady: false,
    );
    expect(offline.headline, '소통24워크 Agent 재연결 필요');
    expect(offline.agentLine, '소통24워크 Agent  · 오프라인');
    expect(offline.showInboxUnconnectedWarning, isTrue);
  });

  test('운영 WI wi_plan_1785905165067 보호·표시 규칙 (데이터 변경 없음)', () {
    const opsId = 'wi_plan_1785905165067';
    expect(PlanUserFacingStatus.isProtectedInstruction(opsId), isTrue);
    final base = _plan(
      id: 'plan_ops',
      topic: '가이드 전자책개발',
      instructionId: opsId,
      tags: const ['보류'],
    );
    final wi = base.instruction!;
    final staleTopic = base.copyWith(
      instruction: WorkInstruction(
        schemaVersion: wi.schemaVersion,
        instructionId: wi.instructionId,
        projectId: wi.projectId,
        instructionVersion: wi.instructionVersion,
        createdAt: wi.createdAt,
        updatedAt: wi.updatedAt,
        businessIdea: '50대 초보도 따라 하는 AI 전자책 첫 출간',
        businessPurpose: wi.businessPurpose,
        customerProblem: wi.customerProblem,
        targetCustomer: wi.targetCustomer,
        deliverableTypes: wi.deliverableTypes,
        recommendedSequence: wi.recommendedSequence,
        valueProposition: wi.valueProposition,
        requiredMaterials: wi.requiredMaterials,
        workflowSteps: wi.workflowSteps,
        completionCriteria: wi.completionCriteria,
        qualityChecks: wi.qualityChecks,
        risks: wi.risks,
        monetizationOptions: wi.monetizationOptions,
        deploymentTargets: wi.deploymentTargets,
        promotionChannels: wi.promotionChannels,
        approvalItems: wi.approvalItems,
        executionStatus: wi.executionStatus,
        artifactType: wi.artifactType,
        checksum: wi.checksum,
      ),
    );
    expect(
      PlanLibraryManagement.displayTitle(staleTopic),
      '50대 초보도 따라 하는 AI 전자책 첫 출간',
    );
    expect(staleTopic.input.topic, '가이드 전자책개발');
    final opsExec = PlanExecutionStatusResolver.resolve(
      staleTopic.copyWith(
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.folderMode,
      ),
      remoteProject: Sotong24RemoteProject(
        projectId: opsId,
        title: '50대 초보도 따라 하는 AI 전자책 첫 출간',
        productType: ArtifactType.ebook,
        currentStage: 18,
        totalStages: 18,
        progress: 90,
        status: Sotong24WorkStatus.awaitingApproval,
        approvalStatus: ApprovalStatus.pending,
        startedAt: '2026-08-06T10:10:00+09:00',
      ),
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        staleTopic,
        execution: opsExec,
      ),
      isTrue,
    );
  });

  test(
    'bootstrapSession restores active before cleanup (draft active protected)',
    () async {
      SharedPreferences.setMockInitialValues({
        BusinessPlanningStore.activePlanIdKey: 'plan_to_protect',
      });
      final memory = <String, Map<String, dynamic>>{};
      final mirror = BusinessPlanMirrorService(memory: memory);
      final store = BusinessPlanningStore(mirror: mirror);

      final parent = _plan(
        id: 'plan_parent_active',
        topic: '동일',
        checksum: 'act_cs',
        status: PlanningStatus.draft,
        updatedAt: '2026-08-13T05:00:00.000Z',
      );
      final activeClone = _plan(
        id: 'plan_to_protect',
        topic: '동일',
        checksum: 'act_cs',
        status: PlanningStatus.draft,
        tags: const ['cloneOf:plan_parent_active'],
        updatedAt: '2026-08-10T05:00:00.000Z',
      );
      await store.savePlans([parent, activeClone]);

      // Simulate prior bug: load without active context must NOT set cleanup flag.
      await store.loadPlans(activeContextReady: false, runCleanup: false);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(BusinessPlanningStore.cleanupAppliedKey),
        isNot(true),
      );

      final boot = await BusinessPlanningStore.bootstrapSession(store);
      expect(boot.activePlanId, 'plan_to_protect');
      final byId = {for (final p in boot.plans) p.id: p};
      expect(byId['plan_to_protect']!.isLibraryArchived, isFalse);
      expect(prefs.getBool(BusinessPlanningStore.cleanupAppliedKey), isTrue);
    },
  );

  test(
    'list UI keeps weak title duplicates active; only filter hides archived',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = BusinessPlanningStore();
      final plans = [
        _plan(
          id: 'g_new',
          topic: '가이드 전자책개발',
          updatedAt: '2026-08-13T12:00:00.000Z',
        ),
        _plan(
          id: 'g_old1',
          topic: '가이드 전자책개발',
          updatedAt: '2026-08-05T13:48:00.000Z',
        ),
        _plan(
          id: 'g_old2',
          topic: '가이드 전자책개발',
          updatedAt: '2026-08-05T13:40:00.000Z',
        ),
      ];
      await store.savePlans(plans);

      final boot = await BusinessPlanningStore.bootstrapSession(store);
      final byId = {for (final p in boot.plans) p.id: p};
      expect(byId['g_new']!.isLibraryArchived, isFalse);
      expect(byId['g_old1']!.isLibraryArchived, isFalse);
      expect(byId['g_old2']!.isLibraryArchived, isFalse);

      final all = PlanLibraryManagement.applyManageFilter(boot.plans, 'all');
      expect(all.map((p) => p.id).toSet(), {'g_new', 'g_old1', 'g_old2'});

      final candidates = PlanLibraryManagement.applyManageFilter(
        boot.plans,
        'duplicate_candidates',
      );
      expect(candidates.length, 3);
    },
  );
}
