import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/widgets/revision_request_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Sotong24RemoteStage> stagesFor({
    required int completed,
    required int awaitingAt,
    int total = 18,
  }) {
    return [
      for (var i = 1; i <= total; i++)
        Sotong24RemoteStage(
          stageId: 's$i',
          stageNumber: i,
          stageName: i == 7 ? '초안 제작' : '단계 $i',
          status: i <= completed
              ? Sotong24WorkStatus.completed
              : i == awaitingAt
              ? Sotong24WorkStatus.awaitingApproval
              : Sotong24WorkStatus.ready,
          approvalRequired: i == awaitingAt,
          criteriaMet: i <= completed || i == awaitingAt,
          approvalStatus: i == awaitingAt
              ? ApprovalStatus.pending
              : ApprovalStatus.notRequired,
          activeRequestId: i == awaitingAt ? 'req_pending' : '',
        ),
    ];
  }

  group('overallProgressPercent', () {
    test('6완료+7승인대기+progress0 → 전체 33%', () {
      final project = Sotong24RemoteProject(
        projectId: 'wi_test_remote_e2e_progress',
        title: '[TEST] 전자책 원격제작 E2E',
        productType: 'ebook',
        currentStage: 7,
        totalStages: 18,
        progress: 0,
        status: Sotong24WorkStatus.awaitingApproval,
        stages: stagesFor(completed: 6, awaitingAt: 7),
      );
      expect(project.reportedProgressPercent, 0);
      expect(project.overallProgressPercent, 33);
      expect(project.progressSummaryLine, contains('전체 진행률 33%'));
      expect(project.progressSummaryLine, contains('7단계 · 초안 제작'));
      expect(project.progressSummaryLine, isNot(contains('7/18')));
      expect(project.showReportedProgressDiagnostic, isTrue);
      expect(project.nowTodoHeadline(), '7단계 · 초안 제작 결과를 확인해 주세요.');
      expect(project.showApprovalActions, isTrue);
    });

    test('18완료 → 전체 100% · 승인 버튼 없음', () {
      final project = Sotong24RemoteProject(
        projectId: 'wi_test_remote_e2e_done',
        title: '[TEST] 전자책 원격제작 E2E',
        productType: 'ebook',
        currentStage: 18,
        totalStages: 18,
        progress: 0,
        status: Sotong24WorkStatus.completed,
        stages: [
          for (var i = 1; i <= 18; i++)
            Sotong24RemoteStage(
              stageId: 's$i',
              stageNumber: i,
              stageName: '단계 $i',
              status: Sotong24WorkStatus.completed,
            ),
        ],
      );
      expect(project.overallProgressPercent, 100);
      expect(project.progressSummaryLine, contains('전체 진행률 100%'));
      expect(project.progressSummaryLine, contains('전체 18단계 완료'));
      expect(project.showApprovalActions, isFalse);
      expect(project.nowTodoHeadline(), '작업이 완료되었습니다.');
    });

    test('0/0 incomplete listing 분류', () {
      const project = Sotong24RemoteProject(
        projectId: 'e2e_mirror_safe',
        title: '아직 찾지 못함',
        productType: 'ebook',
        currentStage: 0,
        totalStages: 0,
        progress: 0,
        status: Sotong24WorkStatus.inProgress,
        stages: [],
      );
      expect(project.isIncompleteListing, isTrue);
    });

    test('지금 할 일 상태별 문구', () {
      final running = Sotong24RemoteProject(
        projectId: 'p1',
        title: '운영',
        productType: 'ebook',
        currentStage: 7,
        totalStages: 18,
        progress: 10,
        status: Sotong24WorkStatus.inProgress,
        stages: [
          Sotong24RemoteStage(
            stageId: 's7',
            stageNumber: 7,
            stageName: '초안 제작',
            status: Sotong24WorkStatus.inProgress,
          ),
        ],
      );
      expect(running.nowTodoHeadline(), 'AI가 작업 중입니다. 완료되면 결과를 확인할 수 있습니다.');

      final revision = running.copyWith(
        status: Sotong24WorkStatus.revision,
        stages: [
          Sotong24RemoteStage(
            stageId: 's7',
            stageNumber: 7,
            stageName: '초안 제작',
            status: Sotong24WorkStatus.revision,
          ),
        ],
      );
      expect(revision.nowTodoHeadline(), '보완 작업이 진행될 예정입니다.');

      final err = running.copyWith(
        status: Sotong24WorkStatus.error,
        stages: [
          Sotong24RemoteStage(
            stageId: 's7',
            stageNumber: 7,
            stageName: '초안 제작',
            status: Sotong24WorkStatus.error,
          ),
        ],
      );
      expect(err.nowTodoHeadline(), contains('오류'));
    });

    test('stages 없으면 reported progress 폴백', () {
      const project = Sotong24RemoteProject(
        projectId: 'wi_plan_1785905165067',
        title: '운영 전자책',
        productType: 'ebook',
        currentStage: 18,
        totalStages: 18,
        progress: 94,
        status: Sotong24WorkStatus.inProgress,
        stages: [],
      );
      expect(project.overallProgressPercent, 94);
    });

    test('데모 12완료 → 전체 67% (보고 72%와 분리)', () {
      final demos = Sotong24RemoteDemoCatalog.demoProjects();
      final ebook = demos.firstWhere(
        (p) => p.projectId == Sotong24RemoteDemoCatalog.demoProjectId,
      );
      expect(ebook.reportedProgressPercent, 72);
      expect(ebook.overallProgressPercent, 67);
    });
  });

  group('RevisionRequestDialog', () {
    Future<void> openEditor(
      WidgetTester tester, {
      required double width,
    }) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showRevisionRequestDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('mobile — full-screen editor·hint·빈 요청 차단', (tester) async {
      await openEditor(tester, width: 390);

      expect(
        find.byKey(const Key('revision_request_mobile_screen')),
        findsOneWidget,
      );
      expect(find.byType(RevisionRequestDialog), findsNothing);
      expect(find.text('보완 요청'), findsOneWidget);
      expect(find.text('Agent가 반영할 보완 내용을 입력하세요.'), findsOneWidget);
      expect(find.text('보완할 내용을 입력하세요.'), findsOneWidget);
      expect(find.text('보완 요청 보내기'), findsOneWidget);

      final field = tester.widget<TextField>(
        find.byKey(const Key('revision_request_field')),
      );
      expect(field.expands, isTrue);
      expect(field.autofocus, isFalse);

      final fieldBox = tester.getSize(
        find.byKey(const Key('revision_request_field')),
      );
      expect(fieldBox.height, greaterThanOrEqualTo(90));

      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('revision_request_submit')),
      );
      expect(submit.onPressed, isNull);

      await tester.tap(find.byKey(const Key('revision_request_cancel')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop — Dialog·hint·최소높이·빈 요청 차단', (tester) async {
      String? result;
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showRevisionRequestDialog(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('revision_request_desktop_dialog')),
        findsOneWidget,
      );
      expect(find.byType(RevisionRequestMobileScreen), findsNothing);
      expect(find.text('보완 요청'), findsOneWidget);
      expect(find.text('Agent가 반영할 보완 내용을 구체적으로 적어 주세요.'), findsOneWidget);
      expect(find.text('보완할 내용을 입력하세요.'), findsOneWidget);

      final field = tester.widget<TextField>(
        find.byKey(const Key('revision_request_field')),
      );
      expect(field.expands, isFalse);
      expect(field.autofocus, isTrue);

      final box = tester.getSize(
        find.byKey(const Key('revision_request_field')),
      );
      expect(box.height, greaterThanOrEqualTo(90));

      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('revision_request_submit')),
      );
      expect(submit.onPressed, isNull);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('한글 완성형 유지·controller 재생성 없음·payload 원문', (tester) async {
      String? result;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showRevisionRequestDialog(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final state = tester.state<RevisionRequestMobileScreenState>(
        find.byType(RevisionRequestMobileScreen),
      );
      final c1 = state.debugController;

      const text = '초보자가 이해하기 쉽게 예시를 하나 추가해 주세요.';
      await tester.enterText(
        find.byKey(const Key('revision_request_field')),
        text,
      );
      await tester.pump();

      final c2 = tester
          .state<RevisionRequestMobileScreenState>(
            find.byType(RevisionRequestMobileScreen),
          )
          .debugController;
      expect(identical(c1, c2), isTrue);
      expect(c2.text, text);

      await tester.tap(find.byKey(const Key('revision_request_submit')));
      await tester.pumpAndSettle();
      expect(result, text);
    });

    testWidgets('mobile keyboard inset — TextField·보내기 버튼 가시', (tester) async {
      // Galaxy급 세로 + Samsung keyboard 대략치
      const viewH = 640.0;
      const keyboardH = 300.0;
      tester.view.physicalSize = const Size(360, viewH);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showRevisionRequestDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardH);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('revision_request_mobile_screen')),
        findsOneWidget,
      );
      expect(find.text('보완 요청'), findsOneWidget);
      expect(find.text('Agent가 반영할 보완 내용을 입력하세요.'), findsOneWidget);
      expect(find.byKey(const Key('revision_request_field')), findsOneWidget);
      expect(find.byKey(const Key('revision_request_submit')), findsOneWidget);

      final fieldRect = tester.getRect(
        find.byKey(const Key('revision_request_field')),
      );
      final submitRect = tester.getRect(
        find.byKey(const Key('revision_request_submit')),
      );
      final visibleBottom = viewH - keyboardH;

      expect(fieldRect.top, greaterThanOrEqualTo(0));
      expect(fieldRect.bottom, lessThanOrEqualTo(visibleBottom + 1));
      expect(fieldRect.height, greaterThanOrEqualTo(48));
      expect(submitRect.top, greaterThanOrEqualTo(0));
      expect(submitRect.bottom, lessThanOrEqualTo(visibleBottom + 1));

      const typed = '한글 입력 유지 확인 — 아이디어를 더 쉽게';
      await tester.enterText(
        find.byKey(const Key('revision_request_field')),
        typed,
      );
      await tester.pump();
      expect(
        tester
            .state<RevisionRequestMobileScreenState>(
              find.byType(RevisionRequestMobileScreen),
            )
            .debugController
            .text,
        typed,
      );

      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('revision_request_submit')),
      );
      expect(submit.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile keyboard open/close layout 안정', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await openEditor(tester, width: 360);
      expect(
        find.byKey(const Key('revision_request_mobile_screen')),
        findsOneWidget,
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('revision_request_mobile_screen')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('revision_request_field')), findsOneWidget);
      expect(find.byKey(const Key('revision_request_submit')), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('revision_request_mobile_screen')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiline 긴 입력 overflow 없음', (tester) async {
      await openEditor(tester, width: 390);

      final long = List.generate(
        8,
        (i) => '테스트 보완 요청입니다. 7단계 초안 내용을 조금 더 쉽게 설명해 주세요. ($i)',
      ).join('\n');
      await tester.enterText(
        find.byKey(const Key('revision_request_field')),
        long,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('revision_request_submit')), findsOneWidget);
    });

    testWidgets('입력 전 요청 비활성 · 입력 후 활성', (tester) async {
      await openEditor(tester, width: 390);

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('revision_request_submit')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('revision_request_field')),
        '   ',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('revision_request_submit')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('revision_request_field')),
        '예시 문장을 더 쉽게 바꿔 주세요.',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('revision_request_submit')),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('AI 제작공정 progress UI', () {
    testWidgets('목록 카드에 전체 진행률 표시 (0% 아님)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final project = Sotong24RemoteProject(
        projectId: 'wi_plan_e2e_ui_real',
        title: 'AI 학습 도우미 활용법 전자책',
        productType: 'ebook',
        currentStage: 7,
        totalStages: 18,
        progress: 0,
        status: Sotong24WorkStatus.awaitingApproval,
        approvalStatus: ApprovalStatus.pending,
        pcStatus: Sotong24PcLinkStatus.online,
        stages: stagesFor(completed: 6, awaitingAt: 7),
      );

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [project],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('AI 학습'), findsWidgets);
      expect(find.textContaining('전체 진행률 33%'), findsWidgets);
      expect(find.textContaining('전자책 · 7/18 · 0%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('상세에서 revision_request 원문 전달', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final project = Sotong24RemoteProject(
        projectId: 'wi_test_remote_e2e_rev',
        title: '[TEST] 전자책 원격제작 E2E',
        productType: 'ebook',
        currentStage: 7,
        totalStages: 18,
        progress: 0,
        status: Sotong24WorkStatus.awaitingApproval,
        approvalStatus: ApprovalStatus.pending,
        pcStatus: Sotong24PcLinkStatus.online,
        stages: stagesFor(completed: 6, awaitingAt: 7),
      );

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [project],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Sotong24RemoteDetailScreen(
            projectId: project.projectId,
            initialProject: project,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('제작 상세'), findsOneWidget);
      expect(find.textContaining('전체 진행률'), findsWidgets);
      expect(find.textContaining('33%'), findsWidgets);
      expect(find.textContaining('진단정보 보기'), findsOneWidget);
      expect(find.textContaining('7단계 · 초안 제작 결과를 확인해 주세요.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('보완 요청'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('보완 요청'));
      await tester.tap(find.text('보완 요청'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('revision_request_mobile_screen')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('revision_request_field')), findsOneWidget);
      const msg = '테스트 보완 요청입니다.';
      await tester.enterText(
        find.byKey(const Key('revision_request_field')),
        msg,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('revision_request_submit')));
      await tester.pumpAndSettle();

      final after = await repo.getProject(project.projectId);
      expect(after, isNotNull);
      expect(after!.approvalStatus, ApprovalStatus.revisionRequested);
      expect(after.status, Sotong24WorkStatus.awaitingApproval);
      expect(after.userFacingStatus, Sotong24WorkStatus.revision);
      expect(after.showApprovalActions, isFalse);
      final stage = after.stages.firstWhere((s) => s.stageNumber == 7);
      expect(stage.summary, msg);
      expect(stage.approvalStatus, ApprovalStatus.revisionRequested);
    });
    testWidgets('완료 상세 — 승인 버튼 없음·완료 배너·결과 문구', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final project = Sotong24RemoteProject(
        projectId: 'wi_test_remote_e2e_complete_ui',
        title: '[TEST] 전자책 원격제작 E2E',
        productType: 'ebook',
        currentStage: 18,
        totalStages: 18,
        progress: 0,
        status: Sotong24WorkStatus.completed,
        stages: [
          for (var i = 1; i <= 18; i++)
            Sotong24RemoteStage(
              stageId: 's$i',
              stageNumber: i,
              stageName: '단계 $i',
              status: Sotong24WorkStatus.completed,
            ),
        ],
      );
      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [project],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Sotong24RemoteDetailScreen(
            projectId: project.projectId,
            initialProject: project,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('100%'), findsWidgets);
      expect(find.text('TEST E2E 완료'), findsWidgets);
      expect(find.text('목록으로'), findsOneWidget);
      expect(find.text('승인'), findsNothing);
      expect(find.text('보완 요청'), findsNothing);
      expect(find.textContaining('작업이 완료되었습니다.'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('결과 확인'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('휴대폰에서 열 수 있는 결과물'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
