import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/planning_summary.dart';
import 'package:sotong_ware_control/models/planning_wizard_state.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/dev_work_doc_paths.dart';
import 'package:sotong_ware_control/services/dev_work_doc_service.dart';
import 'package:sotong_ware_control/services/planning_sentence_composer.dart';
import 'package:sotong_ware_control/services/work_instruction_validator.dart';

void main() {
  const composer = PlanningSentenceComposer();
  const testTopic = '[TEST] 시골에서 AI를 활용해 온라인 수익 기반을 만드는 방법';
  const testAudience = '[TEST] 농촌 거주 중장년, AI 온라인 부업';
  const testProblem = '[TEST] 순서·수익모델·실행 막연';
  const testDeliverables = '[TEST] 실천형 전자책 원고, 체크리스트, 90일 실행계획';

  PlanningWizardState ruralEbookWizard() => PlanningWizardState(
    mode: 'quick',
    step: 4,
    artifactType: ArtifactType.ebook,
    topic: testTopic,
    customerProblem: testProblem,
    targetCustomer: testAudience,
    desiredOutcome: testDeliverables,
    sentencesManuallyEdited: true,
    artifactAnswers: {
      'customerProblem': ['productize_unknown'],
      'targetCustomer': ['return_prep', 'sidejob_40_60'],
      'desiredOutcome': ['ebook_first'],
      'salesDeploy': ['cheap_validate'],
    },
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('rural AI ebook — required fields and artifact', () {
    final state = ruralEbookWizard();
    final input = composer
        .toBusinessPlanInput(state)
        .copyWith(notes: '[TEST] rural ebook flow');

    expect(input.hasRequiredFields, isTrue);
    expect(input.resolvedArtifactType, ArtifactType.ebook);
    expect(input.topic, contains('[TEST]'));
  });

  test('rural AI ebook — primaryTrack ebook_dev / 전자책개발', () {
    final input = composer.toBusinessPlanInput(ruralEbookWizard());
    expect(input.primaryTrack, 'ebook_dev');
    expect(ArtifactType.primaryTrack(input.resolvedArtifactType), '전자책개발');
    expect(ArtifactType.labelKo(ArtifactType.ebook), '전자책');
  });

  test('rural AI ebook — buildInstruction v1 schema and checksum', () {
    final service = BusinessPlanningService();
    final input = composer.toBusinessPlanInput(ruralEbookWizard());
    final analysis = service.analyze(input);
    const iid = 'wi_test_rural_ai';

    var v1 = service.buildInstruction(
      planId: 'plan_test_rural_ai',
      input: input,
      analysis: analysis,
      instructionId: iid,
      version: 1,
      now: DateTime.utc(2026, 8, 5),
    );

    expect(v1.instructionId, iid);
    expect(v1.instructionVersion, '1');
    expect(v1.schemaVersion, '1.0');
    expect(v1.artifactType, ArtifactType.ebook);
    expect(v1.primaryTrack, 'ebook_dev');
    expect(v1.followUpTracks, isNotEmpty);

    final provisional = Map<String, dynamic>.from(v1.toJson())
      ..remove('checksum');
    final checksum = contentChecksum(
      const JsonEncoder.withIndent('  ').convert(provisional),
    );

    v1 = service.buildInstruction(
      planId: 'plan_test_rural_ai',
      input: input,
      analysis: analysis,
      instructionId: iid,
      version: 1,
      createdAt: v1.createdAt,
      checksum: checksum,
      now: DateTime.utc(2026, 8, 5),
    );

    expect(v1.checksum, checksum);
    expect(v1.checksum, isNotEmpty);
  });

  test('rural AI ebook — v2 bumps version with same instructionId', () {
    final service = BusinessPlanningService();
    final input = composer.toBusinessPlanInput(ruralEbookWizard());
    final analysis = service.analyze(input);
    const iid = 'wi_test_rural_ai';

    final v1 = service.buildInstruction(
      planId: 'plan_test_rural_ai',
      input: input,
      analysis: analysis,
      instructionId: iid,
      version: 1,
    );
    final v2 = service.buildInstruction(
      planId: 'plan_test_rural_ai',
      input: input,
      analysis: analysis,
      instructionId: iid,
      version: 2,
      createdAt: v1.createdAt,
    );

    expect(v2.instructionId, iid);
    expect(v2.instructionVersion, '2');
  });

  test('rural AI ebook — DevWorkDocPaths active and versionRelative', () {
    const iid = 'wi_test_rural_ai';
    expect(
      DevWorkDocPaths.activeRelative(ArtifactType.ebook, iid),
      'Ebook/Active/WI_wi_test_rural_ai.json',
    );
    expect(
      DevWorkDocPaths.versionRelative(ArtifactType.ebook, iid, 1),
      'Ebook/Versions/wi_test_rural_ai/WI_wi_test_rural_ai_v1.json',
    );
    expect(
      DevWorkDocPaths.versionRelative(ArtifactType.ebook, iid, 2),
      'Ebook/Versions/wi_test_rural_ai/WI_wi_test_rural_ai_v2.json',
    );
  });

  test(
    'rural AI ebook — BusinessPlanningStore.latestByInstructionId dedupes',
    () {
      const iid = 'wi_test_rural_ai';
      final a1 = BusinessPlanDocument(
        id: 'plan_a1',
        input: BusinessPlanInput(topic: testTopic),
        status: PlanningStatus.draft,
        createdAt: '2026-08-01T00:00:00Z',
        updatedAt: '2026-08-01T00:00:00Z',
        instructionId: iid,
        version: 1,
      );
      final a2 = BusinessPlanDocument(
        id: 'plan_a2',
        input: a1.input,
        status: PlanningStatus.instructionReady,
        createdAt: a1.createdAt,
        updatedAt: '2026-08-05T00:00:00Z',
        instructionId: iid,
        version: 2,
      );
      final latest = BusinessPlanningStore.latestByInstructionId([a1, a2]);
      expect(latest.length, 1);
      expect(latest.single.instructionId, iid);
      expect(latest.single.version, 2);
    },
  );

  test('rural AI ebook — WorkInstructionValidator passes', () {
    final service = BusinessPlanningService();
    final input = composer.toBusinessPlanInput(ruralEbookWizard());
    final analysis = service.analyze(input);
    final instruction = service.buildInstruction(
      planId: 'plan_test_rural_ai',
      input: input,
      analysis: analysis,
      instructionId: 'wi_test_rural_ai',
      version: 1,
    );
    final result = WorkInstructionValidator().validate(
      input: input,
      instruction: instruction,
    );
    expect(result.ok, isTrue);
  });

  test('rural AI ebook — transfer JSON includes required fields', () {
    final service = BusinessPlanningService();
    final input = composer.toBusinessPlanInput(ruralEbookWizard());
    final analysis = service.analyze(input);
    final instruction = service.buildInstruction(
      planId: 'plan_test_rural_ai',
      input: input,
      analysis: analysis,
      instructionId: 'wi_test_rural_ai',
      version: 1,
      checksum: 'abc123',
      status: PlanningStatus.instructionReady,
    );
    final json = instruction.toJson();

    expect(json['instructionId'], 'wi_test_rural_ai');
    expect(json['instructionVersion'], '1');
    expect(json['schemaVersion'], '1.0');
    expect(json['artifactType'], ArtifactType.ebook);
    expect(json['primaryTrack'], 'ebook_dev');
    expect(json['status'], isNotEmpty);
    expect(json['checksum'], 'abc123');
  });

  test('rural AI ebook — PlanningSummary.fromWizard confirmation fields', () {
    final state = ruralEbookWizard();
    final summary = PlanningSummary.fromWizard(state);

    expect(summary.artifactLabel, '전자책');
    expect(summary.primaryTrack, '전자책개발');
    expect(summary.mainDeliverables, contains(testDeliverables));
    expect(summary.targetUser, testAudience);
    expect(summary.purpose, testTopic);
    expect(summary.transferReadyLabel, '작업지시서 미생성 — 전달 준비 전');

    final withInstruction = PlanningSummary.fromWizard(
      state,
      hasInstruction: true,
    );
    expect(withInstruction.transferReadyLabel, '작업지시서 생성됨 — 소통24워크 전달 가능');
  });

  test(
    'rural AI ebook — downloadInstructionJson is download-only mode',
    () async {
      final service = BusinessPlanningService();
      final devWorkDoc = DevWorkDocService();
      final input = composer.toBusinessPlanInput(ruralEbookWizard());
      final analysis = service.analyze(input);
      final instruction = service.buildInstruction(
        planId: 'plan_test_rural_ai',
        input: input,
        analysis: analysis,
        instructionId: 'wi_test_rural_ai',
        version: 1,
      );
      final jsonText = const JsonEncoder.withIndent(
        '  ',
      ).convert(instruction.toJson());

      final result = await devWorkDoc.downloadInstructionJson(
        artifactType: ArtifactType.ebook,
        instructionId: 'wi_test_rural_ai',
        version: 1,
        jsonText: jsonText,
      );

      expect(result.ok, isTrue);
      expect(result.mode, 'download');
      expect(result.message, contains('DevWorkDoc 직접 저장 아님'));
    },
  );

  test('rural AI ebook — archive then restore keeps instructionId/version', () {
    final service = BusinessPlanningService();
    final input = composer.toBusinessPlanInput(ruralEbookWizard());
    final analysis = service.analyze(input);
    final instruction = service.buildInstruction(
      planId: 'plan_test_rural_ai',
      input: input,
      analysis: analysis,
      instructionId: 'wi_test_rural_ai',
      version: 2,
      checksum: 'chk2',
      status: PlanningStatus.instructionReady,
    );
    final active = BusinessPlanDocument(
      id: 'plan_test_rural_ai',
      input: input,
      status: PlanningStatus.instructionReady,
      createdAt: '2026-08-05T00:00:00Z',
      updatedAt: '2026-08-05T01:00:00Z',
      instruction: instruction,
      instructionId: 'wi_test_rural_ai',
      version: 2,
    );

    final archived = active.copyWith(
      status: PlanningStatus.archived,
      updatedAt: '2026-08-05T02:00:00Z',
    );
    expect(archived.status, PlanningStatus.archived);
    expect(archived.stableInstructionId, 'wi_test_rural_ai');
    expect(archived.version, 2);
    expect(
      DevWorkDocPaths.archiveRelative(ArtifactType.ebook, archived.stableInstructionId, 2),
      'Ebook/Archive/WI_wi_test_rural_ai_v2.json',
    );

    final restored = archived.copyWith(
      status: PlanningStatus.instructionReady,
      updatedAt: '2026-08-05T03:00:00Z',
    );
    expect(restored.status, PlanningStatus.instructionReady);
    expect(restored.instruction?.instructionId, 'wi_test_rural_ai');
    expect(restored.version, 2);
    expect(restored.instruction?.checksum, 'chk2');
  });
}
