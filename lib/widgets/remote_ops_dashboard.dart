import 'package:flutter/material.dart';

import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import '../services/sotong24_workshop_presentation.dart';
import '../theme/control_theme.dart';

/// 노트북 원격관제 — 운영자용 한눈에 보기 대시보드.
class RemoteOpsDashboard extends StatelessWidget {
  const RemoteOpsDashboard({
    super.key,
    required this.agents,
    required this.workshops,
    required this.onRefresh,
    this.refreshing = false,
  });

  final List<RemoteAgentDoc> agents;
  final List<Sotong24RemoteProject> workshops;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final onlineAgents = agents.where((a) => a.isOnline()).toList();
    final primaryAgent = onlineAgents.isNotEmpty
        ? onlineAgents.first
        : (agents.isNotEmpty ? agents.first : null);

    final realProjects = workshops
        .where(
          (p) =>
              !p.isIncompleteListing &&
              !Sotong24WorkshopPresentation.isTestProject(p),
        )
        .toList();

    Sotong24RemoteProject? currentWork;
    for (final p in realProjects) {
      if (p.userFacingStatus == Sotong24WorkStatus.awaitingApproval) {
        currentWork = p;
        break;
      }
    }
    currentWork ??= realProjects.cast<Sotong24RemoteProject?>().firstWhere(
      (p) => p!.userFacingStatus != Sotong24WorkStatus.completed,
      orElse: () => realProjects.isEmpty ? null : realProjects.first,
    );

    final waitingCount = realProjects
        .where((p) => p.userFacingStatus == Sotong24WorkStatus.awaitingApproval)
        .length;

    final lastSeen = primaryAgent?.lastHeartbeatAt;
    final lastSeenText = lastSeen == null
        ? '—'
        : _relativeKo(lastSeen.toLocal());

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
          const Divider(height: 24),
          _LabeledBlock(
            label: '현재 작업',
            child: _currentWorkBlock(currentWork, primaryAgent),
          ),
          const SizedBox(height: 12),
          _LabeledBlock(
            label: '승인 대기',
            child: Text(
              waitingCount == 0 &&
                      primaryAgent?.state != 'waiting_approval' &&
                      primaryAgent?.state != 'awaiting_user_approval' &&
                      primaryAgent?.state != 'pending_review'
                  ? '없음'
                  : (waitingCount == 0 ? 'Agent 승인 대기' : '$waitingCount건'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 24),
          _LabeledBlock(
            label: 'AI 작업자',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LabeledBlock(
            label: '최근 연결',
            child: Text(
              lastSeenText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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

  static Widget _currentWorkBlock(
    Sotong24RemoteProject? currentWork,
    RemoteAgentDoc? agent,
  ) {
    if (currentWork != null) {
      final rev = Sotong24WorkshopPresentation.revisionLine(currentWork);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      );
    }
    final jobId = agent?.currentJobId.trim() ?? '';
    final stage = agent?.currentStage.trim() ?? '';
    if (jobId.isNotEmpty || stage.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            jobId.isEmpty ? '진행 중' : jobId,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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
            '상태: ${agent?.stateLabelKo ?? '—'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    return const Text(
      '진행 중인 실제 작업 없음',
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
