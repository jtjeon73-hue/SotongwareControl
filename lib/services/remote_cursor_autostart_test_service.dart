import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_planning.dart';
import '../models/planning_wizard_state.dart';
import '../models/remote_agent_models.dart';
import '../models/remote_e2e_sample.dart';
import 'business_planning_service.dart';
import 'planning_sentence_composer.dart';
import 'remote_control_api.dart';
import 'remote_e2e_sample_service.dart';
import 'remote_work_instruction_mirror.dart';
import 'remote_work_instruction_source.dart';
import 'work_instruction_validator.dart';

/// Cursor 자동실행 전용 TEST WorkInstruction (기존 E2E sample과 prefs/notes 분리).
class RemoteCursorAutostartTestService {
  RemoteCursorAutostartTestService({
    BusinessPlanningService? planning,
    PlanningSentenceComposer? composer,
    RemoteWorkInstructionMirrorService? mirror,
    RemoteWorkInstructionSource? instructionSource,
    WorkInstructionValidator? validator,
    RemoteE2eSampleService? e2eHelper,
    this._prefs,
  }) : _planning = planning ?? BusinessPlanningService(),
       _composer = composer ?? const PlanningSentenceComposer(),
       _mirror = mirror ?? RemoteWorkInstructionMirrorService(),
       _instructionSource = instructionSource ?? RemoteWorkInstructionSource(),
       _validator = validator ?? WorkInstructionValidator(),
       _e2eHelper = e2eHelper ?? RemoteE2eSampleService();

  static const prefsInstructionId = 'remote_cursor_autostart_instruction_id';
  static const prefsJsonText = 'remote_cursor_autostart_json_text';
  static const prefsSentJobId = 'remote_cursor_autostart_sent_job_id';
  static const prefsSentAgentId = 'remote_cursor_autostart_sent_agent_id';
  static const prefsSentAgentName = 'remote_cursor_autostart_sent_agent_name';
  static const prefsSentAtIso = 'remote_cursor_autostart_sent_at_iso';

  final BusinessPlanningService _planning;
  final PlanningSentenceComposer _composer;
  final RemoteWorkInstructionMirrorService _mirror;
  final RemoteWorkInstructionSource _instructionSource;
  final WorkInstructionValidator _validator;
  final RemoteE2eSampleService _e2eHelper;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _storage() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String generateInstructionId({DateTime? now}) {
    final ms = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    return '${RemoteCursorAutostartMarkers.instructionIdPrefix}$ms';
  }

  PlanningWizardState _wizardState() {
    return PlanningWizardState(
      mode: 'quick',
      step: 4,
      artifactType: ArtifactType.ebook,
      topic: RemoteCursorAutostartMarkers.sampleTitle,
      customerProblem: '[TEST] Cursor 자동실행 수신 검증',
      targetCustomer: '[TEST] Cursor 자동실행 검증자',
      desiredOutcome: '[TEST] Cursor required 판정·자동실행만 검증 (실제 제작 금지)',
      sentencesManuallyEdited: true,
      artifactAnswers: const {
        'mainProblem': ['productize_unknown'],
        'targetCustomer': ['sidejob_40_60'],
        'desiredOutcome': ['ebook_first'],
        'salesDeploy': ['cheap_validate'],
      },
    );
  }

  WorkInstruction buildCursorTestWorkInstruction({
    required String instructionId,
    DateTime? now,
  }) {
    final stamp = (now ?? DateTime.now()).toUtc();
    final input = _composer
        .toBusinessPlanInput(_wizardState())
        .copyWith(notes: RemoteCursorAutostartMarkers.buildNotes());
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
    final wi = buildCursorTestWorkInstruction(
      instructionId: instructionId,
      now: now,
    );
    final input = _composer
        .toBusinessPlanInput(_wizardState())
        .copyWith(notes: RemoteCursorAutostartMarkers.buildNotes());
    final validation = _validator.validate(input: input, instruction: wi);
    if (!validation.ok) {
      throw StateError(
        'Cursor TEST WorkInstruction 검증 실패: '
        '${validation.issues.map((e) => e.reason).join(', ')}',
      );
    }
    if (!RemoteE2eSampleMarkers.notesRequireCursor(wi.notes)) {
      throw StateError('Cursor TEST notes에 [cursor:required]가 없습니다.');
    }
    if (!RemoteCursorAutostartMarkers.isCursorTestInstructionId(
      instructionId,
    )) {
      throw StateError('Cursor TEST instructionId prefix 불일치');
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
      title: RemoteCursorAutostartMarkers.sampleTitle,
      totalStages: wi.workflowSteps.length,
    );
    return session;
  }

  Future<RemoteE2eSampleSession> resetSample({String? ownerUid}) async {
    return createSample(ownerUid: ownerUid);
  }

  RemoteAgentDoc? pickOnlineAgent(List<RemoteAgentDoc> agents) =>
      _e2eHelper.pickOnlineAgent(agents);

  RemoteJobDoc? findLinkedJob(
    List<RemoteJobDoc> jobs,
    RemoteE2eSampleSession session,
  ) {
    if (!session.isSent) return null;
    for (final j in jobs) {
      if (j.jobId == session.sentJobId) return j;
    }
    for (final j in jobs) {
      if (j.title.trim() == RemoteCursorAutostartMarkers.sampleTitle) return j;
    }
    return null;
  }

  bool isDuplicateSend({
    required RemoteE2eSampleSession session,
    required List<RemoteJobDoc> jobs,
  }) {
    return _e2eHelper.isDuplicateSend(session: session, jobs: jobs);
  }

  RemoteE2eSampleView buildView({
    required RemoteE2eSampleSession session,
    required List<RemoteAgentDoc> agents,
    required List<RemoteJobDoc> jobs,
  }) {
    final target = pickOnlineAgent(agents);
    final linked = findLinkedJob(jobs, session);
    final phase = _e2eHelper.resolvePhase(
      session: session,
      job: linked,
      agent: target,
    );
    final duplicate = isDuplicateSend(session: session, jobs: jobs);

    var canSend = session.isCreated && !session.isSent && !duplicate;
    var blocked = '';
    if (!session.isCreated) {
      blocked = '먼저 Cursor 자동실행 TEST를 생성하세요.';
      canSend = false;
    } else if (session.isSent || duplicate) {
      blocked = '이미 Agent에 전달된 Cursor TEST입니다. 새 테스트를 만들려면 초기화하세요.';
      canSend = false;
    } else if (target == null) {
      blocked = 'Online Agent가 없습니다. 노트북 Agent 연결·Heartbeat를 확인하세요.';
      canSend = false;
    }

    var detail = '';
    if (session.isSent) {
      detail = '전송 완료 · Cursor required START_JOB';
      if (linked != null) {
        detail += ' · Job ${linked.statusLabelKo}';
      }
    }

    return RemoteE2eSampleView(
      session: session,
      phase: phase,
      targetAgent: target,
      linkedJob: linked,
      currentStage: linked?.progress ?? 0,
      totalStages: linked?.totalStages ?? 18,
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
        '이미 Agent에 전달된 Cursor TEST입니다.',
        code: 'duplicate_send',
      );
    }
    final ref = refFromSession(session);
    if (ref == null) {
      throw RemoteControlApiException(
        'Cursor TEST 작업지시서 형식이 올바르지 않습니다.',
        code: 'invalid_payload',
      );
    }
    final payload = _instructionSource.payloadMap(ref);
    if (payload == null ||
        !RemoteCursorAutostartMarkers.isCursorTestPayload(payload)) {
      throw RemoteControlApiException(
        'Cursor TEST payload 검증에 실패했습니다 ([cursor:required] 필요).',
        code: 'invalid_payload',
      );
    }
    if (!RemoteE2eSampleMarkers.notesRequireCursor(
      '${payload['notes'] ?? ''}',
    )) {
      throw RemoteControlApiException(
        'Cursor TEST notes에 [cursor:required]가 없습니다.',
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
