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
    this.author = '',
    this.language = 'ko',
    this.pdfBytes = 0,
    this.epubBytes = 0,
    this.score,
    this.criticalCount,
    this.majorCount,
    this.refineCount,
    this.generatedAt = '',
    this.frozen = false,
    this.pdfSha256 = '',
    this.epubSha256 = '',
    this.tocSummary = const [],
    this.immutablePath = '',
    this.coverUrl = '',
    this.qualityReportUrl = '',
    this.manifestPath = '',
    this.schemaIsV2 = false,
    this.remoteReady = false,
    this.grantReady = false,
    this.reviewReadyFlag = false,
    this.holdReason = '',
    this.deliveryStatusMessage = '',
  });

  final String revision;
  final String title;
  final String subtitle;
  final String author;
  final String language;
  final String pdfPath;
  final String epubPath;
  final String coverPath;
  final String coverUrl;
  final String qualityReportPath;
  final String qualityReportUrl;
  final String manifestPath;
  final int pdfBytes;
  final int epubBytes;
  final int? score;
  final int? criticalCount;
  final int? majorCount;
  final int? refineCount;
  final String generatedAt;
  final bool frozen;
  final String pdfSha256;
  final String epubSha256;
  final List<String> tocSummary;
  final String immutablePath;
  final bool schemaIsV2;
  final bool remoteReady;
  final bool grantReady;
  final bool reviewReadyFlag;
  final String holdReason;
  final String deliveryStatusMessage;

  bool get hasDownloadablePdf => pdfPath.isNotEmpty;
  bool get hasDownloadableEpub => epubPath.isNotEmpty;
  bool get hasCover => coverPath.isNotEmpty || coverUrl.isNotEmpty;
  bool get hasToc => tocSummary.isNotEmpty;
  bool get hasQualityReport =>
      qualityReportPath.isNotEmpty || qualityReportUrl.isNotEmpty;
  bool get hasManifest =>
      manifestPath.isNotEmpty || immutablePath.contains('package_manifest');

  bool get artifactsStructurallyPresent =>
      hasDownloadablePdf &&
      hasDownloadableEpub &&
      hasCover &&
      hasQualityReport &&
      hasManifest;

  bool get reviewActionsEnabled {
    if (!artifactsStructurallyPresent) return false;
    if (holdReason.isNotEmpty && !reviewReadyFlag) return false;
    if (schemaIsV2) {
      return reviewReadyFlag && remoteReady && grantReady;
    }
    return true;
  }

  static String _artifactPath(dynamic raw, String fallback) {
    if (raw == null) return fallback;
    if (raw is String) {
      final s = raw.trim();
      return s.isNotEmpty ? s : fallback;
    }
    if (raw is Map) {
      final path = '${raw['path'] ?? ''}'.trim();
      return path.isNotEmpty ? path : fallback;
    }
    return fallback;
  }

  static String _artifactUrl(dynamic raw) {
    if (raw is Map) {
      final url =
          '${raw['url'] ?? raw['downloadUrl'] ?? raw['remoteUrl'] ?? ''}'
              .trim();
      return url;
    }
    if (raw is String) {
      final s = raw.trim();
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
    }
    return '';
  }

  static int _artifactSize(dynamic raw, int fallback) {
    if (raw is Map && raw['size'] is num) return (raw['size'] as num).toInt();
    return fallback;
  }

  static String _artifactSha(dynamic raw) {
    if (raw is Map) return '${raw['sha256'] ?? ''}'.trim();
    return '';
  }

  static bool _artifactReadyFlag(dynamic raw, String key) {
    if (raw is Map) return raw[key] == true;
    return false;
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  static List<String> _parseToc(dynamic tocRaw) {
    final toc = <String>[];
    if (tocRaw is List) {
      for (final e in tocRaw) {
        if (e is Map) {
          final title = '${e['title'] ?? e['label'] ?? e['text'] ?? ''}'.trim();
          if (title.isNotEmpty) toc.add(title);
          continue;
        }
        final s = '$e'.trim();
        if (s.isNotEmpty) toc.add(s);
      }
    } else if (tocRaw is String && tocRaw.trim().isNotEmpty) {
      for (final line in tocRaw.split(RegExp(r'[\n|;]'))) {
        final s = line.trim();
        if (s.isNotEmpty) toc.add(s);
      }
    }
    return toc;
  }

  factory EbookR1PackageManifest.fromJson(Map<String, dynamic> json) {
    final artifacts = (json['artifacts'] is Map)
        ? Map<String, dynamic>.from(json['artifacts'] as Map)
        : <String, dynamic>{};
    final sizes = (json['fileSizes'] is Map)
        ? Map<String, dynamic>.from(json['fileSizes'] as Map)
        : <String, dynamic>{};
    final toc = _parseToc(json['tocSummary'] ?? json['toc']);
    final pdfRaw = artifacts['pdf'] ?? json['pdf'];
    final epubRaw = artifacts['epub'] ?? json['epub'];
    final coverRaw = artifacts['cover'] ?? json['cover'];
    final qualityRaw = artifacts['qualityReport'] ?? json['qualityReport'];
    final manifestRaw = artifacts['manifest'] ?? json['manifest'];
    final pdfFallback = 'publish/current/book.pdf';
    final epubFallback = 'publish/current/book.epub';
    final schema = '${json['schemaVersion'] ?? ''}';
    final isV2 =
        schema.contains('ebookReviewPackage/v2') ||
        json['contractVersion'] == 2;
    return EbookR1PackageManifest(
      revision: '${json['revision'] ?? 'r1'}',
      title: '${json['title'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      author: '${json['author'] ?? ''}',
      language: '${json['language'] ?? 'ko'}',
      pdfPath: _artifactPath(pdfRaw, pdfFallback),
      epubPath: _artifactPath(epubRaw, epubFallback),
      coverPath: _artifactPath(coverRaw, ''),
      coverUrl: _artifactUrl(coverRaw),
      qualityReportPath: _artifactPath(qualityRaw, ''),
      qualityReportUrl: _artifactUrl(qualityRaw),
      manifestPath: _artifactPath(
        manifestRaw,
        '${json['immutablePath'] ?? ''}'.contains('package_manifest')
            ? '${json['immutablePath']}'
            : '',
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
      score:
          _asInt(json['qualityScore']) ??
          _asInt((json['quality'] is Map) ? json['quality']['score'] : null),
      criticalCount:
          _asInt(json['criticalCount']) ??
          _asInt(
            (json['quality'] is Map) ? json['quality']['criticalCount'] : null,
          ),
      majorCount:
          _asInt(json['majorCount']) ??
          _asInt(
            (json['quality'] is Map) ? json['quality']['majorCount'] : null,
          ),
      refineCount:
          _asInt(json['refineCount']) ??
          _asInt(
            (json['quality'] is Map) ? json['quality']['refineCount'] : null,
          ),
      generatedAt: '${json['generatedAt'] ?? json['validatedAt'] ?? ''}',
      frozen: json['frozen'] == true || json['promoteToUserR1'] == true,
      pdfSha256: _artifactSha(pdfRaw),
      epubSha256: _artifactSha(epubRaw),
      tocSummary: toc,
      immutablePath: '${json['immutablePath'] ?? ''}',
      schemaIsV2: isV2,
      remoteReady:
          _artifactReadyFlag(pdfRaw, 'remoteReady') &&
          _artifactReadyFlag(epubRaw, 'remoteReady') &&
          _artifactReadyFlag(coverRaw, 'remoteReady') &&
          _artifactReadyFlag(qualityRaw, 'remoteReady') &&
          _artifactReadyFlag(manifestRaw, 'remoteReady'),
      grantReady:
          _artifactReadyFlag(pdfRaw, 'grantReady') &&
          _artifactReadyFlag(epubRaw, 'grantReady') &&
          _artifactReadyFlag(coverRaw, 'grantReady') &&
          _artifactReadyFlag(qualityRaw, 'grantReady') &&
          _artifactReadyFlag(manifestRaw, 'grantReady'),
      reviewReadyFlag: json['reviewReady'] == true,
      holdReason: '${json['holdReason'] ?? ''}',
      deliveryStatusMessage: json['reviewReady'] == true
          ? ''
          : ((json['holdReason'] ?? '').toString().isNotEmpty
                ? '결과물 전달 준비 실패/재시도 필요'
                : '결과물 전달 준비 중'),
    );
  }

  /// Structured `ebookReviewPackage` SSOT from remote stage (not summary scrape).
  factory EbookR1PackageManifest.fromEbookReviewPackage(
    Map<String, dynamic> pkg,
  ) {
    final schema = '${pkg['schemaVersion'] ?? ''}';
    final isV2 =
        schema.contains('ebookReviewPackage/v2') || pkg['contractVersion'] == 2;

    // v2: top-level cover/pdf/epub/qualityReport/manifest. Legacy: *Artifact / nested quality.path.
    final coverRaw = isV2
        ? (pkg['cover'] ?? pkg['coverArtifact'])
        : (pkg['coverArtifact'] ?? pkg['cover']);
    final pdfRaw = isV2
        ? (pkg['pdf'] ?? pkg['pdfArtifact'])
        : (pkg['pdfArtifact'] ?? pkg['pdf']);
    final epubRaw = isV2
        ? (pkg['epub'] ?? pkg['epubArtifact'])
        : (pkg['epubArtifact'] ?? pkg['epub']);
    final manifestRaw = isV2
        ? (pkg['manifest'] ?? pkg['manifestArtifact'])
        : (pkg['manifestArtifact'] ?? pkg['manifest']);
    final qualityRaw = pkg['quality'];

    int? score = _asInt(pkg['qualityScore']);
    int? critical = _asInt(pkg['criticalCount']);
    int? major = _asInt(pkg['majorCount']);
    int? refine = _asInt(pkg['refineCount']);
    dynamic qualityReportRaw =
        pkg['qualityReport'] ?? pkg['qualityReportArtifact'];

    if (qualityRaw is Map) {
      final q = Map<String, dynamic>.from(qualityRaw);
      score ??= _asInt(q['score'] ?? q['qualityScore']);
      critical ??= _asInt(q['criticalCount'] ?? q['critical']);
      major ??= _asInt(q['majorCount'] ?? q['major']);
      refine ??= _asInt(q['refineCount'] ?? q['refines']);
      if (!isV2) {
        qualityReportRaw ??=
            q['report'] ??
            q['artifact'] ??
            q['qualityReport'] ??
            ((q.containsKey('path') ||
                    q.containsKey('url') ||
                    q.containsKey('downloadUrl'))
                ? q
                : null);
      }
    } else if (qualityRaw is num) {
      score ??= qualityRaw.toInt();
    } else if (!isV2 && qualityRaw is String && qualityRaw.trim().isNotEmpty) {
      qualityReportRaw ??= qualityRaw;
    }

    final toc = _parseToc(pkg['toc'] ?? pkg['tocSummary']);
    final immutable = _artifactPath(
      manifestRaw,
      '${pkg['immutablePath'] ?? ''}'.trim(),
    );

    final remoteReady =
        _artifactReadyFlag(coverRaw, 'remoteReady') &&
        _artifactReadyFlag(pdfRaw, 'remoteReady') &&
        _artifactReadyFlag(epubRaw, 'remoteReady') &&
        _artifactReadyFlag(qualityReportRaw, 'remoteReady') &&
        _artifactReadyFlag(manifestRaw, 'remoteReady');
    final grantReady =
        _artifactReadyFlag(coverRaw, 'grantReady') &&
        _artifactReadyFlag(pdfRaw, 'grantReady') &&
        _artifactReadyFlag(epubRaw, 'grantReady') &&
        _artifactReadyFlag(qualityReportRaw, 'grantReady') &&
        _artifactReadyFlag(manifestRaw, 'grantReady');
    final reviewReady = pkg['reviewReady'] == true;
    final hold = '${pkg['holdReason'] ?? ''}'.trim();

    return EbookR1PackageManifest(
      revision: '${pkg['revision'] ?? 'r1'}',
      title: '${pkg['title'] ?? ''}',
      subtitle: '${pkg['subtitle'] ?? ''}',
      author: '${pkg['author'] ?? ''}',
      language: '${pkg['language'] ?? 'ko'}',
      pdfPath: _artifactPath(pdfRaw, ''),
      epubPath: _artifactPath(epubRaw, ''),
      coverPath: _artifactPath(coverRaw, ''),
      coverUrl: _artifactUrl(coverRaw),
      qualityReportPath: _artifactPath(qualityReportRaw, ''),
      qualityReportUrl: _artifactUrl(qualityReportRaw),
      manifestPath: _artifactPath(manifestRaw, ''),
      pdfBytes: _artifactSize(pdfRaw, 0),
      epubBytes: _artifactSize(epubRaw, 0),
      score: score,
      criticalCount: critical,
      majorCount: major,
      refineCount: refine,
      generatedAt: '${pkg['validatedAt'] ?? pkg['generatedAt'] ?? ''}',
      frozen: pkg['frozen'] == true || pkg['promoteToUserR1'] == true,
      pdfSha256: _artifactSha(pdfRaw),
      epubSha256: _artifactSha(epubRaw),
      tocSummary: toc,
      immutablePath: immutable,
      schemaIsV2: isV2,
      remoteReady: isV2 ? remoteReady : true,
      grantReady: isV2 ? grantReady : true,
      reviewReadyFlag: isV2 ? reviewReady : true,
      holdReason: hold,
      deliveryStatusMessage: (!isV2 || reviewReady)
          ? ''
          : (hold.isNotEmpty ? '결과물 전달 준비 실패/재시도 필요' : '결과물 전달 준비 중'),
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

  String resolveQualityReportFileName() {
    if (qualityReportPath.isEmpty) return 'pre_review_quality_report.json';
    final parts = qualityReportPath.split('/');
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isNotEmpty ? name : 'pre_review_quality_report.json';
  }

  String resolveManifestFileName() {
    if (manifestPath.isEmpty) return 'package_manifest.json';
    final parts = manifestPath.split(RegExp(r'[/\\]'));
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isNotEmpty ? name : 'package_manifest.json';
  }
}
