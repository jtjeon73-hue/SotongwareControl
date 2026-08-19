import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/services/sotong24_workshop_presentation.dart';
import 'package:sotong_ware_control/widgets/sotong24_stage_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Sotong24RemoteProject project({
    required String id,
    required String title,
    required String status,
    int currentStage = 1,
    String stageStatus = Sotong24WorkStatus.ready,
    String approvalStatus = ApprovalStatus.notRequired,
    String stageApproval = ApprovalStatus.notRequired,
    String resultUrl = '',
    List<Sotong24RemoteStage>? stages,
  }) {
    return Sotong24RemoteProject(
      projectId: id,
      title: title,
      productType: 'ebook',
      currentStage: currentStage,
      totalStages: 18,
      progress: 0,
      status: status,
      approvalStatus: approvalStatus,
      stages:
          stages ??
          [
            Sotong24RemoteStage(
              stageId: 'idea_clarify',
              stageNumber: 1,
              stageName: '아이디어 정리',
              status: stageStatus,
              approvalRequired:
                  Sotong24UserFacingStatus.normalize(stageStatus) ==
                  Sotong24WorkStatus.awaitingApproval,
              criteriaMet:
                  Sotong24UserFacingStatus.normalize(stageStatus) ==
                  Sotong24WorkStatus.awaitingApproval,
              approvalStatus: stageApproval,
              resultUrl: resultUrl,
            ),
            for (var i = 2; i <= 18; i++)
              Sotong24RemoteStage(
                stageId: 's$i',
                stageNumber: i,
                stageName: '단계 $i',
                status: Sotong24WorkStatus.ready,
              ),
          ],
    );
  }

  group('Sotong24WorkshopPresentation', () {
    test('실제/TEST 분리 및 제목', () {
      final real = project(
        id: 'wi_plan_1785905165067',
        title: '50대 초보도 따라 하는 AI 전자책 첫 출간',
        status: Sotong24WorkStatus.inProgress,
      );
      final codex = project(
        id: 'wi_test_remote_e2e_codex_1786877899287',
        title: '[TEST] Codex 무인작업',
        status: Sotong24WorkStatus.ready,
        stageStatus: Sotong24WorkStatus.awaitingApproval,
      );
      final cursor = project(
        id: 'wi_test_remote_e2e_cursor_1',
        title: '[TEST] Cursor 자동실행',
        status: Sotong24WorkStatus.inProgress,
      );
      final vague = project(
        id: 'wi_test_remote_e2e_999',
        title: 'E2E',
        status: Sotong24WorkStatus.inProgress,
      );

      expect(Sotong24WorkshopPresentation.isTestProject(real), isFalse);
      expect(
        Sotong24WorkshopPresentation.testKind(codex),
        WorkshopTestKind.codex,
      );
      expect(
        Sotong24WorkshopPresentation.testKind(cursor),
        WorkshopTestKind.cursor,
      );
      expect(
        Sotong24WorkshopPresentation.testKind(vague),
        WorkshopTestKind.e2e,
      );
      expect(
        Sotong24WorkshopPresentation.displayTitle(codex),
        '[TEST] Codex 무인작업',
      );
      expect(
        Sotong24WorkshopPresentation.displayTitle(vague),
        '[TEST] 단계진행 E2E',
      );
      expect(
        Sotong24WorkshopPresentation.displayTitle(real),
        '50대 초보도 따라 하는 AI 전자책 첫 출간',
      );
    });

    test('project ready + stage awaiting → 승인 대기', () {
      final p = project(
        id: 'wi_test_remote_e2e_codex_1',
        title: '[TEST] Codex 무인작업',
        status: Sotong24WorkStatus.ready,
        stageStatus: Sotong24WorkStatus.awaitingApproval,
        stageApproval: ApprovalStatus.pending,
        resultUrl:
            'https://storage.googleapis.com/sotongware-control.appspot.com/a.md',
      );
      expect(p.userFacingStatus, Sotong24WorkStatus.awaitingApproval);
      expect(p.userFacingStatusLabel, '승인 대기');
      expect(p.showApprovalActions, isTrue);
      expect(p.nowTodoHeadline(), '결과물을 확인한 뒤 승인 또는 보완을 선택하세요.');
      expect(Sotong24WorkshopPresentation.currentStageLine(p), '1단계 · 아이디어 정리');
      final stats = Sotong24StageStats.fromProject(p);
      expect(stats.awaiting, 1);
    });

    test('waiting_approval alias → 승인 대기', () {
      final p = project(
        id: 'wi_plan_1',
        title: '운영',
        status: 'waiting_approval',
        stageStatus: 'waiting_approval',
      );
      expect(p.userFacingStatusLabel, '승인 대기');
      expect(p.showApprovalActions, isTrue);
    });

    test('승인 제출 후 Agent 적용 전에는 승인 대기를 유지하고 버튼을 숨긴다', () {
      final p = project(
        id: 'wi_plan_approval_inflight',
        title: '운영 승인 반영 중',
        status: Sotong24WorkStatus.awaitingApproval,
        stageStatus: Sotong24WorkStatus.awaitingApproval,
        stageApproval: ApprovalStatus.approved,
      );
      expect(p.userFacingStatus, Sotong24WorkStatus.awaitingApproval);
      expect(p.showApprovalActions, isFalse);
      expect(p.nowTodoHeadline(), '승인 요청을 전송했습니다. Agent가 다음 단계를 준비 중입니다.');
    });

    test('awaiting_user_approval / pending_review alias → 승인 대기', () {
      final a = project(
        id: 'wi_plan_1786083242850',
        title: '운영 r2',
        status: 'awaiting_user_approval',
        stageStatus: 'pending_review',
      );
      expect(a.userFacingStatus, Sotong24WorkStatus.awaitingApproval);
      expect(a.userFacingStatusLabel, '승인 대기');
      expect(a.showApprovalActions, isTrue);
    });

    test('criteriaMet=false이면 승인 대기 표시여도 버튼을 숨긴다', () {
      final p = project(
        id: 'wi_plan_incomplete_gate',
        title: '완료기준 동기화 중',
        status: Sotong24WorkStatus.awaitingApproval,
        stages: const [
          Sotong24RemoteStage(
            stageId: 'problem_validate',
            stageNumber: 2,
            stageName: '고객 문제 검증',
            status: Sotong24WorkStatus.awaitingApproval,
            approvalRequired: true,
            criteriaMet: false,
            approvalStatus: ApprovalStatus.pending,
          ),
        ],
        currentStage: 2,
      );
      expect(p.userFacingStatus, Sotong24WorkStatus.awaitingApproval);
      expect(p.showApprovalActions, isFalse);
    });

    test('revision 필드가 있으면 결과 버전을 표시한다', () {
      final p = project(
        id: 'wi_plan_1786083242850',
        title: '운영 r2',
        status: 'waiting_approval',
        stageStatus: 'waiting_approval',
        stages: [
          Sotong24RemoteStage(
            stageId: 'idea_clarify',
            stageNumber: 1,
            stageName: '아이디어 정리',
            status: 'waiting_approval',
            revision: 2,
          ),
        ],
      );
      expect(Sotong24WorkshopPresentation.revisionLine(p), '결과 버전 r2');
    });

    test('revision 미보고면 결과 버전을 만들지 않는다', () {
      final p = project(
        id: 'wi_plan_1',
        title: '운영',
        status: 'waiting_approval',
        stageStatus: 'waiting_approval',
      );
      expect(Sotong24WorkshopPresentation.revisionLine(p), '');
    });

    test('workDurationMs 없으면 작업시간을 만들지 않는다', () {
      final p = project(
        id: 'wi_plan_1',
        title: '운영',
        status: Sotong24WorkStatus.inProgress,
        stageStatus: Sotong24WorkStatus.inProgress,
      );
      expect(
        Sotong24WorkshopPresentation.stageDurationLine(p.currentStageDoc!),
        '',
      );
      expect(Sotong24WorkshopPresentation.totalWorkDurationLine(p), '');
      expect(
        Sotong24WorkshopPresentation.stageTimingDetailNote(p.currentStageDoc!),
        '작업시간 기록 없음',
      );
    });

    test('startedAt·completedAt만 있어도 workDurationMs 없으면 작업시간 미표시', () {
      final stage = Sotong24RemoteStage(
        stageId: 'idea_clarify',
        stageNumber: 1,
        stageName: '아이디어 정리',
        status: Sotong24WorkStatus.awaitingApproval,
        startedAt: '2026-08-18T00:00:00.000Z',
        completedAt: '2026-08-18T00:18:00.000Z',
      );
      expect(Sotong24WorkshopPresentation.stageDurationLine(stage), '');
    });

    test('workDurationMs가 있으면 작업시간을 표시한다', () {
      final stage = Sotong24RemoteStage(
        stageId: 'idea_clarify',
        stageNumber: 1,
        stageName: '아이디어 정리',
        status: Sotong24WorkStatus.completed,
        workDurationMs: 440000,
        revision: 2,
      );
      expect(
        Sotong24WorkshopPresentation.stageDurationLine(stage),
        '작업시간 7분 20초',
      );
      expect(Sotong24WorkshopPresentation.stageRevisionLine(stage), '결과 버전 r2');
      final p = project(
        id: 'wi_plan_1',
        title: '운영',
        status: Sotong24WorkStatus.completed,
        stages: [stage],
      );
      expect(
        Sotong24WorkshopPresentation.totalWorkDurationLine(p),
        '전체 누적 작업시간: 7분 20초',
      );
    });

    test('상태별 지금 할 일', () {
      expect(
        project(
          id: 'a',
          title: 't',
          status: Sotong24WorkStatus.inProgress,
          stageStatus: Sotong24WorkStatus.inProgress,
        ).nowTodoHeadline(),
        contains('AI가 작업 중'),
      );
      expect(
        project(
          id: 'b',
          title: 't',
          status: Sotong24WorkStatus.revision,
          stageStatus: Sotong24WorkStatus.revision,
        ).nowTodoHeadline(),
        contains('보완'),
      );
      expect(
        project(
          id: 'c',
          title: 't',
          status: Sotong24WorkStatus.completed,
          currentStage: 18,
          stages: [
            for (var i = 1; i <= 18; i++)
              Sotong24RemoteStage(
                stageId: 's$i',
                stageNumber: i,
                stageName: '단계 $i',
                status: Sotong24WorkStatus.completed,
              ),
          ],
        ).nowTodoHeadline(),
        '작업이 완료되었습니다.',
      );
      expect(
        project(
          id: 'd',
          title: 't',
          status: Sotong24WorkStatus.ready,
        ).nowTodoHeadline(),
        contains('다음 단계 시작'),
      );
    });

    test('instructionId는 displayTitle에 노출되지 않음', () {
      final p = project(
        id: 'wi_test_remote_e2e_codex_1786877899287',
        title: '[TEST] Codex 무인작업',
        status: Sotong24WorkStatus.awaitingApproval,
        stageStatus: Sotong24WorkStatus.awaitingApproval,
      );
      expect(
        Sotong24WorkshopPresentation.displayTitle(p),
        isNot(contains('wi_test_remote_e2e_codex_1786877899287')),
      );
    });
  });

  group('ProductWorkshopScreen UX', () {
    testWidgets('실제/TEST 섹션 분리 + Codex 제목 + 승인 대기', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [
          project(
            id: 'wi_plan_real',
            title: '50대 초보도 따라 하는 AI 전자책 첫 출간',
            status: Sotong24WorkStatus.inProgress,
            stageStatus: Sotong24WorkStatus.inProgress,
          ),
          project(
            id: 'wi_test_remote_e2e_codex_1786877899287',
            title: '[TEST] Codex 무인작업',
            status: Sotong24WorkStatus.awaitingApproval,
            approvalStatus: ApprovalStatus.pending,
            stageStatus: Sotong24WorkStatus.awaitingApproval,
            stageApproval: ApprovalStatus.pending,
            resultUrl:
                'https://storage.googleapis.com/sotongware-control.appspot.com/x.md',
          ),
        ],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('진행 중'), findsWidgets);
      expect(find.text('개발/테스트 작업 보기'), findsOneWidget);
      expect(find.text('50대 초보도 따라 하는 AI 전자책 첫 출간'), findsWidgets);
      expect(find.textContaining('wi_test_remote_e2e_codex_'), findsNothing);

      await tester.ensureVisible(find.text('개발/테스트 작업 보기'));
      await tester.tap(find.text('개발/테스트 작업 보기'));
      await tester.pumpAndSettle();
      expect(find.text('[TEST] Codex 무인작업'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('URL 없으면 결과물 보기 버튼 없음', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [
          project(
            id: 'wi_test_remote_e2e_1',
            title: '[TEST] 단계진행 E2E',
            status: Sotong24WorkStatus.awaitingApproval,
            stageStatus: Sotong24WorkStatus.awaitingApproval,
            stageApproval: ApprovalStatus.pending,
          ),
        ],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('개발/테스트 작업 보기'));
      await tester.tap(find.text('개발/테스트 작업 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('[TEST] 단계진행 E2E').last);
      await tester.pumpAndSettle();
      expect(find.text('결과물 보기'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('결과 준비 중'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('결과 준비 중'), findsOneWidget);
    });
  });
}
