import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/ebook_r1_package_manifest.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';
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

Sotong24RemoteStage _finalStage({
  required String status,
  required bool criteriaMet,
  int revision = 1,
  Map<String, dynamic>? package,
}) {
  return Sotong24RemoteStage(
    stageId: 'final_user_approval',
    stageNumber: 17,
    stageName: '최종 사용자 승인',
    status: status,
    approvalRequired: true,
    criteriaMet: criteriaMet,
    revision: revision,
    approvalStatus: ApprovalStatus.pending,
    ebookReviewPackage: package,
  );
}

Sotong24RemoteStage _step18() => const Sotong24RemoteStage(
  stageId: 'publication_package',
  stageNumber: 18,
  stageName: '출시 준비 패키지',
  status: Sotong24WorkStatus.ready,
);

Sotong24RemoteProject _project(Sotong24RemoteStage gate) {
  return Sotong24RemoteProject(
    projectId: 'wi_plan_final_noop',
    title: 'final book',
    productType: 'ebook',
    currentStage: 17,
    totalStages: 18,
    progress: 90,
    status: gate.status,
    approvalStatus: ApprovalStatus.pending,
    lastHeartbeat: DateTime.now().toUtc().toIso8601String(),
    stages: [gate, _step18()],
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required Sotong24RemoteProject project,
  required Sotong24RemoteStage stage,
  required EbookR1PackageManifest? manifest,
  VoidCallback? onApprove,
  VoidCallback? onChangesRequested,
  VoidCallback? onHold,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EbookPackageUserReviewPanel(
            project: project,
            stage: stage,
            busy: false,
            manifest: manifest,
            onApprove: onApprove,
            onChangesRequested: onChangesRequested,
            onHold: onHold,
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
}

void main() {
  test('D: authoritative r2 wins over stale stage.revision=1', () {
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(_trustedR2Raw());
    expect(
      EbookPackageReviewContract.authoritativeFinalApprovalRevision(
        stageId: 'final_user_approval',
        stageRevision: 1,
        package: r2,
      ),
      2,
    );
    expect(r2.reviewActionsEnabledForAuthoritativePackage(1), isTrue);
  });

  test('A: showApprovalActions true for awaiting+criteriaMet+r2 gate', () {
    final gate = _finalStage(
      status: Sotong24WorkStatus.awaitingApproval,
      criteriaMet: true,
      revision: 1,
      package: _trustedR2Raw(),
    );
    final project = _project(gate);
    expect(project.showApprovalActions, isTrue);
  });

  test('B: showApprovalActions false when criteriaMet=false', () {
    final gate = _finalStage(
      status: Sotong24WorkStatus.awaitingApproval,
      criteriaMet: false,
      package: _trustedR2Raw(),
    );
    expect(_project(gate).showApprovalActions, isFalse);
  });

  test('C: showApprovalActions false when not awaiting_approval', () {
    final gate = _finalStage(
      status: Sotong24WorkStatus.inProgress,
      criteriaMet: true,
      package: _trustedR2Raw(),
    );
    expect(_project(gate).showApprovalActions, isFalse);
  });

  testWidgets(
    'A/H: awaiting+criteriaMet+r2 enables approve callback (no no-op)',
    (tester) async {
      final raw = _trustedR2Raw();
      final r2 = EbookR1PackageManifest.fromEbookReviewPackage(raw);
      final gate = _finalStage(
        status: Sotong24WorkStatus.awaitingApproval,
        criteriaMet: true,
        revision: 1,
        package: raw,
      );
      final project = _project(gate);
      expect(project.showApprovalActions, isTrue);

      var approved = false;
      await _pumpPanel(
        tester,
        project: project,
        stage: gate,
        manifest: r2,
        onApprove: () => approved = true,
        onChangesRequested: () {},
        onHold: () {},
      );

      final approve = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '승인'),
      );
      expect(approve.onPressed, isNotNull);
      approve.onPressed!();
      expect(approved, isTrue);
      expect(find.textContaining('revision r2'), findsWidgets);
    },
  );

  testWidgets('B/H: criteriaMet=false → approve disabled (null, not no-op)', (
    tester,
  ) async {
    final raw = _trustedR2Raw();
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(raw);
    final gate = _finalStage(
      status: Sotong24WorkStatus.awaitingApproval,
      criteriaMet: false,
      package: raw,
    );
    final project = _project(gate);
    expect(project.showApprovalActions, isFalse);

    var approved = false;
    await _pumpPanel(
      tester,
      project: project,
      stage: gate,
      manifest: r2,
      // Parent must pass null when actions disabled — never () {}.
      onApprove: null,
      onChangesRequested: null,
      onHold: null,
    );

    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '승인'),
    );
    final revise = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '보완 요청'),
    );
    final hold = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '보류'),
    );
    expect(approve.onPressed, isNull);
    expect(revise.onPressed, isNull);
    expect(hold.onPressed, isNull);
    expect(approved, isFalse);
  });

  testWidgets('C/H: not awaiting → approve disabled when callback null', (
    tester,
  ) async {
    final raw = _trustedR2Raw();
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(raw);
    final gate = _finalStage(
      status: Sotong24WorkStatus.ready,
      criteriaMet: true,
      package: raw,
    );
    expect(_project(gate).showApprovalActions, isFalse);

    await _pumpPanel(
      tester,
      project: _project(gate),
      stage: gate,
      manifest: r2,
      onApprove: null,
      onChangesRequested: null,
      onHold: null,
    );

    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '승인'),
    );
    expect(approve.onPressed, isNull);
  });

  testWidgets('H: empty () {} must not look enabled when review package ready', (
    tester,
  ) async {
    // Regression: previously parent passed onApprove: () {} while
    // reviewEnabled==true → button looked active but did nothing.
    final raw = _trustedR2Raw();
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(raw);
    final gate = _finalStage(
      status: Sotong24WorkStatus.ready,
      criteriaMet: true,
      package: raw,
    );
    expect(r2.reviewActionsEnabledForAuthoritativePackage(1), isTrue);

    await _pumpPanel(
      tester,
      project: _project(gate),
      stage: gate,
      manifest: r2,
      onApprove: null,
      onChangesRequested: null,
      onHold: null,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '승인'))
          .onPressed,
      isNull,
    );
  });

  test('E: STEP15 package_user_review authoritative r2 still enables', () {
    final r2 = EbookR1PackageManifest.fromEbookReviewPackage(_trustedR2Raw());
    expect(
      EbookPackageReviewContract.canonicalReviewRevision(
        stageId: 'package_user_review',
        stageRevision: 1,
        package: r2,
      ),
      2,
    );
    expect(r2.reviewActionsEnabledForAuthoritativePackage(1), isTrue);
  });

  test('G: approveStage does not advance to STEP18 publication_package', () async {
    final raw = _trustedR2Raw();
    final gate = _finalStage(
      status: Sotong24WorkStatus.awaitingApproval,
      criteriaMet: true,
      revision: 1,
      package: raw,
    );
    final project = _project(gate);
    final repo = Sotong24RemoteRepository(
      forceMemory: true,
      memorySeed: [project],
    );
    addTearDown(repo.dispose);
    final err = await repo.approveStage(
      projectId: project.projectId,
      stageId: 'final_user_approval',
      requestId: 'req_final_user_approval_test',
      reviewedRevision: 'r2',
    );
    expect(err, isNull);
    final after = await repo.getProject(project.projectId);
    expect(after, isNotNull);
    expect(after!.currentStage, 17);
    final step18 = after.stages.firstWhere(
      (s) => s.stageId == 'publication_package',
    );
    expect(step18.status, Sotong24WorkStatus.ready);
    expect(step18.status, isNot(Sotong24WorkStatus.inProgress));
    expect(step18.status, isNot(Sotong24WorkStatus.completed));
    final step17 = after.stages.firstWhere(
      (s) => s.stageId == 'final_user_approval',
    );
    expect(step17.approvalStatus, ApprovalStatus.approved);
  });

  test('F: requestRevision/on_hold still allowed when actions enabled', () async {
    final raw = _trustedR2Raw();
    final gate = _finalStage(
      status: Sotong24WorkStatus.awaitingApproval,
      criteriaMet: true,
      revision: 1,
      package: raw,
    );
    final project = _project(gate);
    final repo = Sotong24RemoteRepository(
      forceMemory: true,
      memorySeed: [project],
    );
    addTearDown(repo.dispose);
    final err = await repo.requestRevision(
      projectId: project.projectId,
      stageId: 'final_user_approval',
      requestId: 'req_final_hold_test',
      message:
          '[reviewDecision=on_hold]\n[reviewedRevision=r2]\n최종 사용자 승인 보류',
      reviewDecision: 'on_hold',
    );
    expect(err, isNull);
    final after = await repo.getProject(project.projectId);
    expect(after!.currentStage, 17);
    expect(
      after.stages.firstWhere((s) => s.stageId == 'publication_package').status,
      Sotong24WorkStatus.ready,
    );
  });
}
