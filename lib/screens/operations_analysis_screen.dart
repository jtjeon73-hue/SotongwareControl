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

/// 운영 분석 전용 화면 (사업기획·작업지시와 분리).
class OperationsAnalysisScreen extends StatefulWidget {
  const OperationsAnalysisScreen({super.key});

  @override
  State<OperationsAnalysisScreen> createState() =>
      _OperationsAnalysisScreenState();
}

class _OperationsAnalysisScreenState extends State<OperationsAnalysisScreen> {
  OpsRepository? _repository;
  final _analysis = BusinessAnalysisService();
  bool _running = false;
  String? _error;

  OpsRepository get _ops => _repository ??= OpsRepository();

  Future<void> _runAnalysis() async {
    if (_running) return;
    if (!isFirebaseReady()) {
      setState(() => _error = 'Firebase 연결이 필요합니다.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        _ops.watchProjects().first,
        _ops.watchTasks().first,
        _ops.watchWorkLogs().first,
        _ops.watchDeployments().first,
        _ops.watchIssues().first,
        _ops.latestBusinessAnalysisReport(),
      ]);
      final report = await _analysis.analyze(
        projects: values[0] as List<ProjectDoc>,
        tasks: values[1] as List<TaskDoc>,
        logs: values[2] as List<WorkLogDoc>,
        deployments: values[3] as List<DeploymentDoc>,
        issues: values[4] as List<IssueDoc>,
        previous: values[5] as BusinessAnalysisReport?,
      );
      await _ops.saveBusinessAnalysisReport(report);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHero(
            title: '운영 분석',
            subtitle: '실제 프로젝트·작업·배포·GitHub 기록을 바탕으로 사업 운영 준비도를 점검합니다.',
            badge: '운영 분석 · 규칙 기반',
          ),
          const SizedBox(height: 16),
          if (!isFirebaseReady())
            const EmptyStatePanel(
              title: '운영 분석',
              message: 'Firebase 연결 후 분석 이력을 저장할 수 있습니다.',
            )
          else
            StreamBuilder<List<BusinessAnalysisReport>>(
              stream: _ops.watchBusinessAnalysisReports(),
              builder: (context, snapshot) {
                final reports = snapshot.data ?? const [];
                final latest = reports.firstOrNull;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        label: Text(
                          _running ? 'GitHub·운영 데이터 분석 중…' : '전체 사업 분석 실행',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '현재 운영 분석은 AI가 내용을 만들어내는 방식이 아니라 실제 프로젝트·작업·배포·이슈와 '
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
                      _OpsReportView(report: latest),
                    if (reports.length > 1) ...[
                      const SizedBox(height: 20),
                      Text(
                        '분석 이력',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OpsReportView extends StatelessWidget {
  const _OpsReportView({required this.report});

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
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _OpsStringListCard(title: '전체 공통 미흡 사항', values: report.weaknesses),
        const SizedBox(height: 12),
        _OpsStringListCard(title: 'AI 대표 권고 우선순위', values: report.priorities),
      ],
    );
  }
}

class _OpsStringListCard extends StatelessWidget {
  const _OpsStringListCard({required this.title, required this.values});

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
