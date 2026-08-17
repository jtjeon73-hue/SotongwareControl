import 'package:flutter/material.dart';

import '../data/idea_bank_seed.dart';
import '../models/idea_bank.dart';
import '../services/idea_bank_store.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';

/// 뉴 아이디어 뱅크 — 데스크톱은 탐색·관리, 모바일은 목록→집중 읽기.
class IdeaBankScreen extends StatefulWidget {
  const IdeaBankScreen({
    super.key,
    this.onSendToWorkInstruction,
    this.onImmersiveModeChanged,
    this.onOpenDrawer,
  });

  final ValueChanged<IdeaToPlanningSeed>? onSendToWorkInstruction;
  final ValueChanged<bool>? onImmersiveModeChanged;
  final VoidCallback? onOpenDrawer;

  @override
  State<IdeaBankScreen> createState() => _IdeaBankScreenState();
}

class _IdeaBankScreenState extends State<IdeaBankScreen> {
  static const _wideBreakpoint = 900.0;
  static const _barHeight = 52.0;

  final _store = IdeaBankStore();
  final _search = TextEditingController();
  final _listScrollController = ScrollController();
  final _detailScrollController = ScrollController();

  List<IdeaBankItem> _items = [];
  bool _loading = true;
  int? _yearFilter;
  int? _monthFilter;
  bool _favoritesOnly = false;
  bool _recentOnly = false;
  bool _topOnly = false;
  String? _categoryFilter;

  String? _selectedId;
  var _mobileReading = false;
  var _fullscreenReading = false;
  var _shellImmersiveRequested = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    if (_shellImmersiveRequested) {
      widget.onImmersiveModeChanged?.call(false);
    }
    _search.dispose();
    _listScrollController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final items = await _store.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<IdeaBankItem> get _filtered {
    var list = List<IdeaBankItem>.from(_items);
    if (_yearFilter != null) {
      list = list.where((e) => e.year == _yearFilter).toList();
    }
    if (_monthFilter != null) {
      list = list.where((e) => e.month == _monthFilter).toList();
    }
    if (_favoritesOnly) {
      list = list.where((e) => e.favorite).toList();
    }
    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      list = list.where((e) => e.category == _categoryFilter).toList();
    }
    if (_topOnly) {
      list = list
          .where(
            (e) =>
                e.favorite ||
                e.status == IdeaBankStatuses.planningCandidate ||
                e.status == IdeaBankStatuses.sentToWorkOrder,
          )
          .toList();
    }
    if (_recentOnly) {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (list.length > 20) list = list.take(20).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.oneLiner.toLowerCase().contains(q) ||
            e.targetCustomer.toLowerCase().contains(q) ||
            e.product.toLowerCase().contains(q) ||
            e.memo.toLowerCase().contains(q) ||
            e.whyNow.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  Set<int> get _years {
    final y = _items.map((e) => e.year).toSet().toList()..sort();
    if (y.isEmpty) y.add(DateTime.now().year);
    return y.toSet();
  }

  int get _activeFilterCount {
    var n = 0;
    if (_search.text.trim().isNotEmpty) n++;
    if (_yearFilter != null) n++;
    if (_monthFilter != null) n++;
    if (_favoritesOnly) n++;
    if (_topOnly) n++;
    if (_recentOnly) n++;
    if (_categoryFilter != null) n++;
    return n;
  }

  IdeaBankItem? get _selectedItem {
    final id = _selectedId;
    if (id == null) return null;
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _syncShellImmersive(bool isWide) {
    final hide = !isWide;
    if (_shellImmersiveRequested == hide) return;
    _shellImmersiveRequested = hide;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onImmersiveModeChanged?.call(hide);
    });
  }

  void _openReading(String id) {
    final same = _selectedId == id && _mobileReading;
    setState(() {
      _selectedId = id;
      _mobileReading = true;
      _fullscreenReading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!same && _detailScrollController.hasClients) {
        _detailScrollController.jumpTo(0);
      }
    });
  }

  void _openList() {
    setState(() {
      _mobileReading = false;
      _fullscreenReading = false;
    });
  }

  Future<void> _createIdea() async {
    final now = DateTime.now();
    final iso = now.toUtc().toIso8601String();
    final item = IdeaBankItem(
      id: IdeaBankStore.newId(now),
      title: '새 아이디어',
      createdAt: iso,
      updatedAt: iso,
      year: now.year,
      month: now.month,
    );
    await _store.upsert(item);
    await _reload();
    if (mounted) await _editIdea(item);
  }

  Future<void> _toggleFavorite(IdeaBankItem item) async {
    await _store.upsert(
      item.copyWith(
        favorite: !item.favorite,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    await _reload();
  }

  Future<void> _editIdea(IdeaBankItem item) async {
    final title = TextEditingController(text: item.title);
    final one = TextEditingController(text: item.oneLiner);
    final customer = TextEditingController(text: item.targetCustomer);
    final product = TextEditingController(text: item.product);
    final memo = TextEditingController(text: item.memo);
    var status = item.status;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('아이디어 편집'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: '제목'),
                  ),
                  TextField(
                    controller: one,
                    decoration: const InputDecoration(labelText: '한줄 설명'),
                  ),
                  TextField(
                    controller: customer,
                    decoration: const InputDecoration(labelText: '대상 고객'),
                  ),
                  TextField(
                    controller: product,
                    decoration: const InputDecoration(labelText: '만들 상품'),
                  ),
                  TextField(
                    controller: memo,
                    decoration: const InputDecoration(labelText: '메모'),
                    maxLines: 3,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: [
                      for (final s in IdeaBankStatuses.all)
                        DropdownMenuItem(
                          value: s,
                          child: Text(IdeaBankStatuses.labelKo(s)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => status = v);
                    },
                    decoration: const InputDecoration(labelText: '상태'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _store.upsert(
      item.copyWith(
        title: title.text.trim().isEmpty ? item.title : title.text.trim(),
        oneLiner: one.text.trim(),
        targetCustomer: customer.text.trim(),
        product: product.text.trim(),
        memo: memo.text.trim(),
        status: status,
        updatedAt: now,
      ),
    );
    await _reload();
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ControlColors.surface,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.88;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void sync(VoidCallback fn) {
              setState(fn);
              setModalState(() {});
            }

            return SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '필터 · 검색',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => sync(() {
                            _search.clear();
                            _yearFilter = null;
                            _monthFilter = null;
                            _favoritesOnly = false;
                            _topOnly = false;
                            _recentOnly = false;
                            _categoryFilter = null;
                          }),
                          child: const Text('초기화'),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        TextField(
                          controller: _search,
                          onChanged: (_) => sync(() {}),
                          decoration: const InputDecoration(
                            hintText: '제목·고객·상품·메모 검색',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildYearMonthChips(sync),
                        const SizedBox(height: 8),
                        _buildQuickFilterChips(sync),
                        const SizedBox(height: 12),
                        const Text(
                          '카테고리',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        _buildCategoryWrap(sync),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('적용 (${_filtered.length}건)'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        _syncShellImmersive(isWide);
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (isWide) return _buildDesktop();
        return _buildMobile();
      },
    );
  }

  Widget _buildDesktop() {
    final visible = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '뉴 아이디어 뱅크',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _createIdea,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('추가'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '새로운 기회와 제작 아이디어를 발견하는 곳입니다. '
                '(사업전략연구실=공부·판단, 작업지시제작소=지시 전환, AI 제작공정=단계 진행)',
                style: TextStyle(
                  color: ControlColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '제목·고객·상품·메모 검색',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ..._yearMonthDropdowns(),
                  ..._quickFilterChipWidgets(() => setState(() {})),
                ],
              ),
              const SizedBox(height: 8),
              _buildCategoryWrap((fn) => setState(fn)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildDesktopList(visible)),
      ],
    );
  }

  Widget _buildMobile() {
    final reading = _mobileReading ? _selectedItem : null;
    return ColoredBox(
      color: ControlColors.surface,
      child: Column(
        children: [
          _mobileCompactBar(fullscreen: _fullscreenReading),
          Expanded(
            child: reading == null
                ? _buildMobileList()
                : _IdeaReadingPane(
                    item: reading,
                    scrollController: _detailScrollController,
                    fullscreen: _fullscreenReading,
                    onToggleFavorite: () => _toggleFavorite(reading),
                    onEdit: () => _editIdea(reading),
                    onSendAs: (product) => _sendAs(reading, product),
                    onSendToWork: widget.onSendToWorkInstruction == null
                        ? null
                        : () => _sendAs(
                            reading,
                            reading.product.isEmpty ? 'ebook' : reading.product,
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mobileCompactBar({required bool fullscreen}) {
    if (fullscreen) {
      return SizedBox(
        height: _barHeight,
        child: Material(
          color: ControlColors.surface,
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _fullscreenReading = false),
                child: const Text('전체화면 종료'),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    final filterCount = _activeFilterCount;
    return SizedBox(
      height: _barHeight,
      child: Material(
        color: ControlColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              IconButton(
                tooltip: widget.onOpenDrawer != null ? '메뉴' : '목록',
                onPressed: widget.onOpenDrawer ?? _openList,
                icon: Icon(
                  widget.onOpenDrawer != null ? Icons.menu : Icons.arrow_back,
                ),
              ),
              const Expanded(
                child: Text(
                  '뉴 아이디어 뱅크',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              if (_mobileReading)
                TextButton(onPressed: _openList, child: const Text('목록')),
              TextButton(
                onPressed: _openFilterSheet,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('필터'),
                    if (filterCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ControlColors.tealSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$filterCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ControlColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_mobileReading)
                IconButton(
                  tooltip: '전체화면 읽기',
                  onPressed: () => setState(() => _fullscreenReading = true),
                  icon: const Icon(Icons.fullscreen),
                )
              else
                IconButton(
                  tooltip: '추가',
                  onPressed: _createIdea,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    final visible = _filtered;
    if (visible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '조건에 맞는 아이디어가 없습니다.\n필터를 조정하거나 추가해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ControlColors.textMuted, height: 1.4),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final item = visible[i];
        final selected = item.id == _selectedId;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: selected ? ControlColors.tealSoft : ControlColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? ControlColors.teal : ControlColors.border,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openReading(item.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (item.favorite)
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: ControlColors.accentWarm,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (item.category.isNotEmpty)
                        IdeaBankCategories.labelKo(item.category),
                      if (item.isSeed) '시드',
                      IdeaBankStatuses.labelKo(item.status),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ControlColors.textMuted,
                    ),
                  ),
                  if (item.oneLiner.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.oneLiner,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.35, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopList(List<IdeaBankItem> visible) {
    if (visible.isEmpty) {
      return const Center(
        child: Text(
          '아이디어가 없습니다. 추가 버튼으로 시작하세요.',
          style: TextStyle(color: ControlColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final item = visible[i];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: ControlColors.border),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                if (item.category.isNotEmpty)
                  IdeaBankCategories.labelKo(item.category),
                if (item.isSeed) '시드',
                IdeaBankStatuses.labelKo(item.status),
                if (item.oneLiner.isNotEmpty) item.oneLiner,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              _IdeaDetailBody(
                item: item,
                onToggleFavorite: () => _toggleFavorite(item),
                onEdit: () => _editIdea(item),
                onSendAs: (product) => _sendAs(item, product),
                onSendToWork: widget.onSendToWorkInstruction == null
                    ? null
                    : () => _sendAs(
                        item,
                        item.product.isEmpty ? 'ebook' : item.product,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _yearMonthDropdowns() {
    return [
      DropdownButton<int?>(
        value: _yearFilter,
        hint: const Text('연도'),
        items: [
          const DropdownMenuItem(value: null, child: Text('전체 연도')),
          for (final y in _years) DropdownMenuItem(value: y, child: Text('$y')),
        ],
        onChanged: (v) => setState(() {
          _yearFilter = v;
          _monthFilter = null;
        }),
      ),
      DropdownButton<int?>(
        value: _monthFilter,
        hint: const Text('월'),
        items: [
          const DropdownMenuItem(value: null, child: Text('전체 월')),
          for (var m = 1; m <= 12; m++)
            DropdownMenuItem(value: m, child: Text('$m월')),
        ],
        onChanged: (v) => setState(() => _monthFilter = v),
      ),
    ];
  }

  Widget _buildYearMonthChips(void Function(VoidCallback) sync) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<int?>(
          value: _yearFilter,
          hint: const Text('연도'),
          items: [
            const DropdownMenuItem(value: null, child: Text('전체 연도')),
            for (final y in _years)
              DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged: (v) => sync(() {
            _yearFilter = v;
            _monthFilter = null;
          }),
        ),
        DropdownButton<int?>(
          value: _monthFilter,
          hint: const Text('월'),
          items: [
            const DropdownMenuItem(value: null, child: Text('전체 월')),
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text('$m월')),
          ],
          onChanged: (v) => sync(() => _monthFilter = v),
        ),
      ],
    );
  }

  List<Widget> _quickFilterChipWidgets(VoidCallback onChanged) {
    return [
      FilterChip(
        label: const Text('즐겨찾기'),
        selected: _favoritesOnly,
        onSelected: (v) {
          _favoritesOnly = v;
          onChanged();
        },
      ),
      FilterChip(
        label: const Text('TOP'),
        selected: _topOnly,
        onSelected: (v) {
          _topOnly = v;
          onChanged();
        },
      ),
      FilterChip(
        label: const Text('최근'),
        selected: _recentOnly,
        onSelected: (v) {
          _recentOnly = v;
          onChanged();
        },
      ),
    ];
  }

  Widget _buildQuickFilterChips(void Function(VoidCallback) sync) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _quickFilterChipWidgets(() => sync(() {})),
    );
  }

  Widget _buildCategoryWrap(void Function(VoidCallback) sync) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        FilterChip(
          label: const Text('전체 카테고리'),
          selected: _categoryFilter == null,
          onSelected: (_) => sync(() => _categoryFilter = null),
        ),
        for (final c in IdeaBankCategories.all)
          FilterChip(
            label: Text(IdeaBankCategories.labelKo(c)),
            selected: _categoryFilter == c,
            onSelected: (_) => sync(() => _categoryFilter = c),
          ),
      ],
    );
  }

  void _sendAs(IdeaBankItem item, String product) {
    widget.onSendToWorkInstruction?.call(
      IdeaToPlanningSeed(
        title: item.title,
        targetCustomer: item.targetCustomer,
        field: product,
        description: item.oneLiner.isNotEmpty
            ? item.oneLiner
            : item.howToBusiness,
        memo: [
          if (item.whyNow.isNotEmpty) item.whyNow,
          if (item.memo.isNotEmpty) item.memo,
        ].join('\n'),
      ),
    );
  }
}

class _IdeaReadingPane extends StatelessWidget {
  const _IdeaReadingPane({
    required this.item,
    required this.scrollController,
    required this.fullscreen,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onSendAs,
    this.onSendToWork,
  });

  final IdeaBankItem item;
  final ScrollController scrollController;
  final bool fullscreen;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final ValueChanged<String> onSendAs;
  final VoidCallback? onSendToWork;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        fullscreen ? 12 : 16,
        fullscreen ? 8 : 12,
        fullscreen ? 12 : 16,
        28,
      ),
      children: [
        Text(
          item.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        if (item.oneLiner.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.oneLiner,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: ControlColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (item.category.isNotEmpty)
              _MetaChip(IdeaBankCategories.labelKo(item.category)),
            _MetaChip(IdeaBankStatuses.labelKo(item.status)),
            if (item.isSeed) const _MetaChip('시드'),
            if (item.infoAsOf.isNotEmpty) _MetaChip('기준 ${item.infoAsOf}'),
            if (item.lastCheckedAt.isNotEmpty)
              _MetaChip('확인 ${item.lastCheckedAt}'),
          ],
        ),
        const SizedBox(height: 16),
        _IdeaDetailBody(
          item: item,
          onToggleFavorite: onToggleFavorite,
          onEdit: onEdit,
          onSendAs: onSendAs,
          onSendToWork: onSendToWork,
        ),
      ],
    );
  }
}

class _IdeaDetailBody extends StatelessWidget {
  const _IdeaDetailBody({
    required this.item,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onSendAs,
    this.onSendToWork,
  });

  final IdeaBankItem item;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final ValueChanged<String> onSendAs;
  final VoidCallback? onSendToWork;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.whyNow.isNotEmpty || item.recommendReason.isNotEmpty)
          _ideaLine(
            '왜 지금 주목할 만한가',
            item.whyNow.isNotEmpty ? item.whyNow : item.recommendReason,
          ),
        if (item.targetCustomer.isNotEmpty)
          _ideaLine('어떤 사람에게 필요한가', item.targetCustomer),
        if (item.howToBusiness.isNotEmpty)
          _ideaLine('사업으로 연결하는 방법', item.howToBusiness),
        if (item.revenueMethod.isNotEmpty)
          _ideaLine('수익화 아이디어', item.revenueMethod),
        if (item.businessUnits.isNotEmpty)
          _ideaLine('적용 가능한 사업부', item.businessUnits),
        if (item.product.isNotEmpty) _ideaLine('만들 상품', item.product),
        if (item.difficulty.isNotEmpty || item.estimatedScale.isNotEmpty)
          _ideaLine(
            '난이도/규모',
            [
              if (item.difficulty.isNotEmpty) item.difficulty,
              if (item.estimatedScale.isNotEmpty) item.estimatedScale,
            ].join(' · '),
          ),
        if (item.memo.isNotEmpty) _ideaLine('메모/평가', item.memo),
        if (item.sources.any(
          (s) => IdeaBankSourceRef.isTrustedHttpUrl(s.sourceUrl),
        )) ...[
          const Text(
            '참고자료 / 출처',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: ControlColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          for (final s in item.sources)
            if (IdeaBankSourceRef.isTrustedHttpUrl(s.sourceUrl))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => ExternalUrl.open(s.sourceUrl),
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(s.sourceTitle),
                ),
              ),
          const SizedBox(height: 8),
        ],
        const Text(
          '이 아이디어로 무엇을 만들까?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('전자책으로 검토'),
              onPressed: () => onSendAs('ebook'),
            ),
            ActionChip(
              label: const Text('앱으로 검토'),
              onPressed: () => onSendAs('app'),
            ),
            ActionChip(
              label: const Text('콘텐츠로 검토'),
              onPressed: () => onSendAs('contents'),
            ),
            ActionChip(
              label: const Text('사이트로 검토'),
              onPressed: () => onSendAs('site'),
            ),
            ActionChip(
              label: const Text('홍보사업으로 검토'),
              onPressed: () => onSendAs('promo_site'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: '즐겨찾기',
              iconSize: 22,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(item.favorite ? Icons.star : Icons.star_border),
              onPressed: onToggleFavorite,
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              onPressed: onEdit,
              child: const Text('편집'),
            ),
            if (onSendToWork != null)
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                onPressed: onSendToWork,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('작업지시 제작소로'),
              ),
          ],
        ),
      ],
    );
  }

  static Widget _ideaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: ControlColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, height: 1.45)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ControlColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: ControlColors.textSecondary,
        ),
      ),
    );
  }
}
