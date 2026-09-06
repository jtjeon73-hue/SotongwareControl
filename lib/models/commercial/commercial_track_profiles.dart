/// Track commercial quality profiles — mirrors Sotong24Work AppCommercialQualityProfile.
library;

import 'commercial_depth_plan.dart';
import 'commercial_quality_standard.dart';

class CommercialAppQualityProfile {
  const CommercialAppQualityProfile({
    this.present = true,
    this.schemaVersion = kSchemaVersion,
    this.targetUsers = '',
    this.realWorldProblem = '',
    this.primaryUseEnvironment = '',
    this.coreUserJourneys = const [],
    this.commercialGoal = '',
    this.monetizationModel = '',
    this.offlineRequirement = '',
    this.loginRequirement = '',
    this.loginRequirementRationale = '',
    this.privacyRiskLevel = '',
    this.accessibilityTarget = '',
    this.localizationTarget = '',
    this.requiredCapabilities = const [],
    this.criticalUserJourneys = const [],
    this.domainSpecificCapabilities = const [],
    this.dataLifecycle = '',
    this.importExportShare = const [],
    this.recoveryBackup = '',
    this.notifications = '',
    this.settingsHelpAbout = '',
    this.explicitlyOutOfScope = const [],
    this.designDirection = '',
    this.brandIdentity = '',
    this.designTokens = '',
    this.navigationModel = '',
    this.screenInventory = const [],
    this.screenPurpose = '',
    this.primaryAction = '',
    this.informationHierarchy = '',
    this.reusableComponents = const [],
    this.iconPolicy = '',
    this.stateUxRequired = const [],
    this.responsiveRequirements = '',
    this.supportedTextScales = const [],
    this.supportedOrientations = const [],
    this.referenceLevel = '',
    this.prohibitedPatterns = const [],
    this.performanceBudget = '',
    this.accessibilityChecks = const [],
    this.visualEvidenceRequirements = const [],
    this.deviceMatrix = const [],
    this.testMatrix = const [],
    this.ownerReviewRequired = true,
    this.independentReviewRequired = true,
    this.externalTesterReviewRequired = false,
    this.severityPolicy = '',
    this.releaseReadinessCriteria = const [],
    this.commercialDepthPlan = const CommercialDepthPlan(present: false),
  });

  /// Current schema for newly emitted app profiles (depth plan required).
  static const kSchemaVersion = 2;
  static const kMinSchemaVersion = 1;
  static const kDepthPlanRequiredFrom = 2;

  final bool present;
  final int schemaVersion;
  final String targetUsers;
  final String realWorldProblem;
  final String primaryUseEnvironment;
  final List<String> coreUserJourneys;
  final String commercialGoal;
  final String monetizationModel;
  final String offlineRequirement;
  final String loginRequirement;
  final String loginRequirementRationale;
  final String privacyRiskLevel;
  final String accessibilityTarget;
  final String localizationTarget;
  final List<String> requiredCapabilities;
  final List<String> criticalUserJourneys;
  final List<String> domainSpecificCapabilities;
  final String dataLifecycle;
  final List<String> importExportShare;
  final String recoveryBackup;
  final String notifications;
  final String settingsHelpAbout;
  final List<String> explicitlyOutOfScope;
  final String designDirection;
  final String brandIdentity;
  final String designTokens;
  final String navigationModel;
  final List<String> screenInventory;
  final String screenPurpose;
  final String primaryAction;
  final String informationHierarchy;
  final List<String> reusableComponents;
  final String iconPolicy;
  final List<String> stateUxRequired;
  final String responsiveRequirements;
  final List<String> supportedTextScales;
  final List<String> supportedOrientations;
  final String referenceLevel;
  final List<String> prohibitedPatterns;
  final String performanceBudget;
  final List<String> accessibilityChecks;
  final List<String> visualEvidenceRequirements;
  final List<String> deviceMatrix;
  final List<String> testMatrix;
  final bool ownerReviewRequired;
  final bool independentReviewRequired;
  final bool externalTesterReviewRequired;
  final String severityPolicy;
  final List<String> releaseReadinessCriteria;
  final CommercialDepthPlan commercialDepthPlan;

  Map<String, dynamic> toJson() {
    if (!present) return {};
    final out = <String, dynamic>{
      'schemaVersion': schemaVersion > 0 ? schemaVersion : kSchemaVersion,
      'targetUsers': targetUsers,
      'realWorldProblem': realWorldProblem,
      'primaryUseEnvironment': primaryUseEnvironment,
      'coreUserJourneys': coreUserJourneys,
      'commercialGoal': commercialGoal,
      'monetizationModel': monetizationModel,
      'offlineRequirement': offlineRequirement,
      'loginRequirement': loginRequirement,
      'loginRequirementRationale': loginRequirementRationale,
      'privacyRiskLevel': privacyRiskLevel,
      'accessibilityTarget': accessibilityTarget,
      'localizationTarget': localizationTarget,
      'requiredCapabilities': requiredCapabilities,
      'criticalUserJourneys': criticalUserJourneys,
      'domainSpecificCapabilities': domainSpecificCapabilities,
      'dataLifecycle': dataLifecycle,
      'importExportShare': importExportShare,
      'recoveryBackup': recoveryBackup,
      'notifications': notifications,
      'settingsHelpAbout': settingsHelpAbout,
      'explicitlyOutOfScope': explicitlyOutOfScope,
      'designDirection': designDirection,
      'brandIdentity': brandIdentity,
      'designTokens': designTokens,
      'navigationModel': navigationModel,
      'screenInventory': screenInventory,
      'screenPurpose': screenPurpose,
      'primaryAction': primaryAction,
      'informationHierarchy': informationHierarchy,
      'reusableComponents': reusableComponents,
      'iconPolicy': iconPolicy,
      'stateUxRequired': stateUxRequired,
      'responsiveRequirements': responsiveRequirements,
      'supportedTextScales': supportedTextScales,
      'supportedOrientations': supportedOrientations,
      'referenceLevel': referenceLevel,
      'prohibitedPatterns': prohibitedPatterns,
      'performanceBudget': performanceBudget,
      'accessibilityChecks': accessibilityChecks,
      'visualEvidenceRequirements': visualEvidenceRequirements,
      'deviceMatrix': deviceMatrix,
      'testMatrix': testMatrix,
      'ownerReviewRequired': ownerReviewRequired,
      'independentReviewRequired': independentReviewRequired,
      'externalTesterReviewRequired': externalTesterReviewRequired,
      'severityPolicy': severityPolicy,
      'releaseReadinessCriteria': releaseReadinessCriteria,
    };
    if (commercialDepthPlan.present) {
      out['commercialDepthPlan'] = commercialDepthPlan.toJson();
    }
    return out;
  }

  factory CommercialAppQualityProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CommercialAppQualityProfile(
        present: false,
        schemaVersion: 0,
      );
    }
    final depthNode = json['commercialDepthPlan'];
    return CommercialAppQualityProfile(
      present: true,
      schemaVersion: _asInt(json['schemaVersion'], kSchemaVersion),
      targetUsers: '${json['targetUsers'] ?? ''}',
      realWorldProblem: '${json['realWorldProblem'] ?? ''}',
      primaryUseEnvironment: '${json['primaryUseEnvironment'] ?? ''}',
      coreUserJourneys: _asStringList(json['coreUserJourneys']),
      commercialGoal: '${json['commercialGoal'] ?? ''}',
      monetizationModel: '${json['monetizationModel'] ?? ''}',
      offlineRequirement: '${json['offlineRequirement'] ?? ''}',
      loginRequirement: '${json['loginRequirement'] ?? ''}',
      loginRequirementRationale: '${json['loginRequirementRationale'] ?? ''}',
      privacyRiskLevel: '${json['privacyRiskLevel'] ?? ''}',
      accessibilityTarget: '${json['accessibilityTarget'] ?? ''}',
      localizationTarget: '${json['localizationTarget'] ?? ''}',
      requiredCapabilities: _asStringList(json['requiredCapabilities']),
      criticalUserJourneys: _asStringList(json['criticalUserJourneys']),
      domainSpecificCapabilities: _asStringList(
        json['domainSpecificCapabilities'],
      ),
      dataLifecycle: '${json['dataLifecycle'] ?? ''}',
      importExportShare: _asStringList(json['importExportShare']),
      recoveryBackup: '${json['recoveryBackup'] ?? ''}',
      notifications: '${json['notifications'] ?? ''}',
      settingsHelpAbout: '${json['settingsHelpAbout'] ?? ''}',
      explicitlyOutOfScope: _asStringList(json['explicitlyOutOfScope']),
      designDirection: '${json['designDirection'] ?? ''}',
      brandIdentity: '${json['brandIdentity'] ?? ''}',
      designTokens: '${json['designTokens'] ?? ''}',
      navigationModel: '${json['navigationModel'] ?? ''}',
      screenInventory: _asStringList(json['screenInventory']),
      screenPurpose: '${json['screenPurpose'] ?? ''}',
      primaryAction: '${json['primaryAction'] ?? ''}',
      informationHierarchy: '${json['informationHierarchy'] ?? ''}',
      reusableComponents: _asStringList(json['reusableComponents']),
      iconPolicy: '${json['iconPolicy'] ?? ''}',
      stateUxRequired: _asStringList(json['stateUxRequired']),
      responsiveRequirements: '${json['responsiveRequirements'] ?? ''}',
      supportedTextScales: _asStringList(json['supportedTextScales']),
      supportedOrientations: _asStringList(json['supportedOrientations']),
      referenceLevel: '${json['referenceLevel'] ?? ''}',
      prohibitedPatterns: _asStringList(json['prohibitedPatterns']),
      performanceBudget: '${json['performanceBudget'] ?? ''}',
      accessibilityChecks: _asStringList(json['accessibilityChecks']),
      visualEvidenceRequirements: _asStringList(
        json['visualEvidenceRequirements'],
      ),
      deviceMatrix: _asStringList(json['deviceMatrix']),
      testMatrix: _asStringList(json['testMatrix']),
      ownerReviewRequired: json['ownerReviewRequired'] != false,
      independentReviewRequired: json['independentReviewRequired'] != false,
      externalTesterReviewRequired:
          json['externalTesterReviewRequired'] == true,
      severityPolicy: '${json['severityPolicy'] ?? ''}',
      releaseReadinessCriteria: _asStringList(json['releaseReadinessCriteria']),
      commercialDepthPlan: CommercialDepthPlan.fromJson(
        depthNode is Map ? Map<String, dynamic>.from(depthNode) : null,
      ),
    );
  }
}

class CommercialEbookQualityProfile {
  const CommercialEbookQualityProfile({
    this.present = true,
    this.schemaVersion = kSchemaVersion,
    this.standard = const CommercialQualityStandard(present: false),
    this.readerLevel = '',
    this.readerOutcome = '',
    this.paidValueVsFree = '',
    this.chapterOutline = const [],
    this.targetLengthBasis = '',
    this.practiceAssets = const [],
    this.factCheckPolicy = '',
    this.plagiarismCopyrightPolicy = '',
    this.editorialStyle = '',
    this.coverInteriorDesign = '',
    this.requiredFormats = const [],
    this.readabilityTargets = const [],
    this.previewSampleRequirements = const [],
    this.salesCopyRequirements = '',
    this.renderEvidenceRequirements = const [],
    this.rejectCriteria = const [],
  });

  static const kSchemaVersion = 1;

  final bool present;
  final int schemaVersion;
  final CommercialQualityStandard standard;
  final String readerLevel;
  final String readerOutcome;
  final String paidValueVsFree;
  final List<String> chapterOutline;
  final String targetLengthBasis;
  final List<String> practiceAssets;
  final String factCheckPolicy;
  final String plagiarismCopyrightPolicy;
  final String editorialStyle;
  final String coverInteriorDesign;
  final List<String> requiredFormats;
  final List<String> readabilityTargets;
  final List<String> previewSampleRequirements;
  final String salesCopyRequirements;
  final List<String> renderEvidenceRequirements;
  final List<String> rejectCriteria;

  Map<String, dynamic> toJson() {
    if (!present) return {};
    return {
      'schemaVersion': schemaVersion > 0 ? schemaVersion : kSchemaVersion,
      'standard': standard.toJson(),
      'readerLevel': readerLevel,
      'readerOutcome': readerOutcome,
      'paidValueVsFree': paidValueVsFree,
      'chapterOutline': chapterOutline,
      'targetLengthBasis': targetLengthBasis,
      'practiceAssets': practiceAssets,
      'factCheckPolicy': factCheckPolicy,
      'plagiarismCopyrightPolicy': plagiarismCopyrightPolicy,
      'editorialStyle': editorialStyle,
      'coverInteriorDesign': coverInteriorDesign,
      'requiredFormats': requiredFormats,
      'readabilityTargets': readabilityTargets,
      'previewSampleRequirements': previewSampleRequirements,
      'salesCopyRequirements': salesCopyRequirements,
      'renderEvidenceRequirements': renderEvidenceRequirements,
      'rejectCriteria': rejectCriteria,
    };
  }

  factory CommercialEbookQualityProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CommercialEbookQualityProfile(
        present: false,
        schemaVersion: 0,
      );
    }
    final standardNode = json['standard'];
    return CommercialEbookQualityProfile(
      present: true,
      schemaVersion: _asInt(json['schemaVersion'], kSchemaVersion),
      standard: CommercialQualityStandard.fromJson(
        standardNode is Map
            ? Map<String, dynamic>.from(standardNode)
            : Map<String, dynamic>.from(json),
      ),
      readerLevel: '${json['readerLevel'] ?? ''}',
      readerOutcome: '${json['readerOutcome'] ?? ''}',
      paidValueVsFree: '${json['paidValueVsFree'] ?? ''}',
      chapterOutline: _asStringList(json['chapterOutline']),
      targetLengthBasis: '${json['targetLengthBasis'] ?? ''}',
      practiceAssets: _asStringList(json['practiceAssets']),
      factCheckPolicy: '${json['factCheckPolicy'] ?? ''}',
      plagiarismCopyrightPolicy: '${json['plagiarismCopyrightPolicy'] ?? ''}',
      editorialStyle: '${json['editorialStyle'] ?? ''}',
      coverInteriorDesign: '${json['coverInteriorDesign'] ?? ''}',
      requiredFormats: _asStringList(json['requiredFormats']),
      readabilityTargets: _asStringList(json['readabilityTargets']),
      previewSampleRequirements: _asStringList(
        json['previewSampleRequirements'],
      ),
      salesCopyRequirements: '${json['salesCopyRequirements'] ?? ''}',
      renderEvidenceRequirements: _asStringList(
        json['renderEvidenceRequirements'],
      ),
      rejectCriteria: _asStringList(json['rejectCriteria']),
    );
  }
}

class CommercialSiteQualityProfile {
  const CommercialSiteQualityProfile({
    this.present = true,
    this.schemaVersion = kSchemaVersion,
    this.standard = const CommercialQualityStandard(present: false),
    this.sitePurpose = '',
    this.siteSubtype = '',
    this.requiredRoutes = const [],
    this.heroMessage = '',
    this.primaryCtas = const [],
    this.realOffering = '',
    this.trustSignals = const [],
    this.authPaymentsNeed = '',
    this.responsiveBreakpoints = const [],
    this.designSystemBrand = '',
    this.stateUxRequired = const [],
    this.seoRequirements = const [],
    this.performanceBudget = '',
    this.securityPrivacyCookie = const [],
    this.analyticsConversion = const [],
    this.browserEvidenceRequirements = const [],
    this.rejectCriteria = const [],
  });

  static const kSchemaVersion = 1;

  final bool present;
  final int schemaVersion;
  final CommercialQualityStandard standard;
  final String sitePurpose;
  final String siteSubtype;
  final List<String> requiredRoutes;
  final String heroMessage;
  final List<String> primaryCtas;
  final String realOffering;
  final List<String> trustSignals;
  final String authPaymentsNeed;
  final List<String> responsiveBreakpoints;
  final String designSystemBrand;
  final List<String> stateUxRequired;
  final List<String> seoRequirements;
  final String performanceBudget;
  final List<String> securityPrivacyCookie;
  final List<String> analyticsConversion;
  final List<String> browserEvidenceRequirements;
  final List<String> rejectCriteria;

  Map<String, dynamic> toJson() {
    if (!present) return {};
    return {
      'schemaVersion': schemaVersion > 0 ? schemaVersion : kSchemaVersion,
      'standard': standard.toJson(),
      'sitePurpose': sitePurpose,
      'siteSubtype': siteSubtype,
      'requiredRoutes': requiredRoutes,
      'heroMessage': heroMessage,
      'primaryCtas': primaryCtas,
      'realOffering': realOffering,
      'trustSignals': trustSignals,
      'authPaymentsNeed': authPaymentsNeed,
      'responsiveBreakpoints': responsiveBreakpoints,
      'designSystemBrand': designSystemBrand,
      'stateUxRequired': stateUxRequired,
      'seoRequirements': seoRequirements,
      'performanceBudget': performanceBudget,
      'securityPrivacyCookie': securityPrivacyCookie,
      'analyticsConversion': analyticsConversion,
      'browserEvidenceRequirements': browserEvidenceRequirements,
      'rejectCriteria': rejectCriteria,
    };
  }

  factory CommercialSiteQualityProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CommercialSiteQualityProfile(
        present: false,
        schemaVersion: 0,
      );
    }
    final standardNode = json['standard'];
    return CommercialSiteQualityProfile(
      present: true,
      schemaVersion: _asInt(json['schemaVersion'], kSchemaVersion),
      standard: CommercialQualityStandard.fromJson(
        standardNode is Map
            ? Map<String, dynamic>.from(standardNode)
            : Map<String, dynamic>.from(json),
      ),
      sitePurpose: '${json['sitePurpose'] ?? ''}',
      siteSubtype: '${json['siteSubtype'] ?? ''}',
      requiredRoutes: _asStringList(json['requiredRoutes']),
      heroMessage: '${json['heroMessage'] ?? ''}',
      primaryCtas: _asStringList(json['primaryCtas']),
      realOffering: '${json['realOffering'] ?? ''}',
      trustSignals: _asStringList(json['trustSignals']),
      authPaymentsNeed: '${json['authPaymentsNeed'] ?? ''}',
      responsiveBreakpoints: _asStringList(json['responsiveBreakpoints']),
      designSystemBrand: '${json['designSystemBrand'] ?? ''}',
      stateUxRequired: _asStringList(json['stateUxRequired']),
      seoRequirements: _asStringList(json['seoRequirements']),
      performanceBudget: '${json['performanceBudget'] ?? ''}',
      securityPrivacyCookie: _asStringList(json['securityPrivacyCookie']),
      analyticsConversion: _asStringList(json['analyticsConversion']),
      browserEvidenceRequirements: _asStringList(
        json['browserEvidenceRequirements'],
      ),
      rejectCriteria: _asStringList(json['rejectCriteria']),
    );
  }
}

class CommercialContentQualityProfile {
  const CommercialContentQualityProfile({
    this.present = true,
    this.schemaVersion = kSchemaVersion,
    this.standard = const CommercialQualityStandard(present: false),
    this.contentSubtype = '',
    this.audience = '',
    this.messageEmotion = '',
    this.strongHook = '',
    this.storyScriptStructure = '',
    this.platformPurpose = '',
    this.lengthResolutionAspectFps = '',
    this.audioVisualQuality = const [],
    this.captionsReadability = const [],
    this.thumbnailTitleDescriptionCta = const [],
    this.brandConsistency = '',
    this.deliverableVariants = const [],
    this.rightsClearance = const [],
    this.platformExportSpecs = const [],
    this.publishPromoPackage = const [],
    this.derivativeReuse = const [],
    this.subtypeExtraCriteria = const [],
    this.mediaEvidenceRequirements = const [],
    this.rejectCriteria = const [],
    this.humanCreativeReviewRequired = true,
  });

  static const kSchemaVersion = 1;

  final bool present;
  final int schemaVersion;
  final CommercialQualityStandard standard;
  final String contentSubtype;
  final String audience;
  final String messageEmotion;
  final String strongHook;
  final String storyScriptStructure;
  final String platformPurpose;
  final String lengthResolutionAspectFps;
  final List<String> audioVisualQuality;
  final List<String> captionsReadability;
  final List<String> thumbnailTitleDescriptionCta;
  final String brandConsistency;
  final List<String> deliverableVariants;
  final List<String> rightsClearance;
  final List<String> platformExportSpecs;
  final List<String> publishPromoPackage;
  final List<String> derivativeReuse;
  final List<String> subtypeExtraCriteria;
  final List<String> mediaEvidenceRequirements;
  final List<String> rejectCriteria;
  final bool humanCreativeReviewRequired;

  Map<String, dynamic> toJson() {
    if (!present) return {};
    return {
      'schemaVersion': schemaVersion > 0 ? schemaVersion : kSchemaVersion,
      'standard': standard.toJson(),
      'contentSubtype': contentSubtype,
      'audience': audience,
      'messageEmotion': messageEmotion,
      'strongHook': strongHook,
      'storyScriptStructure': storyScriptStructure,
      'platformPurpose': platformPurpose,
      'lengthResolutionAspectFps': lengthResolutionAspectFps,
      'audioVisualQuality': audioVisualQuality,
      'captionsReadability': captionsReadability,
      'thumbnailTitleDescriptionCta': thumbnailTitleDescriptionCta,
      'brandConsistency': brandConsistency,
      'deliverableVariants': deliverableVariants,
      'rightsClearance': rightsClearance,
      'platformExportSpecs': platformExportSpecs,
      'publishPromoPackage': publishPromoPackage,
      'derivativeReuse': derivativeReuse,
      'subtypeExtraCriteria': subtypeExtraCriteria,
      'mediaEvidenceRequirements': mediaEvidenceRequirements,
      'rejectCriteria': rejectCriteria,
      'humanCreativeReviewRequired': humanCreativeReviewRequired,
    };
  }

  factory CommercialContentQualityProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CommercialContentQualityProfile(
        present: false,
        schemaVersion: 0,
      );
    }
    final standardNode = json['standard'];
    return CommercialContentQualityProfile(
      present: true,
      schemaVersion: _asInt(json['schemaVersion'], kSchemaVersion),
      standard: CommercialQualityStandard.fromJson(
        standardNode is Map
            ? Map<String, dynamic>.from(standardNode)
            : Map<String, dynamic>.from(json),
      ),
      contentSubtype: '${json['contentSubtype'] ?? ''}',
      audience: '${json['audience'] ?? ''}',
      messageEmotion: '${json['messageEmotion'] ?? ''}',
      strongHook: '${json['strongHook'] ?? ''}',
      storyScriptStructure: '${json['storyScriptStructure'] ?? ''}',
      platformPurpose: '${json['platformPurpose'] ?? ''}',
      lengthResolutionAspectFps: '${json['lengthResolutionAspectFps'] ?? ''}',
      audioVisualQuality: _asStringList(json['audioVisualQuality']),
      captionsReadability: _asStringList(json['captionsReadability']),
      thumbnailTitleDescriptionCta: _asStringList(
        json['thumbnailTitleDescriptionCta'],
      ),
      brandConsistency: '${json['brandConsistency'] ?? ''}',
      deliverableVariants: _asStringList(json['deliverableVariants']),
      rightsClearance: _asStringList(json['rightsClearance']),
      platformExportSpecs: _asStringList(json['platformExportSpecs']),
      publishPromoPackage: _asStringList(json['publishPromoPackage']),
      derivativeReuse: _asStringList(json['derivativeReuse']),
      subtypeExtraCriteria: _asStringList(json['subtypeExtraCriteria']),
      mediaEvidenceRequirements: _asStringList(
        json['mediaEvidenceRequirements'],
      ),
      rejectCriteria: _asStringList(json['rejectCriteria']),
      humanCreativeReviewRequired: json['humanCreativeReviewRequired'] != false,
    );
  }
}

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((e) => '$e').toList();
}
