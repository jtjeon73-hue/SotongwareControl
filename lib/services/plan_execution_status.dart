/// Plan ↔ Sotong24Work 실행 상태 통합 판정 (전달 전/후 분리).
library;

import '../models/business_planning.dart';
import '../models/project_design_state.dart';
import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import 'plan_progress_status.dart';

/// 전달 여부.
class PlanTransferState {
  static const notDelivered = 'not_delivered';
  static const pending = 'pending';
  static const delivered = 'delivered';
  static const failed = 'failed';
}

/// PC 수신 여부 (Sotong24Work mirror 기준).
class PlanPcReceiveState {
  static const notReceived = 'not_received';
  static const received = 'received';
}

/// Sotong24Work 실제 실행 상태.
class PlanRunState {
  static const notStarted = 'not_started';
  static const working = 'working';
  static const awaitingApproval = 'awaiting_approval';
  static const revisionRequested = 'revision_requested';
  static const reworking = 'reworking';
  static const stopped = 'stopped';
  static const completed = 'completed';
  static const error = 'error';
  static const cancelled = 'cancelled';
}

/// workInstructions mirror / relay 에서 읽은 실행 요약 (선택).
class PlanExecutionRemoteHints {
  const PlanExecutionRemoteHints({
    this.projectTitle = '',
    this.currentStage = 0,
    this.totalStages = 18,
    this.currentStageId = '',
    this.runState = '',
    this.approvalStatus = '',
    this.workflowStarted = false,
    this.hasLocalProject = false,
    this.hasArtifacts = false,
    this.agentOnline = false,
    this.lastUpdated = '',
    this.jobId = '',
    this.agentId = '',
    this.planId = '',
  });

  final String projectTitle;
  final int currentStage;
  final int totalStages;
  final String currentStageId;
  final String runState;
  final String approvalStatus;
  final bool workflowStarted;
  final bool hasLocalProject;
  final bool hasArtifacts;
  final bool agentOnline;
  final String lastUpdated;
  final String jobId;
  final String agentId;
  final String planId;

  bool get hasAnyExecutionEvidence =>
      workflowStarted ||
      currentStage > 0 ||
      hasLocalProject ||
      hasArtifacts ||
      runState == PlanRunState.working ||
      runState == PlanRunState.awaitingApproval ||
      runState == PlanRunState.completed;
}

/// 카드·필터·보호 정책에 쓰는 단일 실행 스냅샷.
class PlanExecutionSnapshot {
  const PlanExecutionSnapshot({
    required this.instructionId,
    required this.planId,
    required this.isPostTransfer,
    required this.transferState,
    required this.pcReceiveState,
    required this.runState,
    required this.instructionDesignStep,
    required this.instructionDesignTotal,
    required this.productionCurrentStage,
    required this.productionTotalStages,
    required this.displayTitle,
    required this.primaryStatusLabel,
    required this.instructionProgressLine,
    required this.productionProgressLine,
    required this.transferLine,
    required this.currentStageLabel,
    required this.hasActualExecution,
    required this.isDeliveredOnly,
    required this.isActivelyRunning,
    required this.isAwaitingApproval,
    required this.agentOnline,
    this.lastUpdated = '',
  });

  final String instructionId;
  final String planId;
  final bool isPostTransfer;
  final String transferState;
  final String pcReceiveState;
  final String runState;
  final int instructionDesignStep;
  final int instructionDesignTotal;
  final int productionCurrentStage;
  final int productionTotalStages;
  final String displayTitle;
  final String primaryStatusLabel;
  final String instructionProgressLine;
  final String productionProgressLine;
  final String transferLine;
  final String currentStageLabel;
  final bool hasActualExecution;
  final bool isDeliveredOnly;
  final bool isActivelyRunning;
  final bool isAwaitingApproval;
  final bool agentOnline;
  final String lastUpdated;

  bool get instructionDesignComplete =>
      instructionDesignStep >= instructionDesignTotal;

  static PlanExecutionSnapshot emptyFor(BusinessPlanDocument plan) =>
      PlanExecutionStatusResolver.resolve(plan);
}

class PlanExecutionStatusResolver {
  PlanExecutionStatusResolver._();

  static const instructionDesignTotal = ProjectDesignStep.count;

  static PlanExecutionSnapshot resolve(
    BusinessPlanDocument plan, {
    Sotong24RemoteProject? remoteProject,
    RemoteJobDoc? remoteJob,
    PlanExecutionRemoteHints? hints,
  }) {
    final instructionId = plan.stableInstructionId;
    final reconciled = PlanProgressStatus.reconcile(plan);
    final planStatus = PlanningStatus.normalize(reconciled.status);
    final trulyTransferred = PlanProgressStatus.isTrulyTransferred(reconciled);
    final downloadPending = PlanProgressStatus.isDownloadOnlyPending(
      reconciled,
    );
    final remoteEvidence =
        (remoteProject != null && !remoteProject.isDemo) || remoteJob != null;

    final designStep = _instructionDesignStep(plan);
    final designComplete = plan.hasInstruction;

    final transferState = _transferState(
      planStatus: planStatus,
      trulyTransferred: trulyTransferred,
      downloadPending: downloadPending,
      designComplete: designComplete,
      remoteEvidence: remoteEvidence,
      transferFailed: planStatus == PlanningStatus.transferFailed,
    );
    final isPostTransfer =
        transferState == PlanTransferState.delivered ||
        transferState == PlanTransferState.pending;

    final merged = _mergeRemote(
      remoteProject: remoteProject,
      remoteJob: remoteJob,
      hints: hints,
    );

    final pcReceive = _pcReceiveState(isPostTransfer, merged);
    final runState = _runState(
      isPostTransfer: isPostTransfer,
      planStatus: planStatus,
      merged: merged,
    );

    final prodCurrent = merged.currentStage;
    final prodTotal = merged.totalStages > 0 ? merged.totalStages : 18;

    final hasActualExecution = _hasActualExecution(
      isPostTransfer: isPostTransfer,
      merged: merged,
      runState: runState,
      planStatus: planStatus,
    );

    final isDeliveredOnly =
        isPostTransfer &&
        !hasActualExecution &&
        transferState == PlanTransferState.delivered;

    final displayTitle = _displayTitle(plan, merged);
    final primaryLabel = _primaryStatusLabel(
      plan: plan,
      isPostTransfer: isPostTransfer,
      transferState: transferState,
      pcReceive: pcReceive,
      runState: runState,
      hasActualExecution: hasActualExecution,
      designStep: designStep,
      designComplete: designComplete,
    );

    final instructionLine = isPostTransfer && designComplete
        ? '작업지시 완료'
        : '작업지시 $designStep/$instructionDesignTotal';

    final productionLine = transferState == PlanTransferState.failed
        ? '다시 시도 필요'
        : !isPostTransfer
        ? 'AI 제작공정: 미전달'
        : !hasActualExecution
        ? 'AI 제작공정: ${pcReceive == PlanPcReceiveState.received ? '수신됨 · 미시작' : '전달됨 · PC 미수신'}'
        : runState == PlanRunState.awaitingApproval
        ? '제작 $prodCurrent/$prodTotal · 승인대기'
        : '제작 $prodCurrent/$prodTotal';

    final transferLine = _transferLine(
      transferState: transferState,
      pcReceive: pcReceive,
      runState: runState,
      hasActualExecution: hasActualExecution,
    );

    final stageLabel = hasActualExecution && merged.currentStageId.isNotEmpty
        ? merged.currentStageId
        : (hasActualExecution && prodCurrent > 0 ? '$prodCurrent단계' : '');

    return PlanExecutionSnapshot(
      instructionId: instructionId,
      planId: plan.id,
      isPostTransfer: isPostTransfer,
      transferState: transferState,
      pcReceiveState: pcReceive,
      runState: runState,
      instructionDesignStep: designStep,
      instructionDesignTotal: instructionDesignTotal,
      productionCurrentStage: prodCurrent,
      productionTotalStages: prodTotal,
      displayTitle: displayTitle,
      primaryStatusLabel: primaryLabel,
      instructionProgressLine: instructionLine,
      productionProgressLine: productionLine,
      transferLine: transferLine,
      currentStageLabel: stageLabel,
      hasActualExecution: hasActualExecution,
      isDeliveredOnly: isDeliveredOnly,
      isActivelyRunning:
          runState == PlanRunState.working ||
          runState == PlanRunState.reworking,
      isAwaitingApproval: runState == PlanRunState.awaitingApproval,
      agentOnline: merged.agentOnline,
      lastUpdated: merged.lastUpdated.isNotEmpty
          ? merged.lastUpdated
          : plan.updatedAt,
    );
  }

  static int _instructionDesignStep(BusinessPlanDocument plan) {
    if (plan.hasInstruction) return instructionDesignTotal;
    final ws = plan.input.wizardSelections;
    if (ws != null) {
      final step = ws['step'];
      if (step is int) {
        return (step + 1).clamp(1, instructionDesignTotal);
      }
      if (step is num) {
        return (step.toInt() + 1).clamp(1, instructionDesignTotal);
      }
    }
    final s = PlanningStatus.normalize(plan.status);
    if (s == PlanningStatus.instructionReady ||
        s == PlanningStatus.readyToTransfer ||
        s == PlanningStatus.validationRequired) {
      return instructionDesignTotal;
    }
    return 1;
  }

  static String _instructionDesignStepLabel(int step) {
    final idx = (step - 1).clamp(0, ProjectDesignStep.labels.length - 1);
    return ProjectDesignStep.labels[idx];
  }

  static String instructionDesignStepName(BusinessPlanDocument plan) =>
      _instructionDesignStepLabel(_instructionDesignStep(plan));

  static String _transferState({
    required String planStatus,
    required bool trulyTransferred,
    required bool downloadPending,
    required bool designComplete,
    bool remoteEvidence = false,
    bool transferFailed = false,
  }) {
    if (planStatus == PlanningStatus.imported ||
        trulyTransferred ||
        remoteEvidence) {
      return PlanTransferState.delivered;
    }
    if (transferFailed) {
      return PlanTransferState.failed;
    }
    if (downloadPending ||
        planStatus == PlanningStatus.downloadedPendingImport) {
      return PlanTransferState.pending;
    }
    if (planStatus == PlanningStatus.readyToTransfer && designComplete) {
      return PlanTransferState.pending;
    }
    if (planStatus == PlanningStatus.transferred && !trulyTransferred) {
      return PlanTransferState.failed;
    }
    return PlanTransferState.notDelivered;
  }

  static PlanExecutionRemoteHints _mergeRemote({
    Sotong24RemoteProject? remoteProject,
    RemoteJobDoc? remoteJob,
    PlanExecutionRemoteHints? hints,
  }) {
    var merged = hints ?? const PlanExecutionRemoteHints();
    if (remoteProject != null && !remoteProject.isDemo) {
      merged = PlanExecutionRemoteHints(
        projectTitle: remoteProject.title.isNotEmpty
            ? remoteProject.title
            : merged.projectTitle,
        currentStage: remoteProject.currentStage > 0
            ? remoteProject.currentStage
            : merged.currentStage,
        totalStages: remoteProject.totalStages > 0
            ? remoteProject.totalStages
            : merged.totalStages,
        currentStageId: remoteProject.currentStageDoc?.stageId ?? '',
        runState: _runStateFromRemoteProject(remoteProject),
        approvalStatus: remoteProject.approvalStatus,
        workflowStarted:
            remoteProject.startedAt.isNotEmpty ||
            remoteProject.currentStage > 0,
        hasLocalProject: true,
        hasArtifacts: remoteProject.progress > 0,
        agentOnline:
            remoteProject.resolvedPcStatus == Sotong24PcLinkStatus.online,
        lastUpdated: remoteProject.updatedAt,
        jobId: merged.jobId,
        agentId: merged.agentId,
        planId: remoteProject.projectId,
      );
    }
    if (remoteJob != null) {
      merged = PlanExecutionRemoteHints(
        projectTitle: merged.projectTitle,
        currentStage: merged.currentStage,
        totalStages: merged.totalStages,
        currentStageId: merged.currentStageId,
        runState: _runStateFromJob(remoteJob) ?? merged.runState,
        approvalStatus: merged.approvalStatus,
        workflowStarted:
            merged.workflowStarted ||
            remoteJob.startedAt != null ||
            const {
              'running',
              'claimed',
              'waiting_approval',
              'reworking',
            }.contains(remoteJob.status),
        hasLocalProject: merged.hasLocalProject,
        hasArtifacts: merged.hasArtifacts,
        agentOnline: merged.agentOnline,
        lastUpdated:
            remoteJob.updatedAt?.toIso8601String() ?? merged.lastUpdated,
        jobId: remoteJob.jobId,
        agentId: remoteJob.assignedAgentId,
        planId: merged.planId,
      );
    }
    return merged;
  }

  static String _runStateFromRemoteProject(Sotong24RemoteProject p) {
    if (p.approvalStatus == ApprovalStatus.pending ||
        p.status == Sotong24WorkStatus.awaitingApproval) {
      return PlanRunState.awaitingApproval;
    }
    if (p.approvalStatus == ApprovalStatus.revisionRequested ||
        p.status == Sotong24WorkStatus.revision) {
      return PlanRunState.revisionRequested;
    }
    if (p.status == Sotong24WorkStatus.completed) {
      return PlanRunState.completed;
    }
    if (p.status == Sotong24WorkStatus.error) {
      return PlanRunState.error;
    }
    if (p.currentStage > 0 || p.startedAt.isNotEmpty) {
      return PlanRunState.working;
    }
    return PlanRunState.notStarted;
  }

  static String? _runStateFromJob(RemoteJobDoc job) {
    switch (job.status) {
      case 'running':
      case 'claimed':
        return PlanRunState.working;
      case 'waiting_approval':
        return PlanRunState.awaitingApproval;
      case 'revision_requested':
        return PlanRunState.revisionRequested;
      case 'reworking':
        return PlanRunState.reworking;
      case 'completed':
      case 'approved':
        return PlanRunState.completed;
      case 'failed':
        return PlanRunState.error;
      case 'cancelled':
      case 'paused':
        return PlanRunState.stopped;
      default:
        return null;
    }
  }

  static String _pcReceiveState(
    bool isPostTransfer,
    PlanExecutionRemoteHints merged,
  ) {
    if (!isPostTransfer) return PlanPcReceiveState.notReceived;
    if (merged.hasLocalProject ||
        merged.workflowStarted ||
        merged.currentStage > 0) {
      return PlanPcReceiveState.received;
    }
    return PlanPcReceiveState.notReceived;
  }

  static String _runState({
    required bool isPostTransfer,
    required String planStatus,
    required PlanExecutionRemoteHints merged,
  }) {
    if (!isPostTransfer) return PlanRunState.notStarted;
    if (merged.runState.isNotEmpty) return merged.runState;
    if (planStatus == PlanningStatus.completed) return PlanRunState.completed;
    if (planStatus == PlanningStatus.inProgress) return PlanRunState.working;
    if (planStatus == PlanningStatus.imported && merged.workflowStarted) {
      return PlanRunState.working;
    }
    return PlanRunState.notStarted;
  }

  static bool _hasActualExecution({
    required bool isPostTransfer,
    required PlanExecutionRemoteHints merged,
    required String runState,
    required String planStatus,
  }) {
    if (!isPostTransfer) return false;
    if (merged.hasAnyExecutionEvidence) return true;
    if (runState != PlanRunState.notStarted) return true;
    if (planStatus == PlanningStatus.inProgress ||
        planStatus == PlanningStatus.imported ||
        planStatus == PlanningStatus.completed) {
      return true;
    }
    return false;
  }

  static String _displayTitle(
    BusinessPlanDocument plan,
    PlanExecutionRemoteHints merged,
  ) {
    final remoteTitle = merged.projectTitle.trim();
    if (remoteTitle.isNotEmpty) return remoteTitle;
    final fromWi = plan.instruction?.businessIdea.trim() ?? '';
    if (fromWi.isNotEmpty) return fromWi;
    final topic = plan.input.topic.trim();
    return topic.isEmpty ? '(주제 미입력)' : topic;
  }

  static String _primaryStatusLabel({
    required BusinessPlanDocument plan,
    required bool isPostTransfer,
    required String transferState,
    required String pcReceive,
    required String runState,
    required bool hasActualExecution,
    required int designStep,
    required bool designComplete,
  }) {
    if (plan.isLibraryArchived ||
        PlanningStatus.normalize(plan.status) == PlanningStatus.archived) {
      return '보관';
    }
    if (plan.tags.contains('보류') ||
        plan.tags.contains('deferred') ||
        plan.tags.contains('hold')) {
      return '보류';
    }

    if (!isPostTransfer) {
      if (transferState == PlanTransferState.failed) {
        return '전송 실패';
      }
      if (!designComplete) {
        if (designStep < instructionDesignTotal) return '작업지시 제작중';
        return '기획중';
      }
      if (transferState == PlanTransferState.pending) return '전달대기';
      final s = PlanningStatus.normalize(plan.status);
      if (s == PlanningStatus.instructionReady ||
          s == PlanningStatus.validationRequired) {
        return '작업지시 준비완료';
      }
      return '작업지시 준비완료';
    }

    if (!hasActualExecution) {
      return pcReceive == PlanPcReceiveState.received
          ? 'PC 수신 · 미시작'
          : '전달됨 · 미실행';
    }

    switch (runState) {
      case PlanRunState.awaitingApproval:
        return '승인대기';
      case PlanRunState.revisionRequested:
        return '보완요청';
      case PlanRunState.reworking:
        return '재작업중';
      case PlanRunState.working:
        return '작업중';
      case PlanRunState.completed:
        return '완료';
      case PlanRunState.error:
        return '오류';
      case PlanRunState.stopped:
      case PlanRunState.cancelled:
        return '중지';
      default:
        return 'PC 수신 · 미시작';
    }
  }

  static String _transferLine({
    required String transferState,
    required String pcReceive,
    required String runState,
    required bool hasActualExecution,
  }) {
    if (transferState == PlanTransferState.notDelivered) {
      return 'AI 제작공정: 미전달';
    }
    if (transferState == PlanTransferState.failed) {
      return '다시 시도 필요';
    }
    if (!hasActualExecution) {
      return pcReceive == PlanPcReceiveState.received
          ? '전달완료 · PC 수신 · 미시작'
          : '전달완료 · PC 미수신';
    }
    switch (runState) {
      case PlanRunState.awaitingApproval:
        return 'AI 제작공정: 승인대기';
      case PlanRunState.working:
      case PlanRunState.reworking:
        return 'AI 제작공정: 작업중';
      case PlanRunState.completed:
        return 'AI 제작공정: 완료';
      case PlanRunState.error:
        return 'AI 제작공정: 오류';
      default:
        return 'AI 제작공정: 실행중';
    }
  }
}
