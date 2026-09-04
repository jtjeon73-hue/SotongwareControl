/// Concept recommendation provider interface + local engine.
library;

import '../data/concept_catalog.dart';
import '../data/concept_commercial_catalog.dart';
import '../data/project_design_catalog.dart';
import '../models/artifact_type.dart';
import '../models/concept_candidate.dart';

/// Abstraction for future LLM / trend providers.
abstract class ConceptRecommendationProvider {
  Future<List<ConceptCandidate>> recommend({
    required List<String> audienceIds,
    required String artifactType,
    String? contentSubtype,
    int limit = 50,
  });
}

class ConceptRecommendQuery {
  const ConceptRecommendQuery({
    required this.audienceIds,
    required this.artifactType,
    this.contentSubtype,
    this.limit = 50,
    this.category,
    this.searchQuery = '',
  });

  final List<String> audienceIds;
  final String artifactType;
  final String? contentSubtype;
  final int limit;
  final String? category;
  final String searchQuery;
}

/// Local catalog + rule scoring (no external API).
class LocalConceptRecommendationProvider
    implements ConceptRecommendationProvider {
  const LocalConceptRecommendationProvider();

  static const scoreDisclaimer =
      'Project Design Engine의 고객 적합도·AI 활용도·실용성 기반 내부 추천 평가';

  @override
  Future<List<ConceptCandidate>> recommend({
    required List<String> audienceIds,
    required String artifactType,
    String? contentSubtype,
    int limit = 50,
  }) async {
    return rank(
      ConceptRecommendQuery(
        audienceIds: audienceIds,
        artifactType: artifactType,
        contentSubtype: contentSubtype,
        limit: limit,
      ),
    );
  }

  List<ConceptCandidate> rank(ConceptRecommendQuery query) {
    final artifact = ArtifactType.normalize(query.artifactType);
    final subtype = (query.contentSubtype ?? '').trim().isEmpty
        ? null
        : ContentSubtype.normalize(query.contentSubtype!);
    final audiences = query.audienceIds
        .where((e) => e.trim().isNotEmpty && e != 'custom')
        .toList();
    final effectiveAudiences = audiences.isEmpty
        ? const ['general']
        : audiences;

    final intersectionBoost = _intersectionCategoryBoost(effectiveAudiences);
    final scored = <ConceptCandidate>[];

    for (final seed in ConceptCatalog.seeds) {
      if (!seed.active || seed.deprecated) continue;
      final variant = seed.variants[artifact];
      if (variant == null) continue;
      if (seed.subtypes.isNotEmpty &&
          subtype != null &&
          subtype != ContentSubtype.undecided &&
          !seed.subtypes.contains(subtype)) {
        // Soft filter: still allow but slight penalty later
      }

      final candidate = _scoreSeed(
        seed: seed,
        title: variant.$1,
        description: variant.$2,
        artifact: artifact,
        subtype: subtype,
        audiences: effectiveAudiences,
        intersectionBoost: intersectionBoost,
      );
      scored.add(candidate);
    }

    // Ensure density: if under limit, add cross-audience adapted fillers
    // from remaining seeds already included — pad by duplicating low-affinity
    // with adjusted titles is avoided; instead lower threshold.
    scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    var list = scored;
    if (query.category != null &&
        query.category!.isNotEmpty &&
        query.category != 'all') {
      list = list.where((c) => c.category == query.category).toList();
    }
    final q = query.searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.title.toLowerCase().contains(q) ||
            c.shortDescription.toLowerCase().contains(q) ||
            c.tags.any((t) => t.toLowerCase().contains(q)) ||
            ConceptCategory.labelKo(c.category).contains(q);
      }).toList();
    }

    if (list.length < query.limit) {
      // Include more mid-score items already in scored that were filtered out
      // by category/search only when not filtering.
    }

    return list.take(query.limit).toList();
  }

  List<ConceptCandidate> topN(ConceptRecommendQuery query, {int n = 10}) {
    return rank(
      query.copyWithLimit(n < 50 ? 50 : query.limit),
    ).take(n).toList();
  }

  ConceptCandidate _scoreSeed({
    required ConceptSeed seed,
    required String title,
    required String description,
    required String artifact,
    required String? subtype,
    required List<String> audiences,
    required Map<String, double> intersectionBoost,
  }) {
    // Audience affinity: max + average for multi-select, boost intersection
    var maxW = 0.0;
    var sumW = 0.0;
    for (final a in audiences) {
      final w = seed.audienceWeights[a] ?? 1.0;
      if (w > maxW) maxW = w;
      sumW += w;
    }
    final avgW = sumW / audiences.length;
    // Prefer concepts strong for ALL selected audiences (intersection)
    var minW = 5.0;
    for (final a in audiences) {
      final w = seed.audienceWeights[a] ?? 1.0;
      if (w < minW) minW = w;
    }
    final audienceFactor = (maxW * 0.35 + avgW * 0.35 + minW * 0.30) / 5.0;

    final catBoost = intersectionBoost[seed.category] ?? 1.0;

    final base = seed.baseScores;
    double s(String k) => (base[k] ?? 3.5).clamp(1.0, 5.0);

    var ai = s('ai');
    var need = s('need') * (0.7 + audienceFactor * 0.6);
    var business = s('business');
    var diff = s('diff');
    var practical = s('practical');
    var beginner = s('beginner');
    var longevity = s('longevity');

    // Artifact-specific nudges
    switch (artifact) {
      case ArtifactType.app:
        practical = (practical + 0.3).clamp(1, 5);
        beginner = (beginner - 0.2).clamp(1, 5);
      case ArtifactType.ebook:
        beginner = (beginner + 0.2).clamp(1, 5);
        longevity = (longevity + 0.1).clamp(1, 5);
      case ArtifactType.contents:
        ai = (ai + 0.1).clamp(1, 5);
        diff = (diff + 0.2).clamp(1, 5);
      case ArtifactType.site:
        longevity = (longevity + 0.3).clamp(1, 5);
      case ArtifactType.promoSite:
        business = (business + 0.3).clamp(1, 5);
        practical = (practical + 0.2).clamp(1, 5);
    }

    if (subtype != null &&
        seed.subtypes.isNotEmpty &&
        !seed.subtypes.contains(subtype)) {
      need = (need - 0.6).clamp(1, 5);
    } else if (subtype != null && seed.subtypes.contains(subtype)) {
      need = (need + 0.4).clamp(1, 5);
      practical = (practical + 0.2).clamp(1, 5);
    }

    need = (need * catBoost).clamp(1.0, 5.0);

    final total =
        (ai * 0.16 +
            need * 0.22 +
            business * 0.14 +
            diff * 0.12 +
            practical * 0.16 +
            beginner * 0.10 +
            longevity * 0.10) *
        (0.85 + audienceFactor * 0.3);

    final commercial = ConceptCommercialCatalog.resolve(seed);
    final shortDesc = commercial.shortDescription.trim().isNotEmpty
        ? commercial.shortDescription
        : description;

    var why = _why(
      audiences: audiences,
      category: seed.category,
      need: need,
      ai: ai,
      practical: practical,
    );
    final recReason = commercial.recommendationReason.trim();
    if (recReason.isNotEmpty) {
      why = why.trim().isEmpty ? recReason : '$recReason · $why';
    }

    return ConceptCandidate(
      id: '${seed.id}__$artifact',
      title: title,
      shortDescription: shortDesc,
      category: seed.category,
      targetCustomers: audiences,
      compatibleArtifacts: [artifact],
      compatibleSubtypes: seed.subtypes,
      aiRelevanceScore: double.parse(ai.toStringAsFixed(2)),
      customerNeedScore: double.parse(need.toStringAsFixed(2)),
      businessPotentialScore: double.parse(business.toStringAsFixed(2)),
      differentiationScore: double.parse(diff.toStringAsFixed(2)),
      practicalValueScore: double.parse(practical.toStringAsFixed(2)),
      beginnerFitScore: double.parse(beginner.toStringAsFixed(2)),
      longevityScore: double.parse(longevity.toStringAsFixed(2)),
      totalScore: double.parse(total.toStringAsFixed(3)),
      tags: seed.tags,
      whyRecommended: why,
      sourceType: 'local_catalog',
      seedId: seed.id,
      customerProblem: commercial.customerProblem,
      promisedOutcome: commercial.promisedOutcome,
      reasonsToPay: commercial.reasonsToPay,
      uniqueValue: commercial.uniqueValue,
      recommendationReason: recReason,
      deprecated: seed.deprecated,
      replacementSeedId: seed.replacementSeedId,
      difficulty: commercial.difficulty,
      catalogVersion: seed.catalogVersion,
      active: seed.active,
    );
  }

  Map<String, double> _intersectionCategoryBoost(List<String> audiences) {
    if (audiences.length < 2) {
      return ConceptCatalog.audienceCategoryBoost[audiences.first] ?? const {};
    }
    // Categories that score high for multiple selected audiences
    final acc = <String, double>{};
    for (final a in audiences) {
      final boosts = ConceptCatalog.audienceCategoryBoost[a] ?? const {};
      for (final e in boosts.entries) {
        acc[e.key] = (acc[e.key] ?? 1.0) + (e.value - 1.0);
      }
    }
    // Normalize: shared categories get higher multipliers
    final shared = <String, double>{};
    for (final e in acc.entries) {
      var hits = 0;
      for (final a in audiences) {
        final b = ConceptCatalog.audienceCategoryBoost[a];
        if (b != null && b.containsKey(e.key)) hits++;
      }
      final shareFactor = 1.0 + (hits / audiences.length) * 0.35;
      shared[e.key] =
          (1.0 + (e.value - audiences.length).clamp(0, 2) * 0.15) * shareFactor;
    }
    return shared;
  }

  String _why({
    required List<String> audiences,
    required String category,
    required double need,
    required double ai,
    required double practical,
  }) {
    final labels = audiences
        .map((id) {
          final found = ProjectDesignCatalog.audiences.where((a) => a.id == id);
          return found.isEmpty ? id : found.first.label;
        })
        .take(2)
        .join('·');
    final cat = ConceptCategory.labelKo(category);
    return '$labels 고객의 $cat 니즈에 맞추고, '
        '적합도 ${bandLabelKo(bandFromScore(need))} · '
        'AI ${bandLabelKo(bandFromScore(ai))} · '
        '실용 ${bandLabelKo(bandFromScore(practical))} '
        '(내부 추천 평가)';
  }
}

extension on ConceptRecommendQuery {
  ConceptRecommendQuery copyWithLimit(int limit) => ConceptRecommendQuery(
    audienceIds: audienceIds,
    artifactType: artifactType,
    contentSubtype: contentSubtype,
    limit: limit,
    category: category,
    searchQuery: searchQuery,
  );
}
