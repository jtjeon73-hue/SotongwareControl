/// 선택값 → 한국어 기획 문장 조립 (로컬 규칙, 외부 AI 없음).
library;

import '../data/planning_choice_catalog.dart';
import '../models/business_planning.dart';
import '../models/planning_wizard_state.dart';

class PlanningSentenceComposer {
  const PlanningSentenceComposer();

  String composeTopic(PlanningWizardState state) {
    final deliverable = state.deliverable;
    if (deliverable == null || deliverable == 'custom') {
      return state.customTexts['deliverables']?.trim() ??
          state.customTexts['topic']?.trim() ??
          '';
    }

    final domainLabels = _labels(PlanningChoiceSteps.domains, state.domains);
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

  String composeProblem(PlanningWizardState state) {
    if (state.problems.contains('custom')) {
      final custom = state.customTexts['problems']?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }

    final problemLabels = _labels(PlanningChoiceSteps.problems, state.problems);
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

  String composeAudience(PlanningWizardState state) {
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
        final restLabels = _labels(PlanningChoiceSteps.audiences, rest);
        if (restLabels.isEmpty) return age;
        return '${restLabels.join(', ')} 및 $age';
      }
    }

    final labels = _labels(PlanningChoiceSteps.audiences, state.audiences);
    if (labels.isEmpty) return '';

    if (state.audiences.contains('return_prep') &&
        state.audiences.contains('sidejob_40_60')) {
      return '귀농·귀촌인, 농촌 거주자, 은퇴 준비자 및 온라인 부업을 원하는 40~60대';
    }

    return labels.join(', ');
  }

  String composeOutcome(PlanningWizardState state) {
    if (state.outcomes.contains('custom')) {
      final custom = state.customTexts['outcomes']?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }

    final outcomeLabels = _labels(PlanningChoiceSteps.outcomes, state.outcomes);
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

  /// 추천값 + 문장을 채운다. [sentencesManuallyEdited]이면 문장은 건드리지 않는다.
  PlanningWizardState applyAutoComplete(PlanningWizardState state) {
    if (!state.canAutoComplete) return state;

    var next = applyRecommendations(state);

    if (next.sentencesManuallyEdited) return next;

    return next.copyWith(
      topic: composeTopic(next),
      customerProblem: composeProblem(next),
      targetCustomer: composeAudience(next),
      desiredOutcome: composeOutcome(next),
    );
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

  List<String> _labels(String step, List<String> ids) {
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
    final labels = _labels(PlanningChoiceSteps.domains, state.domains);
    if (labels.isEmpty) return '';
    return '${_joinNatural(labels)} 분야에서 ';
  }

  String _audienceContextPhrase(PlanningWizardState state) {
    final labels = _labels(PlanningChoiceSteps.audiences, state.audiences);
    if (labels.isEmpty) return '';
    return '${labels.first}이(가) ';
  }
}
