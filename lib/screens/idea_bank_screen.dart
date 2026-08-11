import 'package:flutter/material.dart';

import '../data/idea_bank_seed.dart';
import '../models/idea_bank.dart';
import '../services/idea_bank_store.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';

class IdeaBankScreen extends StatefulWidget {
  const IdeaBankScreen({super.key, this.onSendToWorkInstruction});

  final ValueChanged<IdeaToPlanningSeed>? onSendToWorkInstruction;

  @override
  State<IdeaBankScreen> createState() => _IdeaBankScreenState();
}

class _IdeaBankScreenState extends State<IdeaBankScreen> {
  final _store = IdeaBankStore();
  final _search = TextEditingController();
  List<IdeaBankItem> _items = [];
  bool _loading = true;
  int? _yearFilter;
  int? _monthFilter;
  bool _favoritesOnly = false;
  bool _recentOnly = false;
  bool _topOnly = false;
  String? _categoryFilter;
  /// 모바일에서 카테고리 Wrap을 접기/펼치기. PC는 항상 펼침.
  bool _categoryExpanded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
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
            e.memo.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  Set<int> get _years {
    final y = _items.map((e) => e.year).toSet().toList()..sort();
    if (y.isEmpty) y.add(DateTime.now().year);
    return y.toSet();
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

  @override
  Widget build(BuildContext context) {
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
                '(사업전략연구실=공부·판단, 작업지시제작소=지시 전환, 소통24워크=실제 제작)',
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
                  DropdownButton<int?>(
                    value: _yearFilter,
                    hint: const Text('연도'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('전체 연도'),
                      ),
                      for (final y in _years)
                        DropdownMenuItem(value: y, child: Text('$y')),
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
                      const DropdownMenuItem(
                        value: null,
                        child: Text('전체 월'),
                      ),
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text('$m월')),
                    ],
                    onChanged: (v) => setState(() => _monthFilter = v),
                  ),
                  FilterChip(
                    label: const Text('즐겨찾기'),
                    selected: _favoritesOnly,
                    onSelected: (v) => setState(() => _favoritesOnly = v),
                  ),
                  FilterChip(
                    label: const Text('TOP'),
                    selected: _topOnly,
                    onSelected: (v) => setState(() => _topOnly = v),
                  ),
                  FilterChip(
                    label: const Text('최근'),
                    selected: _recentOnly,
                    onSelected: (v) => setState(() => _recentOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCategoryFilters(context),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
              ? const Center(
                  child: Text(
                    '아이디어가 없습니다. 추가 버튼으로 시작하세요.',
                    style: TextStyle(color: ControlColors.textMuted),
                  ),
                )
              : ListView.builder(
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
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
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
                          if (item.whyNow.isNotEmpty ||
                              item.recommendReason.isNotEmpty)
                            _ideaLine(
                              '왜 지금',
                              item.whyNow.isNotEmpty
                                  ? item.whyNow
                                  : item.recommendReason,
                            ),
                          if (item.targetCustomer.isNotEmpty)
                            _ideaLine('누구에게', item.targetCustomer),
                          if (item.howToBusiness.isNotEmpty ||
                              item.revenueMethod.isNotEmpty)
                            _ideaLine(
                              '사업 연결',
                              item.howToBusiness.isNotEmpty
                                  ? item.howToBusiness
                                  : item.revenueMethod,
                            ),
                          if (item.difficulty.isNotEmpty)
                            _ideaLine('난이도/규모', item.difficulty),
                          if (item.infoAsOf.isNotEmpty ||
                              item.lastCheckedAt.isNotEmpty)
                            _ideaLine(
                              '정보 기준',
                              '기준 ${item.infoAsOf.isEmpty ? '-' : item.infoAsOf} · 확인 ${item.lastCheckedAt.isEmpty ? '-' : item.lastCheckedAt}',
                            ),
                          if (item.memo.isNotEmpty)
                            _ideaLine('메모/평가', item.memo),
                          for (final s in item.sources)
                            if (IdeaBankSourceRef.isTrustedHttpUrl(s.sourceUrl))
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      ExternalUrl.open(s.sourceUrl),
                                  icon: const Icon(Icons.link, size: 18),
                                  label: Text(s.sourceTitle),
                                ),
                              ),
                          const SizedBox(height: 6),
                          const Text(
                            '이 아이디어로 무엇을 만들까?',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                label: const Text('전자책으로 검토'),
                                onPressed: () => _sendAs(item, 'ebook'),
                              ),
                              ActionChip(
                                label: const Text('앱으로 검토'),
                                onPressed: () => _sendAs(item, 'app'),
                              ),
                              ActionChip(
                                label: const Text('콘텐츠로 검토'),
                                onPressed: () => _sendAs(item, 'contents'),
                              ),
                              ActionChip(
                                label: const Text('사이트로 검토'),
                                onPressed: () => _sendAs(item, 'site'),
                              ),
                              ActionChip(
                                label: const Text('홍보사업으로 검토'),
                                onPressed: () => _sendAs(item, 'promo_site'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  item.favorite
                                      ? Icons.star
                                      : Icons.star_border,
                                ),
                                onPressed: () async {
                                  await _store.upsert(
                                    item.copyWith(
                                      favorite: !item.favorite,
                                      updatedAt: DateTime.now()
                                          .toUtc()
                                          .toIso8601String(),
                                    ),
                                  );
                                  await _reload();
                                },
                              ),
                              TextButton(
                                onPressed: () => _editIdea(item),
                                child: const Text('편집'),
                              ),
                              if (widget.onSendToWorkInstruction != null)
                                TextButton.icon(
                                  onPressed: () => _sendAs(
                                    item,
                                    item.product.isEmpty
                                        ? 'ebook'
                                        : item.product,
                                  ),
                                  icon: const Icon(
                                    Icons.send_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('작업지시 제작소로'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
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

  Widget _buildCategoryFilters(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    final wrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        FilterChip(
          label: const Text('전체 카테고리'),
          selected: _categoryFilter == null,
          onSelected: (_) => setState(() => _categoryFilter = null),
        ),
        for (final c in IdeaBankCategories.all)
          FilterChip(
            label: Text(IdeaBankCategories.labelKo(c)),
            selected: _categoryFilter == c,
            onSelected: (_) => setState(() => _categoryFilter = c),
          ),
      ],
    );

    if (!isMobile) return wrap;

    final selectedLabel = _categoryFilter == null
        ? '전체 카테고리'
        : IdeaBankCategories.labelKo(_categoryFilter!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                setState(() => _categoryExpanded = !_categoryExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _categoryExpanded
                          ? '카테고리'
                          : '카테고리 · $selectedLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _categoryExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 22,
                    color: ControlColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_categoryExpanded) ...[const SizedBox(height: 6), wrap],
      ],
    );
  }

  Widget _ideaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
          Text(value, style: const TextStyle(fontSize: 14, height: 1.35)),
        ],
      ),
    );
  }
}
