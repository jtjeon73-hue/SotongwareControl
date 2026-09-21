import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/ops_health_check.dart';
import 'package:sotong_ware_control/widgets/remote_ops_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 9, 21, 1, 0, 0);

  RemoteAgentDoc agent({
    String state = 'idle',
    String currentJobId = '',
    String lastError = '',
    DateTime? hb,
  }) {
    return RemoteAgentDoc(
      agentId: 'agent_1',
      ownerUid: 'uid',
      deviceName: 'LAPTOP',
      state: state,
      enabled: true,
      appVersion: '2.4.1',
      currentJobId: currentJobId,
      lastError: lastError,
      lastHeartbeatAt: hb ?? now.subtract(const Duration(seconds: 10)),
    );
  }

  RemoteJobDoc job({
    String id = 'job_91c66278e88042e0',
    String status = 'running',
    String title = '50대 초보자가 AI로 첫 전자책을 만드는 방법',
  }) {
    return RemoteJobDoc(
      jobId: id,
      ownerUid: 'uid',
      instructionId: 'wi_plan_1789914868666',
      title: title,
      type: 'ebook',
      status: status,
      assignedAgentId: 'agent_1',
      currentStage: 'outline',
      updatedAt: now.subtract(const Duration(minutes: 1)),
    );
  }

  Widget dash({
    required List<RemoteAgentDoc> agents,
    List<RemoteJobDoc> jobs = const [],
    List<Sotong24RemoteProject> workshops = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RemoteOpsDashboard(
            agents: agents,
            jobs: jobs,
            workshops: workshops,
            now: now,
            onRefresh: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('1. Agent online + active job → 현재 작업 표시', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [agent(state: 'running', currentJobId: 'job_91c66278e88042e0')],
        jobs: [job()],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('50대 초보자가 AI로 첫 전자책을 만드는 방법'), findsOneWidget);
    expect(find.text('전자책'), findsOneWidget);
    expect(find.textContaining('실행 중'), findsWidgets);
  });

  testWidgets('2. Agent currentJobId 없음 → 작업 없음', (tester) async {
    await tester.pumpWidget(dash(agents: [agent(state: 'idle')]));
    await tester.pumpAndSettle();
    expect(find.text('현재 실행 중인 작업이 없습니다.'), findsOneWidget);
    expect(find.text('작업지시 대기'), findsOneWidget);
  });

  testWidgets('3. stale old job은 현재 작업으로 선택 금지', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [agent(state: 'running', currentJobId: 'job_91c66278e88042e0')],
        jobs: [
          job(),
          job(id: 'job_old_stale', status: 'running', title: '농작업 기록 앱'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('50대 초보자가 AI로 첫 전자책을 만드는 방법'), findsOneWidget);
    expect(find.text('농작업 기록 앱'), findsNothing);
  });

  testWidgets('4. worker 없음 → 미실행', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [agent(state: 'idle', currentJobId: 'job_91c66278e88042e0')],
        jobs: [job()],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('미실행'), findsOneWidget);
    expect(find.text('실행 중'), findsNothing);
  });

  testWidgets('5. heartbeat 오래됨 → 오프라인/오류', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [
          agent(state: 'idle', hb: now.subtract(const Duration(minutes: 5))),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('오프라인'), findsWidgets);
    expect(find.text('시스템 상태 · 오류'), findsOneWidget);
  });

  testWidgets('6. 정상 상태 → 불필요 경고 없음', (tester) async {
    await tester.pumpWidget(dash(agents: [agent()]));
    await tester.pumpAndSettle();
    expect(find.text('정상 동작 중'), findsOneWidget);
    expect(find.text('시스템 상태 · 오류'), findsNothing);
    expect(find.text('없음'), findsOneWidget);
  });

  testWidgets('7. 결과물/승인/APK/PDF UI 없음', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [agent(state: 'running', currentJobId: 'job_91c66278e88042e0')],
        jobs: [job()],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('지금 확인할 결과물'), findsNothing);
    expect(find.textContaining('APK'), findsNothing);
    expect(find.textContaining('PDF'), findsNothing);
    expect(find.text('사용자 승인'), findsNothing);
    expect(find.text('보완 요청'), findsNothing);
    expect(find.text('AI 제작공정에서 계속 보기'), findsNothing);
  });

  testWidgets('A1. online+running+stale lastError → 빨간 오류 아님', (tester) async {
    final a = agent(
      state: 'running',
      currentJobId: 'job_91c66278e88042e0',
      lastError: '과거 단계 실패 기록(stale)',
    );
    final health = OpsHealthCheck.evaluate(
      agents: [a],
      jobs: [job()],
      now: now,
    );
    expect(
      RemoteOpsDashboard.systemToneFor(
        online: true,
        health: health,
        job: job(),
        agent: a,
      ),
      RemoteOpsSystemTone.ok,
    );

    await tester.pumpWidget(
      dash(agents: [a], jobs: [job()]),
    );
    await tester.pumpAndSettle();
    expect(find.text('없음'), findsOneWidget);
    expect(find.text('정상 동작 중'), findsOneWidget);
    expect(find.text('시스템 상태 · 오류'), findsNothing);
    expect(find.text('시스템 상태 · 정상'), findsOneWidget);
  });

  testWidgets('A2. agent.state=error → 빨간 오류', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [
          agent(
            state: 'error',
            currentJobId: 'job_91c66278e88042e0',
            lastError: '현재 오류',
          ),
        ],
        jobs: [job()],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('시스템 상태 · 오류'), findsOneWidget);
    expect(find.text('Agent 오류 상태'), findsOneWidget);
  });

  testWidgets('A3. current Job stalled → 빨간 오류', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [
          agent(state: 'running', currentJobId: 'job_91c66278e88042e0'),
        ],
        jobs: [job(status: 'stalled')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('시스템 상태 · 오류'), findsOneWidget);
    expect(find.textContaining('stalled'), findsWidgets);
  });

  testWidgets('A4. heartbeat offline → 빨간 오류', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [
          agent(hb: now.subtract(const Duration(minutes: 10))),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('시스템 상태 · 오류'), findsOneWidget);
    expect(find.text('오프라인'), findsWidgets);
  });

  testWidgets('A5. 상단 이상 없음과 시스템 정상 일치', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [
          agent(
            state: 'running',
            currentJobId: 'job_91c66278e88042e0',
            lastError: 'old stale',
          ),
        ],
        jobs: [job()],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('없음'), findsOneWidget);
    expect(find.text('시스템 상태 · 정상'), findsOneWidget);
    expect(find.text('정상 동작 중'), findsOneWidget);
  });

  testWidgets('B. 진단정보 보기 → 즉시 시트 표시 + 이전 오류 기록', (tester) async {
    await tester.pumpWidget(
      dash(
        agents: [
          agent(
            state: 'running',
            currentJobId: 'job_91c66278e88042e0',
            lastError: '과거 실패 메시지',
          ),
        ],
        jobs: [job()],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remote_open_diagnostics_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remote_status_diagnostics_sheet')), findsOneWidget);
    expect(find.text('진단정보'), findsOneWidget);
    expect(find.text('50대 초보자가 AI로 첫 전자책을 만드는 방법'), findsWidgets);
    expect(find.text('이전 오류 기록'), findsOneWidget);
    expect(find.text('과거 실패 메시지'), findsOneWidget);
    expect(find.text('고급 진단'), findsOneWidget);
    // 고급 값은 접힌 상태라 기본 화면에 jobId 라벨만 접힘 타일에 있음
    expect(find.text('job_91c66278e88042e0'), findsNothing);
  });
}
