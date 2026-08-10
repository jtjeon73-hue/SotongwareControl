import 'package:flutter/material.dart';

import '../models/idea_bank.dart';
import '../services/idea_bank_store.dart';
import '../theme/control_theme.dart';

class IdeaBankScreen extends StatefulWidget {
  const IdeaBankScreen({
    super.key,
    this.onSendToWorkInstruction,
  });

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
    if (_topOnly) {
      list = list
          .where((e) =>
              e.favorite ||
              e.status == IdeaBankStatuses.planningCandidate ||
              e.status == IdeaBankStatuses.sentToWorkOrder)
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
                'AI로 온라인에서 수익을 낼 수 있는 사업 아이디어를 축적합니다.',
                style: TextStyle(color: ControlColors.textSecondary),
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<int?>(
                      value: _yearFilter,
                      hint: const Text('연도'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('전체 연도')),
                        for (final y in _years)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (v) => setState(() {
                        _yearFilter = v;
                        _monthFilter = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int?>(
                      value: _monthFilter,
                      hint: const Text('월'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('전체 월')),
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(
                            value: m,
                            child: Text('$m월'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _monthFilter = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('즐겨찾기'),
                      selected: _favoritesOnly,
                      onSelected: (v) => setState(() => _favoritesOnly = v),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('TOP'),
                      selected: _topOnly,
                      onSelected: (v) => setState(() => _topOnly = v),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('최근'),
                      selected: _recentOnly,
                      onSelected: (v) => setState(() => _recentOnly = v),
                    ),
                  ],
                ),
              ),
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
                          child: ListTile(
                            title: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${item.year}-${item.month.toString().padLeft(2, '0')} · '
                              '${IdeaBankStatuses.labelKo(item.status)} · '
                              '${item.oneLiner.isEmpty ? (item.product.isEmpty ? '-' : item.product) : item.oneLiner}',
                            ),
                            trailing: Wrap(
                              spacing: 0,
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
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editIdea(item),
                                ),
                                IconButton(
                                  tooltip: '작업지시 제작소로 보내기',
                                  icon: const Icon(Icons.send_outlined),
                                  onPressed: widget.onSendToWorkInstruction ==
                                          null
                                      ? null
                                      : () {
                                          widget.onSendToWorkInstruction!(
                                            IdeaToPlanningSeed(
                                              title: item.title,
                                              targetCustomer:
                                                  item.targetCustomer,
                                              field: item.product,
                                              description: item.oneLiner,
                                              memo: item.memo,
                                            ),
                                          );
                                        },
                                ),
                              ],
                            ),
                            onTap: () => _editIdea(item),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
