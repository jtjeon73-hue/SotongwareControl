import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/services/business_plan_mirror.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/plan_execution_status.dart';
import 'package:sotong_ware_control/services/plan_library_management.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/plan_user_facing_status.dart';

BusinessPlanDocument _plan({
  required String id,
  String topic = '가이드 전자책개발',
  String artifact = ArtifactType.ebook,
  String customer = '귀촌 준비자',
  String status = PlanningStatus.draft,
  String libraryState = PlanLibraryState.active,
  bool favorite = false,
  bool isProtected = false,
  String updatedAt = '2026-08-05T13:48:00.000Z',
  String createdAt = '2026-08-05T13:00:00.000Z',
  String instructionId = '',
  WorkInstruction? instruction,
  String? lastTransferChecksum,
  String? lastTransferMode,
  List<String> tags = const [],
}) {
  return BusinessPlanDocument(
    id: id,
    input: BusinessPlanInput(
      topic: topic,
      artifactType: artifact,
      deliverableTypes: [artifact],
      targetCustomer: customer,
      customerProblem: '문제',
      desiredOutcome: '결과',
    ),
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    instruction: instruction,
    instructionId: instructionId.isEmpty ? 'wi_$id' : instructionId,
    libraryState: libraryState,
    favorite: favorite,
    isProtected: isProtected,
    lastTransferChecksum: lastTransferChecksum,
    lastTransferMode: lastTransferMode,
    tags: tags,
  );
}

WorkInstruction _wi({
  required String id,
  String checksum = '',
  String topic = '가이드 전자책개발',
}) {
  return WorkInstruction(
    schemaVersion: '1.0',
    instructionId: id,
    projectId: 'p',
    instructionVersion: '1',
    createdAt: '2026-08-05T13:00:00.000Z',
    updatedAt: '2026-08-05T13:00:00.000Z',
    businessIdea: topic,
    businessPurpose: '목적',
    customerProblem: '문제',
    targetCustomer: '귀촌 준비자',
    deliverableTypes: const ['ebook'],
    recommendedSequence: const ['ebook'],
    valueProposition: '가치',
    requiredMaterials: const [],
    workflowSteps: const [],
    completionCriteria: const [],
    qualityChecks: const [],
    risks: const [],
    monetizationOptions: const [],
    deploymentTargets: const [],
    promotionChannels: const [],
    approvalItems: const [],
    executionStatus: '지시서 준비',
    artifactType: ArtifactType.ebook,
    primaryTrack: 'ebook_dev',
    checksum: checksum,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('기존 기획 로딩 — 새 필드 없어도 기본값으로 호환', () {
    final legacy = {
      'id': 'plan_legacy',
      'input': {
        'topic': '레거시 기획',
        'artifactType': ArtifactType.ebook,
        'deliverableTypes': [ArtifactType.ebook],
        'targetCustomer': '고객',
        'customerProblem': '문제',
        'desiredOutcome': '결과',
      },
      'status': PlanningStatus.draft,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
      'instructionId': 'wi_legacy',
      'version': 1,
    };
    final plan = BusinessPlanDocument.fromJson(legacy);
    expect(plan.id, 'plan_legacy');
    expect(plan.libraryState, PlanLibraryState.active);
    expect(plan.isProtected, isFalse);
    expect(plan.trashedAt, isNull);
    expect(plan.input.topic, '레거시 기획');
  });

  test('status=archived 레거시는 libraryState=archived로 추론', () {
    final json = {
      'id': 'plan_a',
      'input': {'topic': '보관됨'},
      'status': PlanningStatus.archived,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
    };
    final plan = BusinessPlanDocument.fromJson(json);
    expect(plan.libraryState, PlanLibraryState.archived);
    expect(plan.status, PlanningStatus.archived);
  });

  test('단일·복수 휴지통 이동 / 복원 / 보관', () async {
    final store = BusinessPlanningStore();
    final a = _plan(id: 'p1', updatedAt: '2026-08-05T13:48:00.000Z');
    final b = _plan(id: 'p2', updatedAt: '2026-08-05T13:41:00.000Z');
    final c = _plan(id: 'p3', updatedAt: '2026-08-05T13:38:00.000Z');
    await store.savePlans([a, b, c]);

    final now = '2026-08-07T00:00:00.000Z';
    final trashedA = PlanLibraryManagement.moveToTrash(
      a,
      updatedAt: now,
      trashedAt: now,
    );
    expect(trashedA.isLibraryTrashed, isTrue);
    await store.upsertPlan(trashedA);

    var loaded = await store.loadPlans();
    expect(loaded.firstWhere((p) => p.id == 'p1').isLibraryTrashed, isTrue);

    final multi = [
      PlanLibraryManagement.moveToTrash(b, updatedAt: now, trashedAt: now),
      PlanLibraryManagement.moveToTrash(c, updatedAt: now, trashedAt: now),
    ];
    await store.upsertPlans(multi);
    loaded = await store.loadPlans();
    expect(loaded.where((p) => p.isLibraryTrashed).length, 3);

    final restored = PlanLibraryManagement.restore(
      loaded.firstWhere((p) => p.id == 'p2'),
      updatedAt: now,
    );
    expect(restored.isLibraryActive, isTrue);
    expect(restored.trashedAt, isNull);
    await store.upsertPlan(restored);

    final archived = PlanLibraryManagement.archive(a, updatedAt: now);
    expect(archived.isLibraryArchived, isTrue);
  });

  test('영구삭제는 기획 레코드만 제거하고 다른 키는 건드리지 않음', () async {
    SharedPreferences.setMockInitialValues({
      BusinessPlanningStore.plansKey: '[]',
      'dev_work_doc_active_marker': 'keep-me',
      'sotong24_inbox_marker': 'keep-inbox',
    });
    final store = BusinessPlanningStore();
    final a = _plan(id: 'del1');
    final b = _plan(id: 'keep1', topic: '유지');
    await store.savePlans([a, b]);
    await store.deletePlans(['del1']);

    final loaded = await store.loadPlans();
    expect(loaded.map((p) => p.id), ['keep1']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dev_work_doc_active_marker'), 'keep-me');
    expect(prefs.getString('sotong24_inbox_marker'), 'keep-inbox');
  });

  test('protected 기획은 휴지통 이동 차단', () {
    final p = _plan(id: 'prot', isProtected: true);
    expect(PlanLibraryManagement.canMoveToTrash(p), isFalse);
    expect(
      () => PlanLibraryManagement.moveToTrash(
        p,
        updatedAt: '2026-08-07T00:00:00.000Z',
        trashedAt: '2026-08-07T00:00:00.000Z',
      ),
      throwsStateError,
    );
  });

  test('동일 checksum은 강한 중복 후보', () {
    final plans = [
      _plan(
        id: 'a',
        updatedAt: '2026-08-05T13:48:00.000Z',
        instruction: _wi(id: 'wi_a', checksum: 'abc123'),
      ),
      _plan(
        id: 'b',
        updatedAt: '2026-08-05T13:41:00.000Z',
        instruction: _wi(id: 'wi_b', checksum: 'abc123'),
      ),
      _plan(
        id: 'c',
        updatedAt: '2026-08-05T13:38:00.000Z',
        instruction: _wi(id: 'wi_c', checksum: 'abc123'),
      ),
    ];
    final groups = PlanLibraryManagement.findDuplicateGroups(plans);
    expect(groups.length, 1);
    expect(groups.first.strongChecksumMatch, isTrue);
    expect(groups.first.plans.length, 3);
    expect(groups.first.newest.id, 'a');
  });

  test('동일 제목이지만 내용 checksum이 다르면 오탐 방지', () {
    final plans = [
      _plan(
        id: 'a',
        instruction: _wi(id: 'wi_a', checksum: 'hash_one'),
      ),
      _plan(
        id: 'b',
        instruction: _wi(id: 'wi_b', checksum: 'hash_two'),
      ),
    ];
    final groups = PlanLibraryManagement.findDuplicateGroups(plans);
    expect(groups, isEmpty);
  });

  test('제목만 같고 결과물·고객이 다르면 중복 후보 아님', () {
    final plans = [
      _plan(id: 'a', artifact: ArtifactType.ebook, customer: 'A'),
      _plan(id: 'b', artifact: ArtifactType.app, customer: 'B'),
    ];
    final groups = PlanLibraryManagement.findDuplicateGroups(plans);
    expect(groups, isEmpty);
  });

  test('필터: 현재/보관/휴지통/중복 후보/진행중', () {
    final plans = [
      _plan(id: 'active1', status: PlanningStatus.draft),
      _plan(id: 'prog', status: PlanningStatus.inProgress, topic: '진행'),
      _plan(id: 'arch', libraryState: PlanLibraryState.archived, topic: '보관됨'),
      _plan(id: 'trash', libraryState: PlanLibraryState.trashed, topic: '휴지'),
      _plan(
        id: 'd1',
        instruction: _wi(id: 'wi_d1', checksum: 'dup'),
      ),
      _plan(
        id: 'd2',
        instruction: _wi(id: 'wi_d2', checksum: 'dup'),
        updatedAt: '2026-08-05T12:00:00.000Z',
      ),
    ];

    final allIds = PlanLibraryManagement.applyManageFilter(plans, 'all')
        .map((p) => p.id)
        .toList();
    expect(allIds, isNot(contains('trash')));
    expect(allIds, isNot(contains('arch')));
    expect(allIds, containsAll(['active1', 'prog', 'd1', 'd2']));
    expect(
      PlanLibraryManagement.applyManageFilter(
        plans,
        'archived',
      ).map((p) => p.id),
      ['arch'],
    );
    expect(
      PlanLibraryManagement.applyManageFilter(
        plans,
        'trashed',
      ).map((p) => p.id),
      ['trash'],
    );
    expect(
      PlanLibraryManagement.applyManageFilter(
        plans,
        'in_progress',
      ).map((p) => p.id),
      ['prog'],
    );
    final dupIds = PlanLibraryManagement.applyManageFilter(
      plans,
      'duplicate_candidates',
    ).map((p) => p.id).toSet();
    expect(dupIds.containsAll({'d1', 'd2'}), isTrue);
  });

  test('영구삭제 경고 — 진행중·전달완료·즐겨찾기·Active', () {
    final transferred = _plan(
      id: 't1',
      status: PlanningStatus.transferred,
      lastTransferMode: 'folder',
      favorite: true,
    );
    final w = PlanLibraryManagement.permanentDeleteWarnings(
      transferred,
      activePlanId: 't1',
    );
    expect(w.reasons, isNot(contains('작업지시 전달 완료')));
    expect(w.reasons, contains('즐겨찾기'));
    expect(w.reasons, contains('현재 Active 프로젝트와 연결'));
  });

  test('latestByInstructionId는 휴지통 제외', () {
    final plans = [
      _plan(
        id: 'a',
        instructionId: 'wi_same',
        updatedAt: '2026-08-06T00:00:00Z',
      ),
      _plan(
        id: 'b',
        instructionId: 'wi_same',
        libraryState: PlanLibraryState.trashed,
        updatedAt: '2026-08-07T00:00:00Z',
      ),
    ];
    final latest = BusinessPlanningStore.latestByInstructionId(plans);
    expect(latest.length, 1);
    expect(latest.first.id, 'a');
  });

  test('동일 제목+결과물+고객 draft는 자동 archive 되지 않고 유사 후보만', () {
    final plans = [
      _plan(
        id: 'guide_new',
        topic: '가이드 전자책개발',
        updatedAt: '2026-08-13T13:48:00.000Z',
      ),
      _plan(
        id: 'guide_old_a',
        topic: '가이드 전자책개발',
        updatedAt: '2026-08-05T13:48:00.000Z',
      ),
      _plan(
        id: 'guide_old_b',
        topic: '가이드 전자책개발',
        updatedAt: '2026-08-05T13:41:00.000Z',
      ),
    ];
    // Soft title-only auto archive removed — no state mutation.
    for (final p in plans) {
      expect(p.isLibraryArchived, isFalse);
    }
    final groups = PlanLibraryManagement.findDuplicateGroups(plans);
    expect(groups.length, 1);
    expect(groups.first.strongChecksumMatch, isFalse);
    expect(groups.first.plans.length, 3);
    final softClean = PlanLibraryManagement.softMarkDuplicateCleanup(plans);
    for (final p in softClean) {
      expect(p.isLibraryArchived, isFalse);
    }
    final candidateIds = PlanLibraryManagement.applyManageFilter(
      plans,
      'duplicate_candidates',
    ).map((p) => p.id).toSet();
    expect(candidateIds, {'guide_new', 'guide_old_a', 'guide_old_b'});
  });

  test('현재 필터는 정리대상 태그 기획 제외', () {
    final plans = [
      _plan(id: 'ok'),
      _plan(id: 'cleanup', tags: const ['cleanup', '정리대상']),
    ];
    final all = PlanLibraryManagement.applyManageFilter(plans, 'all');
    expect(all.map((p) => p.id), ['ok']);
  });

  test('보관 해제/복원 시 cleanup 태그 제거 후 현재 목록에 재표시', () {
    final archived = _plan(
      id: 'a1',
      libraryState: PlanLibraryState.archived,
      tags: const ['정리대상', 'cleanup', '보류', 'userNote'],
    );
    final unarchived = PlanLibraryManagement.unarchive(
      archived,
      updatedAt: '2026-08-13T20:00:00.000Z',
    );
    expect(unarchived.isLibraryArchived, isFalse);
    expect(unarchived.tags, isNot(contains('cleanup')));
    expect(unarchived.tags, isNot(contains('정리대상')));
    expect(unarchived.tags, contains('보류'));
    expect(unarchived.tags, contains('userNote'));
    expect(
      PlanLibraryManagement.applyManageFilter([unarchived], 'all').map((p) => p.id),
      ['a1'],
    );

    final trashed = _plan(
      id: 't1',
      libraryState: PlanLibraryState.trashed,
      tags: const ['cleanup', '정리대상', 'favorite-ish'],
    );
    final restored = PlanLibraryManagement.restore(
      trashed,
      updatedAt: '2026-08-13T20:00:00.000Z',
    );
    expect(restored.isLibraryTrashed, isFalse);
    expect(restored.tags, isNot(contains('cleanup')));
    expect(restored.tags, contains('favorite-ish'));
    expect(
      PlanLibraryManagement.isOperationalListEntry(restored),
      isTrue,
    );
  });

  test('수동 보관/보관 해제는 upsertPlan cloud OCC(memory mirror)로 반영', () async {
    SharedPreferences.setMockInitialValues({});
    final memory = <String, Map<String, dynamic>>{};
    final mirror = BusinessPlanMirrorService(
      memory: memory,
      ownerUidResolver: () => 'owner_test',
    );
    final store = BusinessPlanningStore(mirror: mirror);
    final plan = _plan(id: 'cloud_arch', topic: '보관동기화');

    final created = await mirror.upsertPlan(plan, ownerUid: 'owner_test');
    expect(created.succeeded, isTrue);
    expect(mirror.knownRevisions['cloud_arch'], 1);

    final archived = PlanLibraryManagement.archive(
      plan,
      updatedAt: '2026-08-13T21:00:00.000Z',
    );
    // Bulk archive path: local save + OCC enqueue (await the same enqueue).
    await store.savePlans([archived]);
    final archResult = await mirror.enqueueUpsert(
      archived,
      ownerUid: 'owner_test',
    );
    expect(archResult.succeeded, isTrue);
    final archivedDoc = mirror.debugMemoryDoc('owner_test', 'cloud_arch');
    expect(
      (archivedDoc!['plan'] as Map)['libraryState'],
      PlanLibraryState.archived,
    );

    final restored = PlanLibraryManagement.unarchive(
      archived.copyWith(tags: const ['cleanup', '정리대상', '보류']),
      updatedAt: '2026-08-13T21:05:00.000Z',
    );
    expect(restored.tags, isNot(contains('cleanup')));
    expect(restored.tags, contains('보류'));
    await store.savePlans([restored]);
    final restoreResult = await mirror.enqueueUpsert(
      restored,
      ownerUid: 'owner_test',
    );
    expect(restoreResult.succeeded, isTrue);
    final liveDoc = mirror.debugMemoryDoc('owner_test', 'cloud_arch');
    expect((liveDoc!['plan'] as Map)['libraryState'], PlanLibraryState.active);
    expect(
      List<String>.from((liveDoc['plan'] as Map)['tags'] as List? ?? const []),
      isNot(contains('cleanup')),
    );

    final reloaded = await store.loadPlans(runCleanup: false);
    final local = reloaded.firstWhere((p) => p.id == 'cloud_arch');
    expect(local.isLibraryArchived, isFalse);
    expect(local.tags, isNot(contains('cleanup')));
    expect(PlanLibraryManagement.isOperationalListEntry(local), isTrue);
  });

  test('기본 필터 라벨은 전체 대신 현재', () {
    expect(PlanUserFacingStatus.primaryFilterLabel('all'), '현재');
    expect(PlanUserFacingStatus.primaryFilters, [
      'all',
      'not_delivered',
      'working',
      'waiting',
      'completed',
      'archived',
    ]);
  });

  test('현재 필터는 archive/cleanup/trash 제외하고 실제 보류는 포함', () {
    final plans = [
      _plan(id: 'live'),
      _plan(id: 'hold', tags: const ['보류']),
      _plan(id: 'arch', libraryState: PlanLibraryState.archived),
      _plan(id: 'trash', libraryState: PlanLibraryState.trashed),
      _plan(id: 'cleanup', tags: const ['cleanup']),
    ];
    final current = PlanLibraryManagement.applyManageFilter(plans, 'all');
    expect(current.map((p) => p.id).toSet(), {'live', 'hold'});
    expect(
      PlanUserFacingStatus.label(current.firstWhere((p) => p.id == 'hold')),
      PlanUserFacingStatus.deferred,
    );
  });

  test('displayTitle은 WI businessIdea를 topic보다 우선 (데이터 덮어쓰기 없음)', () {
    final plan = _plan(
      id: 'ops',
      topic: '가이드 전자책개발',
      instructionId: 'wi_plan_1785905165067',
      instruction: _wi(
        id: 'wi_plan_1785905165067',
        topic: '50대 초보도 따라 하는 AI 전자책 첫 출간',
      ),
      tags: const ['보류'],
    );
    expect(
      PlanLibraryManagement.displayTitle(plan),
      '50대 초보도 따라 하는 AI 전자책 첫 출간',
    );
    expect(plan.input.topic, '가이드 전자책개발');
    expect(PlanUserFacingStatus.label(plan), PlanUserFacingStatus.deferred);
  });

  test('보호·운영 기획은 일괄 보관 차단 (선택/보관)', () {
    final opsExec = PlanExecutionStatusResolver.resolve(
      _plan(
        id: 'ops_plan',
        instructionId: 'wi_plan_1785905165067',
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.folderMode,
        instruction: _wi(id: 'wi_plan_1785905165067'),
      ),
      remoteProject: Sotong24RemoteProject(
        projectId: 'wi_plan_1785905165067',
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
    final ops = _plan(
      id: 'ops_plan',
      instructionId: 'wi_plan_1785905165067',
      instruction: _wi(id: 'wi_plan_1785905165067'),
      status: PlanningStatus.transferred,
      lastTransferMode: PlanProgressStatus.folderMode,
      tags: const ['보류'],
    );
    final protected = _plan(id: 'prot', isProtected: true);
    final working = _plan(
      id: 'work',
      status: PlanningStatus.transferred,
      lastTransferMode: PlanProgressStatus.folderMode,
    );
    final workingExec = PlanExecutionStatusResolver.resolve(
      working,
      remoteProject: Sotong24RemoteProject(
        projectId: 'wi_work',
        title: '작업중',
        productType: ArtifactType.ebook,
        currentStage: 7,
        totalStages: 18,
        progress: 40,
        status: Sotong24WorkStatus.inProgress,
        startedAt: '2026-08-06T10:10:00+09:00',
      ),
    );
    final waiting = _plan(
      id: 'wait',
      status: PlanningStatus.validationRequired,
    );
    final delivered = _plan(
      id: 'deliv',
      status: PlanningStatus.transferred,
      lastTransferMode: PlanProgressStatus.folderMode,
    );
    final normal = _plan(id: 'ok', topic: '정리용');

    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        ops,
        activePlanId: 'other',
        execution: opsExec,
      ),
      isTrue,
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        ops,
        activePlanId: 'other',
      ),
      isFalse,
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        protected,
        activePlanId: null,
      ),
      isTrue,
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        working,
        activePlanId: null,
        execution: workingExec,
      ),
      isTrue,
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        waiting,
        activePlanId: null,
      ),
      isFalse,
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        delivered,
        activePlanId: null,
      ),
      isFalse,
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        normal,
        activePlanId: 'ops_plan',
      ),
      isFalse,
    );
    expect(
      PlanLibraryManagement.isBulkArchiveBlocked(
        normal,
        activePlanId: 'ok',
      ),
      isTrue,
    );
  });

  test('isSelectableForBulkAction — archive vs unarchive vs restore 분리', () {
    final archived = _plan(
      id: 'arch',
      libraryState: PlanLibraryState.archived,
      topic: '보관됨',
    );
    final trashed = _plan(
      id: 'trash',
      libraryState: PlanLibraryState.trashed,
      topic: '휴지',
    );
    final ops = _plan(
      id: 'ops',
      instructionId: 'wi_plan_1785905165067',
      instruction: _wi(id: 'wi_plan_1785905165067'),
    );
    final normal = _plan(id: 'ok', topic: '일반');

    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        archived,
        PlanLibraryBulkAction.archive,
      ),
      isFalse,
    );
    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        archived,
        PlanLibraryBulkAction.unarchive,
      ),
      isTrue,
    );
    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        ops.copyWith(libraryState: PlanLibraryState.archived),
        PlanLibraryBulkAction.unarchive,
      ),
      isTrue,
    );

    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        trashed,
        PlanLibraryBulkAction.archive,
      ),
      isFalse,
    );
    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        trashed,
        PlanLibraryBulkAction.restore,
      ),
      isTrue,
    );
    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        trashed,
        PlanLibraryBulkAction.permanentDelete,
      ),
      isTrue,
    );

    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        ops,
        PlanLibraryBulkAction.archive,
      ),
      isTrue,
    );
    final opsExec = PlanExecutionStatusResolver.resolve(
      ops.copyWith(
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.folderMode,
      ),
      remoteProject: Sotong24RemoteProject(
        projectId: 'wi_plan_1785905165067',
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
      PlanLibraryManagement.isSelectableForBulkAction(
        ops,
        PlanLibraryBulkAction.archive,
        execution: opsExec,
      ),
      isFalse,
    );
    expect(
      PlanLibraryManagement.isSelectableForBulkAction(
        normal,
        PlanLibraryBulkAction.archive,
      ),
      isTrue,
    );

    expect(
      PlanLibraryManagement.primarySelectionActionForFilter('archived'),
      PlanLibraryBulkAction.unarchive,
    );
    expect(
      PlanLibraryManagement.primarySelectionActionForFilter('trashed'),
      PlanLibraryBulkAction.restore,
    );
    expect(
      PlanLibraryManagement.primarySelectionActionForFilter('all'),
      PlanLibraryBulkAction.archive,
    );
  });

  test('일반 기획 여러 건 일괄 보관 후 cloud OCC·reload 유지', () async {
    SharedPreferences.setMockInitialValues({});
    final memory = <String, Map<String, dynamic>>{};
    final mirror = BusinessPlanMirrorService(
      memory: memory,
      ownerUidResolver: () => 'owner_test',
    );
    final store = BusinessPlanningStore(mirror: mirror);

    final a = _plan(id: 'bulk_a', topic: '정리A');
    final b = _plan(id: 'bulk_b', topic: '정리B');
    final ops = _plan(
      id: 'bulk_ops',
      instructionId: 'wi_plan_1785905165067',
      instruction: _wi(id: 'wi_plan_1785905165067'),
    );

    for (final p in [a, b, ops]) {
      final r = await mirror.upsertPlan(p, ownerUid: 'owner_test');
      expect(r.succeeded, isTrue);
    }

    final opsExec = PlanExecutionStatusResolver.resolve(
      ops.copyWith(
        status: PlanningStatus.transferred,
        lastTransferMode: PlanProgressStatus.folderMode,
      ),
      remoteProject: Sotong24RemoteProject(
        projectId: 'wi_plan_1785905165067',
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

    final selected = [a, b, ops];
    final toArchive = selected
        .where(
          (p) => !PlanLibraryManagement.isBulkArchiveBlocked(
            p,
            activePlanId: null,
            execution: p.id == 'bulk_ops' ? opsExec : null,
          ),
        )
        .map(
          (p) => PlanLibraryManagement.archive(
            p,
            updatedAt: '2026-08-14T01:00:00.000Z',
          ),
        )
        .toList();
    expect(toArchive.map((p) => p.id).toSet(), {'bulk_a', 'bulk_b'});

    for (final archived in toArchive) {
      await store.savePlans([
        ...(await store.loadPlans(runCleanup: false))
            .where((p) => p.id != archived.id),
        archived,
      ]);
      final archResult = await mirror.enqueueUpsert(
        archived,
        ownerUid: 'owner_test',
      );
      expect(archResult.succeeded, isTrue);
    }

    final archA = mirror.debugMemoryDoc('owner_test', 'bulk_a');
    final archB = mirror.debugMemoryDoc('owner_test', 'bulk_b');
    final opsDoc = mirror.debugMemoryDoc('owner_test', 'bulk_ops');
    expect(
      (archA!['plan'] as Map)['libraryState'],
      PlanLibraryState.archived,
    );
    expect(
      (archB!['plan'] as Map)['libraryState'],
      PlanLibraryState.archived,
    );
    expect(
      (opsDoc!['plan'] as Map)['libraryState'],
      PlanLibraryState.active,
    );

    final reloaded = await store.loadPlans(runCleanup: false);
    expect(
      reloaded.firstWhere((p) => p.id == 'bulk_a').isLibraryArchived,
      isTrue,
    );
    expect(
      reloaded.firstWhere((p) => p.id == 'bulk_b').isLibraryArchived,
      isTrue,
    );
    expect(
      reloaded.firstWhere((p) => p.id == 'bulk_ops').isLibraryArchived,
      isFalse,
    );
  });
}
