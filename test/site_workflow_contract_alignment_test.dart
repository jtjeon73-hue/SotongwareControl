/// Site preview/WI must match Sotong24Work SiteStageContract (18), not legacy 22.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/sotong24_workflows.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';

void main() {
  const expectedIds = <String>[
    'idea_clarify',
    'problem_validate',
    'site_materials_prep',
    'site_audience_search',
    'site_information_architecture',
    'site_brand_conversion',
    'site_responsive_ux',
    'site_content_media_plan',
    'site_project_scaffold',
    'site_core_pages',
    'site_conversion_features',
    'site_seo_metadata',
    'site_a11y_perf_security',
    'site_build_preview_test',
    'site_user_review',
    'site_revision_quality',
    'site_launch_package',
    'site_deploy_release',
  ];

  test('site catalog is exactly SiteStageContract 18', () {
    final wf = Sotong24WorkflowCatalog.forProduct(ArtifactType.site);
    expect(wf.totalStages, 18);
    expect(wf.stages.map((s) => s.id).toList(), expectedIds);
    expect(wf.stages.last.name, contains('배포'));
    // Legacy aspirational 22-step IDs must not appear.
    expect(wf.stages.any((s) => s.id == 'site_monetize'), isFalse);
    expect(wf.stages.any((s) => s.id == 'site_approve'), isFalse);
  });

  test('promo_site preview shares the same 18 site contract', () {
    final promo = Sotong24WorkflowCatalog.forProduct(ArtifactType.promoSite);
    expect(promo.totalStages, 18);
    expect(promo.stages.map((s) => s.id).toList(), expectedIds);
  });

  test('site WI payload workflowSteps match SiteStageContract', () {
    final service = BusinessPlanningService();
    final input = BusinessPlanInput(
      topic: '지역 상점 홍보 사이트',
      customerProblem: '온라인 문의가 없다',
      targetCustomer: '소상공인',
      desiredOutcome: '문의 전환',
      artifactType: ArtifactType.site,
    );
    final analysis = service.analyze(input);
    final wi = service.buildInstruction(
      planId: 'plan_site_18',
      input: input,
      analysis: analysis,
      instructionId: 'wi_test_site_18_contract',
    );
    expect(wi.workflowSteps.length, 18);
    expect(wi.workflowSteps.map((s) => s.id).toList(), expectedIds);
    expect(wi.workflowSteps.first.id, 'idea_clarify');
    expect(wi.workflowSteps.last.id, 'site_deploy_release');
    // Must not emit ebook shared mid-pipeline IDs for site.
    expect(wi.workflowSteps.any((s) => s.id == 'materials_prep'), isFalse);
    expect(wi.workflowSteps.any((s) => s.id == 'deploy'), isFalse);
  });
}
