import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/remote_e2e_sample.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/remote_cursor_autostart_test_service.dart';
import 'package:sotong_ware_control/services/remote_e2e_sample_service.dart';
import 'package:sotong_ware_control/services/remote_work_instruction_mirror.dart';
import 'package:sotong_ware_control/widgets/remote_cursor_autostart_panel.dart';

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
    return 'job_cursor_1';
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

  final clock = DateTime.utc(2026, 8, 16, 12);

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

  group('RemoteCursorAutostart markers / E2E isolation', () {
    test('existing E2E notes do not include cursor:required', () {
      final e2e = RemoteE2eSampleService();
      final id = e2e.generateInstructionId(now: clock);
      final wi = e2e.buildSampleWorkInstruction(instructionId: id, now: clock);
      expect(wi.notes, contains('[environment:test]'));
      expect(wi.notes, contains('[isTest:true]'));
      expect(RemoteE2eSampleMarkers.notesRequireCursor(wi.notes), isFalse);
      expect(RemoteE2eSampleMarkers.notesRequireCodex(wi.notes), isFalse);
      expect(wi.notes, isNot(contains('[cursor:required]')));
      expect(wi.notes, isNot(contains('[codex:required]')));
      expect(
        RemoteCursorAutostartMarkers.isCursorTestInstructionId(id),
        isFalse,
      );
    });

    test('Cursor TEST notes include all required markers', () {
      final svc = RemoteCursorAutostartTestService();
      final id = svc.generateInstructionId(
        now: clock.add(const Duration(minutes: 1)),
      );
      expect(id, startsWith('wi_test_remote_e2e_cursor_'));
      expect(RemoteE2eSampleMarkers.isTestInstructionId(id), isTrue);
      final wi = svc.buildCursorTestWorkInstruction(
        instructionId: id,
        now: clock,
      );
      expect(wi.notes, contains('[environment:test]'));
      expect(wi.notes, contains('[isTest:true]'));
      expect(wi.notes, contains('[cursor:required]'));
      expect(RemoteE2eSampleMarkers.notesRequireCursor(wi.notes), isTrue);
      expect(RemoteE2eSampleMarkers.notesRequireCodex(wi.notes), isFalse);
      expect(wi.notes, isNot(contains('[codex:required]')));
      expect(wi.artifactType, ArtifactType.ebook);
      expect(wi.workflowSteps.length, 18);
    });

    test('instructionId does not collide with plain E2E id', () {
      final e2e = RemoteE2eSampleService();
      final cursor = RemoteCursorAutostartTestService();
      final a = e2e.generateInstructionId(now: clock);
      final b = cursor.generateInstructionId(now: clock);
      expect(a, isNot(b));
      expect(a.contains('cursor_'), isFalse);
      expect(b, startsWith('wi_test_remote_e2e_cursor_'));
    });

    test(
      'WorkInstructionValidator accepts Cursor TEST via createSample',
      () async {
        final svc = RemoteCursorAutostartTestService(
          mirror: RemoteWorkInstructionMirrorService(memory: {}),
        );
        final session = await svc.createSample(
          now: clock.add(const Duration(minutes: 2)),
        );
        final wiJson = jsonDecode(session.jsonText) as Map<String, dynamic>;
        expect(wiJson['notes'], contains('[cursor:required]'));
        expect(session.instructionId, startsWith('wi_test_remote_e2e_cursor_'));
      },
    );
  });

  group('RemoteCursorAutostartTestService send', () {
    test('create + send START_JOB payload keeps cursor marker', () async {
      final api = _FakeApi();
      final svc = RemoteCursorAutostartTestService(
        mirror: RemoteWorkInstructionMirrorService(memory: {}),
      );
      final session = await svc.createSample(
        now: clock.add(const Duration(minutes: 3)),
      );
      expect(
        RemoteCursorAutostartMarkers.isCursorTestInstructionId(
          session.instructionId,
        ),
        isTrue,
      );
      final decoded = jsonDecode(session.jsonText) as Map<String, dynamic>;
      expect(RemoteCursorAutostartMarkers.isCursorTestPayload(decoded), isTrue);

      final e2e = RemoteE2eSampleService();
      final e2eWi = e2e.buildSampleWorkInstruction(
        instructionId: e2e.generateInstructionId(now: clock),
        now: clock,
      );
      expect(RemoteE2eSampleMarkers.notesRequireCursor(e2eWi.notes), isFalse);

      final updated = await svc.sendToAgent(
        session: session,
        agent: agent(),
        api: api,
        jobs: const [],
      );
      expect(api.createCalls, 1);
      expect(api.startCalls, 1);
      expect(
        RemoteE2eSampleMarkers.notesRequireCursor(
          '${api.lastPayload!['notes']}',
        ),
        isTrue,
      );
      expect(updated.isSent, isTrue);
      expect(updated.sentJobId, 'job_cursor_1');
    });

    test('duplicate send is blocked', () async {
      final api = _FakeApi();
      final svc = RemoteCursorAutostartTestService(
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
  });

  group('RemoteCursorAutostartPanel UI', () {
    testWidgets('shows warning and create action; no overflow at 320', (
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
        sendBlockedReason: '먼저 Cursor 자동실행 TEST를 생성하세요.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: RemoteCursorAutostartPanel(
                  view: view,
                  busy: false,
                  onCreate: () {},
                  onViewContent: () {},
                  onSendToAgent: () {},
                  onReset: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cursor 자동실행 TEST'), findsOneWidget);
      expect(find.text('Cursor 자동실행 TEST 만들기'), findsOneWidget);
      expect(find.textContaining('Cursor를 종료한 상태'), findsWidgets);
      expect(find.text('샘플 작업지시서 E2E 테스트'), findsNothing);
      expect(errors, isEmpty);
    });
  });
}
