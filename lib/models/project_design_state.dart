/// Project Design Engine 상태 — PlanningWizardState / BusinessPlanInput과 호환.
library;

import '../models/artifact_type.dart';
import '../models/concept_candidate.dart';
import '../models/planning_wizard_state.dart';
import '../services/site_subtype_contract.dart';

/// Wizard STEP 0~6
class ProjectDesignStep {
  static const artifact = 0;
  static const audience = 1;
  static const topics = 2;
  static const details = 3;
  static const production = 4;
  static const review = 5;
  static const finalize = 6;

  static const labels = [
    '사업유형 선택',
    '대상 고객',
    '핵심 내용',
    '세부 기획',
    '필요한 최소 설정',
    '최종 확인',
    '작업지시 생성',
  ];

  static const count = 7;
}

/// 최종 확정 → 생성 → 로컬 검증 → 전송 준비 (네트워크 전송과 분리).
class StudioPipelinePhase {
  static const drafting = 'drafting';
  static const contentConfirmed = 'content_confirmed';
  static const instructionGenerated = 'instruction_generated';
  static const locallyValidated = 'locally_validated';
  static const readyToSend = 'ready_to_send';
}

class ProjectDesignState {
  ProjectDesignState({
    this.step = ProjectDesignStep.artifact,
    this.artifactType,
    this.contentSubtype,
    this.siteSubtype,
    List<String>? selectedAudiences,
    this.customAudience = '',
    List<String>? selectedTopicIds,
    List<String>? selectedConceptIds,
    List<ConceptCandidate>? userAddedConcepts,
    this.designMemo = '',
    Map<String, List<String>>? productionSelections,
    this.topic = '',
    this.customerProblem = '',
    this.targetCustomer = '',
    this.desiredOutcome = '',
    this.topicStatus = DesignFieldStatus.undecided,
    this.problemStatus = DesignFieldStatus.undecided,
    this.outcomeStatus = DesignFieldStatus.undecided,
    this.customerStatus = DesignFieldStatus.undecided,
    this.planningConfirmed = false,
    this.combinedDirection = '',
    String? wizardSessionId,
    this.creationMode = 'new_product',
    this.manualOnlyMode = false,
    this.displayTitle = '',
    this.workingTitle = '',
    List<String>? suggestedTitles,
    this.titleSource = '',
    this.originalUserBrief = '',
    this.originalUserBriefConfirmed = false,
    this.aiAugmentedBrief = '',
    List<String>? aiAssumptions,
    List<String>? unansweredQuestions,
    List<String>? acceptedAiSuggestions,
    List<String>? rejectedAiSuggestions,
    List<String>? reasonsToPay,
    this.uniqueValue = '',
    this.sourceInstructionId = '',
    this.sourceRevision = '',
    this.requestedRevision = '',
    this.ownerReviewDecisionRef = '',
    List<String>? preservedArtifactHashes,
    List<String>? requestedChanges,
    this.userConfirmedAt = '',
    this.studioPipelinePhase = StudioPipelinePhase.drafting,
    this.commercialLocalValidated = false,
    this.useEnvironment = '',
    this.mainPainPoint = '',
    this.digitalSkillLevel = '',
  }) : selectedAudiences = selectedAudiences ?? [],
       selectedTopicIds = selectedTopicIds ?? [],
       selectedConceptIds = selectedConceptIds ?? [],
       userAddedConcepts = userAddedConcepts ?? [],
       productionSelections = productionSelections ?? {},
       suggestedTitles = suggestedTitles ?? [],
       aiAssumptions = aiAssumptions ?? [],
       unansweredQuestions = unansweredQuestions ?? [],
       acceptedAiSuggestions = acceptedAiSuggestions ?? [],
       rejectedAiSuggestions = rejectedAiSuggestions ?? [],
       reasonsToPay = reasonsToPay ?? [],
       preservedArtifactHashes = preservedArtifactHashes ?? [],
       requestedChanges = requestedChanges ?? [],
       wizardSessionId =
           wizardSessionId ??
           'wiz_${DateTime.now().toUtc().millisecondsSinceEpoch}';

  int step;

  /// 새 작업 / 이어하기를 구분하는 세션 id. autosave와 복원 경로를 분리한다.
  String wizardSessionId;
  String? artifactType;
  String? contentSubtype;

  /// Site track subtype (corporate_site | marketing_site | …). Single-select.
  String? siteSubtype;
  List<String> selectedAudiences;
  String customAudience;

  /// Legacy topic ids (compat) + concept ids.
  List<String> selectedTopicIds;
  List<String> selectedConceptIds;
  List<ConceptCandidate> userAddedConcepts;
  String designMemo;
  Map<String, List<String>> productionSelections;
  String topic;
  String customerProblem;
  String targetCustomer;
  String desiredOutcome;

  DesignFieldStatus topicStatus;
  DesignFieldStatus problemStatus;
  DesignFieldStatus outcomeStatus;
  DesignFieldStatus customerStatus;

  /// Final planning confirmation before instruction generation.
  bool planningConfirmed;

  /// Multi-concept combined project direction (suggested until confirmed).
  String combinedDirection;

  /// new_product | revise_existing
  String creationMode;
  bool manualOnlyMode;
  String displayTitle;
  String workingTitle;
  List<String> suggestedTitles;
  String titleSource;
  String originalUserBrief;
  bool originalUserBriefConfirmed;
  String aiAugmentedBrief;
  List<String> aiAssumptions;
  List<String> unansweredQuestions;
  List<String> acceptedAiSuggestions;
  List<String> rejectedAiSuggestions;
  List<String> reasonsToPay;
  String uniqueValue;
  String sourceInstructionId;
  String sourceRevision;
  String requestedRevision;
  String ownerReviewDecisionRef;
  List<String> preservedArtifactHashes;
  List<String> requestedChanges;
  String userConfirmedAt;
  String studioPipelinePhase;
  bool commercialLocalValidated;
  String useEnvironment;
  String mainPainPoint;
  String digitalSkillLevel;

  bool get hasArtifact {
    final a = artifactType;
    return a != null &&
        a.isNotEmpty &&
        ArtifactType.normalize(a) != ArtifactType.undecided;
  }

  bool get canProceedFromArtifact {
    if (!hasArtifact) return false;
    final artifact = ArtifactType.normalize(artifactType!);
    if (artifact == ArtifactType.contents) {
      return contentSubtype != null &&
          contentSubtype!.isNotEmpty &&
          ContentSubtype.normalize(contentSubtype!) != ContentSubtype.undecided;
    }
    if (artifact == ArtifactType.site || artifact == ArtifactType.promoSite) {
      return SiteSubtypeContract.isKnown(siteSubtype);
    }
    return true;
  }

  bool get canProceedFromAudience =>
      selectedAudiences.isNotEmpty || customAudience.trim().isNotEmpty;

  bool get canProceedFromTopics =>
      selectedConceptIds.isNotEmpty ||
      selectedTopicIds.isNotEmpty ||
      userAddedConcepts.isNotEmpty ||
      designMemo.trim().isNotEmpty;

  bool get canCreateInstruction {
    if (!(hasArtifact &&
        canProceedFromAudience &&
        topic.trim().isNotEmpty &&
        customerProblem.trim().isNotEmpty &&
        targetCustomer.trim().isNotEmpty &&
        desiredOutcome.trim().isNotEmpty &&
        planningConfirmed)) {
      return false;
    }
    if (creationMode == 'revise_existing') {
      if (sourceInstructionId.trim().isEmpty ||
          sourceRevision.trim().isEmpty ||
          requestedChanges.isEmpty) {
        return false;
      }
    }
    if (reasonsToPay.isEmpty && uniqueValue.trim().isEmpty) {
      // Allow create attempt — builder/preflight will surface missing commercial
      // fields; marketability alone must not hard-block draft save elsewhere.
    }
    return true;
  }

  bool get canSendAfterLocalValidate =>
      commercialLocalValidated &&
      (studioPipelinePhase == StudioPipelinePhase.locallyValidated ||
          studioPipelinePhase == StudioPipelinePhase.readyToSend);

  bool get hasWizardProgress =>
      hasArtifact ||
      selectedAudiences.isNotEmpty ||
      customAudience.trim().isNotEmpty ||
      selectedConceptIds.isNotEmpty ||
      selectedTopicIds.isNotEmpty ||
      userAddedConcepts.isNotEmpty ||
      designMemo.trim().isNotEmpty ||
      topic.trim().isNotEmpty ||
      customerProblem.trim().isNotEmpty ||
      desiredOutcome.trim().isNotEmpty ||
      planningConfirmed;

  ProjectDesignState copy() => ProjectDesignState(
    step: step,
    wizardSessionId: wizardSessionId,
    artifactType: artifactType,
    contentSubtype: contentSubtype,
    siteSubtype: siteSubtype,
    selectedAudiences: List<String>.from(selectedAudiences),
    customAudience: customAudience,
    selectedTopicIds: List<String>.from(selectedTopicIds),
    selectedConceptIds: List<String>.from(selectedConceptIds),
    userAddedConcepts: List<ConceptCandidate>.from(userAddedConcepts),
    designMemo: designMemo,
    productionSelections: {
      for (final e in productionSelections.entries)
        e.key: List<String>.from(e.value),
    },
    topic: topic,
    customerProblem: customerProblem,
    targetCustomer: targetCustomer,
    desiredOutcome: desiredOutcome,
    topicStatus: topicStatus,
    problemStatus: problemStatus,
    outcomeStatus: outcomeStatus,
    customerStatus: customerStatus,
    planningConfirmed: planningConfirmed,
    combinedDirection: combinedDirection,
    creationMode: creationMode,
    manualOnlyMode: manualOnlyMode,
    displayTitle: displayTitle,
    workingTitle: workingTitle,
    suggestedTitles: List<String>.from(suggestedTitles),
    titleSource: titleSource,
    originalUserBrief: originalUserBrief,
    originalUserBriefConfirmed: originalUserBriefConfirmed,
    aiAugmentedBrief: aiAugmentedBrief,
    aiAssumptions: List<String>.from(aiAssumptions),
    unansweredQuestions: List<String>.from(unansweredQuestions),
    acceptedAiSuggestions: List<String>.from(acceptedAiSuggestions),
    rejectedAiSuggestions: List<String>.from(rejectedAiSuggestions),
    reasonsToPay: List<String>.from(reasonsToPay),
    uniqueValue: uniqueValue,
    sourceInstructionId: sourceInstructionId,
    sourceRevision: sourceRevision,
    requestedRevision: requestedRevision,
    ownerReviewDecisionRef: ownerReviewDecisionRef,
    preservedArtifactHashes: List<String>.from(preservedArtifactHashes),
    requestedChanges: List<String>.from(requestedChanges),
    userConfirmedAt: userConfirmedAt,
    studioPipelinePhase: studioPipelinePhase,
    commercialLocalValidated: commercialLocalValidated,
    useEnvironment: useEnvironment,
    mainPainPoint: mainPainPoint,
    digitalSkillLevel: digitalSkillLevel,
  );

  /// 기존 마법사/저장 파이프라인과 호환되는 상태로 변환.
  PlanningWizardState toWizardState() {
    final answers = <String, List<String>>{
      'targetCustomer': _audienceLabelsForAnswers(),
      'designTopics': List<String>.from(selectedTopicIds),
      'designConcepts': List<String>.from(selectedConceptIds),
      for (final e in productionSelections.entries)
        'prod_${e.key}': List<String>.from(e.value),
      if (reasonsToPay.isNotEmpty)
        'reasonsToPay': List<String>.from(reasonsToPay),
      if (acceptedAiSuggestions.isNotEmpty)
        'acceptedAiSuggestions': List<String>.from(acceptedAiSuggestions),
      if (rejectedAiSuggestions.isNotEmpty)
        'rejectedAiSuggestions': List<String>.from(rejectedAiSuggestions),
      if (aiAssumptions.isNotEmpty)
        'aiAssumptions': List<String>.from(aiAssumptions),
      if (unansweredQuestions.isNotEmpty)
        'unansweredQuestions': List<String>.from(unansweredQuestions),
      if (requestedChanges.isNotEmpty)
        'requestedChanges': List<String>.from(requestedChanges),
      if (preservedArtifactHashes.isNotEmpty)
        'preservedArtifactHashes': List<String>.from(preservedArtifactHashes),
      if (suggestedTitles.isNotEmpty)
        'suggestedTitles': List<String>.from(suggestedTitles),
    };
    if (customAudience.trim().isNotEmpty) {
      answers['customAudience'] = [customAudience.trim()];
    }
    return PlanningWizardState(
      mode: 'quick',
      step: step,
      artifactType: artifactType,
      contentSubtype: contentSubtype,
      artifactAnswers: answers,
      topic: topic,
      customerProblem: customerProblem,
      targetCustomer: targetCustomer,
      desiredOutcome: desiredOutcome,
      customTexts: {
        if (designMemo.trim().isNotEmpty) 'designMemo': designMemo.trim(),
        'topicStatus': topicStatus.name,
        'problemStatus': problemStatus.name,
        'outcomeStatus': outcomeStatus.name,
        'customerStatus': customerStatus.name,
        'planningConfirmed': planningConfirmed ? 'true' : 'false',
        'designStep': '$step',
        'wizardSessionId': wizardSessionId,
        if (combinedDirection.trim().isNotEmpty)
          'combinedDirection': combinedDirection.trim(),
        if (userAddedConcepts.isNotEmpty)
          'userAddedConceptsJson':
              '[${userAddedConcepts.map((c) => '"${c.id}"').join(',')}]',
        'creationMode': creationMode,
        'manualOnlyMode': manualOnlyMode ? 'true' : 'false',
        'displayTitle': displayTitle,
        'workingTitle': workingTitle,
        'titleSource': titleSource,
        'originalUserBrief': originalUserBrief,
        'originalUserBriefConfirmed': originalUserBriefConfirmed
            ? 'true'
            : 'false',
        'aiAugmentedBrief': aiAugmentedBrief,
        'uniqueValue': uniqueValue,
        'sourceInstructionId': sourceInstructionId,
        'sourceRevision': sourceRevision,
        'requestedRevision': requestedRevision,
        'ownerReviewDecisionRef': ownerReviewDecisionRef,
        'userConfirmedAt': userConfirmedAt,
        'studioPipelinePhase': studioPipelinePhase,
        'commercialLocalValidated': commercialLocalValidated ? 'true' : 'false',
        'useEnvironment': useEnvironment,
        'mainPainPoint': mainPainPoint,
        'digitalSkillLevel': digitalSkillLevel,
        if ((siteSubtype ?? '').trim().isNotEmpty)
          'siteSubtype': siteSubtype!.trim(),
      },
    );
  }

  List<String> _audienceLabelsForAnswers() {
    return List<String>.from(selectedAudiences);
  }

  factory ProjectDesignState.fromWizardState(PlanningWizardState w) {
    final answers = w.artifactAnswers;
    final audiences = List<String>.from(
      answers['targetCustomer'] ?? answers['_legacy_audiences'] ?? const [],
    );
    final topics = List<String>.from(answers['designTopics'] ?? const []);
    final concepts = List<String>.from(answers['designConcepts'] ?? topics);
    final production = <String, List<String>>{};
    for (final e in answers.entries) {
      if (e.key.startsWith('prod_')) {
        production[e.key.substring(5)] = List<String>.from(e.value);
      }
    }
    final custom =
        (answers['customAudience']?.firstOrNull ??
                w.customTexts['customAudience'] ??
                '')
            .trim();
    final memo = (w.customTexts['designMemo'] ?? w.customTexts['notes'] ?? '')
        .trim();

    // Legacy: revision_requested drafts → revise_existing
    var creationMode = w.customTexts['creationMode'] ?? '';
    if (creationMode.isEmpty) {
      final legacy =
          (w.customTexts['revisionMode'] ?? w.customTexts['status'] ?? '')
              .toLowerCase();
      if (legacy.contains('revision') || legacy == 'revision_requested') {
        creationMode = 'revise_existing';
      } else {
        creationMode = 'new_product';
      }
    }

    final restoredStep = int.tryParse(w.customTexts['designStep'] ?? '');
    return ProjectDesignState(
      step: (restoredStep ?? ProjectDesignStep.artifact).clamp(
        0,
        ProjectDesignStep.count - 1,
      ),
      wizardSessionId: w.customTexts['wizardSessionId'],
      artifactType: w.artifactType,
      contentSubtype: w.contentSubtype,
      siteSubtype: () {
        final fromText = (w.customTexts['siteSubtype'] ?? '').trim();
        if (fromText.isNotEmpty) return fromText;
        final fromProd = production['site_kind'] ?? production['siteKind'];
        if (fromProd != null && fromProd.isNotEmpty) return fromProd.first;
        return null;
      }(),
      selectedAudiences: audiences,
      customAudience: custom,
      selectedTopicIds: topics,
      selectedConceptIds: concepts,
      designMemo: memo,
      productionSelections: production,
      topic: w.topic,
      customerProblem: w.customerProblem,
      targetCustomer: w.targetCustomer,
      desiredOutcome: w.desiredOutcome,
      topicStatus: DesignFieldStatusX.parse(w.customTexts['topicStatus'] ?? ''),
      problemStatus: DesignFieldStatusX.parse(
        w.customTexts['problemStatus'] ?? '',
      ),
      outcomeStatus: DesignFieldStatusX.parse(
        w.customTexts['outcomeStatus'] ?? '',
      ),
      customerStatus: DesignFieldStatusX.parse(
        w.customTexts['customerStatus'] ?? '',
      ),
      planningConfirmed: w.customTexts['planningConfirmed'] == 'true',
      combinedDirection: w.customTexts['combinedDirection'] ?? '',
      creationMode: creationMode,
      manualOnlyMode: w.customTexts['manualOnlyMode'] == 'true',
      displayTitle: w.customTexts['displayTitle'] ?? '',
      workingTitle: w.customTexts['workingTitle'] ?? '',
      suggestedTitles: List<String>.from(
        answers['suggestedTitles'] ?? const [],
      ),
      titleSource: w.customTexts['titleSource'] ?? '',
      originalUserBrief: w.customTexts['originalUserBrief'] ?? '',
      originalUserBriefConfirmed:
          w.customTexts['originalUserBriefConfirmed'] == 'true',
      aiAugmentedBrief: w.customTexts['aiAugmentedBrief'] ?? '',
      aiAssumptions: List<String>.from(answers['aiAssumptions'] ?? const []),
      unansweredQuestions: List<String>.from(
        answers['unansweredQuestions'] ?? const [],
      ),
      acceptedAiSuggestions: List<String>.from(
        answers['acceptedAiSuggestions'] ?? const [],
      ),
      rejectedAiSuggestions: List<String>.from(
        answers['rejectedAiSuggestions'] ?? const [],
      ),
      reasonsToPay: List<String>.from(answers['reasonsToPay'] ?? const []),
      uniqueValue: w.customTexts['uniqueValue'] ?? '',
      sourceInstructionId: w.customTexts['sourceInstructionId'] ?? '',
      sourceRevision: w.customTexts['sourceRevision'] ?? '',
      requestedRevision: w.customTexts['requestedRevision'] ?? '',
      ownerReviewDecisionRef: w.customTexts['ownerReviewDecisionRef'] ?? '',
      preservedArtifactHashes: List<String>.from(
        answers['preservedArtifactHashes'] ?? const [],
      ),
      requestedChanges: List<String>.from(
        answers['requestedChanges'] ?? const [],
      ),
      userConfirmedAt: w.customTexts['userConfirmedAt'] ?? '',
      studioPipelinePhase:
          w.customTexts['studioPipelinePhase'] ?? StudioPipelinePhase.drafting,
      commercialLocalValidated:
          w.customTexts['commercialLocalValidated'] == 'true',
      useEnvironment: w.customTexts['useEnvironment'] ?? '',
      mainPainPoint: w.customTexts['mainPainPoint'] ?? '',
      digitalSkillLevel: w.customTexts['digitalSkillLevel'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'step': step,
    'wizardSessionId': wizardSessionId,
    'artifactType': artifactType,
    'contentSubtype': contentSubtype,
    'siteSubtype': siteSubtype,
    'selectedAudiences': selectedAudiences,
    'customAudience': customAudience,
    'selectedTopicIds': selectedTopicIds,
    'selectedConceptIds': selectedConceptIds,
    'userAddedConcepts': userAddedConcepts.map((e) => e.toJson()).toList(),
    'designMemo': designMemo,
    'productionSelections': productionSelections,
    'topic': topic,
    'customerProblem': customerProblem,
    'targetCustomer': targetCustomer,
    'desiredOutcome': desiredOutcome,
    'topicStatus': topicStatus.name,
    'problemStatus': problemStatus.name,
    'outcomeStatus': outcomeStatus.name,
    'customerStatus': customerStatus.name,
    'planningConfirmed': planningConfirmed,
    'combinedDirection': combinedDirection,
    'creationMode': creationMode,
    'manualOnlyMode': manualOnlyMode,
    'displayTitle': displayTitle,
    'workingTitle': workingTitle,
    'suggestedTitles': suggestedTitles,
    'titleSource': titleSource,
    'originalUserBrief': originalUserBrief,
    'originalUserBriefConfirmed': originalUserBriefConfirmed,
    'aiAugmentedBrief': aiAugmentedBrief,
    'aiAssumptions': aiAssumptions,
    'unansweredQuestions': unansweredQuestions,
    'acceptedAiSuggestions': acceptedAiSuggestions,
    'rejectedAiSuggestions': rejectedAiSuggestions,
    'reasonsToPay': reasonsToPay,
    'uniqueValue': uniqueValue,
    'sourceInstructionId': sourceInstructionId,
    'sourceRevision': sourceRevision,
    'requestedRevision': requestedRevision,
    'ownerReviewDecisionRef': ownerReviewDecisionRef,
    'preservedArtifactHashes': preservedArtifactHashes,
    'requestedChanges': requestedChanges,
    'userConfirmedAt': userConfirmedAt,
    'studioPipelinePhase': studioPipelinePhase,
    'commercialLocalValidated': commercialLocalValidated,
    'useEnvironment': useEnvironment,
    'mainPainPoint': mainPainPoint,
    'digitalSkillLevel': digitalSkillLevel,
  };

  factory ProjectDesignState.fromJson(Map<String, dynamic> json) {
    final prodRaw = json['productionSelections'];
    final prod = <String, List<String>>{};
    if (prodRaw is Map) {
      for (final e in prodRaw.entries) {
        final v = e.value;
        if (v is List) {
          prod['${e.key}'] = v.map((x) => '$x').toList();
        }
      }
    }
    final userRaw = json['userAddedConcepts'];
    final userAdded = <ConceptCandidate>[];
    if (userRaw is List) {
      for (final e in userRaw) {
        if (e is Map) {
          userAdded.add(
            ConceptCandidate.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    List<String> strList(String key) =>
        (json[key] as List?)?.map((e) => '$e').toList() ?? const [];

    var creationMode = '${json['creationMode'] ?? ''}';
    if (creationMode.isEmpty) {
      final legacy = '${json['revisionMode'] ?? json['status'] ?? ''}'
          .toLowerCase();
      if (legacy.contains('revision')) {
        creationMode = 'revise_existing';
      } else {
        creationMode = 'new_product';
      }
    }

    return ProjectDesignState(
      step: (json['step'] as num?)?.toInt() ?? 0,
      wizardSessionId: json['wizardSessionId'] == null
          ? null
          : '${json['wizardSessionId']}',
      artifactType: json['artifactType'] == null
          ? null
          : '${json['artifactType']}',
      contentSubtype: json['contentSubtype'] == null
          ? null
          : '${json['contentSubtype']}',
      siteSubtype: () {
        if (json['siteSubtype'] != null &&
            '${json['siteSubtype']}'.trim().isNotEmpty) {
          return '${json['siteSubtype']}'.trim();
        }
        final fromProd = prod['site_kind'] ?? prod['siteKind'];
        if (fromProd != null && fromProd.isNotEmpty) return fromProd.first;
        return null;
      }(),
      selectedAudiences:
          (json['selectedAudiences'] as List?)?.map((e) => '$e').toList() ??
          const [],
      customAudience: '${json['customAudience'] ?? ''}',
      selectedTopicIds:
          (json['selectedTopicIds'] as List?)?.map((e) => '$e').toList() ??
          const [],
      selectedConceptIds:
          (json['selectedConceptIds'] as List?)?.map((e) => '$e').toList() ??
          const [],
      userAddedConcepts: userAdded,
      designMemo: '${json['designMemo'] ?? ''}',
      productionSelections: prod,
      topic: '${json['topic'] ?? ''}',
      customerProblem: '${json['customerProblem'] ?? ''}',
      targetCustomer: '${json['targetCustomer'] ?? ''}',
      desiredOutcome: '${json['desiredOutcome'] ?? ''}',
      topicStatus: DesignFieldStatusX.parse('${json['topicStatus'] ?? ''}'),
      problemStatus: DesignFieldStatusX.parse('${json['problemStatus'] ?? ''}'),
      outcomeStatus: DesignFieldStatusX.parse('${json['outcomeStatus'] ?? ''}'),
      customerStatus: DesignFieldStatusX.parse(
        '${json['customerStatus'] ?? ''}',
      ),
      planningConfirmed: json['planningConfirmed'] == true,
      combinedDirection: '${json['combinedDirection'] ?? ''}',
      creationMode: creationMode,
      manualOnlyMode: json['manualOnlyMode'] == true,
      displayTitle: '${json['displayTitle'] ?? ''}',
      workingTitle: '${json['workingTitle'] ?? ''}',
      suggestedTitles: strList('suggestedTitles'),
      titleSource: '${json['titleSource'] ?? ''}',
      originalUserBrief: '${json['originalUserBrief'] ?? ''}',
      originalUserBriefConfirmed: json['originalUserBriefConfirmed'] == true,
      aiAugmentedBrief: '${json['aiAugmentedBrief'] ?? ''}',
      aiAssumptions: strList('aiAssumptions'),
      unansweredQuestions: strList('unansweredQuestions'),
      acceptedAiSuggestions: strList('acceptedAiSuggestions'),
      rejectedAiSuggestions: strList('rejectedAiSuggestions'),
      reasonsToPay: strList('reasonsToPay'),
      uniqueValue: '${json['uniqueValue'] ?? ''}',
      sourceInstructionId: '${json['sourceInstructionId'] ?? ''}',
      sourceRevision: '${json['sourceRevision'] ?? ''}',
      requestedRevision: '${json['requestedRevision'] ?? ''}',
      ownerReviewDecisionRef: '${json['ownerReviewDecisionRef'] ?? ''}',
      preservedArtifactHashes: strList('preservedArtifactHashes'),
      requestedChanges: strList('requestedChanges'),
      userConfirmedAt: '${json['userConfirmedAt'] ?? ''}',
      studioPipelinePhase:
          '${json['studioPipelinePhase'] ?? StudioPipelinePhase.drafting}',
      commercialLocalValidated: json['commercialLocalValidated'] == true,
      useEnvironment: '${json['useEnvironment'] ?? ''}',
      mainPainPoint: '${json['mainPainPoint'] ?? ''}',
      digitalSkillLevel: '${json['digitalSkillLevel'] ?? ''}',
    );
  }
}
