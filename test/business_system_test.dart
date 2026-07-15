import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/core/business/business_catalog.dart';
import 'package:sotong_ware_control/core/business/business_study_content.dart';
import 'package:sotong_ware_control/models/ops_enums.dart';
import 'package:sotong_ware_control/models/ops_models.dart';
import 'package:sotong_ware_control/screens/business_study_screen.dart';
import 'package:sotong_ware_control/services/business_analysis_service.dart';
import 'package:sotong_ware_control/services/github_service.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

class _FakeGithubService extends GithubService {
  @override
  Future<GithubRepositoryInspection> inspectPublicRepository({
    required String owner,
    required String repo,
  }) async {
    return GithubRepositoryInspection(
      repo: '$owner/$repo',
      defaultBranch: 'main',
      lastPushedAt: DateTime(2026, 7, 15),
      hasReadme: true,
      hasTests: false,
      hasFirebaseConfig: true,
      hasFlutterProject: true,
      hasWebProject: true,
      recentCommits: [
        GithubCommitInfo(
          message: 'test commit',
          author: 'tester',
          date: DateTime(2026, 7, 15),
          url: 'https://github.com/example/repo/commit/1',
          sha: '1234567',
          repo: '$owner/$repo',
        ),
      ],
    );
  }
}

void main() {
  test('5개 사업 분류와 기존 ID 호환', () {
    expect(BusinessCatalog.businesses.length, 5);
    expect(BusinessCatalog.canonicalId('online_expansion'), 'web_marketing');
    expect(BusinessCatalog.canonicalId('content_music'), 'content_music');
    expect(BusinessCatalog.businesses.map((e) => e.id).toSet(), {
      'industrial_automation',
      'app_development',
      'ebook',
      'content_music',
      'web_marketing',
    });
  });

  test('프로젝트는 기존 businessUnitId를 보존하며 공통 사업으로 해석', () {
    const project = ProjectDoc(
      id: 'legacy',
      businessUnitId: 'online_expansion',
      name: '기존 마케팅 프로젝트',
    );
    expect(project.businessUnitId, 'online_expansion');
    expect(project.canonicalBusinessId, 'web_marketing');
  });

  test('규칙 기반 사업분석과 GitHub 실패 없는 결과', () async {
    final service = BusinessAnalysisService(github: _FakeGithubService());
    final report = await service.analyze(
      projects: const [
        ProjectDoc(
          id: 'p1',
          businessUnitId: 'app_development',
          name: '앱',
          status: ProjectStatus.inProgress,
          progress: 50,
          repositoryUrl: 'https://github.com/example/repo',
          nextAction: '테스트 추가',
        ),
      ],
      tasks: const [],
      logs: const [],
      deployments: const [],
      issues: const [],
    );
    expect(report.businessResults.length, 5);
    expect(report.projectResults.length, 1);
    expect(report.analysisMethod, 'rules_based');
    expect(report.githubStatus, 'success');
    expect(report.projectResults.first['gaps'], contains('테스트 경로 미확인'));
    expect(report.sourceMetrics['projectCount'], 1);
  });

  test('5개 학습 영역과 실제 콘텐츠', () {
    expect(BusinessStudyContent.domains.length, 5);
    expect(
      BusinessStudyContent.domains.every((d) => d.lessons.length >= 3),
      isTrue,
    );
    expect(
      BusinessStudyContent.domains
          .expand((d) => d.lessons)
          .every((l) => l.sotongApplication.isNotEmpty),
      isTrue,
    );
  });

  test('통합 메뉴 목적지', () {
    expect(ControlDestination.dashboardOverview.label, '전체 사업 현황');
    expect(ControlDestination.divisionProgress.label, '사업부별 진행상태');
    expect(ControlDestination.aiBusinessAnalysis.label, 'AI 사업분석');
    expect(ControlDestination.businessStudy.label, '사업 지식 학습');
    expect(ControlDestination.webMarketing.label, '웹마케팅제작사업부');
  });

  for (final width in [360.0, 390.0, 430.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('사업스터디 반응형 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BusinessStudyScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('소통사업스터디부'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
