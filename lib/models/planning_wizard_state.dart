/// 선택형 기획 마법사 상태 (로컬 규칙 기반, UI 무관).
library;

class PlanningWizardState {
  PlanningWizardState({
    this.mode = 'quick',
    this.step = 0,
    this.deliverable,
    this.domains = const [],
    this.audiences = const [],
    this.problems = const [],
    this.outcomes = const [],
    this.formats = const [],
    this.scale,
    this.duration,
    this.budget,
    this.salesMode,
    this.topic = '',
    this.customerProblem = '',
    this.targetCustomer = '',
    this.desiredOutcome = '',
    this.sentencesManuallyEdited = false,
    this.customTexts = const {},
    this.followUpDeliverables = const [],
  });

  /// `quick` | `advanced`
  String mode;

  /// 0–7 단계, 8 = 최종 확인
  int step;

  String? deliverable;
  List<String> domains;
  List<String> audiences;
  List<String> problems;
  List<String> outcomes;
  List<String> formats;
  String? scale;
  String? duration;
  String? budget;
  String? salesMode;

  String topic;
  String customerProblem;
  String targetCustomer;
  String desiredOutcome;
  bool sentencesManuallyEdited;

  /// `custom` 선택 시 사용자 입력 (키: step id 또는 필드명).
  Map<String, String> customTexts;

  /// 추천 후속 결과물 id (예: youtube_shorts, web_marketing).
  List<String> followUpDeliverables;

  bool get canAutoComplete =>
      deliverable != null &&
      deliverable!.isNotEmpty &&
      deliverable != 'undecided' &&
      domains.isNotEmpty;

  PlanningWizardState copyWith({
    String? mode,
    int? step,
    String? deliverable,
    List<String>? domains,
    List<String>? audiences,
    List<String>? problems,
    List<String>? outcomes,
    List<String>? formats,
    String? scale,
    String? duration,
    String? budget,
    String? salesMode,
    String? topic,
    String? customerProblem,
    String? targetCustomer,
    String? desiredOutcome,
    bool? sentencesManuallyEdited,
    Map<String, String>? customTexts,
    List<String>? followUpDeliverables,
    bool clearDeliverable = false,
    bool clearScale = false,
    bool clearDuration = false,
    bool clearBudget = false,
    bool clearSalesMode = false,
  }) {
    return PlanningWizardState(
      mode: mode ?? this.mode,
      step: step ?? this.step,
      deliverable: clearDeliverable ? null : (deliverable ?? this.deliverable),
      domains: domains ?? List<String>.from(this.domains),
      audiences: audiences ?? List<String>.from(this.audiences),
      problems: problems ?? List<String>.from(this.problems),
      outcomes: outcomes ?? List<String>.from(this.outcomes),
      formats: formats ?? List<String>.from(this.formats),
      scale: clearScale ? null : (scale ?? this.scale),
      duration: clearDuration ? null : (duration ?? this.duration),
      budget: clearBudget ? null : (budget ?? this.budget),
      salesMode: clearSalesMode ? null : (salesMode ?? this.salesMode),
      topic: topic ?? this.topic,
      customerProblem: customerProblem ?? this.customerProblem,
      targetCustomer: targetCustomer ?? this.targetCustomer,
      desiredOutcome: desiredOutcome ?? this.desiredOutcome,
      sentencesManuallyEdited:
          sentencesManuallyEdited ?? this.sentencesManuallyEdited,
      customTexts: customTexts ?? Map<String, String>.from(this.customTexts),
      followUpDeliverables:
          followUpDeliverables ?? List<String>.from(this.followUpDeliverables),
    );
  }

  /// 깊은 복사 (샘플 시드 → 사용자 편집용).
  PlanningWizardState deepCopy() => copyWith(
    domains: List<String>.from(domains),
    audiences: List<String>.from(audiences),
    problems: List<String>.from(problems),
    outcomes: List<String>.from(outcomes),
    formats: List<String>.from(formats),
    customTexts: Map<String, String>.from(customTexts),
    followUpDeliverables: List<String>.from(followUpDeliverables),
  );

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'step': step,
    if (deliverable != null) 'deliverable': deliverable,
    'domains': domains,
    'audiences': audiences,
    'problems': problems,
    'outcomes': outcomes,
    'formats': formats,
    if (scale != null) 'scale': scale,
    if (duration != null) 'duration': duration,
    if (budget != null) 'budget': budget,
    if (salesMode != null) 'salesMode': salesMode,
    'topic': topic,
    'customerProblem': customerProblem,
    'targetCustomer': targetCustomer,
    'desiredOutcome': desiredOutcome,
    'sentencesManuallyEdited': sentencesManuallyEdited,
    'customTexts': customTexts,
    'followUpDeliverables': followUpDeliverables,
  };

  factory PlanningWizardState.fromJson(Map<String, dynamic> json) {
    return PlanningWizardState(
      mode: '${json['mode'] ?? 'quick'}',
      step: (json['step'] as num?)?.toInt() ?? 0,
      deliverable: json['deliverable'] == null
          ? null
          : '${json['deliverable']}',
      domains:
          (json['domains'] as List?)?.map((e) => '$e').toList() ?? const [],
      audiences:
          (json['audiences'] as List?)?.map((e) => '$e').toList() ?? const [],
      problems:
          (json['problems'] as List?)?.map((e) => '$e').toList() ?? const [],
      outcomes:
          (json['outcomes'] as List?)?.map((e) => '$e').toList() ?? const [],
      formats:
          (json['formats'] as List?)?.map((e) => '$e').toList() ?? const [],
      scale: json['scale'] == null ? null : '${json['scale']}',
      duration: json['duration'] == null ? null : '${json['duration']}',
      budget: json['budget'] == null ? null : '${json['budget']}',
      salesMode: json['salesMode'] == null ? null : '${json['salesMode']}',
      topic: '${json['topic'] ?? ''}',
      customerProblem: '${json['customerProblem'] ?? ''}',
      targetCustomer: '${json['targetCustomer'] ?? ''}',
      desiredOutcome: '${json['desiredOutcome'] ?? ''}',
      sentencesManuallyEdited: json['sentencesManuallyEdited'] == true,
      customTexts:
          (json['customTexts'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const {},
      followUpDeliverables:
          (json['followUpDeliverables'] as List?)?.map((e) => '$e').toList() ??
          const [],
    );
  }
}
