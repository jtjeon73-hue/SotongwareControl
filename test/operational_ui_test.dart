import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sotong_ware_control/app.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/screens/remote_control_screen.dart';
import 'package:sotong_ware_control/screens/standard_production_guide_screen.dart';
import 'package:sotong_ware_control/services/auth_service.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/state/control_scope.dart';
import 'package:sotong_ware_control/state/control_state.dart';
import 'package:sotong_ware_control/widgets/remote_ops_dashboard.dart';

class _FakeAuth implements AuthClient {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  bool get isAuthorized => false;

  @override
  Future<void> setPersistence({required bool keepSignedIn}) async {}

  @override
  Future<AuthResult> signIn({
    required String adminId,
    required String password,
    required bool keepSignedIn,
  }) async => const AuthResult.failure(AuthFailureReason.invalidCredentials);

  @override
  Future<void> signOut() async {}
}

class _PendingWorkshopRepository extends Sotong24RemoteRepository {
  _PendingWorkshopRepository() : super(forceMemory: true);

  @override
  Stream<List<Sotong24RemoteProject>> watchProjects() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('운영 UI', () {
    testWidgets('AI 제작공정 — 초기 로딩 중에도 빈 화면 대신 상태 문구 표시', (tester) async {
      final repo = _PendingWorkshopRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
        ),
      );

      expect(find.byKey(const Key('workshop_loading_label')), findsOneWidget);
      expect(find.text('AI 제작공정 불러오는 중'), findsOneWidget);
    });

    testWidgets('AI 제작공정 — 앱 단계의 Codex 작업자 표시', (tester) async {
      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: const [
          Sotong24RemoteProject(
            projectId: 'wi_plan_app_worker',
            title: '전기 점검 체크 앱',
            productType: 'app',
            currentStage: 2,
            totalStages: 18,
            progress: 5,
            status: Sotong24WorkStatus.inProgress,
            currentWorker: 'codex',
            stages: [
              Sotong24RemoteStage(
                stageId: 'app_problem_validate',
                stageNumber: 2,
                stageName: '고객 문제 검증',
                status: Sotong24WorkStatus.inProgress,
                executorKind: 'codex',
                activityState: 'codex_running',
              ),
            ],
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

      expect(find.textContaining('현재 작업자: Codex'), findsOneWidget);
      expect(find.textContaining('2단계'), findsWidgets);
    });

    testWidgets('표준제작 가이드 홈·카테고리', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StandardProductionGuideScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('표준제작 가이드'), findsWidgets);
      expect(find.text('전자책 제작'), findsOneWidget);
      expect(find.text('앱 제작'), findsOneWidget);
      expect(find.text('콘텐츠 제작'), findsOneWidget);

      await tester.tap(find.text('전자책 제작'));
      await tester.pumpAndSettle();
      expect(find.textContaining('전자책'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AI 제작공정 — projects 0건이면 demo·과거 작업 미표시', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: const [],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductWorkshopScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('현재 진행 중인 작업이 없습니다.'), findsOneWidget);
      expect(find.textContaining('Firestore'), findsNothing);
      expect(find.textContaining('데모'), findsNothing);
      expect(find.textContaining('50대 초보도'), findsNothing);
      expect(find.text('승인 대기'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AI 제작공정 — TEST 기본 접힘·가이드 패널 없음', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [
          Sotong24RemoteProject(
            projectId: 'wi_test_remote_e2e_ui',
            title: '[TEST] 전자책 원격제작 E2E',
            productType: 'ebook',
            currentStage: 7,
            totalStages: 18,
            progress: 0,
            status: Sotong24WorkStatus.awaitingApproval,
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

      expect(find.text('개발/테스트 작업 보기'), findsOneWidget);
      expect(find.text('[TEST] 전자책 원격제작 E2E'), findsNothing);
      expect(find.text('사업별 표준 제작 가이드'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('원격관제 — 대시보드·개발도구 접힘', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = RemoteAgentRepository(forceMemory: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RemoteControlScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remote_ops_dashboard')), findsOneWidget);
      expect(find.textContaining('수집 준비 중'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('개발/진단 도구'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('상태 재확인'), findsOneWidget);
      expect(find.text('샘플 작업지시서 E2E 테스트'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('원격관제 — stale currentJobId·jobs 0이면 과거 작업 미표시', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final agentRepo = RemoteAgentRepository(
        forceMemory: true,
        memoryAgents: [
          RemoteAgentDoc(
            agentId: 'agent_live',
            ownerUid: 'uid',
            deviceName: 'LAPTOP-OPS',
            state: 'idle',
            enabled: true,
            currentJobId: 'wi_stale_deleted_job',
            currentStage: '13단계 배포',
            lastHeartbeatAt: DateTime.now().toUtc().subtract(
              const Duration(seconds: 20),
            ),
          ),
        ],
        memoryJobs: const [],
      );
      final workshopRepo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: const [],
      );
      addTearDown(workshopRepo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: agentRepo,
              workshopRepository: workshopRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('온라인'), findsOneWidget);
      expect(find.text('정상'), findsOneWidget);
      expect(find.text('대기'), findsOneWidget);
      expect(find.text('현재 진행 중인 작업이 없습니다.'), findsOneWidget);
      expect(find.textContaining('50대 초보도'), findsNothing);
      expect(find.textContaining('13단계'), findsNothing);
      expect(find.text('0건'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RemoteOpsDashboard — heartbeat stale이면 오프라인', (tester) async {
      final staleHb = DateTime.now().toUtc().subtract(
        const Duration(minutes: 5),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteOpsDashboard(
              agents: [
                RemoteAgentDoc(
                  agentId: 'agent_off',
                  ownerUid: 'uid',
                  deviceName: 'LAPTOP-OFF',
                  state: 'idle',
                  enabled: true,
                  lastHeartbeatAt: staleHb,
                ),
              ],
              workshops: const [],
              onRefresh: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('오프라인'), findsWidgets);
      expect(find.text('응답 없음'), findsOneWidget);
      expect(find.textContaining('Agent 연결이 끊겼습니다'), findsOneWidget);
    });

    testWidgets('로그인 셸 기본 화면 = 노트북 원격관제', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final controlState = ControlState();
      await controlState.initialize();

      await tester.pumpWidget(
        ControlScope(
          notifier: controlState,
          child: MaterialApp(
            home: ControlCenterShell(authService: _FakeAuth()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('노트북·Agent'), findsOneWidget);
      expect(find.byKey(const Key('remote_ops_dashboard')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
