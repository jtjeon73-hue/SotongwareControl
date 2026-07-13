import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/ops_enums.dart';
import 'package:sotong_ware_control/models/ops_models.dart';
import 'package:sotong_ware_control/services/dashboard_service.dart';
import 'package:sotong_ware_control/services/github_service.dart';
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
      const p = ProjectDoc(
        id: 'a',
        businessUnitId: 'x',
        name: 't',
      );
      expect(p.computedProgress, isNull);
    });

    test('미완료 배포는 완료가 아님', () {
      const d = DeploymentDoc(
        id: 'd1',
        projectId: 'p1',
        analyzePassed: true,
        testPassed: true,
        buildPassed: true,
        gitCommitted: true,
        gitPushed: true,
        firebaseDeployed: true,
        siteVerified: false,
      );
      expect(d.isFullyComplete, isFalse);
      expect(d.statusLabel, '확인 필요');
    });

    test('전부 통과 시 배포 완료', () {
      const d = DeploymentDoc(
        id: 'd1',
        projectId: 'p1',
        analyzePassed: true,
        testPassed: true,
        buildPassed: true,
        gitCommitted: true,
        gitPushed: true,
        firebaseDeployed: true,
        siteVerified: true,
      );
      expect(d.isFullyComplete, isTrue);
      expect(d.statusLabel, '완료');
    });
  });

  group('DashboardService', () {
    test('빈 데이터 KPI는 0', () {
      final k = DashboardService().computeKpis(
        units: const [],
        projects: const [],
        tasks: const [],
        logs: const [],
        deployments: const [],
      );
      expect(k.projectCount, 0);
      expect(k.inProgress, 0);
      expect(k.workLogs7d, 0);
    });

    test('주의 항목이 없으면 안내 문구', () {
      final items = DashboardService().attentionItems(
        projects: const [],
        tasks: const [],
        issues: const [],
        deployments: const [],
      );
      expect(items.first, contains('긴급 확인'));
    });
  });

  test('GitHub URL 파싱', () {
    final p = GithubService.parseGithubUrl(
      'https://github.com/jtjeon73-hue/SotongwareControl',
    );
    expect(p?.owner, 'jtjeon73-hue');
    expect(p?.repo, 'SotongwareControl');
  });

  test('사업부 메뉴에 소통24워크 포함', () {
    expect(
      ControlDestination.sotong24work.label,
      '소통24워크',
    );
    expect(
      ControlDestination.youtubeContent.label,
      '콘텐츠·음악사업부',
    );
  });

  testWidgets('빈 상태·긴 텍스트 오버플로 방지', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const EmptyStatePanel(
                  title: '아직 등록된 프로젝트가 없습니다',
                  message:
                      '첫 프로젝트를 등록하여 사업부 관리를 시작하십시오. '
                      '매우긴프로젝트이름매우긴프로젝트이름매우긴프로젝트이름매우긴프로젝트이름',
                ),
                const ProgressLabel(progress: null),
                StatusBadge(
                  label: ProjectStatus.labelKo(ProjectStatus.notStarted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('아직 등록된 프로젝트'), findsOneWidget);
    expect(find.text('진행률 미설정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
