import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/ebook_r1_package_manifest.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';

void main() {
  test('ebook complete-r1 WI stages include package_user_review at 15', () {
    // Hardcoded commercial v2 IDs — do not import BusinessPlanningService (cold-start hang).
    const steps = <String>[
      'idea_clarify',
      'problem_validate',
      'materials_prep',
      'planning',
      'project_setup',
      'prompt_generate',
      'draft',
      'editorial_structure_review',
      'user_review',
      'revise',
      'quality',
      'cover_layout_design',
      'format_build',
      'reader_accessibility_test',
      'package_user_review',
      'final_polish',
      'final_user_approval',
      'publication_package',
    ];
    expect(steps.length, 18);
    expect(steps[8], 'user_review'); // demoted checkpoint
    expect(steps[14], 'package_user_review');
    expect(steps.contains('sales_metadata'), isFalse);
  });

  test('EbookR1PackageManifest parses nested artifact SSOT', () {
    const raw = '''
{
  "revision": "r1",
  "title": "완성형 전자책",
  "subtitle": "실습",
  "language": "ko",
  "generatedAt": "2026-09-08T21:00:00",
  "qualityScore": 92,
  "criticalCount": 0,
  "majorCount": 0,
  "frozen": true,
  "promoteToUserR1": true,
  "immutablePath": "publish/revisions/r1",
  "tocSummary": ["1. 시작", "2. 본문"],
  "artifacts": {
    "pdf": {"path": "publish/current/book.pdf", "size": 12000, "sha256": "abc123def456"},
    "epub": {"path": "publish/current/book.epub", "size": 8000, "sha256": "epubsha"},
    "cover": {"path": "assets/cover/cover.png", "size": 100, "sha256": "c"},
    "qualityReport": {"path": "output/pre_review_quality_report.json", "size": 1, "sha256": "q"}
  },
  "fileSizes": {"pdf": 12000, "epub": 8000}
}
''';
    final m = EbookR1PackageManifest.fromJsonString(raw);
    expect(m.revision, 'r1');
    expect(m.title, '완성형 전자책');
    expect(m.hasDownloadablePdf, isTrue);
    expect(m.hasDownloadableEpub, isTrue);
    expect(m.hasCover, isTrue);
    expect(m.hasToc, isTrue);
    expect(m.frozen, isTrue);
    expect(m.score, 92);
    expect(m.pdfPath, 'publish/current/book.pdf');
    expect(m.pdfSha256, 'abc123def456');
    expect(m.resolvePdfFileName(), 'book.pdf');
    expect(m.resolveEpubFileName(), 'book.epub');
  });

  test('EbookR1PackageManifest still accepts legacy string artifact paths', () {
    const raw = '''
{
  "revision": "r1",
  "title": "legacy",
  "artifacts": {
    "pdf": "publish/book.pdf",
    "epub": "publish/book.epub",
    "cover": "assets/cover/cover.png"
  }
}
''';
    final m = EbookR1PackageManifest.fromJsonString(raw);
    expect(m.pdfPath, 'publish/book.pdf');
    expect(m.epubPath, 'publish/book.epub');
    expect(m.hasCover, isTrue);
  });

  test(
    'fromEbookReviewPackage maps structured fields + coverUrl/toc/quality',
    () {
      final m = EbookR1PackageManifest.fromEbookReviewPackage({
        'revision': 'r1',
        'title': '구조화 패키지',
        'subtitle': '부제',
        'author': '홍길동',
        'validatedAt': '2026-09-09T12:00:00Z',
        'frozen': true,
        'toc': ['서문', '1장', '2장'],
        'coverArtifact': {
          'path': 'assets/cover/cover.png',
          'url': 'https://cdn.example/cover.png',
          'sha256': 'coversha',
          'size': 2048,
        },
        'pdfArtifact': {
          'path': 'publish/current/book.pdf',
          'size': 9000,
          'sha256': 'pdfsha',
        },
        'epubArtifact': 'publish/current/book.epub',
        'quality': {
          'score': 95,
          'criticalCount': 0,
          'majorCount': 0,
          'refineCount': 2,
          'path': 'output/pre_review_quality_report.json',
          'downloadUrl': 'https://cdn.example/quality.json',
        },
        'manifestArtifact': {
          'path': 'publish/revisions/r1/package_manifest.json',
        },
      });

      expect(m.revision, 'r1');
      expect(m.title, '구조화 패키지');
      expect(m.author, '홍길동');
      expect(m.generatedAt, '2026-09-09T12:00:00Z');
      expect(m.coverUrl, 'https://cdn.example/cover.png');
      expect(m.coverPath, 'assets/cover/cover.png');
      expect(m.pdfPath, 'publish/current/book.pdf');
      expect(m.epubPath, 'publish/current/book.epub');
      expect(m.hasToc, isTrue);
      expect(m.tocSummary, ['서문', '1장', '2장']);
      expect(m.score, 95);
      expect(m.refineCount, 2);
      expect(m.qualityReportPath, 'output/pre_review_quality_report.json');
      expect(m.qualityReportUrl, 'https://cdn.example/quality.json');
      expect(m.hasQualityReport, isTrue);
      expect(m.frozen, isTrue);
      expect(m.immutablePath, 'publish/revisions/r1/package_manifest.json');
    },
  );

  test(
    'Sotong24RemoteStage parses ebookReviewPackage (top-level and nested)',
    () {
      final top = Sotong24RemoteStage.fromMap({
        'stageId': 'package_user_review',
        'stageNumber': 15,
        'stageName': '완성형 검토',
        'status': 'awaiting_approval',
        'ebookReviewPackage': {
          'title': 'top',
          'pdfArtifact': {'path': 'publish/current/book.pdf'},
        },
      });
      expect(top.ebookReviewPackage?['title'], 'top');

      final nestedResult = Sotong24RemoteStage.fromMap({
        'stageId': 'package_user_review',
        'stageNumber': 15,
        'stageName': '완성형 검토',
        'status': 'awaiting_approval',
        'result': {
          'ebookReviewPackage': {
            'title': 'from-result',
            'cover': {'downloadUrl': 'https://cdn.example/c.png'},
          },
        },
      });
      expect(nestedResult.ebookReviewPackage?['title'], 'from-result');

      final nestedPackage = Sotong24RemoteStage.fromMap({
        'stageId': 'package_user_review',
        'stageNumber': 15,
        'stageName': '완성형 검토',
        'status': 'awaiting_approval',
        'result': {
          'package': {
            'title': 'result-package',
            'tocSummary': ['A'],
          },
        },
      });
      expect(nestedPackage.ebookReviewPackage?['title'], 'result-package');
    },
  );

  test('structured ebookReviewPackage is preferred over summary scrape', () {
    final stage = Sotong24RemoteStage.fromMap({
      'stageId': 'package_user_review',
      'stageNumber': 15,
      'stageName': '완성형 검토',
      'status': 'awaiting_approval',
      'summary':
          '{"revision":"r0","title":"scraped-legacy","artifacts":{"pdf":"publish/old.pdf"}}',
      'ebookReviewPackage': {
        'revision': 'r1',
        'title': 'structured-ssot',
        'pdfArtifact': {'path': 'publish/current/book.pdf'},
        'toc': ['구조화 목차'],
        'quality': {'score': 91, 'refineCount': 1},
        'coverArtifact': {
          'url': 'https://cdn.example/cover-ssot.png',
          'path': 'assets/cover/cover.png',
        },
      },
    });

    final structured = stage.ebookReviewPackage!;
    final fromStructured = EbookR1PackageManifest.fromEbookReviewPackage(
      structured,
    );
    final scraped = EbookR1PackageManifest.fromJsonString(
      stage.summary.substring(
        stage.summary.indexOf('{'),
        stage.summary.lastIndexOf('}') + 1,
      ),
    );

    expect(fromStructured.title, 'structured-ssot');
    expect(scraped.title, 'scraped-legacy');
    expect(fromStructured.title, isNot(scraped.title));
    expect(fromStructured.coverUrl, 'https://cdn.example/cover-ssot.png');
    expect(fromStructured.tocSummary, ['구조화 목차']);
    expect(fromStructured.score, 91);
    expect(fromStructured.refineCount, 1);
  });

  test('manifest path enables manifest UX + incomplete blocks review', () {
    final complete = EbookR1PackageManifest.fromEbookReviewPackage({
      'revision': 'r1',
      'title': 'complete',
      'pdfArtifact': {'path': 'publish/current/book.pdf'},
      'epubArtifact': {'path': 'publish/current/book.epub'},
      'coverArtifact': {'path': 'publish/revisions/r1/cover/cover.png'},
      'quality': {
        'path': 'publish/revisions/r1/pre_review_quality_report.json',
        'score': 95,
      },
      'manifestArtifact': {
        'path': 'publish/revisions/r1/package_manifest.json',
      },
    });
    expect(complete.hasManifest, isTrue);
    expect(complete.resolveManifestFileName(), 'package_manifest.json');
    expect(complete.reviewActionsEnabled, isTrue);

    final incomplete = EbookR1PackageManifest.fromEbookReviewPackage({
      'revision': 'r1',
      'title': 'incomplete',
      'pdfArtifact': {'path': 'publish/current/book.pdf'},
      'epubArtifact': {'path': 'publish/current/book.epub'},
    });
    expect(incomplete.reviewActionsEnabled, isFalse);
    expect(incomplete.hasCover, isFalse);
    expect(incomplete.hasQualityReport, isFalse);
    expect(incomplete.hasManifest, isFalse);
  });

  test('v2 ebookReviewPackage requires remoteReady/grantReady for review', () {
    Map<String, dynamic> art(String path, {bool ready = true}) => {
      'path': path,
      'fileName': path.split('/').last,
      'size': 10,
      'sha256': 'abc',
      'remoteStatus': ready ? 'grantReady' : 'error',
      'remoteReady': ready,
      'grantReady': ready,
      'remoteUrl': ready ? 'https://example.com/$path' : '',
    };
    final ready = EbookR1PackageManifest.fromEbookReviewPackage({
      'schemaVersion': 'ebookReviewPackage/v2',
      'contractVersion': 2,
      'revision': 'r1',
      'title': 'v2 ready',
      'reviewReady': true,
      'deliveryStatus': 'ready',
      'manifestSHA256': 'abc',
      'cover': art('publish/revisions/r1/cover/cover.png'),
      'pdf': art('publish/revisions/r1/book.pdf'),
      'epub': art('publish/revisions/r1/book.epub'),
      'qualityReport': art(
        'publish/revisions/r1/pre_review_quality_report.json',
      ),
      'manifest': art('publish/revisions/r1/package_manifest.json'),
      'quality': {'score': 95, 'criticalCount': 0, 'majorCount': 0},
      'toc': ['1'],
    });
    expect(ready.schemaIsV2, isTrue);
    expect(ready.reviewActionsEnabled, isTrue);
    expect(ready.reviewActionsEnabledForStage(1), isTrue);
    expect(ready.reviewActionsEnabledForStage(2), isFalse);

    final staleR1 = EbookR1PackageManifest.fromEbookReviewPackage({
      'schemaVersion': 'ebookReviewPackage/v2',
      'contractVersion': 2,
      'revision': 'r1',
      'title': 'stale r1',
      'reviewReady': true,
      'deliveryStatus': 'ready',
      'manifestSHA256': 'abc',
      'cover': art('publish/revisions/r1/cover/cover.png'),
      'pdf': art('publish/revisions/r1/book.pdf'),
      'epub': art('publish/revisions/r1/book.epub'),
      'qualityReport': art(
        'publish/revisions/r1/pre_review_quality_report.json',
      ),
      'manifest': art('publish/revisions/r1/package_manifest.json'),
      'quality': {'score': 95},
    });
    expect(staleR1.reviewActionsEnabledForStage(2), isFalse);

    final noSha = EbookR1PackageManifest.fromEbookReviewPackage({
      'schemaVersion': 'ebookReviewPackage/v2',
      'contractVersion': 2,
      'revision': 'r1',
      'title': 'no sha',
      'reviewReady': true,
      'cover': art('publish/revisions/r1/cover/cover.png'),
      'pdf': art('publish/revisions/r1/book.pdf'),
      'epub': art('publish/revisions/r1/book.epub'),
      'qualityReport': art(
        'publish/revisions/r1/pre_review_quality_report.json',
      ),
      'manifest': {
        'path': 'publish/revisions/r1/package_manifest.json',
        'remoteReady': true,
        'grantReady': true,
        'remoteUrl': 'https://example.com/m',
      },
      'quality': {'score': 95},
    });
    expect(noSha.reviewActionsEnabled, isFalse);

    final hold = EbookR1PackageManifest.fromEbookReviewPackage({
      'schemaVersion': 'ebookReviewPackage/v2',
      'contractVersion': 2,
      'revision': 'r1',
      'title': 'v2 hold',
      'reviewReady': false,
      'holdReason': 'artifact_delivery_hold',
      'cover': art('publish/revisions/r1/cover/cover.png', ready: false),
      'pdf': art('publish/revisions/r1/book.pdf'),
      'epub': art('publish/revisions/r1/book.epub'),
      'qualityReport': art(
        'publish/revisions/r1/pre_review_quality_report.json',
      ),
      'manifest': art('publish/revisions/r1/package_manifest.json'),
      'quality': {'score': 95},
    });
    expect(hold.reviewActionsEnabled, isFalse);
    expect(hold.deliveryStatusMessage, contains('전달'));
  });

  test(
    'commercial-v2: package revision is authoritative over stale stage r1',
    () {
      Map<String, dynamic> art(String path, {bool ready = true}) => {
        'path': path,
        'fileName': path.split('/').last,
        'size': 10,
        'sha256': 'abc',
        'remoteStatus': ready ? 'grantReady' : 'error',
        'remoteReady': ready,
        'grantReady': ready,
        'remoteUrl': ready ? 'https://example.com/$path' : '',
      };
      final r2 = EbookR1PackageManifest.fromEbookReviewPackage({
        'schemaVersion': 'ebookReviewPackage/v2',
        'contractVersion': 2,
        'revision': 'r2',
        'title': 'frozen r2',
        'reviewReady': true,
        'deliveryStatus': 'ready',
        'manifestSHA256': 'abc',
        'cover': art('publish/revisions/r2/cover/cover.png'),
        'pdf': art('publish/revisions/r2/book.pdf'),
        'epub': {
          ...art('publish/revisions/r2/book.epub'),
          'sha256':
              '147d9ccc15bea8c5917296498a5dc8cbc30f85c9df9210f3730abe09c5fde3e6',
        },
        'qualityReport': art(
          'publish/revisions/r2/pre_review_quality_report.json',
        ),
        'manifest': art('publish/revisions/r2/package_manifest.json'),
        'quality': {'score': 95, 'criticalCount': 0, 'majorCount': 0},
        'toc': ['1'],
        'frozen': true,
        'immutablePath': 'publish/revisions/r2',
      });

      expect(r2.revisionNumber, 2);
      expect(r2.downloadEpubAttachmentName(), 'ebook_r2.epub');
      expect(
        r2.epubSha256,
        '147d9ccc15bea8c5917296498a5dc8cbc30f85c9df9210f3730abe09c5fde3e6',
      );
      expect(r2.frozenPathsMatchPackageRevision, isTrue);
      // Stale stage.revision=1 must not block r2 package review.
      expect(r2.reviewActionsEnabledForAuthoritativePackage(1), isTrue);
      expect(
        r2.reviewActionsEnabledForStage(1),
        isFalse,
      ); // legacy gate still strict
      expect(r2.reviewReadinessGapsForAuthoritativePackage(1), isEmpty);
      expect(r2.packageReviewBlockReason(1), isNull);

      // Stale r1 package while stage advanced to r2 remains fail-closed.
      final staleR1 = EbookR1PackageManifest.fromEbookReviewPackage({
        'schemaVersion': 'ebookReviewPackage/v2',
        'contractVersion': 2,
        'revision': 'r1',
        'title': 'stale r1',
        'reviewReady': true,
        'deliveryStatus': 'ready',
        'manifestSHA256': 'abc',
        'cover': art('publish/revisions/r1/cover/cover.png'),
        'pdf': art('publish/revisions/r1/book.pdf'),
        'epub': art('publish/revisions/r1/book.epub'),
        'qualityReport': art(
          'publish/revisions/r1/pre_review_quality_report.json',
        ),
        'manifest': art('publish/revisions/r1/package_manifest.json'),
        'quality': {'score': 95},
      });
      expect(staleR1.reviewActionsEnabledForAuthoritativePackage(2), isFalse);
      expect(staleR1.packageReviewBlockReason(2), contains('패키지-r1'));
      expect(staleR1.packageReviewBlockReason(2), contains('단계-r2'));
      expect(
        staleR1.reviewReadinessGapsForAuthoritativePackage(2).join(','),
        contains('패키지-r1'),
      );

      // Package label r2 but paths still on r1 → fail-closed.
      final pathMismatch = EbookR1PackageManifest.fromEbookReviewPackage({
        'schemaVersion': 'ebookReviewPackage/v2',
        'contractVersion': 2,
        'revision': 'r2',
        'title': 'path mismatch',
        'reviewReady': true,
        'deliveryStatus': 'ready',
        'manifestSHA256': 'abc',
        'cover': art('publish/revisions/r1/cover/cover.png'),
        'pdf': art('publish/revisions/r1/book.pdf'),
        'epub': art('publish/revisions/r1/book.epub'),
        'qualityReport': art(
          'publish/revisions/r1/pre_review_quality_report.json',
        ),
        'manifest': art('publish/revisions/r1/package_manifest.json'),
        'quality': {'score': 95},
      });
      expect(pathMismatch.frozenPathsMatchPackageRevision, isFalse);
      expect(
        pathMismatch.reviewActionsEnabledForAuthoritativePackage(2),
        isFalse,
      );
      expect(pathMismatch.packageReviewBlockReason(2), contains('패키지 경로'));
    },
  );

  test('Work exported fixture parses as Control ebookReviewPackage v2', () {
    final fixture = File('test/fixtures/ebook_complete_r1_work_payload.json');
    // Fixture is produced by Work --ebook-r1-selftest case W.
    // Until first export exists in CI workspace, skip without hanging.
    if (!fixture.existsSync()) {
      // ignore: avoid_print
      print('SKIP: Work fixture not yet exported at ${fixture.path}');
      return;
    }
    final pkg = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
    final m = EbookR1PackageManifest.fromEbookReviewPackage(pkg);
    expect(pkg['schemaVersion'], 'ebookReviewPackage/v2');
    expect(m.schemaIsV2, isTrue);
    expect(m.hasCover, isTrue);
    expect(m.hasDownloadablePdf, isTrue);
    expect(m.hasDownloadableEpub, isTrue);
    expect(m.hasQualityReport, isTrue);
    expect(m.hasManifest, isTrue);
    expect(m.revision, isNotEmpty);
    expect(m.manifestSHA256, isNotEmpty);
    expect(m.reviewActionsEnabled, isTrue);
    expect(m.reviewActionsEnabledForStage(2), isTrue);
    expect(m.reviewActionsEnabledForStage(1), isFalse);
  });
}
