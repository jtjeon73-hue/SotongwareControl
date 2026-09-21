import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import 'sotong24_workshop_presentation.dart';

/// AI 제작공정 대시보드: Agent.currentJobId → live Remote Job 순 SSOT.
class WorkshopCurrentWorkSelection {
  WorkshopCurrentWorkSelection._();

  static const _terminalJobStatuses = {
    'completed',
    'cancelled',
    'failed',
    'result_validation_failed',
    'approved',
    'archived',
    'stale',
  };

  static const _awaitingJobStatuses = {
    'waiting_approval',
    'awaiting_user_approval',
    'pending_review',
    'revision_requested',
  };

  static const _activeExecutionStatuses = {
    'running',
    'claimed',
    'queued',
    'reworking',
    'paused',
    'result_validation_retrying',
    'stalled',
    'paused_quota',
    'paused_network',
    'ai_process_failed',
    'stage_transition_failed',
  };

  /// running(0) > waiting/queued 계열(1). awaiting review는 현재 제작 후보에서 제외.
  static int executionPriority(RemoteJobDoc job) {
    switch (job.status) {
      case 'running':
      case 'reworking':
      case 'claimed':
        return 0;
      case 'queued':
      case 'paused':
      case 'result_validation_retrying':
      case 'stalled':
      case 'paused_quota':
      case 'paused_network':
      case 'ai_process_failed':
      case 'stage_transition_failed':
        return 1;
      default:
        return 50;
    }
  }

  static bool isTerminalJob(RemoteJobDoc job) =>
      _terminalJobStatuses.contains(job.status);

  static bool isAwaitingJob(RemoteJobDoc job) =>
      _awaitingJobStatuses.contains(job.status);

  static bool isActiveExecutionJob(RemoteJobDoc job) =>
      _activeExecutionStatuses.contains(job.status);

  /// 승인/사용자검토/보류 project는 Job이 stale running이어도 현재 제작 제외.
  static bool isUserAttentionProject(Sotong24RemoteProject? project) {
    if (project == null) return false;
    if (project.userFacingStatus == Sotong24WorkStatus.awaitingApproval) {
      return true;
    }
    final stage = project.currentStageDoc;
    if (stage?.isOnHold == true) return true;
    return false;
  }

  static bool isExcludedFromCurrentProduction({
    required RemoteJobDoc job,
    Sotong24RemoteProject? project,
  }) {
    if (isTerminalJob(job)) return true;
    if (isAwaitingJob(job)) return true;
    if (isUserAttentionProject(project)) return true;
    return false;
  }

  static DateTime? jobActivity(RemoteJobDoc job) =>
      job.updatedAt ?? job.startedAt ?? job.createdAt;

  static int compareJobsByCurrentDesc(RemoteJobDoc a, RemoteJobDoc b) {
    final pa = executionPriority(a);
    final pb = executionPriority(b);
    if (pa != pb) return pa.compareTo(pb);
    final aa = jobActivity(a);
    final bb = jobActivity(b);
    if (aa == null && bb == null) return b.jobId.compareTo(a.jobId);
    if (aa == null) return 1;
    if (bb == null) return -1;
    final byTime = bb.compareTo(aa);
    if (byTime != 0) return byTime;
    return b.jobId.compareTo(a.jobId);
  }

  /// online·enabled Agent 중 가장 최근 heartbeat의 currentJobId.
  static String? pickOnlineAgentCurrentJobId(
    Iterable<RemoteAgentDoc> agents, {
    DateTime? now,
  }) {
    final candidates =
        agents.where((a) {
          if (!a.enabled) return false;
          if (a.currentJobId.trim().isEmpty) return false;
          if (!a.isOnline(now: now)) return false;
          return true;
        }).toList()
          ..sort((a, b) {
            final ah = a.lastHeartbeatAt;
            final bh = b.lastHeartbeatAt;
            if (ah == null && bh == null) {
              return b.agentId.compareTo(a.agentId);
            }
            if (ah == null) return 1;
            if (bh == null) return -1;
            final byHb = bh.compareTo(ah);
            if (byHb != 0) return byHb;
            return b.agentId.compareTo(a.agentId);
          });
    if (candidates.isEmpty) return null;
    return candidates.first.currentJobId.trim();
  }

  /// 1) Agent.currentJobId 일치 Job  2) 없으면 live non-terminal fallback.
  /// updatedAt만 최근인 stale job이 Agent 점유 Job보다 우선하지 않는다.
  static RemoteJobDoc? pickCurrentExecutionJob(
    Iterable<RemoteJobDoc> jobs, {
    Iterable<RemoteAgentDoc> agents = const [],
    Iterable<Sotong24RemoteProject> projects = const [],
    DateTime? now,
  }) {
    final byId = <String, RemoteJobDoc>{
      for (final j in jobs)
        if (j.jobId.trim().isNotEmpty) j.jobId.trim(): j,
    };

    final occupiedId = pickOnlineAgentCurrentJobId(agents, now: now);
    if (occupiedId != null && occupiedId.isNotEmpty) {
      final occupied = byId[occupiedId];
      if (occupied != null) {
        final project = projectForJob(projects, occupied);
        if (!isExcludedFromCurrentProduction(
          job: occupied,
          project: project,
        )) {
          return occupied;
        }
      }
    }

    final candidates = jobs.where((job) {
      if (!isActiveExecutionJob(job)) return false;
      final project = projectForJob(projects, job);
      return !isExcludedFromCurrentProduction(job: job, project: project);
    }).toList()
      ..sort(compareJobsByCurrentDesc);
    return candidates.isEmpty ? null : candidates.first;
  }

  static Sotong24RemoteProject? projectForJob(
    Iterable<Sotong24RemoteProject> projects,
    RemoteJobDoc job,
  ) {
    final id = job.instructionId.trim();
    if (id.isEmpty) return null;
    return Sotong24WorkshopPresentation.projectForInstruction(projects, id);
  }

  /// 대시보드 뷰 구성 (숨김이 아니라 섹션 분리).
  static WorkshopDashboardModel build({
    required Iterable<Sotong24RemoteProject> projects,
    required Iterable<RemoteJobDoc> jobs,
    Iterable<RemoteAgentDoc> agents = const [],
    String? focusInstructionId,
    DateTime? now,
  }) {
    final focusId = focusInstructionId?.trim() ?? '';
    final operational = Sotong24WorkshopPresentation.operationalProjects(
      projects,
    );
    final testProjects = projects
        .where(
          (p) =>
              !p.isDemo &&
              !p.isIncompleteListing &&
              Sotong24WorkshopPresentation.isTestProject(p),
        )
        .toList();
    final incomplete = projects
        .where((p) => p.isIncompleteListing && !p.isDemo)
        .toList();

    if (focusId.isNotEmpty) {
      final match = Sotong24WorkshopPresentation.projectForInstruction(
        projects,
        focusId,
      );
      final job = _jobForInstruction(jobs, focusId);
      if (match == null) {
        return WorkshopDashboardModel(
          waitingForExactFocus: job == null,
          current: job == null
              ? null
              : WorkshopCurrentWorkItem.fromJob(
                  job: job,
                  project: null,
                  syncing: true,
                ),
          needsAttention: const [],
          completed: const [],
          history: const [],
        );
      }
      return WorkshopDashboardModel(
        waitingForExactFocus: false,
        current: WorkshopCurrentWorkItem.fromJob(
          job: job,
          project: match,
          syncing: false,
        ),
        needsAttention: const [],
        completed: const [],
        history: const [],
      );
    }

    final currentJob = pickCurrentExecutionJob(
      jobs,
      agents: agents,
      projects: projects,
      now: now,
    );
    WorkshopCurrentWorkItem? current;
    String? currentInstructionId;
    if (currentJob != null) {
      final project = projectForJob(operational, currentJob);
      // operational에 없어도 전체 projects에서 merge 시도
      final merged = project ?? projectForJob(projects, currentJob);
      final eligibleProject =
          isUserAttentionProject(merged) ? null : merged;
      current = WorkshopCurrentWorkItem.fromJob(
        job: currentJob,
        project: eligibleProject,
        syncing: eligibleProject == null,
      );
      currentInstructionId = currentJob.instructionId.trim().isNotEmpty
          ? currentJob.instructionId.trim()
          : (eligibleProject?.projectId.trim() ?? '');
    }

    final needsAttention = <Sotong24RemoteProject>[];
    final completed = <Sotong24RemoteProject>[];
    final history = <Sotong24RemoteProject>[];

    for (final p in operational) {
      final id = p.projectId.trim();
      if (currentInstructionId != null &&
          currentInstructionId.isNotEmpty &&
          id == currentInstructionId) {
        continue;
      }
      final st = p.userFacingStatus;
      if (st == Sotong24WorkStatus.awaitingApproval ||
          isUserAttentionProject(p)) {
        needsAttention.add(p);
      } else if (st == Sotong24WorkStatus.completed) {
        completed.add(p);
      } else {
        history.add(p);
      }
    }

    for (final job in jobs) {
      if (!isAwaitingJob(job)) continue;
      final iid = job.instructionId.trim();
      if (iid.isEmpty) continue;
      if (currentInstructionId != null && iid == currentInstructionId) continue;
      if (needsAttention.any((p) => p.projectId.trim() == iid)) continue;
      final project = projectForJob(projects, job);
      if (project != null &&
          !Sotong24WorkshopPresentation.isTestProject(project) &&
          !project.isDemo) {
        needsAttention.add(project);
      }
    }

    needsAttention.sort(Sotong24WorkshopPresentation.compareByRecencyDesc);
    completed.sort(Sotong24WorkshopPresentation.compareByRecencyDesc);
    history.sort(Sotong24WorkshopPresentation.compareByRecencyDesc);

    for (final p in [...testProjects, ...incomplete]) {
      if (history.any((h) => h.projectId == p.projectId)) continue;
      if (needsAttention.any((h) => h.projectId == p.projectId)) continue;
      if (completed.any((h) => h.projectId == p.projectId)) continue;
      history.add(p);
    }

    return WorkshopDashboardModel(
      waitingForExactFocus: false,
      current: current,
      needsAttention: needsAttention,
      completed: completed,
      history: history,
    );
  }

  static RemoteJobDoc? _jobForInstruction(
    Iterable<RemoteJobDoc> jobs,
    String instructionId,
  ) {
    final id = instructionId.trim();
    if (id.isEmpty) return null;
    final matches = jobs.where((j) => j.instructionId.trim() == id).toList()
      ..sort(compareJobsByCurrentDesc);
    return matches.isEmpty ? null : matches.first;
  }
}

class WorkshopDashboardModel {
  const WorkshopDashboardModel({
    required this.waitingForExactFocus,
    required this.current,
    required this.needsAttention,
    required this.completed,
    required this.history,
  });

  final bool waitingForExactFocus;
  final WorkshopCurrentWorkItem? current;
  final List<Sotong24RemoteProject> needsAttention;
  final List<Sotong24RemoteProject> completed;
  final List<Sotong24RemoteProject> history;

  bool get isEmpty =>
      current == null &&
      needsAttention.isEmpty &&
      completed.isEmpty &&
      history.isEmpty;
}

class WorkshopCurrentWorkItem {
  const WorkshopCurrentWorkItem({
    required this.syncing,
    this.job,
    this.project,
  });

  final RemoteJobDoc? job;
  final Sotong24RemoteProject? project;
  final bool syncing;

  factory WorkshopCurrentWorkItem.fromJob({
    required RemoteJobDoc? job,
    required Sotong24RemoteProject? project,
    required bool syncing,
  }) {
    return WorkshopCurrentWorkItem(
      job: job,
      project: project,
      syncing: syncing,
    );
  }

  String get instructionId {
    final fromJob = job?.instructionId.trim() ?? '';
    if (fromJob.isNotEmpty) return fromJob;
    return project?.projectId.trim() ?? '';
  }

  String get jobId => job?.jobId.trim() ?? '';

  String get title {
    final fromProject = project == null
        ? ''
        : Sotong24WorkshopPresentation.displayTitle(project!);
    if (fromProject.isNotEmpty && fromProject != '(제목 없음)') return fromProject;
    final fromJob = job?.title.trim() ?? '';
    return fromJob.isEmpty ? '(제목 없음)' : fromJob;
  }

  String get productTypeLabel {
    if (project != null) return project!.productTypeLabel;
    final t = job?.type.trim() ?? '';
    if (t.isEmpty) return '제작';
    return ArtifactTypeLabel.safe(t);
  }

  String get statusLabel {
    if (syncing) return '제작공정 동기화 중';
    if (project != null) return project!.userFacingStatusLabel;
    return job?.statusLabelKo ?? '작업 중';
  }

  String get stageLine {
    if (project != null) {
      return Sotong24WorkshopPresentation.currentStageLine(project!);
    }
    final stage = job?.currentStage.trim() ?? '';
    if (stage.isEmpty) return '단계 정보 동기화 중';
    return stage;
  }

  String get progressLine {
    if (syncing) return '전체 진행률 — (동기화 대기)';
    if (project != null) {
      return Sotong24WorkshopPresentation.overallProgressLine(project!);
    }
    final p = job?.progress ?? 0;
    return '전체 진행률 보고값 $p%';
  }

  int? get progressBarPercent {
    if (syncing || project == null) return null;
    return project!.overallProgressPercent.clamp(0, 100);
  }

  String get lastUpdatedLine {
    final fromProject = project?.lastActivityAt.trim().isNotEmpty == true
        ? project!.lastActivityAt
        : (project?.updatedAt.trim().isNotEmpty == true
              ? project!.updatedAt
              : project?.lastHeartbeat ?? '');
    if (fromProject.trim().isNotEmpty) {
      return fromProject;
    }
    final dt = job?.updatedAt ?? job?.startedAt;
    return dt?.toUtc().toIso8601String() ?? '';
  }

  /// 문제가 있을 때만 짧은 경고. 동기화 대기 자체는 상태가 담당.
  String? get warningLine {
    if (syncing) return null;
    final st = job?.status.trim() ?? '';
    switch (st) {
      case 'stalled':
        return '작업이 정체된 것으로 보입니다.';
      case 'ai_process_failed':
      case 'stage_transition_failed':
        return '단계 진행에 문제가 있습니다.';
      case 'paused_quota':
        return '할당량 제한으로 일시 정지되었습니다.';
      case 'paused_network':
        return '네트워크 문제로 일시 정지되었습니다.';
      default:
        break;
    }
    final stage = project?.currentStageDoc;
    final err = stage?.errorMessage.trim() ?? '';
    if (err.isNotEmpty) return err;
    final attention = stage?.userAttention.trim() ?? '';
    if (attention.isNotEmpty) return attention;
    return null;
  }
}

/// ArtifactType import 없이 라벨만 안전하게.
class ArtifactTypeLabel {
  static String safe(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'ebook':
        return '전자책';
      case 'app':
        return '앱';
      case 'site':
        return '사이트';
      case 'promo_site':
        return '홍보 사이트';
      case 'contents':
        return '콘텐츠';
      default:
        return raw;
    }
  }
}
