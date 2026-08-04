import 'dart:async';

import 'package:flutter/material.dart';

import '../data/planning_choice_catalog.dart';
import '../models/business_planning.dart';
import '../models/planning_wizard_state.dart';
import '../services/planning_recent_store.dart';
import '../services/planning_sentence_composer.dart';
import '../theme/control_theme.dart';

/// 선택형 기획 마법사 (0–7 단계 + 8 최종 확인).
class PlanningWizardPanel extends StatefulWidget {
  const PlanningWizardPanel({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onConfirmCreateInstruction,
    this.onSavePlan,
  });

  final PlanningWizardState initial;
  final ValueChanged<PlanningWizardState> onChanged;
  final VoidCallback? onConfirmCreateInstruction;
  final VoidCallback? onSavePlan;

  @override
  State<PlanningWizardPanel> createState() => _PlanningWizardPanelState();
}

class _PlanningWizardPanelState extends State<PlanningWizardPanel> {
  static const _visibleOptionCount = 8;
  static const _stepTitles = [
    '만들 결과물',
    '분야·주제',
    '대상 고객',
    '고객 문제',
    '원하는 결과',
    '제공 형태',
    '규모·기간·예산',
    '기획 문장',
    '최종 확인',
  ];

  final _composer = const PlanningSentenceComposer();
  final _recentStore = PlanningRecentStore();

  late PlanningWizardState _state;
  Timer? _notifyTimer;
  bool _sentencesEditing = false;
  final _topicCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();
  final _customCtrl = TextEditingController();

  final _expandedSteps = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _state = widget.initial.deepCopy();
    _syncSentenceControllers();
  }

  @override
  void didUpdateWidget(covariant PlanningWizardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      _state = widget.initial.deepCopy();
      _syncSentenceControllers();
    }
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _topicCtrl.dispose();
    _problemCtrl.dispose();
    _targetCtrl.dispose();
    _outcomeCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _syncSentenceControllers() {
    _topicCtrl.text = _state.topic;
    _problemCtrl.text = _state.customerProblem;
    _targetCtrl.text = _state.targetCustomer;
    _outcomeCtrl.text = _state.desiredOutcome;
  }

  void _emit({bool immediate = false}) {
    if (immediate) {
      _notifyTimer?.cancel();
      widget.onChanged(_state);
      return;
    }
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 400), () {
      widget.onChanged(_state);
    });
  }

  void _setState(PlanningWizardState next, {bool immediate = false}) {
    setState(() => _state = next);
    _emit(immediate: immediate);
  }

  int get _totalSteps => 9;
  int get _currentDisplayStep => _state.step.clamp(0, 8);
  int get _remainingSteps =>
      (_totalSteps - 1 - _currentDisplayStep).clamp(0, 8);

  Set<String> get _domainSet => _state.domains.toSet();
  Set<String> get _audienceSet => _state.audiences.toSet();

  List<String> _recommendedIds(String step) {
    switch (step) {
      case PlanningChoiceSteps.problems:
        return suggestProblems(
          deliverable: _state.deliverable,
          domains: _domainSet,
          audiences: _audienceSet,
        );
      case PlanningChoiceSteps.outcomes:
        return suggestOutcomes(
          deliverable: _state.deliverable,
          domains: _domainSet,
        );
      case PlanningChoiceSteps.formats:
        return suggestFormats(
          deliverable: _state.deliverable,
          domains: _domainSet,
        );
      case PlanningChoiceSteps.audiences:
        return suggestAudiences(domains: _domainSet);
      default:
        return const [];
    }
  }

  void _applySample(String sampleId) {
    final seed = cloneSampleSeed(sampleId);
    final completed = _composer.applyAutoComplete(seed);
    _sentencesEditing = false;
    _setState(completed.copyWith(step: 0), immediate: true);
    _syncSentenceControllers();
  }

  Future<void> _autoCompleteAll() async {
    if (!_state.canAutoComplete) {
      _snack('결과물과 분야를 먼저 선택하세요.');
      return;
    }
    if (_state.sentencesManuallyEdited) {
      final ok = await _confirmRegenerateSentences();
      if (!ok) return;
    }
    final next = _composer.applyAutoComplete(_state);
    _sentencesEditing = false;
    _setState(next, immediate: true);
    _syncSentenceControllers();
    _snack('추천 선택과 문장을 자동으로 채웠습니다.');
  }

  Future<void> _applyDontKnow() async {
    if (_state.sentencesManuallyEdited && _state.step >= 7) {
      final ok = await _confirmRegenerateSentences();
      if (!ok) return;
    }
    var next = applyRecommendations(_state);
    if (_state.step >= 7 && !next.sentencesManuallyEdited) {
      next = _composer.regenerateSentences(next, force: true);
    }
    _setState(next, immediate: true);
    _syncSentenceControllers();
    _snack('안전한 추천값을 적용했습니다.');
  }

  Future<bool> _confirmRegenerateSentences() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문장 다시 만들기'),
        content: const Text('직접 수정한 문장이 있습니다. 추천 규칙으로 문장을 다시 만들까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('다시 만들기'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _onDeliverableChanged(String id) {
    final prev = _state.deliverable;
    if (prev == id) return;

    final cleared = <String>[];
    var next = _state.copyWith(
      deliverable: id,
      clearScale: id != PlanningDeliverables.ebook,
    );

    final validFormats = optionsFor(
      PlanningChoiceSteps.formats,
      deliverable: id,
      domains: _domainSet,
      audiences: _audienceSet,
    ).map((o) => o.id).toSet();
    if (next.formats.any((f) => !validFormats.contains(f))) {
      next = next.copyWith(
        formats: next.formats.where(validFormats.contains).toList(),
      );
      cleared.add('제공 형태');
    }

    final validProblems = optionsFor(
      PlanningChoiceSteps.problems,
      deliverable: id,
      domains: _domainSet,
      audiences: _audienceSet,
    ).map((o) => o.id).toSet();
    if (next.problems.any((p) => !validProblems.contains(p))) {
      next = next.copyWith(
        problems: next.problems.where(validProblems.contains).toList(),
      );
      cleared.add('고객 문제');
    }

    if (id != PlanningDeliverables.ebook && _state.scale != null) {
      cleared.add('규모');
    }

    if (id == PlanningDeliverables.custom) {
      _customCtrl.text = _state.customTexts['deliverables'] ?? '';
    }

    _setState(next, immediate: true);

    if (cleared.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('결과물 변경으로 ${cleared.join(', ')} 선택이 초기화되었습니다.')),
      );
    }
  }

  void _toggleMulti(String step, String id, List<String> current) {
    final next = List<String>.from(current);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }

    PlanningWizardState updated;
    switch (step) {
      case PlanningChoiceSteps.domains:
        updated = _state.copyWith(domains: next);
        _recentStore.recordDomainSelections(next);
        break;
      case PlanningChoiceSteps.audiences:
        updated = _state.copyWith(audiences: next);
        _recentStore.recordAudienceSelections(next);
        break;
      case PlanningChoiceSteps.problems:
        updated = _state.copyWith(problems: next);
        break;
      case PlanningChoiceSteps.outcomes:
        updated = _state.copyWith(outcomes: next);
        break;
      case PlanningChoiceSteps.formats:
        updated = _state.copyWith(formats: next);
        break;
      default:
        return;
    }
    _setState(updated);
  }

  void _selectSingle(String field, String id) {
    PlanningWizardState updated;
    switch (field) {
      case PlanningChoiceSteps.scales:
        updated = _state.copyWith(scale: id);
        break;
      case PlanningChoiceSteps.durations:
        updated = _state.copyWith(duration: id);
        break;
      case PlanningChoiceSteps.budgets:
        updated = _state.copyWith(budget: id);
        break;
      case PlanningChoiceSteps.salesModes:
        updated = _state.copyWith(salesMode: id);
        break;
      default:
        return;
    }
    _setState(updated);
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _state.deliverable != null && _state.deliverable!.isNotEmpty;
      case 1:
        return _state.domains.isNotEmpty ||
            (_state.deliverable == PlanningDeliverables.custom &&
                (_state.customTexts['domains']?.trim().isNotEmpty ?? false));
      case 2:
        return _state.audiences.isNotEmpty;
      case 3:
        return _state.problems.isNotEmpty;
      case 4:
        return _state.outcomes.isNotEmpty;
      case 5:
        final formats = optionsFor(
          PlanningChoiceSteps.formats,
          deliverable: _state.deliverable,
          domains: _domainSet,
          audiences: _audienceSet,
        );
        return formats.isEmpty || _state.formats.isNotEmpty;
      case 6:
        return true;
      case 7:
        return _state.topic.trim().isNotEmpty &&
            _state.customerProblem.trim().isNotEmpty &&
            _state.targetCustomer.trim().isNotEmpty &&
            _state.desiredOutcome.trim().isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _goNext() async {
    if (_state.step == 7) {
      if (_state.sentencesManuallyEdited) {
        _applySentenceEdits();
      } else {
        final next = _composer.applyAutoComplete(_state);
        _setState(next, immediate: true);
        _syncSentenceControllers();
      }
    }

    if (!_canProceedFromStep(_state.step)) {
      _snack('이 단계에서 필요한 선택을 완료하세요.');
      return;
    }

    if (_state.step < 8) {
      var nextStep = _state.step + 1;
      if (nextStep == 5) {
        final formats = optionsFor(
          PlanningChoiceSteps.formats,
          deliverable: _state.deliverable,
          domains: _domainSet,
          audiences: _audienceSet,
        );
        if (formats.isEmpty) nextStep = 6;
      }
      _setState(_state.copyWith(step: nextStep), immediate: true);
    }
  }

  void _goPrev() {
    if (_state.step <= 0) return;
    var prevStep = _state.step - 1;
    if (prevStep == 5) {
      final formats = optionsFor(
        PlanningChoiceSteps.formats,
        deliverable: _state.deliverable,
        domains: _domainSet,
        audiences: _audienceSet,
      );
      if (formats.isEmpty) prevStep = 4;
    }
    _setState(_state.copyWith(step: prevStep), immediate: true);
  }

  void _applySentenceEdits() {
    _setState(
      _state.copyWith(
        topic: _topicCtrl.text,
        customerProblem: _problemCtrl.text,
        targetCustomer: _targetCtrl.text,
        desiredOutcome: _outcomeCtrl.text,
        sentencesManuallyEdited: true,
      ),
      immediate: true,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '빠른 선택으로 만들기',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildSampleChips(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _autoCompleteAll,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('추천 기획으로 자동 완성'),
                    ),
                    TextButton(
                      onPressed: _applyDontKnow,
                      child: const Text('잘 모르겠음'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildProgress(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStepContent(),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _state.step == 8
                ? _buildConfirmButtons()
                : _buildNavButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final sample in planningSamples)
          ActionChip(
            avatar: const Icon(Icons.lightbulb_outline, size: 16),
            label: Text(sample.title, softWrap: true),
            onPressed: () => _applySample(sample.id),
          ),
      ],
    );
  }

  Widget _buildProgress() {
    final step = _currentDisplayStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${step + 1} / $_totalSteps · ${_stepTitles[step]}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ControlColors.textPrimary,
                ),
              ),
            ),
            Text(
              '남은 $_remainingSteps단계',
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (step + 1) / _totalSteps,
            minHeight: 6,
            backgroundColor: ControlColors.slate,
            color: ControlColors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_state.step) {
      case 0:
        return _buildChoiceStep(
          step: PlanningChoiceSteps.deliverables,
          title: '어떤 결과물을 만들고 싶으신가요?',
          multi: false,
          selectedIds: _state.deliverable == null ? [] : [_state.deliverable!],
          onSelect: (id) => _onDeliverableChanged(id),
        );
      case 1:
        return _buildChoiceStep(
          step: PlanningChoiceSteps.domains,
          title: '어떤 분야·주제인가요? (복수 선택 가능)',
          multi: true,
          selectedIds: _state.domains,
          onSelect: (id) =>
              _toggleMulti(PlanningChoiceSteps.domains, id, _state.domains),
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChoiceStep(
              step: PlanningChoiceSteps.audiences,
              title: '누구를 위한 것인가요? (복수 선택 가능)',
              multi: true,
              selectedIds: _state.audiences,
              onSelect: (id) => _toggleMulti(
                PlanningChoiceSteps.audiences,
                id,
                _state.audiences,
              ),
            ),
            if (_state.audiences.contains('age_custom')) ...[
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('age_${_state.customTexts['age_custom']}'),
                initialValue: _state.customTexts['age_custom'] ?? '',
                decoration: const InputDecoration(
                  labelText: '연령대 직접 입력',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  final texts = Map<String, String>.from(_state.customTexts);
                  texts['age_custom'] = v;
                  _setState(_state.copyWith(customTexts: texts));
                },
              ),
            ],
            if (exceedsRecommendedAudienceCount(_state.audiences.length))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  audienceCountHint(_state.audiences.length),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.accentWarm,
                  ),
                ),
              ),
          ],
        );
      case 3:
        return _buildChoiceStep(
          step: PlanningChoiceSteps.problems,
          title: '어떤 문제를 해결하나요?',
          multi: true,
          selectedIds: _state.problems,
          onSelect: (id) =>
              _toggleMulti(PlanningChoiceSteps.problems, id, _state.problems),
        );
      case 4:
        return _buildChoiceStep(
          step: PlanningChoiceSteps.outcomes,
          title: '어떤 결과를 원하시나요?',
          multi: true,
          selectedIds: _state.outcomes,
          onSelect: (id) =>
              _toggleMulti(PlanningChoiceSteps.outcomes, id, _state.outcomes),
        );
      case 5:
        return _buildChoiceStep(
          step: PlanningChoiceSteps.formats,
          title: '어떤 형태로 제공할까요?',
          multi: true,
          selectedIds: _state.formats,
          onSelect: (id) =>
              _toggleMulti(PlanningChoiceSteps.formats, id, _state.formats),
        );
      case 6:
        return _buildOperationalStep();
      case 7:
        return _buildSentenceStep();
      case 8:
        return _buildConfirmationSummary();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChoiceStep({
    required String step,
    required String title,
    required bool multi,
    required List<String> selectedIds,
    required ValueChanged<String> onSelect,
  }) {
    final recommended = _recommendedIds(step).toSet();
    final options = optionsFor(
      step,
      deliverable: _state.deliverable,
      domains: _domainSet,
      audiences: _audienceSet,
      recommendedIds: recommended,
    );

    final showMore = _expandedSteps[step] ?? false;
    final visible = showMore
        ? options
        : options.take(_visibleOptionCount).toList();
    final hasMore = options.length > _visibleOptionCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (_state.deliverable == PlanningDeliverables.custom &&
            step == PlanningChoiceSteps.deliverables) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customCtrl,
            decoration: const InputDecoration(
              labelText: '결과물 직접 입력',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              final texts = Map<String, String>.from(_state.customTexts);
              texts['deliverables'] = v;
              _setState(_state.copyWith(customTexts: texts));
            },
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in visible)
              _ChoiceCard(
                option: opt,
                selected: selectedIds.contains(opt.id),
                multi: multi,
                reason: recommendationReason(
                  step: step,
                  optionId: opt.id,
                  deliverable: _state.deliverable,
                  domains: _domainSet,
                ),
                onTap: () => onSelect(opt.id),
              ),
          ],
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _expandedSteps[step] = !showMore;
                });
              },
              icon: Icon(showMore ? Icons.expand_less : Icons.expand_more),
              label: Text(
                showMore
                    ? '접기'
                    : '더 보기 (${options.length - _visibleOptionCount}개)',
              ),
            ),
          ),
        if (selectedIds.contains('custom')) ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('custom_${step}_${_state.customTexts[step]}'),
            initialValue: _state.customTexts[step] ?? '',
            decoration: InputDecoration(
              labelText: '${labelForChoice(step, 'custom')} 내용',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              final texts = Map<String, String>.from(_state.customTexts);
              texts[step] = v;
              _setState(_state.copyWith(customTexts: texts));
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOperationalStep() {
    final isEbook = _state.deliverable == PlanningDeliverables.ebook;

    Widget section(String step, String title, String? selected) {
      final options = optionsFor(
        step,
        deliverable: _state.deliverable,
        domains: _domainSet,
        audiences: _audienceSet,
      );
      if (options.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final opt in options)
                  FilterChip(
                    label: Text(opt.label, softWrap: true),
                    selected: selected == opt.id,
                    onSelected: (_) => _selectSingle(step, opt.id),
                    avatar: opt.recommended
                        ? const Icon(
                            Icons.star,
                            size: 14,
                            color: ControlColors.teal,
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('규모·기간·예산·판매 방식', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        if (isEbook)
          section(PlanningChoiceSteps.scales, '전자책 규모', _state.scale),
        section(PlanningChoiceSteps.durations, '예상 기간', _state.duration),
        section(PlanningChoiceSteps.budgets, '예산', _state.budget),
        section(PlanningChoiceSteps.salesModes, '판매·배포 방식', _state.salesMode),
        if (_state.followUpDeliverables.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '추천 후속 결과물: ${_state.followUpDeliverables.map((d) => labelForChoice(PlanningChoiceSteps.deliverables, d)).join(', ')}',
            style: const TextStyle(
              fontSize: 12,
              color: ControlColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSentenceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '기획 문장 확인',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () {
                if (!_sentencesEditing) {
                  final next = _composer.applyAutoComplete(_state);
                  _syncSentenceControllers();
                  setState(() {
                    _state = next;
                    _sentencesEditing = true;
                  });
                  _emit();
                } else {
                  setState(() => _sentencesEditing = false);
                }
              },
              child: Text(_sentencesEditing ? '읽기 전용' : '직접 수정'),
            ),
            TextButton(
              onPressed: () async {
                if (_state.sentencesManuallyEdited) {
                  final ok = await _confirmRegenerateSentences();
                  if (!ok) return;
                }
                final next = _composer.regenerateSentences(_state, force: true);
                _sentencesEditing = false;
                _setState(next, immediate: true);
                _syncSentenceControllers();
              },
              child: const Text('문장 재생성'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_sentencesEditing) ...[
          _sentenceField('사업 주제', _topicCtrl),
          _sentenceField('고객 문제', _problemCtrl, maxLines: 3),
          _sentenceField('대상 고객', _targetCtrl, maxLines: 2),
          _sentenceField('원하는 결과', _outcomeCtrl, maxLines: 2),
        ] else ...[
          _readOnlyBlock('사업 주제', _state.topic),
          _readOnlyBlock('고객 문제', _state.customerProblem),
          _readOnlyBlock('대상 고객', _state.targetCustomer),
          _readOnlyBlock('원하는 결과', _state.desiredOutcome),
        ],
      ],
    );
  }

  Widget _sentenceField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _applySentenceEdits(),
      ),
    );
  }

  Widget _readOnlyBlock(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ControlColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '(아직 생성되지 않음)' : value,
            softWrap: true,
            style: const TextStyle(color: ControlColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationSummary() {
    final input = _composer.toBusinessPlanInput(_state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('기획 요약', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        _summaryRow('주제', input.topic),
        _summaryRow('고객 문제', input.customerProblem),
        _summaryRow('대상 고객', input.targetCustomer),
        _summaryRow('원하는 결과', input.desiredOutcome),
        _summaryRow(
          '결과물',
          input.deliverableTypes.map(DeliverableType.labelKo).join(', '),
        ),
        if (input.expectedScale.isNotEmpty)
          _summaryRow('규모', input.expectedScale),
        if (input.expectedDuration.isNotEmpty)
          _summaryRow('기간', input.expectedDuration),
        if (input.budgetEstimate.isNotEmpty)
          _summaryRow('예산', input.budgetEstimate),
        if (input.revenueModel.isNotEmpty)
          _summaryRow('판매 방식', input.revenueModel),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: ControlColors.textPrimary,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value.trim().isEmpty ? '—' : value),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _state.step > 0 ? _goPrev : null,
            child: const Text('이전'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _goNext,
            child: Text(_state.step == 7 ? '최종 확인' : '다음'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () => _setState(_state.copyWith(step: 0), immediate: true),
          child: const Text('선택 내용 수정'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: widget.onConfirmCreateInstruction,
          icon: const Icon(Icons.description_outlined),
          label: const Text('이 기획으로 작업지시서 생성'),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.option,
    required this.selected,
    required this.multi,
    required this.onTap,
    this.reason,
  });

  final ChoiceOption option;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ControlColors.tealSoft : ControlColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ControlColors.teal : ControlColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  multi
                      ? (selected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                      : (selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off),
                  size: 18,
                  color: selected
                      ? ControlColors.teal
                      : ControlColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    option.label,
                    softWrap: true,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: ControlColors.textPrimary,
                    ),
                  ),
                ),
                if (option.recommended)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ControlColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '추천',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ControlColors.teal,
                      ),
                    ),
                  ),
              ],
            ),
            if (option.hint != null && option.hint!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                option.hint!,
                style: const TextStyle(
                  fontSize: 11,
                  color: ControlColors.textMuted,
                ),
              ),
            ],
            if (reason != null && reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                reason!,
                style: const TextStyle(
                  fontSize: 11,
                  color: ControlColors.sandBeige,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
