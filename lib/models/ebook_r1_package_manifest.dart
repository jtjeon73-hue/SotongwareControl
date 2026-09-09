import 'dart:convert';

/// Parses publish package_manifest.json (current / alias / revisions/rN) for Control UI.
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
    this.frozen = false,
    this.pdfSha256 = '',
    this.epubSha256 = '',
    this.tocSummary = const [],
    this.immutablePath = '',
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
  final bool frozen;
  final String pdfSha256;
  final String epubSha256;
  final List<String> tocSummary;
  final String immutablePath;

  bool get hasDownloadablePdf => pdfPath.isNotEmpty;
  bool get hasDownloadableEpub => epubPath.isNotEmpty;
  bool get hasCover => coverPath.isNotEmpty;
  bool get hasToc => tocSummary.isNotEmpty;

  static String _artifactPath(dynamic raw, String fallback) {
    if (raw == null) return fallback;
    if (raw is String) return raw;
    if (raw is Map) {
      final path = '${raw['path'] ?? ''}'.trim();
      return path.isNotEmpty ? path : fallback;
    }
    return fallback;
  }

  static int _artifactSize(dynamic raw, int fallback) {
    if (raw is Map && raw['size'] is num) return (raw['size'] as num).toInt();
    return fallback;
  }

  static String _artifactSha(dynamic raw) {
    if (raw is Map) return '${raw['sha256'] ?? ''}'.trim();
    return '';
  }

  factory EbookR1PackageManifest.fromJson(Map<String, dynamic> json) {
    final artifacts = (json['artifacts'] is Map)
        ? Map<String, dynamic>.from(json['artifacts'] as Map)
        : <String, dynamic>{};
    final sizes = (json['fileSizes'] is Map)
        ? Map<String, dynamic>.from(json['fileSizes'] as Map)
        : <String, dynamic>{};
    final tocRaw = json['tocSummary'];
    final toc = <String>[];
    if (tocRaw is List) {
      for (final e in tocRaw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) toc.add(s);
      }
    }
    final pdfRaw = artifacts['pdf'];
    final epubRaw = artifacts['epub'];
    final coverRaw = artifacts['cover'];
    final qualityRaw = artifacts['qualityReport'];
    final pdfFallback = 'publish/current/book.pdf';
    final epubFallback = 'publish/current/book.epub';
    return EbookR1PackageManifest(
      revision: '${json['revision'] ?? 'r1'}',
      title: '${json['title'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      language: '${json['language'] ?? 'ko'}',
      pdfPath: _artifactPath(pdfRaw, pdfFallback),
      epubPath: _artifactPath(epubRaw, epubFallback),
      coverPath: _artifactPath(coverRaw, ''),
      qualityReportPath: _artifactPath(
        qualityRaw,
        'output/pre_review_quality_report.json',
      ),
      pdfBytes: _artifactSize(
        pdfRaw,
        (sizes['pdf'] is num)
            ? (sizes['pdf'] as num).toInt()
            : int.tryParse('${sizes['pdf'] ?? ''}') ?? 0,
      ),
      epubBytes: _artifactSize(
        epubRaw,
        (sizes['epub'] is num)
            ? (sizes['epub'] as num).toInt()
            : int.tryParse('${sizes['epub'] ?? ''}') ?? 0,
      ),
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
      frozen: json['frozen'] == true || json['promoteToUserR1'] == true,
      pdfSha256: _artifactSha(pdfRaw),
      epubSha256: _artifactSha(epubRaw),
      tocSummary: toc,
      immutablePath: '${json['immutablePath'] ?? ''}',
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

  String resolveEpubFileName() {
    if (epubPath.endsWith('book.epub')) return 'book.epub';
    return epubPath.split('/').isNotEmpty
        ? epubPath.split('/').last
        : 'book.epub';
  }
}
