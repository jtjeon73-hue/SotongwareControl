import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/sotong24_monitoring.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';

void main() {
  const policy = Sotong24MonitoringPolicy(
    offlineAfter: Duration(minutes: 10),
    noActivityAfter: Duration(minutes: 5),
    defaultExpectedMax: Duration(minutes: 8),
  );

  Sotong24RemoteProject project({
    required String heartbeat,
    required Sotong24RemoteStage stage,
    String status = Sotong24WorkStatus.inProgress,
  }) {
    return Sotong24RemoteProject(
      projectId: 'wi_test_monitor',
      title: 'monitor',
      productType: 'ebook',
      currentStage: 1,
      totalStages: 18,
      progress: 0,
      status: status,
      lastHeartbeat: heartbeat,
      stages: [stage],
    );
  }

  Sotong24RemoteStage stage({
    String startedAt = '2026-08-19T00:00:00.000Z',
    String lastActivityAt = '2026-08-19T00:04:30.000Z',
    String activityState = 'result_validating',
  }) {
    return Sotong24RemoteStage(
      stageId: 'idea_clarify',
      stageNumber: 1,
      stageName: '아이디어 정리',
      status: Sotong24WorkStatus.inProgress,
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
      activityState: activityState,
    );
  }

  test('server timestamps drive elapsed time and activity label', () {
    final result = Sotong24StageMonitoring.evaluate(
      project: project(heartbeat: '2026-08-19T00:04:50.000Z', stage: stage()),
      stage: stage(),
      policy: policy,
      now: DateTime.parse('2026-08-19T00:05:00.000Z'),
    );
    expect(result.elapsed, const Duration(minutes: 5));
    expect(result.lastActivityAge, const Duration(seconds: 30));
    expect(result.activityLabel, '결과 검증 중');
    expect(result.agentOnline, isTrue);
    expect(result.health, Sotong24StageHealth.healthy);
  });

  test('recent heartbeat cannot hide missing real activity', () {
    final s = stage(lastActivityAt: '2026-08-19T00:00:00.000Z');
    final result = Sotong24StageMonitoring.evaluate(
      project: project(heartbeat: '2026-08-19T00:09:55.000Z', stage: s),
      stage: s,
      policy: policy,
      now: DateTime.parse('2026-08-19T00:10:00.000Z'),
    );
    expect(result.agentOnline, isTrue);
    expect(result.health, Sotong24StageHealth.inactive);
  });

  test('long work with recent activity is delayed, never an error', () {
    final s = stage(lastActivityAt: '2026-08-19T00:19:30.000Z');
    final result = Sotong24StageMonitoring.evaluate(
      project: project(heartbeat: '2026-08-19T00:19:50.000Z', stage: s),
      stage: s,
      policy: policy,
      now: DateTime.parse('2026-08-19T00:20:00.000Z'),
    );
    expect(result.health, Sotong24StageHealth.delayed);
    expect(result.health, isNot(Sotong24StageHealth.error));
  });

  test('stale heartbeat is offline', () {
    final s = stage();
    final result = Sotong24StageMonitoring.evaluate(
      project: project(heartbeat: '2026-08-18T23:00:00.000Z', stage: s),
      stage: s,
      policy: policy,
      now: DateTime.parse('2026-08-19T00:05:00.000Z'),
    );
    expect(result.health, Sotong24StageHealth.offline);
  });

  test('waiting approval freezes work time and never becomes inactivity', () {
    final awaiting = Sotong24RemoteStage(
      stageId: 'idea_clarify',
      stageNumber: 1,
      stageName: '아이디어 정리',
      status: Sotong24WorkStatus.awaitingApproval,
      startedAt: '2026-08-19T00:00:00.000Z',
      completedAt: '2026-08-19T00:02:00.000Z',
      lastActivityAt: '2026-08-19T00:02:00.000Z',
      activityState: 'approval_preparing',
    );
    final result = Sotong24StageMonitoring.evaluate(
      project: project(heartbeat: '2026-08-19T00:02:00.000Z', stage: awaiting),
      stage: awaiting,
      policy: policy,
      now: DateTime.parse('2026-08-19T01:02:00.000Z'),
    );
    expect(result.health, Sotong24StageHealth.awaitingUser);
    expect(result.healthLabel, '사용자 승인 대기');
    expect(result.elapsed, const Duration(minutes: 2));
    expect(result.approvalWaitAge, const Duration(hours: 1));
  });

  test('quota pause is explicit even when errorMessage is present', () {
    final paused = Sotong24RemoteStage(
      stageId: 'project_setup',
      stageNumber: 5,
      stageName: '프로젝트 생성 또는 불러오기',
      status: Sotong24WorkStatus.pausedQuota,
      errorMessage: 'quota_exhausted',
      activityState: 'paused_quota',
    );
    final result = Sotong24StageMonitoring.evaluate(
      project: project(
        heartbeat: '2026-08-19T00:04:50.000Z',
        stage: paused,
        status: Sotong24WorkStatus.pausedQuota,
      ),
      stage: paused,
      policy: policy,
      now: DateTime.parse('2026-08-19T00:05:00.000Z'),
    );
    expect(result.health, Sotong24StageHealth.pausedQuota);
    expect(result.activityLabel, 'AI 사용량 초기화 대기');
  });
}
