import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';
import 'package:sotong_ware_control/widgets/sotong24_stage_widgets.dart';

Sotong24RemoteProject _operationalEbookFromDemo() {
  final demo = Sotong24RemoteDemoCatalog.demoProjects().firstWhere(
    (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
  );
  return Sotong24RemoteProject(
    projectId: 'wi_ops_ui_display_test',
    title: demo.title,
    productType: demo.productType,
    contentSubtype: demo.contentSubtype,
    currentStage: demo.currentStage,
    totalStages: demo.totalStages,
    progress: demo.progress,
    status: demo.status,
    approvalStatus: demo.approvalStatus,
    pcStatus: demo.pcStatus,
    lastHeartbeat: demo.lastHeartbeat,
    startedAt: demo.startedAt,
    createdAt: demo.createdAt,
    updatedAt: demo.updatedAt,
    isDemo: false,
    stages: demo.stages,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical 메뉴 라벨이 AI 제작공정이다', () {
    expect(ControlDestination.productWorkshop.label, 'AI 제작공정');
    expect(
      SidebarNavigation.canonicalDestinations
          .where((e) => e == ControlDestination.productWorkshop)
          .length,
      1,
    );
  });

  test('데모 전자책은 표준 18단계와 호환된다', () {
    final demos = Sotong24RemoteDemoCatalog.demoProjects();
    final ebook = demos.firstWhere(
      (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
    );
    expect(ebook.isDemo, isTrue);
    expect(
      ebook.totalStages,
      BusinessPlanningService.standardWorkflowTitles.length,
    );
    expect(ebook.stages.length, ebook.totalStages);
    expect(ebook.status, Sotong24WorkStatus.awaitingApproval);
    expect(ebook.currentStage, 13);
  });

  test('heartbeat로 PC 연결 상태를 판정한다', () {
    final now = DateTime.utc(2026, 8, 11, 1, 0);
    expect(
      Sotong24PcLinkStatus.fromHeartbeat(
        now.subtract(const Duration(seconds: 30)).toIso8601String(),
        now: now,
      ),
      Sotong24PcLinkStatus.online,
    );
    expect(
      Sotong24PcLinkStatus.fromHeartbeat(
        now.subtract(const Duration(minutes: 5)).toIso8601String(),
        now: now,
      ),
      Sotong24PcLinkStatus.delayed,
    );
    expect(
      Sotong24PcLinkStatus.fromHeartbeat(
        now.subtract(const Duration(hours: 1)).toIso8601String(),
        now: now,
      ),
      Sotong24PcLinkStatus.offline,
    );
  });

  test('승인·보완요청과 중복 승인을 막는다', () async {
    final repo = Sotong24RemoteRepository(forceMemory: true);
    addTearDown(repo.dispose);
    final project = (await repo.watchProjects().first).firstWhere(
      (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
    );
    final stage = project.currentStageDoc!;
    final requestId = stage.activeRequestId;

    expect(
      await repo.approveStage(
        projectId: project.projectId,
        stageId: stage.stageId,
        requestId: requestId,
      ),
      isNull,
    );

    final after = await repo.getProject(project.projectId);
    expect(after!.approvalStatus, ApprovalStatus.approved);
    expect(
      after.stages.firstWhere((s) => s.stageId == stage.stageId).approvalStatus,
      ApprovalStatus.approved,
    );
    expect(after.status, Sotong24WorkStatus.awaitingApproval);
    expect(after.currentStageDoc!.status, Sotong24WorkStatus.awaitingApproval);
    expect(after.showApprovalActions, isFalse);
    expect(after.nowTodoHeadline(), '승인 요청을 전송했습니다. Agent가 다음 단계를 준비 중입니다.');

    // 동일 requestId 재승인 거부
    expect(
      await repo.approveStage(
        projectId: project.projectId,
        stageId: stage.stageId,
        requestId: requestId,
      ),
      isNotNull,
    );
  });

  test('잘못된 requestId·비현재 단계는 거부된다', () async {
    final repo = Sotong24RemoteRepository(forceMemory: true);
    addTearDown(repo.dispose);
    final project = (await repo.watchProjects().first).firstWhere(
      (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
    );
    final stage = project.currentStageDoc!;

    expect(
      await repo.requestRevision(
        projectId: project.projectId,
        stageId: stage.stageId,
        requestId: 'wrong_id',
        message: '표지 수정',
      ),
      contains('대기'),
    );

    expect(
      await repo.requestRevision(
        projectId: project.projectId,
        stageId: project.stages.first.stageId,
        requestId: 'any',
        message: '표지 수정',
      ),
      isNotNull,
    );
  });

  test('보완 요청이 revision_requested로 저장된다', () async {
    final repo = Sotong24RemoteRepository(forceMemory: true);
    addTearDown(repo.dispose);
    final project = (await repo.watchProjects().first).firstWhere(
      (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
    );
    final stage = project.currentStageDoc!;
    expect(
      await repo.requestRevision(
        projectId: project.projectId,
        stageId: stage.stageId,
        requestId: stage.activeRequestId,
        message: '표지 제목을 더 크게 하고 사례를 추가해 주세요.',
      ),
      isNull,
    );
    final after = await repo.getProject(project.projectId);
    expect(after!.approvalStatus, ApprovalStatus.revisionRequested);
    // Raw execution status stays Agent-owned until the request is applied.
    expect(after.status, Sotong24WorkStatus.awaitingApproval);
    expect(after.currentStageDoc!.status, Sotong24WorkStatus.awaitingApproval);
    expect(after.userFacingStatus, Sotong24WorkStatus.revision);
    expect(after.showApprovalActions, isFalse);
  });

  test('allocateRequestId: 동일 revision terminal은 재사용, r2만 신규', () {
    final stage = Sotong24RemoteStage(
      stageId: 'stage_07_outline',
      stageNumber: 7,
      stageName: '아웃라인',
      status: Sotong24WorkStatus.awaitingApproval,
      approvalRequired: true,
      criteriaMet: true,
      approvalStatus: ApprovalStatus.pending,
      activeRequestId: 'req_rev_A',
      revision: 1,
    );
    final existing = [
      const Sotong24RemoteRequest(
        requestId: 'req_rev_A',
        projectId: 'wi_fake_e2e_reapprove',
        stageId: 'stage_07_outline',
        requestType: 'revision_request',
        status: ApprovalStatus.revisionRequested,
        processedAt: '2026-08-15T12:00:00.000Z',
        revision: 1,
      ),
    ];
    final next = Sotong24RemoteApprovalGuard.allocateRequestId(
      stage: stage,
      existingRequests: existing,
      preferred: 'req_rev_A',
      now: DateTime.utc(2026, 8, 15, 12, 30),
    );
    expect(next, 'req_rev_A');

    final r2 = Sotong24RemoteApprovalGuard.allocateRequestId(
      stage: stage.copyWith(revision: 2),
      existingRequests: existing,
      preferred: 'req_rev_A',
      now: DateTime.utc(2026, 8, 15, 12, 30),
    );
    expect(r2, isNot(equals('req_rev_A')));
    expect(r2, startsWith('req_stage_07_outline_'));

    final open = Sotong24RemoteApprovalGuard.allocateRequestId(
      stage: stage.copyWith(activeRequestId: 'req_pending_open'),
      existingRequests: const [
        Sotong24RemoteRequest(
          requestId: 'req_pending_open',
          projectId: 'wi_fake_e2e_reapprove',
          stageId: 'stage_07_outline',
          requestType: 'approve',
          status: ApprovalStatus.pending,
        ),
      ],
      preferred: 'req_pending_open',
    );
    expect(open, 'req_pending_open');
  });

  test('r1 보완 후 r2 재승인 requestId는 달라야 하고 더블클릭은 차단', () async {
    final repo = Sotong24RemoteRepository(forceMemory: true);
    addTearDown(repo.dispose);
    final project = (await repo.watchProjects().first).firstWhere(
      (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
    );
    final stage = project.currentStageDoc!;
    final pendingSlot = stage.activeRequestId;
    expect(pendingSlot, isNotEmpty);

    // B. 보완 → requestId A
    expect(
      await repo.requestRevision(
        projectId: project.projectId,
        stageId: stage.stageId,
        requestId: pendingSlot,
        message: '초보자가 이해하기 쉽게 예시를 하나 추가해 주세요.',
      ),
      isNull,
    );
    final afterRev = await repo.listRequests(project.projectId);
    final revReq = afterRev.firstWhere(
      (r) => r.requestType == 'revision_request',
    );
    final requestIdA = revReq.requestId;
    expect(requestIdA, pendingSlot);
    expect(revReq.status, ApprovalStatus.revisionRequested);

    // Agent 재작업 → r2 승인대기 (stale activeRequestId = A 유지)
    expect(
      await repo.simulateAgentReworkAwaitingApproval(
        projectId: project.projectId,
        stageId: stage.stageId,
        resultPreview: '7단계 E2E 보완 후 재승인 대기 r2',
      ),
      isNull,
    );
    final r2 = await repo.getProject(project.projectId);
    final r2Stage = r2!.stages.firstWhere((s) => s.stageId == stage.stageId);
    expect(r2Stage.status, Sotong24WorkStatus.awaitingApproval);
    expect(r2Stage.activeRequestId, requestIdA);

    // C. 재승인 → requestId B, A != B
    expect(
      await repo.approveStage(
        projectId: project.projectId,
        stageId: stage.stageId,
        requestId: r2Stage.activeRequestId,
      ),
      isNull,
    );
    final afterApprove = await repo.listRequests(project.projectId);
    final approveReqs = afterApprove
        .where((r) => r.requestType == 'approve')
        .toList();
    expect(approveReqs, isNotEmpty);
    final requestIdB = approveReqs.last.requestId;
    expect(requestIdB, isNotEmpty);
    expect(requestIdB, isNot(equals(requestIdA)));
    expect(
      (await repo.getProject(project.projectId))!.approvalStatus,
      ApprovalStatus.approved,
    );

    // D. 동일 승인 더블클릭 → 중복 생성 없음
    final countBefore = afterApprove.length;
    final dup = await repo.approveStage(
      projectId: project.projectId,
      stageId: stage.stageId,
      requestId: requestIdB,
    );
    expect(dup, isNotNull);
    final countAfter = (await repo.listRequests(project.projectId)).length;
    expect(countAfter, countBefore);
  });

  test('다른 stage 승인은 새 requestId', () async {
    final titles = BusinessPlanningService.standardWorkflowTitles;
    final now = DateTime.utc(2026, 8, 15, 13).toIso8601String();
    final stages = <Sotong24RemoteStage>[
      for (var i = 0; i < titles.length; i++)
        Sotong24RemoteStage(
          stageId: titles[i].$1,
          stageNumber: i + 1,
          stageName: titles[i].$2,
          status: i + 1 < 8
              ? Sotong24WorkStatus.completed
              : (i + 1 == 8
                    ? Sotong24WorkStatus.awaitingApproval
                    : Sotong24WorkStatus.ready),
          approvalRequired: i + 1 == 8,
          criteriaMet: i + 1 <= 8,
          approvalStatus: i + 1 == 8
              ? ApprovalStatus.pending
              : ApprovalStatus.notRequired,
          activeRequestId: i + 1 == 8 ? 'req_stage08_open' : '',
          updatedAt: now,
        ),
    ];
    final stage8Id = titles[7].$1;
    final repo = Sotong24RemoteRepository(
      forceMemory: true,
      memorySeed: [
        Sotong24RemoteProject(
          projectId: 'wi_fake_e2e_stage8',
          title: '[TEST] stage8 approve',
          productType: 'ebook',
          currentStage: 8,
          totalStages: titles.length,
          progress: 0,
          status: Sotong24WorkStatus.awaitingApproval,
          approvalStatus: ApprovalStatus.pending,
          stages: stages,
          updatedAt: now,
          createdAt: now,
        ),
      ],
    );
    addTearDown(repo.dispose);

    expect(
      await repo.approveStage(
        projectId: 'wi_fake_e2e_stage8',
        stageId: stage8Id,
        requestId: 'req_stage08_open',
      ),
      isNull,
    );
    final reqs = await repo.listRequests('wi_fake_e2e_stage8');
    expect(reqs.single.requestId, 'req_stage08_open');
    expect(reqs.single.requestType, 'approve');
    expect(reqs.single.stageId, stage8Id);
  });

  testWidgets('AI 제작공정 화면·모바일 폭 표시', (tester) async {
    final repo = Sotong24RemoteRepository(
      forceMemory: true,
      memorySeed: [_operationalEbookFromDemo()],
    );
    addTearDown(repo.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 제작공정'), findsWidgets);
    expect(find.textContaining('진행 상태를 확인하고'), findsOneWidget);
    expect(find.textContaining('현재 제작'), findsOneWidget);
    expect(find.textContaining('50대 초보도'), findsWidgets);
    expect(find.text('승인 대기'), findsWidgets);
    expect(find.text('상세보기'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('데스크톱 폭에서도 오버플로 없음', (tester) async {
    final repo = Sotong24RemoteRepository(
      forceMemory: true,
      memorySeed: [_operationalEbookFromDemo()],
    );
    addTearDown(repo.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('작업 목록'), findsOneWidget);
  });

  group('not_applicable stage contract', () {
    test('표시는 해당 없음이며 완료로 집계하지 않는다', () {
      expect(
        Sotong24WorkStatus.labelKo(Sotong24WorkStatus.notApplicable),
        '해당 없음',
      );
      expect(Sotong24WorkStatus.countsAsCompleted('not_applicable'), isFalse);
      expect(Sotong24WorkStatus.isNotApplicable('not_applicable'), isTrue);
      expect(sotong24StatusGlyph('not_applicable'), '—');
    });

    test('N/A 단계는 완료 수·진행률 분모에서 제외', () {
      final project = Sotong24RemoteProject(
        projectId: 'wi_na_progress',
        title: '해당없음 집계',
        productType: 'ebook',
        currentStage: 1,
        totalStages: 4,
        progress: 0,
        status: Sotong24WorkStatus.inProgress,
        stages: const [
          Sotong24RemoteStage(
            stageId: 's1',
            stageNumber: 1,
            stageName: '진행',
            status: Sotong24WorkStatus.inProgress,
          ),
          Sotong24RemoteStage(
            stageId: 's2',
            stageNumber: 2,
            stageName: '완료',
            status: Sotong24WorkStatus.completed,
          ),
          Sotong24RemoteStage(
            stageId: 's3',
            stageNumber: 3,
            stageName: '해당없음A',
            status: Sotong24WorkStatus.notApplicable,
          ),
          Sotong24RemoteStage(
            stageId: 's4',
            stageNumber: 4,
            stageName: '해당없음B',
            status: Sotong24WorkStatus.notApplicable,
          ),
        ],
      );
      expect(project.overallProgressPercent, 50);
      final stats = Sotong24StageStats.fromProject(project);
      expect(stats.completed, 1);
      expect(stats.inProgress, 1);
    });
  });
}
