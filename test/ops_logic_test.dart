import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/known_projects_catalog.dart';
import 'package:sotong_ware_control/models/ops_enums.dart';
import 'package:sotong_ware_control/models/ops_models.dart';
import 'package:sotong_ware_control/screens/project_detail_screen.dart';
import 'package:sotong_ware_control/screens/sotong24work_screen.dart';
import 'package:sotong_ware_control/services/dashboard_service.dart';
import 'package:sotong_ware_control/services/firebase_ready.dart';
import 'package:sotong_ware_control/services/github_service.dart';
import 'package:sotong_ware_control/services/known_projects_seed_service.dart';
import 'package:sotong_ware_control/widgets/deployment_checklist.dart';
import 'package:sotong_ware_control/widgets/ops_ui.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  group('진행률·배포 계산', () {
    test('단계 기반 진행률', () {
      const p = ProjectDoc(
        id: 'a',
        businessUnitId: 'x',
        name: 't',
        totalStages: 4,
        completedStages: 1,
      );
      expect(p.computedProgress, 25);
    });

    test('데이터 없으면 진행률 미설정', () {
      const p = ProjectDoc(id: 'a', businessUnitId: 'x', name: 't');
      expect(p.computedProgress, isNull);
    });

    test('사이트 미확인은 배포 완료가 아님', () {
      const d = DeploymentDoc(
        id: 'd1',
        projectId: 'p1',
        flutterAnalyze: DeployStepStatus.success,
        flutterTest: DeployStepStatus.success,
        flutterBuildWeb: DeployStepStatus.success,
        gitCommit: DeployStepStatus.success,
        gitPush: DeployStepStatus.success,
        firebaseDeploy: DeployStepStatus.success,
        siteVerified: DeployStepStatus.notChecked,
      );
      expect(d.isFullyComplete, isFalse);
      expect(d.deployOkSitePending, isTrue);
      expect(d.statusLabel, '배포 성공 / 실제 반영 확인 필요');
    });

    test('전부 성공 시 배포 완료', () {
      const d = DeploymentDoc(
        id: 'd1',
        projectId: 'p1',
        flutterAnalyze: DeployStepStatus.success,
        flutterTest: DeployStepStatus.success,
        flutterBuildWeb: DeployStepStatus.success,
        gitCommit: DeployStepStatus.success,
        gitPush: DeployStepStatus.success,
        firebaseDeploy: DeployStepStatus.success,
        siteVerified: DeployStepStatus.success,
      );
      expect(d.isFullyComplete, isTrue);
      expect(d.statusLabel, '배포 완료');
    });
  });

  group('작업 로그 유틸', () {
    test('커밋 해시 중복 감지', () {
      expect(
        WorkLogUtils.isDuplicateCommit(
          newHash: 'Abc123',
          existingHashes: ['abc123', 'zzz'],
        ),
        isTrue,
      );
      expect(
        WorkLogUtils.isDuplicateCommit(newHash: '', existingHashes: ['abc']),
        isFalse,
      );
    });

    test('JSON 가져오기 검증', () {
      expect(WorkLogUtils.validateImportItem({'title': ''}), isNotEmpty);
      expect(WorkLogUtils.validateImportItem({'title': 'ok'}), isEmpty);
    });

    test('필터·정렬', () {
      final logs = [
        WorkLogDoc(
          id: '1',
          title: 'a',
          projectId: 'p1',
          businessUnitId: 'u1',
          workedAt: DateTime(2026, 1, 1),
        ),
        WorkLogDoc(
          id: '2',
          title: 'b',
          projectId: 'p2',
          businessUnitId: 'u1',
          workedAt: DateTime(2026, 2, 1),
        ),
      ];
      final f = WorkLogUtils.filterLogs(logs: logs, projectId: 'p1');
      expect(f.length, 1);
      expect(f.first.id, '1');
    });
  });

  test('실제 프로젝트 카탈로그에 소통총관제·소통사주 포함, id 중복 없음', () {
    final ids = KnownProjectsCatalog.all.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, contains('control_center'));
    expect(ids, contains('app_sotong_saju'));
    expect(ids, contains('promo_ebook'));
    expect(KnownProjectsCatalog.all.length, greaterThanOrEqualTo(12));
  });

  test('GitHub URL 오류 파싱', () {
    expect(GithubService.parseGithubUrl('not-a-url'), isNull);
    expect(GithubService.parseGithubUrl('https://example.com/x'), isNull);
  });

  test('사업부 메뉴에 소통24워크 포함', () {
    expect(ControlDestination.sotong24work.label, '소통24워크');
  });

  test('Firebase 미준비 시 false', () {
    expect(isFirebaseReady(), isFalse);
  });

  testWidgets('빈 상태·배포 체크리스트 UI', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const d = DeploymentDoc(
      id: 'd',
      projectId: 'control_center',
      flutterAnalyze: DeployStepStatus.success,
      flutterTest: DeployStepStatus.success,
      flutterBuildWeb: DeployStepStatus.success,
      gitCommit: DeployStepStatus.success,
      gitPush: DeployStepStatus.success,
      firebaseDeploy: DeployStepStatus.success,
      siteVerified: DeployStepStatus.notChecked,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                EmptyStatePanel(
                  title: '아직 등록된 프로젝트가 없습니다',
                  message: '첫 프로젝트를 등록하여 사업부 관리를 시작하십시오.',
                ),
                DeploymentChecklistCard(deployment: d),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('배포 성공'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('프로젝트 상세·소통24 화면은 Firebase 없을 때 빈 상태', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ProjectDetailScreen(projectId: 'x')),
    );
    await tester.pump();
    expect(find.textContaining('Firebase'), findsWidgets);

    await tester.pumpWidget(const MaterialApp(home: Sotong24WorkScreen()));
    await tester.pump();
    expect(find.textContaining('소통24워크'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('DashboardService 빈 KPI', () {
    final k = DashboardService().computeKpis(
      units: const [],
      projects: const [],
      tasks: const [],
      logs: const [],
      deployments: const [],
    );
    expect(k.projectCount, 0);
  });
}
