import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/instruction_contract_validator.dart';
import 'package:sotong_ware_control/services/instruction_transfer_core.dart';
import 'package:sotong_ware_control/services/project_design_engine.dart';
import 'package:sotong_ware_control/services/work_instruction_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final service = BusinessPlanningService();
  final engine = ProjectDesignEngine();
  final contractValidator = InstructionContractValidator();
  final legacyValidator = WorkInstructionValidator();

  BusinessPlanInput inputFor({
    required String artifact,
    String subtype = '',
    required String title,
    required List<String> audiences,
    List<String> topics = const [],
    Map<String, List<String>> production = const {},
    String memo = '',
  }) {
    var state = ProjectDesignState(
      artifactType: artifact,
      contentSubtype: subtype.isEmpty ? null : subtype,
      selectedAudiences: audiences,
      selectedTopicIds: topics,
      productionSelections: production,
      designMemo: memo,
      topic: title,
      customerProblem: '$title - confirmed problem',
      targetCustomer: audiences.join(', '),
      desiredOutcome: '$title - confirmed outcome',
    );
    state = engine.syncSentences(state);
    // Lock user-confirmed sentences as canonical.
    state.topic = title;
    state.customerProblem = '$title - confirmed problem';
    state.desiredOutcome = '$title - confirmed outcome';
    if (state.targetCustomer.trim().isEmpty) {
      state.targetCustomer = 'confirmed audience';
    }
    state = engine.confirmPlanning(state);
    final input = engine.toBusinessPlanInput(state);
    return input.copyWith(
      topic: title,
      customerProblem: '$title - confirmed problem',
      targetCustomer: state.targetCustomer,
      desiredOutcome: '$title - confirmed outcome',
    );
  }

  Future<void> assertCase({
    required String name,
    required BusinessPlanInput input,
  }) async {
    final store = BusinessPlanningStore();
    final now = DateTime.utc(2026, 8, 7, 5, 0, 0);
    final analysis = service.analyze(input);
    final instruction = service.buildInstruction(
      planId: 'plan_$name',
      input: input,
      analysis: analysis,
      instructionId: 'wi_$name',
      version: 1,
      now: now,
    );

    expect(instruction.schemaVersion, instructionSchemaVersionCurrent);
    expect(instruction.contract, isNotNull);
    final contract = instruction.contract!;
    expect(contract.identity.artifactType, input.resolvedArtifactType);
    expect(contract.projectDefinition.title.value, input.topic);
    expect(contract.projectDefinition.coreProblem.value, input.customerProblem);
    expect(
      contract.projectDefinition.expectedOutcome.value,
      input.desiredOutcome,
    );
    expect(contract.qualityCriteria, isNotEmpty);
    expect(contract.aiGuards, isNotEmpty);
    expect(contract.workflow.stages, isNotEmpty);
    expect(contract.approval.production, ApprovalStatus.pending);
    expect(contract.productionSpec.artifactType, isNotEmpty);

    expect(instruction.businessIdea, input.topic);
    expect(instruction.customerProblem, input.customerProblem);
    expect(instruction.businessPurpose, input.desiredOutcome);
    expect(instruction.businessIdea, isNot(contains('template title')));
    expect(instruction.targetCustomer, isNot(contains('generic reader')));

    final json = instruction.toJson();
    expect(json['projectDefinition'], isA<Map>());
    expect(json['productionSpec'], isA<Map>());
    expect(json['qualityCriteria'], isA<List>());
    expect(json['aiGuards'], isA<List>());
    expect(json['workflow'], isA<Map>());
    expect(json['approval'], isA<Map>());
    expect(json['validation'], isA<Map>());

    final encoded = const JsonEncoder.withIndent('  ').convert(json);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final roundTrip = WorkInstruction.fromJson(decoded);
    expect(roundTrip.businessIdea, instruction.businessIdea);
    expect(roundTrip.contract?.projectDefinition.title.value, input.topic);
    expect(roundTrip.schemaVersion, instructionSchemaVersionCurrent);

    final withSum = withCanonicalChecksumFields(roundTrip.toJson());
    expect(withSum['contentChecksum'], isNotEmpty);
    expect(withSum['checksumAlgorithm'], checksumAlgorithmCanonicalV2);
    final sumA = stableContentChecksum(withSum);
    final sumB = stableContentChecksum(
      withCanonicalChecksumFields(instruction.toJson()),
    );
    expect(sumA, sumB);

    final fileName = inboxTransferFileName(
      instructionId: instruction.instructionId,
      version: 1,
      artifactType: instruction.artifactType,
    );
    expect(fileName, contains('WI_'));
    expect(fileName, endsWith('.json'));

    final legacy = legacyValidator.validate(
      input: input,
      instruction: instruction,
    );
    expect(legacy.ok, isTrue, reason: '$name legacy: ${legacy.issues}');

    final contractResult = contractValidator.validate(
      input: input,
      instruction: instruction,
    );
    expect(
      contractResult.canTransfer,
      isTrue,
      reason: '$name contract: ${contractResult.issues.map((e) => e.toJson())}',
    );

    final doc = BusinessPlanDocument(
      id: 'doc_$name',
      input: input,
      status: PlanningStatus.instructionReady,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      instructionId: instruction.instructionId,
      version: 1,
      analysis: analysis,
      instruction: instruction,
    );
    await store.upsertPlan(doc);
    final loaded = await store.loadPlans();
    final found = loaded.firstWhere((p) => p.id == 'doc_$name');
    expect(found.input.topic, input.topic);
    expect(found.instruction?.businessIdea, input.topic);
    expect(found.instruction?.contract, isNotNull);
  }

  test('Case1 ebook Contract E2E', () async {
    final input = inputFor(
      artifact: ArtifactType.ebook,
      title: 'Rural AI Practical Ebook',
      audiences: const ['rural', 'age_40_60'],
      topics: const ['ai_usage', 'online_income'],
      production: {
        'format': ['pdf', 'epub'],
        'pages': ['p50'],
        'tone': ['practical'],
        'level': ['beginner'],
        'pricing': ['low'],
      },
      memo: 'checklist focus',
    );
    await assertCase(name: 'ebook', input: input);
  });

  test('Case2 app Contract E2E', () async {
    final input = inputFor(
      artifact: ArtifactType.app,
      title: 'SMB Booking App',
      audiences: const ['smb'],
      topics: const ['local_biz'],
      production: {
        'platform': ['android', 'flutter'],
        'monetization': ['login', 'firebase'],
      },
    );
    await assertCase(name: 'app', input: input);
  });

  test('Case3 contents song/video Contract E2E', () async {
    final song = inputFor(
      artifact: ArtifactType.contents,
      subtype: ContentSubtype.song,
      title: 'Return-to-farm Song',
      audiences: const ['returning_farm'],
      topics: const ['returning_farm_guide'],
      production: {
        'channel': ['song', 'voice'],
      },
    );
    await assertCase(name: 'contents_song', input: song);

    final video = inputFor(
      artifact: ArtifactType.contents,
      subtype: ContentSubtype.video,
      title: 'Smart Farm Video',
      audiences: const ['rural'],
      topics: const ['smart_farm'],
      production: {
        'channel': ['youtube', 'subtitle'],
      },
    );
    await assertCase(name: 'contents_video', input: video);
  });

  test('Case4 knowledge site Contract E2E', () async {
    final input = inputFor(
      artifact: ArtifactType.site,
      title: 'Rural AI Knowledge Site',
      audiences: const ['rural', 'age_60_80'],
      topics: const ['ai_usage', 'gov_support'],
      production: {
        'stack': ['flutter_web', 'seo', 'firebase_hosting'],
      },
    );
    await assertCase(name: 'site', input: input);
  });

  test('Case5 promo site Contract E2E', () async {
    final input = inputFor(
      artifact: ArtifactType.promoSite,
      title: 'Ebook Promo Landing',
      audiences: const ['general', 'office'],
      topics: const ['marketing'],
      production: {
        'promo': ['landing', 'cta', 'analytics'],
      },
    );
    await assertCase(name: 'promo', input: input);
  });

  test('legacy schema 1.0 without Contract', () {
    final legacyJson = <String, dynamic>{
      'schemaVersion': '1.0',
      'instructionId': 'wi_legacy',
      'projectId': 'plan_legacy',
      'instructionVersion': '1',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
      'businessIdea': 'Legacy Ebook Title',
      'businessPurpose': 'Legacy purpose',
      'customerProblem': 'Legacy problem',
      'targetCustomer': 'Legacy audience',
      'deliverableTypes': ['ebook'],
      'recommendedSequence': ['ebook'],
      'valueProposition': 'Legacy value',
      'requiredMaterials': ['memo'],
      'workflowSteps': [
        for (var i = 1; i <= 18; i++)
          {
            'order': i,
            'id': 'step_$i',
            'title': 'Step $i',
            'applicable': true,
            'completionCriteria': 'done',
            'notes': '',
          },
      ],
      'completionCriteria': ['done'],
      'qualityChecks': ['quality'],
      'risks': [],
      'monetizationOptions': [],
      'deploymentTargets': [],
      'promotionChannels': [],
      'approvalItems': ['approval'],
      'executionStatus': '??? ??',
      'notes': '',
      'primaryTrack': 'ebook_dev',
      'followUpTracks': [],
      'artifactType': 'ebook',
      'contentSubtype': '',
    };

    final wi = WorkInstruction.fromJson(legacyJson);
    expect(wi.schemaVersion, '1.0');
    expect(wi.contract, isNull);
    expect(wi.businessIdea, 'Legacy Ebook Title');

    final input = BusinessPlanInput(
      topic: 'Legacy Ebook Title',
      customerProblem: 'Legacy problem',
      targetCustomer: 'Legacy audience',
      desiredOutcome: 'Legacy purpose',
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [ArtifactType.ebook],
    );
    final result = contractValidator.validate(input: input, instruction: wi);
    expect(result.canTransfer, isTrue);
    expect(result.level, ContractValidationLevel.warning);

    final empty = CanonicalValue.undecided();
    expect(empty.pending, isTrue);
    expect(empty.source, FieldSource.undecided);
  });

  test('UI/JSON mismatch is BLOCKED', () {
    final input = BusinessPlanInput(
      topic: 'Confirmed Title',
      customerProblem: 'Confirmed Problem',
      targetCustomer: 'Confirmed Audience',
      desiredOutcome: 'Confirmed Outcome',
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [ArtifactType.ebook],
    );
    final analysis = service.analyze(input);
    final instruction = service.buildInstruction(
      planId: 'mismatch',
      input: input,
      analysis: analysis,
      instructionId: 'wi_mismatch',
    );
    final json = instruction.toJson();
    json['businessIdea'] = 'Polluted Template Title';
    final polluted = WorkInstruction.fromJson(json);
    final result = contractValidator.validate(
      input: input,
      instruction: polluted,
    );
    expect(result.isBlocked, isTrue);
  });

  test('auto approval without executionMode continuous is BLOCKED', () {
    final input = inputFor(
      artifact: ArtifactType.app,
      title: 'Continuous Contract App',
      audiences: const ['mobile users'],
    );
    final analysis = service.analyze(input);
    final instruction = service.buildInstruction(
      planId: 'continuous_contract',
      input: input,
      analysis: analysis,
      instructionId: 'wi_continuous_contract',
      aiExecution: AiExecutionPolicy.productionApp(approvalMode: 'auto'),
    );
    expect(instruction.aiExecution!.executionMode, 'continuous');

    final brokenJson = instruction.toJson();
    brokenJson['aiExecution'] = {
      ...instruction.aiExecution!.toJson(),
      'executionMode': 'hold',
    };
    final broken = WorkInstruction.fromJson(brokenJson);
    final result = contractValidator.validate(
      input: input,
      instruction: broken,
    );
    expect(result.isBlocked, isTrue);
    expect(
      result.blockers.any((b) => b.field == 'aiExecution.executionMode'),
      isTrue,
    );
  });
}
