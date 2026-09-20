import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/remote_agent_repository.dart';
import 'package:sotong_ware_control/services/remote_job_progress_presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RemoteJobDoc job({
    String currentStage = 'format_build',
    int progress = 0,
    String status = 'result_validation_failed',
  }) {
    return RemoteJobDoc(
      jobId: 'job_ebook_format',
      ownerUid: 'u1',
      title: '하루 10분, 생활이 편해지는 AI 활용법',
      type: 'ebook',
      status: status,
      assignedAgentId: 'agent_1',
      instructionId: 'wi_plan_ebook_20260916',
      currentStage: currentStage,
      totalStages: 18,
      progress: progress,
    );
  }

  group('RemoteJobProgressPresentation', () {
    test('STEP13 + progress=0 → 상태 불일치 (가짜 % 금지)', () {
      final stages = [
        const RemoteStageDoc(
          stageId: 'idea_clarify',
          stageNumber: 1,
          stageName: '아이디어',
          status: 'running',
        ),
        const RemoteStageDoc(
          stageId: 'format_build',
          stageNumber: 13,
          stageName: 'PDF/EPUB 빌드',
          status: 'result_validation_failed',
        ),
      ];
      final j = job();
      expect(
        RemoteJobProgressPresentation.hasProgressInconsistency(j, stages),
        isTrue,
      );
      expect(
        RemoteJobProgressPresentation.hasStageStatusConflict(j, stages),
        isTrue,
      );
      expect(
        RemoteJobProgressPresentation.shouldShowProgressBar(j, stages),
        isFalse,
      );
      final banner = RemoteJobProgressPresentation.inconsistencyBanner(
        j,
        stages,
      );
      expect(banner, contains('상태 불일치/진단 필요'));
      expect(banner, contains('progress=0%'));
      expect(
        RemoteJobProgressPresentation.progressCaption(j, stages),
        contains('진단 필요'),
      );
    });

    test('정상 progress는 바를 표시하고 진단 배너는 없음', () {
      final stages = [
        const RemoteStageDoc(
          stageId: 'format_build',
          stageNumber: 13,
          stageName: 'PDF/EPUB 빌드',
          status: 'running',
        ),
      ];
      final j = job(progress: 72, status: 'running');
      expect(
        RemoteJobProgressPresentation.hasProgressInconsistency(j, stages),
        isFalse,
      );
      expect(
        RemoteJobProgressPresentation.shouldShowProgressBar(j, stages),
        isTrue,
      );
      expect(
        RemoteJobProgressPresentation.inconsistencyBanner(j, stages),
        isNull,
      );
      expect(
        RemoteJobProgressPresentation.progressCaption(j, stages),
        '전체 진행률 72%',
      );
    });
  });

  testWidgets('Job 상세에서 progress=0 모순을 진단 배너로 표시', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = RemoteAgentRepository(
      forceMemory: true,
      memoryJobs: [job()],
      memoryStages: {
        'job_ebook_format': [
          const RemoteStageDoc(
            stageId: 'idea_clarify',
            stageNumber: 1,
            stageName: '아이디어',
            status: 'running',
          ),
          const RemoteStageDoc(
            stageId: 'format_build',
            stageNumber: 13,
            stageName: 'PDF/EPUB 빌드',
            status: 'result_validation_failed',
          ),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _JobDetailHarness(
                        repo: repo,
                        jobId: 'job_ebook_format',
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('job_progress_inconsistency_banner')),
      findsOneWidget,
    );
    expect(find.textContaining('상태 불일치/진단 필요'), findsOneWidget);
    expect(find.textContaining('진단 필요'), findsWidgets);
    expect(find.textContaining('이전 단계 잔여 상태'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// RemoteControlScreen의 private _JobDetailPage와 동일 계약을 검증하기 위해
/// 공개 화면 진입 대신 저장소+동일 presentation을 쓰는 래퍼.
class _JobDetailHarness extends StatelessWidget {
  const _JobDetailHarness({required this.repo, required this.jobId});

  final RemoteAgentRepository repo;
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('작업 상세')),
      body: StreamBuilder<RemoteJobDoc?>(
        stream: repo.watchJob(jobId),
        builder: (context, jobSnap) {
          final job = jobSnap.data;
          if (job == null) {
            return const Center(child: Text('작업을 찾을 수 없습니다.'));
          }
          return StreamBuilder<List<RemoteStageDoc>>(
            stream: repo.watchStages(jobId),
            builder: (context, stageSnap) {
              final stages = stageSnap.data ?? const <RemoteStageDoc>[];
              final banner = RemoteJobProgressPresentation.inconsistencyBanner(
                job,
                stages,
              );
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(job.title),
                  if (banner != null)
                    Text(
                      banner,
                      key: const Key('job_progress_inconsistency_banner'),
                    ),
                  Text(
                    RemoteJobProgressPresentation.progressCaption(job, stages),
                  ),
                  for (final s in stages)
                    Text(
                      '${s.stageId}:${s.status}'
                      '${RemoteJobProgressPresentation.hasStageStatusConflict(job, stages) && s.status == 'running' && s.stageId != job.currentStage ? ' · 이전 단계 잔여 상태(진단 필요)' : ''}',
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
