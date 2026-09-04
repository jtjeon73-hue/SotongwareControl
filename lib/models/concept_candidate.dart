/// Concept recommendation models (local heuristic scores, not market stats).
library;

import 'artifact_type.dart';

/// Concept category ids used for filtering/weighting.
class ConceptCategory {
  static const ai = 'ai';
  static const money = 'money';
  static const productivity = 'productivity';
  static const education = 'education';
  static const health = 'health';
  static const life = 'life';
  static const business = 'business';
  static const hobby = 'hobby';
  static const relationship = 'relationship';
  static const rural = 'rural';
  static const retirement = 'retirement';
  static const tech = 'tech';
  static const content = 'content';
  static const marketing = 'marketing';

  static const all = <String>[
    ai,
    money,
    productivity,
    education,
    health,
    life,
    business,
    hobby,
    relationship,
    rural,
    retirement,
    tech,
    content,
    marketing,
  ];

  static String labelKo(String id) {
    switch (id) {
      case ai:
        return 'AI';
      case money:
        return '수익';
      case productivity:
        return '생산성';
      case education:
        return '교육';
      case health:
        return '건강';
      case life:
        return '생활';
      case business:
        return '사업';
      case hobby:
        return '취미';
      case relationship:
        return '관계';
      case rural:
        return '농촌';
      case retirement:
        return '노후';
      case tech:
        return '기술';
      case content:
        return '콘텐츠';
      case marketing:
        return '마케팅';
      default:
        return id;
    }
  }
}

/// Internal heuristic band — never present as market share %.
enum ConceptScoreBand { veryHigh, high, medium, low }

ConceptScoreBand bandFromScore(double score) {
  if (score >= 4.2) return ConceptScoreBand.veryHigh;
  if (score >= 3.4) return ConceptScoreBand.high;
  if (score >= 2.4) return ConceptScoreBand.medium;
  return ConceptScoreBand.low;
}

String bandLabelKo(ConceptScoreBand band) {
  switch (band) {
    case ConceptScoreBand.veryHigh:
      return '매우 높음';
    case ConceptScoreBand.high:
      return '높음';
    case ConceptScoreBand.medium:
      return '보통';
    case ConceptScoreBand.low:
      return '낮음';
  }
}

String bandStars(ConceptScoreBand band) {
  switch (band) {
    case ConceptScoreBand.veryHigh:
      return '★★★★★';
    case ConceptScoreBand.high:
      return '★★★★☆';
    case ConceptScoreBand.medium:
      return '★★★☆☆';
    case ConceptScoreBand.low:
      return '★★☆☆☆';
  }
}

/// Scored concept candidate for an audience × artifact query.
class ConceptCandidate {
  const ConceptCandidate({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.category,
    required this.targetCustomers,
    required this.compatibleArtifacts,
    this.compatibleSubtypes = const [],
    required this.aiRelevanceScore,
    required this.customerNeedScore,
    required this.businessPotentialScore,
    required this.differentiationScore,
    required this.practicalValueScore,
    required this.beginnerFitScore,
    required this.longevityScore,
    required this.totalScore,
    this.tags = const [],
    this.whyRecommended = '',
    this.sourceType = 'local_catalog',
    this.isUserAdded = false,
    this.seedId,
    this.customerProblem = '',
    this.promisedOutcome = '',
    this.reasonsToPay = const [],
    this.uniqueValue = '',
    this.recommendationReason = '',
    this.deprecated = false,
    this.replacementSeedId,
    this.difficulty = 'medium',
    this.catalogVersion = 1,
    this.active = true,
  });

  final String id;
  final String title;
  final String shortDescription;
  final String category;
  final List<String> targetCustomers;
  final List<String> compatibleArtifacts;
  final List<String> compatibleSubtypes;
  final double aiRelevanceScore;
  final double customerNeedScore;
  final double businessPotentialScore;
  final double differentiationScore;
  final double practicalValueScore;
  final double beginnerFitScore;
  final double longevityScore;
  final double totalScore;
  final List<String> tags;
  final String whyRecommended;
  final String sourceType;
  final bool isUserAdded;
  final String? seedId;
  final String customerProblem;
  final String promisedOutcome;
  final List<String> reasonsToPay;
  final String uniqueValue;
  final String recommendationReason;
  final bool deprecated;
  final String? replacementSeedId;
  final String difficulty;
  final int catalogVersion;
  final bool active;

  ConceptScoreBand get fitBand => bandFromScore(customerNeedScore);
  ConceptScoreBand get aiBand => bandFromScore(aiRelevanceScore);
  ConceptScoreBand get practicalBand => bandFromScore(practicalValueScore);
  ConceptScoreBand get businessBand => bandFromScore(businessPotentialScore);
  ConceptScoreBand get difficultyBand {
    // Inverse of beginner fit for "난이도" display.
    return bandFromScore(6.0 - beginnerFitScore.clamp(1.0, 5.0));
  }

  ConceptCandidate copyWith({
    String? id,
    String? title,
    String? shortDescription,
    double? totalScore,
    String? whyRecommended,
    bool? isUserAdded,
    List<String>? tags,
    String? seedId,
    String? customerProblem,
    String? promisedOutcome,
    List<String>? reasonsToPay,
    String? uniqueValue,
    String? recommendationReason,
    bool? deprecated,
    String? replacementSeedId,
    String? difficulty,
    int? catalogVersion,
    bool? active,
  }) {
    return ConceptCandidate(
      id: id ?? this.id,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      category: category,
      targetCustomers: targetCustomers,
      compatibleArtifacts: compatibleArtifacts,
      compatibleSubtypes: compatibleSubtypes,
      aiRelevanceScore: aiRelevanceScore,
      customerNeedScore: customerNeedScore,
      businessPotentialScore: businessPotentialScore,
      differentiationScore: differentiationScore,
      practicalValueScore: practicalValueScore,
      beginnerFitScore: beginnerFitScore,
      longevityScore: longevityScore,
      totalScore: totalScore ?? this.totalScore,
      tags: tags ?? this.tags,
      whyRecommended: whyRecommended ?? this.whyRecommended,
      sourceType: sourceType,
      isUserAdded: isUserAdded ?? this.isUserAdded,
      seedId: seedId ?? this.seedId,
      customerProblem: customerProblem ?? this.customerProblem,
      promisedOutcome: promisedOutcome ?? this.promisedOutcome,
      reasonsToPay: reasonsToPay ?? this.reasonsToPay,
      uniqueValue: uniqueValue ?? this.uniqueValue,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      deprecated: deprecated ?? this.deprecated,
      replacementSeedId: replacementSeedId ?? this.replacementSeedId,
      difficulty: difficulty ?? this.difficulty,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'shortDescription': shortDescription,
    'category': category,
    'targetCustomers': targetCustomers,
    'compatibleArtifacts': compatibleArtifacts,
    'compatibleSubtypes': compatibleSubtypes,
    'aiRelevanceScore': aiRelevanceScore,
    'customerNeedScore': customerNeedScore,
    'businessPotentialScore': businessPotentialScore,
    'differentiationScore': differentiationScore,
    'practicalValueScore': practicalValueScore,
    'beginnerFitScore': beginnerFitScore,
    'longevityScore': longevityScore,
    'totalScore': totalScore,
    'tags': tags,
    'whyRecommended': whyRecommended,
    'sourceType': sourceType,
    'isUserAdded': isUserAdded,
    'seedId': seedId,
    'customerProblem': customerProblem,
    'promisedOutcome': promisedOutcome,
    'reasonsToPay': reasonsToPay,
    'uniqueValue': uniqueValue,
    'recommendationReason': recommendationReason,
    'deprecated': deprecated,
    'replacementSeedId': replacementSeedId,
    'difficulty': difficulty,
    'catalogVersion': catalogVersion,
    'active': active,
  };

  factory ConceptCandidate.fromJson(Map<String, dynamic> json) {
    double d(Object? v, [double fallback = 3]) =>
        (v is num) ? v.toDouble() : fallback;
    return ConceptCandidate(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      shortDescription: '${json['shortDescription'] ?? ''}',
      category: '${json['category'] ?? ConceptCategory.life}',
      targetCustomers:
          (json['targetCustomers'] as List?)?.map((e) => '$e').toList() ??
          const [],
      compatibleArtifacts:
          (json['compatibleArtifacts'] as List?)?.map((e) => '$e').toList() ??
          ArtifactType.allSelectable,
      compatibleSubtypes:
          (json['compatibleSubtypes'] as List?)?.map((e) => '$e').toList() ??
          const [],
      aiRelevanceScore: d(json['aiRelevanceScore']),
      customerNeedScore: d(json['customerNeedScore']),
      businessPotentialScore: d(json['businessPotentialScore']),
      differentiationScore: d(json['differentiationScore']),
      practicalValueScore: d(json['practicalValueScore']),
      beginnerFitScore: d(json['beginnerFitScore']),
      longevityScore: d(json['longevityScore']),
      totalScore: d(json['totalScore']),
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
      whyRecommended: '${json['whyRecommended'] ?? ''}',
      sourceType: '${json['sourceType'] ?? 'local_catalog'}',
      isUserAdded: json['isUserAdded'] == true,
      seedId: json['seedId'] as String?,
      customerProblem: '${json['customerProblem'] ?? ''}',
      promisedOutcome: '${json['promisedOutcome'] ?? ''}',
      reasonsToPay:
          (json['reasonsToPay'] as List?)?.map((e) => '$e').toList() ??
          const [],
      uniqueValue: '${json['uniqueValue'] ?? ''}',
      recommendationReason: '${json['recommendationReason'] ?? ''}',
      deprecated: json['deprecated'] == true,
      replacementSeedId: json['replacementSeedId'] as String?,
      difficulty: '${json['difficulty'] ?? 'medium'}',
      catalogVersion: (json['catalogVersion'] is num)
          ? (json['catalogVersion'] as num).toInt()
          : 1,
      active: json['active'] != false,
    );
  }

  static ConceptCandidate userAdded({
    required String title,
    String memo = '',
    required String artifactType,
    List<String> audiences = const [],
  }) {
    final id =
        'user_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';
    return ConceptCandidate(
      id: id,
      title: title.trim(),
      shortDescription: memo.trim().isEmpty ? '사용자가 직접 추가한 아이디어' : memo.trim(),
      category: ConceptCategory.life,
      targetCustomers: audiences,
      compatibleArtifacts: [ArtifactType.normalize(artifactType)],
      aiRelevanceScore: 3,
      customerNeedScore: 4.5,
      businessPotentialScore: 3.5,
      differentiationScore: 4,
      practicalValueScore: 4,
      beginnerFitScore: 3.5,
      longevityScore: 3.5,
      totalScore: 4.2,
      tags: const ['user', 'custom'],
      whyRecommended: '사용자가 직접 추가한 컨셉입니다.',
      sourceType: 'user_added',
      isUserAdded: true,
    );
  }
}

/// Sentence / field confirmation status in the design wizard.
enum DesignFieldStatus {
  undecided,
  suggested,
  userSelected,
  userEdited,
  userConfirmed,
}

extension DesignFieldStatusX on DesignFieldStatus {
  String get labelKo {
    switch (this) {
      case DesignFieldStatus.undecided:
        return '미정';
      case DesignFieldStatus.suggested:
        return 'AI 추천';
      case DesignFieldStatus.userSelected:
        return '사용자 선택';
      case DesignFieldStatus.userEdited:
        return '사용자 수정';
      case DesignFieldStatus.userConfirmed:
        return '사용자 확정';
    }
  }

  bool get isLocked =>
      this == DesignFieldStatus.userConfirmed ||
      this == DesignFieldStatus.userEdited;

  bool get isConfirmed => this == DesignFieldStatus.userConfirmed;

  String get fieldSource {
    switch (this) {
      case DesignFieldStatus.userConfirmed:
        return 'user_confirmed';
      case DesignFieldStatus.userEdited:
      case DesignFieldStatus.userSelected:
        return 'user_selected';
      case DesignFieldStatus.suggested:
        return 'suggested';
      case DesignFieldStatus.undecided:
        return 'undecided';
    }
  }

  static DesignFieldStatus parse(String raw) {
    switch (raw) {
      case 'user_confirmed':
      case 'userConfirmed':
        return DesignFieldStatus.userConfirmed;
      case 'user_edited':
      case 'userEdited':
        return DesignFieldStatus.userEdited;
      case 'user_selected':
      case 'userSelected':
        return DesignFieldStatus.userSelected;
      case 'suggested':
        return DesignFieldStatus.suggested;
      default:
        return DesignFieldStatus.undecided;
    }
  }
}
