import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import 'ops_ui.dart';

class DeploymentChecklistCard extends StatelessWidget {
  const DeploymentChecklistCard({super.key, required this.deployment});

  final DeploymentDoc deployment;

  @override
  Widget build(BuildContext context) {
    final d = deployment;
    final steps = <(String, String)>[
      ('clean', d.flutterClean),
      ('pub get', d.flutterPubGet),
      ('analyze', d.flutterAnalyze),
      ('test', d.flutterTest),
      ('build web', d.flutterBuildWeb),
      ('commit', d.gitCommit),
      ('push', d.gitPush),
      ('firebase', d.firebaseDeploy),
      ('사이트 확인', d.siteVerified),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.projectId,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                StatusBadge(
                  label: d.statusLabel,
                  color: d.isFullyComplete
                      ? ControlColors.accentGreen
                      : ControlColors.accentWarm,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: steps
                  .map(
                    (e) => _StepChip(label: e.$1, status: e.$2),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '배포일: ${d.deployedAt == null ? '미등록' : DateFormat('yyyy-MM-dd HH:mm').format(d.deployedAt!)}',
            ),
            if (d.commitHash.isNotEmpty) Text('커밋: ${d.commitHash}'),
            if (d.commitMessage.isNotEmpty)
              Text(
                '메시지: ${d.commitMessage}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (d.siteUrl.isNotEmpty)
              TextButton(
                onPressed: () => ExternalUrl.open(d.siteUrl),
                child: Text(d.siteUrl, overflow: TextOverflow.ellipsis),
              ),
            if (d.verificationNote.isNotEmpty)
              Text('확인 메모: ${d.verificationNote}'),
          ],
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ok = status == DeployStepStatus.success;
    final fail = status == DeployStepStatus.failed;
    final mark = ok
        ? '✓'
        : fail
        ? '✗'
        : status == DeployStepStatus.notRequired
        ? '–'
        : '·';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
        color: ControlColors.surface,
      ),
      child: Text(
        '$mark $label (${DeployStepStatus.labelKo(status)})',
        style: TextStyle(
          fontSize: 12,
          color: ok
              ? ControlColors.accentGreen
              : fail
              ? ControlColors.accentWarm
              : ControlColors.textSecondary,
        ),
      ),
    );
  }
}
