import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ops_health_check.dart';
import '../theme/control_theme.dart';

class OpsHealthPanel extends StatelessWidget {
  const OpsHealthPanel({
    super.key,
    required this.report,
    required this.onRunAll,
  });

  final OpsHealthReport report;
  final VoidCallback onRunAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('ops_health_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          report.overallLabelKo,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          '읽기 전용 점검입니다. 작업을 만들거나 전송하지 않습니다.',
          style: TextStyle(fontSize: 12.5, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final c in report.checks) ...[
          _CheckRow(item: c),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: onRunAll,
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('전체 자동 점검'),
        ),
        if (report.overall != OpsHealthLevel.ok) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report.toGptMemo()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('문제 해결 메모를 복사했습니다.')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('GPT에 알려줄 문제 해결 메모 복사'),
          ),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.item});

  final OpsHealthCheckItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.level) {
      OpsHealthLevel.ok => ControlColors.accentGreen,
      OpsHealthLevel.attention => ControlColors.accentWarm,
      OpsHealthLevel.problem => ControlColors.accentWarm,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                item.levelLabelKo,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.summary,
            style: const TextStyle(
              fontSize: 13,
              color: ControlColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
