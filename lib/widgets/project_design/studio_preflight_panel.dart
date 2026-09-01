import 'package:flutter/material.dart';

import '../../services/work_instruction_studio_preflight.dart';
import '../../theme/control_theme.dart';

/// STEP F — AI 작업자·Agent 사전점검 (실제 telemetry만, 가짜 수치 없음).
class StudioPreflightPanel extends StatelessWidget {
  const StudioPreflightPanel({
    super.key,
    required this.report,
    this.onRefresh,
    this.refreshing = false,
  });

  final StudioPreflightReport report;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: report.canStartProduction
          ? ControlColors.accentGreen.withValues(alpha: 0.08)
          : ControlColors.warningBg,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'AI 작업자 사전점검',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    tooltip: '다시 확인',
                    onPressed: refreshing ? null : onRefresh,
                    icon: refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              report.summaryLine,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: report.canStartProduction
                    ? ControlColors.accentGreen
                    : ControlColors.accentWarm,
              ),
            ),
            const SizedBox(height: 10),
            for (final check in report.checks) _CheckRow(check: check),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final StudioPreflightCheck check;

  @override
  Widget build(BuildContext context) {
    final icon = switch (check.status) {
      StudioPreflightStatus.ok => Icons.check_circle_outline,
      StudioPreflightStatus.warning => Icons.warning_amber_outlined,
      StudioPreflightStatus.blocked => Icons.block,
    };
    final color = switch (check.status) {
      StudioPreflightStatus.ok => ControlColors.accentGreen,
      StudioPreflightStatus.warning => ControlColors.accentWarm,
      StudioPreflightStatus.blocked => ControlColors.accentRose,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  check.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
