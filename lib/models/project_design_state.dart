/// Project Design Engine 상태 — PlanningWizardState / BusinessPlanInput과 호환.
library;

import '../models/artifact_type.dart';
import '../models/concept_candidate.dart';
import '../models/planning_wizard_state.dart';

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
    '결과물 선택',
    '대상 고객',
    'AI 추천 컨셉',
    '세부 기획',
    '제작 정보',
    '최종 기획 확인',
    '작업지시서',
  ];

  static const count = 7;
}

class ProjectDesignState {
  ProjectDesignState({
    this.step = ProjectDesignStep.artifact,
    this.artifactType,
    this.contentSubtype,
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
  }) : selectedAudiences = selectedAudiences ?? [],
       selectedTopicIds = selectedTopicIds ?? [],
       selectedConceptIds = selectedConceptIds ?? [],
       userAddedConcepts = userAddedConcepts ?? [],
       productionSelections = productionSelections ?? {};

  int step;
  String? artifactType;
  String? contentSubtype;
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

  bool get hasArtifact {
    final a = artifactType;
    return a != null &&
        a.isNotEmpty &&
        ArtifactType.normalize(a) != ArtifactType.undecided;
  }

  bool get canProceedFromArtifact {
    if (!hasArtifact) return false;
    if (ArtifactType.normalize(artifactType!) == ArtifactType.contents) {
      return contentSubtype != null &&
          contentSubtype!.isNotEmpty &&
          ContentSubtype.normalize(contentSubtype!) != ContentSubtype.undecided;
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

  bool get canCreateInstruction =>
      hasArtifact &&
      canProceedFromAudience &&
      topic.trim().isNotEmpty &&
      customerProblem.trim().isNotEmpty &&
      targetCustomer.trim().isNotEmpty &&
      desiredOutcome.trim().isNotEmpty &&
      planningConfirmed;

  ProjectDesignState copy() => ProjectDesignState(
    step: step,
    artifactType: artifactType,
    contentSubtype: contentSubtype,
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
  );

  /// 기존 마법사/저장 파이프라인과 호환되는 상태로 변환.
  PlanningWizardState toWizardState() {
    final answers = <String, List<String>>{
      'targetCustomer': _audienceLabelsForAnswers(),
      'designTopics': List<String>.from(selectedTopicIds),
      'designConcepts': List<String>.from(selectedConceptIds),
      for (final e in productionSelections.entries)
        'prod_${e.key}': List<String>.from(e.value),
    };
    if (customAudience.trim().isNotEmpty) {
      answers['customAudience'] = [customAudience.trim()];
    }
    return PlanningWizardState(
      mode: 'quick',
      step: 4,
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
        if (combinedDirection.trim().isNotEmpty)
          'combinedDirection': combinedDirection.trim(),
        if (userAddedConcepts.isNotEmpty)
          'userAddedConceptsJson':
              '[${userAddedConcepts.map((c) => '"${c.id}"').join(',')}]',
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

    return ProjectDesignState(
      step: ProjectDesignStep.artifact,
      artifactType: w.artifactType,
      contentSubtype: w.contentSubtype,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'step': step,
    'artifactType': artifactType,
    'contentSubtype': contentSubtype,
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
    return ProjectDesignState(
      step: (json['step'] as num?)?.toInt() ?? 0,
      artifactType: json['artifactType'] == null
          ? null
          : '${json['artifactType']}',
      contentSubtype: json['contentSubtype'] == null
          ? null
          : '${json['contentSubtype']}',
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
    );
  }
}
