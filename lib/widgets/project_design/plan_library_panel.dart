import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/project_design_catalog.dart';
import '../../models/business_planning.dart';
import '../../theme/control_theme.dart';

enum PlanLibraryViewMode { cards, list, table }

enum PlanLibrarySort { newest, name, updated, status, artifact }

/// 저장된 기획 관리 — 폴더·검색·보기·정렬.
class PlanLibraryPanel extends StatelessWidget {
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
  final Set<String> duplicateTopics;

  List<BusinessPlanDocument> get _filtered {
    var list = List<BusinessPlanDocument>.from(plans);
    switch (folderFilter) {
      case 'favorite':
        list = list.where((p) => p.favorite).toList();
      case 'completed':
        list = list
            .where(
              (p) =>
                  PlanningStatus.normalize(p.status) ==
                  PlanningStatus.completed,
            )
            .toList();
      case 'archived':
        list = list
            .where(
              (p) =>
                  PlanningStatus.normalize(p.status) == PlanningStatus.archived,
            )
            .toList();
      case 'all':
        break;
      default:
        list = list.where((p) {
          final folder = p.libraryFolder.isNotEmpty
              ? p.libraryFolder
              : ArtifactType.normalize(p.input.resolvedArtifactType);
          return folder == folderFilter;
        }).toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        final status = PlanningStatus.labelKo(p.status).toLowerCase();
        final artifact = ArtifactType.labelKo(
          p.input.resolvedArtifactType,
        ).toLowerCase();
        final tags = p.tags.join(' ').toLowerCase();
        return p.input.topic.toLowerCase().contains(q) ||
            p.input.targetCustomer.toLowerCase().contains(q) ||
            p.input.customerProblem.toLowerCase().contains(q) ||
            status.contains(q) ||
            artifact.contains(q) ||
            tags.contains(q) ||
            p.createdAt.toLowerCase().contains(q) ||
            p.updatedAt.toLowerCase().contains(q);
      }).toList();
    }

    list.sort((a, b) {
      switch (sort) {
        case PlanLibrarySort.name:
          return a.input.topic.compareTo(b.input.topic);
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

  String _statusBadge(BusinessPlanDocument p) {
    final s = PlanningStatus.normalize(p.status);
    if (s == PlanningStatus.draft) return '기획중';
    if (s == PlanningStatus.instructionReady ||
        s == PlanningStatus.readyToTransfer ||
        s == PlanningStatus.validationRequired) {
      return '작업지시 생성';
    }
    if (s == PlanningStatus.inProgress) return '진행중';
    if (s == PlanningStatus.transferred || s == PlanningStatus.imported) {
      return '승인대기';
    }
    if (s == PlanningStatus.completed) return '완료';
    if (s == PlanningStatus.archived) return '보관';
    return PlanningStatus.labelKo(s);
  }

  String _formatIso(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
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
            FilledButton.tonalIcon(
              onPressed: onStartNew,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 기획'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final id in ProjectDesignCatalog.libraryFolders)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(ProjectDesignCatalog.libraryFolderLabel(id)),
                    selected: folderFilter == id,
                    onSelected: (_) => onFolderChanged(id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: '제목·태그·고객·날짜·상태·결과물 검색',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
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
                selected: {viewMode},
                onSelectionChanged: (s) => onViewModeChanged(s.first),
              ),
              const SizedBox(width: 12),
              DropdownButton<PlanLibrarySort>(
                value: sort,
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
                  if (v != null) onSortChanged(v);
                },
              ),
            ],
          ),
        ),
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
          switch (viewMode) {
            PlanLibraryViewMode.cards => _buildCards(visible),
            PlanLibraryViewMode.list => _buildList(visible),
            PlanLibraryViewMode.table => _buildTable(visible),
          },
      ],
    );
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
                  color: p.id == activePlanId
                      ? ControlColors.tealSoft.withValues(alpha: 0.35)
                      : ControlColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onOpenPlan(p),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ControlColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.input.topic.isEmpty
                                      ? '(주제 미입력)'
                                      : p.input.topic,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onToggleFavorite(p),
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _badge(p),
                              Text(
                                ArtifactType.labelKo(
                                  p.input.resolvedArtifactType,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ControlColors.textMuted,
                                ),
                              ),
                              if (duplicateTopics.contains(
                                p.input.topic.trim().toLowerCase(),
                              ))
                                const Text(
                                  '유사 주제',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ControlColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '고객: ${p.input.targetCustomer.isEmpty ? '-' : p.input.targetCustomer}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '수정 ${_formatIso(p.updatedAt)} · v${p.version}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: ControlColors.textMuted,
                            ),
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
            selected: p.id == activePlanId,
            title: Text(
              p.input.topic.isEmpty ? '(주제 미입력)' : p.input.topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${ArtifactType.labelKo(p.input.resolvedArtifactType)} · '
              '${_statusBadge(p)} · ${_formatIso(p.updatedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              onPressed: () => onToggleFavorite(p),
              icon: Icon(p.favorite ? Icons.star : Icons.star_border),
            ),
            onTap: () => onOpenPlan(p),
          ),
      ],
    );
  }

  Widget _buildTable(List<BusinessPlanDocument> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('주제')),
          DataColumn(label: Text('결과물')),
          DataColumn(label: Text('상태')),
          DataColumn(label: Text('고객')),
          DataColumn(label: Text('수정')),
          DataColumn(label: Text('★')),
        ],
        rows: [
          for (final p in list)
            DataRow(
              selected: p.id == activePlanId,
              onSelectChanged: (_) => onOpenPlan(p),
              cells: [
                DataCell(
                  Text(
                    p.input.topic.isEmpty ? '(미입력)' : p.input.topic,
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
                DataCell(Text(_formatIso(p.updatedAt))),
                DataCell(
                  IconButton(
                    onPressed: () => onToggleFavorite(p),
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
