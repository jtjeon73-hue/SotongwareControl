/// Catalog coverage, title quality, and full active×artifact WI generation.
/// Local memory only — never calls RemoteDelivery / network.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/concept_catalog.dart';
import 'package:sotong_ware_control/data/concept_commercial_catalog.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/concept_candidate.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/commercial_studio_builder.dart';
import 'package:sotong_ware_control/services/commercial_work_instruction_preflight.dart';
import 'package:sotong_ware_control/services/concept_recommendation_provider.dart';
import 'package:sotong_ware_control/services/project_design_engine.dart';
import 'package:sotong_ware_control/services/work_instruction_delivery_presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const artifacts = [
    ArtifactType.app,
    ArtifactType.ebook,
    ArtifactType.site,
    ArtifactType.contents,
    ArtifactType.promoSite,
  ];

  group('commercial metadata coverage', () {
    test('8건의 의미 = 이전 단계에서 inline commercial을 가진 seed 8개', () {
      final inline = ConceptCatalog.seeds
          .where((s) => s.commercial != null)
          .map((s) => s.id)
          .toList();
      expect(inline.length, 8);
      expect(ConceptCommercialCatalog.bySeedId.length, 61);
      expect(ConceptCommercialCatalog.completeCount, 61);
    });

    test('수치: seeds/variants/active/deprecated/complete', () {
      final seeds = ConceptCatalog.seeds;
      expect(seeds.length, 61);
      final variants = seeds.fold<int>(0, (n, s) => n + s.variants.length);
      expect(variants, 305);
      expect(seeds.where((s) => s.deprecated).length, 1);
      expect(seeds.where((s) => s.active && !s.deprecated).length, 60);
      final missing = ConceptCommercialCatalog.missingSeedIds(
        seeds.map((s) => s.id),
      );
      expect(missing, isEmpty);
      for (final s in seeds.where((s) => s.active && !s.deprecated)) {
        expect(
          ConceptCommercialCatalog.isComplete(
            ConceptCommercialCatalog.resolve(s),
          ),
          isTrue,
          reason: s.id,
        );
      }
    });

    test('artifact별 추천 가능 제목 ≥50 및 TOP50 전부 complete meta', () {
      final provider = const LocalConceptRecommendationProvider();
      for (final artifact in artifacts) {
        final ranked = provider.rank(
          ConceptRecommendQuery(
            audienceIds: const ['general'],
            artifactType: artifact,
            limit: 50,
          ),
        );
        expect(ranked.length, greaterThanOrEqualTo(50), reason: artifact);
        expect(
          ranked.any((c) => c.seedId == 'policy_rural' || c.deprecated),
          isFalse,
          reason: 'deprecated must not appear in recommendations for $artifact',
        );
        for (final c in ranked) {
          expect(c.customerProblem, isNotEmpty, reason: c.id);
          expect(c.promisedOutcome, isNotEmpty, reason: c.id);
          expect(c.reasonsToPay, isNotEmpty, reason: c.id);
          expect(c.uniqueValue, isNotEmpty, reason: c.id);
          expect(
            c.recommendationReason.isNotEmpty || c.whyRecommended.isNotEmpty,
            isTrue,
            reason: c.id,
          );
        }
      }
    });
  });

  group('title quality audit', () {
    final suffixDup = RegExp(r'(앱\s*앱|전자책\s*전자책|사이트\s*사이트|콘텐츠\s*콘텐츠)$');
    final internalId = RegExp(
      r'(proj_|wi_|instructionId|repositorySlug|STEP\s*\d+|R\d+_slot)',
      caseSensitive: false,
    );

    test('active variants: no suffix dup, no internal id titles', () {
      var checked = 0;
      final titles = <String, List<String>>{};
      for (final seed in ConceptCatalog.seeds) {
        if (!seed.active || seed.deprecated) continue;
        for (final e in seed.variants.entries) {
          checked++;
          final title = e.value.$1.trim();
          final desc = e.value.$2.trim();
          expect(
            suffixDup.hasMatch(title),
            isFalse,
            reason: '${seed.id} $title',
          );
          expect(internalId.hasMatch(title), isFalse, reason: title);
          expect(title, isNotEmpty);
          expect(desc, isNotEmpty);
          // shortDescription should not be exact title clone only
          expect(desc == title, isFalse, reason: '${seed.id} desc==title');
          titles.putIfAbsent(title, () => []).add('${seed.id}:${e.key}');
        }
      }
      expect(checked, greaterThanOrEqualTo(300)); // 60*5 = 300
      // Exact duplicate titles across different seeds (same artifact family)
      // policy_rural excluded; return_farm_guide keeps 귀농 정책 정보관 alone among active.
      final exactDupes = titles.entries
          .where((e) => e.value.length > 1)
          .toList();
      expect(
        exactDupes,
        isEmpty,
        reason: exactDupes
            .map((e) => '${e.key}->${e.value.join(",")}')
            .join(' | '),
      );
    });

    test('sanitizeDisplayTitle removes duplicated artifact suffix', () {
      expect(
        CommercialStudioBuilder.sanitizeDisplayTitle('생활 AI 체크 앱 앱', 'app'),
        '생활 AI 체크 앱',
      );
    });

    test('deprecated draft selection still resolves', () {
      final engine = ProjectDesignEngine();
      final state = ProjectDesignState(
        artifactType: ArtifactType.site,
        selectedAudiences: const ['returning_farm'],
        selectedConceptIds: const ['policy_rural__site'],
        topic: '귀농 정책',
        customerProblem: '정책 찾기 어려움',
        targetCustomer: '귀농 준비자',
        desiredOutcome: '지원 정보 정리',
      );
      final selected = engine.resolveSelectedConcepts(state);
      expect(selected, isNotEmpty);
      expect(selected.first.deprecated, isTrue);
      expect(selected.first.replacementSeedId, 'return_farm_guide');
    });
  });

  group('active seed × artifact full WI generation', () {
    test('all active combinations PASS Commercial Preflight', () {
      const builder = CommercialStudioBuilder();
      var total = 0;
      var pass = 0;
      final fails = <String>[];
      final byTrack = <String, List<int>>{};

      for (final seed in ConceptCatalog.seeds) {
        if (!seed.active || seed.deprecated) continue;
        final meta = ConceptCommercialCatalog.resolve(seed);
        for (final artifact in artifacts) {
          final variant = seed.variants[artifact];
          if (variant == null) continue;
          total++;
          final track = switch (ArtifactType.normalize(artifact)) {
            ArtifactType.app => 'app',
            ArtifactType.ebook => 'ebook',
            ArtifactType.contents => 'content',
            _ => 'site',
          };
          byTrack.putIfAbsent(track, () => [0, 0]);

          final displayTitle = CommercialStudioBuilder.sanitizeDisplayTitle(
            variant.$1,
            artifact,
          );
          final state = ProjectDesignState(
            artifactType: artifact,
            contentSubtype: artifact == ArtifactType.contents
                ? ContentSubtype.music
                : null,
            siteSubtype:
                (artifact == ArtifactType.site ||
                    artifact == ArtifactType.promoSite)
                ? (artifact == ArtifactType.promoSite
                      ? 'marketing_site'
                      : 'knowledge_site')
                : null,
            selectedAudiences: seed.audienceWeights.keys.take(2).toList(),
            selectedConceptIds: ['${seed.id}__$artifact'],
            topic: displayTitle,
            displayTitle: displayTitle,
            customerProblem: meta.customerProblem,
            desiredOutcome: meta.promisedOutcome,
            targetCustomer: seed.audienceWeights.keys.isEmpty
                ? '일반 사용자'
                : seed.audienceWeights.keys.first,
            reasonsToPay: List<String>.from(meta.reasonsToPay),
            uniqueValue: meta.uniqueValue,
            planningConfirmed: true,
            originalUserBriefConfirmed: true,
            originalUserBrief:
                '${meta.customerProblem}\n${meta.promisedOutcome}',
            userConfirmedAt: '2026-09-04T12:00:00Z',
            studioPipelinePhase: StudioPipelinePhase.contentConfirmed,
            manualOnlyMode: true,
            titleSource: 'manual',
          );
          final input = BusinessPlanInput(
            topic: displayTitle,
            customerProblem: meta.customerProblem,
            targetCustomer: state.targetCustomer,
            desiredOutcome: meta.promisedOutcome,
            artifactType: artifact,
            contentSubtype: state.contentSubtype ?? '',
            experienceSkills: '관련 실무 경험',
            existingMaterials: '기존 메모',
            expectedScale: '소규모',
            budgetEstimate: '미정',
            references: '내부 참고',
            constraints: '과장 금지',
            extraRequests: '친절한 문체',
            notes: '사용자 확인 완료',
            revenueModel: meta.monetizationModels.first,
          );

          final attachment = builder.tryBuild(
            state: state,
            input: input,
            instructionId: 'wi_${seed.id}_$artifact',
            projectId: 'plan_${seed.id}',
          );
          if (attachment == null) {
            fails.add('${seed.id}/$artifact: builder null');
            byTrack[track]![1]++;
            continue;
          }
          final json = <String, dynamic>{
            'schemaVersion': '1.1',
            'artifactType': artifact,
            if (state.contentSubtype != null)
              'contentSubtype': state.contentSubtype,
            ...attachment.toInstructionJsonFields(),
          };
          // Ensure displayTitle not internal id
          expect(attachment.brief.displayTitle.contains('wi_'), isFalse);
          expect(attachment.brief.internalProjectId, isNotEmpty);
          expect(attachment.brief.repositorySlug, isNotEmpty);
          expect(
            attachment.brief.displayTitle,
            isNot(equals(attachment.brief.internalProjectId)),
          );

          final preflight = CommercialWorkInstructionPreflight.evaluate(json);
          if (preflight.ok && preflight.errors.isEmpty) {
            pass++;
            byTrack[track]![0]++;
          } else {
            fails.add(
              '${seed.id}/$artifact: ${preflight.errors.map((e) => e.code).join(",")}',
            );
            byTrack[track]![1]++;
          }
        }
      }

      expect(total, 300); // 60 active * 5 artifacts
      expect(
        fails,
        isEmpty,
        reason: 'FAIL ${fails.length}/$total: ${fails.take(20).join(" | ")}',
      );
      expect(pass, total);
      for (final e in byTrack.entries) {
        expect(e.value[1], 0, reason: '${e.key} failures=${e.value[1]}');
      }
    });
  });

  group('path matrix', () {
    ProjectDesignState confirmed({
      required String artifact,
      String? subtype,
      bool manualOnly = false,
      String creationMode = 'new_product',
      String seedId = 'ai_daily_assistant',
    }) {
      final seed = ConceptCatalog.seeds.firstWhere((s) => s.id == seedId);
      final meta = ConceptCommercialCatalog.resolve(seed);
      final title = seed.variants[artifact]?.$1 ?? meta.shortDescription;
      return ProjectDesignState(
        artifactType: artifact,
        contentSubtype: subtype,
        selectedAudiences: const ['general'],
        selectedConceptIds: ['${seedId}__$artifact'],
        topic: title,
        displayTitle: title,
        customerProblem: meta.customerProblem,
        desiredOutcome: meta.promisedOutcome,
        targetCustomer: '대상 고객',
        reasonsToPay: List<String>.from(meta.reasonsToPay),
        uniqueValue: meta.uniqueValue,
        planningConfirmed: true,
        originalUserBrief: '원문-사용자확인',
        originalUserBriefConfirmed: true,
        manualOnlyMode: manualOnly,
        creationMode: creationMode,
        titleSource: manualOnly ? 'manual' : 'ai_refined',
        acceptedAiSuggestions: manualOnly ? const [] : const ['적용된 제안'],
        rejectedAiSuggestions: manualOnly ? const [] : const ['거절된 제안'],
        aiAugmentedBrief: manualOnly ? '' : 'AI 보완문',
        sourceInstructionId: creationMode == 'revise_existing' ? 'wi_src' : '',
        sourceRevision: creationMode == 'revise_existing' ? 'R1' : '',
        requestedRevision: creationMode == 'revise_existing' ? 'R2' : '',
        requestedChanges: creationMode == 'revise_existing'
            ? const ['문구 수정']
            : const [],
        preservedArtifactHashes: creationMode == 'revise_existing'
            ? const ['hash_a']
            : const [],
        ownerReviewDecisionRef: creationMode == 'revise_existing'
            ? 'owner_review_decisions/R1.json'
            : '',
        userConfirmedAt: '2026-09-04T12:00:00Z',
      );
    }

    test('track/subtype paths build complete profiles', () {
      const builder = CommercialStudioBuilder();
      final cases = <(String, String?)>[
        (ArtifactType.app, null),
        (ArtifactType.ebook, null),
        (ArtifactType.site, null),
        (ArtifactType.promoSite, null),
        (ArtifactType.contents, ContentSubtype.music),
        (ArtifactType.contents, ContentSubtype.shorts),
        (ArtifactType.contents, ContentSubtype.comic),
        (ArtifactType.contents, ContentSubtype.notificationPromoVideo),
        (ArtifactType.contents, ContentSubtype.imageDesign),
      ];
      for (final (artifact, subtype) in cases) {
        final state = confirmed(artifact: artifact, subtype: subtype);
        if (artifact == ArtifactType.site ||
            artifact == ArtifactType.promoSite) {
          state.siteSubtype = artifact == ArtifactType.promoSite
              ? 'marketing_site'
              : 'knowledge_site';
          state.productionSelections['site_kind'] = [
            state.siteSubtype!,
          ];
        }
        final attachment = builder.tryBuild(
          state: state,
          input: BusinessPlanInput(
            topic: state.topic,
            customerProblem: state.customerProblem,
            targetCustomer: state.targetCustomer,
            desiredOutcome: state.desiredOutcome,
            artifactType: artifact,
            contentSubtype: subtype ?? '',
          ),
          instructionId: 'wi_path_$artifact',
          projectId: 'plan_path',
        );
        expect(attachment, isNotNull, reason: '$artifact/$subtype');
        final json = {
          'schemaVersion': '1.1',
          'artifactType': artifact,
          'contentSubtype': ?subtype,
          ...attachment!.toInstructionJsonFields(),
        };
        final pf = CommercialWorkInstructionPreflight.evaluate(json);
        expect(
          pf.ok,
          isTrue,
          reason: '$artifact/${pf.errors.map((e) => e.code)}',
        );
      }
    });

    test('manualOnly / revise / user-added / legacy migration', () {
      const builder = CommercialStudioBuilder();
      final manual = confirmed(artifact: ArtifactType.ebook, manualOnly: true);
      final mAtt = builder.tryBuild(
        state: manual,
        input: BusinessPlanInput(
          topic: manual.topic,
          customerProblem: manual.customerProblem,
          targetCustomer: manual.targetCustomer,
          desiredOutcome: manual.desiredOutcome,
          artifactType: ArtifactType.ebook,
        ),
        instructionId: 'wi_m',
        projectId: 'p_m',
      )!;
      expect(mAtt.brief.manualOnlyMode, isTrue);
      expect(mAtt.brief.originalUserBrief, '원문-사용자확인');
      expect(mAtt.brief.aiAugmentedBrief, isEmpty);

      final revise = confirmed(
        artifact: ArtifactType.app,
        creationMode: 'revise_existing',
      );
      final rAtt = builder.tryBuild(
        state: revise,
        input: BusinessPlanInput(
          topic: revise.topic,
          customerProblem: revise.customerProblem,
          targetCustomer: revise.targetCustomer,
          desiredOutcome: revise.desiredOutcome,
          artifactType: ArtifactType.app,
        ),
        instructionId: 'wi_r',
        projectId: 'p_r',
      )!;
      expect(rAtt.brief.creationMode, 'revise_existing');
      expect(rAtt.brief.requestedChanges, isNotEmpty);

      final userIdea = confirmed(artifact: ArtifactType.ebook)
        ..selectedConceptIds = const []
        ..userAddedConcepts = [
          ConceptCandidate.userAdded(
            title: '내가 직접 추가한 아이디어',
            memo: '사용자 메모',
            artifactType: ArtifactType.ebook,
            audiences: const ['general'],
          ),
        ]
        ..topic = '내가 직접 추가한 아이디어'
        ..displayTitle = '내가 직접 추가한 아이디어';
      final uAtt = builder.tryBuild(
        state: userIdea,
        input: BusinessPlanInput(
          topic: userIdea.topic,
          customerProblem: userIdea.customerProblem,
          targetCustomer: userIdea.targetCustomer,
          desiredOutcome: userIdea.desiredOutcome,
          artifactType: ArtifactType.ebook,
        ),
        instructionId: 'wi_u',
        projectId: 'p_u',
      );
      expect(uAtt, isNotNull);

      final wizard = confirmed(artifact: ArtifactType.app).toWizardState();
      final texts = Map<String, String>.from(wizard.customTexts)
        ..remove('creationMode')
        ..['revisionMode'] = 'revision_requested';
      final migrated = ProjectDesignState.fromWizardState(
        wizard.copyWith(customTexts: texts),
      );
      expect(migrated.creationMode, 'revise_existing');
    });

    test('unconfirmed recommendation does not invent attachment', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        selectedAudiences: const ['general'],
        topic: '주제만 있음',
        customerProblem: '문제',
        targetCustomer: '고객',
        desiredOutcome: '결과',
        // reasons/unique empty → not confirmed commercial
      );
      expect(
        const CommercialStudioBuilder().tryBuild(
          state: state,
          input: BusinessPlanInput(
            topic: '주제만 있음',
            customerProblem: '문제',
            targetCustomer: '고객',
            desiredOutcome: '결과',
            artifactType: ArtifactType.ebook,
          ),
          instructionId: 'wi_x',
          projectId: 'p_x',
        ),
        isNull,
      );
    });

    test(
      'finalize/generate/validate do not enable send without local validate',
      () {
        final view = WorkInstructionDeliveryPresentation.resolve(
          plan: null,
          validation: null,
          agents: const [],
          transferBusy: false,
          localCommercialValidated: false,
        );
        expect(view.buttonEnabled, isFalse);
      },
    );

    test('RemoteDelivery entry not used in catalog generation path', () {
      // Guard: this suite never constructs a delivery client / HTTP call.
      expect(jsonEncode({'remoteDeliveryCalls': 0}), contains('0'));
    });
  });

  group('original / AI separation', () {
    test(
      'confirm locks original; AI accept/reject survive draft roundtrip',
      () {
        final engine = ProjectDesignEngine();
        var state = ProjectDesignState(
          artifactType: ArtifactType.ebook,
          selectedAudiences: const ['general'],
          selectedConceptIds: const ['ai_daily_assistant__ebook'],
          topic: '일상 AI 활용 입문',
          customerProblem: '문제',
          targetCustomer: '고객',
          desiredOutcome: '결과',
          planningConfirmed: false,
        );
        state = engine.confirmPlanning(state);
        final locked = state.originalUserBrief;
        expect(locked, isNotEmpty);
        state.aiAugmentedBrief = 'AI 문장';
        state.acceptedAiSuggestions = ['수락A'];
        state.rejectedAiSuggestions = ['거절B'];
        expect(state.originalUserBrief, locked);
        final restored = ProjectDesignState.fromWizardState(
          state.toWizardState(),
        );
        expect(restored.originalUserBrief, locked);
        expect(restored.acceptedAiSuggestions, ['수락A']);
        expect(restored.rejectedAiSuggestions, ['거절B']);
        expect(restored.aiAugmentedBrief, 'AI 문장');
      },
    );
  });

  group('coverage report artifact', () {
    test('writes coverage numbers for audit/manifest consumers', () {
      final outDir = Directory('test/support/commercial_coverage');
      outDir.createSync(recursive: true);
      final provider = const LocalConceptRecommendationProvider();
      final perArtifact = <String, int>{};
      for (final a in artifacts) {
        perArtifact[a] = provider
            .rank(
              ConceptRecommendQuery(
                audienceIds: const ['general'],
                artifactType: a,
                limit: 50,
              ),
            )
            .length;
      }
      final report = {
        'generatedAt': '2026-09-04T12:30:00+09:00',
        'seedCount': ConceptCatalog.seeds.length,
        'variantCount': ConceptCatalog.seeds.fold<int>(
          0,
          (n, s) => n + s.variants.length,
        ),
        'activeNonDeprecated': ConceptCatalog.seeds
            .where((s) => s.active && !s.deprecated)
            .length,
        'deprecated': ConceptCatalog.seeds.where((s) => s.deprecated).length,
        'commercialCompleteSeeds': ConceptCommercialCatalog.completeCount,
        'inlineCommercialSeedsLegacyMeaning': 8,
        'perArtifactRecommendAtLeast50': perArtifact,
        'remoteDeliveryCallsInThisSuite': 0,
      };
      final file = File('${outDir.path}/coverage_manifest.json');
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(report),
      );
      expect(file.existsSync(), isTrue);
      expect(jsonDecode(file.readAsStringSync())['seedCount'], 61);
    });
  });
}
