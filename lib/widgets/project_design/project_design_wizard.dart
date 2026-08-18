import 'package:flutter/material.dart';

import '../../data/project_design_catalog.dart';
import '../../models/artifact_type.dart';
import '../../models/concept_candidate.dart';
import '../../models/project_design_state.dart';
import '../../services/project_design_engine.dart';
import '../../theme/control_theme.dart';
import 'concept_picker_panel.dart';

/// Project Design Engine Wizard (STEP 0~6).
class ProjectDesignWizard extends StatefulWidget {
  const ProjectDesignWizard({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onRequestCreateInstruction,
    this.onRequestSavePlan,
  });

  final ProjectDesignState initial;
  final ValueChanged<ProjectDesignState> onChanged;
  final VoidCallback? onRequestCreateInstruction;
  final VoidCallback? onRequestSavePlan;

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
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    _customAudienceCtrl.dispose();
    _topicCtrl.dispose();
    _problemCtrl.dispose();
    _outcomeCtrl.dispose();
    super.dispose();
  }

  void _emit(ProjectDesignState next) {
    setState(() => _state = next);
    widget.onChanged(next);
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
          '만들고 싶은 사업유형을 선택하세요. 선택 전에는 다음 단계로 이동할 수 없습니다.',
          style: TextStyle(fontSize: 13, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cards = ProjectDesignCatalog.artifactCards;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 20) / 3
                        : constraints.maxWidth,
                    child: _ArtifactSelectCard(
                      key: ValueKey('artifact-${card.id}'),
                      selected: _state.artifactType == card.id,
                      title: card.title,
                      subtitle: card.subtitle,
                      icon: _artifactIcon(card.iconName),
                      onTap: () {
                        final next = _state.copy()
                          ..artifactType = card.id
                          ..contentSubtype = card.id == ArtifactType.contents
                              ? _state.contentSubtype
                              : null;
                        _emit(next);
                      },
                    ),
                  ),
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
                    _emit(_state.copy()..contentSubtype = opt.id);
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
          onSelectionChanged: (ids) {
            var next = _state.copy()..selectedConceptIds = ids;
            next.planningConfirmed = false;
            next = _engine.syncSentences(next);
            _topicCtrl.text = next.topic;
            _problemCtrl.text = next.customerProblem;
            _outcomeCtrl.text = next.desiredOutcome;
            _emit(next);
          },
          onAddUserConcept: (title, memo) {
            final added = ConceptCandidate.userAdded(
              title: title,
              memo: memo,
              artifactType: _state.artifactType ?? '',
              audiences: _state.selectedAudiences,
            );
            var next = _state.copy();
            next.userAddedConcepts = [...next.userAddedConcepts, added];
            next.selectedConceptIds = [...next.selectedConceptIds, added.id];
            next.planningConfirmed = false;
            next = _engine.syncSentences(next);
            _topicCtrl.text = next.topic;
            _problemCtrl.text = next.customerProblem;
            _outcomeCtrl.text = next.desiredOutcome;
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
      ],
    );
  }

  Widget _buildProductionStep() {
    final groups = ProjectDesignCatalog.productionGroupsFor(
      _state.artifactType ?? '',
    );
    if (groups.isEmpty) {
      return const Text('이 결과물은 추가 제작 정보가 필수는 아닙니다. 다음으로 진행하세요.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        _confirmRow('대상 고객', _state.targetCustomer, _state.customerStatus),
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
        if (synced.designMemo.trim().isNotEmpty)
          _kv('추가 메모', synced.designMemo),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: synced.canCreateInstruction
                  ? () {
                      _emit(synced);
                      widget.onRequestCreateInstruction?.call();
                    }
                  : null,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('작업지시서 생성'),
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

class _ArtifactSelectCard extends StatelessWidget {
  const _ArtifactSelectCard({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
