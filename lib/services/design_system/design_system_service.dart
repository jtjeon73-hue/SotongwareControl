import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/design_system/design_system_catalog.dart';

class DesignSystemService {
  DesignSystemService._();
  static final DesignSystemService instance = DesignSystemService._();

  DesignSystemCatalog? _catalog;

  Future<DesignSystemCatalog> loadCatalog() async {
    final cached = _catalog;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(DesignSystemCatalog.kAssetPath);
    final json = jsonDecode(raw);
    if (json is! Map) {
      throw StateError('design_catalog_invalid');
    }
    final catalog = DesignSystemCatalog.fromJson(
      Map<String, dynamic>.from(json),
    );
    _catalog = catalog;
    return catalog;
  }

  DesignSystemCatalog? get cached => _catalog;

  /// AI recommendation based on artifact + free text context.
  DesignSelection recommend({
    required DesignSystemCatalog catalog,
    required String artifactType,
    String contextText = '',
  }) {
    final hay = contextText.toLowerCase();
    final artifact = artifactType.trim().toLowerCase();
    DesignRecommendationRule? fallback;
    for (final rule in catalog.recommendationRules) {
      if (rule.fallback) {
        fallback = rule;
        continue;
      }
      if (rule.artifact.isNotEmpty && rule.artifact != artifact) continue;
      if (rule.anyKeyword.isNotEmpty) {
        final hit = rule.anyKeyword.any((k) => hay.contains(k.toLowerCase()));
        if (!hit) continue;
      }
      final profile = catalog.byCode(rule.recommend) ?? catalog.defaultProfile;
      return DesignSelection.fromProfile(
        profile,
        designSource: 'ai_recommended',
      );
    }
    final code = fallback?.recommend ?? catalog.defaultProfile.profileCode;
    final profile = catalog.byCode(code) ?? catalog.defaultProfile;
    return DesignSelection.fromProfile(profile, designSource: 'ai_recommended');
  }

  String reasonFor({
    required DesignSystemCatalog catalog,
    required String profileCode,
    required String artifactType,
    String contextText = '',
  }) {
    final hay = contextText.toLowerCase();
    final artifact = artifactType.trim().toLowerCase();
    for (final rule in catalog.recommendationRules) {
      if (rule.recommend.toUpperCase() != profileCode.toUpperCase()) continue;
      if (rule.artifact.isNotEmpty && rule.artifact != artifact) continue;
      if (rule.anyKeyword.isNotEmpty &&
          !rule.anyKeyword.any((k) => hay.contains(k.toLowerCase()))) {
        continue;
      }
      return rule.reason;
    }
    return '선택한 디자인 프로필을 적용합니다.';
  }

  /// Pre-Review Quality Loop summary for Control UI.
  /// Work writes output/pre_review_quality_report.json; this maps it (or stub).
  DesignQualityReport buildPreReviewHook({
    required String recommendedDesignProfileCode,
    Map<String, dynamic>? reportJson,
  }) {
    if (reportJson != null && reportJson.isNotEmpty) {
      final issuesRaw = reportJson['criticalIssues'] ??
          reportJson['majorIssues'] ??
          reportJson['issues'] ??
          const [];
      final issues = <DesignQualityIssue>[];
      if (issuesRaw is List) {
        for (final item in issuesRaw) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          issues.add(
            DesignQualityIssue(
              dimension: '${m['dimension'] ?? 'quality'}',
              severity: '${m['severity'] ?? 'info'}',
              message: '${m['message'] ?? ''}',
              recommendation: '${m['recommendation'] ?? ''}',
            ),
          );
        }
      }
      final scoreVal = reportJson['score'];
      final score = scoreVal is num
          ? scoreVal.toDouble()
          : double.tryParse('$scoreVal') ?? 0;
      return DesignQualityReport(
        designSystemVersion:
            '${reportJson['designSystemVersion'] ?? DesignSystemCatalog.kVersion}',
        recommendedDesignProfileCode:
            '${reportJson['designProfile'] ?? recommendedDesignProfileCode}',
        score: score,
        preReviewQualityGate: reportJson['preReviewQualityGate'] == true,
        issues: issues.isEmpty
            ? [
                DesignQualityIssue(
                  dimension: 'release_readiness',
                  severity: 'info',
                  message:
                      'verdict=${reportJson['verdict']} attempts=${reportJson['internalRefineAttempts']}',
                  recommendation:
                      'internal refine does not increment user revision; STEP15/18 stay user-gated',
                ),
              ]
            : issues,
      );
    }
    return DesignQualityReport(
      designSystemVersion: DesignSystemCatalog.kVersion,
      recommendedDesignProfileCode: recommendedDesignProfileCode,
      score: 0,
      preReviewQualityGate: false,
      issues: const [
        DesignQualityIssue(
          dimension: 'release_readiness',
          severity: 'info',
          message:
              'Pre-Review Quality Loop active in Work (max 2 internal refine, pass≥90)',
          recommendation:
              'Wait for output/pre_review_quality_report.json before STEP15 user review',
        ),
        DesignQualityIssue(
          dimension: 'visual_system',
          severity: 'info',
          message:
              'Prefer profile structural cues (hero/nav/card/cta/density) over color-only swaps',
          recommendation: 'Select A~E by mood + layout, not swatches alone',
        ),
      ],
    );
  }
}
