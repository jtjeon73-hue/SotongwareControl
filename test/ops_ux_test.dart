import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/ai_business_analysis_screen.dart';
import 'package:sotong_ware_control/screens/remote_control_screen.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/widgets/ops_health_panel.dart';
import 'package:sotong_ware_control/widgets/remote_ops_dashboard.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now().toUtc();

  RemoteAgentDoc liveAgent() => RemoteAgentDoc(
    agentId: 'agent_1',
    ownerUid: 'uid',
    deviceName: 'LAPTOP-TEST',
    state: 'idle',
    enabled: true,
    lastHeartbeatAt: now.subtract(const Duration(seconds: 5)),
  );

  Widget remoteScreen({
    required RemoteAgentRepository repo,
    Sotong24RemoteRepository? workshop,
    ValueChanged<ControlDestination>? onNavigate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: RemoteControlScreen(
          repository: repo,
          workshopRepository: workshop,
          onNavigate: onNavigate,
          api: RemoteControlApi(
            httpClient: MockClient(
              (_) async => http.Response('{"ok":false}', 500),
            ),
            idTokenProvider: () async => 't',
          ),
        ),
      ),
    );
  }

  testWidgets('작업지시 제작소 wizard 흐름과 전송 전 관리 UI 최소화', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('사업유형 선택'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('이전'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('임시 저장'), findsNothing);
    expect(find.textContaining('instructionId'), findsNothing);
    expect(find.text('작업지시 JSON 붙여넣기'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('artifact-ebook')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artifact-ebook')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('다음'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('대상 고객'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('원격관제 Agent 상세에 작업 보내기 없고 제작소 이동만', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    ControlDestination? dest;
    final repo = RemoteAgentRepository(
      forceMemory: true,
      memoryAgents: [liveAgent()],
    );

    await tester.pumpWidget(
      remoteScreen(repo: repo, onNavigate: (d) => dest = d),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Agent 상태 자세히'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Agent 상태 자세히'));
    await tester.pumpAndSettle();

    expect(find.text('작업 보내기'), findsNothing);
    expect(find.text('작업지시 제작소로 이동'), findsOneWidget);
    await tester.tap(find.text('작업지시 제작소로 이동'));
    expect(dest, ControlDestination.aiBusinessAnalysis);
  });

  testWidgets('현재 작업에서 AI 제작공정 바로가기', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    ControlDestination? dest;
    final agentRepo = RemoteAgentRepository(
      forceMemory: true,
      memoryAgents: [liveAgent()],
    );
    final workshop = Sotong24RemoteRepository(
      forceMemory: true,
      memorySeed: [
        Sotong24RemoteProject(
          projectId: 'wi_live_ops',
          title: '50대 AI 활용 입문',
          productType: 'ebook',
          currentStage: 1,
          totalStages: 18,
          progress: 10,
          status: Sotong24WorkStatus.inProgress,
        ),
      ],
    );
    addTearDown(workshop.dispose);

    await tester.pumpWidget(
      remoteScreen(
        repo: agentRepo,
        workshop: workshop,
        onNavigate: (d) => dest = d,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('50대 AI 활용 입문'), findsOneWidget);
    expect(find.text('AI 제작공정에서 계속 보기'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('AI 제작공정에서 계속 보기'),
      find.byType(ListView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 제작공정에서 계속 보기'));
    expect(dest, ControlDestination.productWorkshop);
  });

  testWidgets('진단 결과 정상/확인 필요/문제 표시와 GPT 메모', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      remoteScreen(repo: RemoteAgentRepository(forceMemory: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('문제 있음'), findsWidgets);
    expect(find.text('Agent 연결 테스트'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('개발/진단 도구'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('개발/진단 도구'));
    await tester.pumpAndSettle();

    expect(find.byType(OpsHealthPanel), findsOneWidget);
    expect(find.text('정상'), findsWidgets);
    expect(find.text('문제 있음'), findsWidgets);
    expect(find.text('GPT에 알려줄 문제 해결 메모 복사'), findsOneWidget);
    expect(find.text('전체 자동 점검'), findsOneWidget);
  });

  testWidgets('테스트 필요 없을 때 정상 표시', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteOpsDashboard(
            agents: [liveAgent()],
            workshops: const [],
            onRefresh: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('시스템 정상 · 별도 테스트 필요 없음'), findsOneWidget);
    expect(find.text('현재 진행 중인 작업이 없습니다.'), findsOneWidget);
  });

  testWidgets('모바일 390px overflow 없음', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = RemoteAgentRepository(
      forceMemory: true,
      memoryAgents: [liveAgent()],
      memoryJobs: [
        RemoteJobDoc(
          jobId: 'job_1',
          ownerUid: 'uid',
          title: '50대 AI 활용 입문',
          type: 'ebook',
          status: 'completed',
          assignedAgentId: 'agent_1',
          currentStage: 'publish',
          startedAt: now.subtract(const Duration(minutes: 40)),
          completedAt: now.subtract(const Duration(minutes: 22)),
        ),
      ],
    );

    await tester.pumpWidget(remoteScreen(repo: repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
