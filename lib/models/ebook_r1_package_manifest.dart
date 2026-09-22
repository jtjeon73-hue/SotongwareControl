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
    this.manifestSHA256 = '',
    this.deliveryStatus = '',
    this.pdfRemoteUrl = '',
    this.epubRemoteUrl = '',
    this.manifestRemoteUrl = '',
    this.coverGrantReady = false,
    this.pdfGrantReady = false,
    this.epubGrantReady = false,
    this.qualityGrantReady = false,
    this.manifestGrantReady = false,
    this.coverRemoteReady = false,
    this.pdfRemoteReady = false,
    this.epubRemoteReady = false,
    this.qualityRemoteReady = false,
    this.manifestRemoteReady = false,
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
  final String manifestSHA256;
  final String deliveryStatus;
  final String pdfRemoteUrl;
  final String epubRemoteUrl;
  final String manifestRemoteUrl;
  final bool coverGrantReady;
  final bool pdfGrantReady;
  final bool epubGrantReady;
  final bool qualityGrantReady;
  final bool manifestGrantReady;
  final bool coverRemoteReady;
  final bool pdfRemoteReady;
  final bool epubRemoteReady;
  final bool qualityRemoteReady;
  final bool manifestRemoteReady;

  bool get hasDownloadablePdf => pdfPath.isNotEmpty || pdfRemoteUrl.isNotEmpty;
  bool get hasDownloadableEpub =>
      epubPath.isNotEmpty || epubRemoteUrl.isNotEmpty;
  bool get hasCover => coverPath.isNotEmpty || coverUrl.isNotEmpty;
  bool get hasToc => tocSummary.isNotEmpty;
  bool get hasQualityReport =>
      qualityReportPath.isNotEmpty || qualityReportUrl.isNotEmpty;
  bool get hasManifest =>
      manifestPath.isNotEmpty ||
      immutablePath.contains('package_manifest') ||
      manifestRemoteUrl.isNotEmpty;

  bool get artifactsStructurallyPresent =>
      hasDownloadablePdf &&
      hasDownloadableEpub &&
      hasCover &&
      hasQualityReport &&
      hasManifest;

  /// 자동 검사 결과 라벨. 판매 품질 보증이 아님.
  String get autoCheckLabel {
    final c = criticalCount ?? 0;
    final m = majorCount ?? 0;
    final s = score;
    if (s != null && s >= 90 && c == 0 && m == 0) {
      return '자동 검사 PASS (판매 보증 아님)';
    }
    return '자동 검사 CHECK (확인 필요)';
  }

  /// 사용자 검토 게이트 상태 (승인 버튼과 별개로 표시).
  String get userReviewGateLabel {
    if (reviewActionsEnabled) return '사용자 검토 준비 완료';
    if (holdReason.isNotEmpty && !reviewReadyFlag) {
      return '결과물 전달 보류 · 승인 불가';
    }
    if (!artifactsStructurallyPresent) return '결과물 등록 부족 · 승인 불가';
    if (schemaIsV2 && !reviewReadyFlag) return '전달 준비 중 · 승인 불가';
    return '검토 준비 미완 · 승인 불가';
  }

  /// 승인 비활성 사유를 항목별로 나열 (추측·단일 플래그 의존 금지).
  List<String> get reviewReadinessGaps {
    final gaps = <String>[];
    if (!hasCover) gaps.add('표지 파일 없음');
    if (!hasDownloadablePdf) gaps.add('PDF 파일 없음');
    if (!hasDownloadableEpub) gaps.add('EPUB 파일 없음');
    if (!hasQualityReport) gaps.add('품질 보고서 없음');
    if (!hasManifest) gaps.add('manifest 없음');
    if (!schemaIsV2) return gaps;
    if (!reviewReadyFlag) gaps.add('reviewReady=false');
    if (holdReason.isNotEmpty && !reviewReadyFlag) {
      gaps.add('holdReason=$holdReason');
    }
    if (manifestSHA256.trim().isEmpty) gaps.add('manifestSHA256 없음');
    if (deliveryStatus.isNotEmpty && deliveryStatus != 'ready') {
      gaps.add('deliveryStatus=$deliveryStatus');
    }
    void flagGap(String label, bool remote, bool grant) {
      if (!remote) gaps.add('$label remoteReady=false');
      if (!grant) gaps.add('$label grantReady=false');
    }

    flagGap('표지', coverRemoteReady, coverGrantReady);
    flagGap('PDF', pdfRemoteReady, pdfGrantReady);
    flagGap('EPUB', epubRemoteReady, epubGrantReady);
    flagGap('품질보고서', qualityRemoteReady, qualityGrantReady);
    flagGap('manifest', manifestRemoteReady, manifestGrantReady);
    return gaps;
  }

  List<String> reviewReadinessGapsForStage(int stageRevision) {
    final gaps = List<String>.from(reviewReadinessGaps);
    if (!matchesStageRevision(stageRevision)) {
      final expect = normalizeRevisionLabel(
        'r${stageRevision > 0 ? stageRevision : 1}',
      );
      gaps.add('revision 불일치(패키지=$revision, 단계=$expect)');
    }
    return gaps;
  }

  static String normalizeRevisionLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    if (s.startsWith('r') && s.length > 1) return s;
    final n = int.tryParse(s);
    if (n != null && n > 0) return 'r$n';
    return s;
  }

  bool matchesStageRevision(int stageRevision) {
    final expect = normalizeRevisionLabel(
      'r${stageRevision > 0 ? stageRevision : 1}',
    );
    final got = normalizeRevisionLabel(revision);
    return got.isNotEmpty && got == expect;
  }

  bool get reviewActionsEnabled {
    if (!artifactsStructurallyPresent) return false;
    if (holdReason.isNotEmpty && !reviewReadyFlag) return false;
    if (schemaIsV2) {
      if (!(reviewReadyFlag && remoteReady && grantReady)) return false;
      if (manifestSHA256.trim().isEmpty) return false;
      if (deliveryStatus.isNotEmpty && deliveryStatus != 'ready') return false;
      return true;
    }
    return true;
  }

  /// Approve/revise only when package revision matches current stage review revision.
  bool reviewActionsEnabledForStage(int stageRevision) {
    if (!reviewActionsEnabled) return false;
    return matchesStageRevision(stageRevision);
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
      manifestSHA256: () {
        final top = '${json['manifestSHA256'] ?? ''}'.trim();
        if (top.isNotEmpty) return top;
        return _artifactSha(manifestRaw);
      }(),
      deliveryStatus: '${json['deliveryStatus'] ?? ''}'.trim(),
      pdfRemoteUrl: _artifactUrl(pdfRaw),
      epubRemoteUrl: _artifactUrl(epubRaw),
      manifestRemoteUrl: _artifactUrl(manifestRaw),
      coverGrantReady: _artifactReadyFlag(coverRaw, 'grantReady'),
      pdfGrantReady: _artifactReadyFlag(pdfRaw, 'grantReady'),
      epubGrantReady: _artifactReadyFlag(epubRaw, 'grantReady'),
      qualityGrantReady: _artifactReadyFlag(qualityRaw, 'grantReady'),
      manifestGrantReady: _artifactReadyFlag(manifestRaw, 'grantReady'),
      coverRemoteReady: _artifactReadyFlag(coverRaw, 'remoteReady'),
      pdfRemoteReady: _artifactReadyFlag(pdfRaw, 'remoteReady'),
      epubRemoteReady: _artifactReadyFlag(epubRaw, 'remoteReady'),
      qualityRemoteReady: _artifactReadyFlag(qualityRaw, 'remoteReady'),
      manifestRemoteReady: _artifactReadyFlag(manifestRaw, 'remoteReady'),
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
      manifestSHA256: () {
        final top = '${pkg['manifestSHA256'] ?? ''}'.trim();
        if (top.isNotEmpty) return top;
        return _artifactSha(manifestRaw);
      }(),
      deliveryStatus: '${pkg['deliveryStatus'] ?? ''}'.trim(),
      pdfRemoteUrl: _artifactUrl(pdfRaw),
      epubRemoteUrl: _artifactUrl(epubRaw),
      manifestRemoteUrl: _artifactUrl(manifestRaw),
      coverGrantReady: isV2
          ? _artifactReadyFlag(coverRaw, 'grantReady')
          : true,
      pdfGrantReady: isV2 ? _artifactReadyFlag(pdfRaw, 'grantReady') : true,
      epubGrantReady: isV2 ? _artifactReadyFlag(epubRaw, 'grantReady') : true,
      qualityGrantReady: isV2
          ? _artifactReadyFlag(qualityReportRaw, 'grantReady')
          : true,
      manifestGrantReady: isV2
          ? _artifactReadyFlag(manifestRaw, 'grantReady')
          : true,
      coverRemoteReady: isV2
          ? _artifactReadyFlag(coverRaw, 'remoteReady')
          : true,
      pdfRemoteReady: isV2 ? _artifactReadyFlag(pdfRaw, 'remoteReady') : true,
      epubRemoteReady: isV2 ? _artifactReadyFlag(epubRaw, 'remoteReady') : true,
      qualityRemoteReady: isV2
          ? _artifactReadyFlag(qualityReportRaw, 'remoteReady')
          : true,
      manifestRemoteReady: isV2
          ? _artifactReadyFlag(manifestRaw, 'remoteReady')
          : true,
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

  String resolveCoverFileName() {
    if (coverPath.isEmpty) return 'cover.png';
    final parts = coverPath.split(RegExp(r'[/\\]'));
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isNotEmpty ? name : 'cover.png';
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
