import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/concept_candidate.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/commercial_studio_builder.dart';
import 'package:sotong_ware_control/services/commercial_work_instruction_preflight.dart';
import 'package:sotong_ware_control/services/instruction_contract_validator.dart';
import 'package:sotong_ware_control/services/project_design_engine.dart';
import 'package:sotong_ware_control/services/work_instruction_workshop_presentation.dart';

/// manualOnly(직접 입력) ebook → SSOT canonical title/coreProblem/expectedOutcome
/// 이 pending/empty로 남지 않는지 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const title = '하루 10분, 생활이 편해지는 AI 활용법';
  const coreProblem =
      'AI를 접해봤지만 무엇을 어떻게 질문해야 하는지 모르고, '
      '검색·문서작성·일정관리·정보정리 등 일상과 업무에 '
      'AI를 실제로 활용하는 방법이 어렵다.';
  const targetCustomer = 'AI 초보 일반 성인, 직장인, 주부, 40~60대 중장년층';
  const expectedOutcome = '상용 수준 전자책 + PDF/EPUB + SotongWare Reader 등록을 고려한 결과';

  final service = BusinessPlanningService();
  final engine = ProjectDesignEngine();
  final contractValidator = InstructionContractValidator();

  /// 운영 버그 재현: advanced wizardSelections에 값은 있으나
  /// fieldStatuses가 undecided/userEdited이거나 누락된 경우.
  BusinessPlanInput advancedManualInput({
    DesignFieldStatus status = DesignFieldStatus.undecided,
    bool includeFieldStatuses = true,
    bool stampUserConfirmed = false,
  }) {
    final effective = stampUserConfirmed
        ? DesignFieldStatus.userConfirmed
        : status;
    final wizard = <String, dynamic>{
      'mode': 'advanced',
      'topic': title,
      'customerProblem': coreProblem,
      'targetCustomer': targetCustomer,
      'desiredOutcome': expectedOutcome,
      'artifactType': ArtifactType.ebook,
      'customTexts': {
        'manualOnlyMode': 'true',
        'topicStatus': effective.name,
        'problemStatus': effective.name,
        'outcomeStatus': effective.name,
        'customerStatus': effective.name,
        'planningConfirmed': 'true',
        'titleSource': 'manual',
        'displayTitle': title,
        'workingTitle': title,
      },
    };
    if (includeFieldStatuses) {
      wizard['fieldStatuses'] = {
        'topic': effective.name,
        'problem': effective.name,
        'outcome': effective.name,
        'customer': effective.name,
        'planningConfirmed': true,
      };
    }
    return BusinessPlanInput(
      topic: title,
      customerProblem: coreProblem,
      targetCustomer: targetCustomer,
      desiredOutcome: expectedOutcome,
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [DeliverableType.ebook],
      wizardSelections: wizard,
    );
  }

  group('manualOnly ebook canonical SSOT mapping', () {
    test('undecided statuses still map non-empty values as non-pending', () {
      final input = advancedManualInput(status: DesignFieldStatus.undecided);
      final instruction = service.buildInstruction(
        planId: 'plan_manual_canon',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_manual_canon',
        version: 1,
        now: DateTime.utc(2026, 9, 15, 12),
      );

      final contract = instruction.contract!;
      final def = contract.projectDefinition;

      expect(def.title.value, title);
      expect(def.title.pending, isFalse);
      expect(def.title.isBlank, isFalse);

      expect(def.coreProblem.value, coreProblem);
      expect(def.coreProblem.pending, isFalse);
      expect(def.coreProblem.isBlank, isFalse);

      expect(def.expectedOutcome.value, expectedOutcome);
      expect(def.expectedOutcome.pending, isFalse);
      expect(def.expectedOutcome.isBlank, isFalse);

      expect(
        def.targetCustomers.isNotEmpty ||
            !def.targetCustomerDescription.isBlank,
        isTrue,
      );
      expect(def.targetCustomerDescription.value, contains('AI 초보'));

      final spec = instruction.contract!.productionSpec;
      expect(spec.undecidedKeys, isEmpty, reason: '${spec.undecidedKeys}');
      expect(spec.spec.length, greaterThanOrEqualTo(2));
      expect(spec.spec['outputFormat'], containsAll(['pdf', 'epub']));
    });

    test('userEdited statuses (pre-fix sync) map as non-pending', () {
      final input = advancedManualInput(status: DesignFieldStatus.userEdited);
      final instruction = service.buildInstruction(
        planId: 'plan_manual_edited',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_manual_edited',
        version: 1,
        now: DateTime.utc(2026, 9, 15, 12),
      );
      final def = instruction.contract!.projectDefinition;
      expect(def.title.pending, isFalse);
      expect(def.coreProblem.pending, isFalse);
      expect(def.expectedOutcome.pending, isFalse);
    });

    test('payload JSON carries non-pending canonical fields', () {
      final input = advancedManualInput(stampUserConfirmed: true);
      final instruction = service.buildInstruction(
        planId: 'plan_manual_payload',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_manual_payload',
        version: 1,
        now: DateTime.utc(2026, 9, 15, 12),
      );
      final json = instruction.toJson();
      final projectDef = json['projectDefinition'] as Map<String, dynamic>;
      final titleMap = projectDef['title'] as Map<String, dynamic>;
      final problemMap = projectDef['coreProblem'] as Map<String, dynamic>;
      final outcomeMap = projectDef['expectedOutcome'] as Map<String, dynamic>;

      expect(titleMap['value'], title);
      expect(titleMap['pending'] == true, isFalse);
      expect(problemMap['value'], coreProblem);
      expect(problemMap['pending'] == true, isFalse);
      expect(outcomeMap['value'], expectedOutcome);
      expect(outcomeMap['pending'] == true, isFalse);

      final encoded = const JsonEncoder.withIndent('  ').convert(json);
      final roundTrip = WorkInstruction.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      final rt = roundTrip.contract!.projectDefinition;
      expect(rt.title.pending, isFalse);
      expect(rt.coreProblem.pending, isFalse);
      expect(rt.expectedOutcome.pending, isFalse);
      expect(rt.title.value, title);
    });

    test('InstructionContractValidator does not BLOCK canonical fields', () {
      final input = advancedManualInput(status: DesignFieldStatus.undecided);
      final instruction = service.buildInstruction(
        planId: 'plan_manual_val',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_manual_val',
        version: 1,
        now: DateTime.utc(2026, 9, 15, 12),
      );
      final result = contractValidator.validate(
        input: input,
        instruction: instruction,
      );
      final blockedCanonical = result.issues.where(
        (i) =>
            i.level == ContractValidationLevel.blocked &&
            (i.field.contains('title') ||
                i.field.contains('coreProblem') ||
                i.field.contains('expectedOutcome')),
      );
      expect(blockedCanonical, isEmpty, reason: result.issues.toString());
    });

    test('commercial ebook attachment + studio preflight stay green', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        topic: title,
        customerProblem: coreProblem,
        targetCustomer: targetCustomer,
        desiredOutcome: expectedOutcome,
        displayTitle: title,
        workingTitle: title,
        titleSource: 'manual',
        manualOnlyMode: true,
        planningConfirmed: true,
        selectedConceptIds: const [],
        reasonsToPay: const [],
        uniqueValue: '',
        topicStatus: DesignFieldStatus.userConfirmed,
        problemStatus: DesignFieldStatus.userConfirmed,
        outcomeStatus: DesignFieldStatus.userConfirmed,
        customerStatus: DesignFieldStatus.userConfirmed,
        customAudience: targetCustomer,
        originalUserBriefConfirmed: true,
        userConfirmedAt: '2026-09-15T12:00:00Z',
      );
      final input = engine
          .toBusinessPlanInput(state)
          .copyWith(
            topic: title,
            customerProblem: coreProblem,
            targetCustomer: targetCustomer,
            desiredOutcome: expectedOutcome,
            artifactType: ArtifactType.ebook,
          );
      // advanced fieldStatuses stamp (UI path)
      final wizard = Map<String, dynamic>.from(input.wizardSelections ?? {});
      wizard['mode'] = 'advanced';
      wizard['fieldStatuses'] = {
        'topic': 'userConfirmed',
        'problem': 'userConfirmed',
        'outcome': 'userConfirmed',
        'customer': 'userConfirmed',
        'planningConfirmed': true,
      };
      final stamped = input.copyWith(wizardSelections: wizard);

      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: stamped,
        instructionId: 'wi_manual_commercial',
        projectId: 'plan_manual_commercial',
      );
      expect(attachment, isNotNull);
      expect(attachment!.brief.manualOnlyMode, isTrue);

      final instruction = service.buildInstruction(
        planId: 'plan_manual_commercial',
        input: stamped,
        analysis: service.analyze(stamped),
        instructionId: 'wi_manual_commercial',
        version: 1,
        now: DateTime.utc(2026, 9, 15, 12),
        commercialQuality: attachment,
      );

      expect(instruction.notes, contains('ebookProductionContractVersion=2'));
      expect(instruction.notes, contains('[ebook:v2]'));
      expect(instruction.contract!.projectDefinition.title.pending, isFalse);
      expect(
        instruction.contract!.projectDefinition.coreProblem.pending,
        isFalse,
      );
      expect(
        instruction.contract!.projectDefinition.expectedOutcome.pending,
        isFalse,
      );

      final pf = CommercialWorkInstructionPreflight.evaluate(
        instruction.toJson(),
      );
      expect(pf.ok, isTrue, reason: '${pf.code} ${pf.issues}');

      final spec = instruction.contract!.productionSpec;
      expect(spec.undecidedKeys, isEmpty, reason: '${spec.undecidedKeys}');
      expect(spec.spec['outputFormat'], containsAll(['pdf', 'epub']));
      expect(spec.spec['pageRange'], isNot(equals('undecided')));
      expect(spec.spec['difficulty'], isNotEmpty);
      expect(spec.spec['writingStyle'], isNotEmpty);
      expect(spec.spec['salesDirection'], isNotEmpty);

      final briefProd =
          attachment.brief.structuredUserInputs['productionSelections']
              as Map?;
      expect(briefProd, isNotNull);
      expect(briefProd!['format'], containsAll(['pdf', 'epub']));
      expect(briefProd['pages'], ['p50']);
      expect(briefProd['level'], ['beginner']);
      expect(attachment.ebookProfile.requiredFormats, containsAll(['pdf', 'epub']));
      expect(attachment.ebookProfile.targetLengthBasis, '50페이지 내외');

      final quality = WorkInstructionWorkshopPresentation.qualityHints(
        instruction,
      );
      final qty = quality.firstWhere((h) => h.area == '분량·제작 조건');
      expect(qty.status, '명확');
    });

    test('user production overrides are preserved (putIfAbsent)', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        topic: title,
        customerProblem: coreProblem,
        targetCustomer: targetCustomer,
        desiredOutcome: expectedOutcome,
        displayTitle: title,
        manualOnlyMode: true,
        planningConfirmed: true,
        productionSelections: {
          'pages': ['p100'],
          'tone': ['friendly'],
          'pricing': ['free'],
        },
        topicStatus: DesignFieldStatus.userConfirmed,
        problemStatus: DesignFieldStatus.userConfirmed,
        outcomeStatus: DesignFieldStatus.userConfirmed,
        customerStatus: DesignFieldStatus.userConfirmed,
        customAudience: targetCustomer,
        originalUserBriefConfirmed: true,
        reasonsToPay: const ['override test'],
        uniqueValue: 'override',
        userConfirmedAt: '2026-09-15T12:00:00Z',
      );
      final input = engine.toBusinessPlanInput(state).copyWith(
            topic: title,
            customerProblem: coreProblem,
            targetCustomer: targetCustomer,
            desiredOutcome: expectedOutcome,
            artifactType: ArtifactType.ebook,
            wizardSelections: {
              ...?engine.toBusinessPlanInput(state).wizardSelections,
              'mode': 'advanced',
              'customTexts': {
                'manualOnlyMode': 'true',
              },
            },
          );
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: input,
        instructionId: 'wi_override',
        projectId: 'plan_override',
      )!;
      final prod =
          attachment.brief.structuredUserInputs['productionSelections'] as Map;
      expect(prod['pages'], ['p100']);
      expect(prod['tone'], ['friendly']);
      expect(prod['pricing'], ['free']);
      // unset groups still defaulted
      expect(prod['format'], containsAll(['pdf', 'epub']));
      expect(prod['level'], ['beginner']);

      final instruction = service.buildInstruction(
        planId: 'plan_override',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_override',
        version: 1,
        commercialQuality: attachment,
      );
      expect(instruction.contract!.productionSpec.spec['pageRange'], '100페이지 내외');
      expect(
        instruction.contract!.productionSpec.spec['writingStyle'],
        '친절·쉬운 설명',
      );
      expect(instruction.contract!.productionSpec.undecidedKeys, isEmpty);
    });

    test(
      'AI 보완(quick) path still requires userConfirmed (no false promote)',
      () {
        // manualOnly 아님 + undecided → pending 유지 (회귀 방지)
        final state = ProjectDesignState(
          artifactType: ArtifactType.ebook,
          topic: title,
          customerProblem: coreProblem,
          targetCustomer: targetCustomer,
          desiredOutcome: expectedOutcome,
          manualOnlyMode: false,
          planningConfirmed: false,
          topicStatus: DesignFieldStatus.suggested,
          problemStatus: DesignFieldStatus.suggested,
          outcomeStatus: DesignFieldStatus.suggested,
          customerStatus: DesignFieldStatus.suggested,
          selectedAudiences: const ['age_40_60'],
          reasonsToPay: const ['실습'],
          uniqueValue: '체크리스트',
          originalUserBrief: '브리프',
          originalUserBriefConfirmed: true,
        );
        final input = engine.toBusinessPlanInput(state);
        expect('${input.wizardSelections?['mode']}', isNot(equals('advanced')));
        final instruction = service.buildInstruction(
          planId: 'plan_ai_regress',
          input: input,
          analysis: service.analyze(input),
          instructionId: 'wi_ai_regress',
          version: 1,
          now: DateTime.utc(2026, 9, 15, 12),
        );
        final def = instruction.contract!.projectDefinition;
        // AI 제안 상태면 pending이어야 함 (confirmPlanning 전)
        expect(def.title.pending, isTrue);
        expect(def.coreProblem.pending, isTrue);
        expect(def.expectedOutcome.pending, isTrue);
      },
    );
  });
}
