import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/data/sotong24_production_guides.dart';
import 'package:sotong_ware_control/data/sotong24_workflows.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/screens/standard_production_guide_screen.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/widgets/sotong24_production_guide_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('사업별 가이드 6종 존재', () {
    expect(Sotong24ProductionGuideCatalog.productIds, [
      'ebook',
      'app',
      'industrial',
      'site',
      'promo_site',
      'contents',
    ]);
    for (final id in Sotong24ProductionGuideCatalog.productIds) {
      final g = Sotong24ProductionGuideCatalog.guideFor(id);
      expect(g.stages, isNotEmpty, reason: id);
      expect(g.checklist, isNotEmpty, reason: id);
      expect(g.goal, isNotEmpty, reason: id);
      expect(g.flowOverview, isNotEmpty, reason: id);
      expect(g.keyDeliverables, isNotEmpty, reason: id);
    }
  });

  test('전자책 18단계 canonical 일치 및 stageId 연결', () {
    final g = Sotong24ProductionGuideCatalog.guideFor('ebook');
    expect(g.totalStages, 18);
    expect(
      g.totalStages,
      BusinessPlanningService.standardWorkflowTitles.length,
    );
    expect(g.workflow.stages.length, Sotong24WorkflowCatalog.ebook.totalStages);
    for (var i = 0; i < g.stages.length; i++) {
      final expected = BusinessPlanningService.standardWorkflowTitles[i];
      expect(g.stages[i].stageId, expected.$1);
      expect(g.stages[i].name, expected.$2);
      expect(g.stages[i].purpose, isNotEmpty);
      expect(g.stages[i].whyNeeded, isNotEmpty);
      expect(g.stages[i].mainTasks, isNotEmpty);
      expect(g.stages[i].aiWork, isNotEmpty);
      expect(g.stages[i].humanChecks, isNotEmpty);
      expect(g.stages[i].inputs, isNotEmpty);
      expect(g.stages[i].deliverables, isNotEmpty);
      expect(g.stages[i].qualityCriteria, isNotEmpty);
      expect(g.stages[i].approvalCriteria, isNotEmpty);
      expect(g.stages[i].commonProblems, isNotEmpty);
      expect(g.stages[i].cautions, isNotEmpty);
      expect(g.stages[i].completionConditions, isNotEmpty);
      expect(g.stages[i].nextStep, isNotEmpty);
    }
  });

  test('앱·산업자동화·사이트·마케팅·콘텐츠 가이드 단계 및 상세', () {
    final app = Sotong24ProductionGuideCatalog.guideFor('app');
    expect(app.totalStages, Sotong24WorkflowCatalog.app.totalStages);
    expect(app.totalStages, 23);

    final ind = Sotong24ProductionGuideCatalog.guideFor('industrial');
    expect(ind.totalStages, Sotong24WorkflowCatalog.industrial.totalStages);
    expect(ind.totalStages, 22);
    expect(ind.checklist.any((e) => e.contains('PLC')), isTrue);

    final site = Sotong24ProductionGuideCatalog.guideFor('site');
    expect(site.totalStages, Sotong24WorkflowCatalog.site.totalStages);
    expect(site.totalStages, 22);

    final promo = Sotong24ProductionGuideCatalog.guideFor('promo_site');
    expect(promo.totalStages, Sotong24WorkflowCatalog.promoSite.totalStages);
    expect(promo.totalStages, 22);

    final contents = Sotong24ProductionGuideCatalog.guideFor(
      'contents',
      contentSubtype: ContentSubtype.shorts,
    );
    expect(
      contents.totalStages,
      Sotong24WorkflowCatalog.contentsFor(ContentSubtype.shorts).totalStages,
    );
    expect(contents.totalStages, 20);
    expect(contents.subtypeExtraNotes(ContentSubtype.shorts), isNotEmpty);

    for (final g in [app, ind, site, promo, contents]) {
      for (final s in g.stages) {
        expect(s.whyNeeded, isNotEmpty, reason: '${g.id}/${s.stageId}');
        expect(s.mainTasks, isNotEmpty, reason: '${g.id}/${s.stageId}');
        expect(g.workflow.byId(s.stageId), isNotNull);
      }
    }
  });

  test('가이드 검색', () {
    final g = Sotong24ProductionGuideCatalog.guideFor('ebook');
    expect(g.search('저작권'), isNotEmpty);
    final ind = Sotong24ProductionGuideCatalog.guideFor('industrial');
    expect(ind.search('PLC'), isNotEmpty);
    final promo = Sotong24ProductionGuideCatalog.guideFor('promo_site');
    expect(promo.search('CTA'), isNotEmpty);
  });

  for (final width in [390.0, 768.0, 1280.0]) {
    testWidgets('표준 제작 가이드 UI ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: Sotong24ProductionGuidePanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('사업별 표준 제작 가이드'), findsOneWidget);
      expect(find.textContaining('표준 제작 절차'), findsOneWidget);

      if (width < 768) {
        await tester.tap(find.textContaining('사업 ·'));
        await tester.pumpAndSettle();
      }

      expect(find.text('전자책'), findsWidgets);
      expect(find.text('산업자동화SW'), findsOneWidget);
      expect(find.text('전체 가이드'), findsOneWidget);
      expect(find.text('체크리스트'), findsOneWidget);
      expect(find.textContaining('전자책 표준 제작 가이드'), findsOneWidget);
      expect(find.textContaining('18단계'), findsWidgets);

      // Accordion: open first stage
      await tester.tap(find.textContaining('1. ').first);
      await tester.pumpAndSettle();
      expect(find.text('왜 필요한가'), findsWidgets);
      expect(find.text('품질검사 기준'), findsWidgets);

      await tester.tap(find.text('체크리스트'));
      await tester.pumpAndSettle();
      expect(find.textContaining('참고용'), findsWidgets);
      expect(find.textContaining('기획 완료'), findsWidgets);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('표준제작 가이드 화면에 신 가이드 표시', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StandardProductionGuideScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('전자책 제작'));
    await tester.pumpAndSettle();

    expect(find.textContaining('전자책'), findsWidgets);
    expect(find.text('제작 가이드 (기존 설명)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
