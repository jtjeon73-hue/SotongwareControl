import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/strategy/strategy_articles.dart';
import '../data/strategy/strategy_models.dart';
import '../services/strategy_lab_progress_store.dart';
import '../theme/control_theme.dart';

enum _QuickFilter { recommend, unread, reading, reviewed, favorites }

const _bodyStyle = TextStyle(
  fontSize: 16.5,
  height: 1.75,
  color: ControlColors.textPrimary,
  letterSpacing: 0.1,
);

const _sectionTitleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  height: 1.4,
  color: ControlColors.textPrimary,
);

class BusinessStudyScreen extends StatefulWidget {
  const BusinessStudyScreen({super.key});

  @override
  State<BusinessStudyScreen> createState() => _BusinessStudyScreenState();
}

class _BusinessStudyScreenState extends State<BusinessStudyScreen> {
  final _store = StrategyLabProgressStore();
  final _searchController = TextEditingController();
  final _listScrollController = ScrollController();
  final _detailScrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};

  Map<String, String> _statuses = {};
  Set<String> _favorites = {};
  Map<String, String> _memos = {};
  Map<String, String> _applyNotes = {};
  Map<String, bool> _actionChecks = {};

  String? _selectedId;
  String? _categoryFilter;
  var _searchQuery = '';
  var _quickFilter = _QuickFilter.recommend;
  var _loading = true;
  var _tocExpanded = true;
  var _listCollapsed = false;
  var _fullscreenReading = false;
  double? _savedListOffset;

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
    _listScrollController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    // SharedPreferences 초기화가 테스트에서 필요할 수 있음
    await SharedPreferences.getInstance();
    final results = await Future.wait([
      _store.loadStatuses(),
      _store.loadFavorites(),
      _store.loadMemos(),
      _store.loadApplyNotes(),
      _store.loadActionChecks(),
      _store.loadLastOpenedId(),
    ]);
    if (!mounted) return;

    final lastOpened = results[5] as String?;
    final initialId = _resolveInitialId(lastOpened);

    setState(() {
      _statuses = results[0] as Map<String, String>;
      _favorites = results[1] as Set<String>;
      _memos = results[2] as Map<String, String>;
      _applyNotes = results[3] as Map<String, String>;
      _actionChecks = results[4] as Map<String, bool>;
      _selectedId = initialId;
      _loading = false;
    });

    if (initialId != null) {
      await _store.saveLastOpenedId(initialId);
    }
  }

  String? _resolveInitialId(String? lastOpened) {
    if (lastOpened != null &&
        allStrategyArticles.any((a) => a.id == lastOpened)) {
      return lastOpened;
    }
    final recommended = StrategyLabProgressStore.todaysRecommendedId();
    if (allStrategyArticles.any((a) => a.id == recommended)) {
      return recommended;
    }
    if (allStrategyArticles.isNotEmpty) {
      return allStrategyArticles.first.id;
    }
    return null;
  }

  List<StrategyArticle> get _filteredArticles {
    var list = allStrategyArticles.where((article) {
      if (_categoryFilter != null && article.category != _categoryFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final haystack = [
          article.title,
          article.summary,
          article.category,
          article.audience,
          ...article.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(_searchQuery)) return false;
      }
      final status = _statuses[article.id] ?? 'unread';
      switch (_quickFilter) {
        case _QuickFilter.recommend:
          return true;
        case _QuickFilter.unread:
          return status == 'unread' || !_statuses.containsKey(article.id);
        case _QuickFilter.reading:
          return status == 'reading';
        case _QuickFilter.reviewed:
          return status == 'reviewed';
        case _QuickFilter.favorites:
          return _favorites.contains(article.id);
      }
    }).toList();

    if (_quickFilter == _QuickFilter.recommend) {
      list = [...list]
        ..sort((a, b) => a.recommendOrder.compareTo(b.recommendOrder));
    }
    return list;
  }

  int get _readingCount => allStrategyArticles
      .where((a) => (_statuses[a.id] ?? '') == 'reading')
      .length;

  int get _reviewedCount => allStrategyArticles
      .where((a) => (_statuses[a.id] ?? '') == 'reviewed')
      .length;

  StrategyArticle? get _selectedArticle {
    final id = _selectedId;
    if (id == null) return null;
    for (final article in allStrategyArticles) {
      if (article.id == id) return article;
    }
    // 필터로 사라진 경우에도 안전하게 첫 글
    if (_filteredArticles.isNotEmpty) return _filteredArticles.first;
    if (allStrategyArticles.isNotEmpty) return allStrategyArticles.first;
    return null;
  }

  Future<void> _selectArticle(String id, {required bool isWide}) async {
    if (!isWide) {
      _savedListOffset = _listScrollController.hasClients
          ? _listScrollController.offset
          : null;
    }
    setState(() => _selectedId = id);
    await _store.saveLastOpenedId(id);
    final status = _statuses[id] ?? 'unread';
    if (status == 'unread') {
      await _setStatus(id, 'reading');
    }
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
    final current = _selectedArticle;
    final currentIndex = current == null
        ? 0
        : list.indexWhere((a) => a.id == current.id);
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (safeIndex + delta).clamp(0, list.length - 1);
    _selectArticle(list[nextIndex].id, isWide: true);
  }

  void _scrollToSection(String key) {
    final target = _sectionKeys[key]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  void _backToList() {
    setState(() => _selectedId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_savedListOffset != null && _listScrollController.hasClients) {
        _listScrollController.jumpTo(
          _savedListOffset!.clamp(
            0.0,
            _listScrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final selected = _selectedArticle;

        // 데스크톱: 항상 본문 표시. 모바일: 선택 시에만 상세.
        final showDetail = isWide || selected != null;
        final showList = isWide || selected == null;

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _navigateArticle(1);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _navigateArticle(-1);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? (_fullscreenReading ? 12 : 24) : 12,
              _fullscreenReading ? 8 : (isWide ? 12 : 8),
              isWide ? (_fullscreenReading ? 12 : 24) : 12,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_fullscreenReading)
                  _ReadingHeader(
                    total: allStrategyArticles.length,
                    reading: _readingCount,
                    reviewed: _reviewedCount,
                    favorites: _favorites.length,
                  ),
                if (showList && !_fullscreenReading) ...[
                  const SizedBox(height: 8),
                  _FilterRow(
                    searchController: _searchController,
                    categoryFilter: _categoryFilter,
                    quickFilter: _quickFilter,
                    onCategoryChanged: (v) =>
                        setState(() => _categoryFilter = v),
                    onQuickFilterChanged: (v) =>
                        setState(() => _quickFilter = v),
                  ),
                ],
                if (isWide && selected != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _listCollapsed = !_listCollapsed),
                        icon: Icon(
                          _listCollapsed
                              ? Icons.view_sidebar_outlined
                              : Icons.view_sidebar,
                          size: 18,
                        ),
                        label: Text(_listCollapsed ? '목록 펼치기' : '목록 접기'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _fullscreenReading = !_fullscreenReading,
                        ),
                        icon: Icon(
                          _fullscreenReading
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          size: 18,
                        ),
                        label: Text(
                          _fullscreenReading ? '일반 보기' : '전체화면 읽기',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_listCollapsed && !_fullscreenReading) ...[
                              SizedBox(
                                width: 300,
                                child: _ArticleList(
                                  articles: _filteredArticles,
                                  selectedId: selected?.id,
                                  statuses: _statuses,
                                  favorites: _favorites,
                                  scrollController: _listScrollController,
                                  onSelect: (id) =>
                                      _selectArticle(id, isWide: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: selected == null
                                  ? const SizedBox.shrink()
                                  : _ReadingPane(
                                      article: selected,
                                      scrollController: _detailScrollController,
                                      sectionKeys: _sectionKeys,
                                      status:
                                          _statuses[selected.id] ?? 'unread',
                                      isFavorite: _favorites.contains(
                                        selected.id,
                                      ),
                                      memo: _memos[selected.id] ?? '',
                                      applyNote: _applyNotes[selected.id] ?? '',
                                      actionChecks: _actionChecks,
                                      tocExpanded:
                                          _fullscreenReading ? false : _tocExpanded,
                                      onTocExpanded: (v) =>
                                          setState(() => _tocExpanded = v),
                                      onBack: null,
                                      onSetStatus: _setStatus,
                                      onToggleFavorite: _toggleFavorite,
                                      onSaveMemo: _saveMemo,
                                      onSaveApplyNote: _saveApplyNote,
                                      onToggleAction: _toggleAction,
                                      onNavigate: _navigateArticle,
                                      onScrollToSection: _scrollToSection,
                                      compactChrome: _fullscreenReading,
                                    ),
                            ),
                          ],
                        )
                      : showDetail && selected != null
                      ? _ReadingPane(
                          article: selected,
                          scrollController: _detailScrollController,
                          sectionKeys: _sectionKeys,
                          status: _statuses[selected.id] ?? 'unread',
                          isFavorite: _favorites.contains(selected.id),
                          memo: _memos[selected.id] ?? '',
                          applyNote: _applyNotes[selected.id] ?? '',
                          actionChecks: _actionChecks,
                          tocExpanded: _tocExpanded,
                          onTocExpanded: (v) =>
                              setState(() => _tocExpanded = v),
                          onBack: _backToList,
                          onSetStatus: _setStatus,
                          onToggleFavorite: _toggleFavorite,
                          onSaveMemo: _saveMemo,
                          onSaveApplyNote: _saveApplyNote,
                          onToggleAction: _toggleAction,
                          onNavigate: _navigateArticle,
                          onScrollToSection: _scrollToSection,
                          compactChrome: true,
                        )
                      : _ArticleList(
                          articles: _filteredArticles,
                          selectedId: null,
                          statuses: _statuses,
                          favorites: _favorites,
                          scrollController: _listScrollController,
                          onSelect: (id) => _selectArticle(id, isWide: false),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadingHeader extends StatelessWidget {
  const _ReadingHeader({
    required this.total,
    required this.reading,
    required this.reviewed,
    required this.favorites,
  });

  final int total;
  final int reading;
  final int reviewed;
  final int favorites;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : reviewed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '사업전략연구실',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: ControlColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '엄선된 전략 글을 읽고, 판단하고, 내 사업에 적용하는 독서 공간',
          style: TextStyle(color: ControlColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatChip(label: '전체', value: '$total편'),
            _StatChip(label: '읽는 중', value: '$reading'),
            _StatChip(label: '읽기 완료', value: '$reviewed'),
            _StatChip(label: '즐겨찾기', value: '$favorites'),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '진행 ${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ControlColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: ControlColors.border,
                      color: ControlColors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ControlColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ControlColors.border),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: const TextStyle(
                  fontSize: 12,
                  color: ControlColors.textMuted,
                ),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ControlColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.searchController,
    required this.categoryFilter,
    required this.quickFilter,
    required this.onCategoryChanged,
    required this.onQuickFilterChanged,
  });

  final TextEditingController searchController;
  final String? categoryFilter;
  final _QuickFilter quickFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_QuickFilter> onQuickFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: '제목·키워드 검색',
            prefixIcon: Icon(Icons.search, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _QuickFilter.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_quickLabel(filter)),
                    selected: quickFilter == filter,
                    onSelected: (_) => onQuickFilterChanged(filter),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('전체 분야'),
                  selected: categoryFilter == null,
                  onSelected: (_) => onCategoryChanged(null),
                ),
              ),
              for (final category in StrategyCategories.all)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(category),
                    selected: categoryFilter == category,
                    onSelected: (selected) =>
                        onCategoryChanged(selected ? category : null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _quickLabel(_QuickFilter filter) {
    switch (filter) {
      case _QuickFilter.recommend:
        return '추천순';
      case _QuickFilter.unread:
        return '미읽음';
      case _QuickFilter.reading:
        return '읽는 중';
      case _QuickFilter.reviewed:
        return '완료';
      case _QuickFilter.favorites:
        return '즐겨찾기';
    }
  }
}

class _ArticleList extends StatelessWidget {
  const _ArticleList({
    required this.articles,
    required this.selectedId,
    required this.statuses,
    required this.favorites,
    required this.scrollController,
    required this.onSelect,
  });

  final List<StrategyArticle> articles;
  final String? selectedId;
  final Map<String, String> statuses;
  final Set<String> favorites;
  final ScrollController scrollController;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Center(
        child: Text(
          '조건에 맞는 글이 없습니다.',
          style: TextStyle(color: ControlColors.textMuted),
        ),
      );
    }

    return Semantics(
      label: '전략 글 목록 ${articles.length}편',
      child: ListView.separated(
        controller: scrollController,
        itemCount: articles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final article = articles[index];
          final selected = article.id == selectedId;
          final status = statuses[article.id] ?? 'unread';
          return _ArticleListTile(
            article: article,
            selected: selected,
            status: status,
            favorite: favorites.contains(article.id),
            onTap: () => onSelect(article.id),
          );
        },
      ),
    );
  }
}

class _ArticleListTile extends StatelessWidget {
  const _ArticleListTile({
    required this.article,
    required this.selected,
    required this.status,
    required this.favorite,
    required this.onTap,
  });

  final StrategyArticle article;
  final bool selected;
  final String status;
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${article.title}, ${article.readingMinutes}분 읽기',
      child: Material(
        color: selected ? ControlColors.tealSoft : ControlColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? ControlColors.teal : ControlColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: selected
                              ? ControlColors.teal
                              : ControlColors.textPrimary,
                        ),
                      ),
                    ),
                    if (favorite)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          color: ControlColors.accentWarm,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  article.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: ControlColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${article.readingMinutes}분',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ControlColors.textMuted,
                      ),
                    ),
                    Text(
                      '· ${article.category}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ControlColors.textMuted,
                      ),
                    ),
                    Text(
                      '· ${_statusLabel(status)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'reviewed'
                            ? ControlColors.accentGreen
                            : ControlColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'reading':
        return '읽는 중';
      case 'reviewed':
        return '검토 완료';
      default:
        return '미읽음';
    }
  }
}

class _ReadingPane extends StatefulWidget {
  const _ReadingPane({
    required this.article,
    required this.scrollController,
    required this.sectionKeys,
    required this.status,
    required this.isFavorite,
    required this.memo,
    required this.applyNote,
    required this.actionChecks,
    required this.tocExpanded,
    required this.onTocExpanded,
    required this.onBack,
    required this.onSetStatus,
    required this.onToggleFavorite,
    required this.onSaveMemo,
    required this.onSaveApplyNote,
    required this.onToggleAction,
    required this.onNavigate,
    required this.onScrollToSection,
    this.compactChrome = false,
  });

  final StrategyArticle article;
  final ScrollController scrollController;
  final Map<String, GlobalKey> sectionKeys;
  final String status;
  final bool isFavorite;
  final String memo;
  final String applyNote;
  final Map<String, bool> actionChecks;
  final bool tocExpanded;
  final ValueChanged<bool> onTocExpanded;
  final VoidCallback? onBack;
  final Future<void> Function(String id, String status) onSetStatus;
  final Future<void> Function(String id) onToggleFavorite;
  final Future<void> Function(String id, String text) onSaveMemo;
  final Future<void> Function(String id, String text) onSaveApplyNote;
  final Future<void> Function(String id, int index, bool value) onToggleAction;
  final void Function(int delta) onNavigate;
  final void Function(String sectionId) onScrollToSection;
  final bool compactChrome;

  @override
  State<_ReadingPane> createState() => _ReadingPaneState();
}

class _ReadingPaneState extends State<_ReadingPane> {
  late final TextEditingController _memoController;
  late final TextEditingController _applyController;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: widget.memo);
    _applyController = TextEditingController(text: widget.applyNote);
  }

  @override
  void didUpdateWidget(covariant _ReadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _memoController.text = widget.memo;
      _applyController.text = widget.applyNote;
      for (final section in widget.article.readingSections) {
        widget.sectionKeys.putIfAbsent(section.id, GlobalKey.new);
      }
      widget.sectionKeys.putIfAbsent('options', GlobalKey.new);
      widget.sectionKeys.putIfAbsent('questions', GlobalKey.new);
      widget.sectionKeys.putIfAbsent('actions', GlobalKey.new);
    } else {
      if (oldWidget.memo != widget.memo &&
          _memoController.text != widget.memo) {
        _memoController.text = widget.memo;
      }
      if (oldWidget.applyNote != widget.applyNote &&
          _applyController.text != widget.applyNote) {
        _applyController.text = widget.applyNote;
      }
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _applyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    for (final section in article.readingSections) {
      widget.sectionKeys.putIfAbsent(section.id, GlobalKey.new);
    }
    widget.sectionKeys.putIfAbsent('options', GlobalKey.new);
    widget.sectionKeys.putIfAbsent('questions', GlobalKey.new);
    widget.sectionKeys.putIfAbsent('actions', GlobalKey.new);

    return Material(
      color: ControlColors.surface,
      borderRadius: BorderRadius.circular(widget.compactChrome ? 0 : 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.compactChrome ? 0 : 14),
          border: widget.compactChrome
              ? null
              : Border.all(color: ControlColors.border),
        ),
        child: Column(
          children: [
            if (widget.onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('목록으로 돌아가기'),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.compactChrome ? 1100 : 920,
                  ),
                  child: ListView(
                    controller: widget.scrollController,
                    padding: EdgeInsets.fromLTRB(
                      widget.compactChrome ? 12 : 20,
                      widget.compactChrome ? 8 : 12,
                      widget.compactChrome ? 12 : 20,
                      widget.compactChrome ? 20 : 32,
                    ),
                    children: [
                      Text(
                        article.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article.whyRead,
                        style: _bodyStyle.copyWith(
                          color: ControlColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _MetaPill(
                            icon: Icons.schedule,
                            label: '약 ${article.readingMinutes}분',
                          ),
                          _MetaPill(
                            icon: Icons.category_outlined,
                            label: article.category,
                          ),
                          _MetaPill(
                            icon: Icons.signal_cellular_alt,
                            label: article.difficulty,
                          ),
                          _MetaPill(
                            icon: Icons.person_outline,
                            label: article.audience,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ControlColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ControlColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '핵심 질문',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ControlColors.teal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(article.keyQuestion, style: _bodyStyle),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: widget.tocExpanded,
                          onExpansionChanged: widget.onTocExpanded,
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            '목차',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          children: [
                            for (final section in article.readingSections)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () =>
                                      widget.onScrollToSection(section.id),
                                  child: Text(section.title),
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () =>
                                    widget.onScrollToSection('options'),
                                child: const Text('선택 가능한 전략'),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () =>
                                    widget.onScrollToSection('questions'),
                                child: const Text('사업가의 생각거리'),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () =>
                                    widget.onScrollToSection('actions'),
                                child: const Text('이번 달 실행할 행동'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final section in article.readingSections) ...[
                        KeyedSubtree(
                          key: widget.sectionKeys[section.id],
                          child: _ProseSection(
                            title: section.title,
                            body: section.body,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      KeyedSubtree(
                        key: widget.sectionKeys['options'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('선택 가능한 전략', style: _sectionTitleStyle),
                            const SizedBox(height: 10),
                            for (final option in article.options) ...[
                              Text(
                                option.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(option.description, style: _bodyStyle),
                              const SizedBox(height: 6),
                              Text(
                                '장점: ${option.pros}',
                                style: _bodyStyle.copyWith(fontSize: 15),
                              ),
                              Text(
                                '위험·전제: ${option.risks}',
                                style: _bodyStyle.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                      ),
                      KeyedSubtree(
                        key: widget.sectionKeys['questions'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('사업가의 생각거리', style: _sectionTitleStyle),
                            const SizedBox(height: 8),
                            for (
                              var i = 0;
                              i < article.reviewQuestions.length;
                              i++
                            )
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${i + 1}. ${article.reviewQuestions[i]}',
                                  style: _bodyStyle,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: widget.sectionKeys['actions'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '이번 달 실행할 행동',
                              style: _sectionTitleStyle,
                            ),
                            const SizedBox(height: 8),
                            for (
                              var i = 0;
                              i < article.monthActions.length;
                              i++
                            )
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value:
                                    widget
                                        .actionChecks[StrategyLabProgressStore.actionEntryKey(
                                      article.id,
                                      i,
                                    )] ==
                                    true,
                                title: Text(
                                  article.monthActions[i],
                                  style: _bodyStyle.copyWith(fontSize: 15),
                                ),
                                onChanged: (v) => widget.onToggleAction(
                                  article.id,
                                  i,
                                  v ?? false,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('내 사업에 적용할 점', style: _sectionTitleStyle),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _applyController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '이 글을 읽고 내 사업에 바로 적용할 점을 적어 두세요.',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => widget.onSaveApplyNote(article.id, v),
                      ),
                      const SizedBox(height: 16),
                      const Text('회장 메모', style: _sectionTitleStyle),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _memoController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '전략 메모를 남겨 두세요. 브라우저에 저장됩니다.',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => widget.onSaveMemo(article.id, v),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                widget.onToggleFavorite(article.id),
                            icon: Icon(
                              widget.isFavorite
                                  ? Icons.star
                                  : Icons.star_border,
                            ),
                            label: Text(widget.isFavorite ? '즐겨찾기됨' : '즐겨찾기'),
                          ),
                          ChoiceChip(
                            label: const Text('읽는 중'),
                            selected: widget.status == 'reading',
                            onSelected: (_) =>
                                widget.onSetStatus(article.id, 'reading'),
                          ),
                          ChoiceChip(
                            label: const Text('읽기 완료'),
                            selected: widget.status == 'reviewed',
                            onSelected: (_) =>
                                widget.onSetStatus(article.id, 'reviewed'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => widget.onNavigate(-1),
                              child: const Text('이전 글'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => widget.onNavigate(1),
                              child: const Text('다음 글'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProseSection extends StatelessWidget {
  const _ProseSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionTitleStyle),
        const SizedBox(height: 8),
        SelectableText(body, style: _bodyStyle),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ControlColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ControlColors.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
