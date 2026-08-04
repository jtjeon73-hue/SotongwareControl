import 'dart:async';

import 'package:flutter/material.dart';

import '../data/artifact_question_catalog.dart';
import '../models/artifact_type.dart';
import '../models/business_planning.dart';
import '../models/planning_summary.dart';
import '../models/planning_wizard_state.dart';
import '../services/planning_sentence_composer.dart';
import '../theme/control_theme.dart';

/// artifact-first 선택형 기획 마법사 (0–4 단계).
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
  static const _stepTitles = ['만들 결과물', '콘텐츠 유형', '기획 질문', '기획 문장', '최종 확인'];

  static const _quickCommonIds = {
    'customerProblem',
    'targetCustomer',
    'desiredOutcome',
  };

  static const _advancedOnlyCommonIds = {
    'materialsExperience',
    'schedule',
    'budget',
    'salesDeploy',
  };

  static const _requiredQuestionIds = {
    'customerProblem',
    'targetCustomer',
    'desiredOutcome',
  };

  final _composer = const PlanningSentenceComposer();

  late PlanningWizardState _state;
  Timer? _notifyTimer;
  bool _sentencesEditing = false;
  final _topicCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();

  final _expandedQuestions = <String, bool>{};
  final _customCtrls = <String, TextEditingController>{};

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
    for (final c in _customCtrls.values) {
      c.dispose();
    }
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

  bool get _needsSubtype =>
      ArtifactType.normalize(_state.artifactType ?? '') ==
          ArtifactType.contents &&
      _state.canProceedPastArtifact;

  int get _maxStep => 4;

  int get _progressStep {
    var display = _state.step;
    if (!_needsSubtype && display > 1) {
      display -= 1;
    }
    return display.clamp(0, _needsSubtype ? 4 : 3);
  }

  int get _progressTotal => _needsSubtype ? 5 : 4;

  int get _remainingSteps =>
      (_progressTotal - 1 - _progressStep).clamp(0, _progressTotal);

  String get _stepTitle {
    final step = _state.step.clamp(0, _maxStep);
    if (step >= 0 && step < _stepTitles.length) {
      return _stepTitles[step];
    }
    return _stepTitles.last;
  }

  List<ArtifactQuestion> get _activeQuestions {
    final artifact = _state.effectiveArtifactType;
    if (artifact == null || artifact == ArtifactType.undecided) {
      return commonQuestions()
          .where((q) => _quickCommonIds.contains(q.id))
          .toList();
    }

    final all = questionsFor(
      artifact: artifact,
      contentSubtype: _state.contentSubtype,
    );

    if (_state.mode == 'advanced') return all;

    return all.where((q) {
      if (_quickCommonIds.contains(q.id)) return true;
      if (_advancedOnlyCommonIds.contains(q.id)) return false;
      return q.options.any((o) => o.recommended);
    }).toList();
  }

  void _onArtifactChanged(String id) {
    final normalized = ArtifactType.normalize(id);
    final prev = _state.artifactType;
    if (prev == normalized) return;

    var next = _state.copyWith(
      artifactType: normalized,
      clearRecommendedArtifact: normalized != ArtifactType.undecided,
      clearContentSubtype: normalized != ArtifactType.contents,
    );

    if (normalized != ArtifactType.undecided &&
        normalized != ArtifactType.contents) {
      next = _applyDefaultAnswers(next, normalized);
    }

    _setState(next, immediate: true);
  }

  void _onSubtypeChanged(String id) {
    final normalized = ContentSubtype.normalize(id);
    if (_state.contentSubtype == normalized) return;

    var next = _state.copyWith(contentSubtype: normalized);
    final artifact = _state.effectiveArtifactType;
    if (artifact != null && normalized != ContentSubtype.undecided) {
      next = _applyDefaultAnswers(next, artifact);
    }
    _setState(next, immediate: true);
  }

  PlanningWizardState _applyDefaultAnswers(
    PlanningWizardState state,
    String artifact,
  ) {
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

  void _runRecommend() {
    final domains = _state.domains;
    final problems = _state.artifactAnswers['customerProblem'] ?? const [];
    final recommended = recommendArtifact(domains: domains, problems: problems);
    _setState(
      _state.copyWith(recommendedArtifact: recommended),
      immediate: true,
    );
    if (recommended == ArtifactType.undecided) {
      _snack('추천할 만한 유형을 찾지 못했습니다. 직접 선택해 주세요.');
    }
  }

  void _confirmRecommended(String artifactId) {
    final normalized = ArtifactType.normalize(artifactId);
    if (normalized == ArtifactType.undecided) return;

    var next = _state.copyWith(
      artifactType: normalized,
      recommendedArtifact: normalized,
      clearContentSubtype: normalized != ArtifactType.contents,
    );
    next = _applyDefaultAnswers(next, normalized);
    _setState(next, immediate: true);
  }

  void _toggleAnswer(ArtifactQuestion question, String optionId) {
    final answers = Map<String, List<String>>.from(_state.artifactAnswers);
    final current = List<String>.from(answers[question.id] ?? []);

    if (question.multi) {
      if (current.contains(optionId)) {
        current.remove(optionId);
      } else {
        current.add(optionId);
      }
    } else {
      current
        ..clear()
        ..add(optionId);
    }

    answers[question.id] = current;
    _setState(_state.copyWith(artifactAnswers: answers));
  }

  void _updateCustomText(String questionId, String value) {
    final texts = Map<String, String>.from(_state.customTexts);
    texts[questionId] = value;
    _setState(_state.copyWith(customTexts: texts));
  }

  TextEditingController _customController(String questionId) {
    return _customCtrls.putIfAbsent(
      questionId,
      () => TextEditingController(text: _state.customTexts[questionId] ?? ''),
    );
  }

  Future<void> _applyDefaults() async {
    if (_state.sentencesManuallyEdited && _state.step >= 3) {
      final ok = await _confirmRegenerateSentences();
      if (!ok) return;
    }

    var next = _composer.applyAutoComplete(_state);
    if (_state.step >= 3 && !next.sentencesManuallyEdited) {
      next = _composer.regenerateSentences(next, force: true);
    }
    _sentencesEditing = false;
    _setState(next, immediate: true);
    _syncSentenceControllers();
    _snack('추천 선택과 문장을 자동으로 채웠습니다.');
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

  bool _questionComplete(ArtifactQuestion question) {
    final selected = _state.artifactAnswers[question.id] ?? const [];
    if (!_requiredQuestionIds.contains(question.id)) return true;
    if (selected.isEmpty) return false;
    if (selected.contains('custom')) {
      return _state.customTexts[question.id]?.trim().isNotEmpty ?? false;
    }
    return true;
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        if (_state.artifactType == null) return false;
        if (_state.artifactType == ArtifactType.undecided) {
          return _state.canProceedPastArtifact;
        }
        return true;
      case 1:
        if (!_needsSubtype) return true;
        final sub = ContentSubtype.normalize(_state.contentSubtype ?? '');
        return sub.isNotEmpty && sub != ContentSubtype.undecided;
      case 2:
        return _activeQuestions.every(_questionComplete);
      case 3:
        return _state.topic.trim().isNotEmpty &&
            _state.customerProblem.trim().isNotEmpty &&
            _state.targetCustomer.trim().isNotEmpty &&
            _state.desiredOutcome.trim().isNotEmpty;
      default:
        return true;
    }
  }

  int _nextStep(int current) {
    var next = current + 1;
    if (next == 1 && !_needsSubtype) next = 2;
    return next;
  }

  int _prevStep(int current) {
    var prev = current - 1;
    if (prev == 1 && !_needsSubtype) prev = 0;
    return prev;
  }

  Future<void> _goNext() async {
    if (_state.step == 3) {
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

    if (_state.step < _maxStep) {
      _setState(_state.copyWith(step: _nextStep(_state.step)), immediate: true);
    }
  }

  void _goPrev() {
    if (_state.step <= 0) return;
    _setState(_state.copyWith(step: _prevStep(_state.step)), immediate: true);
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _state.canProceedPastArtifact
                          ? _applyDefaults
                          : null,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('추천 기획으로 자동 완성'),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'quick', label: Text('빠른')),
                        ButtonSegment(value: 'advanced', label: Text('상세')),
                      ],
                      selected: {_state.mode},
                      onSelectionChanged: (s) {
                        _setState(
                          _state.copyWith(mode: s.first),
                          immediate: true,
                        );
                      },
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
            child: _state.step == _maxStep
                ? _buildConfirmButtons()
                : _buildNavButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_progressStep + 1} / $_progressTotal · $_stepTitle',
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
            value: (_progressStep + 1) / _progressTotal,
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
        return _buildArtifactStep();
      case 1:
        return _buildSubtypeStep();
      case 2:
        return _buildQuestionsStep();
      case 3:
        return _buildSentenceStep();
      case 4:
        return _buildConfirmationSummary();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildArtifactStep() {
    final options = artifactTypeOptions();
    final selected = _state.artifactType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떤 결과물을 만들고 싶으신가요?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              _ChoiceCard(
                label: opt.label,
                hint: opt.recommended ? '추천' : null,
                selected: selected == opt.id,
                multi: false,
                onTap: () => _onArtifactChanged(opt.id),
              ),
          ],
        ),
        if (selected == ArtifactType.undecided) ...[
          const SizedBox(height: 16),
          Text(
            '아래 질문에 답하거나 바로 추천을 받은 뒤, 실제 유형을 하나 선택해야 다음으로 진행할 수 있습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ControlColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._buildUndecidedMiniQuestions(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _runRecommend,
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: const Text('답변 기반 유형 추천'),
          ),
          if (_state.recommendedArtifact != null &&
              _state.recommendedArtifact != ArtifactType.undecided) ...[
            const SizedBox(height: 12),
            Text(
              '추천: ${ArtifactType.labelKo(_state.recommendedArtifact!)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ControlColors.teal,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text('최종 유형 선택', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in options.where(
                (o) => o.id != ArtifactType.undecided,
              ))
                FilterChip(
                  label: Text(opt.label),
                  selected: _state.effectiveArtifactType == opt.id,
                  onSelected: (_) => _confirmRecommended(opt.id),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _buildUndecidedMiniQuestions() {
    final mini = commonQuestions()
        .where((q) => _quickCommonIds.contains(q.id))
        .toList();

    return [for (final q in mini) _buildQuestionBlock(q, compact: true)];
  }

  Widget _buildSubtypeStep() {
    if (!_needsSubtype) {
      return Text(
        '콘텐츠 유형 선택이 필요하지 않습니다.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final options = contentSubtypeOptions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('어떤 콘텐츠인가요?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              _ChoiceCard(
                label: opt.label,
                selected: _state.contentSubtype == opt.id,
                multi: false,
                onTap: () => _onSubtypeChanged(opt.id),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionsStep() {
    final questions = _activeQuestions;
    final advancedHidden = _state.mode == 'quick';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '기획 질문',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (advancedHidden)
              TextButton(
                onPressed: () {
                  _setState(_state.copyWith(mode: 'advanced'), immediate: true);
                },
                child: const Text('상세 질문 보기'),
              ),
          ],
        ),
        if (advancedHidden)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '빠른 모드: 핵심 질문과 추천 항목만 표시합니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ControlColors.textMuted),
            ),
          ),
        const SizedBox(height: 8),
        for (final q in questions) _buildQuestionBlock(q),
      ],
    );
  }

  Widget _buildQuestionBlock(
    ArtifactQuestion question, {
    bool compact = false,
  }) {
    final selected = _state.artifactAnswers[question.id] ?? const [];
    final showMore = _expandedQuestions[question.id] ?? false;
    const visibleCount = 8;
    final options = showMore
        ? question.options
        : question.options.take(visibleCount).toList();
    final hasMore = question.options.length > visibleCount;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 13 : 14,
              color: ControlColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in options)
                _ChoiceCard(
                  label: opt.label,
                  selected: selected.contains(opt.id),
                  multi: question.multi,
                  recommended: opt.recommended,
                  onTap: () => _toggleAnswer(question, opt.id),
                ),
            ],
          ),
          if (hasMore)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _expandedQuestions[question.id] = !showMore;
                });
              },
              icon: Icon(showMore ? Icons.expand_less : Icons.expand_more),
              label: Text(
                showMore
                    ? '접기'
                    : '더 보기 (${question.options.length - visibleCount}개)',
              ),
            ),
          if (selected.contains('custom') && question.allowCustom) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _customController(question.id),
              decoration: InputDecoration(
                labelText: '${question.label} 직접 입력',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => _updateCustomText(question.id, v),
            ),
          ],
        ],
      ),
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
    final summary = PlanningSummary.fromWizard(_state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('기획 요약', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        _summaryRow('제작 형태', summary.artifactLabel),
        _summaryRow('주 트랙', summary.primaryTrack),
        _summaryRow('주요 결과물', summary.mainDeliverables),
        _summaryRow('대상 사용자', summary.targetUser),
        _summaryRow('핵심 목적', summary.purpose),
        _summaryRow('수익화 방향', summary.monetization),
        _summaryRow('소통24워크 전달 준비 상태', summary.transferReadyLabel),
        if (_state.contentSubtype != null &&
            _state.effectiveArtifactType == ArtifactType.contents) ...[
          const SizedBox(height: 4),
          _summaryRow(
            '콘텐츠 유형',
            ContentSubtype.labelKo(
              ContentSubtype.normalize(_state.contentSubtype!),
            ),
          ),
        ],
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
            child: Text(_state.step == 3 ? '기획안 완성' : '다음'),
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
          onPressed: widget.onSavePlan,
          icon: const Icon(Icons.save_outlined),
          label: const Text('기획안 저장'),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.multi,
    required this.onTap,
    this.hint,
    this.recommended = false,
  });

  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;
  final String? hint;
  final bool recommended;

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
        child: Row(
          children: [
            Icon(
              multi
                  ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                  : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
              size: 18,
              color: selected ? ControlColors.teal : ControlColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: ControlColors.textPrimary,
                ),
              ),
            ),
            if (recommended || hint != null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ControlColors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hint ?? '추천',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ControlColors.teal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
