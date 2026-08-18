import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/planning_wizard_state.dart';
import 'package:sotong_ware_control/services/planning_sentence_composer.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/remote_e2e_sample.dart';
import 'package:sotong_ware_control/screens/remote_control_screen.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/remote_e2e_sample_service.dart';
import 'package:sotong_ware_control/services/remote_work_instruction_mirror.dart';
import 'package:sotong_ware_control/services/remote_work_instruction_source.dart';
import 'package:sotong_ware_control/services/work_instruction_validator.dart';
import 'package:sotong_ware_control/widgets/remote_e2e_sample_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clock = DateTime.now().toUtc();
  final hbOnline = clock.subtract(const Duration(seconds: 12));
  final hbOffline = clock.subtract(const Duration(minutes: 5));

  RemoteAgentDoc agent({
    String id = 'agent_jt',
    String name = 'JT-JEON',
    DateTime? hb,
    bool enabled = true,
  }) {
    return RemoteAgentDoc(
      agentId: id,
      ownerUid: 'uid_test',
      deviceName: name,
      state: 'idle',
      enabled: enabled,
      appVersion: '2.0',
      lastHeartbeatAt: hb ?? hbOnline,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RemoteE2eSampleService', () {
    late RemoteE2eSampleService service;
    late Map<String, Map<String, dynamic>> mirrorMemory;

    setUp(() {
      mirrorMemory = {};
      service = RemoteE2eSampleService(
        mirror: RemoteWorkInstructionMirrorService(memory: mirrorMemory),
      );
    });

    test('샘플 WorkInstruction — 실제 contract·18단계·TEST 식별', () {
      const id = 'wi_test_remote_e2e_1785905165067';
      final wi = service.buildSampleWorkInstruction(
        instructionId: id,
        now: clock,
      );

      expect(RemoteE2eSampleMarkers.isTestInstructionId(id), isTrue);
      expect(wi.instructionId, id);
      expect(wi.businessIdea, RemoteE2eSampleMarkers.sampleTitle);
      expect(wi.artifactType, ArtifactType.ebook);
      expect(wi.workflowSteps.length, 18);
      expect(
        wi.workflowSteps.map((s) => s.id).toList(),
        BusinessPlanningService.standardWorkflowTitles
            .map((e) => e.$1)
            .toList(),
      );
      expect(wi.notes, contains('[environment:test]'));
      expect(wi.notes, contains('[isTest:true]'));

      const composer = PlanningSentenceComposer();
      final validation = WorkInstructionValidator().validate(
        input: composer.toBusinessPlanInput(
          PlanningWizardState(
            mode: 'quick',
            step: 4,
            artifactType: ArtifactType.ebook,
            topic: RemoteE2eSampleMarkers.sampleTitle,
            customerProblem: '[TEST] E2E',
            targetCustomer: '[TEST]',
            desiredOutcome: '[TEST]',
            sentencesManuallyEdited: true,
          ),
        ),
        instruction: wi,
      );
      expect(validation.ok, isTrue);

      final roundTrip = WorkInstruction.fromJson(wi.toJson());
      expect(roundTrip.instructionId, id);
      expect(roundTrip.workflowSteps.length, 18);
    });

    test('createSample — serialization·mirror·세션 저장', () async {
      final prefs = await SharedPreferences.getInstance();
      service = RemoteE2eSampleService(
        mirror: RemoteWorkInstructionMirrorService(memory: mirrorMemory),
        prefs: prefs,
      );

      final session = await service.createSample(
        ownerUid: 'uid_test',
        now: clock,
      );

      expect(session.instructionId, startsWith('wi_test_remote_e2e_'));
      expect(session.isCreated, isTrue);
      expect(session.isSent, isFalse);
      expect(mirrorMemory, isNotEmpty);

      final decoded = jsonDecode(session.jsonText) as Map<String, dynamic>;
      expect(RemoteE2eSampleMarkers.isTestPayload(decoded), isTrue);
      expect(decoded['workflowSteps'], isA<List>());
      expect((decoded['workflowSteps'] as List).length, 18);

      final loaded = await service.loadSession();
      expect(loaded.instructionId, session.instructionId);
    });

    test('Online Agent 우선 JT-JEON 선택·Offline 차단', () {
      final onlineJt = agent(name: 'JT-JEON', hb: hbOnline);
      final onlineOther = agent(id: 'agent_b', name: 'OTHER-PC', hb: hbOnline);
      final offlineJt = agent(name: 'JT-JEON', hb: hbOffline);

      expect(service.pickOnlineAgent([offlineJt]), isNull);
      expect(
        service.pickOnlineAgent([onlineOther, onlineJt])?.deviceName,
        'JT-JEON',
      );
      expect(service.pickOnlineAgent([onlineOther])?.deviceName, 'OTHER-PC');
    });

    test('workshop completed → phase 완료 (Job claimed이어도)', () {
      final service = RemoteE2eSampleService();
      final phase = service.resolvePhase(
        session: const RemoteE2eSampleSession(
          instructionId: 'wi_test_remote_e2e_done',
          jsonText: '{}',
          sentJobId: 'job1',
          sentAtIso: '2026-08-15T12:00:00.000Z',
        ),
        job: const RemoteJobDoc(
          jobId: 'job1',
          ownerUid: 'u',
          assignedAgentId: 'a',
          title: '[TEST] 전자책 원격제작 E2E',
          type: 'work_instruction',
          status: 'claimed',
          totalStages: 18,
          progress: 0,
        ),
        workshopStatus: 'completed',
        workshopProgressPercent: 100,
      );
      expect(phase, RemoteE2ePhase.completed);
    });

    test('Job progress 18/18 → phase 완료', () {
      final service = RemoteE2eSampleService();
      final phase = service.resolvePhase(
        session: const RemoteE2eSampleSession(
          instructionId: 'wi_test_remote_e2e_prog',
          jsonText: '{}',
          sentJobId: 'job2',
          sentAtIso: '2026-08-15T12:00:00.000Z',
        ),
        job: const RemoteJobDoc(
          jobId: 'job2',
          ownerUid: 'u',
          assignedAgentId: 'a',
          title: '[TEST] 전자책 원격제작 E2E',
          type: 'work_instruction',
          status: 'claimed',
          totalStages: 18,
          progress: 18,
        ),
      );
      expect(phase, RemoteE2ePhase.completed);
    });

    test('buildView — Offline Agent 전송 차단', () async {
      final session = await service.createSample(now: clock);
      final view = service.buildView(
        session: session,
        agents: [agent(hb: hbOffline)],
        jobs: const [],
      );
      expect(view.canSend, isFalse);
      expect(view.sendBlockedReason, contains('Online Agent'));
    });

    test('buildView — Online Agent 전송 가능', () async {
      final session = await service.createSample(now: clock);
      final view = service.buildView(
        session: session,
        agents: [agent(hb: hbOnline)],
        jobs: const [],
      );
      expect(view.canSend, isTrue);
      expect(view.phase, RemoteE2ePhase.readyToSend);
      expect(view.targetAgent?.deviceName, 'JT-JEON');
    });

    test('동일 instructionId 중복 전송 차단', () async {
      final prefs = await SharedPreferences.getInstance();
      service = RemoteE2eSampleService(
        mirror: RemoteWorkInstructionMirrorService(memory: mirrorMemory),
        prefs: prefs,
      );
      var session = await service.createSample(now: clock);
      session = session.copyWith(
        sentJobId: 'job_sent_1',
        sentAgentId: 'agent_jt',
        sentAgentName: 'JT-JEON',
        sentAtIso: clock.toIso8601String(),
      );
      await prefs.setString(
        RemoteE2eSampleService.prefsSentJobId,
        session.sentJobId,
      );

      expect(service.isDuplicateSend(session: session, jobs: const []), isTrue);

      final view = service.buildView(
        session: session,
        agents: [agent(hb: hbOnline)],
        jobs: const [],
      );
      expect(view.canSend, isFalse);
      expect(view.sendBlockedReason, contains('이미 소통24워크 Agent에 전달'));
    });

    test('sendToAgent — START_JOB payload·Relay contract 필드', () async {
      final prefs = await SharedPreferences.getInstance();
      service = RemoteE2eSampleService(
        mirror: RemoteWorkInstructionMirrorService(memory: mirrorMemory),
        prefs: prefs,
      );
      final session = await service.createSample(now: clock);
      final api = RemoteControlApi(
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('create-job')) {
            return http.Response('{"ok":true,"jobId":"job_e2e_1"}', 200);
          }
          expect(req.url.path.endsWith('start-job'), isTrue);
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final payload = body['payload'] as Map<String, dynamic>;
          expect(payload['instructionId'], session.instructionId);
          expect(RemoteE2eSampleMarkers.isTestPayload(payload), isTrue);
          expect(payload['workflowSteps'], isA<List>());
          expect(
            body['idempotencyKey'],
            startsWith('idem_${session.instructionId}'),
          );
          return http.Response(
            '{"ok":true,"commandId":"cmd_1","jobId":"job_e2e_1","idempotent":false}',
            200,
          );
        }),
        baseUrl: () => 'http://example.test',
        idTokenProvider: () async => 'tok',
      );

      final updated = await service.sendToAgent(
        session: session,
        agent: agent(hb: hbOnline),
        api: api,
        jobs: const [],
      );

      expect(updated.isSent, isTrue);
      expect(updated.sentJobId, 'job_e2e_1');
      expect(service.isDuplicateSend(session: updated, jobs: const []), isTrue);
    });

    test('sendToAgent — Offline Agent 예외', () async {
      final session = await service.createSample(now: clock);
      final api = RemoteControlApi(
        httpClient: MockClient((_) async => http.Response('{"ok":false}', 500)),
        baseUrl: () => 'http://example.test',
        idTokenProvider: () async => 'tok',
      );

      expect(
        () => service.sendToAgent(
          session: session,
          agent: agent(hb: hbOffline),
          api: api,
          jobs: const [],
        ),
        throwsA(
          isA<RemoteControlApiException>().having(
            (e) => e.code,
            'code',
            'agent_offline',
          ),
        ),
      );
    });

    test('resetSample — 새 instructionId·전송 준비', () async {
      final prefs = await SharedPreferences.getInstance();
      service = RemoteE2eSampleService(
        mirror: RemoteWorkInstructionMirrorService(memory: mirrorMemory),
        prefs: prefs,
      );
      final first = await service.createSample(now: clock);
      await prefs.setString(RemoteE2eSampleService.prefsSentJobId, 'job_old');

      final reset = await service.resetSample(ownerUid: 'uid_test');
      expect(reset.instructionId, isNot(first.instructionId));
      expect(reset.instructionId, startsWith('wi_test_remote_e2e_'));
      expect(reset.isSent, isFalse);
      expect(reset.sentJobId, isEmpty);

      final view = service.buildView(
        session: reset,
        agents: [agent(hb: hbOnline)],
        jobs: const [],
      );
      expect(view.phase, RemoteE2ePhase.readyToSend);
      expect(view.canSend, isTrue);
    });

    test('운영 wi_plan_1785905165067 — 샘플 생성·전송 로직 영향 없음', () {
      const opsId = 'wi_plan_1785905165067';
      expect(RemoteE2eSampleMarkers.isTestInstructionId(opsId), isFalse);

      final opsWi = WorkInstruction(
        schemaVersion: '1.0',
        instructionId: opsId,
        projectId: opsId,
        instructionVersion: '1',
        createdAt: clock.toIso8601String(),
        updatedAt: clock.toIso8601String(),
        businessIdea: '운영 전자책',
        businessPurpose: 'purpose',
        customerProblem: 'problem',
        targetCustomer: 'customer',
        deliverableTypes: const ['ebook'],
        recommendedSequence: const [],
        valueProposition: 'vp',
        requiredMaterials: const [],
        workflowSteps: const [],
        completionCriteria: const [],
        qualityChecks: const [],
        risks: const [],
        monetizationOptions: const [],
        deploymentTargets: const [],
        promotionChannels: const [],
        approvalItems: const [],
        executionStatus: 'draft',
        notes: '',
        primaryTrack: ArtifactType.ebook,
        followUpTracks: const [],
        artifactType: ArtifactType.ebook,
      );
      expect(RemoteE2eSampleMarkers.isTestPayload(opsWi.toJson()), isFalse);
    });
  });

  group('RemoteE2eSamplePanel UI', () {
    testWidgets('노트북 원격관제에 E2E 패널 표시', (tester) async {
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
      final e2e = RemoteE2eSampleService(
        mirror: RemoteWorkInstructionMirrorService(memory: {}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: repo,
              e2eService: e2e,
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
        find.text('개발/진단 도구'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('개발/진단 도구'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('샘플 작업지시서 E2E 테스트'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('샘플 작업지시서 E2E 테스트'), findsOneWidget);
      expect(find.text('샘플 작업지시서 생성'), findsOneWidget);
      expect(find.text('Cursor 자동실행 TEST'), findsOneWidget);
      expect(find.text('Cursor 자동실행 TEST 만들기'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Codex 무인작업 TEST'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Codex 무인작업 TEST'), findsOneWidget);
      expect(find.text('Codex TEST 만들기'), findsOneWidget);
      expect(find.text('Agent로 보내기'), findsNWidgets(3));
      expect(find.text('테스트 초기화'), findsNWidgets(3));
    });

    testWidgets('전송 후 Agent로 보내기 버튼 비활성', (tester) async {
      const sentSession = RemoteE2eSampleSession(
        instructionId: 'wi_test_remote_e2e_1',
        jsonText:
            '{"instructionId":"wi_test_remote_e2e_1","businessIdea":"[TEST] 전자책 원격제작 E2E","artifactType":"ebook","instructionVersion":"1","notes":"[environment:test][isTest:true]"}',
        sentJobId: 'job_1',
        sentAgentName: 'JT-JEON',
      );
      final view = RemoteE2eSampleView(
        session: sentSession,
        phase: RemoteE2ePhase.working,
        canSend: false,
        sendBlockedReason: '이미 소통24워크 Agent에 전달된 작업입니다. 현재 상태를 확인해 주세요.',
        currentStage: 3,
        totalStages: 18,
        detailMessage: '전송 완료 · 현재 3 / 18 단계',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteE2eSamplePanel(
              view: view,
              busy: false,
              onCreateSample: () {},
              onViewContent: () {},
              onSendToAgent: () {},
              onViewStatus: () {},
              onReset: () {},
            ),
          ),
        ),
      );

      final sendBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '전송 완료'),
      );
      expect(sendBtn.onPressed, isNull);
      expect(find.textContaining('3 / 18'), findsOneWidget);
    });

    testWidgets('현재 상태 보기 — 390px 스크롤·하단 항목 접근', (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final updatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      final view = RemoteE2eSampleView(
        session: const RemoteE2eSampleSession(
          instructionId: 'wi_test_remote_e2e_1786758821204',
          jsonText:
              '{"instructionId":"wi_test_remote_e2e_1786758821204","businessIdea":"[TEST] 전자책 원격제작 E2E","notes":"[environment:test][isTest:true]"}',
          sentJobId: 'job_2a506b5cba518917',
          sentAgentId: 'agent_jt',
          sentAgentName: 'JT-JEON',
          sentAtIso: '2026-08-15T02:00:00.000Z',
        ),
        phase: RemoteE2ePhase.received,
        targetAgent: agent(hb: hbOnline),
        linkedJob: RemoteJobDoc(
          jobId: 'job_2a506b5cba518917',
          ownerUid: 'uid_test',
          title: RemoteE2eSampleMarkers.sampleTitle,
          type: 'ebook',
          status: 'claimed',
          assignedAgentId: 'agent_jt',
          currentStage: '',
          totalStages: 18,
          progress: 0,
          updatedAt: updatedAt,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showRemoteE2eStatusSheet(context, view),
                  child: const Text('open-status'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-status'));
      await tester.pumpAndSettle();

      expect(find.text('E2E 테스트 현재 상태'), findsOneWidget);
      expect(find.text('TEST'), findsWidgets);
      expect(find.textContaining('job_2a506b5cba518917'), findsWidgets);
      expect(find.textContaining('Agent 수신'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(const Key('remote_e2e_status_footer')),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('remote_e2e_status_scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote_e2e_status_footer')), findsOneWidget);
      expect(find.textContaining('진단 참고'), findsWidgets);
      expect(find.textContaining('deferred_busy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('현재 상태 보기 — 짧은 콘텐츠·데스크톱 폭', (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      const view = RemoteE2eSampleView(
        session: RemoteE2eSampleSession(
          instructionId: 'wi_test_remote_e2e_short',
          jsonText: '{"instructionId":"wi_test_remote_e2e_short"}',
        ),
        phase: RemoteE2ePhase.readyToSend,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showRemoteE2eStatusSheet(context, view),
                  child: const Text('open-status'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-status'));
      await tester.pumpAndSettle();
      expect(find.text('E2E 테스트 현재 상태'), findsOneWidget);
      expect(find.text('미전송'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('buildRemoteE2eStatusRows', () {
    test('claimed Job — raw+한글·필드 구분', () {
      final rows = buildRemoteE2eStatusRows(
        RemoteE2eSampleView(
          session: const RemoteE2eSampleSession(
            instructionId: 'wi_test_remote_e2e_1786758821204',
            jsonText: '{}',
            sentJobId: 'job_2a506b5cba518917',
            sentAgentName: 'JT-JEON',
            sentAtIso: '2026-08-15T02:00:00.000Z',
          ),
          phase: RemoteE2ePhase.received,
          linkedJob: RemoteJobDoc(
            jobId: 'job_2a506b5cba518917',
            ownerUid: 'uid_test',
            title: RemoteE2eSampleMarkers.sampleTitle,
            type: 'ebook',
            status: 'claimed',
            assignedAgentId: 'agent_jt',
            progress: 0,
            totalStages: 18,
            updatedAt: clock,
          ),
        ),
        now: clock,
      );
      final map = {for (final r in rows) r.label: r.value};
      expect(map['Job 상태'], contains('Agent 수신'));
      expect(map['Job 상태'], contains('claimed'));
      expect(map['Job ID'], 'job_2a506b5cba518917');
      expect(map['deferred_busy'], contains('없음'));
      expect(map['오류 상세'], isNull);
      expect(map['진단 참고'], isNotNull);
    });
  });

  group('instruction source payload', () {
    test('parseJsonText·payloadMap — 실제 WorkInstruction contract', () async {
      final service = RemoteE2eSampleService(
        mirror: RemoteWorkInstructionMirrorService(memory: {}),
      );
      final wi = service.buildSampleWorkInstruction(
        instructionId: 'wi_test_remote_e2e_payload',
        now: clock,
      );
      final jsonText = jsonEncode(wi.toJson());
      final src = RemoteWorkInstructionSource();
      final ref = src.parseJsonText(jsonText, artifactHint: ArtifactType.ebook);
      expect(ref, isNotNull);
      expect(ref!.instructionId, 'wi_test_remote_e2e_payload');
      expect(ref.title, RemoteE2eSampleMarkers.sampleTitle);

      final payload = src.payloadMap(ref);
      expect(payload, isNotNull);
      expect(payload!['instructionId'], 'wi_test_remote_e2e_payload');
      expect(payload['schemaVersion'], isNotEmpty);
      expect(payload['workflowSteps'], isA<List>());
    });
  });
}
