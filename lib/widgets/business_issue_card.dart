import 'package:flutter/material.dart';
import '../models/business_issue.dart';
import '../theme/control_theme.dart';

class BusinessIssueCard extends StatelessWidget {
  const BusinessIssueCard({super.key, required this.issue});

  final BusinessIssue issue;

  Color _levelColor(ImpactLevel level) {
    switch (level) {
      case ImpactLevel.high:
        return ControlColors.accentWarm;
      case ImpactLevel.medium:
        return ControlColors.sandBeige;
      case ImpactLevel.low:
        return ControlColors.textMuted;
    }
  }

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        issue.divisionName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ControlColors.teal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _LevelBadge(
                  label: '영향 ${issue.impactLevel.label}',
                  color: _levelColor(issue.impactLevel),
                ),
                const SizedBox(width: 6),
                _LevelBadge(
                  label: '긴급도 ${issue.urgencyLevel.label}',
                  color: issue.urgencyLevel == UrgencyLevel.high
                      ? ControlColors.accentWarm
                      : ControlColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FieldRow(label: '현재 문제', value: issue.problem, highlight: true),
            _FieldRow(label: '문제 원인', value: issue.cause),
            _FieldRow(label: '대응 방안', value: issue.responsePlan),
            _FieldRow(label: '담당 AI', value: issue.assignedAiRole),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ControlColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ControlColors.teal.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_arrow,
                    size: 16,
                    color: ControlColors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '다음 액션',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          issue.nextAction,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
