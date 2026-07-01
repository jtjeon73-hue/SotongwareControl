import 'package:flutter/material.dart';
import '../models/revenue_pipeline.dart';
import '../theme/control_theme.dart';

class RevenuePipelineCard extends StatelessWidget {
  const RevenuePipelineCard({super.key, required this.pipeline});

  final RevenuePipeline pipeline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    Icons.paid_outlined,
                    color: ControlColors.teal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pipeline.businessName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ControlColors.sandBeige.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pipeline.expectedRevenueLevel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10,
                      color: ControlColors.sandBeige,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Row(label: '대상 고객', value: pipeline.targetCustomer),
            _Row(label: '수익 방식', value: pipeline.revenueModel),
            _Row(label: '현재 단계', value: pipeline.currentStage),
            _Row(label: '다음 단계', value: pipeline.nextStep, highlight: true),
            const SizedBox(height: 12),
            Text('필요 작업', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pipeline.requiredTasks.map((task) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ControlColors.slate.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: ControlColors.textMuted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
                color: highlight ? ControlColors.teal : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
