import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sotong_ware_control/config/remote_control_env.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/screens/remote_control_screen.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/remote_work_instruction_source.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 12, 0, 0, 0);

  RemoteAgentDoc agent({
    String state = 'idle',
    DateTime? hb,
    String id = 'agent_1',
  }) {
    return RemoteAgentDoc(
      agentId: id,
      ownerUid: 'uid_a',
      deviceName: 'LAPTOP-TEST',
      state: state,
      enabled: true,
      appVersion: '2.0',
      lastHeartbeatAt: hb ?? now.subtract(const Duration(seconds: 8)),
    );
  }

  group('online helpers', () {
    test('online within threshold', () {
      final a = agent(hb: now.subtract(const Duration(seconds: 30)));
      expect(a.isOnline(now: now), isTrue);
    });

    test('offline beyond threshold', () {
      final a = agent(hb: now.subtract(const Duration(seconds: 120)));
      expect(a.isOnline(now: now), isFalse);
    });

    test('relative labels', () {
      expect(
        formatRelativeKo(now.subtract(const Duration(seconds: 2)), now: now),
        '방금 전',
      );
      expect(
        formatRelativeKo(now.subtract(const Duration(seconds: 12)), now: now),
        '12초 전',
      );
      expect(
        formatRelativeKo(now.subtract(const Duration(minutes: 5)), now: now),
        '5분 전',
      );
    });

    test('state labels', () {
      expect(agent(state: 'idle').stateLabelKo, '작업지시 대기');
      expect(
        agent(state: 'running', hb: DateTime.now().toUtc()).uiKind,
        RemoteAgentUiKind.running,
      );
      expect(
        agent(state: 'waiting_approval', hb: DateTime.now().toUtc()).uiKind,
        RemoteAgentUiKind.waitingApproval,
      );
    });
  });

  group('RemoteControlApi', () {
    test('createPairing success', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/api/control/create-pairing');
        expect(req.headers['Authorization'], 'Bearer test-id-token');
        return http.Response(
          '{"ok":true,"sessionId":"pair_1","pairingCode":"ABCD1234","expiresAt":"2026-08-12T00:10:00.000Z","ttlSeconds":600}',
          200,
        );
      });
      final api = RemoteControlApi(
        httpClient: client,
        baseUrl: () => 'http://example.test',
        idTokenProvider: () async => 'test-id-token',
      );
      final r = await api.createPairing();
      expect(r.pairingCode, 'ABCD1234');
    });

    test('auth failure maps to friendly message', () async {
      final client = MockClient(
        (_) async => http.Response('{"ok":false,"error":"unauthorized"}', 401),
      );
      final api = RemoteControlApi(
        httpClient: client,
        baseUrl: () => 'http://example.test',
        idTokenProvider: () async => 'tok',
      );
      expect(
        () => api.createJob(type: 'ebook', title: 't', assignedAgentId: 'a'),
        throwsA(
          isA<RemoteControlApiException>().having(
            (e) => e.userMessage,
            'msg',
            contains('인증'),
          ),
        ),
      );
    });

    test('create-job and start-job', () async {
      var n = 0;
      final client = MockClient((req) async {
        n++;
        if (req.url.path.endsWith('create-job')) {
          return http.Response('{"ok":true,"jobId":"job_1"}', 200);
        }
        return http.Response(
          '{"ok":true,"commandId":"cmd_1","jobId":"job_1","idempotent":false}',
          200,
        );
      });
      final api = RemoteControlApi(
        httpClient: client,
        baseUrl: () => 'http://example.test',
        idTokenProvider: () async => 'tok',
      );
      final jobId = await api.createJob(
        type: 'ebook',
        title: '책',
        assignedAgentId: 'agent_1',
      );
      final start = await api.startJob(
        jobId: jobId,
        payload: {'instructionId': 'wi_1', 'title': '책'},
        idempotencyKey: 'idem_1',
      );
      expect(jobId, 'job_1');
      expect(start.commandId, 'cmd_1');
      expect(n, 2);
    });
  });

  group('instruction source', () {
    test('parse json and list memory', () async {
      final src = RemoteWorkInstructionSource(
        memoryCatalog: [
          const ActiveWorkInstructionRef(
            artifactType: 'ebook',
            instructionId: 'wi_demo',
            title: '데모 전자책',
            jsonText:
                '{"instructionId":"wi_demo","title":"데모 전자책","version":1}',
          ),
        ],
      );
      final list = await src.listActive('ebook');
      expect(list, hasLength(1));
      expect(list.first.title, '데모 전자책');
      final parsed = src.parseJsonText(
        '{"instructionId":"wi_x","title":"X","artifactType":"app","version":2}',
      );
      expect(parsed?.artifactType, 'app');
      expect(src.payloadMap(list.first)?['instructionId'], 'wi_demo');
    });
  });

  group('widgets', () {
    test('menu label and online threshold', () {
      expect(ControlDestination.sotong24RemoteControl.label, '노트북 원격관제');
      expect(RemoteControlEnv.onlineThresholdSeconds, 90);
    });

    testWidgets('E2E sample panel visible', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(forceMemory: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: repo,
              api: RemoteControlApi(
                httpClient: MockClient(
                  (_) async => http.Response('{"ok":false}', 500),
                ),
                idTokenProvider: () async => 't',
              ),
              instructionSource: RemoteWorkInstructionSource(memoryCatalog: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('개발/진단 도구'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('개발/진단 도구'));
      await tester.pumpAndSettle();
      expect(find.text('샘플 작업지시서 E2E 테스트'), findsOneWidget);
      expect(find.text('샘플 작업지시서 생성'), findsOneWidget);
      expect(find.text('Cursor 자동실행 TEST'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Codex 무인작업 TEST'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Codex 무인작업 TEST'), findsOneWidget);
    });

    testWidgets('empty agents shows connect CTA', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(forceMemory: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: repo,
              api: RemoteControlApi(
                httpClient: MockClient(
                  (_) async => http.Response('{"ok":false}', 500),
                ),
                idTokenProvider: () async => 't',
              ),
              instructionSource: RemoteWorkInstructionSource(memoryCatalog: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('노트북 Agent 연결하기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('연결된 노트북 Agent가 없습니다'), findsOneWidget);
      expect(find.text('노트북 Agent 연결하기'), findsOneWidget);
    });

    testWidgets('agent online idle card', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(
        forceMemory: true,
        memoryAgents: [
          agent(
            hb: DateTime.now().toUtc().subtract(const Duration(seconds: 5)),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: repo,
              api: RemoteControlApi(
                httpClient: MockClient(
                  (_) async => http.Response('{"ok":false}', 500),
                ),
                idTokenProvider: () async => 't',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Agent 상태 자세히'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Agent 상태 자세히'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('작업 보내기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('작업지시 대기'), findsWidgets);
      expect(find.text('작업 보내기'), findsOneWidget);
    });

    testWidgets('offline agent disables send', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(
        forceMemory: true,
        memoryAgents: [
          agent(
            hb: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: repo,
              api: RemoteControlApi(
                httpClient: MockClient(
                  (_) async => http.Response('{"ok":false}', 500),
                ),
                idTokenProvider: () async => 't',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Agent 상태 자세히'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Agent 상태 자세히'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('작업 보내기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '작업 보내기'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('job list shows running filter content', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(
        forceMemory: true,
        memoryAgents: [agent()],
        memoryJobs: [
          RemoteJobDoc(
            jobId: 'job_1',
            ownerUid: 'uid_a',
            title: '50대 초보도 따라 하는 AI 전자책',
            type: 'ebook',
            status: 'running',
            assignedAgentId: 'agent_1',
            currentStage: 'draft',
            progress: 50,
            updatedAt: DateTime.now().toUtc(),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: repo,
              api: RemoteControlApi(
                httpClient: MockClient(
                  (_) async => http.Response('{"ok":false}', 500),
                ),
                idTokenProvider: () async => 't',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('작업 내역 자세히'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('작업 내역 자세히'));
      await tester.pumpAndSettle();
      expect(find.textContaining('50대'), findsWidgets);
      expect(find.textContaining('상태:'), findsWidgets);
    });

    testWidgets('pairing sheet creates code', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(forceMemory: true);
      final api = RemoteControlApi(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"ok":true,"sessionId":"pair_1","pairingCode":"XY12AB34","expiresAt":"${DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String()}","ttlSeconds":600}',
            200,
          ),
        ),
        idTokenProvider: () async => 'tok',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(repository: repo, api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('노트북 Agent 연결하기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('노트북 Agent 연결하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('새 연결 코드 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('XY12AB34'), findsOneWidget);
      expect(find.text('코드 복사'), findsOneWidget);
    });

    testWidgets('narrow layout no overflow smoke', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(
        forceMemory: true,
        memoryAgents: [agent()],
        memoryJobs: List.generate(
          3,
          (i) => RemoteJobDoc(
            jobId: 'job_$i',
            ownerUid: 'uid_a',
            title: '작업 $i 제목이 조금 길어도 줄바꿈',
            type: 'ebook',
            status: i == 0 ? 'waiting_approval' : 'completed',
            assignedAgentId: 'agent_1',
            progress: i * 10,
            updatedAt: DateTime.now().toUtc(),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: repo,
              api: RemoteControlApi(
                httpClient: MockClient(
                  (_) async => http.Response('{"ok":false}', 500),
                ),
                idTokenProvider: () async => 't',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
