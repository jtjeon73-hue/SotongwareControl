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

  test('EbookR1PackageManifest parses SSOT paths', () {
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
  "artifacts": {
    "pdf": "publish/book.pdf",
    "epub": "publish/book.epub",
    "cover": "assets/cover/cover.png",
    "qualityReport": "output/pre_review_quality_report.json"
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
    expect(m.score, 92);
    expect(m.resolvePdfFileName(), 'book.pdf');
  });
}
