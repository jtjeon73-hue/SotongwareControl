import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

/// 자동 홍보 전략실 — 로컬 템플릿 (광고 API 미연동).
class AutoPromotionScreen extends StatelessWidget {
  const AutoPromotionScreen({super.key});

  static const _artifacts = [
    '전자책',
    '앱',
    '지식사이트',
    '마케팅사이트',
    '컨텐츠',
    '산업자동화 제품/서비스',
  ];

  static const _channels = [
    'SNS',
    'YouTube',
    'Blog',
    'SEO',
    '광고',
  ];

  static const _remedies = [
    ('유입 부족', '제목 변경'),
    ('조회 부족', '썸네일 변경'),
    ('구매전환 부족', '가격/설명/CTA 개선'),
    ('검색노출 부족', 'SEO 개선'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('자동 홍보 전략실',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          '상품 완성 후 자동·반자동 홍보 전략을 설계·관리합니다. 실제 광고 API 집행은 하지 않습니다.',
          style: TextStyle(color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _block('대상 상품', _artifacts),
        _block('홍보 채널', _channels),
        const SizedBox(height: 8),
        _section(context, '기본 구성', [
          '상품',
          '대상 고객',
          '홍보 메시지',
          '콘텐츠 전략',
          '일정',
          '성과',
          '개선대책',
        ]),
        const SizedBox(height: 12),
        Text('홍보 보완대책',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final r in _remedies)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: ControlColors.border),
            ),
            child: ListTile(
              title: Text(r.$1),
              trailing: const Icon(Icons.arrow_forward, size: 16),
              subtitle: Text('→ ${r.$2}'),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          '향후: 상품 생성 시 홍보 프로젝트 자동 생성 가능하도록 모델만 준비합니다.',
          style: TextStyle(fontSize: 12, color: ControlColors.textMuted),
        ),
      ],
    );
  }

  Widget _block(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final i in items)
                Chip(
                  label: Text(i),
                  backgroundColor: ControlColors.surfaceMuted,
                  side: const BorderSide(color: ControlColors.border),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final i in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline, size: 18),
            title: Text(i),
          ),
      ],
    );
  }
}
