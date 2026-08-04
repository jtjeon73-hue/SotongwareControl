import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/portfolio_seed_examples.dart';
import '../models/portfolio_models.dart';
import '../services/portfolio_dashboard_service.dart';
import '../services/portfolio_score_service.dart';
import '../services/portfolio_store.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';

/// 제작 포트폴리오 허브 — artifact별 목표·후보·진행 현황.
class PortfolioHubScreen extends StatefulWidget {
  const PortfolioHubScreen({super.key, this.onOpenPlanning});

  final VoidCallback? onOpenPlanning;

  @override
  State<PortfolioHubScreen> createState() => _PortfolioHubScreenState();
}

class _PortfolioHubScreenState extends State<PortfolioHubScreen> {
  final _store = PortfolioStore();
  final _dashboard = PortfolioDashboardService();
  final _scoreService = PortfolioScoreService();
  final _searchController = TextEditingController();

  List<PortfolioItem> _allItems = [];
  List<ThemeBundle> _bundles = [];
  PortfolioArtifactGoals _goals = const PortfolioArtifactGoals(
    targets: PortfolioArtifactGoals.defaultTargets,
  );
  PortfolioDashboardStats _stats = const PortfolioDashboardStats();
  bool _loading = true;

  String _search = '';
  String? _filterArtifact;
  String? _filterStatus;
  String? _filterCategory;
  PortfolioSortField _sortField = PortfolioSortField.updatedAt;
  bool _sortDesc = true;
  int _page = 0;
  static const _pageSize = 20;

  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text;
        _page = 0;
      });
    });
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final items = await _store.loadItems();
    final goals = await _store.loadGoals();
    final bundles = await _store.loadBundles();
    final stats = _dashboard.build(items: items, goals: goals);
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _goals = goals;
      _bundles = bundles;
      _stats = stats;
      _loading = false;
    });
  }

  List<PortfolioItem> get _filteredItems {
    var list = PortfolioStore.filterItems(
      _allItems,
      search: _search,
      artifact: _filterArtifact,
      status: _filterStatus,
      category: _filterCategory,
    );
    list = PortfolioStore.sortItems(
      list,
      field: _sortField,
      descending: _sortDesc,
    );
    return list;
  }

  Future<void> _loadSeedExamples() async {
    await PortfolioSeedExamples.loadIntoStore(
      loadItems: _store.loadItems,
      saveItems: _store.saveItems,
      loadBundles: _store.loadBundles,
      saveBundles: _store.saveBundles,
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('예시 주제 묶음을 불러왔습니다.')));
  }

  Future<void> _editGoal(String artifact, int current) async {
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${ArtifactType.labelShortKo(artifact)} 목표 수'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '목표 제작 수',
            helperText: '기본 50 — 상한이 아니며 50보다 크게 설정할 수 있습니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v == null || v < 1) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final next = _goals.setGoal(artifact, result);
    await _store.saveGoals(next);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredItems;
    final pageItems = PortfolioStore.page(filtered, _page, _pageSize);
    final totalPages = PortfolioStore.pageCount(filtered.length, _pageSize);
    final categories = PortfolioStore.distinctCategories(_allItems);
    final isEmpty = _allItems.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHero(
            title: '제작 포트폴리오',
            subtitle: 'artifact별 제작 목표·후보·기획·제작·출시 현황을 한곳에서 관리합니다.',
            badge: '포트폴리오 · 목표 · 점수',
            compact: true,
          ),
          const SizedBox(height: 16),
          if (isEmpty)
            EmptyStatePanel(
              title: '아직 등록된 포트폴리오 항목이 없습니다',
              message: '제작할 주제·아이디어를 등록하거나, UI 확인을 위해 예시 묶음을 불러올 수 있습니다.',
              actionLabel: '예시 주제 묶음 불러오기',
              onAction: _loadSeedExamples,
            )
          else ...[
            _SummarySection(stats: _stats, onEditGoal: _editGoal),
            const SizedBox(height: 16),
            if (_stats.actionNeeded.isNotEmpty ||
                _stats.stalled.isNotEmpty) ...[
              _AlertStrip(stats: _stats),
              const SizedBox(height: 16),
            ],
            if (_bundles.isNotEmpty) ...[
              _ThemeBundleSection(bundles: _bundles, items: _allItems),
              const SizedBox(height: 16),
            ],
            _FilterBar(
              searchController: _searchController,
              filterArtifact: _filterArtifact,
              filterStatus: _filterStatus,
              filterCategory: _filterCategory,
              categories: categories,
              sortField: _sortField,
              sortDesc: _sortDesc,
              onArtifactChanged: (v) => setState(() {
                _filterArtifact = v;
                _page = 0;
              }),
              onStatusChanged: (v) => setState(() {
                _filterStatus = v;
                _page = 0;
              }),
              onCategoryChanged: (v) => setState(() {
                _filterCategory = v;
                _page = 0;
              }),
              onSortFieldChanged: (v) => setState(() => _sortField = v),
              onSortDescChanged: (v) => setState(() => _sortDesc = v),
            ),
            const SizedBox(height: 12),
            Text(
              '총 ${filtered.length}건 · ${_page + 1}/$totalPages 페이지',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ControlColors.textMuted),
            ),
            const SizedBox(height: 8),
            ...pageItems.map(
              (item) => _PortfolioItemTile(
                item: item,
                scoreService: _scoreService,
                expanded: _expandedIds.contains(item.id),
                onOpenPlanning: widget.onOpenPlanning,
                onToggle: () => setState(() {
                  if (_expandedIds.contains(item.id)) {
                    _expandedIds.remove(item.id);
                  } else {
                    _expandedIds.add(item.id);
                  }
                }),
              ),
            ),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('필터 조건에 맞는 항목이 없습니다.')),
              ),
            if (totalPages > 1) ...[
              const SizedBox(height: 12),
              _PaginationBar(
                page: _page,
                totalPages: totalPages,
                onPrev: _page > 0 ? () => setState(() => _page -= 1) : null,
                onNext: _page < totalPages - 1
                    ? () => setState(() => _page += 1)
                    : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.stats, required this.onEditGoal});

  final PortfolioDashboardStats stats;
  final Future<void> Function(String artifact, int current) onEditGoal;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ArtifactType.allSelectable.map((artifact) {
        final s = stats.byArtifact[artifact];
        if (s == null) return const SizedBox.shrink();
        return _ArtifactSummaryCard(
          stats: s,
          onEditGoal: () => onEditGoal(artifact, s.goal),
        );
      }).toList(),
    );
  }
}

class _ArtifactSummaryCard extends StatelessWidget {
  const _ArtifactSummaryCard({required this.stats, required this.onEditGoal});

  final ArtifactPortfolioStats stats;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final label = ArtifactType.labelShortKo(stats.artifact);
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: '목표 수정',
                    onPressed: onEditGoal,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _miniStat('목표', '${stats.goal}'),
                  _miniStat('후보', '${stats.candidates}'),
                  _miniStat('기획', '${stats.planned}'),
                  _miniStat('제작', '${stats.inProduction}'),
                  _miniStat('출시', '${stats.launched}'),
                ],
              ),
              const SizedBox(height: 8),
              ProgressLabel(progress: stats.progress.clamp(0, 100)),
              if (stats.nextRecommended != null) ...[
                const SizedBox(height: 8),
                Text(
                  '다음 추천: ${stats.nextRecommended!.title}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ControlColors.teal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _miniStat(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: ControlColors.teal,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: ControlColors.textMuted),
      ),
    ],
  );
}

class _AlertStrip extends StatelessWidget {
  const _AlertStrip({required this.stats});

  final PortfolioDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ControlColors.sandLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (stats.actionNeeded.isNotEmpty)
              StatusBadge(
                label: '조치 필요 ${stats.actionNeeded.length}',
                color: ControlColors.accentWarm,
              ),
            if (stats.transferWaiting.isNotEmpty)
              StatusBadge(
                label: '전달 대기 ${stats.transferWaiting.length}',
                color: ControlColors.teal,
              ),
            if (stats.reviewWaiting.isNotEmpty)
              StatusBadge(label: '검토 대기 ${stats.reviewWaiting.length}'),
            if (stats.stalled.isNotEmpty)
              StatusBadge(
                label: '정체 ${stats.stalled.length}',
                color: ControlColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeBundleSection extends StatelessWidget {
  const _ThemeBundleSection({required this.bundles, required this.items});

  final List<ThemeBundle> bundles;
  final List<PortfolioItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주제 묶음', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...bundles.map((bundle) {
              final linked = items
                  .where((i) => bundle.linkedProjectIds.contains(i.id))
                  .toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.coreTopic,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (bundle.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bundle.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ControlColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: linked.map((item) {
                        return StatusBadge(
                          label:
                              '${ArtifactType.labelShortKo(item.artifactType)} · ${PortfolioStatus.labelKo(item.status)}',
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.filterArtifact,
    required this.filterStatus,
    required this.filterCategory,
    required this.categories,
    required this.sortField,
    required this.sortDesc,
    required this.onArtifactChanged,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onSortFieldChanged,
    required this.onSortDescChanged,
  });

  final TextEditingController searchController;
  final String? filterArtifact;
  final String? filterStatus;
  final String? filterCategory;
  final List<String> categories;
  final PortfolioSortField sortField;
  final bool sortDesc;
  final ValueChanged<String?> onArtifactChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<PortfolioSortField> onSortFieldChanged;
  final ValueChanged<bool> onSortDescChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: '제목·주제·메모 검색',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _dropdown<String?>(
                  label: '형태',
                  value: filterArtifact,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    ...ArtifactType.allSelectable.map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(ArtifactType.labelShortKo(a)),
                      ),
                    ),
                  ],
                  onChanged: onArtifactChanged,
                ),
                _dropdown<String?>(
                  label: '상태',
                  value: filterStatus,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    ...PortfolioStatus.all.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(PortfolioStatus.labelKo(s)),
                      ),
                    ),
                  ],
                  onChanged: onStatusChanged,
                ),
                if (categories.isNotEmpty)
                  _dropdown<String?>(
                    label: '카테고리',
                    value: filterCategory,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체')),
                      ...categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: onCategoryChanged,
                  ),
                _dropdown<PortfolioSortField>(
                  label: '정렬',
                  value: sortField,
                  items: const [
                    DropdownMenuItem(
                      value: PortfolioSortField.updatedAt,
                      child: Text('수정일'),
                    ),
                    DropdownMenuItem(
                      value: PortfolioSortField.score,
                      child: Text('점수'),
                    ),
                    DropdownMenuItem(
                      value: PortfolioSortField.status,
                      child: Text('상태'),
                    ),
                    DropdownMenuItem(
                      value: PortfolioSortField.priority,
                      child: Text('우선순위'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onSortFieldChanged(v);
                  },
                ),
                FilterChip(
                  label: Text(sortDesc ? '내림차순' : '오름차순'),
                  selected: sortDesc,
                  onSelected: (_) => onSortDescChanged(!sortDesc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 160,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _PortfolioItemTile extends StatelessWidget {
  const _PortfolioItemTile({
    required this.item,
    required this.scoreService,
    required this.expanded,
    required this.onToggle,
    this.onOpenPlanning,
  });

  final PortfolioItem item;
  final PortfolioScoreService scoreService;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onOpenPlanning;

  @override
  Widget build(BuildContext context) {
    final breakdown = item.scoreBreakdown ?? scoreService.computeFromItem(item);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.isEmpty ? '(제목 없음)' : item.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.oneLiner.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.oneLiner,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ControlColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        label: ArtifactType.labelShortKo(item.artifactType),
                      ),
                      const SizedBox(height: 4),
                      StatusBadge(
                        label: PortfolioStatus.labelKo(item.status),
                        color: ControlColors.teal,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  StatusBadge(
                    label: '총점 ${breakdown.total}',
                    color: ControlColors.accentGreen,
                  ),
                  if (item.topicCategory.isNotEmpty)
                    StatusBadge(label: item.topicCategory),
                  if (item.isTestMarked)
                    const StatusBadge(
                      label: 'TEST',
                      color: ControlColors.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '수정 ${dateFmt.format(item.updatedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: ControlColors.textMuted,
                ),
              ),
              if (expanded) ...[
                const Divider(height: 20),
                _ScoreBreakdownPanel(breakdown: breakdown),
                if (item.planId != null || item.instructionId != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (item.planId != null)
                        Text(
                          'plan: ${item.planId}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      if (item.instructionId != null)
                        Text(
                          'instruction: ${item.instructionId}',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                  if (onOpenPlanning != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onOpenPlanning,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('사업기획·작업지시로 이동'),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBreakdownPanel extends StatelessWidget {
  const _ScoreBreakdownPanel({required this.breakdown});

  final PortfolioScoreBreakdown breakdown;

  static const _dims = [
    ('회장 관심', 'chairmanInterest'),
    ('미래 필요', 'futureNeed'),
    ('시장성', 'marketability'),
    ('필요성', 'necessity'),
    ('차별성', 'differentiation'),
    ('수익화', 'monetizationPotential'),
    ('제작 가능', 'buildability'),
  ];

  int _value(String key) {
    switch (key) {
      case 'chairmanInterest':
        return breakdown.chairmanInterest;
      case 'futureNeed':
        return breakdown.futureNeed;
      case 'marketability':
        return breakdown.marketability;
      case 'necessity':
        return breakdown.necessity;
      case 'differentiation':
        return breakdown.differentiation;
      case 'monetizationPotential':
        return breakdown.monetizationPotential;
      case 'buildability':
        return breakdown.buildability;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _dims.map((d) {
            return StatusBadge(
              label: '${d.$1} ${_value(d.$2)}',
              color: ControlColors.slate,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        StatusBadge(
          label:
              '근거: ${PortfolioEvidenceSource.labelKo(breakdown.evidenceSource)}',
          color: ControlColors.textMuted,
        ),
        if (breakdown.reasons.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...breakdown.reasons.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('✓ $r', style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
        if (breakdown.cautions.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...breakdown.cautions.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '⚠ $c',
                style: const TextStyle(
                  fontSize: 11,
                  color: ControlColors.accentWarm,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text('${page + 1} / $totalPages'),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}
