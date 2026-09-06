/// Site type selection UI, next-button gate, draft persistence, WI subtype routing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/project_design_catalog.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/commercial_studio_builder.dart';
import 'package:sotong_ware_control/services/site_subtype_contract.dart';
import 'package:sotong_ware_control/widgets/project_design/project_design_wizard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('site subtype contract', () {
    test('canonical tokens match catalog', () {
      final catalogIds = ProjectDesignCatalog.siteKinds.map((e) => e.id).toSet();
      expect(catalogIds, SiteSubtypeContract.knownWorkSubtypes);
    });

    test('legacy promo aliases map to marketing_site only', () {
      expect(
        SiteSubtypeContract.normalizeOrEmpty('promo_site'),
        SiteSubtypeContract.marketingSite,
      );
      expect(
        SiteSubtypeContract.normalizeOrEmpty('web_marketing'),
        SiteSubtypeContract.marketingSite,
      );
      expect(SiteSubtypeContract.normalizeOrEmpty('site'), isEmpty);
      expect(SiteSubtypeContract.normalizeOrEmpty(''), isEmpty);
    });
  });

  group('next-button required-field gate', () {
    test('site parent alone cannot proceed', () {
      final state = ProjectDesignState(artifactType: ArtifactType.site);
      expect(state.canProceedFromArtifact, isFalse);
    });

    test('marketing_site enables next', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.site,
        siteSubtype: SiteSubtypeContract.marketingSite,
      );
      expect(state.canProceedFromArtifact, isTrue);
    });

    test('ebook / app unchanged', () {
      expect(
        ProjectDesignState(artifactType: ArtifactType.ebook).canProceedFromArtifact,
        isTrue,
      );
      expect(
        ProjectDesignState(artifactType: ArtifactType.app).canProceedFromArtifact,
        isTrue,
      );
    });

    test('contents still requires contentSubtype', () {
      expect(
        ProjectDesignState(artifactType: ArtifactType.contents).canProceedFromArtifact,
        isFalse,
      );
      expect(
        ProjectDesignState(
          artifactType: ArtifactType.contents,
          contentSubtype: ContentSubtype.shorts,
        ).canProceedFromArtifact,
        isTrue,
      );
    });
  });

  group('draft / back-forward persistence', () {
    test('json round-trip keeps siteSubtype', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.site,
        siteSubtype: SiteSubtypeContract.marketingSite,
        productionSelections: {
          'site_kind': [SiteSubtypeContract.marketingSite],
        },
      );
      final restored = ProjectDesignState.fromJson(state.toJson());
      expect(restored.siteSubtype, SiteSubtypeContract.marketingSite);
      expect(restored.canProceedFromArtifact, isTrue);
    });

    test('wizardState round-trip keeps siteSubtype', () {
      final state = ProjectDesignState(
        step: ProjectDesignStep.audience,
        artifactType: ArtifactType.site,
        siteSubtype: SiteSubtypeContract.knowledgeSite,
      );
      final restored = ProjectDesignState.fromWizardState(state.toWizardState());
      expect(restored.siteSubtype, SiteSubtypeContract.knowledgeSite);
      expect(restored.step, ProjectDesignStep.audience);
    });

    test('changing subtype clears stale prior value', () {
      var state = ProjectDesignState(
        artifactType: ArtifactType.site,
        siteSubtype: SiteSubtypeContract.corporateSite,
      );
      state = state.copy()..siteSubtype = SiteSubtypeContract.marketingSite;
      expect(state.siteSubtype, SiteSubtypeContract.marketingSite);
      expect(state.siteSubtype, isNot(SiteSubtypeContract.corporateSite));
    });
  });

  group('WI payload + Control→Work routing fields', () {
    ProjectDesignState richSiteState(String subtype) {
      return ProjectDesignState(
        artifactType: ArtifactType.site,
        siteSubtype: subtype,
        productionSelections: {
          'site_kind': [subtype],
        },
        selectedAudiences: const ['smb'],
        selectedConceptIds: const [],
        topic: '지역 상점 홍보 사이트',
        customerProblem: '온라인 문의가 없다',
        targetCustomer: '소상공인',
        desiredOutcome: '문의·예약 전환',
        displayTitle: '지역 상점 홍보 사이트',
        originalUserBrief: '지역 상점 홍보 사이트 제작',
        originalUserBriefConfirmed: true,
        reasonsToPay: const ['문의가 늘어난다'],
        uniqueValue: '지역 맞춤 CTA',
        planningConfirmed: true,
      );
    }

    test('marketing_site lands in commercialSiteQualityProfile', () {
      final state = richSiteState(SiteSubtypeContract.marketingSite);
      final input = BusinessPlanInput(
        topic: state.topic,
        customerProblem: state.customerProblem,
        targetCustomer: state.targetCustomer,
        desiredOutcome: state.desiredOutcome,
        artifactType: ArtifactType.site,
      );
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: input,
        instructionId: 'wi_test_site_marketing',
        projectId: 'proj_site_marketing',
      );
      expect(attachment, isNotNull);
      expect(
        attachment!.siteProfile.sitePurpose,
        SiteSubtypeContract.marketingSite,
      );
      expect(
        attachment.siteProfile.siteSubtype,
        SiteSubtypeContract.marketingSite,
      );

      final analysis = BusinessPlanningService().analyze(input);
      final wi = BusinessPlanningService().buildInstruction(
        planId: 'proj_site_marketing',
        input: input,
        analysis: analysis,
        instructionId: 'wi_test_site_marketing',
        commercialQuality: attachment,
      );
      final json = wi.toJson();
      expect(json['artifactType'], ArtifactType.site);
      expect(
        json['commercialSiteQualityProfile']['sitePurpose'],
        SiteSubtypeContract.marketingSite,
      );
      expect(
        json['commercialSiteQualityProfile']['siteSubtype'],
        SiteSubtypeContract.marketingSite,
      );
      final deliverables = (json['deliverableTypes'] as List).map((e) => '$e');
      expect(deliverables, contains(SiteSubtypeContract.marketingSite));
      // Must not silently invent corporate when marketing was chosen.
      expect(
        json['commercialSiteQualityProfile']['sitePurpose'],
        isNot(SiteSubtypeContract.corporateSite),
      );
    });

    test('no default subtype without selection', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.site,
        topic: '제목',
        customerProblem: '문제',
        targetCustomer: '고객',
        desiredOutcome: '결과',
        displayTitle: '제목',
        originalUserBrief: '브리프',
        reasonsToPay: const ['이유'],
        uniqueValue: '가치',
      );
      final input = BusinessPlanInput(
        topic: state.topic,
        customerProblem: state.customerProblem,
        targetCustomer: state.targetCustomer,
        desiredOutcome: state.desiredOutcome,
        artifactType: ArtifactType.site,
      );
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: input,
        instructionId: 'wi_test_site_nosub',
        projectId: 'proj_site_nosub',
      );
      expect(attachment, isNull);
    });

    test('corporate / knowledge map to canonical tokens', () {
      for (final sub in [
        SiteSubtypeContract.corporateSite,
        SiteSubtypeContract.knowledgeSite,
      ]) {
        final state = richSiteState(sub);
        final input = BusinessPlanInput(
          topic: state.topic,
          customerProblem: state.customerProblem,
          targetCustomer: state.targetCustomer,
          desiredOutcome: state.desiredOutcome,
          artifactType: ArtifactType.site,
        );
        final attachment = const CommercialStudioBuilder().tryBuild(
          state: state,
          input: input,
          instructionId: 'wi_test_$sub',
          projectId: 'proj_$sub',
        );
        expect(attachment!.siteProfile.sitePurpose, sub);
      }
    });
  });

  group('site type selection UI', () {
    Future<ProjectDesignState?> pumpAndCapture(
      WidgetTester tester, {
      required Size size,
      required Future<void> Function(WidgetTester t) interact,
    }) async {
      ProjectDesignState? latest;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProjectDesignWizard(
                  initial: ProjectDesignState(),
                  onChanged: (s) => latest = s,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await interact(tester);
      await tester.pumpAndSettle();
      return latest;
    }

    testWidgets('mobile: site kinds select marketing and gate next', (
      tester,
    ) async {
      final latest = await pumpAndCapture(
        tester,
        size: const Size(390, 844),
        interact: (t) async {
          await t.tap(find.text('사이트 개발'));
          await t.pumpAndSettle();
          expect(find.text('사이트 유형'), findsOneWidget);

          // Next must stay disabled without subtype.
          final nextBefore = t.widget<FilledButton>(
            find.widgetWithText(FilledButton, '다음'),
          );
          expect(nextBefore.onPressed, isNull);

          await t.ensureVisible(find.text('홍보·마케팅 사이트'));
          await t.tap(find.text('홍보·마케팅 사이트'));
          await t.pumpAndSettle();
        },
      );

      expect(latest, isNotNull);
      expect(latest!.artifactType, ArtifactType.site);
      expect(latest.siteSubtype, SiteSubtypeContract.marketingSite);
      expect(latest.canProceedFromArtifact, isTrue);

      final nextAfter = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '다음'),
      );
      expect(nextAfter.onPressed, isNotNull);

      // Selected chip visual
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '홍보·마케팅 사이트'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('desktop: subtype change replaces stale value', (tester) async {
      final latest = await pumpAndCapture(
        tester,
        size: const Size(1280, 800),
        interact: (t) async {
          await t.tap(find.text('사이트 개발'));
          await t.pumpAndSettle();
          await t.tap(find.text('기업·기관 홈페이지'));
          await t.pumpAndSettle();
          await t.tap(find.text('홍보·마케팅 사이트'));
          await t.pumpAndSettle();
        },
      );
      expect(latest!.siteSubtype, SiteSubtypeContract.marketingSite);
      expect(
        find.widgetWithText(FilterChip, '기업·기관 홈페이지'),
        findsOneWidget,
      );
      final corporate = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '기업·기관 홈페이지'),
      );
      final marketing = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '홍보·마케팅 사이트'),
      );
      expect(corporate.selected, isFalse);
      expect(marketing.selected, isTrue);
    });

    testWidgets('back/forward keeps subtype', (tester) async {
      ProjectDesignState? latest;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProjectDesignWizard(
                  initial: ProjectDesignState(
                    artifactType: ArtifactType.site,
                    siteSubtype: SiteSubtypeContract.marketingSite,
                    productionSelections: {
                      'site_kind': [SiteSubtypeContract.marketingSite],
                    },
                  ),
                  onChanged: (s) => latest = s,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('홍보·마케팅 사이트'), findsOneWidget);
      final next = find.widgetWithText(FilledButton, '다음');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(latest?.step, ProjectDesignStep.audience);

      final back = find.widgetWithText(OutlinedButton, '이전');
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(latest?.step, ProjectDesignStep.artifact);
      expect(latest?.siteSubtype, SiteSubtypeContract.marketingSite);
      final marketing = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '홍보·마케팅 사이트'),
      );
      expect(marketing.selected, isTrue);
    });
  });
}
