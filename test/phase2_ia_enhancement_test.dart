import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/data/idea_bank_seed.dart';
import 'package:sotong_ware_control/data/menu_divisions.dart';
import 'package:sotong_ware_control/data/sotong24_workflows.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
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

  test('메뉴 5개 부문과 flattened 15개 일치', () {
    expect(MenuDivisionCatalog.all.length, 5);
    expect(MenuDivisionCatalog.all.map((e) => e.title).toList(), [
      '기획실행부',
      '개발부',
      '마케팅재무부',
      '설정부',
      '사업전략부',
    ]);
    expect(SidebarNavigation.canonicalDestinations.length, 15);
    expect(
      SidebarNavigation.canonicalDestinations,
      MenuDivisionCatalog.flattenedDestinations,
    );
    expect(ControlDestination.productWorkshop.label, '소통24워크');
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
    expect(find.text('기획실행부'), findsOneWidget);
    expect(find.text('개발부'), findsOneWidget);
    expect(find.text('소통24워크'), findsWidgets);
  });

  testWidgets('소통24워크·아이디어뱅크 390px', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = Sotong24RemoteRepository(forceMemory: true);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('소통24워크'), findsWidgets);
    expect(find.textContaining('지금 할 일'), findsNothing); // 목록 화면
    expect(find.textContaining('완료'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IdeaBankScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('뉴 아이디어 뱅크'), findsOneWidget);
    expect(find.textContaining('기회와 제작 아이디어'), findsOneWidget);
    expect(find.text('세계 트렌드'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
