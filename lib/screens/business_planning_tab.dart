import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/business_planning.dart';
import '../services/business_planning_service.dart';
import '../services/business_planning_store.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';

/// AI 사업분석 내 「사업 기획·작업지시」 탭 (로컬 규칙 기반, 외부 AI 없음).
class BusinessPlanningTab extends StatefulWidget {
  const BusinessPlanningTab({super.key});

  @override
  State<BusinessPlanningTab> createState() => _BusinessPlanningTabState();
}

class _BusinessPlanningTabState extends State<BusinessPlanningTab> {
  final _service = BusinessPlanningService();
  final _store = BusinessPlanningStore();
  final _scrollController = ScrollController();
  final _resultsTitleKey = GlobalKey();

  final _topicCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _materialsCtrl = TextEditingController();
  final _revenueCtrl = TextEditingController();
  final _monthlyGoalCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<String> _deliverableTypes = const [DeliverableType.undecided];
  List<BusinessPlanDocument> _plans = const [];
  PlanningAnalysisResult? _analysis;
  WorkInstruction? _instruction;
  String? _activePlanId;
  bool _loading = true;
  bool _analyzing = false;

  /// 분석 후 기본은 요약(접힘). true면 전체 입력 양식.
  bool _inputExpanded = true;
  Timer? _draftTimer;

  static const _deliverableOptions = [
    ...DeliverableType.allSelectable,
    DeliverableType.undecided,
  ];

  @override
  void initState() {
    super.initState();
    _bindDraftListeners();
    _loadInitial();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _scrollController.dispose();
    for (final c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _allControllers => [
    _topicCtrl,
    _problemCtrl,
    _targetCtrl,
    _outcomeCtrl,
    _skillsCtrl,
    _materialsCtrl,
    _revenueCtrl,
    _monthlyGoalCtrl,
    _durationCtrl,
    _notesCtrl,
  ];

  void _bindDraftListeners() {
    void scheduleDraft() {
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 800), _persistDraft);
    }

    for (final c in _allControllers) {
      c.addListener(scheduleDraft);
    }
  }

  Future<void> _loadInitial() async {
    try {
      final results = await Future.wait([
        _store.loadPlans(),
        _store.loadDraftInput(),
      ]);
      final plans = results[0] as List<BusinessPlanDocument>;
      final draft = results[1] as BusinessPlanInput?;
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
        if (draft != null) _applyInput(draft);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  BusinessPlanInput get _currentInput => BusinessPlanInput(
    topic: _topicCtrl.text,
    customerProblem: _problemCtrl.text,
    targetCustomer: _targetCtrl.text,
    desiredOutcome: _outcomeCtrl.text,
    experienceSkills: _skillsCtrl.text,
    existingMaterials: _materialsCtrl.text,
    revenueModel: _revenueCtrl.text,
    monthlyGoal: _monthlyGoalCtrl.text,
    expectedDuration: _durationCtrl.text,
    deliverableTypes: _deliverableTypes,
    notes: _notesCtrl.text,
  );

  void _applyInput(BusinessPlanInput input) {
    _topicCtrl.text = input.topic;
    _problemCtrl.text = input.customerProblem;
    _targetCtrl.text = input.targetCustomer;
    _outcomeCtrl.text = input.desiredOutcome;
    _skillsCtrl.text = input.experienceSkills;
    _materialsCtrl.text = input.existingMaterials;
    _revenueCtrl.text = input.revenueModel;
    _monthlyGoalCtrl.text = input.monthlyGoal;
    _durationCtrl.text = input.expectedDuration;
    _notesCtrl.text = input.notes;
    _deliverableTypes = input.deliverableTypes.isEmpty
        ? const [DeliverableType.undecided]
        : List<String>.from(input.deliverableTypes);
  }

  Future<void> _persistDraft() async {
    await _store.saveDraftInput(_currentInput);
  }

  void _toggleDeliverable(String type) {
    setState(() {
      if (type == DeliverableType.undecided) {
        _deliverableTypes = const [DeliverableType.undecided];
      } else {
        final next = _deliverableTypes
            .where((t) => t != DeliverableType.undecided)
            .toSet();
        if (next.contains(type)) {
          next.remove(type);
        } else {
          next.add(type);
        }
        _deliverableTypes = next.isEmpty
            ? const [DeliverableType.undecided]
            : next.toList();
      }
    });
    _persistDraft();
  }

  String _statusAfterAnalysis(String verdict) {
    switch (verdict) {
      case PlanningVerdict.readyToBuild:
        return PlanningStatus.analyzing;
      case PlanningVerdict.validateFirst:
        return PlanningStatus.marketValidate;
      case PlanningVerdict.hold:
      case PlanningVerdict.needsRefine:
        return PlanningStatus.needsRefine;
      default:
        return PlanningStatus.analyzing;
    }
  }

  BusinessPlanDocument _buildDocument({
    required String id,
    required String createdAt,
    required String updatedAt,
    required String status,
    PlanningAnalysisResult? analysis,
    WorkInstruction? instruction,
  }) {
    return BusinessPlanDocument(
      id: id,
      input: _currentInput,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      analysis: analysis,
      instruction: instruction,
    );
  }

  Future<void> _refreshPlans() async {
    _plans = await _store.loadPlans();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAnalyze() async {
    final input = _currentInput;
    if (!input.hasRequiredFields) {
      _snack('주제·고객 문제·대상 고객·원하는 결과는 필수입니다.');
      return;
    }
    // 포커스 유지 시 Flutter가 입력 필드로 ensureVisible 하며 중간으로 점프한다.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _analyzing = true);
    try {
      final result = _service.analyze(input);
      final now = DateTime.now().toUtc().toIso8601String();
      final id = _activePlanId ?? BusinessPlanningStore.newPlanId();
      final createdAt = _activePlanId == null
          ? now
          : _plans
                .firstWhere(
                  (p) => p.id == id,
                  orElse: () => _buildDocument(
                    id: id,
                    createdAt: now,
                    updatedAt: now,
                    status: PlanningStatus.idea,
                  ),
                )
                .createdAt;
      final doc = _buildDocument(
        id: id,
        createdAt: createdAt,
        updatedAt: now,
        status: _statusAfterAnalysis(result.verdict),
        analysis: result,
        instruction: _instruction,
      );
      await _store.upsertPlan(doc);
      await _persistDraft();
      await _refreshPlans();
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _activePlanId = id;
        _instruction = doc.instruction;
        _inputExpanded = false;
      });
      _snack('로컬 규칙 기반 분석을 완료했습니다.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToResultsTitle();
      });
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _scrollToResultsTitle() {
    final ctx = _resultsTitleKey.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _saveDraftPlan() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _activePlanId ?? BusinessPlanningStore.newPlanId();
    final existing = _activePlanId == null
        ? null
        : _plans.cast<BusinessPlanDocument?>().firstWhere(
            (p) => p?.id == id,
            orElse: () => null,
          );
    final doc = _buildDocument(
      id: id,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: existing?.status ?? PlanningStatus.idea,
      analysis: _analysis ?? existing?.analysis,
      instruction: _instruction ?? existing?.instruction,
    );
    await _store.upsertPlan(doc);
    await _persistDraft();
    await _refreshPlans();
    if (!mounted) return;
    setState(() => _activePlanId = id);
    _snack('기획안을 임시 저장했습니다.');
  }

  Future<void> _buildInstructionDoc() async {
    if (_analysis == null) {
      _snack('먼저 사업 기획안 분석을 실행하세요.');
      return;
    }
    final id = _activePlanId ?? BusinessPlanningStore.newPlanId();
    final instruction = _service.buildInstruction(
      planId: id,
      input: _currentInput,
      analysis: _analysis!,
    );
    final now = instruction.updatedAt;
    final existing = _plans.cast<BusinessPlanDocument?>().firstWhere(
      (p) => p?.id == id,
      orElse: () => null,
    );
    final doc = _buildDocument(
      id: id,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: PlanningStatus.instructionReady,
      analysis: _analysis,
      instruction: instruction,
    );
    await _store.upsertPlan(doc);
    await _refreshPlans();
    if (!mounted) return;
    setState(() {
      _activePlanId = id;
      _instruction = instruction;
    });
    _snack('작업지시서를 생성했습니다. 실행 상태: 지시서 준비');
  }

  Future<void> _copyJson() async {
    final id = _activePlanId;
    if (id == null && _analysis == null) {
      _snack('저장되거나 분석된 기획안이 없습니다.');
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final doc = _buildDocument(
      id: id ?? BusinessPlanningStore.newPlanId(),
      createdAt: now,
      updatedAt: now,
      status: PlanningStatus.idea,
      analysis: _analysis,
      instruction: _instruction,
    );
    final json = const JsonEncoder.withIndent('  ').convert(doc.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    _snack('JSON을 클립보드에 복사했습니다.');
  }

  Future<void> _copyReadableInstruction() async {
    if (_instruction == null) {
      _snack('작업지시서를 먼저 생성하세요.');
      return;
    }
    final text = _service.buildReadableInstruction(_instruction!);
    await Clipboard.setData(ClipboardData(text: text));
    _snack('텍스트 지시서를 복사했습니다.');
  }

  Future<void> _copyCursorPrompt() async {
    if (_instruction == null) {
      _snack('작업지시서를 먼저 생성하세요.');
      return;
    }
    final text = _service.buildCursorPrompt(
      input: _currentInput,
      instruction: _instruction!,
    );
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Cursor 프롬프트를 복사했습니다.');
  }

  Future<void> _duplicatePlan() async {
    if (!_currentInput.hasRequiredFields && _analysis == null) {
      _snack('복제할 내용이 없습니다.');
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = BusinessPlanningStore.newPlanId();
    final doc = _buildDocument(
      id: id,
      createdAt: now,
      updatedAt: now,
      status: _analysis == null
          ? PlanningStatus.idea
          : _statusAfterAnalysis(_analysis!.verdict),
      analysis: _analysis,
      instruction: _instruction,
    );
    await _store.upsertPlan(doc);
    await _refreshPlans();
    if (!mounted) return;
    setState(() => _activePlanId = id);
    _snack('기획안을 복제했습니다.');
  }

  Future<void> _archivePlan() async {
    final id = _activePlanId;
    if (id == null) {
      _snack('보관할 저장된 기획안을 선택하세요.');
      return;
    }
    final existing = _plans.firstWhere((p) => p.id == id);
    final now = DateTime.now().toUtc().toIso8601String();
    final doc = existing.copyWith(
      status: PlanningStatus.archived,
      updatedAt: now,
    );
    await _store.upsertPlan(doc);
    await _refreshPlans();
    if (!mounted) return;
    setState(() {
      _activePlanId = null;
      _analysis = null;
      _instruction = null;
      _inputExpanded = true;
      _applyInput(const BusinessPlanInput());
    });
    _snack('기획안을 보관함으로 이동했습니다.');
  }

  void _loadPlan(BusinessPlanDocument plan) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _activePlanId = plan.id;
      _applyInput(plan.input);
      _analysis = plan.analysis;
      _instruction = plan.instruction;
      _inputExpanded = plan.analysis == null;
    });
    _persistDraft();
    _snack(
      '「${plan.input.topic.isEmpty ? '제목 없음' : plan.input.topic}」을(를) 불러왔습니다.',
    );
    if (plan.analysis != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToResultsTitle();
      });
    } else if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _startNewPlan() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _activePlanId = null;
      _analysis = null;
      _instruction = null;
      _inputExpanded = true;
      _applyInput(const BusinessPlanInput());
    });
    _persistDraft();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  String _formatIso(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case PlanningVerdict.readyToBuild:
        return ControlColors.accentGreen;
      case PlanningVerdict.validateFirst:
        return ControlColors.sandBeige;
      case PlanningVerdict.needsRefine:
        return ControlColors.accentWarm;
      case PlanningVerdict.hold:
        return ControlColors.accentRose;
      default:
        return ControlColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 콘텐츠 영역 단일 스크롤만 사용 (중첩 세로 스크롤·고정 높이 없음).
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBanner(),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final desktopSplit = width >= 1200 && _analysis != null;
              final tabletish = width >= 768 && width < 1200;

              if (_analysis == null) {
                return _buildPreAnalysisLayout(width, tabletish);
              }
              if (desktopSplit) {
                return _buildPostAnalysisDesktop();
              }
              return _buildPostAnalysisStacked();
            },
          ),
          const SizedBox(height: 16),
          _buildInstructionSection(),
          const SizedBox(height: 16),
          _buildActionsBar(),
          const SizedBox(height: 20),
          _buildSavedPlansSection(),
        ],
      ),
    );
  }

  Widget _buildPreAnalysisLayout(double width, bool tabletish) {
    final form = _buildInputForm(showAnalyzeButton: true);
    final tip = _buildEmptyResultsHint();

    if (width >= 768) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tabletish ? 820 : 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [form, const SizedBox(height: 12), tip],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [form, const SizedBox(height: 12), tip],
    );
  }

  Widget _buildPostAnalysisDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _inputExpanded
              ? _buildInputForm(showAnalyzeButton: true)
              : _buildInputSummaryCard(),
        ),
        const SizedBox(width: 16),
        Expanded(flex: 6, child: _buildResultsContent()),
      ],
    );
  }

  Widget _buildPostAnalysisStacked() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_inputExpanded)
          _buildInputForm(showAnalyzeButton: true)
        else
          _buildInputSummaryCard(),
        const SizedBox(height: 12),
        _buildResultsContent(),
      ],
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ControlColors.border),
      ),
      child: const Text(
        '현재 단계는 로컬 규칙 기반 기획 도우미입니다. 외부 AI 생성·소통24워크 자동 실행은 포함하지 않습니다.',
        style: TextStyle(fontSize: 12.5, color: ControlColors.textSecondary),
      ),
    );
  }

  Widget _buildEmptyResultsHint() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          '필수 항목을 입력한 뒤 「사업 기획안 분석」을 실행하면 12개 기준 평가와 제작 형태 추천이 표시됩니다.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: ControlColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildInputSummaryCard() {
    final input = _currentInput;
    String line(String label, String value) {
      final v = value.trim().isEmpty ? '—' : value.trim();
      return '$label: $v';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '기획 요약',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _inputExpanded = true),
                  child: const Text('입력 수정'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(line('사업 주제', input.topic)),
            const SizedBox(height: 4),
            Text(line('고객 문제', input.customerProblem)),
            const SizedBox(height: 4),
            Text(line('대상 고객', input.targetCustomer)),
            const SizedBox(height: 4),
            Text(line('결과물', input.desiredOutcome)),
            const SizedBox(height: 4),
            Text(
              line(
                '선택 제작 형태',
                input.deliverableTypes.map(DeliverableType.labelKo).join(', '),
              ),
            ),
            const SizedBox(height: 4),
            Text(line('목표 수익', input.revenueModel)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _inputExpanded = true),
                  icon: const Icon(Icons.unfold_more, size: 18),
                  label: const Text('입력 내용 펼치기'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _analyzing ? null : _runAnalyze,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 분석'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm({required bool showAnalyzeButton}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '기획 입력',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_analysis != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _inputExpanded = false),
                    icon: const Icon(Icons.unfold_less, size: 18),
                    label: const Text('입력 내용 접기'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _field(_topicCtrl, '사업 주제 *', maxLines: 1),
            _field(_problemCtrl, '고객 문제 *', maxLines: 3),
            _field(_targetCtrl, '대상 고객 *', maxLines: 2),
            _field(_outcomeCtrl, '원하는 결과 *', maxLines: 2),
            const SizedBox(height: 8),
            Text(
              '희망 결과물 (복수 선택)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in _deliverableOptions)
                  FilterChip(
                    label: Text(DeliverableType.labelKo(type)),
                    selected: _deliverableTypes.contains(type),
                    onSelected: (_) => _toggleDeliverable(type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('선택 입력 (경험·자료·수익 등)'),
              children: [
                _field(_skillsCtrl, '보유 경험·기술'),
                _field(_materialsCtrl, '기존 자료'),
                _field(_revenueCtrl, '수익 모델 가설'),
                _field(_monthlyGoalCtrl, '월 목표'),
                _field(_durationCtrl, '예상 기간'),
                _field(_notesCtrl, '메모', maxLines: 3),
              ],
            ),
            if (showAnalyzeButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _analyzing ? null : _runAnalyze,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(_analyzing ? '분석 중…' : '사업 기획안 분석'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
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
      ),
    );
  }

  Widget _buildResultsContent() {
    final analysis = _analysis!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '분석 결과',
                  key: _resultsTitleKey,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    KpiCard(
                      label: '평균 점수 (5점)',
                      value: analysis.averageScore.toStringAsFixed(1),
                    ),
                    KpiCard(
                      label: '판단',
                      value: PlanningVerdict.labelKo(analysis.verdict),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StatusBadge(
                  label: PlanningVerdict.labelKo(analysis.verdict),
                  color: _verdictColor(analysis.verdict),
                ),
                const SizedBox(height: 8),
                Text(analysis.summary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('기준별 점수', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final c in analysis.criteria)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Expanded(child: Text(c.label, softWrap: true)),
                        const SizedBox(width: 8),
                        Text(
                          '${c.score}/5',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ControlColors.teal,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      _detailLine('근거', c.rationale),
                      _detailLine('부족 정보', c.missingInfo),
                      _detailLine('리스크', c.risks),
                      _detailLine('개선', c.improvement),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '결과물 추천 순위',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final rec in analysis.recommendations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: ControlColors.tealSoft,
                              child: Text(
                                '${rec.rank}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ControlColors.teal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DeliverableType.labelKo(rec.type),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(rec.reason),
                        if (rec.rank <= 3) ...[
                          const SizedBox(height: 4),
                          Text(
                            '최소: ${rec.minimumOutput}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ControlColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _analysis == null ? null : _buildInstructionDoc,
            icon: const Icon(Icons.description_outlined),
            label: const Text('소통24워크 작업지시서 생성'),
          ),
        ),
        if (_instruction != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('작업지시서', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge(
                        label: _instruction!.executionStatus,
                        color: ControlColors.teal,
                      ),
                      StatusBadge(
                        label: 'v${_instruction!.instructionVersion}',
                        color: ControlColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '생성: ${_formatIso(_instruction!.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ControlColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _instruction!.valueProposition,
                    style: const TextStyle(color: ControlColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailLine(String label, String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: ControlColors.textPrimary,
              fontSize: 13,
            ),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _saveDraftPlan,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('임시 저장'),
        ),
        OutlinedButton.icon(
          onPressed: _copyJson,
          icon: const Icon(Icons.code, size: 18),
          label: const Text('JSON 내보내기'),
        ),
        OutlinedButton.icon(
          onPressed: _copyReadableInstruction,
          icon: const Icon(Icons.content_copy, size: 18),
          label: const Text('텍스트 지시서 복사'),
        ),
        OutlinedButton.icon(
          onPressed: _copyCursorPrompt,
          icon: const Icon(Icons.terminal, size: 18),
          label: const Text('Cursor 프롬프트 복사'),
        ),
        OutlinedButton.icon(
          onPressed: _duplicatePlan,
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: const Text('복제'),
        ),
        OutlinedButton.icon(
          onPressed: _archivePlan,
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: const Text('보관'),
        ),
        OutlinedButton.icon(
          onPressed: _startNewPlan,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('새 기획'),
        ),
      ],
    );
  }

  Widget _buildSavedPlansSection() {
    final visible = _plans
        .where((p) => p.status != PlanningStatus.archived)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('저장된 기획안', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const EmptyStatePanel(
            title: '저장된 기획안 없음',
            message: '임시 저장 또는 분석 후 목록에 표시됩니다.',
          )
        else
          for (final plan in visible)
            Card(
              child: ListTile(
                onTap: () => _loadPlan(plan),
                title: Text(
                  plan.input.topic.isEmpty ? '(주제 미입력)' : plan.input.topic,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${plan.input.deliverableTypes.map(DeliverableType.labelKo).join(', ')} · '
                  '${PlanningStatus.labelKo(plan.status)} · '
                  '${_formatIso(plan.updatedAt)}',
                  softWrap: true,
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (plan.analysis != null)
                      StatusBadge(
                        label: PlanningVerdict.labelKo(plan.analysis!.verdict),
                        color: _verdictColor(plan.analysis!.verdict),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      plan.hasInstruction ? '지시서 있음' : '지시서 없음',
                      style: TextStyle(
                        fontSize: 11,
                        color: plan.hasInstruction
                            ? ControlColors.teal
                            : ControlColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
