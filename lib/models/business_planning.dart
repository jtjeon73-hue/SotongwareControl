/// 사업 기획·작업지시 데이터 모델 (로컬 규칙 기반, 외부 AI API 없음).
library;

class DeliverableType {
  static const app = 'app';
  static const ebook = 'ebook';
  static const youtubeShorts = 'youtube_shorts';
  static const contentMusic = 'content_music';
  static const webMarketing = 'web_marketing';
  static const undecided = 'undecided';

  static const allSelectable = [
    app,
    ebook,
    youtubeShorts,
    contentMusic,
    webMarketing,
  ];

  static String labelKo(String id) {
    switch (id) {
      case app:
        return '앱';
      case ebook:
        return '전자책';
      case youtubeShorts:
        return '유튜브 쇼츠';
      case contentMusic:
        return '콘텐츠·노래';
      case webMarketing:
        return '웹마케팅 사이트';
      case undecided:
        return '아직 결정하지 않음';
      default:
        return id;
    }
  }
}

class PlanningStatus {
  static const idea = 'idea';
  static const analyzing = 'analyzing';
  static const needsRefine = 'needs_refine';
  static const marketValidate = 'market_validate';
  static const instructionReady = 'instruction_ready';
  static const readyToHandoff = 'ready_to_handoff';
  static const archived = 'archived';

  static String labelKo(String id) {
    switch (id) {
      case idea:
        return '아이디어';
      case analyzing:
        return '분석 중';
      case needsRefine:
        return '기획 보완';
      case marketValidate:
        return '시장 검증';
      case instructionReady:
        return '지시서 준비';
      case readyToHandoff:
        return '소통24워크 전달 준비';
      case archived:
        return '보관';
      default:
        return id;
    }
  }
}

class PlanningVerdict {
  static const readyToBuild = 'ready_to_build';
  static const validateFirst = 'validate_first';
  static const needsRefine = 'needs_refine';
  static const hold = 'hold';

  static String labelKo(String id) {
    switch (id) {
      case readyToBuild:
        return '바로 제작 검토';
      case validateFirst:
        return '작은 시장 검증 우선';
      case needsRefine:
        return '기획 보완 필요';
      case hold:
        return '보류 권장';
      default:
        return id;
    }
  }
}

class BusinessPlanInput {
  const BusinessPlanInput({
    this.topic = '',
    this.customerProblem = '',
    this.targetCustomer = '',
    this.desiredOutcome = '',
    this.experienceSkills = '',
    this.existingMaterials = '',
    this.revenueModel = '',
    this.monthlyGoal = '',
    this.expectedDuration = '',
    this.deliverableTypes = const [DeliverableType.undecided],
    this.notes = '',
  });

  final String topic;
  final String customerProblem;
  final String targetCustomer;
  final String desiredOutcome;
  final String experienceSkills;
  final String existingMaterials;
  final String revenueModel;
  final String monthlyGoal;
  final String expectedDuration;
  final List<String> deliverableTypes;
  final String notes;

  bool get hasRequiredFields =>
      topic.trim().isNotEmpty &&
      customerProblem.trim().isNotEmpty &&
      targetCustomer.trim().isNotEmpty &&
      desiredOutcome.trim().isNotEmpty;

  BusinessPlanInput copyWith({
    String? topic,
    String? customerProblem,
    String? targetCustomer,
    String? desiredOutcome,
    String? experienceSkills,
    String? existingMaterials,
    String? revenueModel,
    String? monthlyGoal,
    String? expectedDuration,
    List<String>? deliverableTypes,
    String? notes,
  }) {
    return BusinessPlanInput(
      topic: topic ?? this.topic,
      customerProblem: customerProblem ?? this.customerProblem,
      targetCustomer: targetCustomer ?? this.targetCustomer,
      desiredOutcome: desiredOutcome ?? this.desiredOutcome,
      experienceSkills: experienceSkills ?? this.experienceSkills,
      existingMaterials: existingMaterials ?? this.existingMaterials,
      revenueModel: revenueModel ?? this.revenueModel,
      monthlyGoal: monthlyGoal ?? this.monthlyGoal,
      expectedDuration: expectedDuration ?? this.expectedDuration,
      deliverableTypes: deliverableTypes ?? this.deliverableTypes,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'customerProblem': customerProblem,
    'targetCustomer': targetCustomer,
    'desiredOutcome': desiredOutcome,
    'experienceSkills': experienceSkills,
    'existingMaterials': existingMaterials,
    'revenueModel': revenueModel,
    'monthlyGoal': monthlyGoal,
    'expectedDuration': expectedDuration,
    'deliverableTypes': deliverableTypes,
    'notes': notes,
  };

  factory BusinessPlanInput.fromJson(Map<String, dynamic> json) {
    final types =
        (json['deliverableTypes'] as List?)?.map((e) => '$e').toList() ??
        const [DeliverableType.undecided];
    return BusinessPlanInput(
      topic: '${json['topic'] ?? ''}',
      customerProblem: '${json['customerProblem'] ?? ''}',
      targetCustomer: '${json['targetCustomer'] ?? ''}',
      desiredOutcome: '${json['desiredOutcome'] ?? ''}',
      experienceSkills: '${json['experienceSkills'] ?? ''}',
      existingMaterials: '${json['existingMaterials'] ?? ''}',
      revenueModel: '${json['revenueModel'] ?? ''}',
      monthlyGoal: '${json['monthlyGoal'] ?? ''}',
      expectedDuration: '${json['expectedDuration'] ?? ''}',
      deliverableTypes: types.isEmpty
          ? const [DeliverableType.undecided]
          : types,
      notes: '${json['notes'] ?? ''}',
    );
  }
}

class CriterionScore {
  const CriterionScore({
    required this.id,
    required this.label,
    required this.score,
    required this.rationale,
    required this.missingInfo,
    required this.risks,
    required this.improvement,
  });

  final String id;
  final String label;
  final int score; // 1~5, 정보 부족 시 낮은 점수 유지
  final String rationale;
  final String missingInfo;
  final String risks;
  final String improvement;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'score': score,
    'rationale': rationale,
    'missingInfo': missingInfo,
    'risks': risks,
    'improvement': improvement,
  };

  factory CriterionScore.fromJson(Map<String, dynamic> json) => CriterionScore(
    id: '${json['id'] ?? ''}',
    label: '${json['label'] ?? ''}',
    score: (json['score'] as num?)?.toInt() ?? 1,
    rationale: '${json['rationale'] ?? ''}',
    missingInfo: '${json['missingInfo'] ?? ''}',
    risks: '${json['risks'] ?? ''}',
    improvement: '${json['improvement'] ?? ''}',
  );
}

class DeliverableRecommendation {
  const DeliverableRecommendation({
    required this.type,
    required this.rank,
    required this.reason,
    required this.minimumOutput,
    required this.requiredMaterials,
    required this.workSteps,
    required this.nextExpansion,
    required this.monetizationOptions,
    required this.risks,
  });

  final String type;
  final int rank;
  final String reason;
  final String minimumOutput;
  final String requiredMaterials;
  final String workSteps;
  final String nextExpansion;
  final String monetizationOptions;
  final String risks;

  Map<String, dynamic> toJson() => {
    'type': type,
    'rank': rank,
    'reason': reason,
    'minimumOutput': minimumOutput,
    'requiredMaterials': requiredMaterials,
    'workSteps': workSteps,
    'nextExpansion': nextExpansion,
    'monetizationOptions': monetizationOptions,
    'risks': risks,
  };

  factory DeliverableRecommendation.fromJson(Map<String, dynamic> json) =>
      DeliverableRecommendation(
        type: '${json['type'] ?? ''}',
        rank: (json['rank'] as num?)?.toInt() ?? 99,
        reason: '${json['reason'] ?? ''}',
        minimumOutput: '${json['minimumOutput'] ?? ''}',
        requiredMaterials: '${json['requiredMaterials'] ?? ''}',
        workSteps: '${json['workSteps'] ?? ''}',
        nextExpansion: '${json['nextExpansion'] ?? ''}',
        monetizationOptions: '${json['monetizationOptions'] ?? ''}',
        risks: '${json['risks'] ?? ''}',
      );
}

class WorkflowStep {
  const WorkflowStep({
    required this.order,
    required this.id,
    required this.title,
    required this.applicable,
    required this.completionCriteria,
    this.notes = '',
  });

  final int order;
  final String id;
  final String title;
  final bool applicable;
  final String completionCriteria;
  final String notes;

  Map<String, dynamic> toJson() => {
    'order': order,
    'id': id,
    'title': title,
    'applicable': applicable,
    'statusLabel': applicable ? '적용' : '해당 없음',
    'completionCriteria': completionCriteria,
    'notes': notes,
  };

  factory WorkflowStep.fromJson(Map<String, dynamic> json) => WorkflowStep(
    order: (json['order'] as num?)?.toInt() ?? 0,
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    applicable: json['applicable'] != false,
    completionCriteria: '${json['completionCriteria'] ?? ''}',
    notes: '${json['notes'] ?? ''}',
  );
}

class WorkInstruction {
  const WorkInstruction({
    required this.schemaVersion,
    required this.instructionId,
    required this.projectId,
    required this.instructionVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.businessIdea,
    required this.businessPurpose,
    required this.customerProblem,
    required this.targetCustomer,
    required this.deliverableTypes,
    required this.recommendedSequence,
    required this.valueProposition,
    required this.requiredMaterials,
    required this.workflowSteps,
    required this.completionCriteria,
    required this.qualityChecks,
    required this.risks,
    required this.monetizationOptions,
    required this.deploymentTargets,
    required this.promotionChannels,
    required this.approvalItems,
    required this.executionStatus,
    this.notes = '',
  });

  final String schemaVersion;
  final String instructionId;
  final String projectId;
  final String instructionVersion;
  final String createdAt;
  final String updatedAt;
  final String businessIdea;
  final String businessPurpose;
  final String customerProblem;
  final String targetCustomer;
  final List<String> deliverableTypes;
  final List<String> recommendedSequence;
  final String valueProposition;
  final List<String> requiredMaterials;
  final List<WorkflowStep> workflowSteps;
  final List<String> completionCriteria;
  final List<String> qualityChecks;
  final List<String> risks;
  final List<String> monetizationOptions;
  final List<String> deploymentTargets;
  final List<String> promotionChannels;
  final List<String> approvalItems;
  final String executionStatus;
  final String notes;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'instructionId': instructionId,
    'projectId': projectId,
    'instructionVersion': instructionVersion,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'businessIdea': businessIdea,
    'businessPurpose': businessPurpose,
    'customerProblem': customerProblem,
    'targetCustomer': targetCustomer,
    'deliverableTypes': deliverableTypes,
    'recommendedSequence': recommendedSequence,
    'valueProposition': valueProposition,
    'requiredMaterials': requiredMaterials,
    'workflowSteps': workflowSteps.map((e) => e.toJson()).toList(),
    'completionCriteria': completionCriteria,
    'qualityChecks': qualityChecks,
    'risks': risks,
    'monetizationOptions': monetizationOptions,
    'deploymentTargets': deploymentTargets,
    'promotionChannels': promotionChannels,
    'approvalItems': approvalItems,
    'executionStatus': executionStatus,
    'notes': notes,
  };

  factory WorkInstruction.fromJson(
    Map<String, dynamic> json,
  ) => WorkInstruction(
    schemaVersion: '${json['schemaVersion'] ?? '1.0'}',
    instructionId: '${json['instructionId'] ?? ''}',
    projectId: '${json['projectId'] ?? ''}',
    instructionVersion: '${json['instructionVersion'] ?? '1'}',
    createdAt: '${json['createdAt'] ?? ''}',
    updatedAt: '${json['updatedAt'] ?? ''}',
    businessIdea: '${json['businessIdea'] ?? ''}',
    businessPurpose: '${json['businessPurpose'] ?? ''}',
    customerProblem: '${json['customerProblem'] ?? ''}',
    targetCustomer: '${json['targetCustomer'] ?? ''}',
    deliverableTypes:
        (json['deliverableTypes'] as List?)?.map((e) => '$e').toList() ??
        const [],
    recommendedSequence:
        (json['recommendedSequence'] as List?)?.map((e) => '$e').toList() ??
        const [],
    valueProposition: '${json['valueProposition'] ?? ''}',
    requiredMaterials:
        (json['requiredMaterials'] as List?)?.map((e) => '$e').toList() ??
        const [],
    workflowSteps:
        (json['workflowSteps'] as List?)
            ?.map(
              (e) => WorkflowStep.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
    completionCriteria:
        (json['completionCriteria'] as List?)?.map((e) => '$e').toList() ??
        const [],
    qualityChecks:
        (json['qualityChecks'] as List?)?.map((e) => '$e').toList() ?? const [],
    risks: (json['risks'] as List?)?.map((e) => '$e').toList() ?? const [],
    monetizationOptions:
        (json['monetizationOptions'] as List?)?.map((e) => '$e').toList() ??
        const [],
    deploymentTargets:
        (json['deploymentTargets'] as List?)?.map((e) => '$e').toList() ??
        const [],
    promotionChannels:
        (json['promotionChannels'] as List?)?.map((e) => '$e').toList() ??
        const [],
    approvalItems:
        (json['approvalItems'] as List?)?.map((e) => '$e').toList() ?? const [],
    executionStatus: '${json['executionStatus'] ?? '지시서 준비'}',
    notes: '${json['notes'] ?? ''}',
  );
}

class PlanningAnalysisResult {
  const PlanningAnalysisResult({
    required this.criteria,
    required this.verdict,
    required this.summary,
    required this.recommendations,
    required this.averageScore,
  });

  final List<CriterionScore> criteria;
  final String verdict;
  final String summary;
  final List<DeliverableRecommendation> recommendations;
  final double averageScore;

  Map<String, dynamic> toJson() => {
    'criteria': criteria.map((e) => e.toJson()).toList(),
    'verdict': verdict,
    'summary': summary,
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
    'averageScore': averageScore,
  };

  factory PlanningAnalysisResult.fromJson(Map<String, dynamic> json) =>
      PlanningAnalysisResult(
        criteria:
            (json['criteria'] as List?)
                ?.map(
                  (e) => CriterionScore.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            const [],
        verdict: '${json['verdict'] ?? PlanningVerdict.needsRefine}',
        summary: '${json['summary'] ?? ''}',
        recommendations:
            (json['recommendations'] as List?)
                ?.map(
                  (e) => DeliverableRecommendation.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            const [],
        averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0,
      );
}

class BusinessPlanDocument {
  const BusinessPlanDocument({
    required this.id,
    required this.input,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.analysis,
    this.instruction,
  });

  final String id;
  final BusinessPlanInput input;
  final String status;
  final String createdAt;
  final String updatedAt;
  final PlanningAnalysisResult? analysis;
  final WorkInstruction? instruction;

  bool get hasInstruction => instruction != null;

  BusinessPlanDocument copyWith({
    BusinessPlanInput? input,
    String? status,
    String? updatedAt,
    PlanningAnalysisResult? analysis,
    WorkInstruction? instruction,
    bool clearInstruction = false,
  }) {
    return BusinessPlanDocument(
      id: id,
      input: input ?? this.input,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      analysis: analysis ?? this.analysis,
      instruction: clearInstruction ? null : (instruction ?? this.instruction),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'input': input.toJson(),
    'status': status,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (analysis != null) 'analysis': analysis!.toJson(),
    if (instruction != null) 'instruction': instruction!.toJson(),
  };

  factory BusinessPlanDocument.fromJson(Map<String, dynamic> json) =>
      BusinessPlanDocument(
        id: '${json['id'] ?? ''}',
        input: BusinessPlanInput.fromJson(
          Map<String, dynamic>.from(json['input'] as Map? ?? {}),
        ),
        status: '${json['status'] ?? PlanningStatus.idea}',
        createdAt: '${json['createdAt'] ?? ''}',
        updatedAt: '${json['updatedAt'] ?? ''}',
        analysis: json['analysis'] == null
            ? null
            : PlanningAnalysisResult.fromJson(
                Map<String, dynamic>.from(json['analysis'] as Map),
              ),
        instruction: json['instruction'] == null
            ? null
            : WorkInstruction.fromJson(
                Map<String, dynamic>.from(json['instruction'] as Map),
              ),
      );
}
