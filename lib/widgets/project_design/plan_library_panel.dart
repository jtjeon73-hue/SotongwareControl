import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/business_planning.dart';
import '../../services/plan_library_management.dart';
import '../../services/plan_user_facing_status.dart';
import '../../theme/control_theme.dart';

export '../../services/plan_library_management.dart' show PlanLibraryBulkAction;

enum PlanLibraryViewMode { cards, list, table }

enum PlanLibrarySort { newest, name, updated, status, artifact }

/// 저장된 기획 관리 — 폴더·검색·보기·정렬·관리모드.
class PlanLibraryPanel extends StatefulWidget {
  const PlanLibraryPanel({
    super.key,
    required this.plans,
    required this.activePlanId,
    required this.folderFilter,
    required this.searchQuery,
    required this.viewMode,
    required this.sort,
    required this.onFolderChanged,
    required this.onSearchChanged,
    required this.onViewModeChanged,
    required this.onSortChanged,
    required this.onOpenPlan,
    required this.onToggleFavorite,
    required this.onStartNew,
    required this.onBulkAction,
    this.duplicateTopics = const {},
  });

  final List<BusinessPlanDocument> plans;
  final String? activePlanId;
  final String folderFilter;
  final String searchQuery;
  final PlanLibraryViewMode viewMode;
  final PlanLibrarySort sort;
  final ValueChanged<String> onFolderChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PlanLibraryViewMode> onViewModeChanged;
  final ValueChanged<PlanLibrarySort> onSortChanged;
  final ValueChanged<BusinessPlanDocument> onOpenPlan;
  final ValueChanged<BusinessPlanDocument> onToggleFavorite;
  final VoidCallback onStartNew;
  final Future<void> Function(
    PlanLibraryBulkAction action,
    List<BusinessPlanDocument> selected,
  )
  onBulkAction;
  final Set<String> duplicateTopics;

  @override
  State<PlanLibraryPanel> createState() => _PlanLibraryPanelState();
}

class _PlanLibraryPanelState extends State<PlanLibraryPanel> {
  bool _manageMode = false;
  bool _showDuplicates = false;
  final Set<String> _selectedIds = {};

  @override
  void didUpdateWidget(PlanLibraryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderFilter != widget.folderFilter) {
      _clearSelection();
    }
  }

  PlanLibraryBulkAction get _primarySelectionAction =>
      PlanLibraryManagement.primarySelectionActionForFilter(widget.folderFilter);

  bool _canSelect(BusinessPlanDocument plan) {
    return PlanLibraryManagement.isSelectableForBulkAction(
      plan,
      _primarySelectionAction,
      activePlanId: widget.activePlanId,
    );
  }

  List<PlanDuplicateGroup> get _duplicateGroups =>
      PlanLibraryManagement.findDuplicateGroups(widget.plans);

  Set<String> get _duplicateIds =>
      PlanLibraryManagement.duplicateCandidateIdSet(_duplicateGroups);

  List<BusinessPlanDocument> get _filtered {
    var list = List<BusinessPlanDocument>.from(widget.plans);
    final manageFilters = {
      'all',
      'active',
      'waiting',
      'in_progress',
      'instruction_created',
      'transferred',
      'completed',
      'archived',
      'trashed',
      'duplicate_candidates',
      'stale',
      'cleanup',
      'favorite',
    };

    if (manageFilters.contains(widget.folderFilter)) {
      list = PlanLibraryManagement.applyManageFilter(
        list,
        widget.folderFilter,
        duplicateCandidateIds: _duplicateIds,
      );
    } else {
      list = list.where((p) => PlanLibraryManagement.isOperationalListEntry(p)).toList();
      list = list.where((p) {
        final folder = p.libraryFolder.isNotEmpty
            ? p.libraryFolder
            : ArtifactType.normalize(p.input.resolvedArtifactType);
        return folder == widget.folderFilter;
      }).toList();
    }

    // 목록 identity = planId (dedupeById). instructionId로 카드를 합치지 않는다.
    // 동일 plan의 WI 재생성은 같은 plan 문서의 version/history로 유지된다.

    final q = widget.searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        final status = PlanUserFacingStatus.label(p).toLowerCase();
        final artifact = ArtifactType.labelKo(
          p.input.resolvedArtifactType,
        ).toLowerCase();
        final tags = p.tags.join(' ').toLowerCase();
        final iid = p.stableInstructionId.toLowerCase();
        return PlanLibraryManagement.displayTitle(p).toLowerCase().contains(q) ||
            p.input.topic.toLowerCase().contains(q) ||
            p.input.targetCustomer.toLowerCase().contains(q) ||
            p.input.customerProblem.toLowerCase().contains(q) ||
            status.contains(q) ||
            artifact.contains(q) ||
            tags.contains(q) ||
            iid.contains(q) ||
            p.createdAt.toLowerCase().contains(q) ||
            p.updatedAt.toLowerCase().contains(q);
      }).toList();
    }

    list.sort((a, b) {
      switch (widget.sort) {
        case PlanLibrarySort.name:
          return PlanLibraryManagement.displayTitle(a)
              .compareTo(PlanLibraryManagement.displayTitle(b));
        case PlanLibrarySort.updated:
          return b.updatedAt.compareTo(a.updatedAt);
        case PlanLibrarySort.status:
          return a.status.compareTo(b.status);
        case PlanLibrarySort.artifact:
          return a.input.resolvedArtifactType.compareTo(
            b.input.resolvedArtifactType,
          );
        case PlanLibrarySort.newest:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return list;
  }

  List<BusinessPlanDocument> get _selectedPlans {
    final byId = {for (final p in widget.plans) p.id: p};
    return _selectedIds
        .map((id) => byId[id])
        .whereType<BusinessPlanDocument>()
        .toList();
  }

  bool get _inTrashView => widget.folderFilter == 'trashed';

  bool get _inArchivedView => widget.folderFilter == 'archived';

  Color _statusColor(String status) {
    switch (PlanningStatus.normalize(status)) {
      case PlanningStatus.completed:
        return ControlColors.accentGreen;
      case PlanningStatus.archived:
        return ControlColors.textMuted;
      case PlanningStatus.transferred:
      case PlanningStatus.imported:
        return ControlColors.teal;
      case PlanningStatus.inProgress:
        return ControlColors.sandBeige;
      default:
        return ControlColors.border;
    }
  }

  String _statusBadge(BusinessPlanDocument p) => PlanUserFacingStatus.label(p);

  String _formatIso(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('yyyy-MM-dd').format(dt.toLocal());
  }

  void _toggleSelect(String id) {
    final byId = {for (final p in widget.plans) p.id: p};
    final plan = byId[id];
    if (plan != null && !_canSelect(plan)) {
      return;
    }
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(
          _filtered.where(_canSelect).map((p) => p.id),
        );
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  String _titleOf(BusinessPlanDocument plan) {
    return PlanLibraryManagement.displayTitle(plan);
  }

  Future<void> _runBulk(PlanLibraryBulkAction action) async {
    var selected = _selectedPlans;
    if (selected.isEmpty) return;

    if (action == PlanLibraryBulkAction.archive) {
      final blocked = selected
          .where(
            (p) => PlanLibraryManagement.isBulkArchiveBlocked(
              p,
              activePlanId: widget.activePlanId,
            ),
          )
          .toList();
      selected = selected
          .where(
            (p) => !PlanLibraryManagement.isBulkArchiveBlocked(
              p,
              activePlanId: widget.activePlanId,
            ),
          )
          .toList();
      if (selected.isEmpty) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('보관할 수 없음'),
            content: Text(
              blocked.isEmpty
                  ? '선택한 기획을 보관할 수 없습니다.'
                  : '선택한 기획은 보호·운영 상태라 일괄 보관할 수 없습니다.\n'
                      '(${blocked.map((p) => PlanLibraryManagement.bulkArchiveBlockReason(p, activePlanId: widget.activePlanId)).toSet().join(', ')})',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('선택 항목 보관'),
          content: Text(
            blocked.isEmpty
                ? '선택한 ${selected.length}개의 기획을 보관하시겠습니까?'
                : '선택한 ${selected.length}개의 기획을 보관하시겠습니까?\n'
                    '보호·운영 기획 ${blocked.length}건은 제외됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('보관'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await widget.onBulkAction(action, selected);
      if (mounted) _clearSelection();
      return;
    }

    if (action == PlanLibraryBulkAction.trash) {
      final protected = selected.where((p) => p.isProtected).toList();
      if (protected.isNotEmpty) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('보호된 기획'),
            content: Text(
              '보호됨 상태인 기획 ${protected.length}건은 휴지통으로 이동할 수 없습니다.\n'
              '보호 해제 후 다시 시도하세요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (action == PlanLibraryBulkAction.permanentDelete) {
      final ok = await _confirmPermanentDelete(selected);
      if (!ok) return;
    }

    selected = selected
        .where(
          (p) => PlanLibraryManagement.isSelectableForBulkAction(
            p,
            action,
            activePlanId: widget.activePlanId,
          ),
        )
        .toList();
    if (selected.isEmpty) return;

    await widget.onBulkAction(action, selected);
    if (mounted) _clearSelection();
  }

  Future<bool> _confirmPermanentDelete(
    List<BusinessPlanDocument> selected,
  ) async {
    final warnings = <String>[];
    for (final p in selected) {
      final w = PlanLibraryManagement.permanentDeleteWarnings(
        p,
        activePlanId: widget.activePlanId,
      );
      if (w.hasStrongWarning) {
        final title = PlanLibraryManagement.displayTitle(p);
        warnings.add('· $title — ${w.reasons.join(', ')}');
      }
    }

    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영구 삭제 확인'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '선택한 ${selected.length}개의 기획안을 영구 삭제합니다.\n'
                '이 작업은 되돌릴 수 없습니다.\n\n'
                '※ 기획 라이브러리 레코드만 삭제됩니다.\n'
                'DevWorkDoc · Inbox · 작업지시 JSON · 외부 파일은 삭제되지 않습니다.',
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '주의가 필요한 항목:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(warnings.join('\n')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ControlColors.accentRose,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _badge(BusinessPlanDocument p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(p.status).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _statusColor(p.status)),
      ),
      child: Text(
        _statusBadge(p),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _metaChip(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 11, color: ControlColors.textMuted),
    );
  }

  List<Widget> _cardMeta(BusinessPlanDocument p) {
    final artifact = ArtifactType.labelKo(p.input.resolvedArtifactType);
    final status = _statusBadge(p);
    return [
      Text(
        '$artifact · $status',
        style: const TextStyle(fontSize: 13, color: ControlColors.textSecondary),
      ),
      Text(
        '최근 수정 ${_formatIso(p.updatedAt)}',
        style: const TextStyle(fontSize: 12, color: ControlColors.textMuted),
      ),
      Text(
        '작업지시 ${p.stableInstructionId.isEmpty ? '없음' : p.stableInstructionId}',
        style: const TextStyle(fontSize: 12, color: ControlColors.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (p.isProtected || p.favorite)
        Wrap(
          spacing: 8,
          children: [
            if (p.isProtected) _metaChip('보호됨'),
            if (p.favorite) _metaChip('★'),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '저장된 기획',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _manageMode = !_manageMode;
                  if (!_manageMode) {
                    _selectedIds.clear();
                    _showDuplicates = false;
                  }
                });
              },
              icon: Icon(_manageMode ? Icons.close : Icons.tune, size: 18),
              label: Text(_manageMode ? '관리 종료' : '관리'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: widget.onStartNew,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 기획'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in PlanUserFacingStatus.primaryFilters)
              ChoiceChip(
                label: Text(PlanUserFacingStatus.primaryFilterLabel(id)),
                selected: widget.folderFilter == id ||
                    (id == 'active' && widget.folderFilter == 'in_progress'),
                onSelected: (_) {
                  widget.onFolderChanged(id);
                  _clearSelection();
                },
              ),
          ],
        ),
        if (_manageMode) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in PlanUserFacingStatus.advancedFilters)
                FilterChip(
                  label: Text(PlanUserFacingStatus.advancedFilterLabel(id)),
                  selected: widget.folderFilter == id,
                  onSelected: (_) {
                    widget.onFolderChanged(id);
                    _clearSelection();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildManageToolbar(visible),
        ],
        const SizedBox(height: 10),
        TextField(
          onChanged: widget.onSearchChanged,
          decoration: const InputDecoration(
            hintText: '제목·고객·작업지시 ID 검색',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        if (_manageMode || MediaQuery.sizeOf(context).width >= 700)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_manageMode)
                  SegmentedButton<PlanLibraryViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: PlanLibraryViewMode.cards,
                        icon: Icon(Icons.grid_view, size: 16),
                        label: Text('카드'),
                      ),
                      ButtonSegment(
                        value: PlanLibraryViewMode.list,
                        icon: Icon(Icons.view_list, size: 16),
                        label: Text('리스트'),
                      ),
                      ButtonSegment(
                        value: PlanLibraryViewMode.table,
                        icon: Icon(Icons.table_rows, size: 16),
                        label: Text('테이블'),
                      ),
                    ],
                    selected: {widget.viewMode},
                    onSelectionChanged: (s) =>
                        widget.onViewModeChanged(s.first),
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(width: 12),
                DropdownButton<PlanLibrarySort>(
                  value: widget.sort,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: PlanLibrarySort.newest,
                      child: Text('최신순'),
                    ),
                    DropdownMenuItem(
                      value: PlanLibrarySort.name,
                      child: Text('이름순'),
                    ),
                    DropdownMenuItem(
                      value: PlanLibrarySort.updated,
                      child: Text('수정순'),
                    ),
                    DropdownMenuItem(
                      value: PlanLibrarySort.status,
                      child: Text('상태순'),
                    ),
                    DropdownMenuItem(
                      value: PlanLibrarySort.artifact,
                      child: Text('결과물순'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) widget.onSortChanged(v);
                  },
                ),
              ],
            ),
          ),
        if (_showDuplicates) ...[
          const SizedBox(height: 12),
          _buildDuplicatePanel(),
        ],
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '표시할 기획안이 없습니다.',
              style: TextStyle(color: ControlColors.textMuted),
            ),
          )
        else
          switch (_effectiveViewMode(context)) {
            PlanLibraryViewMode.cards => _buildCards(visible),
            PlanLibraryViewMode.list => _buildList(visible),
            PlanLibraryViewMode.table => _buildTable(visible),
          },
      ],
    );
  }

  PlanLibraryViewMode _effectiveViewMode(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 700) {
      return PlanLibraryViewMode.cards;
    }
    return widget.viewMode;
  }

  Widget _buildManageToolbar(List<BusinessPlanDocument> visible) {
    return Material(
      color: ControlColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '선택 ${_selectedIds.length}개',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: visible.isEmpty ? null : _selectAllVisible,
                  child: const Text('전체 선택'),
                ),
                TextButton(
                  onPressed: _selectedIds.isEmpty ? null : _clearSelection,
                  child: const Text('선택 해제'),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _showDuplicates = !_showDuplicates);
                    if (_showDuplicates) {
                      widget.onFolderChanged('duplicate_candidates');
                    }
                  },
                  child: Text(_showDuplicates ? '중복 패널 닫기' : '중복 정리'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_inArchivedView) ...[
                  FilledButton.tonal(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.unarchive),
                    child: const Text('선택 항목 보관 해제'),
                  ),
                ] else if (_inTrashView) ...[
                  FilledButton.tonal(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.restore),
                    child: const Text('선택 항목 복원'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ControlColors.accentRose,
                    ),
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.permanentDelete),
                    child: const Text('영구 삭제'),
                  ),
                ] else ...[
                  FilledButton.tonal(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.archive),
                    child: const Text('선택 항목 보관'),
                  ),
                  FilledButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.trash),
                    child: const Text('휴지통으로 이동'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.favorite),
                    child: const Text('즐겨찾기'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.unfavorite),
                    child: const Text('즐겨찾기 해제'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.protect),
                    child: const Text('보호'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _runBulk(PlanLibraryBulkAction.unprotect),
                    child: const Text('보호 해제'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicatePanel() {
    final groups = _duplicateGroups;
    if (groups.isEmpty) {
      return const Text(
        '중복 후보가 없습니다.',
        style: TextStyle(color: ControlColors.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '중복 후보 ${_duplicateGroups.length}그룹 (자동 삭제하지 않습니다)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < groups.length; i++)
          _duplicateGroupCard(i + 1, groups[i]),
      ],
    );
  }

  Widget _duplicateGroupCard(int index, PlanDuplicateGroup group) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ControlColors.border),
        borderRadius: BorderRadius.circular(8),
        color: ControlColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '중복 후보 그룹 $index'
            '${group.strongChecksumMatch ? ' · 동일 checksum' : ' · 제목·결과물·고객 유사'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(group.title, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 6),
          for (final p in group.plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '· ${_formatIso(p.updatedAt)}'
                ' · ${PlanLibraryManagement.shortId(p.stableInstructionId)}'
                ' · ${_statusBadge(p)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedIds
                      ..clear()
                      ..add(group.newest.id);
                    _manageMode = true;
                  });
                },
                child: const Text('최신 선택'),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedIds
                      ..clear()
                      ..addAll(group.plans.map((p) => p.id));
                    _manageMode = true;
                  });
                },
                child: const Text('직접 선택(전체)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCards(List<BusinessPlanDocument> list) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 700;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in list)
              SizedBox(
                width: wide ? (c.maxWidth - 10) / 2 : c.maxWidth,
                child: Material(
                  color: p.id == widget.activePlanId
                      ? ControlColors.tealSoft.withValues(alpha: 0.35)
                      : ControlColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (_manageMode) {
                        _toggleSelect(p.id);
                      } else {
                        widget.onOpenPlan(p);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedIds.contains(p.id)
                              ? ControlColors.teal
                              : ControlColors.border,
                          width: _selectedIds.contains(p.id) ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_manageMode)
                                Checkbox(
                                  value: _selectedIds.contains(p.id),
                                  onChanged: _canSelect(p)
                                      ? (_) => _toggleSelect(p.id)
                                      : null,
                                ),
                              Expanded(
                                child: Text(
                                  _titleOf(p),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_manageMode)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => widget.onToggleFavorite(p),
                                  icon: Icon(
                                    p.favorite ? Icons.star : Icons.star_border,
                                    size: 20,
                                    color: p.favorite
                                        ? ControlColors.sandBeige
                                        : ControlColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _badge(p),
                          const SizedBox(height: 6),
                          ..._cardMeta(p),
                          const SizedBox(height: 8),
                          if (!_manageMode)
                            Wrap(
                              spacing: 6,
                              children: [
                                TextButton(
                                  onPressed: () => widget.onOpenPlan(p),
                                  child: const Text('열기'),
                                ),
                                if (p.hasInstruction)
                                  TextButton(
                                    onPressed: () => widget.onOpenPlan(p),
                                    child: const Text('작업지시 보기'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildList(List<BusinessPlanDocument> list) {
    return Column(
      children: [
        for (final p in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: p.id == widget.activePlanId,
            leading: _manageMode
                ? Checkbox(
                    value: _selectedIds.contains(p.id),
                    onChanged: _canSelect(p)
                        ? (_) => _toggleSelect(p.id)
                        : null,
                  )
                : null,
            title: Text(
              _titleOf(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${ArtifactType.labelKo(p.input.resolvedArtifactType)} · '
              '${_statusBadge(p)} · ${_formatIso(p.updatedAt)}\n'
              '${p.stableInstructionId.isEmpty ? '작업지시 없음' : p.stableInstructionId}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: _manageMode
                ? null
                : IconButton(
                    onPressed: () => widget.onToggleFavorite(p),
                    icon: Icon(p.favorite ? Icons.star : Icons.star_border),
                  ),
            onTap: () {
              if (_manageMode) {
                _toggleSelect(p.id);
              } else {
                widget.onOpenPlan(p);
              }
            },
          ),
      ],
    );
  }

  Widget _buildTable(List<BusinessPlanDocument> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('주제')),
          const DataColumn(label: Text('결과물')),
          const DataColumn(label: Text('상태')),
          const DataColumn(label: Text('고객')),
          const DataColumn(label: Text('버전')),
          const DataColumn(label: Text('수정')),
          const DataColumn(label: Text('ID')),
          const DataColumn(label: Text('지시')),
          const DataColumn(label: Text('Inbox')),
          if (!_manageMode) const DataColumn(label: Text('★')),
        ],
        rows: [
          for (final p in list)
            DataRow(
              selected:
                  p.id == widget.activePlanId || _selectedIds.contains(p.id),
              onSelectChanged: !_manageMode
                  ? (_) => widget.onOpenPlan(p)
                  : (_canSelect(p) ? (_) => _toggleSelect(p.id) : null),
              cells: [
                DataCell(
                  Text(
                    _titleOf(p),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(ArtifactType.labelKo(p.input.resolvedArtifactType)),
                ),
                DataCell(Text(_statusBadge(p))),
                DataCell(
                  Text(
                    p.input.targetCustomer.isEmpty
                        ? '-'
                        : p.input.targetCustomer,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(Text('v${p.version}')),
                DataCell(Text(_formatIso(p.updatedAt))),
                DataCell(
                  Text(PlanLibraryManagement.shortId(p.stableInstructionId)),
                ),
                DataCell(Text(p.hasInstruction ? 'Y' : 'N')),
                DataCell(Text(p.wasTransferred ? 'Y' : 'N')),
                if (!_manageMode)
                  DataCell(
                    IconButton(
                      onPressed: () => widget.onToggleFavorite(p),
                      icon: Icon(
                        p.favorite ? Icons.star : Icons.star_border,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
