import 'package:flutter/material.dart';

import '../data/strategy/strategy_articles.dart';
import '../data/strategy/strategy_models.dart';
import '../services/strategy_lab_progress_store.dart';
import '../theme/control_theme.dart';
import '../widgets/page_hero.dart';

const _readBodyStyle = TextStyle(
  fontSize: 16,
  height: 1.65,
  color: ControlColors.textPrimary,
);

const _sectionLabels = [
  ('problem', '문제 제기'),
  ('whyImportant', '왜 중요한가'),
  ('corePrinciples', '핵심 원리'),
  ('sotongwareApplication', '소통웨어 적용'),
  ('scenario', '시나리오'),
  ('options', '선택 전략'),
  ('reviewQuestions', '점검 질문'),
  ('monthActions', '이번 달 행동'),
  ('conclusion', '결론'),
];

class BusinessStudyScreen extends StatefulWidget {
  const BusinessStudyScreen({super.key});

  @override
  State<BusinessStudyScreen> createState() => _BusinessStudyScreenState();
}

class _BusinessStudyScreenState extends State<BusinessStudyScreen> {
  final _store = StrategyLabProgressStore();
  final _searchController = TextEditingController();
  final _detailScrollController = ScrollController();
  final _sectionKeys = {
    for (final entry in _sectionLabels) entry.$1: GlobalKey(),
  };

  Map<String, String> _statuses = {};
  Set<String> _favorites = {};
  Map<String, String> _memos = {};
  Map<String, String> _applyNotes = {};
  Map<String, bool> _actionChecks = {};

  String? _selectedId;
  String? _categoryFilter;
  var _searchQuery = '';
  var _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _store.loadStatuses(),
      _store.loadFavorites(),
      _store.loadMemos(),
      _store.loadApplyNotes(),
      _store.loadActionChecks(),
    ]);
    if (!mounted) return;
    setState(() {
      _statuses = results[0] as Map<String, String>;
      _favorites = results[1] as Set<String>;
      _memos = results[2] as Map<String, String>;
      _applyNotes = results[3] as Map<String, String>;
      _actionChecks = results[4] as Map<String, bool>;
    });
  }

  List<String> get _categories {
    final set = allStrategyArticles.map((a) => a.category).toSet();
    final list = set.toList()..sort();
    return list;
  }

  List<StrategyArticle> get _filteredArticles {
    return allStrategyArticles.where((article) {
      if (_categoryFilter != null && article.category != _categoryFilter) {
        return false;
      }
      if (_favoritesOnly && !_favorites.contains(article.id)) return false;
      if (_searchQuery.isEmpty) return true;
      final haystack = [
        article.title,
        article.summary,
        article.category,
        ...article.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  int get _reviewedCount =>
      allStrategyArticles.where((a) => _statuses[a.id] == 'reviewed').length;

  double get _progress => allStrategyArticles.isEmpty
      ? 0
      : _reviewedCount / allStrategyArticles.length;

  StrategyArticle? get _selectedArticle {
    if (_selectedId == null) return null;
    for (final article in allStrategyArticles) {
      if (article.id == _selectedId) return article;
    }
    return null;
  }

  void _selectArticle(String id) {
    setState(() => _selectedId = id);
    if (_detailScrollController.hasClients) {
      _detailScrollController.jumpTo(0);
    }
  }

  Future<void> _setStatus(String articleId, String status) async {
    await _store.setStatus(articleId, status);
    if (!mounted) return;
    setState(() => _statuses = {..._statuses, articleId: status});
  }

  Future<void> _toggleFavorite(String articleId) async {
    await _store.toggleFavorite(articleId);
    final favorites = await _store.loadFavorites();
    if (!mounted) return;
    setState(() => _favorites = favorites);
  }

  Future<void> _saveMemo(String articleId, String text) async {
    await _store.saveMemo(articleId, text);
    if (!mounted) return;
    setState(() {
      final next = {..._memos};
      if (text.trim().isEmpty) {
        next.remove(articleId);
      } else {
        next[articleId] = text;
      }
      _memos = next;
    });
  }

  Future<void> _saveApplyNote(String articleId, String text) async {
    await _store.saveApplyNote(articleId, text);
    if (!mounted) return;
    setState(() {
      final next = {..._applyNotes};
      if (text.trim().isEmpty) {
        next.remove(articleId);
      } else {
        next[articleId] = text;
      }
      _applyNotes = next;
    });
  }

  Future<void> _toggleAction(String articleId, int index, bool value) async {
    await _store.saveActionCheck(articleId, index, value);
    if (!mounted) return;
    setState(() {
      final key = StrategyLabProgressStore.actionEntryKey(articleId, index);
      final next = {..._actionChecks};
      if (value) {
        next[key] = true;
      } else {
        next.remove(key);
      }
      _actionChecks = next;
    });
  }

  void _navigateArticle(int delta) {
    final list = _filteredArticles;
    if (list.isEmpty) return;
    final currentIndex = list.indexWhere((a) => a.id == _selectedId);
    if (currentIndex < 0) return;
    final nextIndex = (currentIndex + delta).clamp(0, list.length - 1);
    _selectArticle(list[nextIndex].id);
  }

  void _scrollToSection(String key) {
    final target = _sectionKeys[key]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final selected = _selectedArticle;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHero(
                title: '사업전략연구실',
                subtitle: '소통회장이 사업 방향을 깊이 읽고 판단하기 위한 전략 연구 공간',
                badge: '전략 연구',
              ),
              const SizedBox(height: 16),
              _ProgressBar(
                reviewed: _reviewedCount,
                total: allStrategyArticles.length,
                progress: _progress,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _ArticleListPanel(
                              articles: _filteredArticles,
                              categories: _categories,
                              categoryFilter: _categoryFilter,
                              favoritesOnly: _favoritesOnly,
                              searchController: _searchController,
                              selectedId: _selectedId,
                              statuses: _statuses,
                              favorites: _favorites,
                              onCategoryChanged: (v) =>
                                  setState(() => _categoryFilter = v),
                              onFavoritesOnlyChanged: (v) =>
                                  setState(() => _favoritesOnly = v),
                              onSelect: _selectArticle,
                              onToggleFavorite: _toggleFavorite,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: selected == null
                                ? const _EmptyDetailHint(isWide: true)
                                : _ArticleDetailPanel(
                                    article: selected,
                                    scrollController: _detailScrollController,
                                    sectionKeys: _sectionKeys,
                                    status: _statuses[selected.id],
                                    isFavorite: _favorites.contains(
                                      selected.id,
                                    ),
                                    memo: _memos[selected.id] ?? '',
                                    applyNote: _applyNotes[selected.id] ?? '',
                                    actionChecks: _actionChecks,
                                    filteredArticles: _filteredArticles,
                                    onBack: null,
                                    onSetStatus: _setStatus,
                                    onToggleFavorite: _toggleFavorite,
                                    onSaveMemo: _saveMemo,
                                    onSaveApplyNote: _saveApplyNote,
                                    onToggleAction: _toggleAction,
                                    onNavigate: _navigateArticle,
                                    onScrollToSection: _scrollToSection,
                                  ),
                          ),
                        ],
                      )
                    : selected == null
                    ? _ArticleListPanel(
                        articles: _filteredArticles,
                        categories: _categories,
                        categoryFilter: _categoryFilter,
                        favoritesOnly: _favoritesOnly,
                        searchController: _searchController,
                        selectedId: _selectedId,
                        statuses: _statuses,
                        favorites: _favorites,
                        onCategoryChanged: (v) =>
                            setState(() => _categoryFilter = v),
                        onFavoritesOnlyChanged: (v) =>
                            setState(() => _favoritesOnly = v),
                        onSelect: _selectArticle,
                        onToggleFavorite: _toggleFavorite,
                      )
                    : _ArticleDetailPanel(
                        article: selected,
                        scrollController: _detailScrollController,
                        sectionKeys: _sectionKeys,
                        status: _statuses[selected.id],
                        isFavorite: _favorites.contains(selected.id),
                        memo: _memos[selected.id] ?? '',
                        applyNote: _applyNotes[selected.id] ?? '',
                        actionChecks: _actionChecks,
                        filteredArticles: _filteredArticles,
                        onBack: () => setState(() => _selectedId = null),
                        onSetStatus: _setStatus,
                        onToggleFavorite: _toggleFavorite,
                        onSaveMemo: _saveMemo,
                        onSaveApplyNote: _saveApplyNote,
                        onToggleAction: _toggleAction,
                        onNavigate: _navigateArticle,
                        onScrollToSection: _scrollToSection,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.reviewed,
    required this.total,
    required this.progress,
  });

  final int reviewed;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '연구 진행도 $reviewed/$total (검토 완료)',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ControlColors.slate,
              color: ControlColors.teal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '읽기 상태와 메모는 이 기기에 저장됩니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ControlColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ArticleListPanel extends StatelessWidget {
  const _ArticleListPanel({
    required this.articles,
    required this.categories,
    required this.categoryFilter,
    required this.favoritesOnly,
    required this.searchController,
    required this.selectedId,
    required this.statuses,
    required this.favorites,
    required this.onCategoryChanged,
    required this.onFavoritesOnlyChanged,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  final List<StrategyArticle> articles;
  final List<String> categories;
  final String? categoryFilter;
  final bool favoritesOnly;
  final TextEditingController searchController;
  final String? selectedId;
  final Map<String, String> statuses;
  final Set<String> favorites;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool> onFavoritesOnlyChanged;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전략 글 목록',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: '제목·태그·요약 검색',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('전체'),
                      selected: categoryFilter == null,
                      onSelected: (_) => onCategoryChanged(null),
                    ),
                    for (final cat in categories)
                      FilterChip(
                        label: Text(cat),
                        selected: categoryFilter == cat,
                        onSelected: (_) => onCategoryChanged(cat),
                      ),
                    FilterChip(
                      avatar: Icon(
                        favoritesOnly ? Icons.star : Icons.star_border,
                        size: 16,
                      ),
                      label: const Text('즐겨찾기'),
                      selected: favoritesOnly,
                      onSelected: onFavoritesOnlyChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: articles.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('조건에 맞는 연구 주제가 없습니다.'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      final status = statuses[article.id] ?? 'unread';
                      final selected = article.id == selectedId;
                      return _ArticleListTile(
                        article: article,
                        status: status,
                        isFavorite: favorites.contains(article.id),
                        selected: selected,
                        onTap: () => onSelect(article.id),
                        onToggleFavorite: () => onToggleFavorite(article.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArticleListTile extends StatelessWidget {
  const _ArticleListTile({
    required this.article,
    required this.status,
    required this.isFavorite,
    required this.selected,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final StrategyArticle article;
  final String status;
  final bool isFavorite;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ControlColors.tealSoft.withValues(alpha: 0.5) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(status: status),
                        const SizedBox(width: 6),
                        Text(
                          article.category,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: ControlColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ControlColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? ControlColors.accentWarm : null,
                  size: 20,
                ),
                onPressed: onToggleFavorite,
                tooltip: '즐겨찾기',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  String get _label => switch (status) {
    'reading' => '읽는 중',
    'reviewed' => '검토 완료',
    _ => '미읽음',
  };

  Color get _color => switch (status) {
    'reading' => ControlColors.sandBeige,
    'reviewed' => ControlColors.teal,
    _ => ControlColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class _EmptyDetailHint extends StatelessWidget {
  const _EmptyDetailHint({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isWide ? double.infinity : 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 40,
            color: ControlColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            '왼쪽에서 연구 주제를 선택하세요',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: ControlColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '읽고 연구하기 → 검토 완료로 진행도를 관리합니다',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ControlColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ArticleDetailPanel extends StatefulWidget {
  const _ArticleDetailPanel({
    required this.article,
    required this.scrollController,
    required this.sectionKeys,
    required this.status,
    required this.isFavorite,
    required this.memo,
    required this.applyNote,
    required this.actionChecks,
    required this.filteredArticles,
    required this.onBack,
    required this.onSetStatus,
    required this.onToggleFavorite,
    required this.onSaveMemo,
    required this.onSaveApplyNote,
    required this.onToggleAction,
    required this.onNavigate,
    required this.onScrollToSection,
  });

  final StrategyArticle article;
  final ScrollController scrollController;
  final Map<String, GlobalKey> sectionKeys;
  final String? status;
  final bool isFavorite;
  final String memo;
  final String applyNote;
  final Map<String, bool> actionChecks;
  final List<StrategyArticle> filteredArticles;
  final VoidCallback? onBack;
  final Future<void> Function(String id, String status) onSetStatus;
  final Future<void> Function(String id) onToggleFavorite;
  final Future<void> Function(String id, String text) onSaveMemo;
  final Future<void> Function(String id, String text) onSaveApplyNote;
  final Future<void> Function(String id, int index, bool value) onToggleAction;
  final void Function(int delta) onNavigate;
  final void Function(String key) onScrollToSection;

  @override
  State<_ArticleDetailPanel> createState() => _ArticleDetailPanelState();
}

class _ArticleDetailPanelState extends State<_ArticleDetailPanel> {
  late TextEditingController _memoController;
  late TextEditingController _applyController;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: widget.memo);
    _applyController = TextEditingController(text: widget.applyNote);
  }

  @override
  void didUpdateWidget(covariant _ArticleDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _memoController.text = widget.memo;
      _applyController.text = widget.applyNote;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _applyController.dispose();
    super.dispose();
  }

  int get _currentIndex =>
      widget.filteredArticles.indexWhere((a) => a.id == widget.article.id);

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final currentStatus = widget.status ?? 'unread';
    final canPrev = _currentIndex > 0;
    final canNext =
        _currentIndex >= 0 &&
        _currentIndex < widget.filteredArticles.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onBack != null)
                  TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('목록으로'),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _StatusBadge(status: currentStatus),
                              Chip(
                                label: Text(article.category),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              for (final tag in article.tags)
                                Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            article.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            article.summary,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: ControlColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        widget.isFavorite ? Icons.star : Icons.star_border,
                        color: widget.isFavorite
                            ? ControlColors.accentWarm
                            : null,
                      ),
                      onPressed: () => widget.onToggleFavorite(article.id),
                      tooltip: '즐겨찾기',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (key, label) in _sectionLabels)
                      ActionChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => widget.onScrollToSection(key),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'unread', label: Text('미읽음')),
                        ButtonSegment(value: 'reading', label: Text('읽는 중')),
                        ButtonSegment(value: 'reviewed', label: Text('검토 완료')),
                      ],
                      selected: {currentStatus},
                      onSelectionChanged: (s) =>
                          widget.onSetStatus(article.id, s.first),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: canPrev ? () => widget.onNavigate(-1) : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '이전 글',
                    ),
                    IconButton(
                      onPressed: canNext ? () => widget.onNavigate(1) : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '다음 글',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TextSection(
                        key: widget.sectionKeys['problem'],
                        title: '문제 제기',
                        body: article.problem,
                      ),
                      _TextSection(
                        key: widget.sectionKeys['whyImportant'],
                        title: '왜 중요한가',
                        body: article.whyImportant,
                      ),
                      _TextSection(
                        key: widget.sectionKeys['corePrinciples'],
                        title: '핵심 원리',
                        body: article.corePrinciples,
                      ),
                      _TextSection(
                        key: widget.sectionKeys['sotongwareApplication'],
                        title: '소통웨어 적용',
                        body: article.sotongwareApplication,
                        emphasized: true,
                      ),
                      _TextSection(
                        key: widget.sectionKeys['scenario'],
                        title: '시나리오',
                        body: article.scenario,
                      ),
                      _OptionsSection(
                        key: widget.sectionKeys['options'],
                        options: article.options,
                      ),
                      _QuestionsSection(
                        key: widget.sectionKeys['reviewQuestions'],
                        title: '검토 질문',
                        questions: article.reviewQuestions,
                      ),
                      _MonthActionsSection(
                        key: widget.sectionKeys['monthActions'],
                        articleId: article.id,
                        actions: article.monthActions,
                        checks: widget.actionChecks,
                        onToggle: widget.onToggleAction,
                      ),
                      _TextSection(
                        key: widget.sectionKeys['conclusion'],
                        title: '결론',
                        body: article.conclusion,
                      ),
                      const SizedBox(height: 20),
                      _NotesSection(
                        memoController: _memoController,
                        applyController: _applyController,
                        onSaveMemo: () =>
                            widget.onSaveMemo(article.id, _memoController.text),
                        onSaveApply: () => widget.onSaveApplyNote(
                          article.id,
                          _applyController.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    super.key,
    required this.title,
    required this.body,
    this.emphasized = false,
  });

  final String title;
  final String body;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: emphasized ? const EdgeInsets.all(14) : EdgeInsets.zero,
      decoration: emphasized
          ? BoxDecoration(
              color: ControlColors.tealSoft,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SelectableText(body, style: _readBodyStyle),
        ],
      ),
    );
  }
}

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({super.key, required this.options});

  final List<StrategyOption> options;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택 전략',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final option in options) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(option.description, style: _readBodyStyle),
                  const SizedBox(height: 6),
                  SelectableText(
                    '장점: ${option.pros}',
                    style: _readBodyStyle.copyWith(
                      color: ControlColors.accentGreen,
                    ),
                  ),
                  SelectableText(
                    '리스크: ${option.risks}',
                    style: _readBodyStyle.copyWith(
                      color: ControlColors.accentRose,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionsSection extends StatelessWidget {
  const _QuestionsSection({
    super.key,
    required this.title,
    required this.questions,
  });

  final String title;
  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: _readBodyStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(questions[i], style: _readBodyStyle),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthActionsSection extends StatelessWidget {
  const _MonthActionsSection({
    super.key,
    required this.articleId,
    required this.actions,
    required this.checks,
    required this.onToggle,
  });

  final String articleId;
  final List<String> actions;
  final Map<String, bool> checks;
  final Future<void> Function(String id, int index, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 달 실행할 행동',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '체크 상태는 저장됩니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ControlColors.textMuted),
          ),
          for (var i = 0; i < actions.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(actions[i], style: _readBodyStyle),
              value:
                  checks[StrategyLabProgressStore.actionEntryKey(
                    articleId,
                    i,
                  )] ??
                  false,
              onChanged: (v) => onToggle(articleId, i, v ?? false),
            ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.memoController,
    required this.applyController,
    required this.onSaveMemo,
    required this.onSaveApply,
  });

  final TextEditingController memoController;
  final TextEditingController applyController;
  final VoidCallback onSaveMemo;
  final VoidCallback onSaveApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '회장 메모',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: memoController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '전략 메모, 의사결정 메모를 남기세요',
            border: OutlineInputBorder(),
          ),
          onEditingComplete: onSaveMemo,
          onTapOutside: (_) => onSaveMemo(),
        ),
        const SizedBox(height: 16),
        Text(
          '내 사업에 적용할 점',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: applyController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '소통웨어 사업에 어떻게 적용할지 적어보세요',
            border: OutlineInputBorder(),
          ),
          onEditingComplete: onSaveApply,
          onTapOutside: (_) => onSaveApply(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
