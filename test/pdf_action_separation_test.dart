import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/pdf_download_service.dart';
import 'package:sotong_ware_control/widgets/pdf_download_button.dart';
import 'package:sotong_ware_control/widgets/result_link_button.dart';
import 'package:sotong_ware_control/widgets/sotong24_stage_widgets.dart';

void main() {
  const pdfUrl =
      'https://storage.googleapis.com/example/wi_plan_mobile/maintain/r1/final_ebook.pdf?signature=viewer';
  const stage = Sotong24RemoteStage(
    stageId: 'maintain',
    stageNumber: 18,
    stageName: 'maintain',
    status: Sotong24WorkStatus.completed,
    revision: 1,
    resultUrl: pdfUrl,
  );
  const project = Sotong24RemoteProject(
    projectId: 'wi_plan_mobile',
    title: 'AI 전자책',
    productType: 'ebook',
    currentStage: 18,
    totalStages: 18,
    progress: 100,
    status: Sotong24WorkStatus.completed,
    finalRevision: 1,
    stages: [stage],
  );

  testWidgets('mobile PDF view, download and result-detail callbacks differ', (
    tester,
  ) async {
    var viewCalls = 0;
    var detailCalls = 0;
    final downloader = _FakePdfDownloader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ResultLinkButton(
                  key: const Key('mobile_pdf_view'),
                  url: pdfUrl,
                  label: 'PDF 보기',
                  opener: (_) async {
                    viewCalls++;
                    return true;
                  },
                ),
                PdfDownloadButton(
                  key: const Key('mobile_pdf_download'),
                  projectId: project.projectId,
                  stageId: stage.stageId,
                  title: project.title,
                  revision: stage.revision,
                  downloader: downloader,
                ),
                Sotong24StageResultOpenButtons(
                  stage: stage,
                  project: project,
                  detailOpener: (_) async => detailCalls++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mobile_pdf_view')));
    await tester.pumpAndSettle();
    expect((viewCalls, downloader.calls, detailCalls), (1, 0, 0));

    await tester.tap(find.byKey(const Key('mobile_pdf_download')));
    await tester.pumpAndSettle();
    expect((viewCalls, downloader.calls, detailCalls), (1, 1, 0));
    expect(find.textContaining('다운로드를 시작했습니다.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile_pdf_view')));
    await tester.pumpAndSettle();
    expect((viewCalls, downloader.calls, detailCalls), (2, 1, 0));
    expect(find.textContaining('다운로드를 시작했습니다.'), findsNothing);

    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).showSnackBar(const SnackBar(content: Text('다운로드 관련 이전 메시지')));
    await tester.pump();
    expect(find.text('다운로드 관련 이전 메시지'), findsOneWidget);

    await tester.tap(find.byKey(const Key('result_detail_maintain')));
    await tester.pumpAndSettle();
    expect((viewCalls, downloader.calls, detailCalls), (2, 1, 1));
    expect(find.text('다운로드 관련 이전 메시지'), findsNothing);
  });

  testWidgets('result-detail entry has no view or download side effect', (
    tester,
  ) async {
    var viewCalls = 0;
    final downloader = _FakePdfDownloader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Sotong24StageResultOpenButtons(
            stage: stage,
            project: project,
            resultOpener: (_) async {
              viewCalls++;
              return true;
            },
            pdfDownloader: downloader,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('result_detail_maintain')));
    await tester.pumpAndSettle();
    expect(find.text('결과물 상세'), findsOneWidget);
    expect((viewCalls, downloader.calls), (0, 0));

    await tester.tap(find.byKey(const Key('stage_result_view_maintain')));
    await tester.pumpAndSettle();
    expect((viewCalls, downloader.calls), (1, 0));

    await tester.tap(find.byKey(const Key('stage_result_download_maintain')));
    await tester.pumpAndSettle();
    expect((viewCalls, downloader.calls), (1, 1));
  });
}

class _FakePdfDownloader implements PdfDownloader {
  int calls = 0;

  @override
  Future<PdfDownloadResult> downloadPdf({
    required String projectId,
    required String stageId,
    required String title,
    required int revision,
  }) async {
    calls++;
    expect(projectId, 'wi_plan_mobile');
    expect(stageId, 'maintain');
    expect(revision, 1);
    return PdfDownloadResult.success(
      fileName: 'AI_전자책_r1.pdf',
      sizeBytes: 142571,
    );
  }
}
