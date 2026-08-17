import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/screens/product_workshop_screen.dart';
import 'package:sotong_ware_control/screens/remote_control_screen.dart';
import 'package:sotong_ware_control/screens/standard_production_guide_screen.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('운영 UI', () {
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
      expect(find.textContaining('사용량: 수집 준비 중'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('개발/진단 도구'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('상태 재확인'), findsOneWidget);
      expect(find.text('샘플 작업지시서 E2E 테스트'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
