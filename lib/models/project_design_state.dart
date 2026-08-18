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
    String? wizardSessionId,
  }) : selectedAudiences = selectedAudiences ?? [],
       selectedTopicIds = selectedTopicIds ?? [],
       selectedConceptIds = selectedConceptIds ?? [],
       userAddedConcepts = userAddedConcepts ?? [],
       productionSelections = productionSelections ?? {},
       wizardSessionId =
           wizardSessionId ??
           'wiz_${DateTime.now().toUtc().millisecondsSinceEpoch}';

  int step;

  /// 새 작업 / 이어하기를 구분하는 세션 id. autosave와 복원 경로를 분리한다.
  String wizardSessionId;
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

    final restoredStep = int.tryParse(w.customTexts['designStep'] ?? '');
    return ProjectDesignState(
      step: (restoredStep ?? ProjectDesignStep.artifact).clamp(
        0,
        ProjectDesignStep.count - 1,
      ),
      wizardSessionId: w.customTexts['wizardSessionId'],
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
    'wizardSessionId': wizardSessionId,
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
      wizardSessionId: json['wizardSessionId'] == null
          ? null
          : '${json['wizardSessionId']}',
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
