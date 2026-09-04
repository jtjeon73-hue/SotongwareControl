import 'package:flutter/material.dart';

import '../models/commercial/production_review_status_envelope.dart';
import '../services/production_review_status_presentation.dart';
import '../theme/control_theme.dart';

/// Compact production review status card for dashboard / workshop.
class ProductionReviewStatusCard extends StatelessWidget {
  const ProductionReviewStatusCard({
    super.key,
    required this.envelope,
    this.onPrepareR2Draft,
    this.compact = false,
  });

  final ProductionReviewStatusEnvelope envelope;
  final VoidCallback? onPrepareR2Draft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lines = compact
        ? ProductionReviewStatusPresentation.workshopCardLines(envelope)
        : ProductionReviewStatusPresentation.dashboardSummary(envelope);
    final facts = ProductionReviewStatusPresentation.statusFacts(envelope);
    final r2Hints = ProductionReviewStatusPresentation.r2DraftHints(envelope);
    final showR2Button =
        envelope.readiness.revisionRequired && onPrepareR2Draft != null;

    return Container(
      key: const Key('production_review_status_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ControlColors.accentWarm.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: ControlColors.accentWarm,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  envelope.userLabelKo.isNotEmpty
                      ? envelope.userLabelKo
                      : (lines.isNotEmpty ? lines.first : '제작 검토 상태'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (envelope.nextActionKo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              envelope.nextActionKo,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final fact in facts)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ControlColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ControlColors.border.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Text(
                    fact,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ControlColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ReviewSection(
            title: '기술검증',
            value: _techSummary(envelope),
            ok:
                envelope.readiness.technicalValidationCompleted ||
                envelope.technicalValidation.completed,
          ),
          const SizedBox(height: 6),
          _ReviewSection(
            title: '소유자 검토',
            value: _ownerSummary(envelope),
            ok: envelope.ownerReview.decision == 'approved',
            warn: envelope.ownerReview.decision == 'changes_requested',
          ),
          if (!compact && lines.length > 1) ...[
            const SizedBox(height: 8),
            for (final line in lines.skip(1))
              if (!facts.contains(line))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ControlColors.textSecondary,
                    ),
                  ),
                ),
          ],
          if (r2Hints.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final hint in r2Hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '· $hint',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textMuted,
                  ),
                ),
              ),
          ],
          if (showR2Button) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('production_review_r2_prepare'),
              onPressed: onPrepareR2Draft,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('R2 보완 초안 준비'),
            ),
          ],
        ],
      ),
    );
  }

  /// Opens a read-only R2 draft summary sheet. Does not send or create jobs.
  static Future<void> showR2DraftSheet(
    BuildContext context,
    ProductionReviewStatusEnvelope envelope,
  ) {
    final lines = ProductionReviewStatusPresentation.r2DraftDialogLines(
      envelope,
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'R2 보완 초안 (읽기 전용)',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '자동 전송·작업 생성은 수행하지 않습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: ControlColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(line, style: const TextStyle(fontSize: 14)),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _techSummary(ProductionReviewStatusEnvelope e) {
    if (e.readiness.technicalValidationCompleted ||
        e.technicalValidation.completed) {
      return '완료';
    }
    return e.technicalValidation.status.isNotEmpty
        ? e.technicalValidation.status
        : '대기';
  }

  static String _ownerSummary(ProductionReviewStatusEnvelope e) {
    switch (e.ownerReview.decision) {
      case 'approved':
        return '승인';
      case 'changes_requested':
        return '보완요청';
      case 'pending':
        return '대기';
      default:
        return e.ownerReview.decision.isNotEmpty ? e.ownerReview.decision : '—';
    }
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.value,
    this.ok = false,
    this.warn = false,
  });

  final String title;
  final String value;
  final bool ok;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? ControlColors.accentGreen
        : warn
        ? ControlColors.accentWarm
        : ControlColors.textSecondary;
    return Row(
      children: [
        Text(
          '$title: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ControlColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
