import '../models/business_planning.dart';
import '../models/remote_agent_models.dart';
import 'commercial_work_instruction_preflight.dart';
import 'instruction_content_checksum.dart';
import 'plan_progress_status.dart';
import 'plan_user_facing_status.dart';
import 'remote_agent_repository.dart';
import 'remote_control_api.dart';

/// instructionId 기준 원격 전달 결과. `delivered` 만 UI 「전달됨」에 쓴다.
class RemoteDeliveryResult {
  const RemoteDeliveryResult({
    required this.delivered,
    this.jobId = '',
    this.commandId = '',
    this.agentId = '',
    this.outcome = '',
    this.errorCode,
    this.userMessage = '',
    this.payload = const {},
  });

  final bool delivered;
  final String jobId;
  final String commandId;
  final String agentId;
  final String outcome;
  final String? errorCode;
  final String userMessage;
  final Map<String, dynamic> payload;

  factory RemoteDeliveryResult.failed({
    required String userMessage,
    String? errorCode,
    String jobId = '',
    String commandId = '',
    String agentId = '',
    String outcome = 'failed',
    Map<String, dynamic> payload = const {},
  }) {
    return RemoteDeliveryResult(
      delivered: false,
      jobId: jobId,
      commandId: commandId,
      agentId: agentId,
      outcome: outcome,
      errorCode: errorCode,
      userMessage: userMessage,
      payload: payload,
    );
  }
}

enum RemoteDeliveryCase {
  /// A. Job/START_JOB 없음 → 생성
  createAll,

  /// B. Job만 있음 → command 복구
  repairCommand,

  /// C. START_JOB 이미 있음 → 재사용
  reuse,

  /// D. claim/started
  blockedInProgress,

  /// E. completed
  blockedCompleted,
}

/// 작업지시 제작소 원격 전달 SSOT (Inbox 쓰기는 전달 성공 조건이 아님).
class WorkInstructionRemoteDelivery {
  WorkInstructionRemoteDelivery._();

  static const orphanProductionInstructionId = 'wi_plan_1786083242850';

  static String startIdempotencyKey(String instructionId) =>
      'idem_start_${instructionId.trim()}';

  static RemoteJobDoc? findJob(List<RemoteJobDoc> jobs, String instructionId) {
    final iid = instructionId.trim();
    if (iid.isEmpty) return null;
    RemoteJobDoc? found;
    for (final j in jobs) {
      if (j.instructionId.trim() == iid) {
        if (found == null ||
            (j.updatedAt != null &&
                (found.updatedAt == null ||
                    j.updatedAt!.isAfter(found.updatedAt!)))) {
          found = j;
        }
      }
    }
    return found;
  }

  static RemoteCommandDoc? findStartJob(List<RemoteCommandDoc> commands) {
    for (final c in commands) {
      if (c.isStartJob && c.commandId.trim().isNotEmpty) return c;
    }
    return null;
  }

  static bool isInProgress(String status) {
    switch (status) {
      case 'claimed':
      case 'running':
      case 'waiting_approval':
      case 'revision_requested':
      case 'reworking':
        return true;
      default:
        return false;
    }
  }

  static bool isCompleted(String status) =>
      status == 'completed' || status == 'approved';

  static RemoteDeliveryCase classify({
    RemoteJobDoc? job,
    RemoteCommandDoc? start,
  }) {
    if (job == null) return RemoteDeliveryCase.createAll;
    if (start != null) {
      if (isCompleted(job.status)) return RemoteDeliveryCase.blockedCompleted;
      if (isInProgress(job.status)) return RemoteDeliveryCase.blockedInProgress;
      return RemoteDeliveryCase.reuse;
    }
    if (isCompleted(job.status)) return RemoteDeliveryCase.blockedCompleted;
    if (isInProgress(job.status)) return RemoteDeliveryCase.blockedInProgress;
    return RemoteDeliveryCase.repairCommand;
  }

  static bool wouldCreateJob(RemoteDeliveryCase c) =>
      c == RemoteDeliveryCase.createAll;

  static bool wouldCreateCommand(RemoteDeliveryCase c) =>
      c == RemoteDeliveryCase.createAll ||
      c == RemoteDeliveryCase.repairCommand;

  static Map<String, dynamic> attachPilotAiExecution(
    Map<String, dynamic> json,
  ) {
    final out = Map<String, dynamic>.from(json);
    out['aiExecution'] = AiExecutionPolicy.pilotCodexStage1.toJson();
    return withCanonicalChecksumFields(out);
  }

  static bool shouldAttachPilot({
    required bool toggleOn,
    required WorkInstruction? instruction,
    bool repairOrphan = false,
  }) {
    if (instruction?.aiExecution?.enabled == true) return false;
    if (repairOrphan) return true;
    return toggleOn;
  }

  static bool isOrphanProduction(String instructionId) =>
      instructionId.trim() == orphanProductionInstructionId;

  static bool isProtectedSkip(String instructionId) =>
      PlanUserFacingStatus.isProtectedInstruction(instructionId);

  static RemoteAgentDoc? pickTargetAgent(
    List<RemoteAgentDoc> agents, {
    String? preferredId,
    DateTime? now,
  }) {
    final online = agents
        .where((a) => a.enabled && a.isOnline(now: now))
        .toList();
    if (online.isEmpty) return null;
    final pref = (preferredId ?? '').trim();
    if (pref.isNotEmpty) {
      for (final a in online) {
        if (a.agentId == pref) return a;
      }
    }
    for (final a in online) {
      if (a.deviceName.toUpperCase().contains('JT-JEON')) return a;
    }
    online.sort((a, b) => a.deviceName.compareTo(b.deviceName));
    return online.first;
  }

  static String userMessageForError(String? code) {
    switch (code) {
      case 'agent_offline':
      case 'agent_missing':
        return '전송 실패. 연결된 노트북 Agent가 없습니다. 다시 시도가 필요합니다.';
      case 'auth':
        return '전송 실패. 로그인을 확인한 뒤 다시 시도해 주세요.';
      case 'network':
        return '통신 상태 확인이 필요합니다. 네트워크를 확인한 뒤 다시 시도해 주세요.';
      case 'timeout':
        return '전달 확인이 지연되고 있습니다. 상태를 먼저 확인해 주세요.';
      case 'job_failed':
        return '전송 실패. 작업 생성에 실패했습니다. 다시 시도가 필요합니다.';
      case 'start_failed':
        return '전송 실패. 작업 시작 명령 생성에 실패했습니다. 다시 시도가 필요합니다.';
      default:
        return '전송 실패. 다시 시도가 필요합니다.';
    }
  }

  static BusinessPlanDocument markDelivered({
    required BusinessPlanDocument plan,
    required RemoteDeliveryResult result,
    WorkInstruction? instruction,
    DateTime? now,
  }) {
    final ts = (now ?? DateTime.now().toUtc()).toIso8601String();
    return plan.copyWith(
      status: PlanningStatus.transferred,
      updatedAt: ts,
      instruction: instruction ?? plan.instruction,
      lastTransferAt: ts,
      lastTransferMode: PlanProgressStatus.remoteMode,
      lastRemoteJobId: result.jobId,
      lastRemoteCommandId: result.commandId,
      lastRemoteAgentId: result.agentId,
      clearDeliveryError: true,
    );
  }

  static BusinessPlanDocument markFailed({
    required BusinessPlanDocument plan,
    required RemoteDeliveryResult result,
    DateTime? now,
  }) {
    final ts = (now ?? DateTime.now().toUtc()).toIso8601String();
    return plan.copyWith(
      status: PlanningStatus.transferFailed,
      updatedAt: ts,
      lastDeliveryErrorCode: result.errorCode ?? 'deliver_failed',
      lastDeliveryErrorLabel: result.userMessage,
    );
  }
}

class WorkInstructionRemoteDeliveryService {
  WorkInstructionRemoteDeliveryService({
    RemoteControlApi? api,
    RemoteAgentRepository? agents,
    this.jobsProvider,
    this.commandsProvider,
    this.agentsProvider,
  }) : _api = api ?? RemoteControlApi(),
       _agents = agents ?? RemoteAgentRepository();

  final RemoteControlApi _api;
  final RemoteAgentRepository _agents;
  final Future<List<RemoteJobDoc>> Function()? jobsProvider;
  final Future<List<RemoteCommandDoc>> Function(String jobId)? commandsProvider;
  final Future<List<RemoteAgentDoc>> Function()? agentsProvider;

  Future<List<RemoteJobDoc>> _jobs(String? ownerUid) async {
    if (jobsProvider != null) return jobsProvider!();
    return _agents.watchJobs(ownerUid: ownerUid).first;
  }

  Future<List<RemoteCommandDoc>> _commands(String jobId) async {
    if (commandsProvider != null) return commandsProvider!(jobId);
    return _agents.listCommands(jobId);
  }

  Future<List<RemoteAgentDoc>> _agentList(String? ownerUid) async {
    if (agentsProvider != null) return agentsProvider!();
    return _agents.watchAgents(ownerUid: ownerUid).first;
  }

  /// Job + START_JOB 존재 여부만 확인 (쓰기 없음).
  Future<RemoteDeliveryResult?> reconcileExisting({
    required String instructionId,
    String? ownerUid,
  }) async {
    final iid = instructionId.trim();
    if (iid.isEmpty) return null;
    final jobs = await _jobs(ownerUid);
    final job = WorkInstructionRemoteDelivery.findJob(jobs, iid);
    if (job == null) return null;
    final start = WorkInstructionRemoteDelivery.findStartJob(
      await _commands(job.jobId),
    );
    if (start == null) return null;
    return RemoteDeliveryResult(
      delivered: true,
      jobId: job.jobId,
      commandId: start.commandId,
      agentId: job.assignedAgentId,
      outcome: 'already_transferred',
    );
  }

  Future<RemoteDeliveryResult> deliver({
    required String instructionId,
    required String title,
    required String type,
    required Map<String, dynamic> payload,
    int totalStages = 18,
    String? ownerUid,
    String? preferredAgentId,
  }) async {
    final iid = instructionId.trim();
    final map = Map<String, dynamic>.from(payload);
    map['instructionId'] = iid;

    // schema 1.1 commercial brief/profile gate (Work inbox parity). No fake defaults.
    if (CommercialWorkInstructionPreflight.isSchema11(map)) {
      final commercial = CommercialWorkInstructionPreflight.evaluate(map);
      if (!commercial.ok) {
        final first = commercial.errors.isNotEmpty
            ? commercial.errors.first
            : null;
        return RemoteDeliveryResult.failed(
          userMessage:
              first?.userMessageKo ??
              '상용 품질 계약(brief/profile)이 불완전하여 전송할 수 없습니다.',
          errorCode: first?.code ?? 'commercial_preflight_blocked',
          payload: map,
        );
      }
    }

    if (WorkInstructionRemoteDelivery.isProtectedSkip(iid)) {
      final jobs = await _jobs(ownerUid);
      final existing = WorkInstructionRemoteDelivery.findJob(jobs, iid);
      if (existing != null) {
        final cmds = await _commands(existing.jobId);
        final start = WorkInstructionRemoteDelivery.findStartJob(cmds);
        if (start != null) {
          return RemoteDeliveryResult(
            delivered: true,
            jobId: existing.jobId,
            commandId: start.commandId,
            agentId: existing.assignedAgentId,
            outcome: 'reused',
            payload: map,
          );
        }
      }
      return RemoteDeliveryResult.failed(
        userMessage: '이 작업은 변경하지 않습니다.',
        errorCode: 'protected_instruction',
        payload: map,
      );
    }

    final reconciled = await reconcileExisting(
      instructionId: iid,
      ownerUid: ownerUid,
    );
    if (reconciled != null) {
      return reconciled.copyWith(payload: map);
    }

    final agents = await _agentList(ownerUid);
    final agent = WorkInstructionRemoteDelivery.pickTargetAgent(
      agents,
      preferredId: preferredAgentId,
    );
    if (agent == null) {
      return RemoteDeliveryResult.failed(
        userMessage: WorkInstructionRemoteDelivery.userMessageForError(
          'agent_offline',
        ),
        errorCode: agents.isEmpty ? 'agent_missing' : 'agent_offline',
        payload: map,
      );
    }

    final jobs = await _jobs(ownerUid);
    var job = WorkInstructionRemoteDelivery.findJob(jobs, iid);
    RemoteCommandDoc? start;
    if (job != null) {
      start = WorkInstructionRemoteDelivery.findStartJob(
        await _commands(job.jobId),
      );
    }
    final classified = WorkInstructionRemoteDelivery.classify(
      job: job,
      start: start,
    );

    if (classified == RemoteDeliveryCase.reuse ||
        classified == RemoteDeliveryCase.blockedInProgress ||
        classified == RemoteDeliveryCase.blockedCompleted) {
      return RemoteDeliveryResult(
        delivered: start != null && job != null,
        jobId: job?.jobId ?? '',
        commandId: start?.commandId ?? '',
        agentId: job?.assignedAgentId ?? agent.agentId,
        outcome: classified == RemoteDeliveryCase.blockedCompleted
            ? 'reused_completed'
            : classified == RemoteDeliveryCase.blockedInProgress
            ? 'reused_in_progress'
            : 'reused',
        payload: map,
      );
    }

    String jobId = job?.jobId ?? '';
    if (classified == RemoteDeliveryCase.createAll) {
      try {
        final created = await _api.deliverInstruction(
          instructionId: iid,
          type: type,
          title: title,
          assignedAgentId: agent.agentId,
          totalStages: totalStages,
          payload: map,
        );
        return RemoteDeliveryResult(
          delivered: true,
          jobId: created.jobId,
          commandId: created.commandId,
          agentId: created.agentId,
          outcome: created.outcome,
          payload: map,
        );
      } on RemoteControlApiException catch (e) {
        return _fallbackCreateStart(
          iid: iid,
          title: title,
          type: type,
          totalStages: totalStages,
          agent: agent,
          map: map,
          code: e.code,
          userMessage: e.userMessage,
        );
      } catch (_) {
        return _fallbackCreateStart(
          iid: iid,
          title: title,
          type: type,
          totalStages: totalStages,
          agent: agent,
          map: map,
        );
      }
    }

    // B. repair command
    try {
      final started = await _api.startJob(
        jobId: jobId,
        payload: map,
        idempotencyKey: WorkInstructionRemoteDelivery.startIdempotencyKey(iid),
      );
      if (started.commandId.trim().isEmpty) {
        return RemoteDeliveryResult.failed(
          userMessage: WorkInstructionRemoteDelivery.userMessageForError(
            'start_failed',
          ),
          errorCode: 'start_failed',
          jobId: jobId,
          agentId: agent.agentId,
          payload: map,
        );
      }
      return RemoteDeliveryResult(
        delivered: true,
        jobId: started.jobId,
        commandId: started.commandId,
        agentId: agent.agentId,
        outcome: 'command_repaired',
        payload: map,
      );
    } on RemoteControlApiException catch (e) {
      return RemoteDeliveryResult.failed(
        userMessage: WorkInstructionRemoteDelivery.userMessageForError(
          e.code ?? 'start_failed',
        ),
        errorCode: e.code ?? 'start_failed',
        jobId: jobId,
        agentId: agent.agentId,
        payload: map,
      );
    }
  }

  Future<RemoteDeliveryResult> _fallbackCreateStart({
    required String iid,
    required String title,
    required String type,
    required int totalStages,
    required RemoteAgentDoc agent,
    required Map<String, dynamic> map,
    String? code,
    String? userMessage,
  }) async {
    if (code == 'agent_offline' || code == 'agent_missing') {
      return RemoteDeliveryResult.failed(
        userMessage: WorkInstructionRemoteDelivery.userMessageForError(code),
        errorCode: code,
        agentId: agent.agentId,
        payload: map,
      );
    }
    String jobId;
    try {
      jobId = await _api.createJob(
        type: type,
        title: title,
        assignedAgentId: agent.agentId,
        totalStages: totalStages,
        instructionId: iid,
      );
    } on RemoteControlApiException catch (e) {
      return RemoteDeliveryResult.failed(
        userMessage:
            userMessage ??
            WorkInstructionRemoteDelivery.userMessageForError(
              e.code ?? 'job_failed',
            ),
        errorCode: e.code ?? 'job_failed',
        agentId: agent.agentId,
        payload: map,
      );
    }
    if (jobId.isEmpty) {
      return RemoteDeliveryResult.failed(
        userMessage: WorkInstructionRemoteDelivery.userMessageForError(
          jobId.isEmpty ? 'job_failed' : 'start_failed',
        ),
        errorCode: jobId.isEmpty ? 'job_failed' : 'start_failed',
        jobId: jobId,
        agentId: agent.agentId,
        payload: map,
      );
    }
    try {
      final started = await _api.startJob(
        jobId: jobId,
        payload: map,
        idempotencyKey: WorkInstructionRemoteDelivery.startIdempotencyKey(iid),
      );
      if (started.commandId.trim().isEmpty) {
        return RemoteDeliveryResult.failed(
          userMessage: WorkInstructionRemoteDelivery.userMessageForError(
            'start_failed',
          ),
          errorCode: 'start_failed',
          jobId: jobId,
          agentId: agent.agentId,
          payload: map,
        );
      }
      return RemoteDeliveryResult(
        delivered: true,
        jobId: started.jobId,
        commandId: started.commandId,
        agentId: agent.agentId,
        outcome: 'created',
        payload: map,
      );
    } on RemoteControlApiException catch (e) {
      return RemoteDeliveryResult.failed(
        userMessage: WorkInstructionRemoteDelivery.userMessageForError(
          e.code ?? 'start_failed',
        ),
        errorCode: e.code ?? 'start_failed',
        jobId: jobId,
        agentId: agent.agentId,
        payload: map,
      );
    }
  }
}

extension RemoteDeliveryResultCopy on RemoteDeliveryResult {
  RemoteDeliveryResult copyWith({Map<String, dynamic>? payload}) {
    return RemoteDeliveryResult(
      delivered: delivered,
      jobId: jobId,
      commandId: commandId,
      agentId: agentId,
      outcome: outcome,
      errorCode: errorCode,
      userMessage: userMessage,
      payload: payload ?? this.payload,
    );
  }
}
