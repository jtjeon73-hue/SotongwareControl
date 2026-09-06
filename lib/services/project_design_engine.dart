/// Project Design Engine — 추천·분석 (로컬 규칙, 외부 AI 없음).
library;

import '../data/concept_catalog.dart';
import '../data/concept_commercial_catalog.dart';
import '../data/project_design_catalog.dart';
import '../models/business_planning.dart';
import '../models/concept_candidate.dart';
import '../models/project_design_state.dart';
import 'business_planning_service.dart';
import 'concept_recommendation_provider.dart';
import 'planning_sentence_composer.dart';

class DesignReviewInsight {
  const DesignReviewInsight({
    required this.title,
    required this.body,
    this.scoreLabel = '',
  });

  final String title;
  final String body;
  final String scoreLabel;
}

class DesignReviewReport {
  const DesignReviewReport({
    required this.insights,
    required this.verdictLabel,
    required this.nextActions,
    this.analysis,
  });

  final List<DesignReviewInsight> insights;
  final String verdictLabel;
  final List<String> nextActions;
  final PlanningAnalysisResult? analysis;
}

class ProjectDesignEngine {
  ProjectDesignEngine({
    BusinessPlanningService? planningService,
    PlanningSentenceComposer? composer,
    ConceptRecommendationProvider? conceptProvider,
  }) : _planning = planningService ?? BusinessPlanningService(),
       _composer = composer ?? const PlanningSentenceComposer(),
       _concepts =
           conceptProvider ?? const LocalConceptRecommendationProvider();

  final BusinessPlanningService _planning;
  final PlanningSentenceComposer _composer;
  final ConceptRecommendationProvider _concepts;

  LocalConceptRecommendationProvider get localConcepts {
    final p = _concepts;
    if (p is LocalConceptRecommendationProvider) return p;
    return const LocalConceptRecommendationProvider();
  }

  /// Legacy topic chips (kept for compatibility).
  List<DesignTopic> recommendTopics(ProjectDesignState state) {
    if (!state.hasArtifact) return const [];
    return ProjectDesignCatalog.topicsFor(
      audienceIds: [
        ...state.selectedAudiences,
        if (state.customAudience.trim().isNotEmpty) 'custom',
      ],
      artifactType: state.artifactType!,
    );
  }

  Future<List<ConceptCandidate>> recommendConcepts(
    ProjectDesignState state, {
    int limit = 50,
    String? category,
    String searchQuery = '',
  }) async {
    return recommendConceptsSync(
      state,
      limit: limit,
      category: category,
      searchQuery: searchQuery,
    );
  }

  List<ConceptCandidate> recommendConceptsSync(
    ProjectDesignState state, {
    int limit = 50,
    String? category,
    String searchQuery = '',
  }) {
    if (!state.hasArtifact) return const [];
    return localConcepts.rank(
      ConceptRecommendQuery(
        audienceIds: [
          ...state.selectedAudiences,
          if (state.customAudience.trim().isNotEmpty) 'custom',
        ],
        artifactType: state.artifactType!,
        contentSubtype: state.contentSubtype,
        limit: limit,
        category: category,
        searchQuery: searchQuery,
      ),
    );
  }

  List<ConceptCandidate> resolveSelectedConcepts(ProjectDesignState state) {
    final pool = [
      ...recommendConceptsSync(state, limit: 80),
      ...state.userAddedConcepts,
    ];
    final byId = {for (final c in pool) c.id: c};
    final selected = <ConceptCandidate>[];
    for (final id in state.selectedConceptIds) {
      final c = byId[id];
      if (c != null) {
        selected.add(c);
        continue;
      }
      // Draft/compat: deprecated or previously selected ids not in active pool.
      final restored = _candidateFromSeedId(
        id,
        artifactType: state.artifactType ?? '',
        audiences: state.selectedAudiences,
      );
      if (restored != null) selected.add(restored);
    }
    for (final c in state.userAddedConcepts) {
      if (state.selectedConceptIds.contains(c.id) &&
          !selected.any((e) => e.id == c.id)) {
        selected.add(c);
      }
    }
    return selected;
  }

  ConceptCandidate? _candidateFromSeedId(
    String candidateOrSeedId, {
    required String artifactType,
    required List<String> audiences,
  }) {
    final seedId = ConceptCommercialCatalog.seedIdFromCandidateId(
      candidateOrSeedId,
    );
    ConceptSeed? seed;
    for (final s in ConceptCatalog.seeds) {
      if (s.id == seedId) {
        seed = s;
        break;
      }
    }
    if (seed == null) return null;
    final artifact = artifactType.trim().isEmpty
        ? seed.variants.keys.first
        : artifactType;
    final variant = seed.variants[artifact] ?? seed.variants.values.first;
    final meta = ConceptCommercialCatalog.resolve(seed);
    return ConceptCandidate(
      id: candidateOrSeedId.contains('__')
          ? candidateOrSeedId
          : '${seed.id}__$artifact',
      title: variant.$1,
      shortDescription: meta.shortDescription.isNotEmpty
          ? meta.shortDescription
          : variant.$2,
      category: seed.category,
      targetCustomers: audiences,
      compatibleArtifacts: [artifact],
      compatibleSubtypes: seed.subtypes,
      aiRelevanceScore: 3,
      customerNeedScore: 3,
      businessPotentialScore: 3,
      differentiationScore: 3,
      practicalValueScore: 3,
      beginnerFitScore: 3,
      longevityScore: 3,
      totalScore: 3,
      tags: seed.tags,
      whyRecommended: meta.recommendationReason,
      sourceType: 'local_catalog',
      seedId: seed.id,
      customerProblem: meta.customerProblem,
      promisedOutcome: meta.promisedOutcome,
      reasonsToPay: meta.reasonsToPay,
      uniqueValue: meta.uniqueValue,
      recommendationReason: meta.recommendationReason,
      deprecated: seed.deprecated,
      replacementSeedId: seed.replacementSeedId,
      difficulty: meta.difficulty,
      catalogVersion: seed.catalogVersion,
      active: seed.active,
    );
  }

  String buildCombinedDirection(List<ConceptCandidate> selected) {
    if (selected.isEmpty) return '';
    if (selected.length == 1) {
      return '「${selected.first.title}」을(를) 핵심 축으로 프로젝트를 구성합니다.';
    }
    final titles = selected.take(5).map((c) => c.title).join(' · ');
    final cats = selected
        .map((c) => ConceptCategory.labelKo(c.category))
        .toSet();
    return '선택한 ${selected.length}개 컨셉($titles)을 하나의 프로젝트로 결합합니다. '
        '공통 축: ${cats.take(4).join(', ')}. '
        '1차 결과물에서 핵심 2개 컨셉을 깊게 다루고, 나머지는 후속 확장으로 분리하세요.';
  }

  /// Suggest sentences without promoting to user_confirmed.
  /// Never overwrites userEdited / userConfirmed fields.
  ProjectDesignState syncSentences(
    ProjectDesignState state, {
    bool forceSuggested = false,
  }) {
    final next = state.copy();
    final selected = resolveSelectedConcepts(next);
    final topicLabels = <String>[...selected.map((c) => c.title)];
    if (topicLabels.isEmpty) {
      topicLabels.addAll(
        ProjectDesignCatalog.topics
            .where((t) => next.selectedTopicIds.contains(t.id))
            .map((t) => t.label),
      );
    }

    final artifactLabel = ArtifactType.labelKo(
      ArtifactType.normalize(next.artifactType ?? ''),
    );

    // Audience labels — always refresh from selection (selection itself is user act)
    final audienceLabels = <String>[];
    for (final id in next.selectedAudiences) {
      final found = ProjectDesignCatalog.audiences
          .where((a) => a.id == id)
          .map((a) => a.label);
      audienceLabels.addAll(found);
      if (found.isEmpty && id.isNotEmpty) audienceLabels.add(id);
    }
    if (next.customAudience.trim().isNotEmpty) {
      audienceLabels.add(next.customAudience.trim());
    }
    final audienceText = audienceLabels.isEmpty
        ? _composer.composeAudience(next.toWizardState())
        : audienceLabels.join(', ');

    if (!next.customerStatus.isLocked || forceSuggested) {
      next.targetCustomer = audienceText;
      next.customerStatus = audienceLabels.isEmpty
          ? DesignFieldStatus.suggested
          : DesignFieldStatus.userSelected;
    }

    final suggestedTopic = topicLabels.isNotEmpty
        ? '${topicLabels.take(2).join(' · ')} $artifactLabel'
        : _composer.composeTopic(next.toWizardState());
    final suggestedProblem = topicLabels.isNotEmpty
        ? '${next.targetCustomer}가 ${topicLabels.take(3).join('·')} 관련 '
              '정보와 실행 방법을 찾기 어렵다.'
        : _composer.composeProblem(next.toWizardState());
    final suggestedOutcome = topicLabels.isNotEmpty
        ? '${topicLabels.take(2).join('·')}을(를) 실행 가능한 $artifactLabel로 '
              '제공해 즉시 적용하게 한다.'
        : _composer.composeOutcome(next.toWizardState());

    if (!next.topicStatus.isLocked || forceSuggested) {
      next.topic = suggestedTopic;
      next.topicStatus = DesignFieldStatus.suggested;
    }
    if (!next.problemStatus.isLocked || forceSuggested) {
      next.customerProblem = suggestedProblem;
      if (next.designMemo.trim().isNotEmpty &&
          !next.customerProblem.contains(next.designMemo.trim())) {
        next.customerProblem =
            '${next.customerProblem}\n[추가 메모] ${next.designMemo.trim()}';
      }
      next.problemStatus = DesignFieldStatus.suggested;
    }
    if (!next.outcomeStatus.isLocked || forceSuggested) {
      next.desiredOutcome = suggestedOutcome;
      next.outcomeStatus = DesignFieldStatus.suggested;
    }

    next.combinedDirection = buildCombinedDirection(selected);
    // Selecting concepts / regenerating suggestions clears final confirm.
    if (forceSuggested || !next.planningConfirmed) {
      next.planningConfirmed = false;
    }

    // Keep selectedTopicIds in sync with concept titles for legacy paths
    if (selected.isNotEmpty) {
      next.selectedTopicIds = selected.map((c) => c.id).toList();
    }

    return next;
  }

  ProjectDesignState confirmPlanning(ProjectDesignState state) {
    final next = state.copy();
    next.topicStatus = DesignFieldStatus.userConfirmed;
    next.problemStatus = DesignFieldStatus.userConfirmed;
    next.outcomeStatus = DesignFieldStatus.userConfirmed;
    next.customerStatus = DesignFieldStatus.userConfirmed;
    next.planningConfirmed = true;
    next.userConfirmedAt = DateTime.now().toUtc().toIso8601String();
    next.studioPipelinePhase = StudioPipelinePhase.contentConfirmed;
    next.commercialLocalValidated = false;
    if (next.displayTitle.trim().isEmpty) {
      next.displayTitle = next.topic.trim();
    }
    if (next.originalUserBrief.trim().isEmpty) {
      next.originalUserBrief = [
        if (next.topic.trim().isNotEmpty) next.topic.trim(),
        if (next.customerProblem.trim().isNotEmpty) next.customerProblem.trim(),
        if (next.desiredOutcome.trim().isNotEmpty) next.desiredOutcome.trim(),
        if (next.targetCustomer.trim().isNotEmpty)
          '대상: ${next.targetCustomer.trim()}',
        if (next.designMemo.trim().isNotEmpty) next.designMemo.trim(),
      ].join('\n');
    }
    next.originalUserBriefConfirmed = true;
    if (next.reasonsToPay.isEmpty) {
      final selected = resolveSelectedConcepts(next);
      if (selected.isNotEmpty && selected.first.reasonsToPay.isNotEmpty) {
        next.reasonsToPay = List<String>.from(selected.first.reasonsToPay);
      } else if (next.desiredOutcome.trim().isNotEmpty) {
        next.reasonsToPay = [
          '${next.desiredOutcome.trim()}을(를) 더 빠르고 확실하게 얻는 데 도움이 됩니다',
        ];
      }
    }
    if (next.uniqueValue.trim().isEmpty) {
      final selected = resolveSelectedConcepts(next);
      if (selected.isNotEmpty && selected.first.uniqueValue.trim().isNotEmpty) {
        next.uniqueValue = selected.first.uniqueValue.trim();
      } else if (next.desiredOutcome.trim().isNotEmpty) {
        next.uniqueValue = next.desiredOutcome.trim();
      }
    }
    if (next.manualOnlyMode) {
      next.titleSource = next.titleSource.isEmpty ? 'manual' : next.titleSource;
    }
    return next;
  }

  ProjectDesignState markFieldEdited(
    ProjectDesignState state, {
    required String field,
  }) {
    final next = state.copy();
    next.planningConfirmed = false;
    next.commercialLocalValidated = false;
    if (next.studioPipelinePhase != StudioPipelinePhase.drafting) {
      next.studioPipelinePhase = StudioPipelinePhase.drafting;
    }
    switch (field) {
      case 'topic':
        next.topicStatus = DesignFieldStatus.userEdited;
      case 'problem':
        next.problemStatus = DesignFieldStatus.userEdited;
      case 'outcome':
        next.outcomeStatus = DesignFieldStatus.userEdited;
      case 'customer':
        next.customerStatus = DesignFieldStatus.userEdited;
    }
    return next;
  }

  BusinessPlanInput toBusinessPlanInput(ProjectDesignState state) {
    final synced = syncSentences(state);
    final wizard = synced.toWizardState();
    final base = _composer.toBusinessPlanInput(wizard);
    final selected = resolveSelectedConcepts(synced);
    final prodNotes = <String>[];
    for (final group in ProjectDesignCatalog.productionGroupsFor(
      synced.artifactType ?? '',
      contentSubtype: synced.contentSubtype ?? '',
    )) {
      final selectedOpts = synced.productionSelections[group.id] ?? const [];
      if (selectedOpts.isEmpty) continue;
      final labels = group.options
          .where((o) => selectedOpts.contains(o.id))
          .map((o) => o.label)
          .join(', ');
      if (labels.isNotEmpty) {
        prodNotes.add('${group.title}: $labels');
      }
    }
    final conceptNotes = selected.isEmpty
        ? ''
        : '선택 컨셉:\n${selected.map((c) => '- ${c.title}').join('\n')}';
    final notes = [
      if (synced.designMemo.trim().isNotEmpty) synced.designMemo.trim(),
      if (conceptNotes.isNotEmpty) conceptNotes,
      if (synced.combinedDirection.trim().isNotEmpty)
        '결합 방향: ${synced.combinedDirection.trim()}',
      if (prodNotes.isNotEmpty) prodNotes.join('\n'),
      '필드상태: topic=${synced.topicStatus.name}, '
          'problem=${synced.problemStatus.name}, '
          'outcome=${synced.outcomeStatus.name}, '
          'customer=${synced.customerStatus.name}, '
          'confirmed=${synced.planningConfirmed}',
    ].join('\n\n');

    final wizardJson = synced.toWizardState().toJson();
    wizardJson['selectedConcepts'] = selected.map((e) => e.toJson()).toList();
    wizardJson['wizardSessionId'] = synced.wizardSessionId;
    if ((synced.siteSubtype ?? '').trim().isNotEmpty) {
      wizardJson['siteSubtype'] = synced.siteSubtype;
    }
    wizardJson['fieldStatuses'] = {
      'topic': synced.topicStatus.name,
      'problem': synced.problemStatus.name,
      'outcome': synced.outcomeStatus.name,
      'customer': synced.customerStatus.name,
      'planningConfirmed': synced.planningConfirmed,
    };

    return base.copyWith(
      topic: synced.topic,
      customerProblem: synced.customerProblem,
      targetCustomer: synced.targetCustomer,
      desiredOutcome: synced.desiredOutcome,
      notes: notes,
      artifactType: synced.artifactType ?? '',
      contentSubtype: synced.contentSubtype ?? '',
      wizardSelections: wizardJson,
    );
  }

  DesignReviewReport buildReview(ProjectDesignState state) {
    final input = toBusinessPlanInput(state);
    final analysis = _planning.analyze(input);
    final artifact = ArtifactType.labelKo(input.resolvedArtifactType);
    final selected = resolveSelectedConcepts(state);
    final topics = selected.map((c) => c.title).toList();

    final insights = <DesignReviewInsight>[
      DesignReviewInsight(
        title: '시장성',
        scoreLabel: analysis.averageScore > 0
            ? analysis.averageScore.toStringAsFixed(1)
            : '검토',
        body: topics.isEmpty
            ? '$artifact 기획의 수요를 대상 고객 기준으로 검증하세요.'
            : '${topics.take(3).join('·')}은(는) ${input.targetCustomer} 수요와 맞물립니다.',
      ),
      DesignReviewInsight(
        title: '경쟁력·차별성',
        body: state.designMemo.trim().isNotEmpty
            ? '추가 메모의 차별화 포인트를 작업지시 품질 기준에 반영합니다.'
            : selected.length > 1
            ? state.combinedDirection
            : '실행 체크리스트·지역/상황 맞춤 예시를 넣어 차별화하세요.',
      ),
      DesignReviewInsight(title: '수익성', body: _pricingHint(state)),
      DesignReviewInsight(title: '제작 난이도', body: _difficultyHint(state)),
      DesignReviewInsight(title: '추천 판매·홍보', body: _channelHint(state)),
      DesignReviewInsight(
        title: '예상 리스크',
        body: analysis.summary.isNotEmpty
            ? analysis.summary
            : '범위 과다·검증 부족·유통 채널 미정을 우선 점검하세요.',
      ),
      DesignReviewInsight(title: '필수 포함 요소', body: _mustInclude(state, topics)),
      DesignReviewInsight(
        title: '확정 상태',
        body: state.planningConfirmed
            ? '사용자가 최종 기획을 확정했습니다.'
            : '아직 최종 확정 전입니다. AI 추천 문장은 suggested/pending 상태입니다.',
      ),
    ];

    final next = analysis.recommendations
        .take(3)
        .map((r) => '${ArtifactType.labelKo(r.type)}: ${r.reason}')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return DesignReviewReport(
      insights: insights,
      verdictLabel: PlanningVerdict.labelKo(analysis.verdict),
      nextActions: next.isNotEmpty
          ? next
          : const ['세부 문장을 확인·확정한 뒤 작업지시서를 생성하세요.'],
      analysis: analysis,
    );
  }

  String _pricingHint(ProjectDesignState state) {
    final pricing = state.productionSelections['pricing'] ?? const [];
    if (pricing.contains('free')) {
      return '무료 배포 후 후속 유료 상품·상담으로 연결하는 구조를 권장합니다.';
    }
    if (pricing.contains('premium')) {
      return '프리미엄은 사례·템플릿·체크리스트 밀도를 높여 가치를 증명하세요.';
    }
    return '저가~중간가 실험 후 반응에 따라 가격을 조정하세요.';
  }

  String _difficultyHint(ProjectDesignState state) {
    final a = ArtifactType.normalize(state.artifactType ?? '');
    switch (a) {
      case ArtifactType.app:
        return '앱은 로그인·결제·Firebase 범위에 따라 난이도가 급변합니다. MVP 범위를 먼저 고정하세요.';
      case ArtifactType.contents:
        return '콘텐츠는 제작 주기와 채널 맞춤이 난이도의 핵심입니다.';
      case ArtifactType.site:
      case ArtifactType.promoSite:
        return '사이트는 SEO·호스팅·관리자 범위를 최소화한 1차 공개가 유리합니다.';
      default:
        return '전자책은 목차·사례·실행표를 고정하면 제작 난이도를 낮출 수 있습니다.';
    }
  }

  String _channelHint(ProjectDesignState state) {
    final a = ArtifactType.normalize(state.artifactType ?? '');
    switch (a) {
      case ArtifactType.app:
        return '스토어 등록 + 프로모 사이트 + 쇼츠 시연을 묶으세요.';
      case ArtifactType.contents:
        return '유튜브·쇼츠·음원 플랫폼 중 주 채널 1곳을 먼저 정하세요.';
      case ArtifactType.promoSite:
        return '랜딩 CTA → 문의/다운로드 → 후속 상품 연결을 설계하세요.';
      case ArtifactType.site:
        return '검색 유입(SEO) + 뉴스레터/커뮤니티 공유를 병행하세요.';
      default:
        return '스마트스토어·크몽·자사 랜딩 중 1곳으로 판매 실험을 시작하세요.';
    }
  }

  String _mustInclude(ProjectDesignState state, List<String> topics) {
    final parts = <String>[
      '대상 고객 명시',
      '핵심 문제 1문장',
      '기대 결과 1문장',
      if (topics.isNotEmpty) '선택 컨셉: ${topics.take(4).join(', ')}',
      if (state.designMemo.trim().isNotEmpty) '추가 메모 반영',
      if (!state.planningConfirmed) '최종 기획 확정 필요',
    ];
    final prod = state.productionSelections;
    if (prod.isNotEmpty) {
      parts.add('제작 옵션 ${prod.length}개 그룹');
    }
    return parts.join(' · ');
  }

  int catalogSeedCount() => ConceptCatalog.seeds.length;
}
