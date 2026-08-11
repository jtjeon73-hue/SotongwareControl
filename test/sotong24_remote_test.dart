import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical 메뉴 라벨이 소통24워크이다', () {
    expect(ControlDestination.productWorkshop.label, '소통24워크');
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
      contains('requestId'),
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
    expect(after.status, Sotong24WorkStatus.revision);
  });

  testWidgets('소통24워크 화면·모바일 폭 표시', (tester) async {
    final repo = Sotong24RemoteRepository(forceMemory: true);
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

    expect(find.text('소통24워크'), findsWidgets);
    expect(find.textContaining('선택된 제품을 실제로 제작하는 곳'), findsOneWidget);
    expect(find.textContaining('현재 제작'), findsOneWidget);
    expect(find.textContaining('50대 초보도'), findsWidgets);
    expect(find.text('승인 대기'), findsWidgets);
    expect(find.text('상세보기'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('데스크톱 폭에서도 오버플로 없음', (tester) async {
    final repo = Sotong24RemoteRepository(forceMemory: true);
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
}
