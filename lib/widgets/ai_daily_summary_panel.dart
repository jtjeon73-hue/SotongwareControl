import 'package:flutter/material.dart';
import '../models/ai_report.dart';
import '../theme/control_theme.dart';

class AiDailySummaryPanel extends StatelessWidget {
  const AiDailySummaryPanel({
    super.key,
    required this.summary,
    this.onViewAiRoom,
  });

  final AiDailySummary summary;
  final VoidCallback? onViewAiRoom;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ControlColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: ControlColors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 AI 종합 보고',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '대표 비서 AI · 부서 AI 종합 판단 (샘플)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewAiRoom != null)
                  TextButton.icon(
                    onPressed: onViewAiRoom,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('AI 직원실'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _SummaryColumn(summary: summary)),
                          const SizedBox(width: 24),
                          Expanded(child: _ActionColumn(summary: summary)),
                        ],
                      )
                    : Column(
                        children: [
                          _SummaryColumn(summary: summary),
                          const SizedBox(height: 20),
                          _ActionColumn(summary: summary),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.summary});

  final AiDailySummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '가장 중요한 문제',
        summary.topProblem,
        Icons.warning_amber_outlined,
        ControlColors.accentWarm,
      ),
      (
        '빠른 수익화 작업',
        summary.fastestRevenueTask,
        Icons.trending_up,
        ControlColors.teal,
      ),
      (
        '홍보 필요 프로젝트',
        summary.promotionNeededProject,
        Icons.campaign_outlined,
        ControlColors.sandBeige,
      ),
      (
        '지연 중인 작업',
        summary.delayedTask,
        Icons.schedule_outlined,
        ControlColors.textMuted,
      ),
      (
        '세무/비용 확인',
        summary.financeCheckItem,
        Icons.receipt_long_outlined,
        ControlColors.accentWarm,
      ),
    ];

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SummaryRow(
            label: item.$1,
            value: item.$2,
            icon: item.$3,
            color: item.$4,
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: ControlColors.textMuted,
                ),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({required this.summary});

  final AiDailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.slate.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('다음 3가지 추천 액션', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          ...summary.recommendedActions.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ControlColors.teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ControlColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
