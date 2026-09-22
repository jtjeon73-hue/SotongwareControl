import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/ebook_r1_package_manifest.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/workshop_current_work_selection.dart';
import 'package:sotong_ware_control/widgets/ebook_package_user_review_panel.dart';

void main() {
  Map<String, dynamic> art(String path, {bool ready = true}) => {
    'path': path,
    'fileName': path.split('/').last,
    'size': 10,
    'sha256': 'abc123abc123abc123abc123abc123abc123abc123abc123abc123abc123ab',
    'remoteStatus': ready ? 'grantReady' : 'error',
    'remoteReady': ready,
    'grantReady': ready,
    'remoteUrl': ready ? 'https://storage.googleapis.com/example/$path' : '',
  };

  Map<String, dynamic> readyPackage({
    String revision = 'r1',
    bool reviewReady = true,
    String deliveryStatus = 'ready',
    bool pdfReady = true,
  }) => {
    'schemaVersion': 'ebookReviewPackage/v2',
    'contractVersion': 2,
    'revision': revision,
    'title': '50대 초보자가 AI로 첫 전자책을 만드는 방법',
    'reviewReady': reviewReady,
    'deliveryStatus': deliveryStatus,
    'manifestSHA256':
        '47ed79f9319f64f7241f8801957fe35728487b6ce91b191d86c557a16aed533c',
    'cover': art('publish/revisions/r1/cover/cover_front.png'),
    'pdf': art('publish/revisions/r1/book.pdf', ready: pdfReady),
    'epub': art('publish/revisions/r1/book.epub'),
    'qualityReport': art(
      'publish/revisions/r1/pre_review_quality_report.json',
    ),
    'manifest': art('publish/revisions/r1/package_manifest.json'),
    'quality': {'score': 100, 'criticalCount': 0, 'majorCount': 0},
    'toc': ['1장'],
  };

  test('ready r1 enables review; missing pdf grant lists gap', () {
    final ready = EbookR1PackageManifest.fromEbookReviewPackage(readyPackage());
    expect(ready.resolveCoverFileName(), 'cover_front.png');
    expect(ready.resolvePdfFileName(), 'book.pdf');
    expect(ready.resolveEpubFileName(), 'book.epub');
    expect(ready.reviewActionsEnabledForStage(1), isTrue);
    expect(ready.reviewReadinessGapsForStage(1), isEmpty);
    expect(ready.autoCheckLabel, contains('자동 검사 PASS'));
    expect(ready.userReviewGateLabel, contains('준비 완료'));

    final missingPdf = EbookR1PackageManifest.fromEbookReviewPackage(
      readyPackage(pdfReady: false),
    );
    expect(missingPdf.reviewActionsEnabled, isFalse);
    expect(
      missingPdf.reviewReadinessGaps,
      containsAll(['PDF remoteReady=false', 'PDF grantReady=false']),
    );
  });

  test('other revision does not enable approve on stage r1', () {
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(
      readyPackage(revision: 'r2'),
    );
    expect(r2.reviewActionsEnabled, isTrue);
    expect(r2.reviewActionsEnabledForStage(1), isFalse);
    expect(
      r2.reviewReadinessGapsForStage(1).join(' '),
      contains('revision 불일치'),
    );
  });

  test('grant failure / not ready keeps actions disabled', () {
    final hold = EbookR1PackageManifest.fromEbookReviewPackage(
      readyPackage(reviewReady: false, deliveryStatus: 'hold'),
    );
    expect(hold.reviewActionsEnabled, isFalse);
    expect(hold.reviewReadinessGaps, isNotEmpty);
  });

  test('Work Golden package fixture enables review actions', () {
    final fixture = File(
      'test/fixtures/ebook_complete_r1_work_payload_wi_plan_1789914868666.json',
    );
    expect(fixture.existsSync(), isTrue);
    final pkg =
        jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
    final m = EbookR1PackageManifest.fromEbookReviewPackage(pkg);
    expect(m.schemaIsV2, isTrue);
    expect(m.reviewReadyFlag, isTrue);
    expect(m.grantReady, isTrue);
    expect(m.remoteReady, isTrue);
    expect(m.deliveryStatus, 'ready');
    expect(m.resolveCoverFileName(), 'cover_front.png');
    expect(m.reviewActionsEnabledForStage(1), isTrue);
    expect(m.reviewReadinessGapsForStage(1), isEmpty);
  });

  testWidgets('panel shows distinct action labels and readiness gaps', (
    tester,
  ) async {
    final project = Sotong24RemoteProject(
      projectId: 'wi_plan_1789914868666',
      title: '50대 초보자가 AI로 첫 전자책을 만드는 방법',
      productType: 'ebook',
      currentStage: 15,
      totalStages: 18,
      progress: 80,
      status: Sotong24WorkStatus.awaitingApproval,
    );
    final stage = Sotong24RemoteStage(
      stageId: 'package_user_review',
      stageNumber: 15,
      stageName: '사용자 검토',
      status: Sotong24WorkStatus.awaitingApproval,
      revision: 1,
      approvalRequired: true,
      criteriaMet: true,
    );
    final missing = EbookR1PackageManifest.fromEbookReviewPackage(
      readyPackage(pdfReady: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EbookPackageUserReviewPanel(
              project: project,
              stage: stage,
              busy: false,
              manifest: missing,
              onApprove: () {},
              onChangesRequested: () {},
              onHold: () {},
              onPreviewPdf: () {},
              onDownloadPdf: () {},
              onDownloadEpub: () {},
              onOpenCover: () {},
              onOpenQualityReport: () {},
              onOpenManifest: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('PDF 본문 보기'), findsOneWidget);
    expect(find.text('PDF 다운로드'), findsOneWidget);
    expect(find.text('EPUB 다운로드'), findsOneWidget);
    expect(find.text('표지 보기'), findsOneWidget);
    expect(find.text('품질 보고서'), findsOneWidget);
    expect(find.textContaining('사용자 승인 필수'), findsWidgets);
    expect(find.textContaining('승인 비활성'), findsOneWidget);
    expect(find.textContaining('PDF grantReady=false'), findsOneWidget);
    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '승인'),
    );
    expect(approve.onPressed, isNull);
  });

  test('idle agent stale currentJobId is not current production', () {
    final now = DateTime.parse('2026-09-22T08:00:00.000Z');
    final staleJob = RemoteJobDoc(
      jobId: 'job_stale_other',
      ownerUid: 'owner',
      instructionId: 'wi_plan_other',
      title: '하루 10분, 생활이 편해지는 AI 활용법',
      type: 'ebook',
      status: 'running',
      assignedAgentId: 'agent_1',
      currentStage: 'draft',
      updatedAt: DateTime.parse('2026-09-20T01:00:00.000Z'),
      createdAt: DateTime.parse('2026-09-20T01:00:00.000Z'),
    );
    final agent = RemoteAgentDoc(
      agentId: 'agent_1',
      ownerUid: 'owner',
      deviceName: 'pc',
      enabled: true,
      state: 'idle',
      currentJobId: 'job_stale_other',
      lastHeartbeatAt: now,
    );
    final picked = WorkshopCurrentWorkSelection.pickCurrentExecutionJob(
      [staleJob],
      agents: [agent],
      now: now,
    );
    expect(picked, isNull);
  });
}
