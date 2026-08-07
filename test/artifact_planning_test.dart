import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/work_instruction_validator.dart';

void main() {
  final service = BusinessPlanningService();
  final validator = WorkInstructionValidator();

  BusinessPlanInput baseInput({
    required String artifact,
    String contentSubtype = '',
  }) {
    return BusinessPlanInput(
      topic: '테스트 주제',
      customerProblem: '고객 문제',
      targetCustomer: '대상 고객',
      desiredOutcome: '원하는 결과',
      artifactType: artifact,
      contentSubtype: contentSubtype,
      deliverableTypes: [artifact],
    );
  }

  void expectArtifactBuild({
    required String artifact,
    required String expectedTrack,
    String contentSubtype = '',
  }) {
    final input = baseInput(artifact: artifact, contentSubtype: contentSubtype);
    final analysis = service.analyze(input);
    final v1 = service.buildInstruction(
      planId: 'plan_$artifact',
      input: input,
      analysis: analysis,
      instructionId: 'wi_plan_$artifact',
      version: 1,
      now: DateTime.utc(2026, 8, 4),
    );
    expect(v1.schemaVersion, '1.1');
    expect(v1.artifactType, artifact);
    expect(v1.primaryTrack, expectedTrack);
    expect(v1.workflowSteps.length, 18);
    expect(v1.contract, isNotNull);
    expect(
      validator.validate(input: input, instruction: v1).ok,
      isTrue,
      reason: artifact,
    );

    final v2 = service.buildInstruction(
      planId: 'plan_$artifact',
      input: input,
      analysis: analysis,
      instructionId: v1.instructionId,
      version: 2,
      createdAt: v1.createdAt,
    );
    expect(v2.instructionVersion, '2');
    expect(v2.instructionId, v1.instructionId);
  }

  test('ebook artifact build', () {
    expectArtifactBuild(
      artifact: ArtifactType.ebook,
      expectedTrack: 'ebook_dev',
    );
  });

  test('app artifact build', () {
    expectArtifactBuild(artifact: ArtifactType.app, expectedTrack: 'app_dev');
  });

  test('contents+song artifact build', () {
    expectArtifactBuild(
      artifact: ArtifactType.contents,
      contentSubtype: ContentSubtype.song,
      expectedTrack: 'content_dev',
    );
  });

  test('site artifact build', () {
    expectArtifactBuild(artifact: ArtifactType.site, expectedTrack: 'site_dev');
  });

  test('promo_site artifact build', () {
    expectArtifactBuild(
      artifact: ArtifactType.promoSite,
      expectedTrack: 'promo_site_dev',
    );
  });

  test('missing artifact is reported as 제작 형태', () {
    const empty = BusinessPlanInput();
    expect(empty.missingRequiredLabels, contains('제작 형태'));
  });
}
