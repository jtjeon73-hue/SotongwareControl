import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/data/idea_bank_seed.dart';
import 'package:sotong_ware_control/data/menu_divisions.dart';
import 'package:sotong_ware_control/data/sotong24_workflows.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/idea_bank_store.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/screens/idea_bank_screen.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('메뉴 5개 부문과 flattened 17개 일치', () {
    expect(MenuDivisionCatalog.all.length, 5);
    expect(MenuDivisionCatalog.all.map((e) => e.title).toList(), [
      '운영 관제',
      '개발부',
      '마케팅재무부',
      '설정부',
      '사업전략부',
    ]);
    expect(SidebarNavigation.canonicalDestinations.length, 17);
    expect(
      SidebarNavigation.canonicalDestinations,
      MenuDivisionCatalog.flattenedDestinations,
    );
    expect(ControlDestination.productWorkshop.label, 'AI 제작공정');
    expect(ControlDestination.sotong24RemoteControl.label, '노트북 원격관제');
    expect(ControlDestination.aiBusinessAnalysis.label, '작업지시 제작소');
  });

  test('전자책 workflow는 표준 18단계 ID와 호환', () {
    final wf = Sotong24WorkflowCatalog.ebook;
    expect(wf.totalStages, 18);
    expect(
      wf.totalStages,
      BusinessPlanningService.standardWorkflowTitles.length,
    );
    for (var i = 0; i < wf.stages.length; i++) {
      expect(
        wf.stages[i].id,
        BusinessPlanningService.standardWorkflowTitles[i].$1,
      );
      expect(wf.stages[i].purpose, isNotEmpty);
      expect(wf.stages[i].aiWork, isNotEmpty);
    }
  });

  test('앱·사이트·마케팅·콘텐츠·산업자동화 workflow 정의', () {
    expect(Sotong24WorkflowCatalog.app.totalStages, greaterThan(15));
    expect(Sotong24WorkflowCatalog.site.totalStages, greaterThan(15));
    expect(Sotong24WorkflowCatalog.promoSite.totalStages, greaterThan(15));
    expect(Sotong24WorkflowCatalog.industrial.totalStages, greaterThan(15));
    expect(
      Sotong24WorkflowCatalog.contentsFor(ContentSubtype.song).totalStages,
      greaterThan(10),
    );
    expect(
      Sotong24WorkflowCatalog.forProduct(ArtifactType.app).title,
      contains('앱'),
    );
  });

  test('시드 아이디어 출처 URL은 http(s)만', () {
    final seeds = IdeaBankSeedCatalog.seeds();
    expect(seeds, isNotEmpty);
    for (final s in seeds) {
      expect(s.isSeed, isTrue);
      expect(s.category, isNotEmpty);
      for (final src in s.sources) {
        expect(IdeaBankSourceRef.isTrustedHttpUrl(src.sourceUrl), isTrue);
      }
    }
  });

  test('IdeaBank load는 시드를 병합하고 사용자 저장과 구분', () async {
    final store = IdeaBankStore();
    final loaded = await store.load();
    expect(loaded.where((e) => e.isSeed).length, greaterThan(5));
    final userOnly = await store.load(includeSeeds: false);
    expect(userOnly.where((e) => e.isSeed), isEmpty);
  });

  testWidgets('사이드바 부문 헤더 표시', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SidebarNavigation(
            selected: ControlDestination.productWorkshop,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('운영 관제'), findsOneWidget);
    expect(find.text('개발부'), findsOneWidget);
    expect(find.text('AI 제작공정'), findsWidgets);
  });

  testWidgets('소통24워크·아이디어뱅크 390px', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final demo = Sotong24RemoteDemoCatalog.demoProjects().firstWhere(
      (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
    );
    final repo = Sotong24RemoteRepository(
      forceMemory: true,
      memorySeed: [
        Sotong24RemoteProject(
          projectId: 'wi_ops_phase2_overflow',
          title: demo.title,
          productType: demo.productType,
          currentStage: demo.currentStage,
          totalStages: demo.totalStages,
          progress: demo.progress,
          status: demo.status,
          approvalStatus: demo.approvalStatus,
          stages: demo.stages,
          isDemo: false,
        ),
      ],
    );
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 제작공정'), findsWidgets);
    expect(find.textContaining('지금 할 일'), findsNothing); // 목록 화면
    expect(find.textContaining('현재 제작'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IdeaBankScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('뉴 아이디어 뱅크'), findsOneWidget);
    // 모바일: compact header — 긴 소개문 없음, 필터로 카테고리 접근
    expect(find.textContaining('기회와 제작 아이디어'), findsNothing);
    expect(find.text('필터'), findsOneWidget);
    await tester.tap(find.text('필터'));
    await tester.pumpAndSettle();
    expect(find.text('전체 카테고리'), findsOneWidget);
    expect(find.text('세계 트렌드'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 768.0, 1280.0, 1600.0]) {
    testWidgets('아이디어뱅크 카테고리 Wrap overflow 없음 ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IdeaBankScreen())),
      );
      await tester.pumpAndSettle();

      final isMobile = width < 900;
      if (isMobile) {
        await tester.tap(find.text('필터'));
        await tester.pumpAndSettle();
      }

      expect(find.text('전체 카테고리'), findsOneWidget);
      for (final c in IdeaBankCategories.all) {
        expect(find.text(IdeaBankCategories.labelKo(c)), findsWidgets);
      }

      final horizontalScrolls = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((w) => w.scrollDirection == Axis.horizontal);
      expect(horizontalScrolls, isEmpty);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('아이디어뱅크 카테고리 필터 선택 유지', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IdeaBankScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('세계 트렌드'));
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '세계 트렌드'),
    );
    expect(chip.selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
