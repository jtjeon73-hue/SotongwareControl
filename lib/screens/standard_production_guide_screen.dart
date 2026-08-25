import 'package:flutter/material.dart';

import '../data/sotong24_production_guides.dart';
import '../models/artifact_type.dart';
import '../theme/control_theme.dart';
import '../widgets/page_hero.dart';
import '../widgets/sotong24_production_guide_panel.dart';

/// 표준제작 가이드 — 참고자료 전용 (실제 제작 상태와 분리).
class StandardProductionGuideScreen extends StatefulWidget {
  const StandardProductionGuideScreen({
    super.key,
    this.initialProductId,
    this.focusStageId,
  });

  final String? initialProductId;
  final String? focusStageId;

  @override
  State<StandardProductionGuideScreen> createState() =>
      _StandardProductionGuideScreenState();
}

class _StandardProductionGuideScreenState
    extends State<StandardProductionGuideScreen> {
  String? _selectedProductId;
  String _contentSubtype = ContentSubtype.song;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId;
  }

  static const _homeCards = <_GuideHomeCard>[
    _GuideHomeCard(
      'ebook',
      '전자책 제작',
      Icons.auto_stories_outlined,
      '아이디어·기획·초안·품질·판매·운영',
    ),
    _GuideHomeCard(
      'app',
      '앱 제작',
      Icons.phone_android_outlined,
      '문제정의·설계·AI 코딩·테스트·APK·출시 전 검토',
    ),
    _GuideHomeCard(
      'contents',
      '콘텐츠 제작',
      Icons.play_circle_outline,
      '노래·1시간형·쇼츠·이미지 광고',
    ),
    _GuideHomeCard(
      'site',
      '지식사이트 제작',
      Icons.hub_outlined,
      '주제·정보구조·콘텐츠·SEO·배포',
    ),
    _GuideHomeCard(
      'promo_site',
      '마케팅사이트 제작',
      Icons.campaign_outlined,
      'USP·랜딩·카피·CTA·Analytics',
    ),
    _GuideHomeCard(
      'industrial',
      '산업자동화SW',
      Icons.precision_manufacturing_outlined,
      '요구·설계·PLC·테스트·납품',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_selectedProductId == null) {
      return _buildHome(context);
    }
    return _buildDetail(context, _selectedProductId!);
  }

  Widget _buildHome(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900 ? 3 : (width >= 600 ? 2 : 1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const PageHero(
          title: '표준제작 가이드',
          subtitle:
              'AI를 활용해 좋은 결과물을 만드는 표준 참고자료입니다. '
              '실제 제작 진행은 AI 제작공정에서 확인하세요.',
        ),
        const SizedBox(height: 8),
        const Text(
          '제작 분야를 선택하면 단계별 목적·준비물·AI 활용·검수 기준을 볼 수 있습니다.',
          style: TextStyle(color: ControlColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: width < 600 ? 2.4 : 1.55,
          children: [
            for (final card in _homeCards)
              _GuideCategoryCard(
                card: card,
                onTap: () =>
                    setState(() => _selectedProductId = card.productId),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetail(BuildContext context, String productId) {
    final label = Sotong24ProductionGuideCatalog.labelKo(productId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _selectedProductId = null),
              icon: const Icon(Icons.arrow_back),
              tooltip: '가이드 홈',
            ),
            Expanded(
              child: Text(
                '$label 제작 가이드',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (productId == 'contents') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in ContentSubtype.allSelectable)
                ChoiceChip(
                  label: Text(ContentSubtype.labelKo(s)),
                  selected: _contentSubtype == s,
                  onSelected: (_) => setState(() => _contentSubtype = s),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Sotong24ProductionGuidePanel(
          initialProductId: productId,
          initialContentSubtype: productId == 'contents' ? _contentSubtype : '',
          embedded: true,
          focusStageId: widget.focusStageId,
        ),
      ],
    );
  }
}

class _GuideHomeCard {
  const _GuideHomeCard(this.productId, this.title, this.icon, this.subtitle);
  final String productId;
  final String title;
  final IconData icon;
  final String subtitle;
}

class _GuideCategoryCard extends StatelessWidget {
  const _GuideCategoryCard({required this.card, required this.onTap});

  final _GuideHomeCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ControlColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ControlColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(card.icon, size: 32, color: ControlColors.teal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ControlColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ControlColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
