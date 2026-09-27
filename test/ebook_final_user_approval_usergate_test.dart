import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/ebook_r1_package_manifest.dart';
import 'package:sotong_ware_control/models/sotong24_monitoring.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/widgets/ebook_package_user_review_panel.dart';

Map<String, dynamic> _art(String path, {bool ready = true}) => {
  'path': path,
  'fileName': path.split('/').last,
  'size': 10,
  'sha256': 'abc',
  'remoteStatus': ready ? 'grantReady' : 'error',
  'remoteReady': ready,
  'grantReady': ready,
  'remoteUrl': ready ? 'https://example.com/$path' : '',
};

Map<String, dynamic> _trustedR2Raw() => {
  'schemaVersion': 'ebookReviewPackage/v2',
  'contractVersion': 2,
  'revision': 'r2',
  'title': 'frozen r2 final',
  'reviewReady': true,
  'deliveryStatus': 'ready',
  'manifestSHA256': 'abc',
  'cover': _art('publish/revisions/r2/cover/cover.png'),
  'pdf': _art('publish/revisions/r2/book.pdf'),
  'epub': {
    ..._art('publish/revisions/r2/book.epub'),
    'sha256':
        '147d9ccc15bea8c5917296498a5dc8cbc30f85c9df9210f3730abe09c5fde3e6',
  },
  'qualityReport': _art(
    'publish/revisions/r2/pre_review_quality_report.json',
  ),
  'manifest': _art('publish/revisions/r2/package_manifest.json'),
  'quality': {'score': 95, 'criticalCount': 0, 'majorCount': 0},
  'toc': ['1'],
  'frozen': true,
  'immutablePath': 'publish/revisions/r2',
};

void main() {
  test('F/G: authoritative R2 wins over stale stage r1 for final approval', () {
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(_trustedR2Raw());
    expect(
      EbookPackageReviewContract.authoritativeFinalApprovalRevision(
        stageId: 'final_user_approval',
        stageRevision: 1,
        package: r2,
      ),
      2,
    );
  });

  test('H: final approval fails closed without trusted package', () {
    expect(
      EbookPackageReviewContract.authoritativeFinalApprovalRevision(
        stageId: 'final_user_approval',
        stageRevision: 1,
        package: null,
      ),
      isNull,
    );
    final incomplete = EbookR1PackageManifest.fromEbookReviewPackage({
      'schemaVersion': 'ebookReviewPackage/v2',
      'revision': 'r2',
      'title': 'incomplete',
      'reviewReady': false,
      'frozen': true,
      'immutablePath': 'publish/revisions/r2',
      'pdf': _art('publish/revisions/r2/book.pdf', ready: false),
      'epub': _art('publish/revisions/r2/book.epub', ready: false),
      'cover': _art('publish/revisions/r2/cover/cover.png', ready: false),
      'qualityReport': _art(
        'publish/revisions/r2/pre_review_quality_report.json',
        ready: false,
      ),
      'manifest': _art(
        'publish/revisions/r2/package_manifest.json',
        ready: false,
      ),
    });
    expect(
      EbookPackageReviewContract.authoritativeFinalApprovalRevision(
        stageId: 'final_user_approval',
        stageRevision: 1,
        package: incomplete,
      ),
      isNull,
    );
  });

  test('I: package_user_review canonical revision regression', () {
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(_trustedR2Raw());
    expect(
      EbookPackageReviewContract.canonicalReviewRevision(
        stageId: 'package_user_review',
        stageRevision: 1,
        package: r2,
      ),
      2,
    );
  });

  testWidgets('D/E: final approval panel shows review copy and actions', (
    tester,
  ) async {
    final raw = _trustedR2Raw();
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(raw);
    final stage = Sotong24RemoteStage(
      stageId: 'final_user_approval',
      stageNumber: 17,
      stageName: '최종 사용자 승인',
      status: Sotong24WorkStatus.awaitingApproval,
      approvalRequired: true,
      criteriaMet: true,
      revision: 1,
      ebookReviewPackage: raw,
    );
    final project = Sotong24RemoteProject(
      projectId: 'wi_final',
      title: 'final book',
      productType: 'ebook',
      currentStage: 17,
      totalStages: 18,
      progress: 90,
      status: Sotong24WorkStatus.awaitingApproval,
      lastHeartbeat: DateTime.now().toUtc().toIso8601String(),
      stages: [stage],
    );
    var approved = false;
    var revised = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const Text('17단계 · 최종 사용자 승인'),
                const Text('최종 결과를 확인한 뒤 승인 또는 보완 요청을 선택하세요.'),
                Text('결과 버전 r${r2.revisionNumber}'),
                EbookPackageUserReviewPanel(
                  project: project,
                  stage: stage,
                  busy: false,
                  manifest: r2,
                  onApprove: () => approved = true,
                  onChangesRequested: () => revised = true,
                  onHold: () {},
                  onPreviewPdf: () {},
                  onDownloadPdf: () {},
                  onDownloadEpub: () {},
                  onOpenCover: () {},
                  onOpenQualityReport: () {},
                  onOpenManifest: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('17단계 · 최종 사용자 승인'), findsOneWidget);
    expect(
      find.textContaining('최종 결과를 확인한 뒤 승인 또는 보완 요청을 선택하세요.'),
      findsOneWidget,
    );
    expect(find.text('결과 버전 r2'), findsOneWidget);
    expect(find.text('결과 버전 r1'), findsNothing);
    expect(find.text('PDF 본문 보기'), findsOneWidget);
    expect(find.text('PDF 다운로드'), findsOneWidget);
    expect(find.text('EPUB 다운로드'), findsOneWidget);
    expect(find.textContaining('revision r2'), findsWidgets);
    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '승인'),
    );
    final revise = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '보완 요청'),
    );
    expect(approve.onPressed, isNotNull);
    expect(revise.onPressed, isNotNull);
    approve.onPressed!();
    revise.onPressed!();
    expect(approved, isTrue);
    expect(revised, isTrue);

    final health = Sotong24StageMonitoring.evaluate(
      project: project,
      stage: stage,
    );
    expect(health.health, Sotong24StageHealth.awaitingUser);
  });
}
