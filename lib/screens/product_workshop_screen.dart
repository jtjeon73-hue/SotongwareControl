import 'package:flutter/material.dart';

import '../data/product_workshop_catalog.dart';
import '../theme/control_theme.dart';

class ProductWorkshopScreen extends StatefulWidget {
  const ProductWorkshopScreen({super.key});

  @override
  State<ProductWorkshopScreen> createState() => _ProductWorkshopScreenState();
}

class _ProductWorkshopScreenState extends State<ProductWorkshopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: ProductWorkshopCatalog.playbooks.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              Text(
                '제품제작 공작실',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '소통24워크를 통해 제품이 만들어지는 과정을 관리·설명합니다.',
                style: TextStyle(color: ControlColors.textSecondary),
              ),
              const SizedBox(height: 14),
              _statusCard(),
              const SizedBox(height: 14),
              Text(
                '상품 Lifecycle',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < ProductLifecycle.stages.length; i++) ...[
                    Chip(
                      label: Text(
                        '${i + 1}. ${ProductLifecycle.stages[i]}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: ControlColors.surfaceMuted,
                      side: const BorderSide(color: ControlColors.border),
                    ),
                    if (i < ProductLifecycle.stages.length - 1)
                      const Icon(Icons.arrow_forward, size: 14,
                          color: ControlColors.textMuted),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '사업부별 제작단계',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  for (final p in ProductWorkshopCatalog.playbooks)
                    Tab(text: p.title),
                ],
              ),
              SizedBox(
                height: 420,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    for (final p in ProductWorkshopCatalog.playbooks)
                      _PlaybookView(playbook: p),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ControlColors.border),
        borderRadius: BorderRadius.circular(8),
        color: ControlColors.surfaceMuted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('소통24워크 현재 개발 상태',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('자동화 수준: ${Sotong24WorkStatusCatalog.automationLevel}'),
          Text('버전/상태: ${Sotong24WorkStatusCatalog.versionNote}',
              style: const TextStyle(
                  fontSize: 12, color: ControlColors.textMuted)),
          const SizedBox(height: 8),
          _bullet('지원 artifact', Sotong24WorkStatusCatalog.supportedArtifacts),
          _bullet('구현 완료', Sotong24WorkStatusCatalog.completed),
          _bullet('부분 구현', Sotong24WorkStatusCatalog.partial),
          _bullet('향후 보완', Sotong24WorkStatusCatalog.upcoming),
        ],
      ),
    );
  }

  Widget _bullet(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$title: ${items.join(' · ')}',
          style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PlaybookView extends StatelessWidget {
  const _PlaybookView({required this.playbook});
  final ArtifactProductionPlaybook playbook;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        if (playbook.notes.isNotEmpty)
          Text(playbook.notes,
              style: const TextStyle(
                  fontSize: 12, color: ControlColors.textMuted)),
        for (final s in playbook.steps)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: ControlColors.border),
            ),
            child: ExpansionTile(
              title: Text('${s.number}. ${s.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('자동화: ${s.automationLevel}',
                  style: const TextStyle(fontSize: 12)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                _kv('목적', s.purpose),
                _kv('입력', s.inputs),
                _kv('AI 작업', s.aiWork),
                _kv('산출물', s.outputs),
                _kv('검수', s.review),
                _kv('사용자 승인', s.approval),
                _kv('다음 단계', s.nextStep),
              ],
            ),
          ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: '$k: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: v),
              ],
            ),
          ),
        ),
      );
}
