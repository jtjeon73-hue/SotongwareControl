import 'package:flutter/material.dart';

import '../theme/control_theme.dart';
import '../widgets/sidebar_navigation.dart';

/// 알람센터 — mock 자동 생성 금지. 실이벤트 없으면 빈 상태.
class AlertCenterScreen extends StatelessWidget {
  const AlertCenterScreen({super.key, required this.onNavigate});

  final ValueChanged<ControlDestination> onNavigate;

  static const categories = [
    '긴급',
    '승인 필요',
    '작업 완료',
    '오류',
    '판매/수익',
    '업데이트 필요',
    '홍보 필요',
    '시스템 점검',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          '알람센터',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '각 사업부를 일일이 확인하지 않고 중요한 사항만 모읍니다.',
          style: TextStyle(color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in categories)
              Chip(
                label: Text(c),
                backgroundColor: ControlColors.surfaceMuted,
                side: const BorderSide(color: ControlColors.border),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 40,
                  color: ControlColors.textMuted,
                ),
                SizedBox(height: 12),
                Text(
                  '표시할 알림이 없습니다.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  '모듈 이벤트가 연결되면 여기에 표시됩니다.\n가짜 알림을 자동 생성하지 않습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ControlColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('문제/지연/체크사항'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onNavigate(ControlDestination.issuesCheck),
        ),
        ListTile(
          title: const Text('다음 실행 우선순위'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onNavigate(ControlDestination.nextPriority),
        ),
        ListTile(
          title: const Text('전체 사업 현황'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onNavigate(ControlDestination.dashboardOverview),
        ),
      ],
    );
  }
}
