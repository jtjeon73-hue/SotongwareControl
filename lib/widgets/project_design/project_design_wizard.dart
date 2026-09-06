import 'package:flutter/material.dart';

import '../../data/project_design_catalog.dart';
import '../../models/artifact_type.dart';
import '../../models/concept_candidate.dart';
import '../../models/project_design_state.dart';
import '../../services/project_design_engine.dart';
import '../../services/work_instruction_concept_occupancy.dart';
import '../../services/work_instruction_workshop_presentation.dart';
import '../../theme/control_theme.dart';
import 'concept_picker_panel.dart';
import 'studio_ai_enhance_panel.dart';
import 'studio_production_options_panel.dart';
import 'studio_workflow_preview_panel.dart';

/// Project Design Engine Wizard (STEP 0~6).
class ProjectDesignWizard extends StatefulWidget {
  const ProjectDesignWizard({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onRequestCreateInstruction,
    this.onRequestRecreateInstruction,
    this.onRequestSavePlan,
    this.onRequestNewWork,
    this.occupancy,
    this.onOccupiedConcept,
    this.instructionGenerated = false,
    this.instructionStale = false,
    this.approvalMode = 'manual',
    this.workerPreference = 'auto',
    this.aiProductionPilot = true,
    this.onApprovalModeChanged,
    this.onWorkerPreferenceChanged,
    this.onRequestLocalValidate,
    this.onRequestTransfer,
  });

  final ProjectDesignState initial;
  final ValueChanged<ProjectDesignState> onChanged;
  final VoidCallback? onRequestCreateInstruction;
  final VoidCallback? onRequestRecreateInstruction;
  final VoidCallback? onRequestSavePlan;
  final VoidCallback? onRequestNewWork;
  final ConceptOccupancyIndex? occupancy;
  final void Function(ConceptOccupancyView view)? onOccupiedConcept;
  final bool instructionGenerated;
  final bool instructionStale;
  final String approvalMode;
  final String workerPreference;
  final bool aiProductionPilot;
  final ValueChanged<String>? onApprovalModeChanged;
  final ValueChanged<String>? onWorkerPreferenceChanged;
  final VoidCallback? onRequestLocalValidate;
  final VoidCallback? onRequestTransfer;

  @override
  State<ProjectDesignWizard> createState() => _ProjectDesignWizardState();
}

class _ProjectDesignWizardState extends State<ProjectDesignWizard> {
  late ProjectDesignState _state;
  final _engine = ProjectDesignEngine();
  final _memoCtrl = TextEditingController();
  final _customAudienceCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();
  final _uniqueValueCtrl = TextEditingController();
  final _reasonsToPayCtrl = TextEditingController();
  final _sourceInstructionIdCtrl = TextEditingController();
  final _sourceRevisionCtrl = TextEditingController();
  final _requestedRevisionCtrl = TextEditingController();
  final _requestedChangesCtrl = TextEditingController();
  final _preservedHashesCtrl = TextEditingController();
  DesignReviewReport? _review;

  @override
  void initState() {
    super.initState();
    _state = widget.initial.copy();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant ProjectDesignWizard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      _state = widget.initial.copy();
      _syncControllers();
      _review = null;
    }
  }

  void _syncControllers() {
    _memoCtrl.text = _state.designMemo;
    _customAudienceCtrl.text = _state.customAudience;
    _topicCtrl.text = _state.topic;
    _problemCtrl.text = _state.customerProblem;
    _outcomeCtrl.text = _state.desiredOutcome;
    _uniqueValueCtrl.text = _state.uniqueValue;
    _reasonsToPayCtrl.text = _state.reasonsToPay.join('\n');
    _sourceInstructionIdCtrl.text = _state.sourceInstructionId;
    _sourceRevisionCtrl.text = _state.sourceRevision;
    _requestedRevisionCtrl.text = _state.requestedRevision;
    _requestedChangesCtrl.text = _state.requestedChanges.join('\n');
    _preservedHashesCtrl.text = _state.preservedArtifactHashes.join('\n');
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    _customAudienceCtrl.dispose();
    _topicCtrl.dispose();
    _problemCtrl.dispose();
    _outcomeCtrl.dispose();
    _uniqueValueCtrl.dispose();
    _reasonsToPayCtrl.dispose();
    _sourceInstructionIdCtrl.dispose();
    _sourceRevisionCtrl.dispose();
    _requestedRevisionCtrl.dispose();
    _requestedChangesCtrl.dispose();
    _preservedHashesCtrl.dispose();
    super.dispose();
  }

  void _emit(ProjectDesignState next) {
    setState(() => _state = next);
    widget.onChanged(next);
  }

  String _creationModeSummary() {
    final parts = <String>[
      _state.creationMode == 'revise_existing' ? '기존 결과물 보완' : '새 결과물',
    ];
    if (_state.manualOnlyMode) parts.add('상세 직접입력');
    return parts.join(' · ');
  }

  String _pipelinePhaseLabel(String phase) {
    switch (phase) {
      case StudioPipelinePhase.drafting:
        return '초안 작성 중';
      case StudioPipelinePhase.contentConfirmed:
        return '기획 확정됨';
      case StudioPipelinePhase.instructionGenerated:
        return '작업지시서 생성됨';
      case StudioPipelinePhase.locallyValidated:
        return '로컬 검증 완료';
      case StudioPipelinePhase.readyToSend:
        return '전송 준비 완료';
      default:
        return phase;
    }
  }

  String _composeUserBrief() {
    return [
      if (_topicCtrl.text.trim().isNotEmpty) _topicCtrl.text.trim(),
      if (_problemCtrl.text.trim().isNotEmpty) _problemCtrl.text.trim(),
      if (_outcomeCtrl.text.trim().isNotEmpty) _outcomeCtrl.text.trim(),
    ].join('\n');
  }

  List<String> _parseMultilineList(String raw) {
    final lines = raw
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return lines;
  }

  String _truncate(String text, {int max = 120}) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  void _prefillCommercialFromConcepts(ProjectDesignState state) {
    if (state.selectedConceptIds.isEmpty) return;
    final selected = _engine.resolveSelectedConcepts(state);
    if (selected.isEmpty) return;
    final first = selected.first;
    var next = state.copy();
    var changed = false;
    if (next.uniqueValue.trim().isEmpty &&
        first.uniqueValue.trim().isNotEmpty) {
      next.uniqueValue = first.uniqueValue.trim();
      _uniqueValueCtrl.text = next.uniqueValue;
      changed = true;
    }
    if (next.reasonsToPay.isEmpty && first.reasonsToPay.isNotEmpty) {
      next.reasonsToPay = List<String>.from(first.reasonsToPay);
      _reasonsToPayCtrl.text = next.reasonsToPay.join('\n');
      changed = true;
    }
    if (changed) _emit(next);
  }

  void _clearReviseFields(ProjectDesignState next) {
    next.sourceInstructionId = '';
    next.sourceRevision = '';
    next.requestedRevision = '';
    next.requestedChanges = [];
    next.preservedArtifactHashes = [];
    _sourceInstructionIdCtrl.clear();
    _sourceRevisionCtrl.clear();
    _requestedRevisionCtrl.clear();
    _requestedChangesCtrl.clear();
    _preservedHashesCtrl.clear();
  }

  bool _canGoNext() {
    switch (_state.step) {
      case ProjectDesignStep.artifact:
        return _state.canProceedFromArtifact;
      case ProjectDesignStep.audience:
        return _state.canProceedFromAudience;
      case ProjectDesignStep.topics:
        return _state.canProceedFromTopics;
      case ProjectDesignStep.details:
        return _topicCtrl.text.trim().isNotEmpty &&
            _problemCtrl.text.trim().isNotEmpty &&
            _outcomeCtrl.text.trim().isNotEmpty;
      case ProjectDesignStep.production:
        return true;
      case ProjectDesignStep.review:
        return _state.planningConfirmed;
      case ProjectDesignStep.finalize:
        return _state.canCreateInstruction;
      default:
        return false;
    }
  }

  void _goNext() {
    var next = _state.copy();
    next.designMemo = _memoCtrl.text;
    next.customAudience = _customAudienceCtrl.text;
    if (next.step == ProjectDesignStep.topics ||
        next.step == ProjectDesignStep.audience) {
      next = _engine.syncSentences(next);
      _topicCtrl.text = next.topic;
      _problemCtrl.text = next.customerProblem;
      _outcomeCtrl.text = next.desiredOutcome;
    }
    if (next.step == ProjectDesignStep.details) {
      final topic = _topicCtrl.text.trim();
      final problem = _problemCtrl.text.trim();
      final outcome = _outcomeCtrl.text.trim();
      if (topic != next.topic) {
        next.topic = topic;
        next = _engine.markFieldEdited(next, field: 'topic');
      } else {
        next.topic = topic;
      }
      if (problem != next.customerProblem) {
        next.customerProblem = problem;
        next = _engine.markFieldEdited(next, field: 'problem');
      } else {
        next.customerProblem = problem;
      }
      if (outcome != next.desiredOutcome) {
        next.desiredOutcome = outcome;
        next = _engine.markFieldEdited(next, field: 'outcome');
      } else {
        next.desiredOutcome = outcome;
      }
      next.planningConfirmed = false;
    }
    if (next.step == ProjectDesignStep.production) {
      _review = _engine.buildReview(next);
    }
    if (next.step < ProjectDesignStep.finalize) {
      next.step += 1;
      _emit(next);
    }
  }

  void _goBack() {
    if (_state.step <= ProjectDesignStep.artifact) return;
    final next = _state.copy()..step -= 1;
    _emit(next);
  }

  IconData _artifactIcon(String name) {
    switch (name) {
      case 'phone_android':
        return Icons.phone_android_outlined;
      case 'play_circle':
        return Icons.play_circle_outline;
      case 'language':
        return Icons.language_outlined;
      case 'campaign':
        return Icons.campaign_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(),
        const SizedBox(height: 12),
        _buildStepBody(),
        const SizedBox(height: 16),
        _buildNav(),
      ],
    );
  }

  Widget _buildStepHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP ${_state.step + 1} / ${ProjectDesignStep.count}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ControlColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ProjectDesignStep.labels[_state.step],
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < ProjectDesignStep.count; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: i == ProjectDesignStep.count - 1 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: i <= _state.step
                        ? ControlColors.teal
                        : ControlColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepBody() {
    switch (_state.step) {
      case ProjectDesignStep.artifact:
        return _buildArtifactStep();
      case ProjectDesignStep.audience:
        return _buildAudienceStep();
      case ProjectDesignStep.topics:
        return _buildTopicsStep();
      case ProjectDesignStep.details:
        return _buildDetailsStep();
      case ProjectDesignStep.production:
        return _buildProductionStep();
      case ProjectDesignStep.review:
        return _buildReviewStep();
      case ProjectDesignStep.finalize:
        return _buildFinalizeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildArtifactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '어떤 방식으로 진행할까요?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CreationModeCard(
              title: '새 결과물 만들기',
              subtitle: '처음부터 새 프로젝트를 기획합니다',
              selected: _state.creationMode == 'new_product',
              onTap: () {
                final next = _state.copy()..creationMode = 'new_product';
                _clearReviseFields(next);
                _emit(next);
              },
            ),
            _CreationModeCard(
              title: '기존 결과물 보완하기',
              subtitle: '이전 작업지시서·리비전을 기준으로 수정',
              selected: _state.creationMode == 'revise_existing',
              onTap: () {
                _emit(_state.copy()..creationMode = 'revise_existing');
              },
            ),
            _CreationModeCard(
              title: '상세 직접입력',
              subtitle: 'AI 보완 없이 사용자 입력만 사용',
              selected: _state.manualOnlyMode,
              onTap: () {
                _emit(_state.copy()..manualOnlyMode = !_state.manualOnlyMode);
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '현재: ${_creationModeSummary()}',
          style: const TextStyle(fontSize: 12, color: ControlColors.textMuted),
        ),
        if (_state.creationMode == 'revise_existing') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _sourceInstructionIdCtrl,
            decoration: const InputDecoration(
              labelText: '원본 작업지시 ID',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _state.sourceInstructionId = v,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sourceRevisionCtrl,
            decoration: const InputDecoration(
              labelText: '원본 리비전',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _state.sourceRevision = v,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _requestedRevisionCtrl,
            decoration: const InputDecoration(
              labelText: '요청 리비전 (선택)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _state.requestedRevision = v,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _requestedChangesCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '요청 변경 사항 (줄 또는 쉼표로 구분)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _state.requestedChanges = _parseMultilineList(v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _preservedHashesCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '보존할 산출물 해시 (선택, 줄 구분)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                _state.preservedArtifactHashes = _parseMultilineList(v),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          '무엇을 만들까요? 4대 제작 유형 중 하나를 선택하세요.',
          style: TextStyle(fontSize: 13, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cards = ProjectDesignCatalog.studioMainCards;
            final isSiteFamily =
                _state.artifactType == ArtifactType.site ||
                _state.artifactType == ArtifactType.promoSite;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: wide
                            ? (constraints.maxWidth - 10) / 2
                            : constraints.maxWidth,
                        child: _ArtifactSelectCard(
                          key: ValueKey('artifact-${card.id}'),
                          selected: card.id == ArtifactType.site
                              ? isSiteFamily
                              : _state.artifactType == card.id,
                          selectedKey:
                              (card.id == ArtifactType.site
                                  ? isSiteFamily
                                  : _state.artifactType == card.id)
                              ? Key('planning_artifact_${card.id}_selected')
                              : null,
                          title: card.title,
                          subtitle: card.subtitle,
                          icon: _artifactIcon(card.iconName),
                          onTap: () {
                            final next = _state.copy()
                              ..artifactType = card.id == ArtifactType.site
                                  ? ArtifactType.site
                                  : card.id
                              ..contentSubtype =
                                  card.id == ArtifactType.contents
                                  ? _state.contentSubtype
                                  : null
                              ..siteSubtype =
                                  (card.id == ArtifactType.site ||
                                      card.id == ArtifactType.promoSite)
                                  ? _state.siteSubtype
                                  : null;
                            if (card.id != ArtifactType.site &&
                                card.id != ArtifactType.promoSite) {
                              final prod = Map<String, List<String>>.from(
                                next.productionSelections,
                              );
                              prod.remove('site_kind');
                              prod.remove('siteKind');
                              next.productionSelections = prod;
                            }
                            _emit(next);
                          },
                        ),
                      ),
                  ],
                ),
                if (isSiteFamily) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '사이트 유형',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in ProjectDesignCatalog.siteKinds)
                        FilterChip(
                          key: ValueKey('site-kind-${kind.id}'),
                          label: Text(kind.label),
                          selected: _state.siteSubtype == kind.id,
                          onSelected: (_) {
                            final prod = Map<String, List<String>>.from(
                              _state.productionSelections,
                            );
                            prod['site_kind'] = [kind.id];
                            prod.remove('siteKind');
                            _emit(
                              _state.copy()
                                ..artifactType = ArtifactType.site
                                ..siteSubtype = kind.id
                                ..contentSubtype = null
                                ..productionSelections = prod,
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        if (_state.artifactType == ArtifactType.contents) ...[
          const SizedBox(height: 16),
          const Text('콘텐츠 유형', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in ProjectDesignCatalog.contentSubtypes)
                FilterChip(
                  label: Text(opt.label),
                  selected: _state.contentSubtype == opt.id,
                  onSelected: (_) {
                    _emit(
                      _state.copy()
                        ..contentSubtype = opt.id
                        ..siteSubtype = null,
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAudienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '누구를 위한 프로젝트인가요? 복수 선택이 가능합니다.',
          style: TextStyle(fontSize: 13, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in ProjectDesignCatalog.audiences)
              FilterChip(
                key: _state.selectedAudiences.contains(a.id)
                    ? Key('planning_audience_${a.id}_selected')
                    : Key('planning_audience_${a.id}'),
                label: Text(a.label),
                selected: _state.selectedAudiences.contains(a.id),
                onSelected: (on) {
                  final next = _state.copy();
                  if (on) {
                    if (!next.selectedAudiences.contains(a.id)) {
                      next.selectedAudiences = [
                        ...next.selectedAudiences,
                        a.id,
                      ];
                    }
                  } else {
                    next.selectedAudiences = next.selectedAudiences
                        .where((id) => id != a.id)
                        .toList();
                  }
                  _emit(next);
                },
              ),
          ],
        ),
        if (_state.selectedAudiences.contains('custom')) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customAudienceCtrl,
            decoration: const InputDecoration(
              labelText: '기타 대상 고객 직접 입력',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _state.customAudience = v,
          ),
        ],
      ],
    );
  }

  Widget _buildTopicsStep() {
    final concepts = _engine.recommendConceptsSync(_state, limit: 50);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대상 고객·결과물에 맞는 컨셉을 추천합니다. 여러 개를 선택할 수 있습니다.',
          style: TextStyle(fontSize: 13, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ConceptPickerPanel(
          candidates: concepts,
          selectedIds: _state.selectedConceptIds,
          userAdded: _state.userAddedConcepts,
          occupancy: widget.occupancy,
          artifactType: _state.artifactType ?? '',
          audiences: _state.selectedAudiences,
          onOccupiedTap: widget.onOccupiedConcept,
          onSelectionChanged: (ids) {
            var next = _state.copy()..selectedConceptIds = ids;
            next.planningConfirmed = false;
            next = _engine.syncSentences(next);
            _topicCtrl.text = next.topic;
            _problemCtrl.text = next.customerProblem;
            _outcomeCtrl.text = next.desiredOutcome;
            _prefillCommercialFromConcepts(next);
            _emit(next);
          },
          onAddUserConcept: (title, memo) {
            final added = ConceptCandidate.userAdded(
              title: title,
              memo: memo,
              artifactType: _state.artifactType ?? '',
              audiences: _state.selectedAudiences,
            );
            final occ = widget.occupancy?.viewFor(
              conceptId: added.id,
              artifactType: _state.artifactType ?? '',
              title: added.title,
              audiences: _state.selectedAudiences,
            );
            if (occ != null && occ.isOccupied) {
              widget.onOccupiedConcept?.call(occ);
              return;
            }
            var next = _state.copy();
            next.userAddedConcepts = [...next.userAddedConcepts, added];
            next.selectedConceptIds = [...next.selectedConceptIds, added.id];
            next.planningConfirmed = false;
            next = _engine.syncSentences(next);
            _topicCtrl.text = next.topic;
            _problemCtrl.text = next.customerProblem;
            _outcomeCtrl.text = next.desiredOutcome;
            _prefillCommercialFromConcepts(next);
            _emit(next);
          },
        ),
        if (_state.combinedDirection.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: ControlColors.border),
              borderRadius: BorderRadius.circular(8),
              color: ControlColors.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '결합 방향 (AI 추천·미확정)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  _state.combinedDirection,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('추가 메모', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _memoCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '추가 아이디어, 반드시 포함할 내용, 주의사항, 경험, 차별화 포인트',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _state.designMemo = v,
        ),
      ],
    );
  }

  Widget _statusBadge(DesignFieldStatus status) {
    final color = switch (status) {
      DesignFieldStatus.userConfirmed => ControlColors.accentGreen,
      DesignFieldStatus.userEdited ||
      DesignFieldStatus.userSelected => ControlColors.teal,
      DesignFieldStatus.suggested => ControlColors.sandBeige,
      DesignFieldStatus.undecided => ControlColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        status.labelKo,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI 추천 문장은 「AI 추천」 상태입니다. 수정하면 「사용자 수정」, '
          '최종 확인 단계에서만 「사용자 확정」이 됩니다.',
          style: TextStyle(fontSize: 13, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('기획 주제')),
            _statusBadge(_state.topicStatus),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _topicCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) {
            _emit(
              _engine.markFieldEdited(
                _state.copy()..topic = _topicCtrl.text,
                field: 'topic',
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: Text('핵심 문제')),
            _statusBadge(_state.problemStatus),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _problemCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) {
            _emit(
              _engine.markFieldEdited(
                _state.copy()..customerProblem = _problemCtrl.text,
                field: 'problem',
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: Text('기대 결과')),
            _statusBadge(_state.outcomeStatus),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _outcomeCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) {
            _emit(
              _engine.markFieldEdited(
                _state.copy()..desiredOutcome = _outcomeCtrl.text,
                field: 'outcome',
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '대상 고객: ${_state.targetCustomer.isEmpty ? '(미정)' : _state.targetCustomer}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ControlColors.textMuted,
                ),
              ),
            ),
            _statusBadge(_state.customerStatus),
          ],
        ),
        const SizedBox(height: 16),
        const Text('차별 가치', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _uniqueValueCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '이 결과물만의 차별점·독특한 가치',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _emit(_state.copy()..uniqueValue = v);
          },
        ),
        const SizedBox(height: 10),
        const Text('구매·이용 이유', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _reasonsToPayCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '한 줄에 하나씩 입력 (고객이 돈·시간을 쓸 이유)',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _emit(_state.copy()..reasonsToPay = _parseMultilineList(v));
          },
        ),
        const SizedBox(height: 16),
        StudioAiEnhancePanel(
          state: _state,
          onApply: (result) {
            var next = _state.copy();
            if (next.originalUserBrief.trim().isEmpty &&
                !next.originalUserBriefConfirmed) {
              next.originalUserBrief = _composeUserBrief();
            }
            final notes = result.suggestedNotes.trim();
            if (notes.isNotEmpty) {
              next.aiAugmentedBrief = notes;
            }
            for (final section in result.sections) {
              for (final bullet in section.bullets) {
                final b = bullet.trim();
                if (b.isEmpty) continue;
                if (!next.acceptedAiSuggestions.contains(b)) {
                  next.acceptedAiSuggestions = [
                    ...next.acceptedAiSuggestions,
                    b,
                  ];
                }
              }
            }
            if (next.customerProblem.trim().isEmpty) {
              next.customerProblem = result.suggestedProblem;
              _problemCtrl.text = result.suggestedProblem;
              next = _engine.markFieldEdited(next, field: 'problem');
            }
            if (next.desiredOutcome.trim().isEmpty) {
              next.desiredOutcome = result.suggestedOutcome;
              _outcomeCtrl.text = result.suggestedOutcome;
              next = _engine.markFieldEdited(next, field: 'outcome');
            }
            if (notes.isNotEmpty) {
              next.designMemo = next.designMemo.trim().isEmpty
                  ? notes
                  : '${next.designMemo.trim()}\n\n$notes';
              _memoCtrl.text = next.designMemo;
            }
            next.manualOnlyMode = false;
            _emit(next);
          },
          onKeepOriginal: (result) {
            var next = _state.copy();
            if (result != null) {
              for (final section in result.sections) {
                for (final bullet in section.bullets) {
                  final b = bullet.trim();
                  if (b.isEmpty) continue;
                  if (!next.rejectedAiSuggestions.contains(b)) {
                    next.rejectedAiSuggestions = [
                      ...next.rejectedAiSuggestions,
                      b,
                    ];
                  }
                }
              }
            }
            next.aiAugmentedBrief = '';
            next.manualOnlyMode = true;
            _emit(next);
          },
        ),
      ],
    );
  }

  Widget _buildProductionStep() {
    final groups = ProjectDesignCatalog.productionGroupsFor(
      _state.artifactType ?? '',
      contentSubtype: _state.contentSubtype ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.aiProductionPilot) ...[
          StudioProductionOptionsPanel(
            approvalMode: widget.approvalMode,
            workerPreference: widget.workerPreference,
            showApprovalMode: true,
            onApprovalModeChanged: (v) => widget.onApprovalModeChanged?.call(v),
            onWorkerPreferenceChanged: (v) =>
                widget.onWorkerPreferenceChanged?.call(v),
          ),
          if (widget.approvalMode == 'auto') ...[
            const SizedBox(height: 8),
            const Text(
              '자동 승인이 켜져 있어도 다음 단계에서는 반드시 멈춥니다: '
              '사용자 품질 검토, owner review, 외부 공개, 앱스토어·사업부 등록',
              style: TextStyle(fontSize: 11.5, color: ControlColors.accentWarm),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (groups.isEmpty)
          const Text('이 결과물은 추가 제작 정보가 필수는 아닙니다. 다음으로 진행하세요.')
        else ...[
          const Text(
            '결과물에 맞는 제작 정보를 선택하세요.',
            style: TextStyle(fontSize: 13, color: ControlColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final g in groups) ...[
            Text(g.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in g.options)
                  FilterChip(
                    label: Text(opt.label),
                    selected: (_state.productionSelections[g.id] ?? const [])
                        .contains(opt.id),
                    onSelected: (on) {
                      final next = _state.copy();
                      final cur = List<String>.from(
                        next.productionSelections[g.id] ?? const [],
                      );
                      if (g.multi) {
                        if (on) {
                          if (!cur.contains(opt.id)) cur.add(opt.id);
                        } else {
                          cur.remove(opt.id);
                        }
                      } else {
                        cur
                          ..clear()
                          ..addAll(on ? [opt.id] : []);
                      }
                      next.productionSelections[g.id] = cur;
                      _emit(next);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    final report = _review ?? _engine.buildReview(_state);
    _review ??= report;
    final selected = _engine.resolveSelectedConcepts(_state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '작업지시서 생성 전 최종 기획을 확인하세요. '
          '확인 버튼을 눌러야 「사용자 확정」으로 승격됩니다.',
          style: TextStyle(fontSize: 13, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _confirmRow(
          '결과물',
          ArtifactType.labelKo(_state.artifactType ?? ''),
          DesignFieldStatus.userSelected,
        ),
        _confirmRow(
          '대상 고객',
          WorkInstructionWorkshopPresentation.humanizeAudienceOrField(
            _state.targetCustomer,
          ),
          _state.customerStatus,
        ),
        _confirmRow(
          '선택 컨셉',
          selected.isEmpty ? '(없음)' : selected.map((c) => c.title).join(' · '),
          selected.isEmpty
              ? DesignFieldStatus.undecided
              : DesignFieldStatus.userSelected,
        ),
        _confirmRow('핵심 문제', _state.customerProblem, _state.problemStatus),
        _confirmRow('프로젝트 목적', _state.desiredOutcome, _state.outcomeStatus),
        _confirmRow('주제', _state.topic, _state.topicStatus),
        _confirmRow(
          '표시 제목',
          _state.displayTitle.trim().isEmpty
              ? (_state.topic.trim().isEmpty ? '(미정)' : _state.topic)
              : _state.displayTitle,
          _state.planningConfirmed
              ? DesignFieldStatus.userConfirmed
              : DesignFieldStatus.suggested,
        ),
        _confirmRow(
          '제작 방식',
          _creationModeSummary(),
          DesignFieldStatus.userSelected,
        ),
        if (_state.originalUserBrief.trim().isNotEmpty)
          _confirmRow(
            '원본 요약',
            _truncate(_state.originalUserBrief),
            _state.originalUserBriefConfirmed
                ? DesignFieldStatus.userConfirmed
                : DesignFieldStatus.userEdited,
          ),
        _confirmRow(
          'AI 제안 수락',
          '${_state.acceptedAiSuggestions.length}건',
          _state.acceptedAiSuggestions.isEmpty
              ? DesignFieldStatus.undecided
              : DesignFieldStatus.userSelected,
        ),
        _confirmRow(
          'AI 제안 거절',
          '${_state.rejectedAiSuggestions.length}건',
          _state.rejectedAiSuggestions.isEmpty
              ? DesignFieldStatus.undecided
              : DesignFieldStatus.userSelected,
        ),
        if (_state.uniqueValue.trim().isNotEmpty)
          _confirmRow(
            '차별 가치',
            _state.uniqueValue,
            DesignFieldStatus.userEdited,
          ),
        if (_state.reasonsToPay.isNotEmpty)
          _confirmRow(
            '구매·이용 이유',
            _state.reasonsToPay.join('\n'),
            DesignFieldStatus.userEdited,
          ),
        _confirmRow('외부 공개', '금지', DesignFieldStatus.userConfirmed),
        _confirmRow(
          '품질 검토',
          '사용자 품질 검토 · owner review 필수',
          DesignFieldStatus.userConfirmed,
        ),
        if (_state.combinedDirection.isNotEmpty)
          _confirmRow(
            '차별화·결합 방향',
            _state.combinedDirection,
            DesignFieldStatus.suggested,
          ),
        if (_state.designMemo.trim().isNotEmpty)
          _confirmRow(
            '사용자 메모',
            _state.designMemo,
            DesignFieldStatus.userEdited,
          ),
        const SizedBox(height: 12),
        StudioWorkflowPreviewPanel(
          artifactType: _state.artifactType ?? '',
          contentSubtype: _state.contentSubtype ?? '',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            final confirmed = _engine.confirmPlanning(_state);
            _emit(confirmed);
          },
          icon: Icon(
            _state.planningConfirmed
                ? Icons.verified
                : Icons.check_circle_outline,
          ),
          label: Text(_state.planningConfirmed ? '기획 확정 완료' : '이 내용으로 최종 확정'),
        ),
        if (!_state.planningConfirmed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '확정 전에는 다음 단계로 이동할 수 없습니다.',
              style: TextStyle(fontSize: 12, color: ControlColors.accentWarm),
            ),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ControlColors.tealSoft.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ControlColors.border),
          ),
          child: Text(
            '종합 판정: ${report.verdictLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        for (final insight in report.insights.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '· ${insight.title}: ${insight.body}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _confirmRow(String label, String value, DesignFieldStatus status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textMuted,
                  ),
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(value.trim().isEmpty ? '(미정)' : value),
        ],
      ),
    );
  }

  Widget _buildFinalizeStep() {
    final synced = _state.copy();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          synced.planningConfirmed
              ? '확정된 기획으로 작업지시서를 생성합니다.'
              : '최종 기획 확인 단계에서 확정이 필요합니다.',
          style: const TextStyle(
            fontSize: 13,
            color: ControlColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _kv('결과물', ArtifactType.labelKo(synced.artifactType ?? '')),
        _kv('대상 고객', synced.targetCustomer),
        _kv('주제', synced.topic),
        _kv('핵심 문제', synced.customerProblem),
        _kv('기대 결과', synced.desiredOutcome),
        _kv('확정', synced.planningConfirmed ? '사용자 확정' : '미확정 (생성 불가)'),
        _kv('파이프라인', _pipelinePhaseLabel(synced.studioPipelinePhase)),
        _kv('로컬 검증', synced.commercialLocalValidated ? '완료' : '미완료'),
        if (synced.designMemo.trim().isNotEmpty)
          _kv('추가 메모', synced.designMemo),
        const SizedBox(height: 12),
        Builder(
          builder: (_) {
            final kind = InstructionCreateUx.kind(
              generated: widget.instructionGenerated,
              stale: widget.instructionStale,
            );
            final canValidate =
                widget.instructionGenerated && synced.planningConfirmed;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('planning_create_instruction'),
                  onPressed:
                      InstructionCreateUx.enabled(
                        kind,
                        canCreate: synced.canCreateInstruction,
                      )
                      ? () {
                          _emit(synced);
                          if (kind == InstructionCreateButtonKind.recreate) {
                            (widget.onRequestRecreateInstruction ??
                                    widget.onRequestCreateInstruction)
                                ?.call();
                          } else {
                            widget.onRequestCreateInstruction?.call();
                          }
                        }
                      : null,
                  icon: Icon(
                    kind == InstructionCreateButtonKind.completed
                        ? Icons.check_circle_outline
                        : Icons.description_outlined,
                    size: 18,
                  ),
                  label: Text(InstructionCreateUx.label(kind)),
                ),
                OutlinedButton.icon(
                  key: const Key('planning_local_validate'),
                  onPressed:
                      canValidate && widget.onRequestLocalValidate != null
                      ? () {
                          _emit(synced);
                          widget.onRequestLocalValidate?.call();
                        }
                      : null,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('로컬 상용 검증'),
                ),
                if (widget.onRequestTransfer != null &&
                    synced.commercialLocalValidated)
                  OutlinedButton.icon(
                    onPressed: synced.canSendAfterLocalValidate
                        ? () {
                            _emit(synced);
                            widget.onRequestTransfer?.call();
                          }
                        : null,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('전송 준비'),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    _emit(synced);
                    widget.onRequestSavePlan?.call();
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('기획안만 저장'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildNav() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            if (widget.onRequestNewWork != null) {
              widget.onRequestNewWork!();
              return;
            }
            _emit(ProjectDesignState());
            _syncControllers();
            _review = null;
          },
          child: const Text('취소'),
        ),
        OutlinedButton(
          onPressed: _state.step > 0 ? _goBack : null,
          child: const Text('이전'),
        ),
        if (_state.step < ProjectDesignStep.finalize)
          FilledButton(
            onPressed: _canGoNext() ? _goNext : null,
            child: const Text('다음'),
          ),
      ],
    );
  }
}

class _CreationModeCard extends StatelessWidget {
  const _CreationModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ControlColors.tealSoft.withValues(alpha: 0.35)
          : ControlColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? ControlColors.teal : ControlColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ControlColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtifactSelectCard extends StatelessWidget {
  const _ArtifactSelectCard({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.selectedKey,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Key? selectedKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: selectedKey,
      color: selected
          ? ControlColors.tealSoft.withValues(alpha: 0.45)
          : ControlColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? ControlColors.teal : ControlColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: ControlColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ControlColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: ControlColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}
