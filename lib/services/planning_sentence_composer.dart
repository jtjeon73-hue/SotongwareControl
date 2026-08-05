/// 선택값 → 한국어 기획 문장 조립 (로컬 규칙, 외부 AI 없음).
library;

import '../data/artifact_question_catalog.dart';
import '../data/planning_choice_catalog.dart';
import '../models/business_planning.dart';
import '../models/planning_wizard_state.dart';

class PlanningSentenceComposer {
  const PlanningSentenceComposer();

  bool _usesArtifactFlow(PlanningWizardState state) {
    final artifact = state.effectiveArtifactType ?? state.artifactType;
    if (artifact == null ||
        artifact.isEmpty ||
        artifact == ArtifactType.undecided) {
      return false;
    }

    final hasModernAnswers = state.artifactAnswers.entries.any(
      (e) => !e.key.startsWith('_legacy') && e.value.isNotEmpty,
    );
    if (!hasModernAnswers && state.domains.isNotEmpty) {
      return false;
    }
    return true;
  }

  String composeTopic(PlanningWizardState state) {
    if (_usesArtifactFlow(state)) {
      return _composeTopicArtifact(state);
    }
    return _composeTopicLegacy(state);
  }

  String composeProblem(PlanningWizardState state) {
    if (_usesArtifactFlow(state)) {
      return _composeFromAnswers(
        state,
        'customerProblem',
        composeSentence: true,
      );
    }
    return _composeProblemLegacy(state);
  }

  String composeAudience(PlanningWizardState state) {
    if (_usesArtifactFlow(state)) {
      return _composeFromAnswers(
        state,
        'targetCustomer',
        composeSentence: false,
      );
    }
    return _composeAudienceLegacy(state);
  }

  String composeOutcome(PlanningWizardState state) {
    if (_usesArtifactFlow(state)) {
      return _composeFromAnswers(
        state,
        'desiredOutcome',
        composeSentence: true,
      );
    }
    return _composeOutcomeLegacy(state);
  }

  String _composeTopicArtifact(PlanningWizardState state) {
    final artifact = ArtifactType.normalize(state.effectiveArtifactType!);
    final artifactLabel = ArtifactType.labelKo(artifact);

    if (artifact == ArtifactType.contents &&
        state.contentSubtype != null &&
        ContentSubtype.normalize(state.contentSubtype!) !=
            ContentSubtype.undecided) {
      final subLabel = ContentSubtype.labelKo(
        ContentSubtype.normalize(state.contentSubtype!),
      );
      return '$subLabel $artifactLabel';
    }

    final domainPhrase = _artifactDomainPhrase(state);
    final kindLabel =
        _firstAnswerLabel(state, artifact, 'ebookKind') ??
        _firstAnswerLabel(state, artifact, 'appKind') ??
        _firstAnswerLabel(state, artifact, 'sitePurpose') ??
        _firstAnswerLabel(state, artifact, 'productService');

    if (artifact == ArtifactType.ebook) {
      final kindIds = state.artifactAnswers['ebookKind'] ?? const [];
      if (domainPhrase.isNotEmpty && kindLabel != null) {
        return '$domainPhrase $kindLabel $artifactLabel';
      }
      if (kindIds.contains('guide') || kindLabel == '가이드') {
        if (_hasRuralOnlineContext(state)) {
          return 'AI·온라인 수익 실행 가이드 $artifactLabel';
        }
        return '실행 가이드 $artifactLabel';
      }
      if (kindLabel != null && kindLabel.isNotEmpty) {
        return '$kindLabel $artifactLabel';
      }
      if (domainPhrase.isNotEmpty) {
        return '$domainPhrase $artifactLabel';
      }
      return '$artifactLabel 기획';
    }

    if (kindLabel != null && kindLabel.isNotEmpty) {
      if (domainPhrase.isNotEmpty) {
        return '$domainPhrase $kindLabel $artifactLabel';
      }
      return '$kindLabel $artifactLabel';
    }

    if (domainPhrase.isNotEmpty) {
      return '$domainPhrase $artifactLabel';
    }

    return '$artifactLabel 기획';
  }

  bool _hasRuralOnlineContext(PlanningWizardState state) {
    if (state.domains.contains('rural_life') ||
        state.domains.contains('online_income') ||
        state.domains.contains('return_farm')) {
      return true;
    }
    final problems = state.artifactAnswers['customerProblem'] ?? const [];
    if (problems.contains('productize_unknown')) return true;
    final targets = state.artifactAnswers['targetCustomer'] ?? const [];
    return targets.contains('return_prep') ||
        targets.contains('sidejob_40_60') ||
        targets.contains('rural_resident');
  }

  String _artifactDomainPhrase(PlanningWizardState state) {
    if (state.domains.contains('rural_life') ||
        state.domains.contains('return_farm')) {
      if (state.domains.contains('online_income')) {
        return 'AI·온라인 수익';
      }
      return '농촌·귀촌';
    }
    if (state.domains.contains('online_income')) {
      return '온라인 수익';
    }

    final problems = state.artifactAnswers['customerProblem'] ?? const [];
    if (problems.contains('productize_unknown')) {
      return 'AI·온라인 수익';
    }

    for (final entry in state.customTexts.entries) {
      if (entry.key.startsWith('_')) continue;
      final v = entry.value.trim();
      if (v.contains('농촌') || v.contains('시골') || v.contains('귀촌')) {
        return '농촌·온라인';
      }
    }
    return '';
  }

  String? _firstAnswerLabel(
    PlanningWizardState state,
    String artifact,
    String questionId,
  ) {
    final labels = _labelsForQuestion(
      state,
      artifact,
      questionId,
      state.artifactAnswers[questionId] ?? const [],
    );
    return labels.isEmpty ? null : labels.first;
  }

  String _composeFromAnswers(
    PlanningWizardState state,
    String questionId, {
    required bool composeSentence,
  }) {
    final artifact = ArtifactType.normalize(state.effectiveArtifactType!);
    final ids = state.artifactAnswers[questionId] ?? const [];
    if (ids.contains('custom')) {
      final custom = state.customTexts[questionId]?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }

    final labels = _labelsForQuestion(state, artifact, questionId, ids);
    if (labels.isEmpty) return '';

    if (questionId == 'customerProblem' &&
        ids.contains('productize_unknown') &&
        (state.domains.contains('rural_life') ||
            state.domains.contains('online_income') ||
            state.domains.contains('return_farm'))) {
      return '농촌이나 시골에 거주하면서 온라인 수익을 만들고 싶지만, '
          '자신의 경험과 기술을 어떤 상품으로 만들고 어떻게 판매해야 하는지 모른다.';
    }

    if (!composeSentence) {
      return labels.join(', ');
    }

    if (labels.length == 1) {
      return '${labels.first}.';
    }
    return '${labels.take(2).join(', ')} 등의 어려움이 있다.';
  }

  List<String> _labelsForQuestion(
    PlanningWizardState state,
    String artifact,
    String questionId,
    List<String> ids,
  ) {
    if (ids.isEmpty) return const [];

    final questions = questionsFor(
      artifact: artifact,
      contentSubtype: state.contentSubtype,
    );
    final question = questions.where((q) => q.id == questionId).firstOrNull;
    if (question == null) {
      return ids
          .where((id) => id != 'custom')
          .map((id) => labelForChoice(questionId, id))
          .where((l) => l.isNotEmpty)
          .toList();
    }

    return ids
        .where((id) => id != 'custom')
        .map((id) {
          final opt = question.options.where((o) => o.id == id).firstOrNull;
          return opt?.label ?? id;
        })
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// 추천값 + 빈 문장만 채운다. [sentencesManuallyEdited]이면 문장은 건드리지 않는다.
  PlanningWizardState applyAutoComplete(
    PlanningWizardState state, {
    bool trackUndo = false,
  }) {
    if (!state.canProceedPastArtifact && !state.canAutoComplete) return state;

    var next = _usesArtifactFlow(state)
        ? _applyArtifactDefaults(state)
        : applyRecommendations(state);

    if (next.sentencesManuallyEdited) return next;

    final customTexts = Map<String, String>.from(next.customTexts);

    String fillField(
      String current,
      String fieldKey,
      String Function() compose,
    ) {
      if (current.trim().isNotEmpty) return current;
      if (trackUndo) {
        customTexts['_undo_$fieldKey'] = current;
      }
      customTexts['_recommended:$fieldKey'] = '1';
      return compose();
    }

    return next.copyWith(
      topic: fillField(next.topic, 'topic', () => composeTopic(next)),
      customerProblem: fillField(
        next.customerProblem,
        'customerProblem',
        () => composeProblem(next),
      ),
      targetCustomer: fillField(
        next.targetCustomer,
        'targetCustomer',
        () => composeAudience(next),
      ),
      desiredOutcome: fillField(
        next.desiredOutcome,
        'desiredOutcome',
        () => composeOutcome(next),
      ),
      customTexts: customTexts,
    );
  }

  /// 자동 완성 직전 값으로 되돌린다 (추적된 필드만).
  PlanningWizardState undoAutofill(PlanningWizardState state) {
    final customTexts = Map<String, String>.from(state.customTexts);
    var next = state;

    for (final field in const [
      'topic',
      'customerProblem',
      'targetCustomer',
      'desiredOutcome',
    ]) {
      final undoKey = '_undo_$field';
      if (!customTexts.containsKey(undoKey)) continue;
      final previous = customTexts.remove(undoKey)!;
      customTexts.remove('_recommended:$field');
      next = switch (field) {
        'topic' => next.copyWith(topic: previous),
        'customerProblem' => next.copyWith(customerProblem: previous),
        'targetCustomer' => next.copyWith(targetCustomer: previous),
        'desiredOutcome' => next.copyWith(desiredOutcome: previous),
        _ => next,
      };
    }

    return next.copyWith(customTexts: customTexts);
  }

  bool hasAutofillUndo(PlanningWizardState state) {
    return state.customTexts.keys.any((k) => k.startsWith('_undo_'));
  }

  PlanningWizardState _applyArtifactDefaults(PlanningWizardState state) {
    if (!_usesArtifactFlow(state)) {
      return applyRecommendations(state);
    }

    final artifact = ArtifactType.normalize(state.effectiveArtifactType!);
    final defaults = defaultSelectionsFor(
      artifact,
      contentSubtype: state.contentSubtype,
    );
    final answers = Map<String, List<String>>.from(state.artifactAnswers);

    for (final entry in defaults.entries) {
      answers.putIfAbsent(entry.key, () => List<String>.from(entry.value));
    }

    return state.copyWith(artifactAnswers: answers);
  }

  /// 사용자 확인 후 명시적 재생성용.
  PlanningWizardState regenerateSentences(
    PlanningWizardState state, {
    bool force = false,
  }) {
    if (state.sentencesManuallyEdited && !force) return state;
    return state.copyWith(
      topic: composeTopic(state),
      customerProblem: composeProblem(state),
      targetCustomer: composeAudience(state),
      desiredOutcome: composeOutcome(state),
      sentencesManuallyEdited: false,
    );
  }

  /// `BusinessPlanInput` 필드로 변환 (기존 JSON 호환).
  BusinessPlanInput toBusinessPlanInput(PlanningWizardState state) {
    final completed = applyAutoComplete(state);

    if (_usesArtifactFlow(completed)) {
      return _toBusinessPlanInputArtifact(completed);
    }
    return _toBusinessPlanInputLegacy(completed);
  }

  BusinessPlanInput _toBusinessPlanInputArtifact(
    PlanningWizardState completed,
  ) {
    final artifact = ArtifactType.normalize(completed.effectiveArtifactType!);
    final scaleLabel =
        _labelForArtifactAnswer(completed, 'pageVolume') ??
        _labelForArtifactAnswer(completed, 'length') ??
        completed.scale?.let(
          (s) => labelForChoice(PlanningChoiceSteps.scales, s),
        ) ??
        '';

    final durationLabel =
        _labelForArtifactAnswer(completed, 'schedule') ??
        (completed.duration == null
            ? ''
            : labelForChoice(
                PlanningChoiceSteps.durations,
                completed.duration!,
              ));

    final budgetLabel =
        _labelForArtifactAnswer(completed, 'budget') ??
        (completed.budget == null
            ? ''
            : labelForChoice(PlanningChoiceSteps.budgets, completed.budget!));

    final salesLabel =
        _labelForArtifactAnswer(completed, 'salesDeploy') ??
        _labelForArtifactAnswer(completed, 'salesMode') ??
        (completed.salesMode == null
            ? ''
            : labelForChoice(
                PlanningChoiceSteps.salesModes,
                completed.salesMode!,
              ));

    final notesParts = <String>[
      if (completed.contentSubtype != null &&
          ContentSubtype.normalize(completed.contentSubtype!) !=
              ContentSubtype.undecided)
        '콘텐츠 유형: ${ContentSubtype.labelKo(ContentSubtype.normalize(completed.contentSubtype!))}',
      if (salesLabel.isNotEmpty) '판매·배포: $salesLabel',
    ];

    return BusinessPlanInput(
      topic: completed.topic,
      customerProblem: completed.customerProblem,
      targetCustomer: completed.targetCustomer,
      desiredOutcome: completed.desiredOutcome,
      deliverableTypes: [artifact],
      expectedScale: scaleLabel,
      expectedDuration: durationLabel,
      budgetEstimate: budgetLabel,
      revenueModel: salesLabel,
      notes: notesParts.join(' · '),
      wizardSelections: completed.toJson(),
      sentencesManuallyEdited: completed.sentencesManuallyEdited,
      artifactType: artifact,
      contentSubtype: completed.contentSubtype == null
          ? ''
          : ContentSubtype.normalize(completed.contentSubtype!),
      artifactAnswers: Map<String, List<String>>.from(
        completed.artifactAnswers,
      ),
    );
  }

  String? _labelForArtifactAnswer(
    PlanningWizardState state,
    String questionId,
  ) {
    final ids = state.artifactAnswers[questionId];
    if (ids == null || ids.isEmpty) return null;
    final labels = _labelsForQuestion(
      state,
      ArtifactType.normalize(state.effectiveArtifactType!),
      questionId,
      ids,
    );
    return labels.isEmpty ? null : labels.join(', ');
  }

  BusinessPlanInput _toBusinessPlanInputLegacy(PlanningWizardState completed) {
    final deliverables = <String>[
      if (completed.deliverable != null &&
          completed.deliverable != PlanningDeliverables.undecided &&
          completed.deliverable != PlanningDeliverables.custom)
        completed.deliverable!,
      ...completed.followUpDeliverables,
    ];

    final scaleLabel = completed.scale == null
        ? ''
        : labelForChoice(PlanningChoiceSteps.scales, completed.scale!);
    final durationLabel = completed.duration == null
        ? ''
        : labelForChoice(PlanningChoiceSteps.durations, completed.duration!);
    final budgetLabel = completed.budget == null
        ? ''
        : labelForChoice(PlanningChoiceSteps.budgets, completed.budget!);
    final salesLabel = completed.salesMode == null
        ? ''
        : labelForChoice(PlanningChoiceSteps.salesModes, completed.salesMode!);

    final formatLabels = completed.formats
        .map((f) => labelForChoice(PlanningChoiceSteps.formats, f))
        .toList();

    final notesParts = <String>[
      if (formatLabels.isNotEmpty) '제공 형태: ${formatLabels.join(', ')}',
      if (salesLabel.isNotEmpty) '판매·배포: $salesLabel',
    ];

    return BusinessPlanInput(
      topic: completed.topic,
      customerProblem: completed.customerProblem,
      targetCustomer: completed.targetCustomer,
      desiredOutcome: completed.desiredOutcome,
      deliverableTypes: deliverables.isEmpty
          ? const [DeliverableType.undecided]
          : deliverables,
      expectedScale: scaleLabel,
      expectedDuration: durationLabel,
      budgetEstimate: budgetLabel,
      revenueModel: salesLabel,
      notes: notesParts.join(' · '),
      wizardSelections: completed.toJson(),
      sentencesManuallyEdited: completed.sentencesManuallyEdited,
    );
  }

  // ---------------------------------------------------------------------------
  // 레거시 경로 (planning_choice_catalog 기반)
  // ---------------------------------------------------------------------------

  String _composeTopicLegacy(PlanningWizardState state) {
    final deliverable = state.deliverable;
    if (deliverable == null || deliverable == 'custom') {
      return state.customTexts['deliverables']?.trim() ??
          state.customTexts['topic']?.trim() ??
          '';
    }

    final domainLabels = _legacyLabels(
      PlanningChoiceSteps.domains,
      state.domains,
    );
    final deliverableLabel = labelForChoice(
      PlanningChoiceSteps.deliverables,
      deliverable,
    );

    if (domainLabels.isEmpty) {
      return '$deliverableLabel 기획';
    }

    final domainPhrase = _joinNatural(domainLabels);
    switch (deliverable) {
      case PlanningDeliverables.ebook:
        return '$domainPhrase 경험을 활용해 현실적인 온라인 수익을 시작하는 전자책';
      case PlanningDeliverables.youtubeShorts:
      case PlanningDeliverables.youtubeVideo:
        return '$domainPhrase 주제의 $deliverableLabel 콘텐츠';
      case PlanningDeliverables.webMarketing:
        return '$domainPhrase 분야 지역·소상공인을 위한 홍보·마케팅 웹사이트';
      case PlanningDeliverables.app:
        return '$domainPhrase 생활·업무를 돕는 모바일 앱';
      case PlanningDeliverables.industrialAutomation:
        return '$domainPhrase 설비·현장 데이터를 수집·모니터링하는 산업자동화 소프트웨어';
      case PlanningDeliverables.educationContent:
        return '$domainPhrase 학습자를 위한 교육 콘텐츠';
      case PlanningDeliverables.musicContent:
        return '$domainPhrase 음악·노래 콘텐츠';
      default:
        return '$domainPhrase 분야 $deliverableLabel';
    }
  }

  String _composeProblemLegacy(PlanningWizardState state) {
    if (state.problems.contains('custom')) {
      final custom = state.customTexts['problems']?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }

    final problemLabels = _legacyLabels(
      PlanningChoiceSteps.problems,
      state.problems,
    );
    if (problemLabels.isEmpty) return '';

    final audienceHint = _audienceContextPhrase(state);
    final domainHint = _domainContextPhrase(state);

    if (state.problems.contains('productize_unknown') &&
        (state.domains.contains('rural_life') ||
            state.domains.contains('online_income') ||
            state.domains.contains('return_farm'))) {
      return '농촌이나 시골에 거주하면서 온라인 수익을 만들고 싶지만, '
          '자신의 경험과 기술을 어떤 상품으로 만들고 어떻게 판매해야 하는지 모른다.';
    }

    if (state.deliverable == PlanningDeliverables.industrialAutomation) {
      if (state.problems.contains('data_monitor_hard')) {
        return '공장·설비 현장에서 데이터를 한곳에서 확인하기 어렵고, '
            '수작업 기록과 분산된 정보 때문에 오류와 지연이 발생한다.';
      }
    }

    if (problemLabels.length == 1) {
      return '$audienceHint$domainHint${problemLabels.first}.';
    }

    return '$audienceHint$domainHint'
        '${problemLabels.take(2).join(', ')} 등의 어려움이 있다.';
  }

  String _composeAudienceLegacy(PlanningWizardState state) {
    if (state.audiences.contains('custom')) {
      final custom = state.customTexts['audiences']?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }
    if (state.audiences.contains('age_custom')) {
      final age = state.customTexts['age_custom']?.trim();
      if (age != null && age.isNotEmpty) {
        final rest = state.audiences
            .where((a) => a != 'age_custom' && a != 'custom')
            .toList();
        final restLabels = _legacyLabels(PlanningChoiceSteps.audiences, rest);
        if (restLabels.isEmpty) return age;
        return '${restLabels.join(', ')} 및 $age';
      }
    }

    final labels = _legacyLabels(
      PlanningChoiceSteps.audiences,
      state.audiences,
    );
    if (labels.isEmpty) return '';

    if (state.audiences.contains('return_prep') &&
        state.audiences.contains('sidejob_40_60')) {
      return '귀농·귀촌인, 농촌 거주자, 은퇴 준비자 및 온라인 부업을 원하는 40~60대';
    }

    return labels.join(', ');
  }

  String _composeOutcomeLegacy(PlanningWizardState state) {
    if (state.outcomes.contains('custom')) {
      final custom = state.customTexts['outcomes']?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }

    final outcomeLabels = _legacyLabels(
      PlanningChoiceSteps.outcomes,
      state.outcomes,
    );
    if (outcomeLabels.isEmpty) return '';

    if (state.outcomes.contains('sellable') &&
        state.deliverable == PlanningDeliverables.ebook) {
      var text =
          '자신의 경험을 판매 가능한 전자책으로 완성하고, 판매처 등록과 홍보 활동을 통해 '
          '첫 온라인 수익을 시작한다.';
      if (state.salesMode == 'cheap_validate') {
        text = '$text (저가 판매로 초기 시장 검증)';
      }
      return text;
    }

    if (state.outcomes.contains('dashboard') &&
        state.deliverable == PlanningDeliverables.industrialAutomation) {
      return '설비·현장 데이터를 한 화면에서 확인하고, 반복 작업을 줄여 '
          '오류와 대응 시간을 줄인다.';
    }

    if (outcomeLabels.length == 1) {
      return '${outcomeLabels.first}을(를) 달성한다.';
    }

    return '${outcomeLabels.take(2).join('·')} 등의 결과를 얻는다.';
  }

  List<String> _legacyLabels(String step, List<String> ids) {
    return ids
        .where((id) => id != 'custom')
        .map((id) => labelForChoice(step, id))
        .where((l) => l.isNotEmpty)
        .toList();
  }

  String _joinNatural(List<String> labels) {
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]}·${labels[1]}';
    return '${labels.sublist(0, labels.length - 1).join(', ')}·${labels.last}';
  }

  String _domainContextPhrase(PlanningWizardState state) {
    final labels = _legacyLabels(PlanningChoiceSteps.domains, state.domains);
    if (labels.isEmpty) return '';
    return '${_joinNatural(labels)} 분야에서 ';
  }

  String _audienceContextPhrase(PlanningWizardState state) {
    final labels = _legacyLabels(
      PlanningChoiceSteps.audiences,
      state.audiences,
    );
    if (labels.isEmpty) return '';
    return '${labels.first}이(가) ';
  }
}

extension _FirstOrNullComposer<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T value) block) => block(this);
}
