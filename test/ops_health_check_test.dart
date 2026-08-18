import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/ops_health_check.dart';

void main() {
  final now = DateTime.utc(2026, 8, 18, 1, 0, 0);

  RemoteAgentDoc agent({
    DateTime? hb,
    String state = 'idle',
    String lastError = '',
  }) {
    return RemoteAgentDoc(
      agentId: 'agent_1',
      ownerUid: 'uid',
      deviceName: 'LAPTOP',
      state: state,
      enabled: true,
      lastHeartbeatAt: hb,
      lastError: lastError,
    );
  }

  test('온라인 Agent면 전체 정상', () {
    final report = OpsHealthCheck.evaluate(
      agents: [agent(hb: now.subtract(const Duration(seconds: 8)))],
      now: now,
    );
    expect(report.overall, OpsHealthLevel.ok);
    expect(report.overallLabelKo, '시스템 정상 · 별도 테스트 필요 없음');
    expect(report.checks.every((c) => c.level == OpsHealthLevel.ok), isTrue);
    expect(report.suggestedCheck, isNull);
  });

  test('heartbeat 지연이면 확인 필요', () {
    final report = OpsHealthCheck.evaluate(
      agents: [agent(hb: now.subtract(const Duration(minutes: 3)))],
      now: now,
    );
    expect(report.overall, OpsHealthLevel.attention);
    expect(report.overallLabelKo, '확인 필요');
    expect(report.suggestedCheck?.id, 'agent');
    expect(report.suggestedCheck?.levelLabelKo, '확인 필요');
  });

  test('Agent 없으면 문제 있음 + GPT 메모', () {
    final report = OpsHealthCheck.evaluate(agents: const [], now: now);
    expect(report.overall, OpsHealthLevel.problem);
    expect(report.overallLabelKo, '문제 있음');
    expect(report.suggestedCheck?.title, 'Agent 연결 테스트');
    final memo = report.toGptMemo();
    expect(memo, contains('SotongWareControl 문제 해결 메모'));
    expect(memo, contains('Agent 연결 테스트'));
    expect(memo, contains('GPT가 다음으로 확인하면 좋은 부분'));
  });

  test('lastError + error state면 전송 경로 문제', () {
    final report = OpsHealthCheck.evaluate(
      agents: [
        agent(
          hb: now.subtract(const Duration(seconds: 5)),
          state: 'error',
          lastError: 'start_job failed',
        ),
      ],
      now: now,
    );
    expect(report.overall, OpsHealthLevel.problem);
    expect(
      report.checks.firstWhere((c) => c.id == 'delivery').level,
      OpsHealthLevel.problem,
    );
    expect(report.toGptMemo(), contains('start_job failed'));
  });
}
