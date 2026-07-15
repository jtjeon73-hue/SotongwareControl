import '../core/business/business_catalog.dart';
import '../models/business_analysis.dart';
import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import 'github_service.dart';

class BusinessAnalysisService {
  BusinessAnalysisService({GithubService? github})
    : _github = github ?? GithubService();

  final GithubService _github;

  Future<BusinessAnalysisReport> analyze({
    required List<ProjectDoc> projects,
    required List<TaskDoc> tasks,
    required List<WorkLogDoc> logs,
    required List<DeploymentDoc> deployments,
    required List<IssueDoc> issues,
    BusinessAnalysisReport? previous,
  }) async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final inspections = <String, GithubRepositoryInspection>{};
    final githubErrors = <String>[];

    for (final project in projects.where(
      (p) => p.repositoryUrl.trim().isNotEmpty,
    )) {
      final parsed = GithubService.parseGithubUrl(project.repositoryUrl);
      if (parsed == null) {
        githubErrors.add('${project.name}: GitHub URL 형식 확인 필요');
        continue;
      }
      try {
        inspections[project.id] = await _github.inspectPublicRepository(
          owner: parsed.owner,
          repo: parsed.repo,
        );
      } catch (error) {
        githubErrors.add('${project.name}: $error');
      }
    }

    final businessResults = <Map<String, dynamic>>[];
    final projectResults = <Map<String, dynamic>>[];
    final weaknesses = <String>[];

    for (final business in BusinessCatalog.businesses) {
      final businessProjects = projects
          .where((p) => business.matches(p.businessUnitId))
          .toList();
      final active = businessProjects.where(_isActive).length;
      final completed = businessProjects
          .where((p) => p.status == ProjectStatus.completed)
          .length;
      final needsAttention = businessProjects.where((p) {
        final openIssues = issues.any(
          (i) => i.projectId == p.id && i.status == 'open',
        );
        return p.status == ProjectStatus.blocked ||
            p.status == ProjectStatus.onHold ||
            p.needsCeoReview ||
            openIssues ||
            (p.isStale && _isActive(p));
      }).length;
      final progressValues = businessProjects
          .map((p) => p.computedProgress)
          .whereType<int>()
          .toList();
      final progress = progressValues.isEmpty
          ? null
          : (progressValues.reduce((a, b) => a + b) / progressValues.length)
                .round();
      final recentLogs =
          logs
              .where(
                (l) =>
                    business.matches(l.businessUnitId) ||
                    businessProjects.any((p) => p.id == l.projectId),
              )
              .toList()
            ..sort(
              (a, b) => (b.workedAt ?? DateTime(1970)).compareTo(
                a.workedAt ?? DateTime(1970),
              ),
            );
      final latestGithub =
          inspections.entries
              .where((e) => businessProjects.any((p) => p.id == e.key))
              .map((e) => e.value)
              .where((e) => e.lastPushedAt != null)
              .toList()
            ..sort((a, b) => b.lastPushedAt!.compareTo(a.lastPushedAt!));
      final businessDeployments = deployments
          .where((d) => businessProjects.any((p) => p.id == d.projectId))
          .toList();
      final deployComplete = businessDeployments
          .where((d) => d.isFullyComplete)
          .length;
      final status = _businessStatus(
        projects: businessProjects,
        needsAttention: needsAttention,
        progress: progress,
      );
      final importantTask =
          tasks
              .where(
                (t) =>
                    business.matches(t.businessUnitId) &&
                    t.status != TaskStatus.completed &&
                    t.status != TaskStatus.cancelled,
              )
              .toList()
            ..sort(
              (a, b) => _priority(b.priority).compareTo(_priority(a.priority)),
            );
      final weakness = _businessWeakness(
        business: business,
        projects: businessProjects,
        needsAttention: needsAttention,
        deployments: businessDeployments,
        inspections: inspections,
      );
      final nextAction = importantTask.isNotEmpty
          ? importantTask.first.title
          : businessProjects
                    .where((p) => p.nextAction.trim().isNotEmpty)
                    .map((p) => p.nextAction)
                    .firstOrNull ??
                '다음 작업을 실제 데이터에 등록하십시오.';

      if (weakness != '등록된 근거에서 큰 미흡 사항이 확인되지 않았습니다.') {
        weaknesses.add('${business.shortName}: $weakness');
      }
      businessResults.add({
        'businessId': business.id,
        'name': business.shortName,
        'displayName': business.name,
        'status': status,
        'progress': progress,
        'projectCount': businessProjects.length,
        'activeCount': active,
        'completedCount': completed,
        'needsAttentionCount': needsAttention,
        'recentWorkAt': recentLogs.firstOrNull?.workedAt?.toIso8601String(),
        'recentGithubAt': latestGithub.firstOrNull?.lastPushedAt
            ?.toIso8601String(),
        'deploymentCompleteCount': deployComplete,
        'deploymentCount': businessDeployments.length,
        'importantTask': importantTask.firstOrNull?.title ?? '',
        'weakness': weakness,
        'nextAction': nextAction,
        'siteUrl': business.site.url,
      });
    }

    for (final project in projects) {
      final inspection = inspections[project.id];
      final projectIssues = issues
          .where((i) => i.projectId == project.id && i.status == 'open')
          .toList();
      final projectDeployments = deployments
          .where((d) => d.projectId == project.id)
          .toList();
      final completedFacts = <String>[
        if (project.computedProgress != null)
          '등록 진행률 ${project.computedProgress}%',
        if (inspection?.hasReadme == true) 'README 확인',
        if (inspection?.hasTests == true) '테스트 경로 확인',
        if (projectDeployments.any((d) => d.isFullyComplete)) '배포 완료 기록 확인',
      ];
      final gaps = <String>[
        if (project.repositoryUrl.trim().isEmpty) 'GitHub 저장소 미등록',
        if (inspection != null && !inspection.hasReadme) 'README 부족',
        if (inspection != null && !inspection.hasTests) '테스트 경로 미확인',
        if (projectDeployments.isEmpty) '배포 기록 미등록',
        if (project.nextAction.trim().isEmpty) '다음 작업 미등록',
        if (project.isStale && _isActive(project)) '최근 활동 정체',
        ...projectIssues.map((i) => '열린 문제: ${i.title}'),
      ];
      projectResults.add({
        'projectId': project.id,
        'businessId': BusinessCatalog.canonicalId(project.businessUnitId),
        'name': project.name,
        'repositoryUrl': project.repositoryUrl,
        'progress': project.computedProgress,
        'status': project.status,
        'currentStage': project.currentStage,
        'lastWorkedAt': project.lastWorkedAt?.toIso8601String(),
        'lastGithubAt': inspection?.lastPushedAt?.toIso8601String(),
        'lastCommit': inspection?.recentCommits.firstOrNull?.message ?? '',
        'completedFacts': completedFacts,
        'gaps': gaps,
        'nextAction': project.nextAction.isEmpty
            ? '다음 작업을 등록하십시오.'
            : project.nextAction,
        'analysisJudgement': gaps.isEmpty
            ? '등록된 근거에서 주요 보완 항목이 확인되지 않았습니다.'
            : '${gaps.length}개 보완 항목이 확인되었습니다.',
      });
    }

    final progressValues = projects
        .map((p) => p.computedProgress)
        .whereType<int>()
        .toList();
    final averageProgress = progressValues.isEmpty
        ? null
        : (progressValues.reduce((a, b) => a + b) / progressValues.length)
              .round();
    final completedCount = projects
        .where((p) => p.status == ProjectStatus.completed)
        .length;
    final activeCount = projects.where(_isActive).length;
    final recentProjectIds = <String>{
      ...logs
          .where((l) => l.workedAt?.isAfter(weekAgo) == true)
          .map((l) => l.projectId)
          .where((id) => id.isNotEmpty),
      ...inspections.entries
          .where((e) => e.value.lastPushedAt?.isAfter(weekAgo) == true)
          .map((e) => e.key),
    };
    final completeDeployments = deployments
        .where((d) => d.isFullyComplete)
        .length;
    final openIssues = issues.where((i) => i.status == 'open').length;
    final verifiedParts = <int>[
      ...averageProgress == null ? const <int>[] : [averageProgress],
      projects.isEmpty ? 0 : ((completedCount / projects.length) * 100).round(),
      deployments.isEmpty
          ? 0
          : ((completeDeployments / deployments.length) * 100).round(),
      projects.isEmpty
          ? 0
          : ((recentProjectIds.length / projects.length) * 100).round().clamp(
              0,
              100,
            ),
    ];
    final score = verifiedParts.isEmpty
        ? 0
        : (verifiedParts.reduce((a, b) => a + b) / verifiedParts.length)
              .round()
              .clamp(0, 100);
    final overallStatus = score >= 75
        ? '안정적'
        : score >= 45
        ? '주의'
        : '개선 필요';
    final sourceMetrics = <String, dynamic>{
      'businessCount': BusinessCatalog.businesses.length,
      'projectCount': projects.length,
      'activeProjectCount': activeCount,
      'completedProjectCount': completedCount,
      'recentActiveProjectCount': recentProjectIds.length,
      'averageProgress': averageProgress,
      'deploymentCompleteCount': completeDeployments,
      'githubCommitCount': inspections.values.fold<int>(
        0,
        (sum, item) => sum + item.recentCommits.length,
      ),
      'openIssueCount': openIssues,
      'completedTaskCount': tasks
          .where((t) => t.status == TaskStatus.completed)
          .length,
    };
    final comparison = _comparison(previous?.sourceMetrics, sourceMetrics);
    final priorities = businessResults
        .where((b) => b['status'] != '정상' && b['status'] != '완료')
        .map((b) => '${b['name']}: ${b['nextAction']}')
        .take(5)
        .toList();
    if (priorities.isEmpty) {
      priorities.add('등록된 진행 작업의 다음 완료 기준을 확인하십시오.');
    }

    return BusinessAnalysisReport(
      id: '',
      overallStatus: overallStatus,
      overallScore: score,
      summary:
          '실제 등록 프로젝트 ${projects.length}건, 최근 7일 활동 ${recentProjectIds.length}건, '
          '완료 배포 $completeDeployments건을 규칙 기반으로 분석했습니다.',
      businessResults: businessResults,
      projectResults: projectResults,
      weaknesses: weaknesses.isEmpty
          ? ['등록된 근거에서 공통 미흡 사항이 확인되지 않았습니다.']
          : weaknesses,
      recommendations: [
        '다음 작업이 비어 있는 진행 프로젝트를 먼저 보완합니다.',
        '테스트·README·배포 확인은 GitHub 공개 정보와 내부 기록을 함께 검토합니다.',
        '매출 데이터가 연결되기 전에는 개발 성장과 운영 준비도만 판단합니다.',
      ],
      priorities: priorities,
      sourceMetrics: sourceMetrics,
      comparison: comparison,
      githubStatus: githubErrors.isEmpty ? 'success' : 'partial_failure',
      githubError: githubErrors.join('\n'),
      sourceDataUpdatedAt: now,
    );
  }

  static bool _isActive(ProjectDoc project) =>
      project.status == ProjectStatus.inProgress ||
      project.status == ProjectStatus.testing ||
      project.status == ProjectStatus.planning;

  static int _priority(String value) {
    switch (value) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'normal':
        return 2;
      default:
        return 1;
    }
  }

  static String _businessStatus({
    required List<ProjectDoc> projects,
    required int needsAttention,
    required int? progress,
  }) {
    if (projects.isEmpty) return '보완 필요';
    if (projects.every((p) => p.status == ProjectStatus.completed)) return '완료';
    if (projects.any((p) => p.status == ProjectStatus.blocked)) return '지연';
    if (needsAttention > 0) return '주의';
    if (progress != null && progress < 30) return '보완 필요';
    return '진행 중';
  }

  static String _businessWeakness({
    required BusinessDefinition business,
    required List<ProjectDoc> projects,
    required int needsAttention,
    required List<DeploymentDoc> deployments,
    required Map<String, GithubRepositoryInspection> inspections,
  }) {
    if (projects.isEmpty) return '등록된 프로젝트가 없습니다.';
    if (needsAttention > 0) return '주의·보완이 필요한 프로젝트가 $needsAttention건 있습니다.';
    if (projects.any((p) => p.repositoryUrl.isEmpty)) {
      return 'GitHub 저장소가 연결되지 않은 프로젝트가 있습니다.';
    }
    final inspected = inspections.entries
        .where((e) => projects.any((p) => p.id == e.key))
        .map((e) => e.value)
        .toList();
    if (inspected.any((e) => !e.hasTests)) return '테스트 경로가 확인되지 않은 저장소가 있습니다.';
    if (inspected.any((e) => !e.hasReadme)) return 'README가 확인되지 않은 저장소가 있습니다.';
    if (deployments.isEmpty) return '배포 상태 기록이 없습니다.';
    if (deployments.any((d) => !d.isFullyComplete)) {
      return '배포 또는 실사이트 확인이 미완료입니다.';
    }
    return '등록된 근거에서 큰 미흡 사항이 확인되지 않았습니다.';
  }

  static Map<String, dynamic> _comparison(
    Map<String, dynamic>? previous,
    Map<String, dynamic> current,
  ) {
    if (previous == null || previous.isEmpty) return const {};
    int delta(String key) =>
        ((current[key] as num?)?.round() ?? 0) -
        ((previous[key] as num?)?.round() ?? 0);
    return {
      'projectCountDelta': delta('projectCount'),
      'completedProjectCountDelta': delta('completedProjectCount'),
      'recentActiveProjectCountDelta': delta('recentActiveProjectCount'),
      'averageProgressDelta': delta('averageProgress'),
      'deploymentCompleteCountDelta': delta('deploymentCompleteCount'),
      'openIssueCountDelta': delta('openIssueCount'),
    };
  }
}
