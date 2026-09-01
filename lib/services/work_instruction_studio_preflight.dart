import '../models/business_planning.dart';
import '../models/remote_agent_models.dart';
import '../services/codex_usage_presentation.dart';
import '../services/cursor_usage_presentation.dart';
import '../services/instruction_contract_validator.dart';
import '../services/work_instruction_delivery_presentation.dart';

/// 작업지시서 제작소 — 제작 시작 전 사전점검(실제 telemetry만 사용, 가짜 수치 금지).
class WorkInstructionStudioPreflight {
  WorkInstructionStudioPreflight._();

  static StudioPreflightReport evaluate({
    required BusinessPlanInput input,
    WorkInstruction? instruction,
    required List<RemoteAgentDoc> agents,
    ContractValidationResult? contractValidation,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final checks = <StudioPreflightCheck>[];

    checks.add(_requiredFieldsCheck(input));
    checks.add(_artifactCheck(input));
    if (instruction != null) {
      checks.add(_instructionCheck(instruction));
      if (contractValidation != null) {
        checks.add(_contractCheck(contractValidation));
      }
    } else {
      checks.add(
        const StudioPreflightCheck(
          id: 'instruction_missing',
          label: '작업지시서',
          status: StudioPreflightStatus.blocked,
          detail: '작업지시서가 아직 생성되지 않았습니다.',
        ),
      );
    }

    final agentView = WorkInstructionDeliveryPresentation.agentStatus(
      agents,
      now: clock,
    );
    checks.add(_agentCheck(agentView));

    final target = _pickAgent(agents, now: clock);
    checks.addAll(_workerChecks(target, clock));

    final blocked = checks.where(
      (c) => c.status == StudioPreflightStatus.blocked,
    );
    final warnings = checks.where(
      (c) => c.status == StudioPreflightStatus.warning,
    );

    return StudioPreflightReport(
      checks: checks,
      canStartProduction:
          blocked.isEmpty && agentView.canAttemptSend && instruction != null,
      summaryLine: blocked.isEmpty
          ? (warnings.isEmpty
                ? '제작 시작 준비가 완료되었습니다.'
                : '경고가 있습니다. 확인 후 시작할 수 있습니다.')
          : '시작할 수 없습니다. 차단 항목을 해결하세요.',
    );
  }

  static StudioPreflightCheck _requiredFieldsCheck(BusinessPlanInput input) {
    final missing = <String>[];
    if (input.topic.trim().isEmpty) missing.add('프로젝트명');
    if (input.customerProblem.trim().isEmpty) missing.add('핵심 요구사항');
    if (input.targetCustomer.trim().isEmpty) missing.add('대상 사용자');
    if (input.desiredOutcome.trim().isEmpty) missing.add('원하는 결과');
    if (missing.isNotEmpty) {
      return StudioPreflightCheck(
        id: 'required_fields',
        label: '필수 요구사항',
        status: StudioPreflightStatus.blocked,
        detail: '누락: ${missing.join(", ")}',
      );
    }
    return const StudioPreflightCheck(
      id: 'required_fields',
      label: '필수 요구사항',
      status: StudioPreflightStatus.ok,
      detail: '필수 항목이 입력되었습니다.',
    );
  }

  static StudioPreflightCheck _artifactCheck(BusinessPlanInput input) {
    final artifact = ArtifactType.normalize(input.resolvedArtifactType);
    if (artifact == ArtifactType.undecided) {
      return const StudioPreflightCheck(
        id: 'product_type',
        label: '제작 유형',
        status: StudioPreflightStatus.blocked,
        detail: '제작 유형이 선택되지 않았습니다.',
      );
    }
    if (artifact == ArtifactType.site || artifact == ArtifactType.contents) {
      return StudioPreflightCheck(
        id: 'product_type',
        label: '제작 유형',
        status: StudioPreflightStatus.warning,
        detail:
            '${ArtifactType.labelKo(artifact)}: 백엔드 canonical 18단계 계약이 ebook/app 대비 제한적일 수 있습니다.',
      );
    }
    return StudioPreflightCheck(
      id: 'product_type',
      label: '제작 유형',
      status: StudioPreflightStatus.ok,
      detail: ArtifactType.labelKo(artifact),
    );
  }

  static StudioPreflightCheck _instructionCheck(WorkInstruction wi) {
    if (wi.workflowSteps.length != 18) {
      return StudioPreflightCheck(
        id: 'workflow_steps',
        label: '18단계 계약',
        status: StudioPreflightStatus.blocked,
        detail: 'workflowSteps=${wi.workflowSteps.length} (18 필요)',
      );
    }
    return const StudioPreflightCheck(
      id: 'workflow_steps',
      label: '18단계 계약',
      status: StudioPreflightStatus.ok,
      detail: '18단계 workflow가 준비되었습니다.',
    );
  }

  static StudioPreflightCheck _contractCheck(
    ContractValidationResult validation,
  ) {
    if (!validation.canTransfer) {
      return StudioPreflightCheck(
        id: 'contract',
        label: 'Contract 검증',
        status: StudioPreflightStatus.blocked,
        detail: validation.issues.isNotEmpty
            ? validation.issues.first.reason
            : 'Contract BLOCKED',
      );
    }
    if (validation.level == ContractValidationLevel.warning) {
      return const StudioPreflightCheck(
        id: 'contract',
        label: 'Contract 검증',
        status: StudioPreflightStatus.warning,
        detail: '경고가 있습니다. 전달 전 확인이 필요합니다.',
      );
    }
    return const StudioPreflightCheck(
      id: 'contract',
      label: 'Contract 검증',
      status: StudioPreflightStatus.ok,
      detail: 'Contract VALID',
    );
  }

  static StudioPreflightCheck _agentCheck(AgentDeliveryStatusView agentView) {
    return switch (agentView.connectivity) {
      AgentConnectivity.ready => StudioPreflightCheck(
        id: 'agent_relay',
        label: 'Agent · Relay',
        status: StudioPreflightStatus.ok,
        detail: agentView.readinessLine,
      ),
      AgentConnectivity.stale => StudioPreflightCheck(
        id: 'agent_relay',
        label: 'Agent · Relay',
        status: StudioPreflightStatus.warning,
        detail: agentView.readinessLine,
      ),
      _ => StudioPreflightCheck(
        id: 'agent_relay',
        label: 'Agent · Relay',
        status: StudioPreflightStatus.blocked,
        detail: agentView.readinessLine,
      ),
    };
  }

  static List<StudioPreflightCheck> _workerChecks(
    RemoteAgentDoc? agent,
    DateTime now,
  ) {
    final codexView = CodexUsagePresentation.viewFor(agent, now: now);
    final codexCheck = StudioPreflightCheck(
      id: 'worker_codex',
      label: 'Codex',
      status: codexView == null || codexView.unavailable
          ? StudioPreflightStatus.warning
          : (codexView.quotaLabel == '한도 임박'
                ? StudioPreflightStatus.warning
                : StudioPreflightStatus.ok),
      detail: codexView == null || codexView.unavailable
          ? '사용량 조회 불가 — Agent telemetry 확인 필요'
          : codexView.displayText,
    );

    final cursorHeadline = CursorUsagePresentation.headline(agent);
    final cursorLines = CursorUsagePresentation.detailLines(agent);
    final cursorUnavailable = cursorHeadline == '확인 불가';
    final cursorCheck = StudioPreflightCheck(
      id: 'worker_cursor',
      label: 'Cursor',
      status: cursorUnavailable
          ? StudioPreflightStatus.warning
          : StudioPreflightStatus.ok,
      detail: cursorUnavailable
          ? cursorLines.join(' · ')
          : '$cursorHeadline · ${cursorLines.take(2).join(' · ')}',
    );

    return [codexCheck, cursorCheck];
  }

  static RemoteAgentDoc? _pickAgent(
    List<RemoteAgentDoc> agents, {
    DateTime? now,
  }) {
    if (agents.isEmpty) return null;
    final clock = now ?? DateTime.now().toUtc();
    final online = agents.where((a) => a.isOnline(now: clock)).toList();
    if (online.isEmpty) return null;
    online.sort((a, b) {
      final ah = a.lastHeartbeatAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bh = b.lastHeartbeatAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bh.compareTo(ah);
    });
    return online.first;
  }
}

enum StudioPreflightStatus { ok, warning, blocked }

class StudioPreflightCheck {
  const StudioPreflightCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detail,
  });

  final String id;
  final String label;
  final StudioPreflightStatus status;
  final String detail;
}

class StudioPreflightReport {
  const StudioPreflightReport({
    required this.checks,
    required this.canStartProduction,
    required this.summaryLine,
  });

  final List<StudioPreflightCheck> checks;
  final bool canStartProduction;
  final String summaryLine;
}
