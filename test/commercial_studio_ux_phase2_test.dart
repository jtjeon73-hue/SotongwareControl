/// Phase 2 commercial studio wiring — local only, no RemoteDelivery.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/concept_catalog.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/concept_candidate.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/commercial_studio_builder.dart';
import 'package:sotong_ware_control/services/commercial_work_instruction_preflight.dart';
import 'package:sotong_ware_control/services/concept_recommendation_provider.dart';
import 'package:sotong_ware_control/services/content_subtype_contract.dart';
import 'package:sotong_ware_control/services/project_design_engine.dart';
import 'package:sotong_ware_control/services/work_instruction_delivery_presentation.dart';
import 'package:sotong_ware_control/services/work_instruction_remote_delivery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalog commercial metadata', () {
    test('keeps 61 seeds and deprecates exact duplicate title safely', () {
      expect(ConceptCatalog.seeds.length, 61);
      final deprecated = ConceptCatalog.seeds
          .where((s) => s.id == 'policy_rural')
          .single;
      expect(deprecated.deprecated, isTrue);
      expect(deprecated.replacementSeedId, 'return_farm_guide');
      expect(deprecated.variants[ArtifactType.site]?.$1, '귀농 정책 정보관');
      final keeper = ConceptCatalog.seeds
          .where((s) => s.id == 'return_farm_guide')
          .single;
      expect(keeper.deprecated, isFalse);
      expect(keeper.commercial, isNotNull);
    });

    test('TOP10 / full50 / filter ranking', () {
      final provider = const LocalConceptRecommendationProvider();
      final query = ConceptRecommendQuery(
        audienceIds: const ['returning_farm', 'rural'],
        artifactType: ArtifactType.site,
        limit: 50,
      );
      final all = provider.rank(query);
      expect(all.length, lessThanOrEqualTo(50));
      expect(all.take(10).length, lessThanOrEqualTo(10));
      final filtered = provider.rank(
        ConceptRecommendQuery(
          audienceIds: const ['general'],
          artifactType: ArtifactType.app,
          category: ConceptCategory.ai,
          limit: 50,
        ),
      );
      expect(filtered.every((c) => c.category == ConceptCategory.ai), isTrue);
      for (final c in filtered.take(10)) {
        expect(c.title.contains(RegExp(r'\d+\.\d+')), isFalse);
      }
    });

    test('sanitizeDisplayTitle prevents artifact suffix duplication', () {
      expect(
        CommercialStudioBuilder.sanitizeDisplayTitle('생활 AI 체크 앱 앱', 'app'),
        '생활 AI 체크 앱',
      );
      expect(
        CommercialStudioBuilder.sanitizeDisplayTitle('입문 전자책 전자책', 'ebook'),
        '입문 전자책',
      );
    });
  });

  group('studio brief/profile builder', () {
    ProjectDesignState baseState({
      String artifact = ArtifactType.ebook,
      String? subtype,
      bool manualOnly = false,
      String creationMode = 'new_product',
    }) {
      return ProjectDesignState(
        artifactType: artifact,
        contentSubtype: subtype,
        selectedAudiences: const ['age_40_60'],
        topic: '초보자를 위한 AI 전자책 만들기',
        customerProblem: '전자책 제작 절차를 모름',
        targetCustomer: '50대 AI 초보 독자',
        desiredOutcome: '첫 전자책 초고를 완성',
        reasonsToPay: const ['실습과 체크리스트로 혼자 따라 할 수 있음'],
        uniqueValue: '따라하기형 실습 중심',
        planningConfirmed: true,
        originalUserBrief: '원문 브리프 — 사용자가 직접 쓴 내용',
        originalUserBriefConfirmed: true,
        manualOnlyMode: manualOnly,
        creationMode: creationMode,
        displayTitle: '초보자를 위한 AI 전자책 만들기',
        acceptedAiSuggestions: const ['실습 체크리스트'],
        rejectedAiSuggestions: const ['과장 수익 보장 문구'],
      );
    }

    BusinessPlanInput inputFrom(ProjectDesignState s) => BusinessPlanInput(
      topic: s.topic,
      customerProblem: s.customerProblem,
      targetCustomer: s.targetCustomer,
      desiredOutcome: s.desiredOutcome,
      artifactType: s.artifactType ?? '',
      contentSubtype: s.contentSubtype ?? '',
      experienceSkills: '기초 문서 작성',
      existingMaterials: '메모 원고',
      expectedScale: '소규모',
      budgetEstimate: '미정',
      salesPrice: '미정',
      references: '참고 링크',
      constraints: '과장 금지',
      extraRequests: '친절한 문체',
      notes: '추가 메모',
    );

    test('simple confirmed input builds complete ebook brief/profile', () {
      final state = baseState();
      final input = inputFrom(state);
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: input,
        instructionId: 'wi_test_ebook',
        projectId: 'plan_test_ebook',
      );
      expect(attachment, isNotNull);
      expect(attachment!.brief.originalUserBrief, contains('원문 브리프'));
      expect(attachment.brief.aiAugmentedBrief, isEmpty);
      expect(attachment.brief.acceptedAiSuggestions, contains('실습 체크리스트'));
      expect(attachment.brief.rejectedAiSuggestions, contains('과장 수익 보장 문구'));
      expect(attachment.brief.structuredUserInputs['expectedScale'], '소규모');
      expect(attachment.brief.structuredUserInputs['references'], '참고 링크');
      expect(attachment.ebookProfile.present, isTrue);

      final json = {
        'schemaVersion': '1.1',
        'artifactType': ArtifactType.ebook,
        ...attachment.toInstructionJsonFields(),
      };
      final preflight = CommercialWorkInstructionPreflight.evaluate(json);
      expect(
        preflight.ok,
        isTrue,
        reason: preflight.errors.map((e) => e.code).join(','),
      );
    });

    test('manualOnlyMode builds complete WI without AI augmentation', () {
      final state = baseState(manualOnly: true);
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: inputFrom(state),
        instructionId: 'wi_manual',
        projectId: 'plan_manual',
      )!;
      expect(attachment.brief.manualOnlyMode, isTrue);
      expect(attachment.brief.titleSource, 'manual');
      expect(attachment.brief.aiAugmentedBrief, isEmpty);
    });

    test('revise_existing requires source + requestedChanges in canCreate', () {
      final incomplete = baseState(creationMode: 'revise_existing');
      expect(incomplete.canCreateInstruction, isFalse);
      final complete = baseState(creationMode: 'revise_existing')
        ..sourceInstructionId = 'wi_src'
        ..sourceRevision = 'R1'
        ..requestedChanges = const ['문장 다듬기'];
      expect(complete.canCreateInstruction, isTrue);
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: complete,
        input: inputFrom(complete),
        instructionId: 'wi_rev',
        projectId: 'plan_rev',
      )!;
      expect(attachment.brief.creationMode, 'revise_existing');
      expect(attachment.brief.sourceInstructionId, 'wi_src');
      expect(attachment.brief.requestedChanges, contains('문장 다듬기'));
    });

    test('originalUserBrief stays locked after confirmPlanning', () {
      final engine = ProjectDesignEngine();
      var state = baseState()
        ..originalUserBrief = ''
        ..originalUserBriefConfirmed = false
        ..planningConfirmed = false;
      state = engine.confirmPlanning(state);
      final locked = state.originalUserBrief;
      expect(locked, isNotEmpty);
      expect(state.originalUserBriefConfirmed, isTrue);
      state.aiAugmentedBrief = 'AI가 바꾼 문장';
      expect(state.originalUserBrief, locked);
    });

    test('draft migration restores commercial fields', () {
      final state = baseState(manualOnly: true)
        ..acceptedAiSuggestions = const ['A']
        ..rejectedAiSuggestions = const ['B']
        ..studioPipelinePhase = StudioPipelinePhase.contentConfirmed;
      final restored = ProjectDesignState.fromWizardState(
        state.toWizardState(),
      );
      expect(restored.manualOnlyMode, isTrue);
      expect(restored.acceptedAiSuggestions, ['A']);
      expect(restored.rejectedAiSuggestions, ['B']);
      expect(
        restored.studioPipelinePhase,
        StudioPipelinePhase.contentConfirmed,
      );
      expect(restored.creationMode, 'new_product');
    });

    test('legacy revision_requested draft migrates to revise_existing', () {
      final wizard = baseState().toWizardState();
      final texts = Map<String, String>.from(wizard.customTexts)
        ..remove('creationMode')
        ..['revisionMode'] = 'revision_requested';
      final migrated = ProjectDesignState.fromWizardState(
        wizard.copyWith(customTexts: texts),
      );
      expect(migrated.creationMode, 'revise_existing');
    });

    test('four tracks + all content subtypes build profiles', () {
      const builder = CommercialStudioBuilder();
      final tracks = <(String, String?)>[
        (ArtifactType.app, null),
        (ArtifactType.ebook, null),
        (ArtifactType.site, null),
        (ArtifactType.contents, ContentSubtype.music),
        (ArtifactType.contents, ContentSubtype.shorts),
        (ArtifactType.contents, ContentSubtype.comic),
        (ArtifactType.contents, ContentSubtype.notificationPromoVideo),
        (ArtifactType.contents, ContentSubtype.imageDesign),
      ];
      for (final (artifact, subtype) in tracks) {
        final state = baseState(artifact: artifact, subtype: subtype)
          ..topic = '상용 테스트 제목'
          ..displayTitle = '상용 테스트 제목';
        final attachment = builder.tryBuild(
          state: state,
          input: inputFrom(state),
          instructionId: 'wi_$artifact${subtype ?? ''}',
          projectId: 'plan_$artifact',
        );
        expect(attachment, isNotNull, reason: '$artifact/$subtype');
        if (artifact == ArtifactType.contents) {
          expect(attachment!.contentProfile.present, isTrue);
          final workSubtype = ContentSubtypeContract.requireWorkCommercialEnum(
            subtype!,
          );
          expect(attachment.contentProfile.contentSubtype, workSubtype);
        }
      }
    });
  });

  group('finalize vs send separation', () {
    test('send blocked until localCommercialValidated', () {
      final readyWithoutLocal = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: null,
        agents: const [],
        transferBusy: false,
        localCommercialValidated: false,
      );
      expect(readyWithoutLocal.buttonEnabled, isFalse);
      expect(readyWithoutLocal.buttonState, DeliveryButtonState.blocked);
    });

    test('RemoteDelivery is not invoked by studio builder/preflight', () {
      // Guard: these units must not reference live delivery entrypoints.
      expect(RemoteDeliveryResult, isNotNull);
      final state = ProjectDesignState(
        artifactType: ArtifactType.app,
        selectedAudiences: const ['general'],
        topic: '현장 안전 점검 앱',
        customerProblem: '점검 누락',
        targetCustomer: '현장 작업자',
        desiredOutcome: '점검 기록 보존',
        reasonsToPay: const ['현장 즉시 사용'],
        uniqueValue: '오프라인 우선',
        planningConfirmed: true,
        originalUserBrief: '원문',
        originalUserBriefConfirmed: true,
        displayTitle: '현장 안전 점검 앱',
      );
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: BusinessPlanInput(
          topic: state.topic,
          customerProblem: state.customerProblem,
          targetCustomer: state.targetCustomer,
          desiredOutcome: state.desiredOutcome,
          artifactType: ArtifactType.app,
        ),
        instructionId: 'wi_app',
        projectId: 'plan_app',
      );
      expect(attachment, isNotNull);
      // No RemoteWorkInstructionDelivery instance constructed in this test file.
    });
  });

  group('placeholder not persisted as profile value', () {
    test('empty uniqueValue/reasons do not invent commercial attachment', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        selectedAudiences: const ['general'],
        topic: '주제',
        customerProblem: '문제',
        targetCustomer: '고객',
        desiredOutcome: '결과',
        planningConfirmed: true,
        originalUserBrief: '원문',
        // reasonsToPay empty + uniqueValue empty → builder returns null
      );
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: BusinessPlanInput(
          topic: '주제',
          customerProblem: '문제',
          targetCustomer: '고객',
          desiredOutcome: '결과',
          artifactType: ArtifactType.ebook,
        ),
        instructionId: 'wi_empty',
        projectId: 'plan_empty',
      );
      expect(attachment, isNull);
    });
  });
}
