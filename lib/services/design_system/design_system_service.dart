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

  /// Hook for future r1 auto-upgrade — no infinite loop in v1.1.
  DesignQualityReport buildPreReviewHook({
    required String recommendedDesignProfileCode,
  }) {
    return DesignQualityReport(
      designSystemVersion: DesignSystemCatalog.kVersion,
      recommendedDesignProfileCode: recommendedDesignProfileCode,
      score: 0,
      preReviewQualityGate: false,
      issues: const [
        DesignQualityIssue(
          dimension: 'brand_fit',
          severity: 'info',
          message:
              'preReviewQualityGate foundation ready — automatic r1 upgrade loop remains disabled',
          recommendation:
              'Apply recommendedDesignProfile early; use design_change_requested for post-result changes',
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
