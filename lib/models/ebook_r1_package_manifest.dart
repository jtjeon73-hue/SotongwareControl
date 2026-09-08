import 'dart:convert';

/// Parses publish/r1_package_manifest.json for Control ebook complete-r1 UI.
class EbookR1PackageManifest {
  EbookR1PackageManifest({
    required this.revision,
    required this.title,
    required this.pdfPath,
    required this.epubPath,
    required this.coverPath,
    required this.qualityReportPath,
    this.subtitle = '',
    this.language = 'ko',
    this.pdfBytes = 0,
    this.epubBytes = 0,
    this.score,
    this.criticalCount,
    this.majorCount,
    this.generatedAt = '',
  });

  final String revision;
  final String title;
  final String subtitle;
  final String language;
  final String pdfPath;
  final String epubPath;
  final String coverPath;
  final String qualityReportPath;
  final int pdfBytes;
  final int epubBytes;
  final int? score;
  final int? criticalCount;
  final int? majorCount;
  final String generatedAt;

  bool get hasDownloadablePdf => pdfPath.isNotEmpty;
  bool get hasDownloadableEpub => epubPath.isNotEmpty;
  bool get hasCover => coverPath.isNotEmpty;

  factory EbookR1PackageManifest.fromJson(Map<String, dynamic> json) {
    final artifacts = (json['artifacts'] is Map)
        ? Map<String, dynamic>.from(json['artifacts'] as Map)
        : <String, dynamic>{};
    final sizes = (json['fileSizes'] is Map)
        ? Map<String, dynamic>.from(json['fileSizes'] as Map)
        : <String, dynamic>{};
    return EbookR1PackageManifest(
      revision: '${json['revision'] ?? 'r1'}',
      title: '${json['title'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      language: '${json['language'] ?? 'ko'}',
      pdfPath: '${artifacts['pdf'] ?? 'publish/book.pdf'}',
      epubPath: '${artifacts['epub'] ?? 'publish/book.epub'}',
      coverPath: '${artifacts['cover'] ?? ''}',
      qualityReportPath:
          '${artifacts['qualityReport'] ?? 'output/pre_review_quality_report.json'}',
      pdfBytes: (sizes['pdf'] is num)
          ? (sizes['pdf'] as num).toInt()
          : int.tryParse('${sizes['pdf'] ?? ''}') ?? 0,
      epubBytes: (sizes['epub'] is num)
          ? (sizes['epub'] as num).toInt()
          : int.tryParse('${sizes['epub'] ?? ''}') ?? 0,
      score: json['qualityScore'] is num
          ? (json['qualityScore'] as num).toInt()
          : int.tryParse('${json['qualityScore'] ?? ''}'),
      criticalCount: json['criticalCount'] is num
          ? (json['criticalCount'] as num).toInt()
          : int.tryParse('${json['criticalCount'] ?? ''}'),
      majorCount: json['majorCount'] is num
          ? (json['majorCount'] as num).toInt()
          : int.tryParse('${json['majorCount'] ?? ''}'),
      generatedAt: '${json['generatedAt'] ?? ''}',
    );
  }

  factory EbookR1PackageManifest.fromJsonString(String raw) {
    return EbookR1PackageManifest.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  /// Prefer SSOT publish paths; fall back to legacy final_ebook.pdf only if empty.
  String resolvePdfFileName() {
    if (pdfPath.endsWith('book.pdf')) return 'book.pdf';
    if (pdfPath.endsWith('final_ebook.pdf')) return 'final_ebook.pdf';
    return pdfPath.split('/').isNotEmpty ? pdfPath.split('/').last : 'book.pdf';
  }
}
