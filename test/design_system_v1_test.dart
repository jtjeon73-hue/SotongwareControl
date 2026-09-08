import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/commercial/commercial_quality_attachment.dart';
import 'package:sotong_ware_control/models/design_system/design_system_catalog.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/commercial_studio_builder.dart';
import 'package:sotong_ware_control/services/design_system/design_system_service.dart';
import 'package:sotong_ware_control/widgets/site_user_review_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DesignSystemCatalog catalog;

  setUpAll(() async {
    final raw = await rootBundle.loadString(DesignSystemCatalog.kAssetPath);
    catalog = DesignSystemCatalog.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  });

  test('catalog has unique A~E profiles and brand core', () {
    expect(catalog.designSystemVersion, '1.0.0');
    expect(catalog.brandCore.publicName, 'SotongWare');
    final codes = catalog.profiles.map((p) => p.profileCode).toList();
    expect(codes.toSet(), containsAll(['A', 'B', 'C', 'D', 'E']));
    expect(codes.toSet().length, codes.length);
    expect(catalog.defaultProfile.profileCode, 'A');
    for (final p in catalog.profiles) {
      expect(p.trackAdaptation.keys, containsAll([
        'app',
        'site',
        'ebook',
        'knowledge_education',
        'marketing',
        'contents',
      ]));
    }
  });

  test('AI recommend industrial → B, shorts → E, fallback → A', () {
    final svc = DesignSystemService.instance;
    final b = svc.recommend(
      catalog: catalog,
      artifactType: 'site',
      contextText: '산업자동화 제조 설비 B2B',
    );
    expect(b.designProfileCode, 'B');
    expect(b.designSource, 'ai_recommended');

    final e = svc.recommend(
      catalog: catalog,
      artifactType: 'contents',
      contextText: '쇼츠 영상 릴스',
    );
    expect(e.designProfileCode, 'E');

    final a = svc.recommend(
      catalog: catalog,
      artifactType: 'app',
      contextText: '일반 업무 도구',
    );
    expect(a.designProfileCode, 'A');
  });

  test('WI payload serializes design selection fields', () {
    final state = ProjectDesignState(
      artifactType: ArtifactType.site,
      displayTitle: '테스트 사이트',
      topic: '산업자동화',
      customerProblem: '현장 정보 분산',
      desiredOutcome: '통합 안내',
      originalUserBrief: '산업자동화 소개 사이트',
      originalUserBriefConfirmed: true,
      reasonsToPay: const ['전문 신뢰'],
      uniqueValue: '산업 맞춤 구성',
      designProfileCode: 'B',
      designProfileId: 'ds_profile_b_premium_technology',
      designProfileVersion: '1.0.0',
      designSystemVersion: '1.0.0',
      designSource: 'user_selected',
      siteSubtype: 'corporate_site',
      productionSelections: {
        'site_kind': ['corporate_site'],
      },
      planningConfirmed: true,
    );
    final input = BusinessPlanInput(
      topic: state.topic,
      customerProblem: state.customerProblem,
      targetCustomer: '제조 기업',
      desiredOutcome: state.desiredOutcome,
      artifactType: ArtifactType.site,
    );
    final attachment = const CommercialStudioBuilder().tryBuild(
      state: state,
      input: input,
      instructionId: 'wi_test_design_b',
      projectId: 'proj_design_b',
    );
    expect(attachment, isNotNull);
    final fields = attachment!.toInstructionJsonFields();
    expect(fields['designProfileCode'], 'B');
    expect(fields['designProfileId'], 'ds_profile_b_premium_technology');
    expect(fields['designSystemVersion'], '1.0.0');
    expect(fields['designSource'], 'user_selected');
    expect(fields['designDirection'], 'premium_industrial');

    final roundTrip = CommercialQualityAttachment.fromInstructionJson(fields);
    expect(roundTrip.designSelection?.designProfileCode, 'B');
  });

  test('existing WI without design fields remains compatible', () {
    final parsed = CommercialQualityAttachment.fromInstructionJson({
      'title': 'legacy',
    });
    expect(parsed.designSelection, isNull);
  });

  test('design_change_requested carries profile code + legacy direction', () {
    final p = SiteReviewDecisionPayload(
      reviewDecision: 'design_change_requested',
      selectedDesignDirection: 'more_premium',
      designProfileCode: 'D',
      designSystemVersion: '1.0.0',
      reviewedRevision: 'r3',
      reviewComment: 'B→D 디자인만 변경',
    );
    final msg = p.toRevisionMessage();
    expect(msg, contains('[designProfileCode=D]'));
    expect(msg, contains('[designSource=revision_change]'));
    expect(msg, contains('[selectedDesignDirection=more_premium]'));
    final tags = SiteReviewDecisionPayload.parseTags(msg);
    expect(tags.designProfileCode, 'D');
    expect(tags.selectedDesignDirection, 'more_premium');
    expect(tags.reviewedRevision, 'r3');
  });

  test('profile options A~E mapped for UI', () {
    expect(kDesignSystemProfileOptions.map((e) => e.$1).toList(),
        ['A', 'B', 'C', 'D', 'E']);
  });

  test('preReview quality hook prepared without auto loop', () {
    final report = DesignSystemService.instance.buildPreReviewHook(
      recommendedDesignProfileCode: 'B',
    );
    expect(report.preReviewQualityGate, isFalse);
    expect(report.recommendedDesignProfileCode, 'B');
    expect(report.issues, isNotEmpty);
    expect(catalog.designQualityProfile['hooks'], isA<Map>());
    final hooks = Map<String, dynamic>.from(
      catalog.designQualityProfile['hooks'] as Map,
    );
    expect(hooks['autoImprovementLoop'], isFalse);
  });
}
