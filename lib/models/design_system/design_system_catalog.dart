/// SotongWare Design System v1 catalog models (SSOT: assets/design_system/catalog.json).
library;

class DesignSystemCatalog {
  const DesignSystemCatalog({
    required this.designSystemVersion,
    required this.updatedAt,
    required this.brandCore,
    required this.profiles,
    required this.tracks,
    required this.contentSubtypes,
    required this.recommendationRules,
    required this.designChangeContract,
    required this.designQualityProfile,
  });

  final String designSystemVersion;
  final String updatedAt;
  final DesignBrandCore brandCore;
  final List<DesignProfile> profiles;
  final List<String> tracks;
  final List<String> contentSubtypes;
  final List<DesignRecommendationRule> recommendationRules;
  final Map<String, dynamic> designChangeContract;
  final Map<String, dynamic> designQualityProfile;

  static const kAssetPath = 'assets/design_system/catalog.json';
  static const kVersion = '1.0.0';

  DesignProfile? byCode(String code) {
    final c = code.trim().toUpperCase();
    for (final p in profiles) {
      if (p.profileCode == c) return p;
    }
    return null;
  }

  DesignProfile get defaultProfile =>
      byCode(brandCore.defaultProfileCode) ??
      profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first);

  factory DesignSystemCatalog.fromJson(Map<String, dynamic> json) {
    final profilesRaw = json['profiles'];
    final rulesRaw = json['recommendationRules'];
    return DesignSystemCatalog(
      designSystemVersion: '${json['designSystemVersion'] ?? kVersion}',
      updatedAt: '${json['updatedAt'] ?? ''}',
      brandCore: DesignBrandCore.fromJson(
        json['brandCore'] is Map
            ? Map<String, dynamic>.from(json['brandCore'] as Map)
            : const {},
      ),
      profiles: profilesRaw is List
          ? profilesRaw
                .whereType<Map>()
                .map(
                  (e) => DesignProfile.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      tracks: _stringList(json['tracks']),
      contentSubtypes: _stringList(json['contentSubtypes']),
      recommendationRules: rulesRaw is List
          ? rulesRaw
                .whereType<Map>()
                .map(
                  (e) => DesignRecommendationRule.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      designChangeContract: json['designChangeContract'] is Map
          ? Map<String, dynamic>.from(json['designChangeContract'] as Map)
          : const {},
      designQualityProfile: json['designQualityProfile'] is Map
          ? Map<String, dynamic>.from(json['designQualityProfile'] as Map)
          : const {},
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
  }
}

class DesignBrandCore {
  const DesignBrandCore({
    required this.publicName,
    required this.personality,
    required this.nonNegotiables,
    required this.defaultProfileCode,
  });

  final String publicName;
  final List<String> personality;
  final List<String> nonNegotiables;
  final String defaultProfileCode;

  factory DesignBrandCore.fromJson(Map<String, dynamic> json) {
    return DesignBrandCore(
      publicName: '${json['publicName'] ?? 'SotongWare'}',
      personality: DesignSystemCatalog._stringList(json['personality']),
      nonNegotiables: DesignSystemCatalog._stringList(json['nonNegotiables']),
      defaultProfileCode: '${json['defaultProfileCode'] ?? 'A'}',
    );
  }
}

class DesignProfile {
  const DesignProfile({
    required this.profileId,
    required this.profileCode,
    required this.profileName,
    required this.profileDescription,
    required this.profileCategory,
    required this.supportedTracks,
    required this.isDefault,
    required this.isActive,
    required this.version,
    required this.legacyDesignDirection,
    required this.revisionDirectionHint,
    required this.primaryColor,
    required this.previewSwatches,
    required this.previewHeadline,
    required this.heroLabel,
    required this.contentDensity,
    required this.trackAdaptation,
  });

  final String profileId;
  final String profileCode;
  final String profileName;
  final String profileDescription;
  final String profileCategory;
  final List<String> supportedTracks;
  final bool isDefault;
  final bool isActive;
  final String version;
  final String legacyDesignDirection;
  final String revisionDirectionHint;
  final String primaryColor;
  final List<String> previewSwatches;
  final String previewHeadline;
  final String heroLabel;
  final String contentDensity;
  final Map<String, dynamic> trackAdaptation;

  factory DesignProfile.fromJson(Map<String, dynamic> json) {
    final brand = json['brand'] is Map
        ? Map<String, dynamic>.from(json['brand'] as Map)
        : const <String, dynamic>{};
    final preview = json['preview'] is Map
        ? Map<String, dynamic>.from(json['preview'] as Map)
        : const <String, dynamic>{};
    final layout = json['layout'] is Map
        ? Map<String, dynamic>.from(json['layout'] as Map)
        : const <String, dynamic>{};
    return DesignProfile(
      profileId: '${json['profileId'] ?? ''}',
      profileCode: '${json['profileCode'] ?? ''}'.toUpperCase(),
      profileName: '${json['profileName'] ?? ''}',
      profileDescription: '${json['profileDescription'] ?? ''}',
      profileCategory: '${json['profileCategory'] ?? ''}',
      supportedTracks: DesignSystemCatalog._stringList(json['supportedTracks']),
      isDefault: json['isDefault'] == true,
      isActive: json['isActive'] != false,
      version: '${json['version'] ?? '1.0.0'}',
      legacyDesignDirection:
          '${json['legacyDesignDirection'] ?? 'clarity_first'}',
      revisionDirectionHint:
          '${json['revisionDirectionHint'] ?? 'keep_current_partial_edit'}',
      primaryColor: '${brand['primary'] ?? '#0F766E'}',
      previewSwatches: DesignSystemCatalog._stringList(preview['swatches']),
      previewHeadline: '${preview['sampleHeadline'] ?? ''}',
      heroLabel: '${preview['heroLabel'] ?? ''}',
      contentDensity: '${layout['contentDensity'] ?? ''}',
      trackAdaptation: json['trackAdaptation'] is Map
          ? Map<String, dynamic>.from(json['trackAdaptation'] as Map)
          : const {},
    );
  }
}

class DesignRecommendationRule {
  const DesignRecommendationRule({
    required this.id,
    required this.recommend,
    required this.reason,
    this.alternates = const [],
    this.anyKeyword = const [],
    this.artifact = '',
    this.fallback = false,
  });

  final String id;
  final String recommend;
  final String reason;
  final List<String> alternates;
  final List<String> anyKeyword;
  final String artifact;
  final bool fallback;

  factory DesignRecommendationRule.fromJson(Map<String, dynamic> json) {
    final when = json['when'] is Map
        ? Map<String, dynamic>.from(json['when'] as Map)
        : const <String, dynamic>{};
    return DesignRecommendationRule(
      id: '${json['id'] ?? ''}',
      recommend: '${json['recommend'] ?? 'A'}'.toUpperCase(),
      reason: '${json['reason'] ?? ''}',
      alternates: DesignSystemCatalog._stringList(json['alternates']),
      anyKeyword: DesignSystemCatalog._stringList(when['anyKeyword']),
      artifact: '${when['artifact'] ?? ''}',
      fallback: when['fallback'] == true,
    );
  }
}

class DesignSelection {
  const DesignSelection({
    this.designSystemVersion = DesignSystemCatalog.kVersion,
    this.designProfileId = '',
    this.designProfileCode = 'A',
    this.designProfileVersion = '1.0.0',
    this.designDirection = 'clarity_first',
    this.designSource = 'ai_recommended',
  });

  final String designSystemVersion;
  final String designProfileId;
  final String designProfileCode;
  final String designProfileVersion;
  final String designDirection;
  final String designSource;

  Map<String, dynamic> toInstructionJsonFields() => {
    'designSystemVersion': designSystemVersion,
    'designProfileId': designProfileId,
    'designProfileCode': designProfileCode,
    'designProfileVersion': designProfileVersion,
    'designDirection': designDirection,
    'designSource': designSource,
  };

  factory DesignSelection.fromProfile(
    DesignProfile profile, {
    required String designSource,
  }) {
    return DesignSelection(
      designProfileId: profile.profileId,
      designProfileCode: profile.profileCode,
      designProfileVersion: profile.version,
      designDirection: profile.legacyDesignDirection,
      designSource: designSource,
    );
  }
}

class DesignQualityIssue {
  const DesignQualityIssue({
    required this.dimension,
    required this.severity,
    required this.message,
    this.recommendation = '',
  });

  final String dimension;
  final String severity;
  final String message;
  final String recommendation;

  Map<String, dynamic> toJson() => {
    'dimension': dimension,
    'severity': severity,
    'message': message,
    'recommendation': recommendation,
  };
}

class DesignQualityReport {
  const DesignQualityReport({
    this.designSystemVersion = DesignSystemCatalog.kVersion,
    this.recommendedDesignProfileCode = 'A',
    this.score = 0,
    this.issues = const [],
    this.preReviewQualityGate = false,
  });

  final String designSystemVersion;
  final String recommendedDesignProfileCode;
  final double score;
  final List<DesignQualityIssue> issues;
  final bool preReviewQualityGate;

  Map<String, dynamic> toJson() => {
    'designSystemVersion': designSystemVersion,
    'recommendedDesignProfile': recommendedDesignProfileCode,
    'score': score,
    'issues': issues.map((e) => e.toJson()).toList(),
    'preReviewQualityGate': preReviewQualityGate,
    'designQualityIssues': issues.map((e) => e.toJson()).toList(),
  };
}
