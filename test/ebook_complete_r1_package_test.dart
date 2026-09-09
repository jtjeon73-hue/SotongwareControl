import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/ebook_r1_package_manifest.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';

void main() {
  test('ebook complete-r1 WI stages include package_user_review at 15', () {
    final steps = BusinessPlanningService.ebookWorkflowStages;
    expect(steps.length, 18);
    expect(steps[8].$1, 'user_review'); // demoted checkpoint
    expect(steps[14].$1, 'package_user_review');
    expect(steps[14].$2, contains('r1'));
    expect(steps.any((e) => e.$1 == 'sales_metadata'), isFalse);
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
}
