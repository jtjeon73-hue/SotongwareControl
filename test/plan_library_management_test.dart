import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/plan_library_management.dart';

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

  test('필터: 전체/보관/휴지통/중복 후보/진행중', () {
    final plans = [
      _plan(id: 'active1', status: PlanningStatus.draft),
      _plan(
        id: 'prog',
        status: PlanningStatus.inProgress,
        topic: '진행',
      ),
      _plan(
        id: 'arch',
        libraryState: PlanLibraryState.archived,
        topic: '보관됨',
      ),
      _plan(
        id: 'trash',
        libraryState: PlanLibraryState.trashed,
        topic: '휴지',
      ),
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

    expect(
      PlanLibraryManagement.applyManageFilter(plans, 'all').map((p) => p.id),
      isNot(contains('trash')),
    );
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
    expect(w.reasons, contains('작업지시 전달 완료'));
    expect(w.reasons, contains('즐겨찾기'));
    expect(w.reasons, contains('현재 Active 프로젝트와 연결'));
  });

  test('latestByInstructionId는 휴지통 제외', () {
    final plans = [
      _plan(id: 'a', instructionId: 'wi_same', updatedAt: '2026-08-06T00:00:00Z'),
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
}
