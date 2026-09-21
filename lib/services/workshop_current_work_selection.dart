import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import 'sotong24_workshop_presentation.dart';

/// AI 제작공정 대시보드: Remote Job을 현재 작업 1차 SSOT로 사용.
class WorkshopCurrentWorkSelection {
  WorkshopCurrentWorkSelection._();

  static const _terminalJobStatuses = {
    'completed',
    'cancelled',
    'failed',
    'result_validation_failed',
    'approved',
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

  static RemoteJobDoc? pickCurrentExecutionJob(Iterable<RemoteJobDoc> jobs) {
    final candidates = jobs.where(isActiveExecutionJob).toList()
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
    String? focusInstructionId,
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

    final currentJob = pickCurrentExecutionJob(jobs);
    WorkshopCurrentWorkItem? current;
    String? currentInstructionId;
    if (currentJob != null) {
      final project = projectForJob(operational, currentJob);
      current = WorkshopCurrentWorkItem.fromJob(
        job: currentJob,
        project: project,
        syncing: project == null,
      );
      currentInstructionId = currentJob.instructionId.trim().isNotEmpty
          ? currentJob.instructionId.trim()
          : (project?.projectId.trim() ?? '');
    }

    final needsAttention = <Sotong24RemoteProject>[];
    final completed = <Sotong24RemoteProject>[];
    final history = <Sotong24RemoteProject>[];

    for (final p in operational) {
      final id = p.projectId.trim();
      if (currentInstructionId != null &&
          currentInstructionId.isNotEmpty &&
          id == currentInstructionId) {
        continue; // 현재 제작 카드에 이미 표시
      }
      final st = p.userFacingStatus;
      if (st == Sotong24WorkStatus.awaitingApproval) {
        needsAttention.add(p);
      } else if (st == Sotong24WorkStatus.completed) {
        completed.add(p);
      } else {
        // 과거 active/error 등 — 현재 작업을 가리지 않도록 이력으로
        history.add(p);
      }
    }

    // Job만 있고 awaiting인 경우 → 확인 필요 섹션용 synthetic은 project 우선.
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

    // 테스트·불완전·터미널 job 대응 프로젝트도 이력에 합침 (중복 제외).
    for (final p in [...testProjects, ...incomplete]) {
      if (history.any((h) => h.projectId == p.projectId)) continue;
      if (needsAttention.any((h) => h.projectId == p.projectId)) continue;
      if (completed.any((h) => h.projectId == p.projectId)) continue;
      history.add(p);
    }

    // Job 기준 실패/취소 등 — project 없으면 이력 placeholder로 남기지 않고
    // project가 있으면 이미 history/completed에 포함됐을 수 있음.
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
    return WorkshopCurrentWorkItem(job: job, project: project, syncing: syncing);
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
