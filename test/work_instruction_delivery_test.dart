import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/instruction_contract_validator.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/work_instruction_delivery_presentation.dart';
import 'package:sotong_ware_control/services/work_instruction_remote_delivery.dart';
import 'package:sotong_ware_control/widgets/project_design/step7_delivery_panel.dart';

void main() {
  final now = DateTime.utc(2026, 8, 18, 3, 0);

  RemoteAgentDoc onlineAgent() => RemoteAgentDoc(
    agentId: 'a1',
    ownerUid: 'u',
    deviceName: 'JT-JEON',
    state: 'idle',
    enabled: true,
    lastHeartbeatAt: now.subtract(const Duration(seconds: 8)),
  );

  RemoteAgentDoc staleAgent() => RemoteAgentDoc(
    agentId: 'a2',
    ownerUid: 'u',
    deviceName: 'STALE',
    state: 'idle',
    enabled: true,
    lastHeartbeatAt: now.subtract(const Duration(minutes: 2)),
  );

  BusinessPlanDocument transferredPlan() => BusinessPlanDocument(
    id: 'p1',
    status: PlanningStatus.transferred,
    version: 1,
    createdAt: now.toIso8601String(),
    updatedAt: now.toIso8601String(),
    lastTransferAt: now.toIso8601String(),
    lastTransferMode: PlanProgressStatus.remoteMode,
    lastRemoteJobId: 'job_1',
    lastRemoteCommandId: 'cmd_1',
    input: const BusinessPlanInput(
      topic: '테스트 전자책',
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '결과',
      artifactType: ArtifactType.ebook,
      deliverableTypes: [ArtifactType.ebook],
    ),
  );

  group('WorkInstructionDeliveryPresentation', () {
    test('online/fresh → 전달 가능 표시', () {
      final view = WorkInstructionDeliveryPresentation.agentStatus([
        onlineAgent(),
      ], now: now);
      expect(view.connectivity, AgentConnectivity.ready);
      expect(view.readinessLine, contains('전달 가능'));
      expect(view.statusLine, contains('온라인'));
    });

    test('Agent offline → 버튼 disabled', () {
      final step7 = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: const ContractValidationResult(
          level: ContractValidationLevel.valid,
          issues: [],
        ),
        agents: const [],
        transferBusy: false,
        now: now,
      );
      expect(step7.buttonEnabled, isFalse);
      expect(step7.agentStatus.connectivity, AgentConnectivity.noAgent);
    });

    test('heartbeat stale', () {
      final view = WorkInstructionDeliveryPresentation.agentStatus([
        staleAgent(),
      ], now: now);
      expect(view.connectivity, AgentConnectivity.stale);
      expect(view.readinessLine, contains('상태 확인'));
    });

    test('sent 상태 — refresh 후에도 유지', () {
      final plan = transferredPlan();
      final step7 = WorkInstructionDeliveryPresentation.resolve(
        plan: plan,
        validation: const ContractValidationResult(
          level: ContractValidationLevel.valid,
          issues: [],
        ),
        agents: [onlineAgent()],
        transferBusy: false,
        now: now,
      );
      expect(step7.buttonState, DeliveryButtonState.sent);
      expect(step7.buttonEnabled, isFalse);
      expect(step7.showSuccessPanel, isTrue);
      expect(plan.wasTransferred, isTrue);
    });

    test('timeout 실패 — 재전송 즉시 허용 안 함', () {
      final failure = WorkInstructionDeliveryPresentation.failureView(
        result: RemoteDeliveryResult.failed(
          userMessage: 'delay',
          errorCode: 'timeout',
        ),
      );
      expect(failure.kind, DeliveryFailureKind.timeout);
      expect(failure.allowRetry, isFalse);
      expect(failure.primaryAction, DeliveryDiagnosticAction.recheckStatus);
    });

    test('validation 실패 안내', () {
      const validation = ContractValidationResult(
        level: ContractValidationLevel.blocked,
        issues: [
          ContractValidationIssue(
            level: ContractValidationLevel.blocked,
            field: 'targetCustomer',
            reason: '대상 고객 세부 설명이 필요합니다.',
            fix: '입력',
          ),
        ],
      );
      final failure = WorkInstructionDeliveryPresentation.failureView(
        result: RemoteDeliveryResult.failed(
          userMessage: 'validation',
          errorCode: 'validation',
        ),
        validation: validation,
      );
      expect(failure.kind, DeliveryFailureKind.validation);
      expect(failure.primaryAction, DeliveryDiagnosticAction.validationReview);
    });
  });

  group('WorkInstructionRemoteDeliveryService reconcile', () {
    test('already_transferred — duplicate job/command 생성 안 함', () async {
      final api = _CountingApi();
      final jobs = [
        RemoteJobDoc(
          jobId: 'job_keep',
          ownerUid: 'u',
          title: 't',
          type: 'ebook',
          status: 'queued',
          assignedAgentId: 'a1',
          instructionId: 'wi_plan_x',
        ),
      ];
      final commands = {
        'job_keep': const [
          RemoteCommandDoc(
            commandId: 'cmd_keep',
            jobId: 'job_keep',
            type: 'START_JOB',
          ),
        ],
      };
      final service = WorkInstructionRemoteDeliveryService(
        api: api,
        jobsProvider: () async => jobs,
        commandsProvider: (id) async => commands[id] ?? const [],
        agentsProvider: () async => [onlineAgent()],
      );

      final r1 = await service.deliver(
        instructionId: 'wi_plan_x',
        title: 't',
        type: 'ebook',
        payload: {'instructionId': 'wi_plan_x'},
      );
      final r2 = await service.deliver(
        instructionId: 'wi_plan_x',
        title: 't',
        type: 'ebook',
        payload: {'instructionId': 'wi_plan_x'},
      );

      expect(r1.delivered, isTrue);
      expect(r2.delivered, isTrue);
      expect(r2.outcome, 'already_transferred');
      expect(api.createCount, 0);
      expect(api.startCount, 0);
    });

    test('reconcileExisting returns delivered when job+start exist', () async {
      final service = WorkInstructionRemoteDeliveryService(
        api: _CountingApi(),
        jobsProvider: () async => [
          RemoteJobDoc(
            jobId: 'job_1',
            ownerUid: 'u',
            title: 't',
            type: 'ebook',
            status: 'queued',
            assignedAgentId: 'a1',
            instructionId: 'wi_x',
          ),
        ],
        commandsProvider: (_) async => const [
          RemoteCommandDoc(
            commandId: 'cmd_1',
            jobId: 'job_1',
            type: 'START_JOB',
          ),
        ],
        agentsProvider: () async => [onlineAgent()],
      );
      final r = await service.reconcileExisting(instructionId: 'wi_x');
      expect(r?.delivered, isTrue);
      expect(r?.commandId, 'cmd_1');
    });
  });

  testWidgets('Step7DeliveryPanel — sent UI + 버튼 disabled', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final step7 = WorkInstructionDeliveryPresentation.resolve(
      plan: transferredPlan(),
      validation: const ContractValidationResult(
        level: ContractValidationLevel.valid,
        issues: [],
      ),
      agents: [onlineAgent()],
      transferBusy: false,
      now: now,
    );

    var transferCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Step7DeliveryPanel(
              view: step7,
              onTransfer: () => transferCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('planning_delivery_success')), findsOneWidget);
    expect(find.text('작업지시 내용 보기'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('planning_transfer_button')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('✓ 전달 완료'), findsOneWidget);
    expect(transferCount, 0);
  });

  testWidgets('Step7DeliveryPanel — double tap 전송 1회', (tester) async {
    var transferCount = 0;
    var busy = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final view = WorkInstructionDeliveryPresentation.resolve(
                plan: null,
                validation: const ContractValidationResult(
                  level: ContractValidationLevel.valid,
                  issues: [],
                ),
                agents: [onlineAgent()],
                transferBusy: busy,
                now: now,
              );
              return Step7DeliveryPanel(
                view: view,
                onTransfer: () async {
                  if (busy) return;
                  setState(() => busy = true);
                  transferCount++;
                  await Future<void>.delayed(const Duration(milliseconds: 100));
                  setState(() => busy = false);
                },
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('planning_transfer_button')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('planning_transfer_button')));
    await tester.tap(find.byKey(const Key('planning_transfer_button')));
    await tester.pump();
    expect(transferCount, 1);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  });

  testWidgets('Step7DeliveryPanel — 390px overflow 없음', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final failure = WorkInstructionDeliveryPresentation.failureView(
      result: RemoteDeliveryResult.failed(
        userMessage: 'offline',
        errorCode: 'agent_offline',
      ),
    );
    final step7 = DeliveryStep7View(
      agentStatus: WorkInstructionDeliveryPresentation.agentStatus(
        const [],
        now: now,
      ),
      buttonState: DeliveryButtonState.failed,
      buttonLabel: '상태 재확인',
      buttonEnabled: false,
      showSuccessPanel: false,
      failure: failure,
      validationLines: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: Step7DeliveryPanel(view: step7)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('planning_delivery_failure')), findsOneWidget);
  });
}

class _CountingApi extends RemoteControlApi {
  _CountingApi()
    : super(
        idTokenProvider: () async => 'token',
        baseUrl: () => 'http://127.0.0.1',
      );

  int createCount = 0;
  int startCount = 0;

  @override
  Future<({String jobId, String commandId, String agentId, String outcome})>
  deliverInstruction({
    required String instructionId,
    required String type,
    required String title,
    required String assignedAgentId,
    required Map<String, dynamic> payload,
    int totalStages = 18,
  }) async {
    throw RemoteControlApiException('x', code: 'not_found', statusCode: 404);
  }

  @override
  Future<String> createJob({
    required String type,
    required String title,
    required String assignedAgentId,
    int totalStages = 18,
    String? instructionId,
  }) async {
    createCount++;
    return 'job_$createCount';
  }

  @override
  Future<({String commandId, String jobId, bool idempotent})> startJob({
    required String jobId,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    startCount++;
    return (commandId: 'cmd_$startCount', jobId: jobId, idempotent: false);
  }
}
