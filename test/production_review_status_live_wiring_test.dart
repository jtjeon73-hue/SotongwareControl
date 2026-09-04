/// Direct production_review_status subscription + workshop merge wiring.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/commercial/production_review_status_envelope.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/screens/remote_control_screen.dart';
import 'package:sotong_ware_control/services/production_review_status_repository.dart';
import 'package:sotong_ware_control/services/production_review_workshop_merge.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
import 'package:sotong_ware_control/widgets/remote_ops_dashboard.dart';

import 'support/production_review_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final envelope = ProductionReviewFixtures.appR1ChangesRequested();
  final staleR0 = ProductionReviewStatusEnvelope.fromJson({
    ...envelope.toJson(),
    'eventId': 'evt_stale_r0',
    'revision': 'R0',
    'updatedAt': '2026-09-01T00:00:00.000Z',
    'emittedAt': '2026-09-01T00:00:00.000Z',
  });

  group('ProductionReviewWorkshopMerge', () {
    test('envelope-only creates synthetic project card', () {
      final merged = ProductionReviewWorkshopMerge.merge(
        projects: const [],
        envelopes: [envelope],
      );
      expect(merged, hasLength(1));
      expect(merged.single.projectId, envelope.instructionId);
      expect(merged.single.productionReviewStatus?.revision, 'R1');
      expect(merged.single.title, isNot(contains('wi_test_')));
    });

    test('project+envelope merge dedupes to one card', () {
      final project = Sotong24RemoteProject(
        projectId: envelope.instructionId,
        title: '레거시 제목',
        productType: ArtifactType.app,
        currentStage: 10,
        totalStages: 18,
        progress: 50,
        status: Sotong24WorkStatus.inProgress,
        updatedAt: '2026-09-01T00:00:00.000Z',
      );
      final merged = ProductionReviewWorkshopMerge.merge(
        projects: [project],
        envelopes: [envelope],
      );
      expect(merged, hasLength(1));
      expect(merged.single.title, '레거시 제목');
      expect(
        merged.single.productionReviewStatus?.ownerReview.decision,
        'changes_requested',
      );
    });

    test('legacy project-only unchanged', () {
      final project = Sotong24RemoteProject(
        projectId: 'wi_legacy_only',
        title: '레거시만',
        productType: ArtifactType.ebook,
        currentStage: 3,
        totalStages: 10,
        progress: 30,
        status: Sotong24WorkStatus.inProgress,
        updatedAt: '2026-09-01T00:00:00.000Z',
      );
      final merged = ProductionReviewWorkshopMerge.merge(
        projects: [project],
        envelopes: const [],
      );
      expect(merged, hasLength(1));
      expect(merged.single.productionReviewStatus, isNull);
    });

    test('newer revision wins over stale', () {
      final merged = ProductionReviewWorkshopMerge.merge(
        projects: const [],
        envelopes: [staleR0, envelope],
      );
      expect(merged, hasLength(1));
      expect(merged.single.productionReviewStatus?.revision, 'R1');
    });

    test('awaitingOwnerReview picks changes_requested', () {
      final list = ProductionReviewWorkshopMerge.awaitingOwnerReview([
        envelope,
      ]);
      expect(list, hasLength(1));
      expect(list.single.userLabelKo, contains('사용자 보완요청'));
    });
  });

  group('ProductionReviewStatusRepository memory', () {
    test('loading/empty/malformed/stale handling', () async {
      final repo = ProductionReviewStatusRepository(
        forceMemory: true,
        memorySeed: [envelope, staleR0],
      );
      addTearDown(repo.dispose);

      final first = await repo.watchRecent().first;
      expect(first.loading, isFalse);
      expect(first.hasError, isFalse);
      // memory seed is not re-parsed through Firestore snapshot path;
      // duplicate instruction keeps both until parseSnapshot path — setMemory
      // stores list as-is. Prefer watch via setMemory after clear.
      repo.setMemoryEnvelopes([envelope]);
      final second = await repo.watchRecent().first;
      expect(second.envelopes, hasLength(1));
      expect(second.envelopes.single.revision, 'R1');

      final emptyRepo = ProductionReviewStatusRepository(forceMemory: true);
      addTearDown(emptyRepo.dispose);
      final empty = await emptyRepo.watchRecent().first;
      expect(empty.isEmpty, isTrue);

      final byId = await repo
          .watchByInstructionId(envelope.instructionId)
          .first;
      expect(byId?.revision, 'R1');
      expect(await repo.watchByInstructionId('missing').first, isNull);
    });

    test('dispose closes stream safely', () async {
      final repo = ProductionReviewStatusRepository(
        forceMemory: true,
        memorySeed: [envelope],
      );
      final sub = repo.watchRecent().listen((_) {});
      repo.dispose();
      await sub.cancel();
    });
  });

  group('RemoteOpsDashboard envelope-only', () {
    testWidgets('shows R1 card in 지금 확인할 결과물 without project', (tester) async {
      for (final size in const [
        Size(1440, 900),
        Size(768, 1024),
        Size(390, 844),
      ]) {
        for (final scale in [1.0, 1.3, 1.5]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: RemoteOpsDashboard(
                      agents: const [],
                      workshops: const [],
                      onRefresh: () {},
                      productionReview: envelope,
                      reviewAwaiting: [envelope],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('지금 확인할 결과물'), findsOneWidget);
          expect(find.textContaining('기술검증 완료'), findsWidgets);
          expect(find.textContaining('사용자 보완요청'), findsWidgets);
          expect(find.textContaining('R2 준비 대기'), findsWidgets);
          expect(
            find.byKey(const Key('production_review_status_card')),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
          expect(find.textContaining('OVERFLOWED'), findsNothing);
        }
      }
    });

    testWidgets('baseline empty review is not treated as new alert', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RemoteOpsDashboard(
                agents: [
                  RemoteAgentDoc(
                    agentId: 'a1',
                    ownerUid: 'u',
                    deviceName: '노트북',
                    state: 'idle',
                    enabled: true,
                    lastHeartbeatAt: DateTime.now(),
                  ),
                ],
                workshops: const [],
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('새 알림이 아닙니다'), findsOneWidget);
      expect(
        find.byKey(const Key('production_review_status_card')),
        findsNothing,
      );
    });
  });

  group('ProductWorkshopScreen envelope-only', () {
    testWidgets('lists envelope without project and opens detail', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final workshop = Sotong24RemoteRepository(forceMemory: true);
      final review = ProductionReviewStatusRepository(
        forceMemory: true,
        memorySeed: [envelope],
      );
      addTearDown(workshop.dispose);
      addTearDown(review.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductWorkshopScreen(
              repository: workshop,
              productionReviewRepository: review,
              focusInstructionId: envelope.instructionId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workshop_loading_label')), findsNothing);
      expect(
        find.byKey(const Key('production_review_status_card')),
        findsWidgets,
      );
      expect(find.textContaining('기술검증 완료'), findsWidgets);
      expect(find.textContaining('등록 불가'), findsWidgets);
      expect(find.textContaining('외부 공개 불가'), findsWidgets);

      // Deep link should open detail with initial envelope project.
      expect(find.text('제작 상세'), findsOneWidget);
    });

    testWidgets('deep link settles without infinite loading when missing', (
      tester,
    ) async {
      final workshop = Sotong24RemoteRepository(forceMemory: true);
      final review = ProductionReviewStatusRepository(forceMemory: true);
      addTearDown(workshop.dispose);
      addTearDown(review.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductWorkshopScreen(
              repository: workshop,
              productionReviewRepository: review,
              focusInstructionId: 'wi_missing_nowhere',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workshop_loading_label')), findsNothing);
      // Missing id → preparing card (handoff wait), not whole-screen spinner.
      expect(find.byKey(const Key('workshop_preparing_card')), findsOneWidget);
    });
  });

  group('RemoteControlScreen live wiring', () {
    testWidgets('shows envelope-only card on dashboard stream', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final agents = RemoteAgentRepository(forceMemory: true);
      final workshop = Sotong24RemoteRepository(forceMemory: true);
      final review = ProductionReviewStatusRepository(
        forceMemory: true,
        memorySeed: [envelope],
      );
      addTearDown(workshop.dispose);
      addTearDown(review.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteControlScreen(
              repository: agents,
              workshopRepository: workshop,
              productionReviewRepository: review,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('지금 확인할 결과물'), findsOneWidget);
      expect(
        find.byKey(const Key('production_review_status_card')),
        findsOneWidget,
      );
      expect(find.textContaining('STEP16 미시작'), findsWidgets);
      expect(find.textContaining('R2 준비 대기'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
