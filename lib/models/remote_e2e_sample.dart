/// 노트북 원격관제 — 샘플 WorkInstruction E2E 테스트 세션/상태.
library;

import 'remote_agent_models.dart';

/// 샘플 E2E 진행 단계 (UI 표시용).
enum RemoteE2ePhase {
  notCreated,
  readyToSend,
  sent,
  received,
  working,
  awaitingApproval,
  completed,
  error,
}

extension RemoteE2ePhaseX on RemoteE2ePhase {
  String get labelKo {
    switch (this) {
      case RemoteE2ePhase.notCreated:
        return '미생성';
      case RemoteE2ePhase.readyToSend:
        return '전송 준비';
      case RemoteE2ePhase.sent:
        return '전송됨';
      case RemoteE2ePhase.received:
        return '수신됨';
      case RemoteE2ePhase.working:
        return '작업 중';
      case RemoteE2ePhase.awaitingApproval:
        return '승인 대기';
      case RemoteE2ePhase.completed:
        return '완료';
      case RemoteE2ePhase.error:
        return '오류';
    }
  }
}

/// 테스트 샘플 식별 — instructionId / title 기준.
class RemoteE2eSampleMarkers {
  RemoteE2eSampleMarkers._();

  static const instructionIdPrefix = 'wi_test_remote_e2e_';
  static const sampleTitle = '[TEST] 전자책 원격제작 E2E';
  static const sampleDescription =
      '소통총관제 → Relay → 소통24워크 Agent → 단계 진행 → 상태 반환 전체 경로 검증용 샘플';

  static bool isTestInstructionId(String? id) {
    final v = (id ?? '').trim();
    return v.startsWith(instructionIdPrefix);
  }

  static bool isTestTitle(String? title) {
    final v = (title ?? '').trim();
    return v.startsWith('[TEST]') || v == sampleTitle;
  }

  static bool isTestPayload(Map<String, dynamic>? json) {
    if (json == null) return false;
    if (isTestInstructionId('${json['instructionId'] ?? ''}')) return true;
    if (isTestTitle('${json['title'] ?? json['businessIdea'] ?? ''}')) {
      return true;
    }
    final notes = '${json['notes'] ?? ''}';
    return notes.contains('[environment:test]') ||
        notes.contains('[isTest:true]');
  }

  /// 기존 lightweight E2E notes에는 없어야 함.
  static bool notesRequireCursor(String? notes) {
    return (notes ?? '').contains('[cursor:required]');
  }

  /// 기존 lightweight / Cursor TEST notes에는 없어야 함.
  static bool notesRequireCodex(String? notes) {
    return (notes ?? '').contains('[codex:required]');
  }
}

/// Cursor 자동실행 전용 TEST — 기존 lightweight E2E와 분리.
class RemoteCursorAutostartMarkers {
  RemoteCursorAutostartMarkers._();

  /// `wi_test_remote_e2e_` 범위 유지 + cursor 식별.
  static const instructionIdPrefix = 'wi_test_remote_e2e_cursor_';
  static const sampleTitle = '[TEST] Cursor 자동실행';
  static const sampleDescription =
      'Cursor를 종료한 상태에서 전송하세요. '
      'Agent가 작업을 수신하면 Cursor 실행 여부만 검증합니다. '
      '실제 전자책 제작·출시 작업이 아닙니다.';

  static const environmentMarker = '[environment:test]';
  static const isTestMarker = '[isTest:true]';
  static const cursorRequiredMarker = '[cursor:required]';

  static String buildNotes() =>
      '$sampleDescription\n'
      '$environmentMarker\n'
      '$isTestMarker\n'
      '$cursorRequiredMarker';

  static bool isCursorTestInstructionId(String? id) {
    final v = (id ?? '').trim();
    return v.startsWith(instructionIdPrefix);
  }

  static bool isCursorTestTitle(String? title) {
    return (title ?? '').trim() == sampleTitle;
  }

  static bool isCursorTestPayload(Map<String, dynamic>? json) {
    if (json == null) return false;
    if (isCursorTestInstructionId('${json['instructionId'] ?? ''}')) {
      return RemoteE2eSampleMarkers.notesRequireCursor(
        '${json['notes'] ?? ''}',
      );
    }
    if (isCursorTestTitle('${json['title'] ?? json['businessIdea'] ?? ''}')) {
      return RemoteE2eSampleMarkers.notesRequireCursor(
        '${json['notes'] ?? ''}',
      );
    }
    return false;
  }
}

/// Codex 무인작업 전용 TEST — lightweight E2E·Cursor TEST와 분리.
class RemoteCodexUnattendedMarkers {
  RemoteCodexUnattendedMarkers._();

  static const instructionIdPrefix = 'wi_test_remote_e2e_codex_';
  static const sampleTitle = '[TEST] Codex 무인작업';
  static const sampleDescription =
      '휴대폰 전송만으로 Agent가 Codex를 실행해 '
      '안전한 Markdown 결과 파일을 생성하는 테스트입니다. '
      '실제 전자책 제작·출시 작업이 아닙니다.';
  static const expectedOutputPath = 'output/codex_ai_smoke.md';
  static const smokeStageId = 'draft';

  static const environmentMarker = '[environment:test]';
  static const isTestMarker = '[isTest:true]';
  static const codexRequiredMarker = '[codex:required]';

  static String buildNotes() =>
      '$sampleDescription\n'
      '$environmentMarker\n'
      '$isTestMarker\n'
      '$codexRequiredMarker\n'
      '[codexSmokeStage:$smokeStageId]\n'
      '[codexExpectedOutput:$expectedOutputPath]\n'
      'Codex smoke 규칙: TEST Markdown 1개만 생성. '
      'git 금지 · deploy 금지 · package install 금지 · '
      '외부 destructive 작업 금지 · workspace 밖 파일 수정 금지.';

  static bool isCodexTestInstructionId(String? id) {
    final v = (id ?? '').trim();
    return v.startsWith(instructionIdPrefix);
  }

  static bool isCodexTestTitle(String? title) {
    return (title ?? '').trim() == sampleTitle;
  }

  static bool isCodexTestPayload(Map<String, dynamic>? json) {
    if (json == null) return false;
    final notes = '${json['notes'] ?? ''}';
    if (!RemoteE2eSampleMarkers.notesRequireCodex(notes)) return false;
    if (RemoteE2eSampleMarkers.notesRequireCursor(notes)) return false;
    if (isCodexTestInstructionId('${json['instructionId'] ?? ''}')) {
      return true;
    }
    if (isCodexTestTitle('${json['title'] ?? json['businessIdea'] ?? ''}')) {
      return true;
    }
    return false;
  }
}

class RemoteE2eSampleSession {
  const RemoteE2eSampleSession({
    this.instructionId = '',
    this.jsonText = '',
    this.sentJobId = '',
    this.sentAgentId = '',
    this.sentAgentName = '',
    this.sentAtIso = '',
  });

  final String instructionId;
  final String jsonText;
  final String sentJobId;
  final String sentAgentId;
  final String sentAgentName;
  final String sentAtIso;

  bool get isCreated =>
      instructionId.trim().isNotEmpty && jsonText.trim().isNotEmpty;

  bool get isSent => sentJobId.trim().isNotEmpty;

  RemoteE2eSampleSession copyWith({
    String? instructionId,
    String? jsonText,
    String? sentJobId,
    String? sentAgentId,
    String? sentAgentName,
    String? sentAtIso,
    bool clearSend = false,
  }) {
    return RemoteE2eSampleSession(
      instructionId: instructionId ?? this.instructionId,
      jsonText: jsonText ?? this.jsonText,
      sentJobId: clearSend ? '' : (sentJobId ?? this.sentJobId),
      sentAgentId: clearSend ? '' : (sentAgentId ?? this.sentAgentId),
      sentAgentName: clearSend ? '' : (sentAgentName ?? this.sentAgentName),
      sentAtIso: clearSend ? '' : (sentAtIso ?? this.sentAtIso),
    );
  }
}

class RemoteE2eSampleView {
  const RemoteE2eSampleView({
    required this.session,
    required this.phase,
    this.targetAgent,
    this.linkedJob,
    this.currentStage = 0,
    this.totalStages = 18,
    this.detailMessage = '',
    this.canSend = false,
    this.sendBlockedReason = '',
  });

  final RemoteE2eSampleSession session;
  final RemoteE2ePhase phase;
  final RemoteAgentDoc? targetAgent;
  final RemoteJobDoc? linkedJob;
  final int currentStage;
  final int totalStages;
  final String detailMessage;
  final bool canSend;
  final String sendBlockedReason;
}

/// E2E 상태 시트용 Job status 설명 (기존 RemoteJobDoc.statusLabelKo와 병행).
String remoteE2eJobStatusExplainKo(String status) {
  switch (status) {
    case 'queued':
      return '전송 대기';
    case 'claimed':
      return 'Agent 수신';
    case 'running':
      return '실행 중';
    case 'waiting_approval':
      return '승인 대기';
    case 'revision_requested':
      return '보완 요청';
    case 'reworking':
      return '보완 중';
    case 'approved':
      return '승인됨';
    case 'completed':
      return '완료';
    case 'failed':
      return '오류';
    case 'cancelled':
      return '취소';
    case 'paused':
      return '일시정지';
    default:
      return status.isEmpty ? '알 수 없음' : status;
  }
}

class RemoteE2eStatusRow {
  const RemoteE2eStatusRow({
    required this.label,
    required this.value,
    this.isFooter = false,
  });

  final String label;
  final String value;
  final bool isFooter;
}

/// 실제 세션/Job/Agent 모델에 있는 값만 행으로 구성. 없는 필드는 안내 문구.
List<RemoteE2eStatusRow> buildRemoteE2eStatusRows(
  RemoteE2eSampleView view, {
  DateTime? now,
}) {
  final session = view.session;
  final job = view.linkedJob;
  final agent = view.targetAgent;
  final rows = <RemoteE2eStatusRow>[];

  final title = (job?.title.trim().isNotEmpty == true)
      ? job!.title.trim()
      : RemoteE2eSampleMarkers.sampleTitle;
  rows.add(RemoteE2eStatusRow(label: '제목', value: title));

  rows.add(
    RemoteE2eStatusRow(
      label: 'instructionId',
      value: session.instructionId.isEmpty ? '—' : session.instructionId,
    ),
  );

  final agentName = session.sentAgentName.isNotEmpty
      ? session.sentAgentName
      : (agent?.deviceName ?? '—');
  final agentId = session.sentAgentId.isNotEmpty
      ? session.sentAgentId
      : (agent?.agentId ?? '');
  rows.add(
    RemoteE2eStatusRow(
      label: 'Agent',
      value: agentId.isEmpty ? agentName : '$agentName ($agentId)',
    ),
  );

  if (agent != null) {
    final online = agent.isOnline(now: now) ? 'Online' : 'Offline';
    rows.add(
      RemoteE2eStatusRow(
        label: 'Agent 상태',
        value: '$online · ${agent.stateLabelKo} (${agent.state})',
      ),
    );
    rows.add(
      RemoteE2eStatusRow(
        label: '마지막 heartbeat',
        value: formatRelativeKo(agent.lastHeartbeatAt, now: now),
      ),
    );
  }

  rows.add(RemoteE2eStatusRow(label: 'UI 상태', value: view.phase.labelKo));
  rows.add(
    RemoteE2eStatusRow(label: '전송', value: session.isSent ? '완료' : '미전송'),
  );
  if (session.sentAtIso.isNotEmpty) {
    rows.add(RemoteE2eStatusRow(label: '전송 시각', value: session.sentAtIso));
  }

  if (job != null) {
    rows.add(RemoteE2eStatusRow(label: 'Job ID', value: job.jobId));
    rows.add(
      RemoteE2eStatusRow(
        label: 'Job 상태',
        value: '${remoteE2eJobStatusExplainKo(job.status)} (${job.status})',
      ),
    );

    final ack = switch (job.status) {
      'queued' => '대기 중 (아직 Agent 미수신)',
      'claimed' => 'Agent 수신 완료 (claimed)',
      'running' || 'reworking' => '실행 중',
      'waiting_approval' || 'revision_requested' => '승인/보완 대기',
      'completed' => '완료',
      'failed' => '실패',
      'cancelled' => '취소됨',
      _ => 'Job status=${job.status}',
    };
    rows.add(RemoteE2eStatusRow(label: 'Agent 수신/ACK', value: ack));

    if (agent != null && agent.currentJobId.isNotEmpty) {
      final match = agent.currentJobId == job.jobId;
      rows.add(
        RemoteE2eStatusRow(
          label: 'Agent currentJobId',
          value: match
              ? '${agent.currentJobId} (이 Job과 일치)'
              : '${agent.currentJobId} (다른 Job)',
        ),
      );
    }

    rows.add(
      RemoteE2eStatusRow(
        label: '현재 stageId',
        value: job.currentStage.isEmpty ? '미보고' : job.currentStage,
      ),
    );
    rows.add(
      RemoteE2eStatusRow(
        label: '진행률',
        value: '${job.progress}% · 전체 ${job.totalStages}단계',
      ),
    );
    rows.add(
      RemoteE2eStatusRow(
        label: '단계 번호',
        value: '현재 총관제 Job 모델에서 확인 불가 (stageId·진행률만 제공)',
      ),
    );

    if (job.updatedAt != null) {
      rows.add(
        RemoteE2eStatusRow(
          label: 'Job 마지막 업데이트',
          value:
              '${formatRelativeKo(job.updatedAt, now: now)} · ${job.updatedAt!.toUtc().toIso8601String()}',
        ),
      );
    }
    if (job.startedAt != null) {
      rows.add(
        RemoteE2eStatusRow(
          label: 'Job 시작',
          value: job.startedAt!.toUtc().toIso8601String(),
        ),
      );
    }
    if (job.completedAt != null) {
      rows.add(
        RemoteE2eStatusRow(
          label: 'Job 완료',
          value: job.completedAt!.toUtc().toIso8601String(),
        ),
      );
    }
    if (job.status == 'failed') {
      rows.add(
        const RemoteE2eStatusRow(
          label: '오류 상세',
          value: '현재 총관제 Job 모델에서 error code/message 확인 불가',
        ),
      );
    }
  } else if (session.isSent) {
    rows.add(
      RemoteE2eStatusRow(
        label: 'Job ID',
        value: session.sentJobId.isEmpty
            ? '—'
            : '${session.sentJobId} (목록에서 Job 문서 미확인)',
      ),
    );
    rows.add(
      const RemoteE2eStatusRow(
        label: 'Job 상태',
        value: '현재 총관제에서 확인 불가 (Job 스트림에 없음)',
      ),
    );
  }

  rows.add(
    const RemoteE2eStatusRow(
      label: 'deferred_busy',
      value: '현재 총관제 Job/Agent 모델에 없음',
    ),
  );
  rows.add(
    const RemoteE2eStatusRow(
      label: '프로젝트 동기화',
      value: 'AI 제작공정/Relay stage_sync는 별도 화면·경로 — 이 시트에서는 확인 불가',
    ),
  );
  rows.add(
    const RemoteE2eStatusRow(
      label: '진단 참고',
      value:
          'queued→claimed까지면 전송·수신 성공. claimed 이후 stageId/진행률이 비면 Agent 자동 실행 전 정체 가능.',
      isFooter: true,
    ),
  );

  return rows;
}
