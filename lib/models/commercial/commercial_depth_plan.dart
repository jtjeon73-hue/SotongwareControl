/// commercialDepthPlan — mirrors Sotong24Work AppCommercialDepthPlan.h.
library;

class CommercialScreenDepthSpec {
  const CommercialScreenDepthSpec({
    this.screenId = '',
    this.purpose = '',
    this.primaryAction = '',
    this.backTarget = '',
    this.requiredBehaviors = const [],
  });

  final String screenId;
  final String purpose;
  final String primaryAction;
  final String backTarget;
  final List<String> requiredBehaviors;

  Map<String, dynamic> toJson() => {
    'screenId': screenId,
    'purpose': purpose,
    'primaryAction': primaryAction,
    'backTarget': backTarget,
    'requiredBehaviors': requiredBehaviors,
  };

  factory CommercialScreenDepthSpec.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CommercialScreenDepthSpec();
    }
    return CommercialScreenDepthSpec(
      screenId: '${json['screenId'] ?? ''}',
      purpose: '${json['purpose'] ?? ''}',
      primaryAction: '${json['primaryAction'] ?? ''}',
      backTarget: '${json['backTarget'] ?? ''}',
      requiredBehaviors: _asStringList(json['requiredBehaviors']),
    );
  }
}

class CommercialDepthPlan {
  const CommercialDepthPlan({
    this.present = true,
    this.schemaVersion = kPlanSchemaVersion,
    this.appPurpose = '',
    this.targetUsers = '',
    this.coreUserFlows = const [],
    this.requiredScreens = const [],
    this.coreFeatures = const [],
    this.supportingFeatures = const [],
    this.domainContentRequirements = const [],
    this.minDomainTemplates = 0,
    this.minItemsPerCoreTemplate = 0,
    this.requiredStates = const [],
    this.navigationBackScenarios = const [],
    this.settingsRequirements = const [],
    this.dataSafetyRequirements = const [],
    this.mobileViewportWidthsPx = const [],
    this.mobileTextScales = const [],
    this.reviewCriteria = const [],
    this.antiPatternsBanned = const [],
    this.screenDepth = const [],
  });

  static const kPlanSchemaVersion = 1;

  static const kRequiredBackScenarios = [
    'appbar_back',
    'system_back',
    'dirty_exit_guard',
    'dialog_back',
    'detail_to_list',
    'home_return',
  ];

  static const kRequiredViewportWidths = ['320', '360', '390', '412', '430'];

  /// Farm-safety R3 calibration lessons — must stay banned for new apps.
  static const kCalibrationAntiPatterns = [
    'listtile_trailing_title_squeeze',
    'one_glyph_vertical_wrap',
    'shallow_domain_templates',
    'empty_settings_shell',
    'menu_card_without_function',
    'screen_exists_only_pass',
    'sample_only_placeholder_data',
    'unverified_back_navigation',
  ];

  final bool present;
  final int schemaVersion;
  final String appPurpose;
  final String targetUsers;
  final List<String> coreUserFlows;
  final List<String> requiredScreens;
  final List<String> coreFeatures;
  final List<String> supportingFeatures;
  final List<String> domainContentRequirements;
  final int minDomainTemplates;
  final int minItemsPerCoreTemplate;
  final List<String> requiredStates;
  final List<String> navigationBackScenarios;
  final List<String> settingsRequirements;
  final List<String> dataSafetyRequirements;
  final List<String> mobileViewportWidthsPx;
  final List<String> mobileTextScales;
  final List<String> reviewCriteria;
  final List<String> antiPatternsBanned;
  final List<CommercialScreenDepthSpec> screenDepth;

  /// Defaults matching AppCommercialDepthPlan::DefaultsForStandardApp().
  factory CommercialDepthPlan.defaultsForStandardApp({
    String appPurpose = 'declare_before_implementation',
    String targetUsers = '',
  }) {
    return CommercialDepthPlan(
      present: true,
      schemaVersion: kPlanSchemaVersion,
      appPurpose: appPurpose,
      targetUsers: targetUsers,
      coreUserFlows: const [
        'start_to_complete_core_work',
        'review_or_history_after_save',
      ],
      requiredScreens: const [
        'home',
        'list_or_templates',
        'detail_or_edit',
        'settings',
      ],
      coreFeatures: const ['create_or_start', 'persist', 'review_result'],
      supportingFeatures: const [
        'search_or_filter_if_applicable',
        'export_or_share_if_applicable',
      ],
      domainContentRequirements: const [
        'domain_templates_or_items_sufficient_for_real_use',
        'no_demo_only_two_or_three_shallow_samples',
      ],
      minDomainTemplates: 5,
      minItemsPerCoreTemplate: 8,
      requiredStates: const [
        'empty',
        'loading',
        'error',
        'offline',
        'destructive_confirm',
      ],
      navigationBackScenarios: List<String>.from(kRequiredBackScenarios),
      settingsRequirements: const [
        'meaningful_settings_or_help',
        'version_without_debug_schema',
        'data_privacy_or_permissions_note',
      ],
      dataSafetyRequirements: const [
        'persist_core_work',
        'restore_after_relaunch',
        'destructive_confirm',
      ],
      mobileViewportWidthsPx: List<String>.from(kRequiredViewportWidths),
      mobileTextScales: const ['1.0', '1.3', '1.5', '2.0'],
      reviewCriteria: const [
        'real_user_reason_to_keep',
        'domain_content_depth',
        'navigation_safe',
        'mobile_readable',
        'no_placeholder_shell',
      ],
      antiPatternsBanned: List<String>.from(kCalibrationAntiPatterns),
    );
  }

  Map<String, dynamic> toJson() {
    if (!present) return {};
    return {
      'schemaVersion': schemaVersion > 0 ? schemaVersion : kPlanSchemaVersion,
      'appPurpose': appPurpose,
      'targetUsers': targetUsers,
      'coreUserFlows': coreUserFlows,
      'requiredScreens': requiredScreens,
      'coreFeatures': coreFeatures,
      'supportingFeatures': supportingFeatures,
      'domainContentRequirements': domainContentRequirements,
      'minDomainTemplates': minDomainTemplates,
      'minItemsPerCoreTemplate': minItemsPerCoreTemplate,
      'requiredStates': requiredStates,
      'navigationBackScenarios': navigationBackScenarios,
      'settingsRequirements': settingsRequirements,
      'dataSafetyRequirements': dataSafetyRequirements,
      'mobileViewportWidthsPx': mobileViewportWidthsPx,
      'mobileTextScales': mobileTextScales,
      'reviewCriteria': reviewCriteria,
      'antiPatternsBanned': antiPatternsBanned,
      'screenDepth': screenDepth.map((s) => s.toJson()).toList(),
    };
  }

  factory CommercialDepthPlan.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CommercialDepthPlan(present: false, schemaVersion: 0);
    }
    final screensRaw = json['screenDepth'];
    final screens = <CommercialScreenDepthSpec>[];
    if (screensRaw is List) {
      for (final item in screensRaw) {
        if (item is Map) {
          screens.add(
            CommercialScreenDepthSpec.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return CommercialDepthPlan(
      present: true,
      schemaVersion: _asInt(json['schemaVersion'], kPlanSchemaVersion),
      appPurpose: '${json['appPurpose'] ?? ''}',
      targetUsers: '${json['targetUsers'] ?? ''}',
      coreUserFlows: _asStringList(json['coreUserFlows']),
      requiredScreens: _asStringList(json['requiredScreens']),
      coreFeatures: _asStringList(json['coreFeatures']),
      supportingFeatures: _asStringList(json['supportingFeatures']),
      domainContentRequirements: _asStringList(
        json['domainContentRequirements'],
      ),
      minDomainTemplates: _asInt(json['minDomainTemplates'], 0),
      minItemsPerCoreTemplate: _asInt(json['minItemsPerCoreTemplate'], 0),
      requiredStates: _asStringList(json['requiredStates']),
      navigationBackScenarios: _asStringList(json['navigationBackScenarios']),
      settingsRequirements: _asStringList(json['settingsRequirements']),
      dataSafetyRequirements: _asStringList(json['dataSafetyRequirements']),
      mobileViewportWidthsPx: _asStringList(json['mobileViewportWidthsPx']),
      mobileTextScales: _asStringList(json['mobileTextScales']),
      reviewCriteria: _asStringList(json['reviewCriteria']),
      antiPatternsBanned: _asStringList(json['antiPatternsBanned']),
      screenDepth: screens,
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
