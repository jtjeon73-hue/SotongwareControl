import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_planning.dart';
import '../models/planning_wizard_state.dart';
import '../models/remote_agent_models.dart';
import '../models/remote_e2e_sample.dart';
import 'business_planning_service.dart';
import 'planning_sentence_composer.dart';
import 'remote_control_api.dart';
import 'remote_work_instruction_mirror.dart';
import 'remote_work_instruction_source.dart';
import 'work_instruction_validator.dart';

/// 노트북 원격관제 — 샘플 WorkInstruction E2E (실제 contract 재사용).
class RemoteE2eSampleService {
  RemoteE2eSampleService({
    BusinessPlanningService? planning,
    PlanningSentenceComposer? composer,
    RemoteWorkInstructionMirrorService? mirror,
    RemoteWorkInstructionSource? instructionSource,
    WorkInstructionValidator? validator,
    this._prefs,
  }) : _planning = planning ?? BusinessPlanningService(),
       _composer = composer ?? const PlanningSentenceComposer(),
       _mirror = mirror ?? RemoteWorkInstructionMirrorService(),
       _instructionSource = instructionSource ?? RemoteWorkInstructionSource(),
       _validator = validator ?? WorkInstructionValidator();

  static const prefsInstructionId = 'remote_e2e_instruction_id';
  static const prefsJsonText = 'remote_e2e_json_text';
  static const prefsSentJobId = 'remote_e2e_sent_job_id';
  static const prefsSentAgentId = 'remote_e2e_sent_agent_id';
  static const prefsSentAgentName = 'remote_e2e_sent_agent_name';
  static const prefsSentAtIso = 'remote_e2e_sent_at_iso';

  final BusinessPlanningService _planning;
  final PlanningSentenceComposer _composer;
  final RemoteWorkInstructionMirrorService _mirror;
  final RemoteWorkInstructionSource _instructionSource;
  final WorkInstructionValidator _validator;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _storage() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String generateInstructionId({DateTime? now}) {
    final ms = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    return '${RemoteE2eSampleMarkers.instructionIdPrefix}$ms';
  }

  PlanningWizardState _wizardState() {
    return PlanningWizardState(
      mode: 'quick',
      step: 4,
      artifactType: ArtifactType.ebook,
      topic: RemoteE2eSampleMarkers.sampleTitle,
      customerProblem: '[TEST] E2E 원격제작 검증용 고객 문제',
      targetCustomer: '[TEST] E2E 테스트 검증자',
      desiredOutcome: '[TEST] 18단계 경량 산출물 생성 (실제 출시·결제·광고 금지)',
      sentencesManuallyEdited: true,
      artifactAnswers: const {
        'customerProblem': ['productize_unknown'],
        'targetCustomer': ['sidejob_40_60'],
        'desiredOutcome': ['ebook_first'],
        'salesDeploy': ['cheap_validate'],
      },
    );
  }

  /// 실제 `작업지시 제작소`와 동일한 WorkInstruction contract 생성.
  WorkInstruction buildSampleWorkInstruction({
    required String instructionId,
    DateTime? now,
  }) {
    final stamp = (now ?? DateTime.now()).toUtc();
    final input = _composer
        .toBusinessPlanInput(_wizardState())
        .copyWith(
          notes:
              '${RemoteE2eSampleMarkers.sampleDescription}\n'
              '[environment:test][isTest:true]',
        );
    final analysis = _planning.analyze(input);
    final planId = 'plan_${instructionId.replaceFirst('wi_', '')}';
    return _planning.buildInstruction(
      planId: planId,
      input: input,
      analysis: analysis,
      instructionId: instructionId,
      version: 1,
      now: stamp,
    );
  }

  ActiveWorkInstructionRef? refFromSession(RemoteE2eSampleSession session) {
    if (!session.isCreated) return null;
    return _instructionSource.parseJsonText(
      session.jsonText,
      artifactHint: ArtifactType.ebook,
    );
  }

  Future<RemoteE2eSampleSession> loadSession() async {
    final p = await _storage();
    return RemoteE2eSampleSession(
      instructionId: p.getString(prefsInstructionId) ?? '',
      jsonText: p.getString(prefsJsonText) ?? '',
      sentJobId: p.getString(prefsSentJobId) ?? '',
      sentAgentId: p.getString(prefsSentAgentId) ?? '',
      sentAgentName: p.getString(prefsSentAgentName) ?? '',
      sentAtIso: p.getString(prefsSentAtIso) ?? '',
    );
  }

  Future<void> _saveSession(RemoteE2eSampleSession session) async {
    final p = await _storage();
    await p.setString(prefsInstructionId, session.instructionId);
    await p.setString(prefsJsonText, session.jsonText);
    await p.setString(prefsSentJobId, session.sentJobId);
    await p.setString(prefsSentAgentId, session.sentAgentId);
    await p.setString(prefsSentAgentName, session.sentAgentName);
    await p.setString(prefsSentAtIso, session.sentAtIso);
  }

  Future<RemoteE2eSampleSession> createSample({
    String? ownerUid,
    DateTime? now,
  }) async {
    final instructionId = generateInstructionId(now: now);
    final stamp = (now ?? DateTime.now()).toUtc();
    final input = _composer
        .toBusinessPlanInput(_wizardState())
        .copyWith(
          notes:
              '${RemoteE2eSampleMarkers.sampleDescription}\n'
              '[environment:test][isTest:true]',
        );
    final analysis = _planning.analyze(input);
    final planId = 'plan_${instructionId.replaceFirst('wi_', '')}';
    final wi = _planning.buildInstruction(
      planId: planId,
      input: input,
      analysis: analysis,
      instructionId: instructionId,
      version: 1,
      now: stamp,
    );
    final validation = _validator.validate(input: input, instruction: wi);
    if (!validation.ok) {
      throw StateError(
        '샘플 WorkInstruction 검증 실패: '
        '${validation.issues.map((e) => e.reason).join(', ')}',
      );
    }
    final jsonText = jsonEncode(wi.toJson());
    final session = RemoteE2eSampleSession(
      instructionId: instructionId,
      jsonText: jsonText,
    );
    await _saveSession(session);
    await _mirror.upsertActive(
      ownerUid: ownerUid,
      artifactType: ArtifactType.ebook,
      instructionId: instructionId,
      jsonText: jsonText,
      version: 1,
      title: RemoteE2eSampleMarkers.sampleTitle,
      totalStages: wi.workflowSteps.length,
    );
    return session;
  }

  /// 기존 전송 기록 보존 + 새 instructionId 세션.
  Future<RemoteE2eSampleSession> resetSample({String? ownerUid}) async {
    return createSample(ownerUid: ownerUid);
  }

  /// Agent 카드·전송 버튼과 동일한 `RemoteAgentDoc.isOnline()` 기준.
  RemoteAgentDoc? pickOnlineAgent(List<RemoteAgentDoc> agents) {
    final online = agents.where((a) => a.enabled && a.isOnline()).toList();
    if (online.isEmpty) return null;
    final preferred = online
        .where((a) => a.deviceName.toUpperCase().contains('JT-JEON'))
        .toList();
    if (preferred.isNotEmpty) return preferred.first;
    return online.first;
  }

  RemoteJobDoc? findLinkedJob(
    List<RemoteJobDoc> jobs,
    RemoteE2eSampleSession session,
  ) {
    if (!session.isSent) return null;
    for (final j in jobs) {
      if (j.jobId == session.sentJobId) return j;
    }
    for (final j in jobs) {
      if (j.title.trim() == RemoteE2eSampleMarkers.sampleTitle) return j;
    }
    return null;
  }

  bool isDuplicateSend({
    required RemoteE2eSampleSession session,
    required List<RemoteJobDoc> jobs,
  }) {
    if (!session.isCreated) return false;
    if (session.isSent) return true;
    if (session.sentJobId.isNotEmpty) {
      for (final j in jobs) {
        if (j.jobId == session.sentJobId) return true;
      }
    }
    return false;
  }

  RemoteE2ePhase resolvePhase({
    required RemoteE2eSampleSession session,
    RemoteJobDoc? job,
    RemoteAgentDoc? agent,
    String? workshopStatus,
    int? workshopProgressPercent,
  }) {
    if (!session.isCreated) return RemoteE2ePhase.notCreated;
    if (!session.isSent && job == null) return RemoteE2ePhase.readyToSend;

    // AI 제작공정(sotong24work_projects) 상태가 있으면 Job보다 우선
    final ws = (workshopStatus ?? '').trim();
    if (ws == 'completed' || (workshopProgressPercent ?? 0) >= 100) {
      return RemoteE2ePhase.completed;
    }
    if (ws == 'awaiting_approval') {
      return RemoteE2ePhase.awaitingApproval;
    }
    if (ws == 'error') {
      return RemoteE2ePhase.error;
    }
    if (ws == 'revision' || ws == 'in_progress') {
      return RemoteE2ePhase.working;
    }

    final j = job;
    if (j == null) {
      return session.isSent ? RemoteE2ePhase.sent : RemoteE2ePhase.readyToSend;
    }

    switch (j.status) {
      case 'failed':
      case 'cancelled':
        return RemoteE2ePhase.error;
      case 'completed':
        return RemoteE2ePhase.completed;
      case 'waiting_approval':
      case 'revision_requested':
        return RemoteE2ePhase.awaitingApproval;
      case 'running':
      case 'reworking':
      case 'claimed':
        // Job status가 claimed에 머물러도 progress로 단계 반영
        if (j.totalStages > 0 && j.progress >= j.totalStages) {
          return RemoteE2ePhase.completed;
        }
        if (j.progress > 0) {
          return RemoteE2ePhase.working;
        }
        if (j.status == 'claimed' && (agent?.state == 'receiving_job')) {
          return RemoteE2ePhase.received;
        }
        return j.status == 'claimed'
            ? RemoteE2ePhase.received
            : RemoteE2ePhase.working;
      case 'queued':
        return RemoteE2ePhase.sent;
      default:
        if (j.totalStages > 0 && j.progress >= j.totalStages) {
          return RemoteE2ePhase.completed;
        }
        return RemoteE2ePhase.working;
    }
  }

  RemoteE2eSampleView buildView({
    required RemoteE2eSampleSession session,
    required List<RemoteAgentDoc> agents,
    required List<RemoteJobDoc> jobs,
    String? workshopStatus,
    int? workshopProgressPercent,
    int? workshopCurrentStage,
    int? workshopTotalStages,
  }) {
    final target = pickOnlineAgent(agents);
    final linked = findLinkedJob(jobs, session);
    final phase = resolvePhase(
      session: session,
      job: linked,
      agent: target,
      workshopStatus: workshopStatus,
      workshopProgressPercent: workshopProgressPercent,
    );
    final duplicate = isDuplicateSend(session: session, jobs: jobs);

    var canSend = session.isCreated && !session.isSent && !duplicate;
    var blocked = '';
    if (!session.isCreated) {
      blocked = '먼저 샘플 작업지시서를 생성하세요.';
      canSend = false;
    } else if (session.isSent || duplicate) {
      blocked = '이미 소통24워크 Agent에 전달된 작업입니다. 현재 상태를 확인해 주세요.';
      canSend = false;
    } else if (target == null) {
      blocked = 'Online Agent가 없습니다. 노트북 Agent 연결·Heartbeat를 확인하세요.';
      canSend = false;
    }

    final stage = workshopCurrentStage ?? linked?.progress ?? 0;
    final total = workshopTotalStages ?? linked?.totalStages ?? 18;

    var detail = '';
    if (phase == RemoteE2ePhase.completed) {
      detail = 'E2E 완료 · $total / $total 단계';
      if (linked != null) {
        detail += ' · Job ${linked.statusLabelKo}';
      }
    } else if (session.isSent) {
      detail = '전송 완료${stage > 0 ? ' · 현재 $stage / $total 단계' : ''}';
      if (linked != null) {
        detail += ' · Job ${linked.statusLabelKo}';
      }
    }

    return RemoteE2eSampleView(
      session: session,
      phase: phase,
      targetAgent: target,
      linkedJob: linked,
      currentStage: stage,
      totalStages: total,
      detailMessage: detail,
      canSend: canSend,
      sendBlockedReason: blocked,
    );
  }

  Future<RemoteE2eSampleSession> sendToAgent({
    required RemoteE2eSampleSession session,
    required RemoteAgentDoc agent,
    required RemoteControlApi api,
    required List<RemoteJobDoc> jobs,
    String? ownerUid,
  }) async {
    if (!agent.isOnline()) {
      throw RemoteControlApiException(
        'Online Agent가 아닙니다. Heartbeat를 확인하세요.',
        code: 'agent_offline',
      );
    }
    if (isDuplicateSend(session: session, jobs: jobs)) {
      throw RemoteControlApiException(
        '이미 소통24워크 Agent에 전달된 작업입니다. 현재 상태를 확인해 주세요.',
        code: 'duplicate_send',
      );
    }
    final ref = refFromSession(session);
    if (ref == null) {
      throw RemoteControlApiException(
        '샘플 작업지시서 형식이 올바르지 않습니다.',
        code: 'invalid_payload',
      );
    }
    final payload = _instructionSource.payloadMap(ref);
    if (payload == null || !RemoteE2eSampleMarkers.isTestPayload(payload)) {
      throw RemoteControlApiException(
        'TEST 샘플 payload 검증에 실패했습니다.',
        code: 'invalid_payload',
      );
    }

    final jobId = await api.createJob(
      type: ref.artifactType,
      title: ref.title,
      assignedAgentId: agent.agentId,
      totalStages: ref.totalStages,
    );
    final idem = 'idem_${ref.instructionId}_v${ref.version}_$jobId';
    await api.startJob(jobId: jobId, payload: payload, idempotencyKey: idem);

    final sentAt = DateTime.now().toUtc().toIso8601String();
    final updated = session.copyWith(
      sentJobId: jobId,
      sentAgentId: agent.agentId,
      sentAgentName: agent.deviceName,
      sentAtIso: sentAt,
    );
    await _saveSession(updated);
    await _mirror.upsertActive(
      ownerUid: ownerUid,
      artifactType: ArtifactType.ebook,
      instructionId: session.instructionId,
      jsonText: session.jsonText,
      version: ref.version,
      title: ref.title,
      totalStages: ref.totalStages,
    );
    return updated;
  }
}
