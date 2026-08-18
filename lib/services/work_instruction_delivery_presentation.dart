import '../models/business_planning.dart';
import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import '../services/instruction_contract_validator.dart';
import '../services/ops_health_check.dart';
import '../services/work_instruction_remote_delivery.dart';
import '../services/work_instruction_workshop_presentation.dart';
import '../services/transferred_work_reconciliation.dart';

/// STEP 7 — Agent 전달 UI 상태 (presentation only).
enum DeliveryButtonState { ready, sending, sent, failed, blocked }

enum WorkshopHandoffPhase { none, preparing, registered }

enum DeliveryFailureKind {
  agentOffline,
  heartbeatStale,
  relayNetwork,
  timeout,
  validation,
  agentBusy,
  auth,
  alreadyTransferred,
  unknown,
}

enum AgentConnectivity { ready, stale, offline, noAgent }

enum DeliveryDiagnosticAction {
  recheckStatus,
  agentLinkTest,
  relayTest,
  deliveryPathTest,
  validationReview,
  openWorkshop,
  copyGptMemo,
  openRemoteControl,
}

class AgentDeliveryStatusView {
  const AgentDeliveryStatusView({
    required this.connectivity,
    required this.headline,
    required this.statusLine,
    required this.heartbeatLine,
    required this.readinessLine,
    required this.dotColorKind,
  });

  final AgentConnectivity connectivity;
  final String headline;
  final String statusLine;
  final String heartbeatLine;
  final String readinessLine;
  final String dotColorKind;

  bool get canAttemptSend => connectivity == AgentConnectivity.ready;
}

class DeliveryFailureView {
  const DeliveryFailureView({
    required this.kind,
    required this.title,
    required this.body,
    required this.guidance,
    required this.primaryAction,
    this.secondaryAction,
    this.allowRetry = false,
  });

  final DeliveryFailureKind kind;
  final String title;
  final String body;
  final String guidance;
  final DeliveryDiagnosticAction primaryAction;
  final DeliveryDiagnosticAction? secondaryAction;
  final bool allowRetry;
}

class DeliveryStep7View {
  const DeliveryStep7View({
    required this.agentStatus,
    required this.buttonState,
    required this.buttonLabel,
    required this.buttonEnabled,
    required this.showSuccessPanel,
    required this.failure,
    required this.validationLines,
    this.workshopPhase = WorkshopHandoffPhase.none,
    this.remoteDeliveryVerified = false,
    this.remoteEvidencePending = false,
  });

  final AgentDeliveryStatusView agentStatus;
  final DeliveryButtonState buttonState;
  final String buttonLabel;
  final bool buttonEnabled;
  final bool showSuccessPanel;
  final DeliveryFailureView? failure;
  final List<String> validationLines;
  final WorkshopHandoffPhase workshopPhase;
  final bool remoteDeliveryVerified;
  final bool remoteEvidencePending;
}

class WorkInstructionDeliveryPresentation {
  WorkInstructionDeliveryPresentation._();

  static const staleHeartbeatMinutes = 5;

  static AgentDeliveryStatusView agentStatus(
    List<RemoteAgentDoc> agents, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final connectivity = _connectivity(agents, now: clock);
    final agent = WorkInstructionRemoteDelivery.pickTargetAgent(
      agents,
      now: clock,
    );

    switch (connectivity) {
      case AgentConnectivity.ready:
        final stateKo = _userAgentState(agent!);
        return AgentDeliveryStatusView(
          connectivity: connectivity,
          headline: '소통24워크 Agent',
          statusLine: '● 온라인 · $stateKo',
          heartbeatLine:
              '최근 연결 ${formatRelativeKo(agent.lastHeartbeatAt, now: clock)}',
          readinessLine: '● 전달 가능',
          dotColorKind: 'green',
        );
      case AgentConnectivity.stale:
        final best = _bestHeartbeatAgent(agents);
        return AgentDeliveryStatusView(
          connectivity: connectivity,
          headline: '소통24워크 Agent',
          statusLine: '● 상태 확인 필요',
          heartbeatLine: best?.lastHeartbeatAt == null
              ? '최근 연결 기록 없음'
              : '최근 연결 ${formatRelativeKo(best!.lastHeartbeatAt, now: clock)}',
          readinessLine: 'Agent 상태 확인이 필요합니다.',
          dotColorKind: 'amber',
        );
      case AgentConnectivity.offline:
        return const AgentDeliveryStatusView(
          connectivity: AgentConnectivity.offline,
          headline: '소통24워크 Agent',
          statusLine: '● 연결 안 됨',
          heartbeatLine: '최근 연결 확인 불가',
          readinessLine: 'Agent에 연결할 수 없습니다.',
          dotColorKind: 'muted',
        );
      case AgentConnectivity.noAgent:
        return const AgentDeliveryStatusView(
          connectivity: AgentConnectivity.noAgent,
          headline: '소통24워크 Agent',
          statusLine: '● 연결 안 됨',
          heartbeatLine: '등록된 Agent 없음',
          readinessLine: 'Agent에 연결할 수 없습니다.',
          dotColorKind: 'muted',
        );
    }
  }

  static DeliveryStep7View resolve({
    required BusinessPlanDocument? plan,
    required ContractValidationResult? validation,
    required List<RemoteAgentDoc> agents,
    required bool transferBusy,
    RemoteDeliveryResult? lastResult,
    DateTime? now,
    bool operationalProjectReady = false,
    RemoteOperationalEvidence? remoteEvidence,
  }) {
    final agentView = agentStatus(agents, now: now);
    final validationLines = validation == null
        ? const <String>[]
        : WorkInstructionWorkshopPresentation.validationProblemLines(
            validation,
          );

    if (plan?.wasTransferred == true) {
      final evidenceLoaded = remoteEvidence?.remoteLoaded == true;
      final remoteVerified =
          evidenceLoaded &&
          TransferredWorkReconciliation.hasRemoteDeliveryEvidence(
            plan!,
            remoteEvidence!,
          );

      if (evidenceLoaded && !remoteVerified) {
        return DeliveryStep7View(
          agentStatus: agentView,
          buttonState: DeliveryButtonState.failed,
          buttonLabel: '상태 재확인',
          buttonEnabled: true,
          showSuccessPanel: false,
          failure: const DeliveryFailureView(
            kind: DeliveryFailureKind.unknown,
            title: '원격 작업 기록 없음',
            body: '로컬에는 전송 완료로 저장되어 있으나 서버에 작업이 없습니다.',
            guidance: '백엔드가 정리된 상태라면 새 작업지시를 생성·전송하세요.',
            primaryAction: DeliveryDiagnosticAction.recheckStatus,
            allowRetry: false,
          ),
          validationLines: validationLines,
        );
      }

      if (!evidenceLoaded) {
        return DeliveryStep7View(
          agentStatus: agentView,
          buttonState: DeliveryButtonState.sending,
          buttonLabel: '원격 상태 확인 중…',
          buttonEnabled: false,
          showSuccessPanel: false,
          failure: null,
          validationLines: validationLines,
          remoteEvidencePending: true,
        );
      }

      return DeliveryStep7View(
        agentStatus: agentView,
        buttonState: DeliveryButtonState.sent,
        buttonLabel: '✓ 전달 완료',
        buttonEnabled: false,
        showSuccessPanel: true,
        failure: null,
        validationLines: validationLines,
        workshopPhase: operationalProjectReady
            ? WorkshopHandoffPhase.registered
            : WorkshopHandoffPhase.preparing,
        remoteDeliveryVerified: remoteVerified,
      );
    }

    if (transferBusy) {
      return DeliveryStep7View(
        agentStatus: agentView,
        buttonState: DeliveryButtonState.sending,
        buttonLabel: '전달 중…',
        buttonEnabled: false,
        showSuccessPanel: false,
        failure: null,
        validationLines: validationLines,
      );
    }

    if (validation != null && !validation.canTransfer) {
      return DeliveryStep7View(
        agentStatus: agentView,
        buttonState: DeliveryButtonState.blocked,
        buttonLabel:
            WorkInstructionWorkshopPresentation.blockedTransferButtonLabel(),
        buttonEnabled: false,
        showSuccessPanel: false,
        failure: failureView(
          result: RemoteDeliveryResult.failed(
            userMessage: 'validation',
            errorCode: 'validation',
          ),
          validation: validation,
          agentStatus: agentView,
        ),
        validationLines: validationLines,
      );
    }

    if (lastResult != null && !lastResult.delivered) {
      final failure = failureView(
        result: lastResult,
        validation: validation,
        agentStatus: agentView,
      );
      return DeliveryStep7View(
        agentStatus: agentView,
        buttonState: DeliveryButtonState.failed,
        buttonLabel: failure.allowRetry ? '다시 전달' : '상태 재확인',
        buttonEnabled: failure.allowRetry && agentView.canAttemptSend,
        showSuccessPanel: false,
        failure: failure,
        validationLines: validationLines,
      );
    }

    if (!agentView.canAttemptSend) {
      return DeliveryStep7View(
        agentStatus: agentView,
        buttonState: DeliveryButtonState.ready,
        buttonLabel: '소통24워크 Agent로 전달',
        buttonEnabled: false,
        showSuccessPanel: false,
        failure: failureView(
          result: RemoteDeliveryResult.failed(
            userMessage: agentView.readinessLine,
            errorCode: agentView.connectivity == AgentConnectivity.stale
                ? 'heartbeat_stale'
                : 'agent_offline',
          ),
          validation: validation,
          agentStatus: agentView,
        ),
        validationLines: validationLines,
      );
    }

    return DeliveryStep7View(
      agentStatus: agentView,
      buttonState: DeliveryButtonState.ready,
      buttonLabel: '소통24워크 Agent로 전달',
      buttonEnabled: true,
      showSuccessPanel: false,
      failure: null,
      validationLines: validationLines,
    );
  }

  static DeliveryFailureView failureView({
    required RemoteDeliveryResult result,
    ContractValidationResult? validation,
    AgentDeliveryStatusView? agentStatus,
  }) {
    if (validation != null && !validation.canTransfer) {
      return DeliveryFailureView(
        kind: DeliveryFailureKind.validation,
        title: '작업지시를 보내기 전에 확인이 필요합니다.',
        body: WorkInstructionWorkshopPresentation.validationHeadline(
          validation,
        ),
        guidance: '아래 항목을 확인한 뒤 다시 시도해 주세요.',
        primaryAction: DeliveryDiagnosticAction.validationReview,
        allowRetry: false,
      );
    }

    final code = (result.errorCode ?? '').trim();
    switch (code) {
      case 'validation':
        return DeliveryFailureView(
          kind: DeliveryFailureKind.validation,
          title: '작업지시를 보내기 전에 확인이 필요합니다.',
          body: result.userMessage,
          guidance: '문제 항목을 확인하고 수정해 주세요.',
          primaryAction: DeliveryDiagnosticAction.validationReview,
        );
      case 'agent_offline':
      case 'agent_missing':
        return DeliveryFailureView(
          kind: DeliveryFailureKind.agentOffline,
          title: '전달 실패',
          body: '소통24워크 Agent에 연결할 수 없습니다.',
          guidance: '노트북이 켜져 있고 Agent가 실행 중인지 확인해 주세요.',
          primaryAction: DeliveryDiagnosticAction.recheckStatus,
          secondaryAction: DeliveryDiagnosticAction.agentLinkTest,
        );
      case 'heartbeat_stale':
        return DeliveryFailureView(
          kind: DeliveryFailureKind.heartbeatStale,
          title: '전달 실패',
          body: 'Agent의 최근 연결 상태가 오래되었습니다.',
          guidance: '상태를 다시 확인한 뒤 시도해 주세요.',
          primaryAction: DeliveryDiagnosticAction.recheckStatus,
          secondaryAction: DeliveryDiagnosticAction.agentLinkTest,
        );
      case 'network':
        return DeliveryFailureView(
          kind: DeliveryFailureKind.relayNetwork,
          title: '전달 실패',
          body: '통신 상태 확인이 필요합니다.',
          guidance: 'Agent는 보이지만 Relay 응답이 정상적이지 않습니다.',
          primaryAction: DeliveryDiagnosticAction.relayTest,
          secondaryAction: DeliveryDiagnosticAction.recheckStatus,
        );
      case 'timeout':
        return DeliveryFailureView(
          kind: DeliveryFailureKind.timeout,
          title: '전달 확인이 지연되고 있습니다.',
          body: '중복 전송을 막기 위해 먼저 상태를 확인합니다.',
          guidance: '이미 전송되었는지 확인한 뒤에만 다시 시도할 수 있습니다.',
          primaryAction: DeliveryDiagnosticAction.recheckStatus,
          allowRetry: false,
        );
      case 'auth':
        return DeliveryFailureView(
          kind: DeliveryFailureKind.auth,
          title: '전달 실패',
          body: '로그인 상태를 확인해 주세요.',
          guidance: '다시 로그인한 뒤 시도해 주세요.',
          primaryAction: DeliveryDiagnosticAction.recheckStatus,
        );
      case 'already_transferred':
        return DeliveryFailureView(
          kind: DeliveryFailureKind.alreadyTransferred,
          title: '이미 전달된 작업지시입니다.',
          body: 'Agent가 작업지시를 이미 수신했습니다.',
          guidance: 'AI 제작공정에서 진행 상황을 확인하세요.',
          primaryAction: DeliveryDiagnosticAction.openWorkshop,
          allowRetry: false,
        );
      default:
        if (agentStatus != null && !agentStatus.canAttemptSend) {
          return failureView(
            result: RemoteDeliveryResult.failed(
              userMessage: agentStatus.readinessLine,
              errorCode: agentStatus.connectivity == AgentConnectivity.stale
                  ? 'heartbeat_stale'
                  : 'agent_offline',
            ),
            agentStatus: agentStatus,
          );
        }
        return DeliveryFailureView(
          kind: DeliveryFailureKind.unknown,
          title: '전달 실패',
          body: result.userMessage.isNotEmpty
              ? result.userMessage
              : '작업지시 전송에 실패했습니다.',
          guidance: '상태를 다시 확인하거나 진단 도구를 사용해 주세요.',
          primaryAction: DeliveryDiagnosticAction.recheckStatus,
          secondaryAction: DeliveryDiagnosticAction.deliveryPathTest,
          allowRetry: code == 'job_failed' || code == 'start_failed',
        );
    }
  }

  static String actionLabel(DeliveryDiagnosticAction action) {
    switch (action) {
      case DeliveryDiagnosticAction.recheckStatus:
        return '상태 재확인';
      case DeliveryDiagnosticAction.agentLinkTest:
        return 'Agent 연결 테스트';
      case DeliveryDiagnosticAction.relayTest:
        return 'Relay 통신 테스트';
      case DeliveryDiagnosticAction.deliveryPathTest:
        return '작업 전송 경로 테스트';
      case DeliveryDiagnosticAction.validationReview:
        return '문제 항목 확인';
      case DeliveryDiagnosticAction.openWorkshop:
        return 'AI 제작공정에서 보기';
      case DeliveryDiagnosticAction.copyGptMemo:
        return 'GPT에 알려줄 문제 해결 메모 복사';
      case DeliveryDiagnosticAction.openRemoteControl:
        return '노트북 원격관제에서 확인';
    }
  }

  static String transferGptMemo({
    required DeliveryFailureView? failure,
    required AgentDeliveryStatusView agentStatus,
    required BusinessPlanDocument? plan,
    required ContractValidationResult? validation,
    RemoteDeliveryResult? lastResult,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final buf = StringBuffer();
    buf.writeln('SotongWareControl — 작업지시 전송 문제 해결 메모');
    buf.writeln('생성 시각: ${clock.toUtc().toIso8601String()}');
    buf.writeln();
    buf.writeln('## 실패 유형');
    buf.writeln('- ${failure?.kind.name ?? '없음'}');
    if (failure != null) {
      buf.writeln('- ${failure.title}');
      buf.writeln('- ${failure.body}');
    }
    buf.writeln();
    buf.writeln('## Agent 상태');
    buf.writeln('- ${agentStatus.statusLine}');
    buf.writeln('- ${agentStatus.heartbeatLine}');
    buf.writeln('- ${agentStatus.readinessLine}');
    buf.writeln();
    buf.writeln('## 작업지시');
    if (plan != null) {
      buf.writeln('- 제목: ${plan.input.topic}');
      buf.writeln('- instructionId: ${plan.stableInstructionId}');
      buf.writeln('- wasTransferred: ${plan.wasTransferred}');
      if ((plan.lastRemoteJobId ?? '').isNotEmpty) {
        buf.writeln('- jobId: ${plan.lastRemoteJobId}');
      }
      if ((plan.lastRemoteCommandId ?? '').isNotEmpty) {
        buf.writeln('- commandId: ${plan.lastRemoteCommandId}');
      }
    }
    buf.writeln();
    if (validation != null) {
      buf.writeln('## 검증');
      for (final line
          in WorkInstructionWorkshopPresentation.validationProblemLines(
            validation,
          )) {
        buf.writeln(line);
      }
      buf.writeln();
    }
    if (lastResult != null) {
      buf.writeln('## 마지막 전송 시도');
      buf.writeln('- delivered: ${lastResult.delivered}');
      buf.writeln('- outcome: ${lastResult.outcome}');
      if ((lastResult.errorCode ?? '').isNotEmpty) {
        buf.writeln('- error: ${lastResult.errorCode}');
      }
      if (lastResult.userMessage.isNotEmpty) {
        buf.writeln('- message: ${lastResult.userMessage}');
      }
      buf.writeln();
    }
    buf.writeln('## 다음 확인 포인트');
    buf.writeln('- 노트북 Agent 실행 및 heartbeat');
    buf.writeln('- Relay / Functions 응답');
    buf.writeln('- 작업지시 validation 항목');
    buf.writeln('- 중복 job/command 생성 여부');
    return buf.toString();
  }

  static OpsHealthReport opsReportForMemo(
    List<RemoteAgentDoc> agents,
    List<Sotong24RemoteProject> workshops, {
    DateTime? now,
  }) {
    return OpsHealthCheck.evaluate(
      agents: agents,
      workshops: workshops,
      now: now,
    );
  }

  static AgentConnectivity _connectivity(
    List<RemoteAgentDoc> agents, {
    required DateTime now,
  }) {
    final enabled = agents.where((a) => a.enabled).toList();
    if (enabled.isEmpty) return AgentConnectivity.noAgent;
    if (WorkInstructionRemoteDelivery.pickTargetAgent(enabled, now: now) !=
        null) {
      return AgentConnectivity.ready;
    }
    final best = _bestHeartbeatAgent(enabled);
    if (best?.lastHeartbeatAt == null) return AgentConnectivity.offline;
    final age = now.difference(best!.lastHeartbeatAt!.toUtc());
    if (age.inMinutes < staleHeartbeatMinutes) {
      return AgentConnectivity.stale;
    }
    return AgentConnectivity.offline;
  }

  static RemoteAgentDoc? _bestHeartbeatAgent(List<RemoteAgentDoc> agents) {
    RemoteAgentDoc? best;
    for (final a in agents) {
      if (!a.enabled) continue;
      final hb = a.lastHeartbeatAt;
      if (hb == null) continue;
      if (best == null ||
          hb.isAfter(
            best.lastHeartbeatAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          )) {
        best = a;
      }
    }
    return best;
  }

  static String _userAgentState(RemoteAgentDoc agent) {
    switch (agent.state) {
      case 'idle':
      case 'starting':
      case 'receiving_job':
        return '대기';
      case 'running':
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
}
