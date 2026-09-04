/// WorkInstructionBriefContract v1 — mirrors Sotong24Work HEAD 5b204b7.
///
/// Note: Work uses `unansweredQuestions` (not clarificationQuestions).
library;

class WorkInstructionBrief {
  const WorkInstructionBrief({
    this.present = true,
    this.schemaVersion = kSchemaVersion,
    this.displayTitle = '',
    this.workingTitle = '',
    this.suggestedTitles = const [],
    this.displayTitleEn = '',
    this.internalProjectId = '',
    this.repositorySlug = '',
    this.originalUserBrief = '',
    this.structuredUserInputs = const {},
    this.aiAugmentedBrief = '',
    this.aiAssumptions = const [],
    this.unansweredQuestions = const [],
    this.acceptedAiSuggestions = const [],
    this.rejectedAiSuggestions = const [],
    this.manualOnlyMode = false,
    this.titleSource = '',
    this.userConfirmedAt = '',
    this.briefVersion = 1,
    this.creationMode = 'new_product',
    this.sourceInstructionId = '',
    this.sourceRevision = '',
    this.requestedRevision = '',
    this.ownerReviewDecisionRef = '',
    this.preservedArtifactHashes = const [],
    this.requestedChanges = const [],
    this.nextAllowedAction = '',
  });

  static const kSchemaVersion = 1;
  static const kBriefContractVersion = 1;

  final bool present;
  final int schemaVersion;
  final String displayTitle;
  final String workingTitle;
  final List<String> suggestedTitles;
  final String displayTitleEn;
  final String internalProjectId;
  final String repositorySlug;
  final String originalUserBrief;
  final Map<String, dynamic> structuredUserInputs;
  final String aiAugmentedBrief;
  final List<String> aiAssumptions;

  /// Work SSOT name (UI schema may say clarificationQuestions).
  final List<String> unansweredQuestions;
  final List<String> acceptedAiSuggestions;
  final List<String> rejectedAiSuggestions;
  final bool manualOnlyMode;
  final String titleSource; // manual | ai_suggested | ai_refined
  final String userConfirmedAt;
  final int briefVersion;
  final String creationMode; // new_product | revise_existing
  final String sourceInstructionId;
  final String sourceRevision;
  final String requestedRevision;
  final String ownerReviewDecisionRef;
  final List<String> preservedArtifactHashes;
  final List<String> requestedChanges;
  final String nextAllowedAction;

  Map<String, dynamic> toJson() {
    if (!present) return {};
    return {
      'schemaVersion': schemaVersion > 0 ? schemaVersion : kSchemaVersion,
      'displayTitle': displayTitle,
      'workingTitle': workingTitle,
      'suggestedTitles': suggestedTitles,
      'displayTitleEn': displayTitleEn,
      'internalProjectId': internalProjectId,
      'repositorySlug': repositorySlug,
      'originalUserBrief': originalUserBrief,
      'structuredUserInputs': structuredUserInputs,
      'aiAugmentedBrief': aiAugmentedBrief,
      'aiAssumptions': aiAssumptions,
      'unansweredQuestions': unansweredQuestions,
      'acceptedAiSuggestions': acceptedAiSuggestions,
      'rejectedAiSuggestions': rejectedAiSuggestions,
      'manualOnlyMode': manualOnlyMode,
      'titleSource': titleSource,
      'userConfirmedAt': userConfirmedAt,
      'briefVersion': briefVersion,
      'creationMode': creationMode.isEmpty ? 'new_product' : creationMode,
      'sourceInstructionId': sourceInstructionId,
      'sourceRevision': sourceRevision,
      'requestedRevision': requestedRevision,
      'ownerReviewDecisionRef': ownerReviewDecisionRef,
      'preservedArtifactHashes': preservedArtifactHashes,
      'requestedChanges': requestedChanges,
      'nextAllowedAction': nextAllowedAction,
    };
  }

  factory WorkInstructionBrief.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const WorkInstructionBrief(present: false, schemaVersion: 0);
    }
    final structured = json['structuredUserInputs'];
    return WorkInstructionBrief(
      present: true,
      schemaVersion: _asInt(json['schemaVersion'], kSchemaVersion),
      displayTitle: '${json['displayTitle'] ?? ''}',
      workingTitle: '${json['workingTitle'] ?? ''}',
      suggestedTitles: _asStringList(json['suggestedTitles']),
      displayTitleEn: '${json['displayTitleEn'] ?? ''}',
      internalProjectId: '${json['internalProjectId'] ?? ''}',
      repositorySlug: '${json['repositorySlug'] ?? ''}',
      originalUserBrief: '${json['originalUserBrief'] ?? ''}',
      structuredUserInputs: structured is Map
          ? Map<String, dynamic>.from(structured)
          : const {},
      aiAugmentedBrief: '${json['aiAugmentedBrief'] ?? ''}',
      aiAssumptions: _asStringList(json['aiAssumptions']),
      unansweredQuestions: _asStringList(
        json['unansweredQuestions'] ?? json['clarificationQuestions'],
      ),
      acceptedAiSuggestions: _asStringList(json['acceptedAiSuggestions']),
      rejectedAiSuggestions: _asStringList(json['rejectedAiSuggestions']),
      manualOnlyMode: json['manualOnlyMode'] == true,
      titleSource: '${json['titleSource'] ?? ''}',
      userConfirmedAt: '${json['userConfirmedAt'] ?? ''}',
      briefVersion: _asInt(json['briefVersion'], 1),
      creationMode: '${json['creationMode'] ?? 'new_product'}',
      sourceInstructionId: '${json['sourceInstructionId'] ?? ''}',
      sourceRevision: '${json['sourceRevision'] ?? ''}',
      requestedRevision: '${json['requestedRevision'] ?? ''}',
      ownerReviewDecisionRef: '${json['ownerReviewDecisionRef'] ?? ''}',
      preservedArtifactHashes: _asStringList(json['preservedArtifactHashes']),
      requestedChanges: _asStringList(json['requestedChanges']),
      nextAllowedAction: '${json['nextAllowedAction'] ?? ''}',
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
