/// SotongWareCommercialQualityStandard v1 — mirrors Sotong24Work HEAD 5b204b7.
library;

class CommercialQualityStandard {
  const CommercialQualityStandard({
    this.present = true,
    this.schemaVersion = kSchemaVersion,
    this.targetAudience = '',
    this.customerProblem = '',
    this.promisedOutcome = '',
    this.uniqueValue = '',
    this.reasonsToPay = const [],
    this.commercialGoal = '',
    this.monetizationModel = '',
    this.brandDirection = '',
    this.referenceLevel = '',
    this.localizationTarget = '',
    this.accessibilityTarget = '',
    this.requiredDeliverables = const [],
    this.evidenceRequirements = const [],
    this.humanReviewRequirements = const [],
    this.revisionPolicy = '',
    this.releaseReadinessCriteria = const [],
    this.explicitlyOutOfScope = const [],
    this.legalPrivacyCopyrightRisks = const [],
  });

  static const kSchemaVersion = 1;
  static const kContractId = 'SotongWareCommercialQualityStandard';

  final bool present;
  final int schemaVersion;
  final String targetAudience;
  final String customerProblem;
  final String promisedOutcome;
  final String uniqueValue;
  final List<String> reasonsToPay;
  final String commercialGoal;
  final String monetizationModel;
  final String brandDirection;
  final String referenceLevel;
  final String localizationTarget;
  final String accessibilityTarget;
  final List<String> requiredDeliverables;
  final List<String> evidenceRequirements;
  final List<String> humanReviewRequirements;
  final String revisionPolicy;
  final List<String> releaseReadinessCriteria;
  final List<String> explicitlyOutOfScope;
  final List<String> legalPrivacyCopyrightRisks;

  Map<String, dynamic> toJson() {
    if (!present) return {};
    return {
      'schemaVersion': schemaVersion > 0 ? schemaVersion : kSchemaVersion,
      'targetAudience': targetAudience,
      'customerProblem': customerProblem,
      'promisedOutcome': promisedOutcome,
      'uniqueValue': uniqueValue,
      'reasonsToPay': reasonsToPay,
      'commercialGoal': commercialGoal,
      'monetizationModel': monetizationModel,
      'brandDirection': brandDirection,
      'referenceLevel': referenceLevel,
      'localizationTarget': localizationTarget,
      'accessibilityTarget': accessibilityTarget,
      'requiredDeliverables': requiredDeliverables,
      'evidenceRequirements': evidenceRequirements,
      'humanReviewRequirements': humanReviewRequirements,
      'revisionPolicy': revisionPolicy,
      'releaseReadinessCriteria': releaseReadinessCriteria,
      'explicitlyOutOfScope': explicitlyOutOfScope,
      'legalPrivacyCopyrightRisks': legalPrivacyCopyrightRisks,
    };
  }

  factory CommercialQualityStandard.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CommercialQualityStandard(present: false, schemaVersion: 0);
    }
    return CommercialQualityStandard(
      present: true,
      schemaVersion: _asInt(json['schemaVersion'], kSchemaVersion),
      targetAudience: '${json['targetAudience'] ?? ''}',
      customerProblem: '${json['customerProblem'] ?? ''}',
      promisedOutcome: '${json['promisedOutcome'] ?? ''}',
      uniqueValue: '${json['uniqueValue'] ?? ''}',
      reasonsToPay: _asStringList(json['reasonsToPay']),
      commercialGoal: '${json['commercialGoal'] ?? ''}',
      monetizationModel: '${json['monetizationModel'] ?? ''}',
      brandDirection: '${json['brandDirection'] ?? ''}',
      referenceLevel: '${json['referenceLevel'] ?? ''}',
      localizationTarget: '${json['localizationTarget'] ?? ''}',
      accessibilityTarget: '${json['accessibilityTarget'] ?? ''}',
      requiredDeliverables: _asStringList(json['requiredDeliverables']),
      evidenceRequirements: _asStringList(json['evidenceRequirements']),
      humanReviewRequirements: _asStringList(json['humanReviewRequirements']),
      revisionPolicy: '${json['revisionPolicy'] ?? ''}',
      releaseReadinessCriteria: _asStringList(json['releaseReadinessCriteria']),
      explicitlyOutOfScope: _asStringList(json['explicitlyOutOfScope']),
      legalPrivacyCopyrightRisks: _asStringList(
        json['legalPrivacyCopyrightRisks'],
      ),
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
