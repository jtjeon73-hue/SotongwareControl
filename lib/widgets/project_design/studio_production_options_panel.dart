import 'package:flutter/material.dart';

import '../../theme/control_theme.dart';

/// STEP D — 제작 옵션 (승인·실행·AI 작업자).
class StudioProductionOptionsPanel extends StatelessWidget {
  const StudioProductionOptionsPanel({
    super.key,
    required this.approvalMode,
    required this.workerPreference,
    required this.onApprovalModeChanged,
    required this.onWorkerPreferenceChanged,
    this.showApprovalMode = true,
  });

  final String approvalMode;
  final String workerPreference;
  final ValueChanged<String> onApprovalModeChanged;
  final ValueChanged<String> onWorkerPreferenceChanged;
  final bool showApprovalMode;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ControlColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '제작 옵션',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (showApprovalMode) ...[
              const SizedBox(height: 12),
              const Text(
                '승인 방식',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                key: const Key('studio_approval_mode'),
                segments: const [
                  ButtonSegment(value: 'manual', label: Text('수동 승인')),
                  ButtonSegment(value: 'auto', label: Text('자동 승인')),
                ],
                selected: {approvalMode},
                onSelectionChanged: (v) => onApprovalModeChanged(v.first),
              ),
              const SizedBox(height: 4),
              Text(
                approvalMode == 'auto'
                    ? 'validator PASS 시 다음 단계 자동 진행 (continuous)'
                    : '각 주요 단계에서 사용자 확인 (hold)',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ControlColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text('AI 작업자', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              key: const Key('studio_worker_preference'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: ControlColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cursor (고정)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '제작공정 AI 작업자는 Cursor로 고정됩니다. Codex 배정·fallback은 사용하지 않습니다.',
              style: TextStyle(fontSize: 11.5, color: ControlColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
