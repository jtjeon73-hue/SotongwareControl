import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/business_analysis.dart';
import '../models/ops_models.dart';
import '../services/business_analysis_service.dart';
import '../services/firebase_ready.dart';
import '../services/ops_repository.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';

class AiBusinessAnalysisScreen extends StatefulWidget {
  const AiBusinessAnalysisScreen({super.key});

  @override
  State<AiBusinessAnalysisScreen> createState() =>
      _AiBusinessAnalysisScreenState();
}

class _AiBusinessAnalysisScreenState extends State<AiBusinessAnalysisScreen> {
  final _repository = OpsRepository();
  final _analysis = BusinessAnalysisService();
  bool _running = false;
  String? _error;

  Future<void> _runAnalysis() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        _repository.watchProjects().first,
        _repository.watchTasks().first,
        _repository.watchWorkLogs().first,
        _repository.watchDeployments().first,
        _repository.watchIssues().first,
        _repository.latestBusinessAnalysisReport(),
      ]);
      final report = await _analysis.analyze(
        projects: values[0] as List<ProjectDoc>,
        tasks: values[1] as List<TaskDoc>,
        logs: values[2] as List<WorkLogDoc>,
        deployments: values[3] as List<DeploymentDoc>,
        issues: values[4] as List<IssueDoc>,
        previous: values[5] as BusinessAnalysisReport?,
      );
      await _repository.saveBusinessAnalysisReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('실제 등록 데이터 기반 분석 결과를 저장했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: 'AI 사업분석',
          message: 'Firebase 연결 후 분석 이력을 저장할 수 있습니다.',
        ),
      );
    }
    return StreamBuilder<List<BusinessAnalysisReport>>(
      stream: _repository.watchBusinessAnalysisReports(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const [];
        final latest = reports.firstOrNull;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHero(
                title: 'AI 사업분석',
                subtitle:
                    'Firestore 운영 데이터와 공개 GitHub 저장소를 분석해 실제 데이터와 규칙 기반 판단을 구분합니다.',
                badge: 'AI대표 · 규칙 기반',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _running ? null : _runAnalysis,
                  icon: _running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_graph_outlined),
                  label: Text(_running ? 'GitHub·운영 데이터 분석 중…' : '전체 사업 분석 실행'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '현재 분석은 AI가 내용을 만들어내는 방식이 아니라 실제 프로젝트·작업·배포·이슈와 '
                '공개 GitHub의 커밋·README·테스트·설정 파일 존재 여부를 규칙으로 평가합니다.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: ControlColors.warningBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'GitHub 또는 분석 데이터를 불러오지 못했습니다.\n'
                      '기존 소통총관제 데이터는 유지됩니다.\n$_error',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (latest == null)
                const EmptyStatePanel(
                  title: '저장된 사업분석이 없습니다',
                  message: '전체 사업 분석 실행을 눌러 첫 기준점을 저장하십시오.',
                )
              else
                _ReportView(report: latest),
              if (reports.length > 1) ...[
                const SizedBox(height: 20),
                Text('분석 이력', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final report in reports.skip(1).take(10))
                  Card(
                    child: ListTile(
                      title: Text(
                        '${report.overallStatus} · ${report.overallScore}점',
                      ),
                      subtitle: Text(
                        report.createdAt == null
                            ? '저장 시각 확인 필요'
                            : DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(report.createdAt!),
                      ),
                      trailing: const Icon(Icons.history),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final BusinessAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 사업 종합 평가',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('상태 ${report.overallStatus}')),
                    Chip(label: Text('준비도 ${report.overallScore}점')),
                    const Chip(label: Text('규칙 기반 분석')),
                  ],
                ),
                const SizedBox(height: 8),
                Text('[실제 데이터]\n${report.summary}'),
                const SizedBox(height: 8),
                Text(
                  '[분석 판단]\n'
                  '진행률·완료·최근 활동·배포 확인 비율을 조합한 운영 준비도입니다. '
                  '매출이나 미래 성과를 추정하지 않습니다.',
                ),
                if (report.githubStatus == 'partial_failure') ...[
                  const SizedBox(height: 8),
                  Text(
                    'GitHub 일부 조회 실패\n${report.githubError}',
                    style: const TextStyle(color: ControlColors.accentWarm),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (report.comparison.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StringListCard(
            title: '지난 분석 대비 성장 지표',
            values: [
              '프로젝트 수 ${_delta(report.comparison['projectCountDelta'])}',
              '완료 프로젝트 ${_delta(report.comparison['completedProjectCountDelta'])}',
              '최근 활동 프로젝트 ${_delta(report.comparison['recentActiveProjectCountDelta'])}',
              '평균 진행률 ${_delta(report.comparison['averageProgressDelta'], suffix: '%p')}',
              '완료 배포 ${_delta(report.comparison['deploymentCompleteCountDelta'])}',
              '열린 문제 ${_delta(report.comparison['openIssueCountDelta'])}',
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text('사업별 분석', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final business in report.businessResults)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${business['name']} · ${business['status']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '[실제 데이터] 프로젝트 ${business['projectCount']} · '
                              '진행 ${business['activeCount']} · 완료 ${business['completedCount']}',
                            ),
                            Text(
                              '진행률: ${business['progress'] ?? '미설정'}'
                              '${business['progress'] == null ? '' : '%'}',
                            ),
                            const SizedBox(height: 6),
                            Text('[분석 판단] ${business['weakness']}'),
                            Text('다음 권장: ${business['nextAction']}'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _StringListCard(title: '전체 공통 미흡 사항', values: report.weaknesses),
        const SizedBox(height: 12),
        _StringListCard(title: 'AI 대표 권고 우선순위', values: report.priorities),
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('프로젝트별 분석 보기'),
          children: [
            for (final project in report.projectResults)
              ListTile(
                title: Text('${project['name']} · ${project['status']}'),
                subtitle: Text(
                  '[실제 데이터] 진행률 ${project['progress'] ?? '미설정'} · '
                  '최근 커밋 ${project['lastCommit'] == '' ? '확인 없음' : project['lastCommit']}\n'
                  '[분석 판단] ${project['analysisJudgement']}\n'
                  '다음 작업: ${project['nextAction']}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _delta(dynamic value, {String suffix = '건'}) {
    final number = (value as num?)?.round() ?? 0;
    return '${number >= 0 ? '+' : ''}$number$suffix';
  }
}

class _StringListCard extends StatelessWidget {
  const _StringListCard({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < values.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('${i + 1}. ${values[i]}'),
              ),
          ],
        ),
      ),
    );
  }
}
