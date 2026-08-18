import 'package:flutter/material.dart';

import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import '../services/ops_health_check.dart';
import '../services/sotong24_workshop_presentation.dart';
import '../theme/control_theme.dart';

/// 노트북 원격관제 — 운영자용 한눈에 보기 대시보드.
class RemoteOpsDashboard extends StatelessWidget {
  const RemoteOpsDashboard({
    super.key,
    required this.agents,
    required this.workshops,
    required this.onRefresh,
    this.jobs = const [],
    this.refreshing = false,
    this.onOpenWorkshop,
    this.onOpenDiagnostics,
  });

  final List<RemoteAgentDoc> agents;
  final List<Sotong24RemoteProject> workshops;
  final List<RemoteJobDoc> jobs;
  final VoidCallback onRefresh;
  final bool refreshing;
  final VoidCallback? onOpenWorkshop;
  final VoidCallback? onOpenDiagnostics;

  List<Sotong24RemoteProject> get _operationalWorkshops =>
      Sotong24WorkshopPresentation.operationalProjects(workshops);

  @override
  Widget build(BuildContext context) {
    final onlineAgents = agents.where((a) => a.isOnline()).toList();
    final primaryAgent = onlineAgents.isNotEmpty
        ? onlineAgents.first
        : (agents.isNotEmpty ? agents.first : null);

    final operational = _operationalWorkshops;

    Sotong24RemoteProject? currentWork;
    for (final p in operational) {
      if (p.userFacingStatus == Sotong24WorkStatus.awaitingApproval) {
        currentWork = p;
        break;
      }
    }
    currentWork ??= operational.cast<Sotong24RemoteProject?>().firstWhere(
      (p) => p!.userFacingStatus != Sotong24WorkStatus.completed,
      orElse: () => operational.isEmpty ? null : operational.first,
    );
    if (operational.isEmpty) currentWork = null;

    final waitingCount = operational
        .where((p) => p.userFacingStatus == Sotong24WorkStatus.awaitingApproval)
        .length;

    final lastSeen = primaryAgent?.lastHeartbeatAt;
    final lastSeenText = lastSeen == null
        ? '—'
        : _relativeKo(lastSeen.toLocal());

    final alerts = _buildAlerts(
      primaryAgent: primaryAgent,
      waitingCount: waitingCount,
      currentWork: currentWork,
    );

    final health = OpsHealthCheck.evaluate(
      agents: agents,
      jobs: jobs,
      workshops: workshops,
    );
    final suggested = health.suggestedCheck;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AI 공장 기계실',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          const _SectionLabel('시스템 상태'),
          const SizedBox(height: 8),
          _StatusRow(
            label: '노트북',
            value: primaryAgent == null
                ? '연결 없음'
                : (primaryAgent.isOnline() ? '온라인' : '오프라인'),
            ok: primaryAgent?.isOnline() == true,
          ),
          const SizedBox(height: 10),
          _StatusRow(
            label: '소통24워크 Agent',
            value: primaryAgent == null
                ? '미연결'
                : (primaryAgent.isOnline() ? '정상' : '응답 없음'),
            ok: primaryAgent?.isOnline() == true,
          ),
          const SizedBox(height: 10),
          _LabeledBlock(
            label: 'Agent 상태',
            child: Text(
              _agentOperationalState(primaryAgent),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          _LabeledBlock(
            label: '최근 연결',
            child: Text(
              lastSeenText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 24),
          const _SectionLabel('AI 사용량'),
          const SizedBox(height: 8),
          _WorkerLine(
            name: 'Codex',
            status: _workerStatus(primaryAgent),
            usage: '수집 준비 중',
          ),
          const SizedBox(height: 6),
          _WorkerLine(
            name: 'Cursor',
            status: _cursorStatus(primaryAgent),
            usage: '수집 준비 중',
          ),
          const Divider(height: 24),
          const _SectionLabel('현재 진행 작업'),
          const SizedBox(height: 8),
          _currentWorkBlock(currentWork, primaryAgent),
          const SizedBox(height: 12),
          _LabeledBlock(
            label: '승인 대기',
            child: Text(
              waitingCount == 0 ? '0건' : '$waitingCount건',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (alerts.isNotEmpty) ...[
            const Divider(height: 24),
            const _SectionLabel('중요 알림'),
            const SizedBox(height: 8),
            for (final alert in alerts) ...[
              _AlertLine(text: alert),
              const SizedBox(height: 6),
            ],
          ],
          const Divider(height: 24),
          const _SectionLabel('점검 안내'),
          const SizedBox(height: 8),
          Text(
            health.overallLabelKo,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (health.overall != OpsHealthLevel.ok && suggested != null) ...[
            const SizedBox(height: 4),
            Text(
              suggested.summary,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenDiagnostics,
              child: Text(suggested.title),
            ),
          ],
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

  List<String> _buildAlerts({
    required RemoteAgentDoc? primaryAgent,
    required int waitingCount,
    required Sotong24RemoteProject? currentWork,
  }) {
    final alerts = <String>[];
    if (waitingCount > 0) {
      alerts.add('승인 필요: $waitingCount건');
    }
    if (primaryAgent != null && !primaryAgent.isOnline()) {
      alerts.add('Agent 연결이 끊겼습니다');
    }
    if (currentWork?.userFacingStatus == Sotong24WorkStatus.error) {
      alerts.add('작업 오류 — 상세를 확인하세요');
    }
    return alerts;
  }

  static String _agentOperationalState(RemoteAgentDoc? agent) {
    if (agent == null) return '—';
    if (!agent.isOnline()) return '오프라인';
    switch (agent.state) {
      case 'idle':
        return '대기';
      case 'running':
      case 'receiving_job':
        return '작업 중';
      case 'waiting_approval':
      case 'awaiting_user_approval':
      case 'pending_review':
        return '승인 대기';
      case 'revision_requested':
        return '보완 요청';
      case 'error':
        return '오류';
      default:
        return agent.stateLabelKo;
    }
  }

  static String _workerStatus(RemoteAgentDoc? agent) {
    if (agent == null) return '준비';
    if (!agent.isOnline()) return '미연결';
    switch (agent.state) {
      case 'running':
      case 'receiving_job':
        return '작업 중';
      case 'waiting_approval':
      case 'awaiting_user_approval':
      case 'pending_review':
      case 'revision_requested':
        return '승인 대기';
      default:
        return '준비';
    }
  }

  static bool _agentJobIsLive(
    RemoteAgentDoc? agent,
    List<RemoteJobDoc> jobs,
    List<Sotong24RemoteProject> operationalWorkshops,
  ) {
    final jobId = agent?.currentJobId.trim() ?? '';
    if (jobId.isEmpty) return false;
    if (jobs.any((j) => j.jobId == jobId || j.instructionId == jobId)) {
      return true;
    }
    return operationalWorkshops.any((p) => p.projectId == jobId);
  }

  Widget _currentWorkBlock(
    Sotong24RemoteProject? currentWork,
    RemoteAgentDoc? agent,
  ) {
    if (currentWork != null) {
      final rev = Sotong24WorkshopPresentation.revisionLine(currentWork);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentWork.productTypeLabel.isNotEmpty
                ? Sotong24WorkshopPresentation.businessTypeLabel(
                    currentWork.productType,
                  )
                : currentWork.productTypeLabel,
            style: const TextStyle(
              color: ControlColors.teal,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentWork.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            currentWork.progressSummaryLine,
            style: const TextStyle(
              fontSize: 13,
              color: ControlColors.textSecondary,
            ),
          ),
          if (rev.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rev,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '상태: ${currentWork.userFacingStatusLabel}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (onOpenWorkshop != null) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onOpenWorkshop,
              child: const Text('AI 제작공정에서 계속 보기'),
            ),
          ],
        ],
      );
    }
    if (_agentJobIsLive(agent, jobs, _operationalWorkshops)) {
      final jobId = agent!.currentJobId.trim();
      final stage = agent.currentStage.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(jobId, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (stage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stage,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '상태: ${agent.stateLabelKo}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (onOpenWorkshop != null) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onOpenWorkshop,
              child: const Text('AI 제작공정에서 계속 보기'),
            ),
          ],
        ],
      );
    }
    return const Text(
      '현재 진행 중인 작업이 없습니다.',
      style: TextStyle(color: ControlColors.textSecondary),
    );
  }

  static String _cursorStatus(RemoteAgentDoc? agent) {
    if (agent == null) return '미실행';
    if (!agent.isOnline()) return '미실행';
    return agent.state == 'running' ? '실행' : '준비';
  }

  static String _relativeKo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}초 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    return '${diff.inHours}시간 전';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ControlColors.textMuted,
      ),
    );
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline,
          size: 16,
          color: ControlColors.accentWarm,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.circle : Icons.circle_outlined,
          size: 12,
          color: ok ? ControlColors.accentGreen : ControlColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: ControlColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: ok ? ControlColors.textPrimary : ControlColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ControlColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _WorkerLine extends StatelessWidget {
  const _WorkerLine({required this.name, required this.status, this.usage});

  final String name;
  final String status;
  final String? usage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              status,
              style: const TextStyle(color: ControlColors.textSecondary),
            ),
          ],
        ),
        if (usage != null && usage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '사용량: $usage',
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
