import 'package:flutter/material.dart';
import '../models/finance_item.dart';
import '../theme/control_theme.dart';

class ExpansionCandidateCard extends StatelessWidget {
  const ExpansionCandidateCard({super.key, required this.candidate});

  final ExpansionCandidate candidate;

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
                  child: Text(
                    candidate.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _Badge(label: '우선 ${candidate.priority}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              candidate.category,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ControlColors.teal,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              candidate.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '예상 수익성: ${candidate.expectedProfitability}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ControlColors.sandBeige,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Text('필요 준비물', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            ...candidate.requiredPreparation.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 6,
                      color: ControlColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ControlColors.accentWarm.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: ControlColors.accentWarm,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
