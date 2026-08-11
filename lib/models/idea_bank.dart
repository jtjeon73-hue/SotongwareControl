class IdeaBankStatuses {
  static const idea = 'idea';
  static const reviewing = 'reviewing';
  static const planningCandidate = 'planning_candidate';
  static const sentToWorkOrder = 'sent_to_work_order';
  static const hold = 'hold';
  static const done = 'done';

  static const all = [
    idea,
    reviewing,
    planningCandidate,
    sentToWorkOrder,
    hold,
    done,
  ];

  static String labelKo(String id) {
    switch (id) {
      case reviewing:
        return '검토중';
      case planningCandidate:
        return '기획후보';
      case sentToWorkOrder:
        return '작업지시 전환';
      case hold:
        return '보류';
      case done:
        return '완료';
      default:
        return '아이디어';
    }
  }
}

class IdeaBankItem {
  const IdeaBankItem({
    required this.id,
    required this.title,
    this.oneLiner = '',
    this.targetCustomer = '',
    this.product = '',
    this.aiUse = '',
    this.revenueMethod = '',
    this.difficulty = '',
    this.initialCost = '',
    this.automationPotential = '',
    this.recommendReason = '',
    this.status = IdeaBankStatuses.idea,
    this.memo = '',
    required this.createdAt,
    required this.updatedAt,
    required this.year,
    required this.month,
    this.favorite = false,
    this.category = '',
    this.whyNow = '',
    this.howToBusiness = '',
    this.businessUnits = '',
    this.estimatedScale = '',
    this.infoAsOf = '',
    this.lastCheckedAt = '',
    this.isSeed = false,
    this.sources = const [],
    this.scoreTrend = 0,
    this.scoreMarket = 0,
    this.scoreFit = 0,
  });

  final String id;
  final String title;
  final String oneLiner;
  final String targetCustomer;
  final String product;
  final String aiUse;
  final String revenueMethod;
  final String difficulty;
  final String initialCost;
  final String automationPotential;
  final String recommendReason;
  final String status;
  final String memo;
  final String createdAt;
  final String updatedAt;
  final int year;
  final int month;
  final bool favorite;

  /// IdeaBankCategories id (optional).
  final String category;
  final String whyNow;
  final String howToBusiness;
  final String businessUnits;
  final String estimatedScale;
  final String infoAsOf;
  final String lastCheckedAt;
  final bool isSeed;
  final List<IdeaBankSourceLite> sources;

  /// 0이면 미평가. 1~5 참고 지표 (사실 단정 아님).
  final int scoreTrend;
  final int scoreMarket;
  final int scoreFit;

  IdeaBankItem copyWith({
    String? title,
    String? oneLiner,
    String? targetCustomer,
    String? product,
    String? aiUse,
    String? revenueMethod,
    String? difficulty,
    String? initialCost,
    String? automationPotential,
    String? recommendReason,
    String? status,
    String? memo,
    String? updatedAt,
    int? year,
    int? month,
    bool? favorite,
    String? category,
    String? whyNow,
    String? howToBusiness,
    String? businessUnits,
    String? estimatedScale,
    String? infoAsOf,
    String? lastCheckedAt,
    bool? isSeed,
    List<IdeaBankSourceLite>? sources,
    int? scoreTrend,
    int? scoreMarket,
    int? scoreFit,
  }) {
    return IdeaBankItem(
      id: id,
      title: title ?? this.title,
      oneLiner: oneLiner ?? this.oneLiner,
      targetCustomer: targetCustomer ?? this.targetCustomer,
      product: product ?? this.product,
      aiUse: aiUse ?? this.aiUse,
      revenueMethod: revenueMethod ?? this.revenueMethod,
      difficulty: difficulty ?? this.difficulty,
      initialCost: initialCost ?? this.initialCost,
      automationPotential: automationPotential ?? this.automationPotential,
      recommendReason: recommendReason ?? this.recommendReason,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      year: year ?? this.year,
      month: month ?? this.month,
      favorite: favorite ?? this.favorite,
      category: category ?? this.category,
      whyNow: whyNow ?? this.whyNow,
      howToBusiness: howToBusiness ?? this.howToBusiness,
      businessUnits: businessUnits ?? this.businessUnits,
      estimatedScale: estimatedScale ?? this.estimatedScale,
      infoAsOf: infoAsOf ?? this.infoAsOf,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      isSeed: isSeed ?? this.isSeed,
      sources: sources ?? this.sources,
      scoreTrend: scoreTrend ?? this.scoreTrend,
      scoreMarket: scoreMarket ?? this.scoreMarket,
      scoreFit: scoreFit ?? this.scoreFit,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'oneLiner': oneLiner,
    'targetCustomer': targetCustomer,
    'product': product,
    'aiUse': aiUse,
    'revenueMethod': revenueMethod,
    'difficulty': difficulty,
    'initialCost': initialCost,
    'automationPotential': automationPotential,
    'recommendReason': recommendReason,
    'status': status,
    'memo': memo,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'year': year,
    'month': month,
    'favorite': favorite,
    'category': category,
    'whyNow': whyNow,
    'howToBusiness': howToBusiness,
    'businessUnits': businessUnits,
    'estimatedScale': estimatedScale,
    'infoAsOf': infoAsOf,
    'lastCheckedAt': lastCheckedAt,
    'isSeed': isSeed,
    'sources': sources.map((e) => e.toJson()).toList(),
    'scoreTrend': scoreTrend,
    'scoreMarket': scoreMarket,
    'scoreFit': scoreFit,
  };

  factory IdeaBankItem.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final sources = <IdeaBankSourceLite>[];
    if (rawSources is List) {
      for (final e in rawSources) {
        if (e is Map<String, dynamic>) {
          sources.add(IdeaBankSourceLite.fromJson(e));
        } else if (e is Map) {
          sources.add(
            IdeaBankSourceLite.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return IdeaBankItem(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      oneLiner: '${json['oneLiner'] ?? ''}',
      targetCustomer: '${json['targetCustomer'] ?? ''}',
      product: '${json['product'] ?? ''}',
      aiUse: '${json['aiUse'] ?? ''}',
      revenueMethod: '${json['revenueMethod'] ?? ''}',
      difficulty: '${json['difficulty'] ?? ''}',
      initialCost: '${json['initialCost'] ?? ''}',
      automationPotential: '${json['automationPotential'] ?? ''}',
      recommendReason: '${json['recommendReason'] ?? ''}',
      status: '${json['status'] ?? IdeaBankStatuses.idea}',
      memo: '${json['memo'] ?? ''}',
      createdAt: '${json['createdAt'] ?? ''}',
      updatedAt: '${json['updatedAt'] ?? ''}',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      favorite: json['favorite'] == true,
      category: '${json['category'] ?? ''}',
      whyNow: '${json['whyNow'] ?? ''}',
      howToBusiness: '${json['howToBusiness'] ?? ''}',
      businessUnits: '${json['businessUnits'] ?? ''}',
      estimatedScale: '${json['estimatedScale'] ?? ''}',
      infoAsOf: '${json['infoAsOf'] ?? ''}',
      lastCheckedAt: '${json['lastCheckedAt'] ?? ''}',
      isSeed: json['isSeed'] == true,
      sources: sources,
      scoreTrend: (json['scoreTrend'] as num?)?.toInt() ?? 0,
      scoreMarket: (json['scoreMarket'] as num?)?.toInt() ?? 0,
      scoreFit: (json['scoreFit'] as num?)?.toInt() ?? 0,
    );
  }
}

class IdeaBankSourceLite {
  const IdeaBankSourceLite({
    required this.sourceTitle,
    required this.sourceUrl,
    this.sourceType = 'official',
    this.checkedAt = '',
  });

  final String sourceTitle;
  final String sourceUrl;
  final String sourceType;
  final String checkedAt;

  Map<String, dynamic> toJson() => {
    'sourceTitle': sourceTitle,
    'sourceUrl': sourceUrl,
    'sourceType': sourceType,
    'checkedAt': checkedAt,
  };

  factory IdeaBankSourceLite.fromJson(Map<String, dynamic> json) {
    return IdeaBankSourceLite(
      sourceTitle: '${json['sourceTitle'] ?? ''}',
      sourceUrl: '${json['sourceUrl'] ?? ''}',
      sourceType: '${json['sourceType'] ?? 'official'}',
      checkedAt: '${json['checkedAt'] ?? ''}',
    );
  }
}

/// 작업지시 제작소로 넘길 초기값 (active plan 덮어쓰기 금지).
class IdeaToPlanningSeed {
  const IdeaToPlanningSeed({
    required this.title,
    this.targetCustomer = '',
    this.field = '',
    this.description = '',
    this.memo = '',
  });

  final String title;
  final String targetCustomer;
  final String field;
  final String description;
  final String memo;
}
