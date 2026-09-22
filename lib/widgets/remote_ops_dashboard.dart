import 'package:flutter/material.dart';

import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import '../services/ops_health_check.dart';
import '../services/sotong24_workshop_presentation.dart';
import '../services/workshop_current_work_selection.dart';
import '../theme/control_theme.dart';

/// 노트북 원격관제 — 시스템/Agent/Job 상태 확인 전용 계기판.
class RemoteOpsDashboard extends StatelessWidget {
  const RemoteOpsDashboard({
    super.key,
    required this.agents,
    required this.onRefresh,
    this.workshops = const [],
    this.jobs = const [],
    this.refreshing = false,
    this.onOpenDiagnostics,
    this.now,
  });

  final List<RemoteAgentDoc> agents;
  final List<Sotong24RemoteProject> workshops;
  final List<RemoteJobDoc> jobs;
  final VoidCallback onRefresh;
  final bool refreshing;

  /// 하위 호환용. 진단 시트는 대시보드가 직접 표시한다.
  final VoidCallback? onOpenDiagnostics;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now().toUtc();
    final onlineAgents = agents.where((a) => a.isOnline(now: clock)).toList();
    final primaryAgent = onlineAgents.isNotEmpty
        ? onlineAgents.first
        : (agents.isNotEmpty ? agents.first : null);

    final dash = WorkshopCurrentWorkSelection.build(
      projects: workshops,
      jobs: jobs,
      agents: agents,
      now: clock,
    );
    final current = dash.current;
    final health = OpsHealthCheck.evaluate(
      agents: agents,
      jobs: jobs,
      workshops: workshops,
      now: clock,
    );

    final online = primaryAgent?.isOnline(now: clock) == true;
    final agentRunning = _isAgentExecuting(primaryAgent, clock);
    final workerRunning = _isWorkerRunning(primaryAgent, clock);
    final lastHb = primaryAgent?.lastHeartbeatAt;
    final version = _versionLabel(primaryAgent);
    final systemTone = systemToneFor(
      online: online,
      health: health,
      job: current?.job,
      agent: primaryAgent,
    );
    final anomalyLabel = _anomalyLabel(
      tone: systemTone,
      health: health,
      online: online,
      stalled: current?.job?.status == 'stalled',
      failed: current?.job?.status == 'failed',
      agent: primaryAgent,
    );

    return Container(
      key: const Key('remote_ops_dashboard'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '소통24워크 상태 확인',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _SummaryCard(
            title: '소통24워크 상태',
            accent: online ? ControlColors.teal : ControlColors.accentRose,
            children: [
              _kv(
                '연결',
                online ? '온라인' : (primaryAgent == null ? '연결 없음' : '오프라인'),
              ),
              _kv(
                'Agent',
                primaryAgent == null ? '미연결' : (online ? '연결됨' : '응답 없음'),
              ),
              _kv(
                '마지막 heartbeat',
                lastHb == null ? '—' : _relativeKo(lastHb.toLocal()),
              ),
              _kv('버전', version),
              _kv('이상', anomalyLabel),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: '현재 작업',
            accent: ControlColors.teal,
            children: current == null
                ? [
                    const Text(
                      '현재 실행 중인 작업이 없습니다.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ControlColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      online
                          ? (agentRunning ? 'Agent 대기/전환 중' : '작업지시 대기')
                          : 'Agent 연결 후 작업이 표시됩니다.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ControlColors.textMuted,
                      ),
                    ),
                    if (dash.needsAttention.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        '사용자 검토 대기',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Sotong24WorkshopPresentation.displayTitle(
                          dash.needsAttention.first,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dash.needsAttention.first.productTypeLabel} · ${dash.needsAttention.first.userFacingStatusLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ControlColors.textSecondary,
                        ),
                      ),
                      if (dash.needsAttention.length > 1)
                        Text(
                          '외 ${dash.needsAttention.length - 1}건은 AI 제작공정 「내 확인이 필요한 작업」에서 확인',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ControlColors.textMuted,
                          ),
                        ),
                    ],
                  ]
                : [
                    Text(
                      current.productTypeLabel,
                      style: const TextStyle(
                        color: ControlColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      current.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _kv('현재 단계', current.stageLine),
                    _kv('진행 상태', current.statusLabel),
                    _kv('worker', workerRunning ? '실행 중' : '미실행'),
                    _kv(
                      '마지막 활동',
                      current.lastUpdatedLine.trim().isEmpty
                          ? '—'
                          : _formatActivity(current.lastUpdatedLine),
                    ),
                    if (current.syncing) ...[
                      const SizedBox(height: 6),
                      const Text(
                        '제작공정 동기화 중 — 상세는 곧 반영됩니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ControlColors.textSecondary,
                        ),
                      ),
                    ],
                    if (dash.needsAttention.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '별도 사용자 검토 대기 ${dash.needsAttention.length}건 (현재 실행과 분리)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ControlColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
          ),
          const SizedBox(height: 12),
          _SystemStatusCard(
            tone: systemTone,
            health: health,
            stalled: current?.job?.status == 'stalled',
            failed: current?.job?.status == 'failed',
            onOpenDiagnostics: () {
              showRemoteStatusDiagnosticsSheet(
                context,
                agent: primaryAgent,
                current: current,
                workerRunning: workerRunning,
                online: online,
                tone: systemTone,
                now: clock,
              );
              onOpenDiagnostics?.call();
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: const Text('상태 재확인'),
          ),
        ],
      ),
    );
  }

  /// 현재 상태만으로 시스템 톤을 판정한다. stale lastError는 오류로 보지 않는다.
  @visibleForTesting
  static RemoteOpsSystemTone systemToneFor({
    required bool online,
    required OpsHealthReport health,
    required RemoteJobDoc? job,
    required RemoteAgentDoc? agent,
  }) {
    if (!online || agent == null) return RemoteOpsSystemTone.error;
    if (agent.state == 'error') return RemoteOpsSystemTone.error;
    final jobStatus = job?.status.trim() ?? '';
    if (jobStatus == 'stalled' || jobStatus == 'failed') {
      return RemoteOpsSystemTone.error;
    }
    if (health.overall == OpsHealthLevel.problem) {
      return RemoteOpsSystemTone.error;
    }
    if (health.overall == OpsHealthLevel.attention) {
      return RemoteOpsSystemTone.warn;
    }
    return RemoteOpsSystemTone.ok;
  }

  static String _anomalyLabel({
    required RemoteOpsSystemTone tone,
    required OpsHealthReport health,
    required bool online,
    required bool stalled,
    required bool failed,
    required RemoteAgentDoc? agent,
  }) {
    switch (tone) {
      case RemoteOpsSystemTone.ok:
        return '없음';
      case RemoteOpsSystemTone.warn:
        return health.suggestedCheck?.summary ?? '확인 필요';
      case RemoteOpsSystemTone.error:
        if (!online) {
          return health.suggestedCheck?.summary ?? '연결 오류';
        }
        if (agent?.state == 'error') return 'Agent 오류 상태';
        if (stalled) return '작업 stalled';
        if (failed) return '작업 실패';
        return health.suggestedCheck?.summary ?? '오류';
    }
  }

  static bool _isAgentExecuting(RemoteAgentDoc? agent, DateTime now) {
    if (agent == null || !agent.enabled) return false;
    switch (agent.state) {
      case 'idle':
      case 'offline':
      case 'error':
        return false;
      default:
        return agent.isOnline(now: now);
    }
  }

  static bool _isWorkerRunning(RemoteAgentDoc? agent, DateTime now) {
    if (agent == null || !agent.isOnline(now: now)) return false;
    switch (agent.state) {
      case 'running':
      case 'running_ai':
      case 'receiving_job':
      case 'generating_result':
      case 'validating_result':
      case 'validation_retry_waiting':
      case 'transitioning_stage':
      case 'reworking':
        return true;
      default:
        return false;
    }
  }

  static String _versionLabel(RemoteAgentDoc? agent) {
    if (agent == null) return '—';
    final v = agent.appVersion.trim();
    if (v.isEmpty) return '—';
    return v;
  }

  static Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeKo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}초 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    return '${diff.inHours}시간 전';
  }

  static String _formatActivity(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    final dt = DateTime.tryParse(t);
    if (dt == null) return t;
    return _relativeKo(dt.toLocal());
  }
}

enum RemoteOpsSystemTone { ok, warn, error }

/// 상태확인용 진단 시트 — 개발 도구 전체 대신 요약만 표시.
Future<void> showRemoteStatusDiagnosticsSheet(
  BuildContext context, {
  required RemoteAgentDoc? agent,
  required WorkshopCurrentWorkItem? current,
  required bool workerRunning,
  required bool online,
  required RemoteOpsSystemTone tone,
  DateTime? now,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return _RemoteStatusDiagnosticsSheet(
        agent: agent,
        current: current,
        workerRunning: workerRunning,
        online: online,
        tone: tone,
        now: now ?? DateTime.now().toUtc(),
      );
    },
  );
}

class _RemoteStatusDiagnosticsSheet extends StatelessWidget {
  const _RemoteStatusDiagnosticsSheet({
    required this.agent,
    required this.current,
    required this.workerRunning,
    required this.online,
    required this.tone,
    required this.now,
  });

  final RemoteAgentDoc? agent;
  final WorkshopCurrentWorkItem? current;
  final bool workerRunning;
  final bool online;
  final RemoteOpsSystemTone tone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final job = current?.job;
    final lastError = agent?.lastError.trim() ?? '';
    final activeError = agent?.state == 'error'
        ? (lastError.isEmpty ? 'Agent가 오류 상태입니다.' : lastError)
        : (job?.status == 'stalled'
              ? '현재 작업이 stalled 상태입니다.'
              : (job?.status == 'failed' ? '현재 작업이 실패했습니다.' : ''));
    final toneLabel = switch (tone) {
      RemoteOpsSystemTone.ok => '정상',
      RemoteOpsSystemTone.warn => '주의',
      RemoteOpsSystemTone.error => '오류',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(
          key: const Key('remote_status_diagnostics_sheet'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '진단정보',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '시스템 상태 · $toneLabel',
                style: TextStyle(
                  color: switch (tone) {
                    RemoteOpsSystemTone.ok => ControlColors.teal,
                    RemoteOpsSystemTone.warn => Colors.orange.shade800,
                    RemoteOpsSystemTone.error => ControlColors.accentRose,
                  },
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _diagKv(
                'Agent 상태',
                agent == null
                    ? '미연결'
                    : (online ? agent!.stateLabelKo : '오프라인 · ${agent!.stateLabelKo}'),
              ),
              _diagKv(
                'heartbeat',
                agent?.lastHeartbeatAt == null
                    ? '—'
                    : RemoteOpsDashboard._relativeKo(
                        agent!.lastHeartbeatAt!.toLocal(),
                      ),
              ),
              _diagKv(
                '현재 작업',
                current == null ? '없음' : current!.title,
              ),
              _diagKv(
                '현재 단계',
                current == null ? '—' : current!.stageLine,
              ),
              _diagKv('worker', workerRunning ? '실행 중' : '미실행'),
              if (activeError.isNotEmpty) ...[
                const SizedBox(height: 8),
                _diagKv('현재 오류', activeError),
              ],
              if (lastError.isNotEmpty && agent?.state != 'error') ...[
                const SizedBox(height: 8),
                _diagKv('이전 오류 기록', lastError),
              ],
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    '고급 진단',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  children: [
                    _diagKv(
                      'Agent ID',
                      agent == null || agent!.agentId.isEmpty
                          ? '—'
                          : agent!.agentId,
                    ),
                    _diagKv(
                      'jobId',
                      job == null || job.jobId.isEmpty ? '—' : job.jobId,
                    ),
                    _diagKv(
                      'instructionId',
                      () {
                        final fromJob = job?.instructionId.trim() ?? '';
                        if (fromJob.isNotEmpty) return fromJob;
                        final fromProject =
                            current?.project?.projectId.trim() ?? '';
                        return fromProject.isEmpty ? '—' : fromProject;
                      }(),
                    ),
                    _diagKv(
                      'currentJobId',
                      agent == null || agent!.currentJobId.trim().isEmpty
                          ? '—'
                          : agent!.currentJobId,
                    ),
                    _diagKv('내부 status', job?.status ?? agent?.state ?? '—'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _diagKv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.children,
    required this.accent,
  });

  final String title;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        color: accent.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: accent,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard({
    required this.tone,
    required this.health,
    required this.stalled,
    required this.failed,
    this.onOpenDiagnostics,
  });

  final RemoteOpsSystemTone tone;
  final OpsHealthReport health;
  final bool stalled;
  final bool failed;
  final VoidCallback? onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      RemoteOpsSystemTone.ok => ControlColors.teal,
      RemoteOpsSystemTone.warn => Colors.orange.shade800,
      RemoteOpsSystemTone.error => ControlColors.accentRose,
    };
    final title = switch (tone) {
      RemoteOpsSystemTone.ok => '정상',
      RemoteOpsSystemTone.warn => '주의',
      RemoteOpsSystemTone.error => '오류',
    };
    final body = switch (tone) {
      RemoteOpsSystemTone.ok => '정상 동작 중',
      RemoteOpsSystemTone.warn =>
        health.suggestedCheck?.summary ?? '확인이 필요합니다.',
      RemoteOpsSystemTone.error => stalled
          ? '작업이 stalled 상태입니다. worker/단계를 진단하세요.'
          : (failed
                ? '현재 작업이 실패했습니다.'
                : (health.suggestedCheck?.summary ?? '시스템 오류가 있습니다.')),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        color: color.withValues(alpha: 0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시스템 상태 · $title',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          if (onOpenDiagnostics != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('remote_open_diagnostics_button'),
              onPressed: onOpenDiagnostics,
              child: const Text('진단정보 보기'),
            ),
          ],
        ],
      ),
    );
  }
}
