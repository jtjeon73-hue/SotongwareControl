import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/workshop_current_work_selection.dart';

void main() {
  final now = DateTime.parse('2026-09-21T12:00:00.000Z');

  Sotong24RemoteProject project({
    required String id,
    required String title,
    required String status,
    String productType = 'ebook',
    String updatedAt = '2026-09-20T00:00:00.000Z',
    bool isTest = false,
    List<Sotong24RemoteStage>? stages,
  }) {
    return Sotong24RemoteProject(
      projectId: id,
      title: title,
      productType: productType,
      currentStage: 1,
      totalStages: 18,
      progress: 10,
      status: status,
      approvalStatus: status == Sotong24WorkStatus.awaitingApproval
          ? ApprovalStatus.pending
          : ApprovalStatus.notRequired,
      isTest: isTest,
      updatedAt: updatedAt,
      lastActivityAt: updatedAt,
      stages:
          stages ??
          [
            Sotong24RemoteStage(
              stageId: 'idea_clarify',
              stageNumber: 1,
              stageName: '아이디어 정리',
              status: status,
              approvalRequired: status == Sotong24WorkStatus.awaitingApproval,
              criteriaMet: status == Sotong24WorkStatus.awaitingApproval,
              approvalStatus: status == Sotong24WorkStatus.awaitingApproval
                  ? ApprovalStatus.pending
                  : ApprovalStatus.notRequired,
            ),
          ],
    );
  }

  RemoteJobDoc job({
    required String jobId,
    required String instructionId,
    required String title,
    required String status,
    String type = 'ebook',
    String stage = 'idea_clarify',
    DateTime? updatedAt,
  }) {
    return RemoteJobDoc(
      jobId: jobId,
      ownerUid: 'owner',
      title: title,
      type: type,
      status: status,
      assignedAgentId: 'agent_1',
      instructionId: instructionId,
      currentStage: stage,
      progress: 5,
      updatedAt: updatedAt ?? DateTime.parse('2026-09-21T00:00:00.000Z'),
    );
  }

  RemoteAgentDoc agent({
    required String currentJobId,
    DateTime? heartbeat,
    bool online = true,
  }) {
    return RemoteAgentDoc(
      agentId: 'agent_1',
      ownerUid: 'owner',
      deviceName: 'Work PC',
      state: 'running',
      enabled: true,
      currentJobId: currentJobId,
      lastHeartbeatAt: online
          ? (heartbeat ?? now.subtract(const Duration(seconds: 10)))
          : now.subtract(const Duration(hours: 2)),
    );
  }

  group('WorkshopCurrentWorkSelection', () {
    test('A: Agent.currentJobId=ebook + old site stale running → ebook 선택', () {
      final oldSite = project(
        id: 'wi_plan_site_old',
        title: 'SotongWare 산업자동화 소프트웨어 제작 서비스 사이트',
        status: Sotong24WorkStatus.awaitingApproval,
        productType: 'site',
        updatedAt: '2026-09-08T00:00:00.000Z',
        stages: const [
          Sotong24RemoteStage(
            stageId: 'site_user_review',
            stageNumber: 15,
            stageName: '사용자 검토 패키지',
            status: Sotong24WorkStatus.awaitingApproval,
            approvalRequired: true,
            criteriaMet: true,
            approvalStatus: ApprovalStatus.pending,
            reviewDecision: '',
          ),
        ],
      );
      final ebookJob = job(
        jobId: 'job_91c66278e88042e0',
        instructionId: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: 'running',
        stage: 'idea_clarify',
        updatedAt: DateTime.parse('2026-09-21T01:00:00.000Z'),
      );
      // old site job이 더 최근 updatedAt + running 이어도 Agent 점유가 ebook이면 ebook 승
      final staleSiteJob = job(
        jobId: 'job_site_stale',
        instructionId: 'wi_plan_site_old',
        title: 'SotongWare 산업자동화 소프트웨어 제작 서비스 사이트',
        status: 'running',
        type: 'site',
        stage: 'site_user_review',
        updatedAt: DateTime.parse('2026-09-21T11:00:00.000Z'),
      );

      final dash = WorkshopCurrentWorkSelection.build(
        projects: [oldSite],
        jobs: [staleSiteJob, ebookJob],
        agents: [agent(currentJobId: 'job_91c66278e88042e0')],
        now: now,
      );

      expect(dash.current?.jobId, 'job_91c66278e88042e0');
      expect(dash.current?.title, contains('전자책'));
      expect(dash.current?.syncing, isTrue);
      expect(
        dash.needsAttention.any((p) => p.projectId == 'wi_plan_site_old'),
        isTrue,
      );
    });

    test('B: old site awaiting/on_hold → 현재 제작 제외', () {
      final oldSite = project(
        id: 'wi_plan_site_old',
        title: 'SotongWare 산업자동화 소프트웨어 제작 서비스 사이트',
        status: Sotong24WorkStatus.awaitingApproval,
        productType: 'site',
        updatedAt: '2026-09-08T00:00:00.000Z',
        stages: const [
          Sotong24RemoteStage(
            stageId: 'site_user_review',
            stageNumber: 15,
            stageName: '사용자 검토 패키지',
            status: Sotong24WorkStatus.awaitingApproval,
            approvalRequired: true,
            criteriaMet: true,
            approvalStatus: ApprovalStatus.pending,
            reviewDecision: 'on_hold',
          ),
        ],
      );
      final staleSiteJob = job(
        jobId: 'job_site_stale',
        instructionId: 'wi_plan_site_old',
        title: oldSite.title,
        status: 'running',
        type: 'site',
        updatedAt: DateTime.parse('2026-09-21T11:00:00.000Z'),
      );

      final dash = WorkshopCurrentWorkSelection.build(
        projects: [oldSite],
        jobs: [staleSiteJob],
        agents: const [],
        now: now,
      );

      expect(dash.current, isNull);
      expect(dash.needsAttention.map((p) => p.projectId), ['wi_plan_site_old']);
    });

    test('C: ebook project mirror 없음 → syncing placeholder', () {
      final ebookJob = job(
        jobId: 'job_91c66278e88042e0',
        instructionId: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: 'running',
        stage: 'idea_clarify',
      );
      final dash = WorkshopCurrentWorkSelection.build(
        projects: const [],
        jobs: [ebookJob],
        agents: [agent(currentJobId: 'job_91c66278e88042e0')],
        now: now,
      );
      expect(dash.current, isNotNull);
      expect(dash.current!.syncing, isTrue);
      expect(dash.current!.project, isNull);
      expect(dash.current!.statusLabel, '제작공정 동기화 중');
      expect(dash.current!.title, contains('전자책'));
      expect(dash.current!.stageLine, 'idea_clarify');
    });

    test('D: Agent currentJobId 비어 있음 → live job fallback', () {
      final ebookJob = job(
        jobId: 'job_91c66278e88042e0',
        instructionId: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: 'running',
        updatedAt: DateTime.parse('2026-09-21T02:00:00.000Z'),
      );
      final queued = job(
        jobId: 'job_queued',
        instructionId: 'wi_q',
        title: '대기',
        status: 'queued',
        updatedAt: DateTime.parse('2026-09-21T03:00:00.000Z'),
      );
      final dash = WorkshopCurrentWorkSelection.build(
        projects: const [],
        jobs: [queued, ebookJob],
        agents: [
          agent(currentJobId: ''),
        ],
        now: now,
      );
      expect(dash.current?.jobId, 'job_91c66278e88042e0');
    });

    test('최신 active remote job 우선 — running ebook이 stale app보다 앞선다', () {
      final staleApp = project(
        id: 'wi_plan_farm_old',
        title: '농작업 기록 앱 앱',
        status: Sotong24WorkStatus.inProgress,
        productType: 'app',
        updatedAt: '2026-09-10T00:00:00.000Z',
      );
      final ebookProject = project(
        id: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: Sotong24WorkStatus.inProgress,
        updatedAt: '2026-09-21T01:00:00.000Z',
      );
      final ebookJob = job(
        jobId: 'job_91c66278e88042e0',
        instructionId: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: 'running',
        stage: 'idea_clarify',
        updatedAt: DateTime.parse('2026-09-21T02:00:00.000Z'),
      );
      final oldJob = job(
        jobId: 'job_farm_old',
        instructionId: 'wi_plan_farm_old',
        title: '농작업 기록 앱 앱',
        status: 'cancelled',
        type: 'app',
        updatedAt: DateTime.parse('2026-09-10T00:00:00.000Z'),
      );

      final dash = WorkshopCurrentWorkSelection.build(
        projects: [staleApp, ebookProject],
        jobs: [oldJob, ebookJob],
      );

      expect(dash.current?.jobId, 'job_91c66278e88042e0');
      expect(dash.current?.instructionId, 'wi_plan_1789914868666');
      expect(dash.current?.title, contains('전자책'));
      expect(dash.current?.syncing, isFalse);
      expect(
        dash.history.any((p) => p.projectId == 'wi_plan_farm_old'),
        isTrue,
      );
    });

    test('stale project만 있고 active job이 없으면 현재 제작에 올리지 않는다', () {
      final stale = project(
        id: 'wi_plan_farm_old',
        title: '농작업 기록 앱 앱',
        status: Sotong24WorkStatus.inProgress,
        productType: 'app',
      );
      final dash = WorkshopCurrentWorkSelection.build(
        projects: [stale],
        jobs: const [],
      );
      expect(dash.current, isNull);
      expect(dash.history.map((p) => p.projectId), ['wi_plan_farm_old']);
    });

    test('job/project merge — 동일 instructionId면 한 카드로 병합', () {
      final ebookProject = project(
        id: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: Sotong24WorkStatus.inProgress,
      );
      final ebookJob = job(
        jobId: 'job_91c66278e88042e0',
        instructionId: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: 'running',
      );
      final dash = WorkshopCurrentWorkSelection.build(
        projects: [ebookProject],
        jobs: [ebookJob],
        agents: [agent(currentJobId: 'job_91c66278e88042e0')],
        now: now,
      );
      expect(dash.current!.syncing, isFalse);
      expect(dash.current!.project?.projectId, 'wi_plan_1789914868666');
      expect(dash.current!.jobId, 'job_91c66278e88042e0');
      expect(dash.history, isEmpty);
      expect(dash.needsAttention, isEmpty);
    });

    test('awaiting review는 현재 제작에서 제외하고 확인 필요 섹션으로', () {
      final awaiting = project(
        id: 'wi_await',
        title: '승인 대기 전자책',
        status: Sotong24WorkStatus.awaitingApproval,
      );
      final runningJob = job(
        jobId: 'job_run',
        instructionId: 'wi_run',
        title: '실행 중',
        status: 'running',
      );
      final awaitingJob = job(
        jobId: 'job_await',
        instructionId: 'wi_await',
        title: '승인 대기 전자책',
        status: 'waiting_approval',
      );
      final dash = WorkshopCurrentWorkSelection.build(
        projects: [awaiting],
        jobs: [awaitingJob, runningJob],
      );
      expect(dash.current?.jobId, 'job_run');
      expect(dash.needsAttention.map((p) => p.projectId), ['wi_await']);
    });

    test('completed는 완료 섹션으로 분리', () {
      final done = project(
        id: 'wi_done',
        title: '완료 전자책',
        status: Sotong24WorkStatus.completed,
      );
      final runningJob = job(
        jobId: 'job_run',
        instructionId: 'wi_run',
        title: '실행 중',
        status: 'running',
      );
      final dash = WorkshopCurrentWorkSelection.build(
        projects: [done],
        jobs: [runningJob],
      );
      expect(dash.current?.jobId, 'job_run');
      expect(dash.completed.map((p) => p.projectId), ['wi_done']);
    });

    test('running > queued 우선순위', () {
      final queued = job(
        jobId: 'job_q',
        instructionId: 'wi_q',
        title: '대기',
        status: 'queued',
        updatedAt: DateTime.parse('2026-09-21T03:00:00.000Z'),
      );
      final running = job(
        jobId: 'job_r',
        instructionId: 'wi_r',
        title: '실행',
        status: 'running',
        updatedAt: DateTime.parse('2026-09-21T01:00:00.000Z'),
      );
      final picked = WorkshopCurrentWorkSelection.pickCurrentExecutionJob([
        queued,
        running,
      ]);
      expect(picked?.jobId, 'job_r');
    });

    test('terminal job은 현재 후보에서 제외', () {
      final cancelled = job(
        jobId: 'job_c',
        instructionId: 'wi_c',
        title: '취소',
        status: 'cancelled',
      );
      final failed = job(
        jobId: 'job_f',
        instructionId: 'wi_f',
        title: '실패',
        status: 'failed',
      );
      final completed = job(
        jobId: 'job_done',
        instructionId: 'wi_done',
        title: '완료',
        status: 'completed',
      );
      expect(
        WorkshopCurrentWorkSelection.pickCurrentExecutionJob([
          cancelled,
          failed,
          completed,
        ]),
        isNull,
      );
    });

    test('updatedAt만 최근인 stale site running이 Agent ebook보다 우선하지 않는다', () {
      final ebookJob = job(
        jobId: 'job_91c66278e88042e0',
        instructionId: 'wi_plan_1789914868666',
        title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        status: 'running',
        updatedAt: DateTime.parse('2026-09-10T00:00:00.000Z'),
      );
      final siteJob = job(
        jobId: 'job_site_newer_ts',
        instructionId: 'wi_site',
        title: '사이트',
        status: 'running',
        type: 'site',
        updatedAt: DateTime.parse('2026-09-21T11:59:00.000Z'),
      );
      final picked = WorkshopCurrentWorkSelection.pickCurrentExecutionJob(
        [siteJob, ebookJob],
        agents: [agent(currentJobId: 'job_91c66278e88042e0')],
        now: now,
      );
      expect(picked?.jobId, 'job_91c66278e88042e0');
    });
  });
}
