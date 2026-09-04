import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/plan_execution_status.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/plan_user_facing_status.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/services/sotong24_workshop_presentation.dart';
import 'package:sotong_ware_control/services/work_instruction_remote_delivery.dart';

import 'support/commercial_fixtures.dart';

void main() {
  final now = DateTime.now().toUtc();

  RemoteAgentDoc onlineAgent({String id = 'agent_1', String name = 'JT-JEON'}) {
    return RemoteAgentDoc(
      agentId: id,
      ownerUid: 'uid',
      deviceName: name,
      state: 'idle',
      enabled: true,
      lastHeartbeatAt: now.subtract(const Duration(seconds: 5)),
    );
  }

  RemoteAgentDoc offlineAgent() {
    return RemoteAgentDoc(
      agentId: 'agent_off',
      ownerUid: 'uid',
      deviceName: 'OFF',
      state: 'idle',
      enabled: true,
      lastHeartbeatAt: now.subtract(const Duration(minutes: 10)),
    );
  }

  RemoteJobDoc job({
    required String id,
    required String instructionId,
    String status = 'queued',
  }) {
    return RemoteJobDoc(
      jobId: id,
      ownerUid: 'uid',
      title: 't',
      type: 'ebook',
      status: status,
      assignedAgentId: 'agent_1',
      instructionId: instructionId,
    );
  }

  WorkInstruction wi({String id = 'wi_plan_x', AiExecutionPolicy? ai}) {
    return WorkInstruction(
      schemaVersion: '1.1',
      instructionId: id,
      projectId: 'plan_x',
      instructionVersion: '1',
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      businessIdea: 'AI 학습 도우미 활용법 전자책',
      businessPurpose: 'p',
      customerProblem: 'pr',
      targetCustomer: 'c',
      deliverableTypes: const ['ebook'],
      recommendedSequence: const ['ebook'],
      valueProposition: 'v',
      requiredMaterials: const [],
      workflowSteps: const [],
      completionCriteria: const [],
      qualityChecks: const [],
      risks: const [],
      monetizationOptions: const [],
      deploymentTargets: const [],
      promotionChannels: const [],
      approvalItems: const [],
      executionStatus: '지시서 준비',
      artifactType: ArtifactType.ebook,
      aiExecution: ai,
      commercialQuality: CommercialFixtures.forTrack(ArtifactType.ebook),
    );
  }

  BusinessPlanDocument planDoc() {
    return BusinessPlanDocument(
      id: 'plan_1786083242850',
      input: const BusinessPlanInput(
        topic: 'AI 학습 도우미 활용법 전자책',
        artifactType: ArtifactType.ebook,
        deliverableTypes: [ArtifactType.ebook],
        targetCustomer: '학생',
        customerProblem: '문제',
        desiredOutcome: '결과',
      ),
      status: PlanningStatus.instructionReady,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      instructionId: 'wi_plan_1786083242850',
      instruction: wi(id: 'wi_plan_1786083242850'),
    );
  }

  group('classify A-E', () {
    const iid = 'wi_plan_1786083242850';
    test('A. no job', () {
      expect(
        WorkInstructionRemoteDelivery.classify(),
        RemoteDeliveryCase.createAll,
      );
    });
    test('B. job without START_JOB', () {
      expect(
        WorkInstructionRemoteDelivery.classify(
          job: job(id: 'j1', instructionId: iid),
        ),
        RemoteDeliveryCase.repairCommand,
      );
    });
    test('C. START_JOB exists', () {
      expect(
        WorkInstructionRemoteDelivery.classify(
          job: job(id: 'j1', instructionId: iid),
          start: const RemoteCommandDoc(
            commandId: 'c1',
            jobId: 'j1',
            type: 'START_JOB',
          ),
        ),
        RemoteDeliveryCase.reuse,
      );
    });
    test('D. claimed', () {
      expect(
        WorkInstructionRemoteDelivery.classify(
          job: job(id: 'j1', instructionId: iid, status: 'claimed'),
          start: const RemoteCommandDoc(
            commandId: 'c1',
            jobId: 'j1',
            type: 'START_JOB',
          ),
        ),
        RemoteDeliveryCase.blockedInProgress,
      );
      expect(
        WorkInstructionRemoteDelivery.wouldCreateJob(
          RemoteDeliveryCase.blockedInProgress,
        ),
        isFalse,
      );
    });
    test('E. completed', () {
      expect(
        WorkInstructionRemoteDelivery.classify(
          job: job(id: 'j1', instructionId: iid, status: 'completed'),
          start: const RemoteCommandDoc(
            commandId: 'c1',
            jobId: 'j1',
            type: 'START_JOB',
          ),
        ),
        RemoteDeliveryCase.blockedCompleted,
      );
      expect(
        WorkInstructionRemoteDelivery.wouldCreateCommand(
          RemoteDeliveryCase.blockedCompleted,
        ),
        isFalse,
      );
    });
  });

  group('delivered UI contract', () {
    test('1. job 실패 → delivered 금지', () {
      final failed = WorkInstructionRemoteDelivery.markFailed(
        plan: planDoc(),
        result: RemoteDeliveryResult.failed(
          userMessage: '전송 실패. 다시 시도가 필요합니다.',
          errorCode: 'job_failed',
        ),
      );
      final exec = PlanExecutionStatusResolver.resolve(failed);
      expect(failed.hasRemoteDelivery, isFalse);
      expect(PlanProgressStatus.isTrulyTransferred(failed), isFalse);
      expect(exec.primaryStatusLabel, '전송 실패');
      expect(exec.productionProgressLine, '다시 시도 필요');
      expect(PlanUserFacingStatus.label(failed, execution: exec), '전송 실패');
    });

    test('2. START_JOB 실패 → delivered 금지', () {
      final failed = WorkInstructionRemoteDelivery.markFailed(
        plan: planDoc(),
        result: RemoteDeliveryResult.failed(
          userMessage: '전송 실패. 다시 시도가 필요합니다.',
          errorCode: 'start_failed',
          jobId: 'job_only',
        ),
      );
      expect(failed.status, PlanningStatus.transferFailed);
      expect(PlanProgressStatus.isTrulyTransferred(failed), isFalse);
    });

    test('3. Job+START_JOB 성공 → delivered', () {
      final ok = WorkInstructionRemoteDelivery.markDelivered(
        plan: planDoc(),
        result: const RemoteDeliveryResult(
          delivered: true,
          jobId: 'job_1',
          commandId: 'cmd_1',
          agentId: 'agent_1',
          outcome: 'created',
        ),
      );
      expect(ok.hasRemoteDelivery, isTrue);
      expect(PlanProgressStatus.isTrulyTransferred(ok), isTrue);
      expect(
        PlanExecutionStatusResolver.resolve(ok).primaryStatusLabel,
        isNot('전송 실패'),
      );
    });
  });

  group('WorkInstructionRemoteDeliveryService', () {
    late _FakeApi api;
    late List<RemoteJobDoc> jobs;
    late Map<String, List<RemoteCommandDoc>> commands;
    late List<RemoteAgentDoc> agents;

    WorkInstructionRemoteDeliveryService service() {
      return WorkInstructionRemoteDeliveryService(
        api: api,
        jobsProvider: () async => jobs,
        commandsProvider: (id) async => commands[id] ?? const [],
        agentsProvider: () async => agents,
      );
    }

    Map<String, dynamic> payload() => wi(id: 'wi_plan_1786083242850').toJson();

    setUp(() {
      api = _FakeApi();
      jobs = [];
      commands = {};
      agents = [onlineAgent()];
    });

    test('1. Job 실패 → not delivered', () async {
      api.failJob = true;
      final r = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      expect(r.delivered, isFalse);
      expect(api.createCount, 1);
      expect(api.startCount, 0);
    });

    test('2. Job 성공 + START_JOB 실패 → not delivered', () async {
      api.failStart = true;
      final r = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      expect(r.delivered, isFalse);
      expect(r.jobId, isNotEmpty);
      expect(r.commandId, isEmpty);
      expect(api.createCount, 1);
      expect(api.startCount, 1);
    });

    test('3. Job+START_JOB 성공', () async {
      final r = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      expect(r.delivered, isTrue);
      expect(r.jobId, isNotEmpty);
      expect(r.commandId, isNotEmpty);
      expect(api.createCount, 1);
      expect(api.startCount, 1);
    });

    test(
      '4. 같은 instruction 재시도 → duplicate Job 없음 (already_transferred)',
      () async {
        jobs = [job(id: 'job_keep', instructionId: 'wi_plan_1786083242850')];
        commands['job_keep'] = const [
          RemoteCommandDoc(
            commandId: 'cmd_keep',
            jobId: 'job_keep',
            type: 'START_JOB',
          ),
        ];
        final r = await service().deliver(
          instructionId: 'wi_plan_1786083242850',
          title: 't',
          type: 'ebook',
          payload: payload(),
        );
        expect(r.delivered, isTrue);
        expect(r.jobId, 'job_keep');
        expect(r.commandId, 'cmd_keep');
        expect(api.createCount, 0);
        expect(api.startCount, 0);
      },
    );

    test('5. Job 존재 + command 없음 → command만 복구', () async {
      jobs = [job(id: 'job_fix', instructionId: 'wi_plan_1786083242850')];
      final r = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      expect(r.delivered, isTrue);
      expect(r.jobId, 'job_fix');
      expect(r.outcome, 'command_repaired');
      expect(api.createCount, 0);
      expect(api.startCount, 1);
    });

    test('6. START_JOB 이미 존재 → duplicate command 없음', () async {
      jobs = [job(id: 'job_keep', instructionId: 'wi_plan_1786083242850')];
      commands['job_keep'] = const [
        RemoteCommandDoc(
          commandId: 'cmd_keep',
          jobId: 'job_keep',
          type: 'START_JOB',
        ),
      ];
      await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      final again = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      expect(again.commandId, 'cmd_keep');
      expect(api.startCount, 0);
    });

    test('7. claimed → 재전송 금지', () async {
      jobs = [
        job(
          id: 'job_run',
          instructionId: 'wi_plan_1786083242850',
          status: 'claimed',
        ),
      ];
      commands['job_run'] = const [
        RemoteCommandDoc(
          commandId: 'cmd_run',
          jobId: 'job_run',
          type: 'START_JOB',
        ),
      ];
      final r = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      expect(r.delivered, isTrue);
      expect(r.outcome, 'already_transferred');
      expect(api.createCount, 0);
      expect(api.startCount, 0);
    });

    test('8. legacy non-AI WI는 toggle OFF면 aiExecution 추가 안 함', () {
      expect(
        WorkInstructionRemoteDelivery.shouldAttachPilot(
          toggleOn: false,
          instruction: wi(),
        ),
        isFalse,
      );
      final json = wi().toJson();
      expect(json.containsKey('aiExecution'), isFalse);
    });

    test('9. pilot WI / orphan repair는 고정 정책', () {
      expect(
        WorkInstructionRemoteDelivery.shouldAttachPilot(
          toggleOn: true,
          instruction: wi(),
        ),
        isTrue,
      );
      final attached = WorkInstructionRemoteDelivery.attachPilotAiExecution(
        wi(id: 'wi_plan_1786083242850').toJson(),
      );
      final parsed = AiExecutionPolicy.tryParse(attached)!;
      expect(parsed.enabled, isTrue);
      expect(parsed.worker, 'cursor');
      expect(parsed.maxAutoStageOrder, 1);
      expect(parsed.approvalRequired, isTrue);
      expect(parsed.artifactUploadEnabled, isTrue);
      expect(parsed.autoAdvance, isFalse);
      expect(parsed.deploymentAllowed, isFalse);
    });

    test('11. Agent 없음', () async {
      agents = [offlineAgent()];
      final r = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 't',
        type: 'ebook',
        payload: payload(),
      );
      expect(r.delivered, isFalse);
      expect(r.errorCode, 'agent_offline');
      expect(api.createCount, 0);
    });

    test('12. orphan fixture retry → Job 1 + START_JOB 1', () async {
      expect(
        WorkInstructionRemoteDelivery.findJob(jobs, 'wi_plan_1786083242850'),
        isNull,
      );
      final r = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 'AI 학습 도우미 활용법 전자책',
        type: 'ebook',
        payload: payload(),
      );
      expect(r.delivered, isTrue);
      expect(api.createCount, 1);
      expect(api.startCount, 1);
      jobs = [job(id: r.jobId, instructionId: 'wi_plan_1786083242850')];
      commands[r.jobId] = [
        RemoteCommandDoc(
          commandId: r.commandId,
          jobId: r.jobId,
          type: 'START_JOB',
        ),
      ];
      final again = await service().deliver(
        instructionId: 'wi_plan_1786083242850',
        title: 'AI 학습 도우미 활용법 전자책',
        type: 'ebook',
        payload: payload(),
      );
      expect(again.jobId, r.jobId);
      expect(api.createCount, 1);
    });
  });

  test('10. AI 제작공정은 sotong24work_projects만 — Job 없는 WI는 목록에 없음', () {
    final listed = [
      Sotong24RemoteProject(
        projectId: 'wi_plan_1785905165067',
        title: '50대 초보도 따라 하는 AI 전자책 첫 출간',
        productType: 'ebook',
        currentStage: 18,
        totalStages: 18,
        progress: 90,
        status: Sotong24WorkStatus.awaitingApproval,
      ),
    ];
    final real = listed
        .where((p) => !Sotong24WorkshopPresentation.isTestProject(p))
        .toList();
    expect(real.any((p) => p.projectId == 'wi_plan_1786083242850'), isFalse);
    expect(real.single.title, contains('50대 초보'));
  });
}

class _FakeApi extends RemoteControlApi {
  _FakeApi()
    : super(
        idTokenProvider: () async => 'token',
        baseUrl: () => 'http://127.0.0.1',
      );

  bool failJob = false;
  bool failStart = false;
  int createCount = 0;
  int startCount = 0;
  String? createdJobId;
  String? createdCommandId;

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
    throw RemoteControlApiException(
      'fallback',
      code: 'not_found',
      statusCode: 404,
    );
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
    if (failJob) {
      throw RemoteControlApiException('job', code: 'job_failed');
    }
    createdJobId = 'job_$createCount';
    return createdJobId!;
  }

  @override
  Future<({String commandId, String jobId, bool idempotent})> startJob({
    required String jobId,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    startCount++;
    if (failStart) {
      throw RemoteControlApiException('start', code: 'start_failed');
    }
    createdCommandId = 'cmd_$startCount';
    return (commandId: createdCommandId!, jobId: jobId, idempotent: false);
  }
}
