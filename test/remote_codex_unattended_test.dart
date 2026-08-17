import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/remote_e2e_sample.dart';
import 'package:sotong_ware_control/services/remote_codex_unattended_test_service.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/remote_cursor_autostart_test_service.dart';
import 'package:sotong_ware_control/services/remote_e2e_sample_service.dart';
import 'package:sotong_ware_control/services/remote_work_instruction_mirror.dart';
import 'package:sotong_ware_control/widgets/remote_codex_unattended_panel.dart';

class _FakeApi extends RemoteControlApi {
  Map<String, dynamic>? lastPayload;
  var createCalls = 0;
  var startCalls = 0;

  @override
  Future<String> createJob({
    required String type,
    required String title,
    required String assignedAgentId,
    int totalStages = 0,
    String? instructionId,
  }) async {
    createCalls++;
    return 'job_codex_1';
  }

  @override
  Future<({String commandId, String jobId, bool idempotent})> startJob({
    required String jobId,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    startCalls++;
    lastPayload = payload;
    return (commandId: 'cmd_1', jobId: jobId, idempotent: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clock = DateTime.utc(2026, 8, 16, 14);

  RemoteAgentDoc agent() => RemoteAgentDoc(
    agentId: 'agent_jt',
    ownerUid: 'uid_test',
    deviceName: 'JT-JEON',
    state: 'idle',
    enabled: true,
    appVersion: '2.0',
    lastHeartbeatAt: DateTime.now().toUtc(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RemoteCodexUnattended markers / isolation', () {
    test('lightweight E2E notes have no codex/cursor markers', () {
      final e2e = RemoteE2eSampleService();
      final id = e2e.generateInstructionId(now: clock);
      final wi = e2e.buildSampleWorkInstruction(instructionId: id, now: clock);
      expect(wi.notes, contains('[environment:test]'));
      expect(wi.notes, contains('[isTest:true]'));
      expect(RemoteE2eSampleMarkers.notesRequireCodex(wi.notes), isFalse);
      expect(RemoteE2eSampleMarkers.notesRequireCursor(wi.notes), isFalse);
      expect(
        RemoteCodexUnattendedMarkers.isCodexTestInstructionId(id),
        isFalse,
      );
    });

    test('Cursor TEST notes have no codex marker', () {
      final cursor = RemoteCursorAutostartTestService();
      final id = cursor.generateInstructionId(now: clock);
      final wi = cursor.buildCursorTestWorkInstruction(
        instructionId: id,
        now: clock,
      );
      expect(RemoteE2eSampleMarkers.notesRequireCursor(wi.notes), isTrue);
      expect(RemoteE2eSampleMarkers.notesRequireCodex(wi.notes), isFalse);
      expect(wi.notes, isNot(contains('[codex:required]')));
    });

    test('Codex TEST notes include required markers only', () {
      final svc = RemoteCodexUnattendedTestService();
      final id = svc.generateInstructionId(
        now: clock.add(const Duration(minutes: 1)),
      );
      expect(id, startsWith('wi_test_remote_e2e_codex_'));
      expect(RemoteE2eSampleMarkers.isTestInstructionId(id), isTrue);
      final wi = svc.buildCodexTestWorkInstruction(
        instructionId: id,
        now: clock,
      );
      expect(wi.notes, contains('[environment:test]'));
      expect(wi.notes, contains('[isTest:true]'));
      expect(wi.notes, contains('[codex:required]'));
      expect(wi.notes, isNot(contains('[cursor:required]')));
      expect(RemoteE2eSampleMarkers.notesRequireCodex(wi.notes), isTrue);
      expect(RemoteE2eSampleMarkers.notesRequireCursor(wi.notes), isFalse);
      expect(
        wi.notes,
        contains(RemoteCodexUnattendedMarkers.expectedOutputPath),
      );
      expect(wi.notes, contains('git 금지'));
      expect(wi.artifactType, ArtifactType.ebook);
      expect(wi.workflowSteps.length, 18);
      expect(wi.businessIdea, RemoteCodexUnattendedMarkers.sampleTitle);
    });

    test('instructionId / title do not collide across TEST types', () {
      final e2e = RemoteE2eSampleService();
      final cursor = RemoteCursorAutostartTestService();
      final codex = RemoteCodexUnattendedTestService();
      final a = e2e.generateInstructionId(now: clock);
      final b = cursor.generateInstructionId(now: clock);
      final c = codex.generateInstructionId(now: clock);
      expect({a, b, c}.length, 3);
      expect(a.contains('codex_'), isFalse);
      expect(b.contains('codex_'), isFalse);
      expect(c, startsWith('wi_test_remote_e2e_codex_'));
      expect(
        RemoteE2eSampleMarkers.sampleTitle,
        isNot(RemoteCodexUnattendedMarkers.sampleTitle),
      );
      expect(
        RemoteCursorAutostartMarkers.sampleTitle,
        isNot(RemoteCodexUnattendedMarkers.sampleTitle),
      );
    });

    test(
      'WorkInstructionValidator accepts Codex TEST via createSample',
      () async {
        final svc = RemoteCodexUnattendedTestService(
          mirror: RemoteWorkInstructionMirrorService(memory: {}),
        );
        final session = await svc.createSample(
          now: clock.add(const Duration(minutes: 2)),
        );
        final wiJson = jsonDecode(session.jsonText) as Map<String, dynamic>;
        expect(wiJson['notes'], contains('[codex:required]'));
        expect(wiJson['notes'], isNot(contains('[cursor:required]')));
        expect(session.instructionId, startsWith('wi_test_remote_e2e_codex_'));
      },
    );
  });

  group('RemoteCodexUnattendedTestService send', () {
    test('create + send START_JOB payload keeps codex marker', () async {
      final api = _FakeApi();
      final svc = RemoteCodexUnattendedTestService(
        mirror: RemoteWorkInstructionMirrorService(memory: {}),
      );
      final session = await svc.createSample(
        now: clock.add(const Duration(minutes: 3)),
      );
      expect(
        RemoteCodexUnattendedMarkers.isCodexTestInstructionId(
          session.instructionId,
        ),
        isTrue,
      );
      final decoded = jsonDecode(session.jsonText) as Map<String, dynamic>;
      expect(RemoteCodexUnattendedMarkers.isCodexTestPayload(decoded), isTrue);

      final updated = await svc.sendToAgent(
        session: session,
        agent: agent(),
        api: api,
        jobs: const [],
      );
      expect(api.createCalls, 1);
      expect(api.startCalls, 1);
      expect(
        api.lastPayload!['businessIdea'] ?? api.lastPayload!['title'],
        RemoteCodexUnattendedMarkers.sampleTitle,
      );
      expect(
        RemoteE2eSampleMarkers.notesRequireCodex(
          '${api.lastPayload!['notes']}',
        ),
        isTrue,
      );
      expect(
        RemoteE2eSampleMarkers.notesRequireCursor(
          '${api.lastPayload!['notes']}',
        ),
        isFalse,
      );
      expect(updated.isSent, isTrue);
      expect(updated.sentJobId, 'job_codex_1');
    });

    test('duplicate send is blocked', () async {
      final api = _FakeApi();
      final svc = RemoteCodexUnattendedTestService(
        mirror: RemoteWorkInstructionMirrorService(memory: {}),
      );
      final session = await svc.createSample(
        now: clock.add(const Duration(minutes: 4)),
      );
      final sent = await svc.sendToAgent(
        session: session,
        agent: agent(),
        api: api,
        jobs: const [],
      );
      expect(
        () => svc.sendToAgent(
          session: sent,
          agent: agent(),
          api: api,
          jobs: const [],
        ),
        throwsA(isA<RemoteControlApiException>()),
      );
      expect(api.startCalls, 1);
    });

    test('prefs keys do not overlap with E2E or Cursor', () {
      expect(
        RemoteCodexUnattendedTestService.prefsInstructionId,
        isNot(RemoteE2eSampleService.prefsInstructionId),
      );
      expect(
        RemoteCodexUnattendedTestService.prefsInstructionId,
        isNot(RemoteCursorAutostartTestService.prefsInstructionId),
      );
      expect(
        RemoteCodexUnattendedTestService.prefsJsonText,
        isNot(RemoteCursorAutostartTestService.prefsJsonText),
      );
    });
  });

  group('RemoteCodexUnattendedPanel UI', () {
    testWidgets('shows TEST badge and actions; no overflow at 320', (
      tester,
    ) async {
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.toString().contains('overflowed')) errors.add(d);
        old?.call(d);
      };
      addTearDown(() => FlutterError.onError = old);

      const view = RemoteE2eSampleView(
        session: RemoteE2eSampleSession(),
        phase: RemoteE2ePhase.notCreated,
        canSend: false,
        sendBlockedReason: '먼저 Codex 무인작업 TEST를 생성하세요.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: RemoteCodexUnattendedPanel(
                  view: view,
                  busy: false,
                  onCreate: () {},
                  onViewContent: () {},
                  onSendToAgent: () {},
                  onViewStatus: () {},
                  onReset: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Codex 무인작업 TEST'), findsOneWidget);
      expect(find.text('CODEX · TEST'), findsOneWidget);
      expect(find.text('Codex TEST 만들기'), findsOneWidget);
      expect(find.text('현재 상태'), findsOneWidget);
      expect(find.textContaining('휴대폰 전송만으로'), findsWidgets);
      expect(find.text('샘플 작업지시서 E2E 테스트'), findsNothing);
      expect(find.text('Cursor 자동실행 TEST'), findsNothing);
      expect(errors, isEmpty);
    });
  });
}
