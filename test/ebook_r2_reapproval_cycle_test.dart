import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/ebook_r1_package_manifest.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';

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

Map<String, dynamic> _package({
  required String revision,
  bool reviewReady = true,
  String deliveryStatus = 'ready',
  bool frozen = true,
  String? epubPath,
  String? pdfPath,
  String? coverPath,
}) {
  final rev = revision.startsWith('r') ? revision : 'r$revision';
  final folder = 'publish/revisions/$rev';
  return {
    'schemaVersion': 'ebookReviewPackage/v2',
    'contractVersion': 2,
    'revision': rev,
    'title': 'frozen package $rev',
    'reviewReady': reviewReady,
    'deliveryStatus': deliveryStatus,
    'manifestSHA256': 'abc',
    'cover': _art(
      coverPath ?? '$folder/cover/cover.png',
      ready: reviewReady && deliveryStatus == 'ready',
    ),
    'pdf': _art(
      pdfPath ?? '$folder/book.pdf',
      ready: reviewReady && deliveryStatus == 'ready',
    ),
    'epub': {
      ..._art(
        epubPath ?? '$folder/book.epub',
        ready: reviewReady && deliveryStatus == 'ready',
      ),
      'sha256':
          '147d9ccc15bea8c5917296498a5dc8cbc30f85c9df9210f3730abe09c5fde3e6',
    },
    'qualityReport': _art(
      '$folder/pre_review_quality_report.json',
      ready: reviewReady && deliveryStatus == 'ready',
    ),
    'manifest': _art(
      '$folder/package_manifest.json',
      ready: reviewReady && deliveryStatus == 'ready',
    ),
    'quality': {'score': 95, 'criticalCount': 0, 'majorCount': 0},
    'toc': ['1'],
    'frozen': frozen,
    'immutablePath': folder,
  };
}

Sotong24RemoteStage _step15({
  int revision = 1,
  String approvalStatus = ApprovalStatus.pending,
  String activeRequestId = 'req_r1_changes',
  Map<String, dynamic>? package,
}) {
  return Sotong24RemoteStage(
    stageId: 'package_user_review',
    stageNumber: 15,
    stageName: '완성형 r1 사용자 검토',
    status: Sotong24WorkStatus.awaitingApproval,
    approvalRequired: true,
    criteriaMet: true,
    approvalStatus: approvalStatus,
    activeRequestId: activeRequestId,
    revision: revision,
    ebookReviewPackage: package,
  );
}

Sotong24RemoteProject _project(Sotong24RemoteStage stage) {
  return Sotong24RemoteProject(
    projectId: 'wi_test_ebook_r2_reapproval',
    title: 'R2 reapproval fixture',
    productType: ArtifactType.ebook,
    status: Sotong24WorkStatus.awaitingApproval,
    approvalStatus: stage.approvalStatus,
    currentStage: 15,
    totalStages: 18,
    progress: 80,
    finalRevision: 2,
    stages: [stage],
  );
}

void main() {
  const guard = Sotong24RemoteApprovalGuard();

  group('EbookPackageReviewContract', () {
    test('C. R2 frozen + reviewReady is trusted', () {
      final m = EbookR1PackageManifest.fromEbookReviewPackage(
        _package(revision: 'r2'),
      );
      expect(EbookPackageReviewContract.isTrustedFrozenReviewPackage(m), isTrue);
      expect(m.revisionNumber, 2);
    });

    test('I. reviewReady=false is not trusted', () {
      final m = EbookR1PackageManifest.fromEbookReviewPackage(
        _package(revision: 'r2', reviewReady: false),
      );
      expect(
        EbookPackageReviewContract.isTrustedFrozenReviewPackage(m),
        isFalse,
      );
    });

    test('J. delivery not ready is not trusted', () {
      final m = EbookR1PackageManifest.fromEbookReviewPackage(
        _package(revision: 'r2', deliveryStatus: 'pending'),
      );
      expect(
        EbookPackageReviewContract.isTrustedFrozenReviewPackage(m),
        isFalse,
      );
    });

    test('K. path/revision mismatch is not trusted', () {
      final m = EbookR1PackageManifest.fromEbookReviewPackage(
        _package(
          revision: 'r2',
          epubPath: 'publish/revisions/r1/book.epub',
          pdfPath: 'publish/revisions/r1/book.pdf',
          coverPath: 'publish/revisions/r1/cover/cover.png',
        ),
      );
      expect(m.frozenPathsMatchPackageRevision, isFalse);
      expect(
        EbookPackageReviewContract.isTrustedFrozenReviewPackage(m),
        isFalse,
      );
    });
  });

  group('validateSubmit / allocateRequestId R2 cycle', () {
    test('D/E/F. stale revision_requested + package r2 allows new approve', () {
      final stage = _step15(
        revision: 1,
        approvalStatus: ApprovalStatus.revisionRequested,
        package: _package(revision: 'r2'),
      );
      final existing = [
        const Sotong24RemoteRequest(
          requestId: 'req_r1_changes',
          projectId: 'wi_test_ebook_r2_reapproval',
          stageId: 'package_user_review',
          requestType: 'revision_request',
          status: ApprovalStatus.revisionRequested,
          revision: 1,
        ),
      ];
      final package = EbookPackageReviewContract.tryParsePackage(
        stage.ebookReviewPackage,
      );
      final canonical = EbookPackageReviewContract.canonicalReviewRevision(
        stageId: stage.stageId,
        stageRevision: stage.revision,
        package: package,
      );
      expect(canonical, 2);

      final nextId = Sotong24RemoteApprovalGuard.allocateRequestId(
        stage: stage,
        existingRequests: existing,
        preferred: 'req_r1_changes',
        reviewRevision: canonical,
        now: DateTime.utc(2026, 9, 27, 12),
      );
      expect(nextId, isNot('req_r1_changes'));
      expect(nextId, startsWith('req_package_user_review_'));

      final err = guard.validateSubmit(
        project: _project(stage),
        stageId: 'package_user_review',
        requestId: nextId,
        existingRequests: existing,
        reviewRevision: canonical,
      );
      expect(err, isNull);
    });

    test('G. same R2 terminal approve is blocked', () {
      final stage = _step15(
        revision: 1,
        approvalStatus: ApprovalStatus.revisionRequested,
        package: _package(revision: 'r2'),
      );
      final existing = [
        const Sotong24RemoteRequest(
          requestId: 'req_r1_changes',
          projectId: 'wi_test_ebook_r2_reapproval',
          stageId: 'package_user_review',
          requestType: 'revision_request',
          status: ApprovalStatus.revisionRequested,
          revision: 1,
        ),
        const Sotong24RemoteRequest(
          requestId: 'req_r2_approve',
          projectId: 'wi_test_ebook_r2_reapproval',
          stageId: 'package_user_review',
          requestType: 'approve',
          status: ApprovalStatus.approved,
          revision: 2,
        ),
      ];
      final err = guard.validateSubmit(
        project: _project(stage),
        stageId: 'package_user_review',
        requestId: 'req_r2_dup',
        existingRequests: existing,
        reviewRevision: 2,
      );
      expect(err, isNotNull);
      expect(
        err,
        anyOf(contains('이미 처리'), contains('이미 반영')),
      );
      expect(err, isNot(contains('처리 중')));
    });

    test('H. pending active request blocks duplicate submit', () {
      final stage = _step15(
        revision: 2,
        approvalStatus: ApprovalStatus.pending,
        activeRequestId: 'req_open',
        package: _package(revision: 'r2'),
      );
      final existing = [
        const Sotong24RemoteRequest(
          requestId: 'req_open',
          projectId: 'wi_test_ebook_r2_reapproval',
          stageId: 'package_user_review',
          requestType: 'approve',
          status: ApprovalStatus.pending,
          revision: 2,
        ),
      ];
      final err = guard.validateSubmit(
        project: _project(stage),
        stageId: 'package_user_review',
        requestId: 'req_other',
        existingRequests: existing,
        reviewRevision: 2,
      );
      expect(err, isNotNull);
      expect(err, contains('대기 중인 다른 요청'));
    });

    test('I. reviewReady=false blocks submit', () {
      final stage = _step15(
        revision: 1,
        approvalStatus: ApprovalStatus.revisionRequested,
        package: _package(revision: 'r2', reviewReady: false),
      );
      final err = guard.validateSubmit(
        project: _project(stage),
        stageId: 'package_user_review',
        requestId: 'req_new',
        existingRequests: const [],
        reviewRevision: 2,
      );
      expect(err, isNotNull);
    });

    test('J. delivery not ready blocks submit', () {
      final stage = _step15(
        revision: 1,
        approvalStatus: ApprovalStatus.revisionRequested,
        package: _package(revision: 'r2', deliveryStatus: 'holding'),
      );
      final err = guard.validateSubmit(
        project: _project(stage),
        stageId: 'package_user_review',
        requestId: 'req_new',
        existingRequests: const [],
        reviewRevision: 2,
      );
      expect(err, isNotNull);
    });

    test('K. path mismatch blocks submit', () {
      final stage = _step15(
        revision: 1,
        approvalStatus: ApprovalStatus.revisionRequested,
        package: _package(
          revision: 'r2',
          epubPath: 'publish/revisions/r1/book.epub',
          pdfPath: 'publish/revisions/r1/book.pdf',
          coverPath: 'publish/revisions/r1/cover/cover.png',
        ),
      );
      final err = guard.validateSubmit(
        project: _project(stage),
        stageId: 'package_user_review',
        requestId: 'req_new',
        existingRequests: const [],
        reviewRevision: 2,
      );
      expect(err, isNotNull);
      expect(err, contains('revision 불일치'));
    });

    test('stale terminal message is not "처리 중"', () {
      final stage = _step15(
        revision: 1,
        approvalStatus: ApprovalStatus.revisionRequested,
        package: null,
      );
      final err = guard.validateSubmit(
        project: _project(stage),
        stageId: 'package_user_review',
        requestId: 'req_new',
        existingRequests: const [
          Sotong24RemoteRequest(
            requestId: 'req_r1_changes',
            projectId: 'wi_test_ebook_r2_reapproval',
            stageId: 'package_user_review',
            requestType: 'revision_request',
            status: ApprovalStatus.revisionRequested,
            revision: 1,
          ),
        ],
      );
      expect(err, isNotNull);
      expect(err, contains('이미 반영'));
      expect(err, isNot(contains('처리 중')));
    });
  });

  group('repository memory', () {
    test('A. R1 최초 승인 request.revision=1', () async {
      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [
          _project(
            _step15(
              revision: 1,
              approvalStatus: ApprovalStatus.pending,
              activeRequestId: 'req_r1_slot',
              package: _package(revision: 'r1'),
            ),
          ),
        ],
      );
      addTearDown(repo.dispose);
      expect(
        await repo.approveStage(
          projectId: 'wi_test_ebook_r2_reapproval',
          stageId: 'package_user_review',
          requestId: 'req_r1_slot',
          reviewedRevision: 'r1',
        ),
        isNull,
      );
      final reqs = await repo.listRequests('wi_test_ebook_r2_reapproval');
      expect(reqs.single.requestType, 'approve');
      expect(reqs.single.revision, 1);
    });

    test('B. R1 changes_requested request.revision=1', () async {
      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [
          _project(
            _step15(
              revision: 1,
              approvalStatus: ApprovalStatus.pending,
              activeRequestId: 'req_r1_slot',
              package: _package(revision: 'r1'),
            ),
          ),
        ],
      );
      addTearDown(repo.dispose);
      expect(
        await repo.requestRevision(
          projectId: 'wi_test_ebook_r2_reapproval',
          stageId: 'package_user_review',
          requestId: 'req_r1_slot',
          message: '보완 요청',
          reviewDecision: 'changes_requested',
        ),
        isNull,
      );
      final reqs = await repo.listRequests('wi_test_ebook_r2_reapproval');
      expect(reqs.single.status, ApprovalStatus.revisionRequested);
      expect(reqs.single.revision, 1);
    });

    test('D/E/F. stale r1 terminal + r2 package creates approve revision=2',
        () async {
      // Bootstrap R1 changes_requested so request history exists in memory.
      final bootstrap = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [
          _project(
            _step15(
              revision: 1,
              approvalStatus: ApprovalStatus.pending,
              activeRequestId: 'req_r1_changes',
              package: _package(revision: 'r1'),
            ),
          ),
        ],
      );
      addTearDown(bootstrap.dispose);
      expect(
        await bootstrap.requestRevision(
          projectId: 'wi_test_ebook_r2_reapproval',
          stageId: 'package_user_review',
          requestId: 'req_r1_changes',
          message: 'changes',
          reviewDecision: 'changes_requested',
        ),
        isNull,
      );

      final after = await bootstrap.getProject('wi_test_ebook_r2_reapproval');
      final stale = after!.stages.first.copyWith(
        revision: 1,
        approvalStatus: ApprovalStatus.revisionRequested,
        status: Sotong24WorkStatus.awaitingApproval,
        criteriaMet: true,
        ebookReviewPackage: _package(revision: 'r2'),
        replaceEbookReviewPackage: true,
      );
      final patched = after.copyWith(
        stages: [stale],
        status: Sotong24WorkStatus.awaitingApproval,
        approvalStatus: ApprovalStatus.revisionRequested,
        finalRevision: 2,
      );

      // Transplant project+requests is not supported across repos; mutate the
      // same memory store by replacing via a fresh repo that only has project,
      // then rely on guard-level coverage for request history + a direct approve
      // on patched project without prior requests using package r2 identity.
      final fresh = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [patched],
      );
      addTearDown(fresh.dispose);

      // Without prior requests, latestTerminal falls back to stage.revision=1.
      final err = await fresh.approveStage(
        projectId: 'wi_test_ebook_r2_reapproval',
        stageId: 'package_user_review',
        requestId: 'req_r1_changes',
        reviewedRevision: 'r2',
      );
      expect(err, isNull);
      final reqs = await fresh.listRequests('wi_test_ebook_r2_reapproval');
      final approve = reqs.firstWhere((r) => r.requestType == 'approve');
      expect(approve.revision, 2);
      expect(approve.requestId, isNot('req_r1_changes'));
    });
  });

  test('M. EPUB/PDF contract unchanged for r2 package', () {
    final m = EbookR1PackageManifest.fromEbookReviewPackage(
      _package(revision: 'r2'),
    );
    expect(m.downloadEpubAttachmentName(), 'ebook_r2.epub');
    expect(
      m.epubSha256,
      '147d9ccc15bea8c5917296498a5dc8cbc30f85c9df9210f3730abe09c5fde3e6',
    );
    expect(m.frozenPathsMatchPackageRevision, isTrue);
  });
}
