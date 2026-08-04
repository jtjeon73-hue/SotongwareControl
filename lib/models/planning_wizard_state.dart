/// 선택형 기획 마법사 상태 (artifact-first, 로컬 규칙, UI 무관).
library;

import 'artifact_type.dart';

class PlanningWizardState {
  PlanningWizardState({
    this.mode = 'quick',
    this.step = 0,
    String? artifactType,
    this.contentSubtype,
    Map<String, List<String>>? artifactAnswers,
    this.topic = '',
    this.customerProblem = '',
    this.targetCustomer = '',
    this.desiredOutcome = '',
    this.sentencesManuallyEdited = false,
    Map<String, String>? customTexts,
    this.recommendedArtifact,
    // 레거시 생성자·fromJson 호환 (composer·테스트)
    String? deliverable,
    List<String> domains = const [],
    List<String> audiences = const [],
    List<String> problems = const [],
    List<String> outcomes = const [],
    List<String> formats = const [],
    String? scale,
    String? duration,
    String? budget,
    String? salesMode,
    List<String> followUpDeliverables = const [],
  }) : artifactType =
           artifactType ??
           (deliverable != null ? ArtifactType.normalize(deliverable) : null),
       artifactAnswers = _mergeLegacyAnswers(
         artifactAnswers,
         domains: domains,
         audiences: audiences,
         problems: problems,
         outcomes: outcomes,
         formats: formats,
         scale: scale,
         duration: duration,
         budget: budget,
         salesMode: salesMode,
       ),
       customTexts = customTexts ?? const {},
       _legacyFollowUpDeliverables = List<String>.from(followUpDeliverables);

  /// `quick` | `advanced`
  String mode;

  /// 0=artifact, 1=content subtype(contents만), 2=질문, 3=문장, 4=최종 확인
  int step;

  String? artifactType;
  String? contentSubtype;
  Map<String, List<String>> artifactAnswers;

  String topic;
  String customerProblem;
  String targetCustomer;
  String desiredOutcome;
  bool sentencesManuallyEdited;
  Map<String, String> customTexts;

  /// undecided 선택 후 시스템 추천 (확정 전)
  String? recommendedArtifact;

  final List<String> _legacyFollowUpDeliverables;

  // ---------------------------------------------------------------------------
  // 레거시 alias·getter (draft·테스트·composer 구 경로)
  // ---------------------------------------------------------------------------

  @Deprecated('Use artifactType')
  String? get deliverable => artifactType;

  @Deprecated('Use artifactType')
  set deliverable(String? value) {
    artifactType = value == null ? null : ArtifactType.normalize(value);
  }

  @Deprecated('Use artifactAnswers')
  List<String> get domains =>
      List<String>.from(artifactAnswers['_legacy_domains'] ?? const []);

  @Deprecated('Use artifactAnswers')
  List<String> get audiences =>
      _answerList('targetCustomer', fallbackKey: '_legacy_audiences');

  @Deprecated('Use artifactAnswers')
  List<String> get problems =>
      _answerList('customerProblem', fallbackKey: '_legacy_problems');

  @Deprecated('Use artifactAnswers')
  List<String> get outcomes =>
      _answerList('desiredOutcome', fallbackKey: '_legacy_outcomes');

  @Deprecated('Use artifactAnswers')
  List<String> get formats =>
      List<String>.from(artifactAnswers['_legacy_formats'] ?? const []);

  @Deprecated('Use artifactAnswers')
  String? get scale => _legacySingle('_legacy_scale', 'pageVolume');

  @Deprecated('Use artifactAnswers')
  String? get duration => _legacySingle('_legacy_duration', 'schedule');

  @Deprecated('Use artifactAnswers')
  String? get budget =>
      _firstSelected('budget') ??
      artifactAnswers['_legacy_budget']?.firstOrNull;

  @Deprecated('Use artifactAnswers')
  String? get salesMode =>
      _firstSelected('salesDeploy') ??
      _firstSelected('salesMode') ??
      artifactAnswers['_legacy_salesMode']?.firstOrNull;

  @Deprecated('Use artifactAnswers')
  List<String> get followUpDeliverables =>
      List<String>.from(_legacyFollowUpDeliverables);

  /// 확정 artifact (undecided → 추천 확정 후 실제 유형).
  String? get effectiveArtifactType {
    final raw = artifactType;
    if (raw == null || raw.isEmpty) return null;
    if (raw != ArtifactType.undecided) return ArtifactType.normalize(raw);
    if (recommendedArtifact != null &&
        recommendedArtifact != ArtifactType.undecided) {
      return ArtifactType.normalize(recommendedArtifact!);
    }
    return raw;
  }

  bool get canProceedPastArtifact {
    final effective = effectiveArtifactType;
    return effective != null &&
        effective.isNotEmpty &&
        effective != ArtifactType.undecided;
  }

  bool get canCreateInstruction {
    if (!canProceedPastArtifact) return false;
    if (topic.trim().isEmpty ||
        customerProblem.trim().isEmpty ||
        targetCustomer.trim().isEmpty ||
        desiredOutcome.trim().isEmpty) {
      return false;
    }
    if (ArtifactType.normalize(effectiveArtifactType!) ==
        ArtifactType.contents) {
      final sub = ContentSubtype.normalize(contentSubtype ?? '');
      return sub.isNotEmpty && sub != ContentSubtype.undecided;
    }
    return true;
  }

  @Deprecated('Use canProceedPastArtifact')
  bool get canAutoComplete => canProceedPastArtifact;

  List<String> _answerList(String primary, {required String fallbackKey}) {
    final primaryList = artifactAnswers[primary];
    if (primaryList != null && primaryList.isNotEmpty) {
      return List<String>.from(primaryList);
    }
    return List<String>.from(artifactAnswers[fallbackKey] ?? const []);
  }

  String? _firstSelected(String questionId) {
    final list = artifactAnswers[questionId];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  String? _legacySingle(String legacyKey, String modernKey) {
    return artifactAnswers[legacyKey]?.firstOrNull ??
        artifactAnswers[modernKey]?.firstOrNull;
  }

  PlanningWizardState copyWith({
    String? mode,
    int? step,
    String? artifactType,
    String? contentSubtype,
    Map<String, List<String>>? artifactAnswers,
    String? topic,
    String? customerProblem,
    String? targetCustomer,
    String? desiredOutcome,
    bool? sentencesManuallyEdited,
    Map<String, String>? customTexts,
    String? recommendedArtifact,
    List<String>? followUpDeliverables,
    bool clearArtifactType = false,
    bool clearContentSubtype = false,
    bool clearRecommendedArtifact = false,
    // 레거시 copyWith (planning_choice_catalog·테스트)
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
  }) {
    final resolvedArtifact = clearArtifactType
        ? null
        : (artifactType ??
              (deliverable != null
                  ? ArtifactType.normalize(deliverable)
                  : this.artifactType));

    var mergedAnswers =
        artifactAnswers ?? _deepCopyAnswers(this.artifactAnswers);

    void putList(String key, List<String> values) {
      mergedAnswers[key] = List<String>.from(values);
    }

    void putSingle(String key, String? value) {
      if (value == null || value.isEmpty) return;
      mergedAnswers[key] = [value];
    }

    if (domains != null) putList('_legacy_domains', domains);
    if (audiences != null) {
      putList('targetCustomer', audiences);
      putList('_legacy_audiences', audiences);
    }
    if (problems != null) {
      putList('customerProblem', problems);
      putList('_legacy_problems', problems);
    }
    if (outcomes != null) {
      putList('desiredOutcome', outcomes);
      putList('_legacy_outcomes', outcomes);
    }
    if (formats != null) putList('_legacy_formats', formats);
    if (scale != null) putSingle('_legacy_scale', scale);
    if (duration != null) {
      putSingle('schedule', duration);
      putSingle('_legacy_duration', duration);
    }
    if (budget != null) {
      putSingle('budget', budget);
      putSingle('_legacy_budget', budget);
    }
    if (salesMode != null) {
      putSingle('salesDeploy', salesMode);
      putSingle('_legacy_salesMode', salesMode);
    }

    return PlanningWizardState(
      mode: mode ?? this.mode,
      step: step ?? this.step,
      artifactType: resolvedArtifact,
      contentSubtype: clearContentSubtype
          ? null
          : (contentSubtype ?? this.contentSubtype),
      artifactAnswers: mergedAnswers,
      topic: topic ?? this.topic,
      customerProblem: customerProblem ?? this.customerProblem,
      targetCustomer: targetCustomer ?? this.targetCustomer,
      desiredOutcome: desiredOutcome ?? this.desiredOutcome,
      sentencesManuallyEdited:
          sentencesManuallyEdited ?? this.sentencesManuallyEdited,
      customTexts: customTexts ?? Map<String, String>.from(this.customTexts),
      recommendedArtifact: clearRecommendedArtifact
          ? null
          : (recommendedArtifact ?? this.recommendedArtifact),
      followUpDeliverables:
          followUpDeliverables ??
          List<String>.from(_legacyFollowUpDeliverables),
    );
  }

  PlanningWizardState deepCopy() => copyWith(
    artifactAnswers: _deepCopyAnswers(artifactAnswers),
    customTexts: Map<String, String>.from(customTexts),
    followUpDeliverables: List<String>.from(_legacyFollowUpDeliverables),
  );

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'step': step,
    if (artifactType != null) 'artifactType': artifactType,
    if (contentSubtype != null) 'contentSubtype': contentSubtype,
    'artifactAnswers': artifactAnswers.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    ),
    'topic': topic,
    'customerProblem': customerProblem,
    'targetCustomer': targetCustomer,
    'desiredOutcome': desiredOutcome,
    'sentencesManuallyEdited': sentencesManuallyEdited,
    'customTexts': customTexts,
    if (recommendedArtifact != null) 'recommendedArtifact': recommendedArtifact,
    // draft 호환
    if (artifactType != null) 'deliverable': artifactType,
    if (_legacyFollowUpDeliverables.isNotEmpty)
      'followUpDeliverables': _legacyFollowUpDeliverables,
  };

  factory PlanningWizardState.fromJson(Map<String, dynamic> json) {
    var artifactType = json['artifactType'] == null
        ? null
        : ArtifactType.normalize('${json['artifactType']}');
    if ((artifactType == null || artifactType.isEmpty) &&
        json['deliverable'] != null) {
      artifactType = ArtifactType.normalize('${json['deliverable']}');
    }

    final answers = <String, List<String>>{};
    final rawAnswers = json['artifactAnswers'] as Map?;
    if (rawAnswers != null) {
      for (final entry in rawAnswers.entries) {
        answers['${entry.key}'] =
            (entry.value as List?)?.map((e) => '$e').toList() ?? const [];
      }
    }

    _migrateLegacyJson(json, answers);

    return PlanningWizardState(
      mode: '${json['mode'] ?? 'quick'}',
      step: (json['step'] as num?)?.toInt() ?? 0,
      artifactType: artifactType,
      contentSubtype: json['contentSubtype'] == null
          ? null
          : ContentSubtype.normalize('${json['contentSubtype']}'),
      artifactAnswers: answers,
      topic: '${json['topic'] ?? ''}',
      customerProblem: '${json['customerProblem'] ?? ''}',
      targetCustomer: '${json['targetCustomer'] ?? ''}',
      desiredOutcome: '${json['desiredOutcome'] ?? ''}',
      sentencesManuallyEdited: json['sentencesManuallyEdited'] == true,
      customTexts:
          (json['customTexts'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const {},
      recommendedArtifact: json['recommendedArtifact'] == null
          ? null
          : ArtifactType.normalize('${json['recommendedArtifact']}'),
      followUpDeliverables:
          (json['followUpDeliverables'] as List?)?.map((e) => '$e').toList() ??
          const [],
    );
  }

  static Map<String, List<String>> _deepCopyAnswers(
    Map<String, List<String>> source,
  ) {
    return source.map((k, v) => MapEntry(k, List<String>.from(v)));
  }

  static Map<String, List<String>> _mergeLegacyAnswers(
    Map<String, List<String>>? base, {
    required List<String> domains,
    required List<String> audiences,
    required List<String> problems,
    required List<String> outcomes,
    required List<String> formats,
    String? scale,
    String? duration,
    String? budget,
    String? salesMode,
  }) {
    final answers = base != null
        ? _deepCopyAnswers(base)
        : <String, List<String>>{};

    void putLegacy(String key, List<String> values) {
      if (values.isEmpty) return;
      answers.putIfAbsent(key, () => List<String>.from(values));
    }

    void putSingleLegacy(String key, String? value) {
      if (value == null || value.isEmpty) return;
      answers.putIfAbsent(key, () => [value]);
    }

    putLegacy('_legacy_domains', domains);
    putLegacy('_legacy_audiences', audiences);
    putLegacy('_legacy_problems', problems);
    putLegacy('_legacy_outcomes', outcomes);
    putLegacy('_legacy_formats', formats);
    putSingleLegacy('_legacy_scale', scale);
    putSingleLegacy('_legacy_duration', duration);
    putSingleLegacy('_legacy_budget', budget);
    putSingleLegacy('_legacy_salesMode', salesMode);

    if (problems.isNotEmpty && !answers.containsKey('customerProblem')) {
      answers['customerProblem'] = List<String>.from(problems);
    }
    if (audiences.isNotEmpty && !answers.containsKey('targetCustomer')) {
      answers['targetCustomer'] = List<String>.from(audiences);
    }
    if (outcomes.isNotEmpty && !answers.containsKey('desiredOutcome')) {
      answers['desiredOutcome'] = List<String>.from(outcomes);
    }
    if (duration != null &&
        duration.isNotEmpty &&
        !answers.containsKey('schedule')) {
      answers['schedule'] = [duration];
    }
    if (budget != null && budget.isNotEmpty && !answers.containsKey('budget')) {
      answers['budget'] = [budget];
    }
    if (salesMode != null &&
        salesMode.isNotEmpty &&
        !answers.containsKey('salesDeploy')) {
      answers['salesDeploy'] = [salesMode];
    }

    return answers;
  }

  static void _migrateLegacyJson(
    Map<String, dynamic> json,
    Map<String, List<String>> answers,
  ) {
    void migrateList(String jsonKey, String answersKey) {
      if (answers.containsKey(answersKey)) return;
      final list = (json[jsonKey] as List?)?.map((e) => '$e').toList();
      if (list != null && list.isNotEmpty) {
        answers[answersKey] = list;
      }
    }

    migrateList('domains', '_legacy_domains');
    migrateList('audiences', '_legacy_audiences');
    migrateList('problems', 'customerProblem');
    if (!answers.containsKey('customerProblem')) {
      migrateList('problems', '_legacy_problems');
    }
    migrateList('outcomes', 'desiredOutcome');
    if (!answers.containsKey('desiredOutcome')) {
      migrateList('outcomes', '_legacy_outcomes');
    }
    migrateList('formats', '_legacy_formats');

    if (!answers.containsKey('_legacy_scale') && json['scale'] != null) {
      answers['_legacy_scale'] = ['${json['scale']}'];
    }
    if (!answers.containsKey('schedule') && json['duration'] != null) {
      answers['schedule'] = ['${json['duration']}'];
    }
    if (!answers.containsKey('budget') && json['budget'] != null) {
      answers['budget'] = ['${json['budget']}'];
    }
    if (!answers.containsKey('salesDeploy') && json['salesMode'] != null) {
      answers['salesDeploy'] = ['${json['salesMode']}'];
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
