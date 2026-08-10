import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

/// 수익·세금 관리 기반 UI. 자동 신고/거짓 계산 없음.
class AutoFinanceScreen extends StatelessWidget {
  const AutoFinanceScreen({super.key});

  static const _segments = [
    '전자책',
    '앱',
    '사이트',
    '콘텐츠',
    '산업자동화',
    '기타',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('수익세금 자동 재무실',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          '분야별 수익·비용·세금 준비 상태를 한곳에서 관리합니다. '
          '실제 세무 신고·자동 계산은 공식 세법 데이터와 전문가 검증 후 연결합니다.',
          style: TextStyle(color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Text('전체 수익 요약',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final s in _segments)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: ControlColors.border),
            ),
            child: ListTile(
              title: Text(s),
              subtitle: const Text('매출/비용/순이익: 실데이터 연동 전 — 표시하지 않음'),
              trailing: const Text('준비',
                  style: TextStyle(color: ControlColors.textMuted)),
            ),
          ),
        const SizedBox(height: 12),
        Text('수익 정보 항목',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _chips([
          '매출',
          '비용',
          '플랫폼 수수료',
          '광고비',
          '순이익',
          '예상 세금(참고)',
        ]),
        const SizedBox(height: 12),
        Text('세금 관리 (참고)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _chips([
          '과세 자료',
          '부가세',
          '종합소득세/법인 관련 참고',
          '신고 준비',
          '영수증/증빙 상태',
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ControlColors.warningBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ControlColors.border),
          ),
          child: const Text(
            '주의: 이 화면은 관리 기반입니다. 자동 세무 신고 기능을 제공하지 않으며, '
            '금액이 없으면 가짜 수치를 표시하지 않습니다.',
          ),
        ),
      ],
    );
  }

  Widget _chips(List<String> items) {
    return Wrap(
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
    );
  }
}
