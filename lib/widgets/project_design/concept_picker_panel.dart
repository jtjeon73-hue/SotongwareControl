import 'package:flutter/material.dart';

import '../../data/concept_catalog.dart';
import '../../models/concept_candidate.dart';
import '../../services/concept_recommendation_provider.dart';
import '../../services/work_instruction_concept_occupancy.dart';
import '../../theme/control_theme.dart';

/// Concept recommendation picker — TOP10 / category / search / expand / user add.
class ConceptPickerPanel extends StatefulWidget {
  const ConceptPickerPanel({
    super.key,
    required this.candidates,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onAddUserConcept,
    this.userAdded = const [],
    this.occupancy,
    this.artifactType = '',
    this.audiences = const [],
    this.onOccupiedTap,
  });

  final List<ConceptCandidate> candidates;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final void Function(String title, String memo) onAddUserConcept;
  final List<ConceptCandidate> userAdded;
  final ConceptOccupancyIndex? occupancy;
  final String artifactType;
  final List<String> audiences;
  final void Function(ConceptOccupancyView view)? onOccupiedTap;

  @override
  State<ConceptPickerPanel> createState() => _ConceptPickerPanelState();
}

class _ConceptPickerPanelState extends State<ConceptPickerPanel> {
  String _category = 'all';
  String _search = '';
  bool _showAll = false;
  final _searchCtrl = TextEditingController();
  final _ideaTitleCtrl = TextEditingController();
  final _ideaMemoCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ideaTitleCtrl.dispose();
    _ideaMemoCtrl.dispose();
    super.dispose();
  }

  List<ConceptCandidate> get _filtered {
    var list = [...widget.userAdded, ...widget.candidates];
    // de-dupe by id
    final seen = <String>{};
    list = [
      for (final c in list)
        if (seen.add(c.id)) c,
    ];
    if (_category != 'all') {
      list = list.where((c) => c.category == _category).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.title.toLowerCase().contains(q) ||
            c.shortDescription.toLowerCase().contains(q) ||
            c.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }
    list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return list;
  }

  void _toggle(String id, bool on) {
    final occ = _occupancyForId(id);
    if (occ.isOccupied) {
      widget.onOccupiedTap?.call(occ);
      return;
    }
    final next = List<String>.from(widget.selectedIds);
    if (on) {
      if (!next.contains(id)) next.add(id);
    } else {
      next.remove(id);
    }
    widget.onSelectionChanged(next);
  }

  ConceptOccupancyView _occupancyForId(String id) {
    final index = widget.occupancy;
    if (index == null) return ConceptOccupancyView.available;
    ConceptCandidate? concept;
    for (final c in [...widget.userAdded, ...widget.candidates]) {
      if (c.id == id) {
        concept = c;
        break;
      }
    }
    if (concept != null) {
      return index.viewForCandidate(
        concept,
        artifactType: widget.artifactType,
        audiences: widget.audiences,
      );
    }
    return index.viewFor(
      conceptId: id,
      artifactType: widget.artifactType,
      audiences: widget.audiences,
    );
  }

  Future<void> _openAddIdea() async {
    _ideaTitleCtrl.clear();
    _ideaMemoCtrl.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내 아이디어 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ideaTitleCtrl,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ideaMemoCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (ok == true && _ideaTitleCtrl.text.trim().isNotEmpty) {
      widget.onAddUserConcept(
        _ideaTitleCtrl.text.trim(),
        _ideaMemoCtrl.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final top10 = filtered.take(10).toList();
    final visible = _showAll ? filtered.take(50).toList() : top10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AI 추천 TOP ${top10.length.clamp(0, 10)} · 내부 추천 평가 '
          '(시장점유율·판매확률 수치가 아닙니다)',
          style: const TextStyle(
            fontSize: 12.5,
            color: ControlColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Tooltip(
          message: LocalConceptRecommendationProvider.scoreDisclaimer,
          child: const Text(
            '점수 안내 ⓘ',
            style: TextStyle(fontSize: 11, color: ControlColors.textMuted),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: '컨셉 검색 (예: PLC, 부업, 건강, 귀촌)',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _category == 'all',
                onSelected: (_) => setState(() => _category = 'all'),
              ),
              const SizedBox(width: 6),
              for (final cat in ConceptCategory.all)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(ConceptCategory.labelKo(cat)),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Text(
            '조건에 맞는 추천이 없습니다. 검색어를 바꾸거나 아이디어를 직접 추가하세요.',
            style: TextStyle(color: ControlColors.textMuted),
          )
        else
          for (var i = 0; i < visible.length; i++)
            _ConceptCard(
              rank: i + 1,
              concept: visible[i],
              selected: widget.selectedIds.contains(visible[i].id),
              occupancy: _occupancyForId(visible[i].id),
              onChanged: (on) => _toggle(visible[i].id, on),
            ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll ? Icons.unfold_less : Icons.unfold_more),
              label: Text(
                _showAll
                    ? 'TOP10만 보기'
                    : '전체 추천 보기 (${filtered.length.clamp(0, 50)})',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _openAddIdea,
              icon: const Icon(Icons.add),
              label: const Text('내 아이디어 추가'),
            ),
          ],
        ),
        if (widget.selectedIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '선택 ${widget.selectedIds.length}개 · 복수 선택 가능',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({
    required this.rank,
    required this.concept,
    required this.selected,
    required this.onChanged,
    this.occupancy = ConceptOccupancyView.available,
  });

  final int rank;
  final ConceptCandidate concept;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final ConceptOccupancyView occupancy;

  @override
  Widget build(BuildContext context) {
    final occupied = occupancy.isOccupied;
    return Card(
      key: Key('planning_concept_card_${concept.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? ControlColors.tealSoft.withValues(alpha: 0.35) : null,
      child: InkWell(
        onTap: occupied ? () => onChanged(false) : () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected && !occupied,
                    onChanged: occupied ? null : (v) => onChanged(v == true),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              concept.isUserAdded
                                  ? concept.title
                                  : '$rank. ${concept.title}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: occupied
                                    ? ControlColors.textSecondary
                                    : ControlColors.textPrimary,
                              ),
                            ),
                            if (occupancy.badgeLabel.isNotEmpty)
                              _OccupancyBadge(view: occupancy),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          concept.shortDescription,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: ControlColors.textSecondary,
                          ),
                        ),
                        if (_recommendationLine(concept).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _recommendationLine(concept),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: ControlColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (concept.deprecated) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ControlColors.warningBg.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ControlColors.accentWarm),
                            ),
                            child: Text(
                              _deprecatedWarning(concept),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ControlColors.accentWarm,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip(ConceptCategory.labelKo(concept.category)),
                  _chip('적합 ${bandLabelKo(concept.fitBand)}'),
                  _chip('AI ${bandLabelKo(concept.aiBand)}'),
                  _chip('실용 ${bandLabelKo(concept.practicalBand)}'),
                  _chip('사업 ${bandLabelKo(concept.businessBand)}'),
                  _chip('난이도 ${bandStars(concept.difficultyBand)}'),
                  if (concept.isUserAdded) _chip('내 아이디어'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _recommendationLine(ConceptCandidate concept) {
    final reason = concept.recommendationReason.trim();
    if (reason.isNotEmpty) return reason;
    return concept.whyRecommended.trim();
  }

  static String _deprecatedWarning(ConceptCandidate concept) {
    final replacement = _replacementLabel(concept.replacementSeedId);
    if (replacement.isNotEmpty) {
      return '이 아이디어는 더 이상 권장되지 않습니다. '
          '대신 「$replacement」 컨셉을 선택하거나, '
          '기존 결과물 보완(리비전)을 우선 검토하세요.';
    }
    return '이 아이디어는 더 이상 권장되지 않습니다. '
        '대체 컨셉을 선택하거나 기존 결과물 보완(리비전)을 우선 검토하세요.';
  }

  static String _replacementLabel(String? seedId) {
    final id = (seedId ?? '').trim();
    if (id.isEmpty) return '';
    for (final seed in ConceptCatalog.seeds) {
      if (seed.id != id) continue;
      final commercial = seed.commercial;
      if (commercial != null && commercial.shortDescription.trim().isNotEmpty) {
        return commercial.shortDescription.trim();
      }
      final variant = seed.variants.values.firstOrNull;
      if (variant != null && variant.$1.trim().isNotEmpty) {
        return variant.$1.trim();
      }
      break;
    }
    return id.replaceAll('_', ' ');
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: ControlColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _OccupancyBadge extends StatelessWidget {
  const _OccupancyBadge({required this.view});

  final ConceptOccupancyView view;

  @override
  Widget build(BuildContext context) {
    final inProgress = view.state == ConceptWorkState.inProgress;
    return Container(
      key: Key(
        inProgress
            ? 'planning_concept_badge_in_progress'
            : 'planning_concept_badge_completed',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: inProgress ? ControlColors.warningBg : ControlColors.tealSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: inProgress ? ControlColors.accentWarm : ControlColors.teal,
        ),
      ),
      child: Text(
        view.badgeLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: inProgress ? ControlColors.accentWarm : ControlColors.teal,
        ),
      ),
    );
  }
}
