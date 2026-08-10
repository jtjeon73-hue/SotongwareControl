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
  };

  factory IdeaBankItem.fromJson(Map<String, dynamic> json) {
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
