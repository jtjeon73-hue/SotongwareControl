import 'package:flutter/material.dart';

import '../data/sotong24_workflows.dart';
import '../models/instruction_contract.dart';
import '../models/remote_e2e_sample.dart';
import '../models/sotong24_remote_models.dart';
import '../services/sotong24_workshop_presentation.dart';
import '../theme/control_theme.dart';
import 'result_link_button.dart';

/// 단계 자체 resultUrl/previewUrl 열기 — currentStage에 의존하지 않음.
class Sotong24StageResultOpenButtons extends StatelessWidget {
  const Sotong24StageResultOpenButtons({
    super.key,
    required this.stage,
    this.compact = false,
  });

  final Sotong24RemoteStage stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final result = stage.openableResultUrl;
    final preview = stage.openablePreviewUrl;
    if (result == null && preview == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          const Text(
            '결과물',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: ControlColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (result != null)
          ResultLinkButton(
            url: result,
            label: '결과물 보기',
            icon: Icons.description_outlined,
            style: ResultLinkStyle.tonal,
          ),
        if (result != null && preview != null) const SizedBox(height: 8),
        if (preview != null)
          ResultLinkButton(
            url: preview,
            label: '미리보기',
            icon: Icons.open_in_new,
            style: ResultLinkStyle.outlined,
          ),
      ],
    );
  }
}

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
      final st = Sotong24UserFacingStatus.normalize(s.status);
      // 배타적 분류 — pending approval은 awaiting으로만 센다(중복 금지).
      if (st == Sotong24WorkStatus.error) {
        error++;
      } else if (st == Sotong24WorkStatus.revision ||
          s.approvalStatus == ApprovalStatus.revisionRequested) {
        revision++;
      } else if (st == Sotong24WorkStatus.awaitingApproval ||
          s.approvalStatus == ApprovalStatus.pending) {
        awaiting++;
      } else if (st == Sotong24WorkStatus.inProgress) {
        inProgress++;
      } else if (st == Sotong24WorkStatus.completed) {
        completed++;
      }
      // not_applicable: 완료/진행 집계에서 제외.
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
  switch (Sotong24UserFacingStatus.normalize(status)) {
    case Sotong24WorkStatus.completed:
      return '✓';
    case Sotong24WorkStatus.notApplicable:
      return '—';
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
    final completed = project.userFacingStatus == Sotong24WorkStatus.completed;
    final headline = project.nowTodoHeadline(stage: stage);
    final checks = def?.userChecks ?? const <String>['결과 확인'];
    final awaiting =
        project.userFacingStatus == Sotong24WorkStatus.awaitingApproval;
    final showChecks = !completed && awaiting && checks.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? ControlColors.tealSoft : ControlColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? ControlColors.teal : ControlColors.accentWarm,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed ? '작업 완료' : '지금 할 일',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (completed &&
              (RemoteE2eSampleMarkers.isTestInstructionId(project.projectId) ||
                  RemoteE2eSampleMarkers.isTestTitle(project.title))) ...[
            const SizedBox(height: 4),
            const Text(
              'TEST E2E 완료',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ControlColors.teal,
              ),
            ),
          ],
          if (!completed &&
              awaiting &&
              (def?.aiWork ?? stage.workReport).isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('AI 작업', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              def?.aiWork.isNotEmpty == true ? def!.aiWork : stage.workReport,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ],
          if (showChecks) ...[
            const SizedBox(height: 8),
            const Text(
              '내가 확인할 것',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            for (final c in checks)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '□ $c',
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
          ],
          if (!completed && stage.userAttention.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              stage.userAttention,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
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
    final done = Sotong24WorkStatus.countsAsCompleted(s.status);
    final notApplicable = Sotong24WorkStatus.isNotApplicable(s.status);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            color: (done || notApplicable) && !widget.isCurrent
                                ? ControlColors.textMuted
                                : ControlColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        Sotong24WorkStatus.labelKo(
                          Sotong24UserFacingStatus.normalize(s.status),
                        ),
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
                  if (Sotong24WorkshopPresentation.stageDurationLine(
                        s,
                      ).isNotEmpty ||
                      Sotong24WorkshopPresentation.stageRevisionLine(
                        s,
                      ).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 36),
                      child: Text(
                        [
                          Sotong24WorkshopPresentation.stageDurationLine(s),
                          Sotong24WorkshopPresentation.stageRevisionLine(s),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ControlColors.textSecondary,
                        ),
                      ),
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
                  if (s.hasOpenableResult) ...[
                    const SizedBox(height: 4),
                    Sotong24StageResultOpenButtons(stage: s),
                    const SizedBox(height: 8),
                  ],
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
                  _line(
                    '작업시간',
                    Sotong24WorkshopPresentation.stageTimingDetailNote(s),
                  ),
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
