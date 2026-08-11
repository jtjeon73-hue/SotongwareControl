import 'package:flutter/material.dart';

import '../data/sotong24_workflows.dart';
import '../models/sotong24_remote_models.dart';
import '../theme/control_theme.dart';

class Sotong24StageStats {
  const Sotong24StageStats({
    required this.completed,
    required this.inProgress,
    required this.awaiting,
    required this.revision,
    required this.error,
  });

  final int completed;
  final int inProgress;
  final int awaiting;
  final int revision;
  final int error;

  factory Sotong24StageStats.fromProject(Sotong24RemoteProject project) {
    var completed = 0;
    var inProgress = 0;
    var awaiting = 0;
    var revision = 0;
    var error = 0;
    for (final s in project.stages) {
      switch (s.status) {
        case Sotong24WorkStatus.completed:
          completed++;
        case Sotong24WorkStatus.inProgress:
          inProgress++;
        case Sotong24WorkStatus.awaitingApproval:
          awaiting++;
        case Sotong24WorkStatus.revision:
          revision++;
        case Sotong24WorkStatus.error:
          error++;
        default:
          break;
      }
    }
    return Sotong24StageStats(
      completed: completed,
      inProgress: inProgress,
      awaiting: awaiting,
      revision: revision,
      error: error,
    );
  }
}

String sotong24StatusGlyph(String status) {
  switch (status) {
    case Sotong24WorkStatus.completed:
      return '✓';
    case Sotong24WorkStatus.inProgress:
      return '●';
    case Sotong24WorkStatus.awaitingApproval:
      return '⏳';
    case Sotong24WorkStatus.revision:
      return '↻';
    case Sotong24WorkStatus.error:
      return '!';
    default:
      return '○';
  }
}

class Sotong24StatsRow extends StatelessWidget {
  const Sotong24StatsRow({super.key, required this.stats});

  final Sotong24StageStats stats;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int n, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$label $n',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip('완료', stats.completed, ControlColors.accentGreen),
        chip('진행', stats.inProgress, ControlColors.teal),
        chip('승인대기', stats.awaiting, ControlColors.accentWarm),
        chip('보완', stats.revision, ControlColors.sandBeige),
        chip('오류', stats.error, ControlColors.accentRose),
      ],
    );
  }
}

class Sotong24NowTodoPanel extends StatelessWidget {
  const Sotong24NowTodoPanel({
    super.key,
    required this.project,
    required this.stage,
    required this.def,
  });

  final Sotong24RemoteProject project;
  final Sotong24RemoteStage stage;
  final Sotong24WorkflowStageDef? def;

  @override
  Widget build(BuildContext context) {
    final checks = def?.userChecks ?? const <String>['결과 확인'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ControlColors.accentWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '지금 할 일',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${stage.stageNumber}단계 「${stage.stageName}」 결과를 확인해 주세요.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((def?.aiWork ?? stage.workReport).isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('AI 작업', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              def?.aiWork.isNotEmpty == true ? def!.aiWork : stage.workReport,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          const Text('내가 확인할 것', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '□ $c',
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          if (stage.userAttention.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              stage.userAttention,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: ControlColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class Sotong24ExpandableStageTile extends StatefulWidget {
  const Sotong24ExpandableStageTile({
    super.key,
    required this.stage,
    required this.isCurrent,
    required this.def,
  });

  final Sotong24RemoteStage stage;
  final bool isCurrent;
  final Sotong24WorkflowStageDef? def;

  @override
  State<Sotong24ExpandableStageTile> createState() =>
      _Sotong24ExpandableStageTileState();
}

class _Sotong24ExpandableStageTileState
    extends State<Sotong24ExpandableStageTile> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.isCurrent;
  }

  @override
  void didUpdateWidget(covariant Sotong24ExpandableStageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _open = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stage;
    final def = widget.def;
    final done = s.status == Sotong24WorkStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isCurrent
            ? ControlColors.tealSoft
            : ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isCurrent ? ControlColors.teal : ControlColors.border,
          width: widget.isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Text(
                    sotong24StatusGlyph(s.status),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: widget.isCurrent
                          ? ControlColors.teal
                          : ControlColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${s.stageNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.stageName,
                      style: TextStyle(
                        fontWeight: widget.isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 15,
                        color: done && !widget.isCurrent
                            ? ControlColors.textMuted
                            : ControlColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    Sotong24WorkStatus.labelKo(s.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isCurrent
                          ? ControlColors.teal
                          : ControlColors.textSecondary,
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: ControlColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _line('목적', def?.purpose ?? s.summary),
                  _line('이 단계에서 하는 일', def?.workDescription ?? ''),
                  _line('AI 작업', def?.aiWork ?? s.workReport),
                  _line('생성 결과물', def?.outputs ?? s.resultPreview),
                  if (def != null && def.qualityChecks.isNotEmpty)
                    _line(
                      '품질검사',
                      def.qualityChecks.map((e) => '· $e').join('\n'),
                    ),
                  if (def != null && def.userChecks.isNotEmpty)
                    _line(
                      '사용자 확인',
                      def.userChecks.map((e) => '□ $e').join('\n'),
                    ),
                  _line(
                    '승인 필요',
                    (def?.approvalTypicallyRequired == true ||
                            s.approvalRequired)
                        ? '예'
                        : '아니오',
                  ),
                  if (s.errorMessage.isNotEmpty)
                    _line('오류', s.errorMessage, danger: true),
                  _line('다음 단계', def?.nextHint ?? ''),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool danger = false}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: danger
                  ? ControlColors.accentRose
                  : ControlColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
