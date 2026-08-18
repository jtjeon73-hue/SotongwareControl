import '../config/remote_control_env.dart';
import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import 'sotong24_workshop_presentation.dart';

enum OpsHealthLevel { ok, attention, problem }

class OpsHealthCheckItem {
  const OpsHealthCheckItem({
    required this.id,
    required this.title,
    required this.level,
    required this.summary,
    this.detail = '',
  });

  final String id;
  final String title;
  final OpsHealthLevel level;
  final String summary;
  final String detail;

  String get levelLabelKo {
    switch (level) {
      case OpsHealthLevel.ok:
        return '정상';
      case OpsHealthLevel.attention:
        return '확인 필요';
      case OpsHealthLevel.problem:
        return '문제 있음';
    }
  }
}

class OpsHealthReport {
  const OpsHealthReport({
    required this.checks,
    required this.agent,
    required this.now,
  });

  final List<OpsHealthCheckItem> checks;
  final RemoteAgentDoc? agent;
  final DateTime now;

  OpsHealthLevel get overall {
    if (checks.any((c) => c.level == OpsHealthLevel.problem)) {
      return OpsHealthLevel.problem;
    }
    if (checks.any((c) => c.level == OpsHealthLevel.attention)) {
      return OpsHealthLevel.attention;
    }
    return OpsHealthLevel.ok;
  }

  String get overallLabelKo {
    switch (overall) {
      case OpsHealthLevel.ok:
        return '시스템 정상 · 별도 테스트 필요 없음';
      case OpsHealthLevel.attention:
        return '확인 필요';
      case OpsHealthLevel.problem:
        return '문제 있음';
    }
  }

  OpsHealthCheckItem? get suggestedCheck {
    for (final c in checks) {
      if (c.level == OpsHealthLevel.problem) return c;
    }
    for (final c in checks) {
      if (c.level == OpsHealthLevel.attention) return c;
    }
    return null;
  }

  String toGptMemo() {
    final buf = StringBuffer();
    buf.writeln('SotongWareControl 문제 해결 메모');
    buf.writeln('생성 시각: ${now.toUtc().toIso8601String()}');
    buf.writeln();
    buf.writeln('## 실행한 테스트');
    for (final c in checks) {
      buf.writeln('- ${c.title}: ${c.levelLabelKo} — ${c.summary}');
    }
    buf.writeln();
    buf.writeln('## 정상으로 통과한 구간');
    final ok = checks.where((c) => c.level == OpsHealthLevel.ok).toList();
    if (ok.isEmpty) {
      buf.writeln('- 없음');
    } else {
      for (final c in ok) {
        buf.writeln('- ${c.title}');
      }
    }
    buf.writeln();
    buf.writeln('## 실패한/확인할 구간');
    final bad = checks.where((c) => c.level != OpsHealthLevel.ok).toList();
    if (bad.isEmpty) {
      buf.writeln('- 없음');
    } else {
      for (final c in bad) {
        buf.writeln('- ${c.title}: ${c.summary}');
        if (c.detail.isNotEmpty) buf.writeln('  ${c.detail}');
      }
    }
    buf.writeln();
    buf.writeln('## Agent 상태');
    final a = agent;
    if (a == null) {
      buf.writeln('- Agent 문서 없음');
    } else {
      buf.writeln('- agentId: ${a.agentId}');
      buf.writeln('- deviceName: ${a.deviceName}');
      buf.writeln('- state: ${a.state} (${a.stateLabelKo})');
      buf.writeln('- online: ${a.isOnline(now: now)}');
      buf.writeln(
        '- currentJobId: ${a.currentJobId.isEmpty ? '(없음)' : a.currentJobId}',
      );
      buf.writeln(
        '- currentStage: ${a.currentStage.isEmpty ? '(없음)' : a.currentStage}',
      );
      buf.writeln(
        '- lastHeartbeatAt: ${a.lastHeartbeatAt?.toUtc().toIso8601String() ?? '(없음)'}',
      );
      buf.writeln(
        '- lastError: ${a.lastError.trim().isEmpty ? '(없음)' : a.lastError.trim()}',
      );
    }
    buf.writeln();
    buf.writeln('## Relay 상태');
    buf.writeln('- 전용 Relay 필드는 Agent 문서에 없음. heartbeat 온라인 여부로 간접 확인.');
    buf.writeln();
    buf.writeln('## 이미 시도한 조치');
    buf.writeln('- 원격관제 홈에서 읽기 전용 점검을 실행함 (작업 생성/전송 없음).');
    buf.writeln();
    buf.writeln('## GPT가 다음으로 확인하면 좋은 부분');
    buf.writeln('- Sotong24Work Agent 프로세스/로그');
    buf.writeln('- Firestore agents/{agentId}.lastHeartbeatAt 갱신');
    buf.writeln('- Relay poll이 정상인지 (Control Functions / Agent transport)');
    return buf.toString();
  }
}

/// 읽기 전용 운영 점검. Job/WI를 만들지 않는다.
class OpsHealthCheck {
  OpsHealthCheck._();

  static OpsHealthReport evaluate({
    required List<RemoteAgentDoc> agents,
    List<RemoteJobDoc> jobs = const [],
    List<Sotong24RemoteProject> workshops = const [],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final online = agents.where((a) => a.isOnline(now: clock)).toList();
    final agent = online.isNotEmpty
        ? online.first
        : (agents.isNotEmpty ? agents.first : null);
    final operational = Sotong24WorkshopPresentation.operationalProjects(
      workshops,
    );

    return OpsHealthReport(
      now: clock,
      agent: agent,
      checks: [
        _agentLink(agent, clock),
        _relay(agent, clock),
        _deliveryPath(agent, clock),
        _codexPath(agent, clock),
        _artifactSync(agent, operational, clock),
      ],
    );
  }

  static OpsHealthCheckItem _agentLink(RemoteAgentDoc? agent, DateTime now) {
    if (agent == null) {
      return const OpsHealthCheckItem(
        id: 'agent',
        title: 'Agent 연결 테스트',
        level: OpsHealthLevel.problem,
        summary: '연결된 Agent가 없습니다.',
        detail: '노트북에서 Sotong24Work Agent를 실행하고 페어링을 확인하세요.',
      );
    }
    if (agent.isOnline(now: now)) {
      return OpsHealthCheckItem(
        id: 'agent',
        title: 'Agent 연결 테스트',
        level: OpsHealthLevel.ok,
        summary:
            'heartbeat가 ${RemoteControlEnv.onlineThresholdSeconds}초 이내입니다.',
      );
    }
    final hb = agent.lastHeartbeatAt;
    if (hb == null) {
      return const OpsHealthCheckItem(
        id: 'agent',
        title: 'Agent 연결 테스트',
        level: OpsHealthLevel.problem,
        summary: 'heartbeat 기록이 없습니다.',
      );
    }
    final age = now.difference(hb.toUtc());
    if (age.inMinutes < 5) {
      return OpsHealthCheckItem(
        id: 'agent',
        title: 'Agent 연결 테스트',
        level: OpsHealthLevel.attention,
        summary: '최근 연결이 지연되고 있습니다 (${age.inSeconds}초 전).',
      );
    }
    return OpsHealthCheckItem(
      id: 'agent',
      title: 'Agent 연결 테스트',
      level: OpsHealthLevel.problem,
      summary: 'Agent 응답이 없습니다 (${age.inMinutes}분 전).',
    );
  }

  static OpsHealthCheckItem _relay(RemoteAgentDoc? agent, DateTime now) {
    if (agent == null) {
      return const OpsHealthCheckItem(
        id: 'relay',
        title: 'Relay 통신 테스트',
        level: OpsHealthLevel.attention,
        summary: 'Agent가 없어 Relay를 확인할 수 없습니다.',
      );
    }
    if (agent.isOnline(now: now)) {
      return const OpsHealthCheckItem(
        id: 'relay',
        title: 'Relay 통신 테스트',
        level: OpsHealthLevel.ok,
        summary: 'heartbeat가 갱신되고 있어 Relay 경로는 정상으로 보입니다.',
      );
    }
    return const OpsHealthCheckItem(
      id: 'relay',
      title: 'Relay 통신 테스트',
      level: OpsHealthLevel.attention,
      summary: 'Relay 응답 상태 점검이 필요합니다.',
      detail: '전용 Relay 상태 필드는 아직 Agent 문서에 없습니다.',
    );
  }

  static OpsHealthCheckItem _deliveryPath(RemoteAgentDoc? agent, DateTime now) {
    if (agent == null || !agent.isOnline(now: now)) {
      return const OpsHealthCheckItem(
        id: 'delivery',
        title: '작업 전송 경로 테스트',
        level: OpsHealthLevel.attention,
        summary: 'Agent가 오프라인이라 전송 경로를 확인하지 못했습니다.',
      );
    }
    final err = agent.lastError.trim();
    if (err.isNotEmpty && agent.state == 'error') {
      return OpsHealthCheckItem(
        id: 'delivery',
        title: '작업 전송 경로 테스트',
        level: OpsHealthLevel.problem,
        summary: 'Agent 오류가 보고되었습니다.',
        detail: err,
      );
    }
    return const OpsHealthCheckItem(
      id: 'delivery',
      title: '작업 전송 경로 테스트',
      level: OpsHealthLevel.ok,
      summary: 'Agent가 수신 가능한 상태입니다. 실제 전송은 작업지시 제작소에서만 합니다.',
    );
  }

  static OpsHealthCheckItem _codexPath(RemoteAgentDoc? agent, DateTime now) {
    if (agent == null || !agent.isOnline(now: now)) {
      return const OpsHealthCheckItem(
        id: 'codex',
        title: 'Codex 실행 경로 테스트',
        level: OpsHealthLevel.attention,
        summary: 'Agent 연결이 없어 Codex 경로를 확인하지 못했습니다.',
      );
    }
    if (agent.state == 'error') {
      return const OpsHealthCheckItem(
        id: 'codex',
        title: 'Codex 실행 경로 테스트',
        level: OpsHealthLevel.problem,
        summary: 'Agent가 오류 상태입니다.',
      );
    }
    return const OpsHealthCheckItem(
      id: 'codex',
      title: 'Codex 실행 경로 테스트',
      level: OpsHealthLevel.ok,
      summary: 'Agent가 준비/작업 상태입니다. Codex 사용량 실데이터는 아직 없습니다.',
    );
  }

  static OpsHealthCheckItem _artifactSync(
    RemoteAgentDoc? agent,
    List<Sotong24RemoteProject> operational,
    DateTime now,
  ) {
    if (operational.isEmpty) {
      return const OpsHealthCheckItem(
        id: 'artifact',
        title: '결과물 동기화 테스트',
        level: OpsHealthLevel.ok,
        summary: '진행 중인 제작 작업이 없어 동기화 지연을 확인할 대상이 없습니다.',
      );
    }
    final p = operational.first;
    final raw = p.lastHeartbeat.trim().isNotEmpty
        ? p.lastHeartbeat
        : p.updatedAt;
    final ts = DateTime.tryParse(raw);
    if (ts == null) {
      return const OpsHealthCheckItem(
        id: 'artifact',
        title: '결과물 동기화 테스트',
        level: OpsHealthLevel.attention,
        summary: '결과물 동기화 시각을 읽지 못했습니다.',
      );
    }
    final age = now.difference(ts.toUtc());
    if (age.inMinutes >= 10 &&
        p.userFacingStatus != Sotong24WorkStatus.awaitingApproval &&
        p.userFacingStatus != Sotong24WorkStatus.completed) {
      return OpsHealthCheckItem(
        id: 'artifact',
        title: '결과물 동기화 테스트',
        level: OpsHealthLevel.attention,
        summary: '결과물 동기화가 지연되고 있습니다 (${age.inMinutes}분 전).',
      );
    }
    return const OpsHealthCheckItem(
      id: 'artifact',
      title: '결과물 동기화 테스트',
      level: OpsHealthLevel.ok,
      summary: '최근 제작 동기화가 확인됩니다.',
    );
  }
}
