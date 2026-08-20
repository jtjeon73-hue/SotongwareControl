import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/remote_control_env.dart';

/// Firestore `agents/{agentId}` + UI helpers (protocol V1 wire states).
class RemoteAgentDoc {
  const RemoteAgentDoc({
    required this.agentId,
    required this.ownerUid,
    required this.deviceName,
    required this.state,
    required this.enabled,
    this.appVersion = '',
    this.protocolVersion = '1.0',
    this.currentJobId = '',
    this.currentStage = '',
    this.lastHeartbeatAt,
    this.updatedAt,
    this.lastError = '',
    this.codexUsage,
    this.cursorUsage,
  });

  final String agentId;
  final String ownerUid;
  final String deviceName;
  final String state;
  final bool enabled;
  final String appVersion;
  final String protocolVersion;
  final String currentJobId;
  final String currentStage;
  final DateTime? lastHeartbeatAt;
  final DateTime? updatedAt;
  final String lastError;
  final CodexUsageTelemetry? codexUsage;
  final CursorUsageTelemetry? cursorUsage;

  bool isOnline({
    DateTime? now,
    int thresholdSeconds = RemoteControlEnv.onlineThresholdSeconds,
  }) {
    final hb = lastHeartbeatAt;
    if (hb == null) return false;
    final clock = now ?? DateTime.now().toUtc();
    return clock.difference(hb.toUtc()).inSeconds <= thresholdSeconds;
  }

  String get stateLabelKo {
    switch (state) {
      case 'starting':
        return '시작 중';
      case 'idle':
        return '작업지시 대기';
      case 'receiving_job':
        return '작업지시 수신 중';
      case 'running':
        return '작업 진행 중';
      case 'running_ai':
        return 'AI 실행 중';
      case 'generating_result':
        return '결과 생성 중';
      case 'validating_result':
        return '결과 검증 중';
      case 'validation_retry_waiting':
        return '결과 검증 자동 재시도 대기';
      case 'transitioning_stage':
        return '다음 단계 전환 중';
      case 'paused_quota':
        return 'AI 사용량 초기화 대기';
      case 'paused_network':
        return '네트워크 복구 대기';
      case 'result_validation_failed':
        return '결과 검증 최종 실패';
      case 'waiting_approval':
      case 'awaiting_user_approval':
      case 'pending_review':
        return '승인 대기';
      case 'revision_requested':
        return '보완 요청';
      case 'error':
        return '작업 오류';
      case 'offline':
        return '연결 오류';
      default:
        return state.isEmpty ? '알 수 없음' : state;
    }
  }

  /// Visual status for card badge.
  RemoteAgentUiKind get uiKind {
    if (!enabled) return RemoteAgentUiKind.offline;
    if (!isOnline()) return RemoteAgentUiKind.offline;
    switch (state) {
      case 'error':
        return RemoteAgentUiKind.error;
      case 'waiting_approval':
      case 'awaiting_user_approval':
      case 'pending_review':
      case 'revision_requested':
        return RemoteAgentUiKind.waitingApproval;
      case 'running':
      case 'receiving_job':
      case 'running_ai':
      case 'generating_result':
      case 'validating_result':
      case 'validation_retry_waiting':
      case 'transitioning_stage':
        return RemoteAgentUiKind.running;
      default:
        return RemoteAgentUiKind.online;
    }
  }

  factory RemoteAgentDoc.fromMap(Map<String, dynamic> map, {String? id}) {
    return RemoteAgentDoc(
      agentId: '${map['agentId'] ?? id ?? ''}',
      ownerUid: '${map['ownerUid'] ?? ''}',
      deviceName: '${map['deviceName'] ?? '소통24워크 Agent'}',
      state: '${map['state'] ?? 'idle'}',
      enabled: map['enabled'] != false,
      appVersion: '${map['appVersion'] ?? ''}',
      protocolVersion: '${map['protocolVersion'] ?? '1.0'}',
      currentJobId: '${map['currentJobId'] ?? ''}',
      currentStage: '${map['currentStage'] ?? ''}',
      lastHeartbeatAt: _ts(map['lastHeartbeatAt']),
      updatedAt: _ts(map['updatedAt']),
      lastError: _lastErrorText(map['lastError']),
      codexUsage: CodexUsageTelemetry.fromAgentMap(map),
      cursorUsage: CursorUsageTelemetry.fromAgentMap(map),
    );
  }
}

/// Cursor has no supported automatic quota API. Values stay unknown unless a
/// future trusted provider (or explicit manual input) supplies them.
class CursorUsageTelemetry {
  const CursorUsageTelemetry({
    this.status = 'unknown',
    this.source = 'no_official_local_usage_api',
    this.collectedAt,
    this.usedPercent,
    this.remainingPercent,
    this.resetsAt,
  });

  final String status;
  final String source;
  final DateTime? collectedAt;
  final int? usedPercent;
  final int? remainingPercent;
  final DateTime? resetsAt;

  bool get isTrustedManual => source == 'manual';
  bool get hasQuota =>
      isTrustedManual && usedPercent != null && remainingPercent != null;

  static CursorUsageTelemetry? fromAgentMap(Map<String, dynamic> map) {
    final aiUsage = map['aiUsage'];
    if (aiUsage is! Map) return null;
    final cursor = aiUsage['cursor'];
    if (cursor is! Map) return null;
    return CursorUsageTelemetry(
      status: '${cursor['status'] ?? 'unknown'}'.trim(),
      source: '${cursor['source'] ?? 'no_official_local_usage_api'}'.trim(),
      collectedAt: _parseIso('${cursor['collectedAt'] ?? ''}'),
      usedPercent: _optionalPercent(cursor['usedPercent']),
      remainingPercent: _optionalPercent(cursor['remainingPercent']),
      resetsAt: _parseIso('${cursor['resetsAt'] ?? ''}'),
    );
  }
}

/// Agent heartbeat `aiUsage.codex` telemetry (allowlisted fields only).
class CodexUsageTelemetry {
  const CodexUsageTelemetry({
    this.status = '',
    this.collectedAt,
    this.planType = '',
    this.weekly,
  });

  final String status;
  final DateTime? collectedAt;
  final String planType;
  final CodexWeeklyUsage? weekly;

  static CodexUsageTelemetry? fromAgentMap(Map<String, dynamic> map) {
    final aiUsage = map['aiUsage'];
    if (aiUsage is! Map) return null;
    final codex = aiUsage['codex'];
    if (codex is! Map) return null;
    return CodexUsageTelemetry.fromMap(codex);
  }

  factory CodexUsageTelemetry.fromMap(Map<dynamic, dynamic> map) {
    CodexWeeklyUsage? weekly;
    final weeklyRaw = map['weekly'];
    if (weeklyRaw is Map) {
      weekly = CodexWeeklyUsage.fromMap(weeklyRaw);
    }
    return CodexUsageTelemetry(
      status: '${map['status'] ?? ''}'.trim(),
      collectedAt: _parseIso('${map['collectedAt'] ?? ''}'),
      planType: '${map['planType'] ?? ''}'.trim(),
      weekly: weekly,
    );
  }
}

class CodexWeeklyUsage {
  const CodexWeeklyUsage({
    this.usedPercent,
    this.remainingPercent,
    this.windowDurationMins,
    this.resetsAt,
    this.resetsAtIso,
  });

  final int? usedPercent;
  final int? remainingPercent;
  final int? windowDurationMins;
  final DateTime? resetsAt;
  final DateTime? resetsAtIso;

  factory CodexWeeklyUsage.fromMap(Map<dynamic, dynamic> map) {
    return CodexWeeklyUsage(
      usedPercent: _optionalPercent(map['usedPercent']),
      remainingPercent: _optionalPercent(map['remainingPercent']),
      windowDurationMins: _optionalPositiveInt(map['windowDurationMins']),
      resetsAt: _parseIso('${map['resetsAt'] ?? ''}'),
      resetsAtIso: _parseIso('${map['resetsAtIso'] ?? ''}'),
    );
  }

  DateTime? get resetAt => resetsAtIso ?? resetsAt;
}

int? _optionalPercent(dynamic v) {
  if (v is int) return v >= 0 && v <= 100 ? v : null;
  if (v is num) {
    final n = v.round();
    return n >= 0 && n <= 100 ? n : null;
  }
  return null;
}

int? _optionalPositiveInt(dynamic v) {
  if (v is int) return v > 0 ? v : null;
  if (v is num) {
    final n = v.round();
    return n > 0 ? n : null;
  }
  return null;
}

DateTime? _parseIso(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

String _lastErrorText(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  if (raw is Map) {
    final message = '${raw['message'] ?? ''}'.trim();
    final code = '${raw['code'] ?? ''}'.trim();
    if (message.isNotEmpty && code.isNotEmpty) return '$code: $message';
    return message.isNotEmpty ? message : code;
  }
  return '$raw';
}

enum RemoteAgentUiKind { online, offline, running, waitingApproval, error }

class RemoteJobDoc {
  const RemoteJobDoc({
    required this.jobId,
    required this.ownerUid,
    required this.title,
    required this.type,
    required this.status,
    required this.assignedAgentId,
    this.currentStage = '',
    this.totalStages = 18,
    this.progress = 0,
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.instructionId = '',
  });

  final String jobId;
  final String ownerUid;
  final String title;
  final String type;
  final String status;
  final String assignedAgentId;
  final String instructionId;
  final String currentStage;
  final int totalStages;
  final int progress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  String get statusLabelKo {
    switch (status) {
      case 'queued':
        return '대기';
      case 'claimed':
        return '접수됨';
      case 'running':
        return '작업 중';
      case 'waiting_approval':
      case 'awaiting_user_approval':
      case 'pending_review':
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
      case 'result_validation_retrying':
        return '결과 검증 자동 재시도 대기';
      case 'result_validation_failed':
        return '결과 검증 최종 실패';
      default:
        return status;
    }
  }

  factory RemoteJobDoc.fromMap(Map<String, dynamic> map, {String? id}) {
    return RemoteJobDoc(
      jobId: '${map['jobId'] ?? id ?? ''}',
      ownerUid: '${map['ownerUid'] ?? ''}',
      title: '${map['title'] ?? ''}',
      type: '${map['type'] ?? ''}',
      status: '${map['status'] ?? 'queued'}',
      assignedAgentId: '${map['assignedAgentId'] ?? ''}',
      currentStage: '${map['currentStage'] ?? ''}',
      totalStages: _int(map['totalStages'], 18),
      progress: _int(map['progress'], 0),
      createdAt: _ts(map['createdAt']),
      updatedAt: _ts(map['updatedAt']),
      startedAt: _ts(map['startedAt']),
      completedAt: _ts(map['completedAt']),
      instructionId: '${map['instructionId'] ?? ''}',
    );
  }
}

class RemoteCommandDoc {
  const RemoteCommandDoc({
    required this.commandId,
    required this.jobId,
    this.type = '',
    this.status = '',
    this.idempotencyKey = '',
    this.agentId = '',
  });

  final String commandId;
  final String jobId;
  final String type;
  final String status;
  final String idempotencyKey;
  final String agentId;

  bool get isStartJob => type == 'START_JOB';

  factory RemoteCommandDoc.fromMap(Map<String, dynamic> map, {String? id}) {
    return RemoteCommandDoc(
      commandId: '${map['commandId'] ?? id ?? ''}',
      jobId: '${map['jobId'] ?? ''}',
      type: '${map['type'] ?? ''}',
      status: '${map['status'] ?? ''}',
      idempotencyKey: '${map['idempotencyKey'] ?? ''}',
      agentId: '${map['agentId'] ?? ''}',
    );
  }
}

class RemoteStageDoc {
  const RemoteStageDoc({
    required this.stageId,
    this.stageNumber = 0,
    this.stageName = '',
    this.status = 'queued',
    this.progress = 0,
    this.attempt = 0,
    this.summary = '',
    this.requiresApproval = false,
    this.updatedAt,
  });

  final String stageId;
  final int stageNumber;
  final String stageName;
  final String status;
  final int progress;
  final int attempt;
  final String summary;
  final bool requiresApproval;
  final DateTime? updatedAt;

  factory RemoteStageDoc.fromMap(Map<String, dynamic> map, {String? id}) {
    return RemoteStageDoc(
      stageId: '${map['stageId'] ?? id ?? ''}',
      stageNumber: _int(map['stageNumber'], 0),
      stageName: '${map['stageName'] ?? ''}',
      status: '${map['status'] ?? 'queued'}',
      progress: _int(map['progress'], 0),
      attempt: _int(map['attempt'], 0),
      summary: '${map['summary'] ?? ''}',
      requiresApproval: map['requiresApproval'] == true,
      updatedAt: _ts(map['updatedAt']),
    );
  }
}

class RemotePairingResult {
  const RemotePairingResult({
    required this.sessionId,
    required this.pairingCode,
    required this.expiresAt,
    this.ttlSeconds = 600,
  });

  final String sessionId;
  final String pairingCode;
  final DateTime expiresAt;
  final int ttlSeconds;
}

class ActiveWorkInstructionRef {
  const ActiveWorkInstructionRef({
    required this.artifactType,
    required this.instructionId,
    required this.title,
    required this.jsonText,
    this.version = 1,
    this.totalStages = 18,
  });

  final String artifactType;
  final String instructionId;
  final String title;
  final String jsonText;
  final int version;
  final int totalStages;
}

DateTime? _ts(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
  return null;
}

int _int(dynamic v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

/// 완료된 Job만. 현재시각-시작시각으로 승인대기를 포함하지 않는다.
String? jobCompletedDurationLabel(RemoteJobDoc job) {
  final start = job.startedAt;
  final end = job.completedAt;
  if (start == null || end == null) return null;
  final d = end.difference(start);
  if (d.isNegative || d.inSeconds <= 0) return null;
  return formatDurationKo(d);
}

String formatDurationKo(Duration d) {
  if (d.isNegative || d.inSeconds <= 0) return '';
  if (d.inHours >= 1) {
    final m = d.inMinutes.remainder(60);
    return m > 0 ? '${d.inHours}시간 $m분' : '${d.inHours}시간';
  }
  if (d.inMinutes >= 1) return '${d.inMinutes}분';
  return '${d.inSeconds}초';
}

String formatRelativeKo(DateTime? at, {DateTime? now}) {
  if (at == null) return '연결 기록 없음';
  final clock = now ?? DateTime.now().toUtc();
  final sec = clock.difference(at.toUtc()).inSeconds;
  if (sec < 5) return '방금 전';
  if (sec < 60) return '$sec초 전';
  final min = sec ~/ 60;
  if (min < 60) return '$min분 전';
  final hr = min ~/ 60;
  if (hr < 48) return '$hr시간 전';
  return '${hr ~/ 24}일 전';
}
