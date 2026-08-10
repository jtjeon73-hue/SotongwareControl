import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

class AutoSalesScreen extends StatelessWidget {
  const AutoSalesScreen({super.key});

  static const _common = [
    '상품',
    '고객',
    '판매채널',
    '가격',
    '판매방식',
    '무료/유료',
    '구독',
    '패키지',
    '업셀',
    '크로스셀',
    '할인',
    '프로모션',
    '판매 전환',
    '후속 판매',
  ];

  static const _byArtifact = <String, List<String>>{
    '전자책': ['크몽', '탈잉', '자체 판매'],
    '앱': ['Play Store', '광고', '구독'],
    '사이트': ['광고', '제휴', '구독', '서비스 판매'],
    '컨텐츠': ['YouTube', '음원', '상품 유입'],
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('자동판매전략실',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          '상품 완성 후 판매 전략을 체계적으로 관리합니다. 결제 API 연동은 이번 범위가 아닙니다.',
          style: TextStyle(color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Text('기본 구성',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in _common)
              Chip(
                label: Text(i),
                backgroundColor: ControlColors.surfaceMuted,
                side: const BorderSide(color: ControlColors.border),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('artifact별 판매 채널',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final e in _byArtifact.entries)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: ControlColors.border),
            ),
            child: ListTile(
              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(e.value.join(' · ')),
            ),
          ),
      ],
    );
  }
}
