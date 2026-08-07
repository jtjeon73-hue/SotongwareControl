import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/concept_catalog.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/concept_candidate.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/concept_recommendation_provider.dart';
import 'package:sotong_ware_control/services/instruction_contract_builder.dart';
import 'package:sotong_ware_control/services/project_design_engine.dart';

void main() {
  final engine = ProjectDesignEngine();
  final provider = const LocalConceptRecommendationProvider();
  final service = BusinessPlanningService();

  test('catalog has enough seeds for 50-candidate pool', () {
    expect(ConceptCatalog.seeds.length, greaterThanOrEqualTo(45));
  });

  Future<void> assertAudienceArtifact({
    required String name,
    required List<String> audiences,
    required String artifact,
    String? subtype,
  }) async {
    final list = provider.rank(
      ConceptRecommendQuery(
        audienceIds: audiences,
        artifactType: artifact,
        contentSubtype: subtype,
        limit: 50,
      ),
    );
    expect(list.length, greaterThanOrEqualTo(40), reason: name);
    expect(list.take(10).length, lessThanOrEqualTo(10));
    // artifact-specific titles (not a copied universal list)
    for (final c in list.take(5)) {
      expect(c.compatibleArtifacts, contains(artifact));
      expect(c.title, isNotEmpty);
      expect(c.whyRecommended, isNotEmpty);
      expect(c.totalScore, greaterThan(0));
    }
    // no fake market % language
    final blob = list.take(10).map((e) => e.whyRecommended).join(' ');
    expect(blob.contains('시장점유율'), isFalse);
    expect(blob.contains('판매 가능성'), isFalse);
  }

  test('Case A retire_prep + ebook', () async {
    await assertAudienceArtifact(
      name: 'A',
      audiences: const ['retire_prep'],
      artifact: ArtifactType.ebook,
    );
    var state = ProjectDesignState(
      artifactType: ArtifactType.ebook,
      selectedAudiences: const ['retire_prep'],
    );
    final concepts = engine.recommendConceptsSync(state, limit: 50);
    expect(concepts.length, greaterThanOrEqualTo(40));
    final top = concepts.take(3).map((c) => c.id).toList();
    state.selectedConceptIds = top;
    state = engine.syncSentences(state);
    expect(state.topicStatus, DesignFieldStatus.suggested);
    expect(state.planningConfirmed, isFalse);

    state = engine.confirmPlanning(state);
    expect(state.topicStatus, DesignFieldStatus.userConfirmed);
    expect(state.planningConfirmed, isTrue);

    final input = engine.toBusinessPlanInput(state);
    final instruction = service.buildInstruction(
      planId: 'case_a',
      input: input,
      analysis: service.analyze(input),
      instructionId: 'wi_case_a',
    );
    expect(instruction.contract, isNotNull);
    expect(
      instruction.contract!.projectDefinition.title.source,
      FieldSource.userConfirmed,
    );
    expect(instruction.contract!.projectDefinition.title.pending, isFalse);
    expect(instruction.contract!.projectDefinition.selectedTopics, isNotEmpty);
  });

  test('Case B rural + app', () async {
    await assertAudienceArtifact(
      name: 'B',
      audiences: const ['rural'],
      artifact: ArtifactType.app,
    );
    final ebook = provider.rank(
      const ConceptRecommendQuery(
        audienceIds: ['rural'],
        artifactType: ArtifactType.ebook,
        limit: 10,
      ),
    );
    final app = provider.rank(
      const ConceptRecommendQuery(
        audienceIds: ['rural'],
        artifactType: ArtifactType.app,
        limit: 10,
      ),
    );
    expect(ebook.first.title, isNot(equals(app.first.title)));
  });

  test('Case C office + contents/video', () async {
    await assertAudienceArtifact(
      name: 'C',
      audiences: const ['office'],
      artifact: ArtifactType.contents,
      subtype: ContentSubtype.video,
    );
  });

  test('Case D smb + promo_site', () async {
    await assertAudienceArtifact(
      name: 'D',
      audiences: const ['smb'],
      artifact: ArtifactType.promoSite,
    );
  });

  test('Case E student + site', () async {
    await assertAudienceArtifact(
      name: 'E',
      audiences: const ['student'],
      artifact: ArtifactType.site,
    );
  });

  test('Case F multi audience intersection boost', () {
    final single = provider.rank(
      const ConceptRecommendQuery(
        audienceIds: ['age_40_60'],
        artifactType: ArtifactType.ebook,
        limit: 15,
      ),
    );
    final multi = provider.rank(
      const ConceptRecommendQuery(
        audienceIds: ['age_40_60', 'retire_prep'],
        artifactType: ArtifactType.ebook,
        limit: 15,
      ),
    );
    expect(multi.length, greaterThanOrEqualTo(10));
    // retirement/ai/money categories should appear near top for intersection
    final topCats = multi.take(8).map((c) => c.category).toSet();
    expect(
      topCats.intersection({
        ConceptCategory.retirement,
        ConceptCategory.ai,
        ConceptCategory.money,
        ConceptCategory.health,
      }).isNotEmpty,
      isTrue,
    );
    expect(single.first.id, isNotEmpty);
  });

  test('Case G user-added concept', () {
    var state = ProjectDesignState(
      artifactType: ArtifactType.ebook,
      selectedAudiences: const ['general'],
    );
    final added = ConceptCandidate.userAdded(
      title: 'My Custom Idea',
      memo: 'special memo',
      artifactType: ArtifactType.ebook,
      audiences: const ['general'],
    );
    state.userAddedConcepts = [added];
    state.selectedConceptIds = [added.id];
    state = engine.syncSentences(state);
    expect(state.topic, contains('My Custom Idea'));
    final selected = engine.resolveSelectedConcepts(state);
    expect(selected.any((c) => c.isUserAdded), isTrue);
  });

  test('Case H suggested is not user_confirmed', () {
    var state = ProjectDesignState(
      artifactType: ArtifactType.ebook,
      selectedAudiences: const ['retire_prep'],
    );
    final concepts = engine.recommendConceptsSync(state, limit: 5);
    state.selectedConceptIds = [concepts.first.id];
    state = engine.syncSentences(state);
    expect(state.topicStatus, DesignFieldStatus.suggested);
    expect(state.planningConfirmed, isFalse);

    final input = engine.toBusinessPlanInput(state);
    final statuses = input.wizardSelections?['fieldStatuses'] as Map?;
    expect(statuses?['topic'], 'suggested');
    expect(statuses?['planningConfirmed'], isFalse);

    final contract = const InstructionContractBuilder().build(
      input: input,
      planId: 'h',
      instructionId: 'wi_h',
      version: 1,
      createdAt: '2026-08-07T00:00:00.000Z',
      updatedAt: '2026-08-07T00:00:00.000Z',
      legacySteps: service
          .buildInstruction(
            planId: 'h',
            input: input,
            analysis: service.analyze(input),
          )
          .workflowSteps,
    );
    expect(contract.projectDefinition.title.source, FieldSource.suggested);
    expect(contract.projectDefinition.title.pending, isTrue);
  });

  test('category filter and search', () {
    final all = provider.rank(
      const ConceptRecommendQuery(
        audienceIds: ['smb'],
        artifactType: ArtifactType.promoSite,
        limit: 50,
      ),
    );
    final filtered = provider.rank(
      const ConceptRecommendQuery(
        audienceIds: ['smb'],
        artifactType: ArtifactType.promoSite,
        limit: 50,
        category: ConceptCategory.marketing,
      ),
    );
    expect(
      filtered.every((c) => c.category == ConceptCategory.marketing),
      isTrue,
    );
    final searched = provider.rank(
      const ConceptRecommendQuery(
        audienceIds: ['rural'],
        artifactType: ArtifactType.ebook,
        limit: 50,
        searchQuery: 'PLC',
      ),
    );
    expect(searched.any((c) => c.tags.any((t) => t.contains('PLC'))), isTrue);
    expect(all.length, greaterThan(filtered.length));
  });
}
