/// 사업 기획·작업지시 데이터 모델 (로컬 규칙 기반, 외부 AI API 없음).
library;

import 'artifact_type.dart';
import 'commercial/commercial_quality_attachment.dart';
import 'instruction_contract.dart';

export 'artifact_type.dart';
export 'instruction_contract.dart';

class DeliverableType {
  static const app = 'app';
  static const ebook = 'ebook';
  static const youtubeShorts = 'youtube_shorts';
  static const youtubeVideo = 'youtube_video';
  static const content = 'content';
  static const educationContent = 'education_content';
  static const contentMusic = 'content_music'; // 호환 별칭
  static const musicContent = 'music_content'; // content_music 별칭
  static const webMarketing = 'web_marketing';
  static const industrialAutomation = 'industrial_automation';
  static const undecided = 'undecided';

  static const allSelectable = [
    ebook,
    app,
    youtubeShorts,
    youtubeVideo,
    webMarketing,
    content,
    educationContent,
    musicContent,
    industrialAutomation,
  ];

  static String labelKo(String id) {
    switch (id) {
      case app:
        return '앱';
      case ebook:
        return '전자책';
      case youtubeShorts:
        return '유튜브 쇼츠';
      case youtubeVideo:
        return '유튜브 일반 영상';
      case content:
        return '콘텐츠';
      case educationContent:
        return '교육 콘텐츠';
      case contentMusic:
      case musicContent:
        return '음악·노래 콘텐츠';
      case webMarketing:
        return '홍보·마케팅 웹사이트';
      case industrialAutomation:
        return '산업자동화 소프트웨어';
      case undecided:
        return '아직 결정하지 않음';
      default:
        return id;
    }
  }

  /// 레거시·별칭 → 주 id 정규화 (JSON·트랙 호환).
  static String normalize(String id) {
    if (id == contentMusic || id == musicContent) return content;
    if (id == educationContent) return content;
    return id;
  }
}

/// 소통24워크 주 작업 트랙.
class WorkTrack {
  static const ebookDev = 'ebook_dev';
  static const appDev = 'app_dev';
  static const youtubeDev = 'youtube_dev';
  static const webMarketingDev = 'web_marketing_dev';
  static const contentDev = 'content_dev';
  static const industrialAutomationDev = 'industrial_automation_dev';

  static String fromDeliverable(String deliverable) {
    switch (deliverable) {
      case DeliverableType.ebook:
        return ebookDev;
      case DeliverableType.app:
        return appDev;
      case DeliverableType.youtubeShorts:
      case DeliverableType.youtubeVideo:
        return youtubeDev;
      case DeliverableType.webMarketing:
        return webMarketingDev;
      case DeliverableType.content:
      case DeliverableType.educationContent:
      case DeliverableType.contentMusic:
      case DeliverableType.musicContent:
        return contentDev;
      case DeliverableType.industrialAutomation:
        return industrialAutomationDev;
      default:
        return ebookDev;
    }
  }

  static String labelKo(String id) {
    switch (id) {
      case ebookDev:
        return '전자책개발';
      case appDev:
        return '앱개발';
      case youtubeDev:
        return '유튜브·쇼츠개발';
      case webMarketingDev:
        return '웹마케팅개발';
      case contentDev:
        return '콘텐츠개발';
      case industrialAutomationDev:
        return '산업자동화SW개발';
      default:
        return id;
    }
  }
}

/// 정규화된 기획·전달 상태 (기존 값과 호환 매핑 제공).
class PlanningStatus {
  static const draft = 'draft';
  static const instructionReady = 'instruction_ready';
  static const validationRequired = 'validation_required';
  static const readyToTransfer = 'ready_to_transfer';
  static const downloadedPendingImport = 'downloaded_pending_import';
  static const transferred = 'transferred';
  static const transferFailed = 'transfer_failed';
  static const imported = 'imported';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const archived = 'archived';
  static const trashed = 'trashed';

  // 레거시 상수 (읽기 호환)
  static const idea = 'idea';
  static const analyzing = 'analyzing';
  static const needsRefine = 'needs_refine';
  static const marketValidate = 'market_validate';
  static const readyToHandoff = 'ready_to_handoff';

  static String normalize(String raw) {
    switch (raw) {
      case idea:
      case analyzing:
      case needsRefine:
      case marketValidate:
      case draft:
        return draft;
      case instructionReady:
        return instructionReady;
      case validationRequired:
        return validationRequired;
      case readyToHandoff:
      case readyToTransfer:
        return readyToTransfer;
      case downloadedPendingImport:
        return downloadedPendingImport;
      case transferred:
        return transferred;
      case transferFailed:
        return transferFailed;
      case imported:
        return imported;
      case inProgress:
        return inProgress;
      case completed:
        return completed;
      case archived:
        return archived;
      case trashed:
        return trashed;
      default:
        return draft;
    }
  }

  static String labelKo(String id) {
    switch (normalize(id)) {
      case draft:
        return '작성 중';
      case instructionReady:
        return '지시서 준비';
      case validationRequired:
        return '검증 필요';
      case readyToTransfer:
        return '24워크 전달 대기';
      case downloadedPendingImport:
        return 'JSON 다운로드 완료 · 수동 가져오기 대기';
      case transferred:
        return '소통24워크 Agent 전달 완료';
      case transferFailed:
        return '전송 실패 · 다시 시도 필요';
      case imported:
        return '소통24워크 Agent 가져오기 완료';
      case inProgress:
        return '작업 진행';
      case completed:
        return '완료';
      case archived:
        return '보관';
      case trashed:
        return '휴지통';
      default:
        return id;
    }
  }

  static const filterTabs = [
    'all',
    draft,
    instructionReady,
    validationRequired,
    readyToTransfer,
    transferred,
    inProgress,
    completed,
    archived,
  ];

  static String filterLabel(String id) {
    if (id == 'all') return '전체';
    return labelKo(id);
  }
}

/// 기획 라이브러리 수명주기 — 워크플로 status와 분리.
class PlanLibraryState {
  static const active = 'active';
  static const archived = 'archived';
  static const trashed = 'trashed';

  static String normalize(String raw) {
    switch (raw) {
      case archived:
      case 'archive':
        return archived;
      case trashed:
      case 'trash':
        return trashed;
      case active:
      case '':
        return active;
      default:
        return active;
    }
  }

  static String labelKo(String id) {
    switch (normalize(id)) {
      case archived:
        return '보관';
      case trashed:
        return '휴지통';
      default:
        return '활성';
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
    this.expectedScale = '',
    this.budgetEstimate = '',
    this.salesPrice = '',
    this.references = '',
    this.constraints = '',
    this.extraRequests = '',
    this.wizardSelections,
    this.sentencesManuallyEdited = false,
    this.artifactType = '',
    this.contentSubtype = '',
    this.artifactAnswers = const {},
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
  final String expectedScale;
  final String budgetEstimate;
  final String salesPrice;
  final String references;
  final String constraints;
  final String extraRequests;

  /// 선택형 기획 도우미 원본 (`PlanningWizardState.toJson`).
  final Map<String, dynamic>? wizardSelections;
  final bool sentencesManuallyEdited;
  final String artifactType;
  final String contentSubtype;
  final Map<String, List<String>> artifactAnswers;

  List<String> get missingRequiredLabels {
    final missing = <String>[];
    final artifact = artifactType.trim().isNotEmpty
        ? ArtifactType.normalize(artifactType)
        : (deliverableTypes.isNotEmpty
              ? ArtifactType.normalize(deliverableTypes.first)
              : ArtifactType.undecided);
    if (artifact == ArtifactType.undecided || artifact.isEmpty) {
      missing.add('제작 형태');
    }
    if (artifact == ArtifactType.contents) {
      final sub = ContentSubtype.normalize(
        contentSubtype.isEmpty ? ContentSubtype.undecided : contentSubtype,
      );
      if (sub == ContentSubtype.undecided) {
        missing.add('콘텐츠 하위 유형');
      }
    }
    if (topic.trim().isEmpty) missing.add('사업 주제');
    if (customerProblem.trim().isEmpty) missing.add('고객 문제');
    if (targetCustomer.trim().isEmpty) missing.add('대상 고객');
    if (desiredOutcome.trim().isEmpty) missing.add('원하는 결과');
    return missing;
  }

  bool get hasRequiredFields => missingRequiredLabels.isEmpty;

  String get resolvedArtifactType {
    if (artifactType.trim().isNotEmpty) {
      return ArtifactType.normalize(artifactType);
    }
    if (deliverableTypes.isNotEmpty) {
      return ArtifactType.normalize(deliverableTypes.first);
    }
    return ArtifactType.undecided;
  }

  List<String> get normalizedDeliverables => deliverableTypes
      .map(DeliverableType.normalize)
      .where((t) => t != DeliverableType.undecided)
      .toList();

  String get primaryDeliverable => normalizedDeliverables.isEmpty
      ? (resolvedArtifactType == ArtifactType.undecided
            ? DeliverableType.ebook
            : resolvedArtifactType)
      : normalizedDeliverables.first;

  String get primaryTrack => ArtifactType.primaryTrackId(resolvedArtifactType);

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
    String? expectedScale,
    String? budgetEstimate,
    String? salesPrice,
    String? references,
    String? constraints,
    String? extraRequests,
    Map<String, dynamic>? wizardSelections,
    bool? sentencesManuallyEdited,
    bool clearWizardSelections = false,
    String? artifactType,
    String? contentSubtype,
    Map<String, List<String>>? artifactAnswers,
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
      expectedScale: expectedScale ?? this.expectedScale,
      budgetEstimate: budgetEstimate ?? this.budgetEstimate,
      salesPrice: salesPrice ?? this.salesPrice,
      references: references ?? this.references,
      constraints: constraints ?? this.constraints,
      extraRequests: extraRequests ?? this.extraRequests,
      wizardSelections: clearWizardSelections
          ? null
          : (wizardSelections ?? this.wizardSelections),
      sentencesManuallyEdited:
          sentencesManuallyEdited ?? this.sentencesManuallyEdited,
      artifactType: artifactType ?? this.artifactType,
      contentSubtype: contentSubtype ?? this.contentSubtype,
      artifactAnswers: artifactAnswers ?? this.artifactAnswers,
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
    'deliverableTypes': deliverableTypes
        .map(DeliverableType.normalize)
        .toList(),
    'notes': notes,
    'expectedScale': expectedScale,
    'budgetEstimate': budgetEstimate,
    'salesPrice': salesPrice,
    'references': references,
    'constraints': constraints,
    'extraRequests': extraRequests,
    if (wizardSelections != null) 'wizardSelections': wizardSelections,
    if (sentencesManuallyEdited) 'sentencesManuallyEdited': true,
    if (artifactType.isNotEmpty) 'artifactType': artifactType,
    if (contentSubtype.isNotEmpty) 'contentSubtype': contentSubtype,
    if (artifactAnswers.isNotEmpty)
      'artifactAnswers': artifactAnswers.map((k, v) => MapEntry(k, v)),
  };

  factory BusinessPlanInput.fromJson(Map<String, dynamic> json) {
    final types =
        (json['deliverableTypes'] as List?)?.map((e) => '$e').toList() ??
        const [DeliverableType.undecided];
    final answersRaw = json['artifactAnswers'];
    final answers = <String, List<String>>{};
    if (answersRaw is Map) {
      for (final e in answersRaw.entries) {
        final v = e.value;
        if (v is List) {
          answers['${e.key}'] = v.map((x) => '$x').toList();
        }
      }
    }
    final artifactRaw = '${json['artifactType'] ?? ''}';
    final resolvedArtifact = artifactRaw.isNotEmpty
        ? ArtifactType.normalize(artifactRaw)
        : (types.isNotEmpty
              ? ArtifactType.normalize(types.first)
              : ArtifactType.undecided);
    final subtypeRaw = '${json['contentSubtype'] ?? ''}';
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
          : types.map(DeliverableType.normalize).toList(),
      notes: '${json['notes'] ?? ''}',
      expectedScale: '${json['expectedScale'] ?? ''}',
      budgetEstimate: '${json['budgetEstimate'] ?? ''}',
      salesPrice: '${json['salesPrice'] ?? ''}',
      references: '${json['references'] ?? ''}',
      constraints: '${json['constraints'] ?? ''}',
      extraRequests: '${json['extraRequests'] ?? ''}',
      wizardSelections: json['wizardSelections'] == null
          ? null
          : Map<String, dynamic>.from(json['wizardSelections'] as Map),
      sentencesManuallyEdited: json['sentencesManuallyEdited'] == true,
      artifactType: resolvedArtifact,
      contentSubtype: subtypeRaw.isEmpty
          ? ''
          : ContentSubtype.normalize(subtypeRaw),
      artifactAnswers: answers,
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
  final int score;
  final String rationale;
  final String missingInfo;
  final String risks;
  final String improvement;

  CriterionScore copyWith({
    String? id,
    String? label,
    int? score,
    String? rationale,
    String? missingInfo,
    String? risks,
    String? improvement,
  }) {
    return CriterionScore(
      id: id ?? this.id,
      label: label ?? this.label,
      score: score ?? this.score,
      rationale: rationale ?? this.rationale,
      missingInfo: missingInfo ?? this.missingInfo,
      risks: risks ?? this.risks,
      improvement: improvement ?? this.improvement,
    );
  }

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
        type: DeliverableType.normalize('${json['type'] ?? ''}'),
        rank: (json['rank'] as num?)?.toInt() ?? 0,
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

/// Production AI 실행 정책 (opt-in). 없으면 Agent는 자동 Codex를 돌리지 않음.
/// Sotong24Work `AiExecution::Policy` 와 필드 일치.
class AiExecutionPolicy {
  const AiExecutionPolicy({
    required this.enabled,
    required this.worker,
    required this.maxAutoStageOrder,
    required this.approvalRequired,
    required this.artifactUploadEnabled,
    required this.autoAdvance,
    required this.deploymentAllowed,
    this.approvalMode = 'manual',
    this.executionMode = 'hold',
  });

  /// ④ pilot 고정값 — 1단계 Cursor + 승인 게이트, 자동 배포 금지.
  static const AiExecutionPolicy pilotCodexStage1 = AiExecutionPolicy(
    enabled: true,
    worker: 'cursor',
    maxAutoStageOrder: 1,
    approvalRequired: true,
    artifactUploadEnabled: true,
    autoAdvance: false,
    deploymentAllowed: false,
    approvalMode: 'manual',
    executionMode: 'hold',
  );

  factory AiExecutionPolicy.productionEbook({String approvalMode = 'manual'}) {
    final mode = approvalMode == 'auto' ? 'auto' : 'manual';
    return AiExecutionPolicy(
      enabled: true,
      worker: 'cursor',
      maxAutoStageOrder: 12,
      approvalRequired: mode == 'manual',
      artifactUploadEnabled: true,
      autoAdvance: mode == 'auto',
      deploymentAllowed: false,
      approvalMode: mode,
      executionMode: mode == 'auto' ? 'continuous' : 'hold',
    );
  }

  /// App 18-stage production AI policy. approvalMode is the source of truth.
  factory AiExecutionPolicy.productionApp({String approvalMode = 'manual'}) {
    final mode = approvalMode == 'auto' ? 'auto' : 'manual';
    return AiExecutionPolicy(
      enabled: true,
      worker: 'cursor',
      maxAutoStageOrder: 18,
      approvalRequired: mode == 'manual',
      artifactUploadEnabled: true,
      autoAdvance: mode == 'auto',
      deploymentAllowed: false,
      approvalMode: mode,
      executionMode: mode == 'auto' ? 'continuous' : 'hold',
    );
  }

  /// Site / promo_site — ebook 18단계 템플릿 기반 (백엔드 canonical 제한 가능).
  factory AiExecutionPolicy.productionSite({String approvalMode = 'manual'}) {
    return AiExecutionPolicy.productionApp(approvalMode: approvalMode);
  }

  /// Contents — ebook 18단계 템플릿 기반 (subtype별 applicable 단계).
  factory AiExecutionPolicy.productionContents({
    String approvalMode = 'manual',
  }) {
    return AiExecutionPolicy.productionApp(approvalMode: approvalMode);
  }

  final bool enabled;
  final String worker;
  final int maxAutoStageOrder;
  final bool approvalRequired;
  final bool artifactUploadEnabled;
  final bool autoAdvance;
  final bool deploymentAllowed;
  final String approvalMode;
  final String executionMode;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'worker': worker,
    'maxAutoStageOrder': maxAutoStageOrder,
    'approvalRequired': approvalRequired,
    'artifactUploadEnabled': artifactUploadEnabled,
    'autoAdvance': autoAdvance,
    'deploymentAllowed': deploymentAllowed,
    'approvalMode': approvalMode,
    'executionMode': executionMode,
  };

  factory AiExecutionPolicy.fromJson(Map<String, dynamic> json) {
    final approvalMode =
        '${json['approvalMode'] ?? ''}' == 'auto' ||
            (!json.containsKey('approvalMode') &&
                json['approvalRequired'] == false)
        ? 'auto'
        : 'manual';
    final rawExecutionMode = '${json['executionMode'] ?? ''}'.trim();
    final executionMode = switch (rawExecutionMode) {
      'continuous' => 'continuous',
      'hold' || 'single' || 'single_step' => 'hold',
      _ when approvalMode == 'auto' && json['autoAdvance'] == true =>
        'continuous',
      _ => 'hold',
    };
    return AiExecutionPolicy(
      enabled: json['enabled'] == true,
      worker: '${json['worker'] ?? 'none'}'.trim().isEmpty
          ? 'none'
          : '${json['worker']}'.trim(),
      maxAutoStageOrder: () {
        final v = json['maxAutoStageOrder'];
        if (v is int) return v;
        return int.tryParse('$v') ?? 0;
      }(),
      approvalRequired: json['approvalRequired'] != false,
      artifactUploadEnabled: json['artifactUploadEnabled'] == true,
      autoAdvance: json['autoAdvance'] == true,
      deploymentAllowed: json['deploymentAllowed'] == true,
      approvalMode: approvalMode,
      executionMode: executionMode,
    );
  }

  /// `aiExecution` (canonical) 또는 `executionPolicy` (alias) 파싱.
  static AiExecutionPolicy? tryParse(Map<String, dynamic> instructionJson) {
    final raw =
        instructionJson['aiExecution'] ?? instructionJson['executionPolicy'];
    if (raw is! Map) return null;
    return AiExecutionPolicy.fromJson(Map<String, dynamic>.from(raw));
  }

  AiExecutionPolicy withWorkerPreference(String preference) {
    return AiExecutionPolicy(
      enabled: enabled,
      worker: 'cursor',
      maxAutoStageOrder: maxAutoStageOrder,
      approvalRequired: approvalRequired,
      artifactUploadEnabled: artifactUploadEnabled,
      autoAdvance: autoAdvance,
      deploymentAllowed: deploymentAllowed,
      approvalMode: approvalMode,
      executionMode: executionMode,
    );
  }
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
    this.primaryTrack = '',
    this.followUpTracks = const [],
    this.artifactType = '',
    this.contentSubtype = '',
    this.checksum = '',
    this.sourceFileName = '',
    this.status = '',
    this.contract,
    this.aiExecution,
    this.commercialQuality,
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
  final String primaryTrack;
  final List<String> followUpTracks;
  final String artifactType;
  final String contentSubtype;
  final String checksum;
  final String sourceFileName;
  final String status;

  /// schema 1.1+ 표준 Contract (레거시 1.0은 null 가능).
  final InstructionContract? contract;

  /// Production AI opt-in. null이면 기존과 동일(자동 Codex 없음).
  final AiExecutionPolicy? aiExecution;

  /// Sotong24Work commercial brief + track profiles (optional until studio UX fills).
  final CommercialQualityAttachment? commercialQuality;

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
    'primaryTrack': primaryTrack,
    'followUpTracks': followUpTracks,
    'followupTracks': followUpTracks,
    'artifactType': artifactType,
    'contentSubtype': contentSubtype,
    'checksum': checksum,
    'sourceFileName': sourceFileName,
    if (status.isNotEmpty) 'status': status,
    if (aiExecution != null) 'aiExecution': aiExecution!.toJson(),
    if (contract != null) ...contract!.toNestedJson(),
    if (commercialQuality != null)
      ...commercialQuality!.toInstructionJsonFields(),
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
    primaryTrack: '${json['primaryTrack'] ?? ''}',
    followUpTracks:
        (json['followUpTracks'] as List?)?.map((e) => '$e').toList() ??
        (json['followupTracks'] as List?)?.map((e) => '$e').toList() ??
        const [],
    artifactType: '${json['artifactType'] ?? ''}',
    contentSubtype: '${json['contentSubtype'] ?? ''}',
    checksum: '${json['checksum'] ?? ''}',
    sourceFileName: '${json['sourceFileName'] ?? ''}',
    status: '${json['status'] ?? ''}',
    contract: InstructionContract.tryParse(json),
    aiExecution: AiExecutionPolicy.tryParse(json),
    commercialQuality: () {
      final parsed = CommercialQualityAttachment.fromInstructionJson(json);
      return parsed.hasAnyCommercial ? parsed : null;
    }(),
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

class PlanVersionSnapshot {
  const PlanVersionSnapshot({
    required this.version,
    required this.createdAt,
    required this.status,
    this.instruction,
    this.transferFileName,
    this.transferredAt,
    this.checksum,
  });

  final int version;
  final String createdAt;
  final String status;
  final WorkInstruction? instruction;
  final String? transferFileName;
  final String? transferredAt;
  final String? checksum;

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt,
    'status': status,
    if (instruction != null) 'instruction': instruction!.toJson(),
    if (transferFileName != null) 'transferFileName': transferFileName,
    if (transferredAt != null) 'transferredAt': transferredAt,
    if (checksum != null) 'checksum': checksum,
  };

  factory PlanVersionSnapshot.fromJson(Map<String, dynamic> json) =>
      PlanVersionSnapshot(
        version: (json['version'] as num?)?.toInt() ?? 1,
        createdAt: '${json['createdAt'] ?? ''}',
        status: PlanningStatus.normalize('${json['status'] ?? ''}'),
        instruction: json['instruction'] == null
            ? null
            : WorkInstruction.fromJson(
                Map<String, dynamic>.from(json['instruction'] as Map),
              ),
        transferFileName: json['transferFileName'] == null
            ? null
            : '${json['transferFileName']}',
        transferredAt: json['transferredAt'] == null
            ? null
            : '${json['transferredAt']}',
        checksum: json['checksum'] == null ? null : '${json['checksum']}',
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
    this.instructionId = '',
    this.version = 1,
    this.primaryTrack = '',
    this.followUpTracks = const [],
    this.lastTransferAt,
    this.lastTransferFileName,
    this.lastTransferChecksum,
    this.lastTransferMode,
    this.lastRemoteJobId,
    this.lastRemoteCommandId,
    this.lastRemoteAgentId,
    this.lastDeliveryErrorCode,
    this.lastDeliveryErrorLabel,
    this.versionHistory = const [],
    this.favorite = false,
    this.libraryFolder = '',
    this.tags = const [],
    this.libraryState = PlanLibraryState.active,
    this.isProtected = false,
    this.trashedAt,
  });

  final String id;
  final BusinessPlanInput input;
  final String status;
  final String createdAt;
  final String updatedAt;
  final PlanningAnalysisResult? analysis;
  final WorkInstruction? instruction;
  final String instructionId;
  final int version;
  final String primaryTrack;
  final List<String> followUpTracks;
  final String? lastTransferAt;
  final String? lastTransferFileName;
  final String? lastTransferChecksum;
  final String? lastTransferMode;
  final String? lastRemoteJobId;
  final String? lastRemoteCommandId;
  final String? lastRemoteAgentId;
  final String? lastDeliveryErrorCode;
  final String? lastDeliveryErrorLabel;
  final List<PlanVersionSnapshot> versionHistory;
  final bool favorite;
  final String libraryFolder;
  final List<String> tags;

  /// 라이브러리 수명주기 (active / archived / trashed). 워크플로 status와 독립.
  final String libraryState;
  final bool isProtected;
  final String? trashedAt;

  bool get hasInstruction => instruction != null;
  bool get isLibraryArchived =>
      PlanLibraryState.normalize(libraryState) == PlanLibraryState.archived;
  bool get isLibraryTrashed =>
      PlanLibraryState.normalize(libraryState) == PlanLibraryState.trashed;
  bool get isLibraryActive =>
      PlanLibraryState.normalize(libraryState) == PlanLibraryState.active;

  String get stableInstructionId => instructionId.isNotEmpty
      ? instructionId
      : (instruction?.instructionId.isNotEmpty == true
            ? instruction!.instructionId
            : 'wi_$id');

  String get resolvedPrimaryTrack => primaryTrack.isNotEmpty
      ? primaryTrack
      : (instruction?.primaryTrack.isNotEmpty == true
            ? instruction!.primaryTrack
            : input.primaryTrack);

  /// Job + START_JOB 이 모두 확보된 경우만 true. Inbox 파일 쓰기만으로는 true가 되지 않는다.
  bool get wasTransferred {
    final s = PlanningStatus.normalize(status);
    if (s == PlanningStatus.imported) return true;
    if (s != PlanningStatus.transferred) return false;
    return hasRemoteDelivery;
  }

  bool get hasRemoteDelivery {
    final mode = (lastTransferMode ?? '').trim();
    if (mode == 'remote') return true;
    return (lastRemoteJobId ?? '').trim().isNotEmpty &&
        (lastRemoteCommandId ?? '').trim().isNotEmpty;
  }

  /// 다운로드만 되어 수동 가져오기 대기인 경우.
  bool get isManualImportPending {
    final s = PlanningStatus.normalize(status);
    final mode = lastTransferMode ?? '';
    if (s == PlanningStatus.downloadedPendingImport) return true;
    if (mode == 'download' && s != PlanningStatus.imported) return true;
    if (s == PlanningStatus.transferred &&
        mode != 'folder' &&
        mode != 'remote' &&
        !hasRemoteDelivery) {
      return true;
    }
    return false;
  }

  BusinessPlanDocument copyWith({
    BusinessPlanInput? input,
    String? status,
    String? updatedAt,
    PlanningAnalysisResult? analysis,
    WorkInstruction? instruction,
    bool clearInstruction = false,
    String? instructionId,
    int? version,
    String? primaryTrack,
    List<String>? followUpTracks,
    String? lastTransferAt,
    String? lastTransferFileName,
    String? lastTransferChecksum,
    String? lastTransferMode,
    String? lastRemoteJobId,
    String? lastRemoteCommandId,
    String? lastRemoteAgentId,
    String? lastDeliveryErrorCode,
    String? lastDeliveryErrorLabel,
    bool clearDeliveryError = false,
    List<PlanVersionSnapshot>? versionHistory,
    bool? favorite,
    String? libraryFolder,
    List<String>? tags,
    String? libraryState,
    bool? isProtected,
    String? trashedAt,
    bool clearTrashedAt = false,
  }) {
    return BusinessPlanDocument(
      id: id,
      input: input ?? this.input,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      analysis: analysis ?? this.analysis,
      instruction: clearInstruction ? null : (instruction ?? this.instruction),
      instructionId: instructionId ?? this.instructionId,
      version: version ?? this.version,
      primaryTrack: primaryTrack ?? this.primaryTrack,
      followUpTracks: followUpTracks ?? this.followUpTracks,
      lastTransferAt: lastTransferAt ?? this.lastTransferAt,
      lastTransferFileName: lastTransferFileName ?? this.lastTransferFileName,
      lastTransferChecksum: lastTransferChecksum ?? this.lastTransferChecksum,
      lastTransferMode: lastTransferMode ?? this.lastTransferMode,
      lastRemoteJobId: lastRemoteJobId ?? this.lastRemoteJobId,
      lastRemoteCommandId: lastRemoteCommandId ?? this.lastRemoteCommandId,
      lastRemoteAgentId: lastRemoteAgentId ?? this.lastRemoteAgentId,
      lastDeliveryErrorCode: clearDeliveryError
          ? null
          : (lastDeliveryErrorCode ?? this.lastDeliveryErrorCode),
      lastDeliveryErrorLabel: clearDeliveryError
          ? null
          : (lastDeliveryErrorLabel ?? this.lastDeliveryErrorLabel),
      versionHistory: versionHistory ?? this.versionHistory,
      favorite: favorite ?? this.favorite,
      libraryFolder: libraryFolder ?? this.libraryFolder,
      tags: tags ?? this.tags,
      libraryState: libraryState ?? this.libraryState,
      isProtected: isProtected ?? this.isProtected,
      trashedAt: clearTrashedAt ? null : (trashedAt ?? this.trashedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'input': input.toJson(),
    'status': PlanningStatus.normalize(status),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (analysis != null) 'analysis': analysis!.toJson(),
    if (instruction != null) 'instruction': instruction!.toJson(),
    'instructionId': stableInstructionId,
    'version': version,
    'primaryTrack': resolvedPrimaryTrack,
    'followUpTracks': followUpTracks,
    if (lastTransferAt != null) 'lastTransferAt': lastTransferAt,
    if (lastTransferFileName != null)
      'lastTransferFileName': lastTransferFileName,
    if (lastTransferChecksum != null)
      'lastTransferChecksum': lastTransferChecksum,
    if (lastTransferMode != null) 'lastTransferMode': lastTransferMode,
    if (lastRemoteJobId != null) 'lastRemoteJobId': lastRemoteJobId,
    if (lastRemoteCommandId != null) 'lastRemoteCommandId': lastRemoteCommandId,
    if (lastRemoteAgentId != null) 'lastRemoteAgentId': lastRemoteAgentId,
    if (lastDeliveryErrorCode != null)
      'lastDeliveryErrorCode': lastDeliveryErrorCode,
    if (lastDeliveryErrorLabel != null)
      'lastDeliveryErrorLabel': lastDeliveryErrorLabel,
    'versionHistory': versionHistory.map((e) => e.toJson()).toList(),
    'favorite': favorite,
    if (libraryFolder.isNotEmpty) 'libraryFolder': libraryFolder,
    if (tags.isNotEmpty) 'tags': tags,
    'libraryState': PlanLibraryState.normalize(libraryState),
    'protected': isProtected,
    if (trashedAt != null) 'trashedAt': trashedAt,
  };

  /// 레거시 JSON에서 libraryState 추론 (필드 없으면 데이터 소실 없이 기본값).
  static String resolveLibraryStateFromJson(Map<String, dynamic> json) {
    final raw = '${json['libraryState'] ?? ''}';
    if (raw.isNotEmpty) return PlanLibraryState.normalize(raw);
    final folder = '${json['libraryFolder'] ?? ''}';
    if (folder == 'trashed' || folder == PlanLibraryState.trashed) {
      return PlanLibraryState.trashed;
    }
    if (folder == 'archived' || folder == PlanLibraryState.archived) {
      return PlanLibraryState.archived;
    }
    final status = PlanningStatus.normalize(
      '${json['status'] ?? PlanningStatus.draft}',
    );
    if (status == PlanningStatus.trashed) return PlanLibraryState.trashed;
    if (status == PlanningStatus.archived) return PlanLibraryState.archived;
    return PlanLibraryState.active;
  }

  factory BusinessPlanDocument.fromJson(Map<String, dynamic> json) {
    final input = BusinessPlanInput.fromJson(
      Map<String, dynamic>.from(json['input'] as Map? ?? {}),
    );
    final instruction = json['instruction'] == null
        ? null
        : WorkInstruction.fromJson(
            Map<String, dynamic>.from(json['instruction'] as Map),
          );
    final id = '${json['id'] ?? ''}';
    final rawInstructionId = '${json['instructionId'] ?? ''}';
    var status = PlanningStatus.normalize(
      '${json['status'] ?? PlanningStatus.draft}',
    );
    // 워크플로 status에 trashed가 들어와도 libraryState로 분리 유지.
    if (status == PlanningStatus.trashed) {
      status = PlanningStatus.draft;
    }
    return BusinessPlanDocument(
      id: id,
      input: input,
      status: status,
      createdAt: '${json['createdAt'] ?? ''}',
      updatedAt: '${json['updatedAt'] ?? ''}',
      analysis: json['analysis'] == null
          ? null
          : PlanningAnalysisResult.fromJson(
              Map<String, dynamic>.from(json['analysis'] as Map),
            ),
      instruction: instruction,
      instructionId: rawInstructionId.isNotEmpty
          ? rawInstructionId
          : (instruction?.instructionId.isNotEmpty == true
                ? instruction!.instructionId
                : 'wi_$id'),
      version:
          (json['version'] as num?)?.toInt() ??
          int.tryParse(instruction?.instructionVersion ?? '1') ??
          1,
      primaryTrack:
          '${json['primaryTrack'] ?? instruction?.primaryTrack ?? ''}',
      followUpTracks:
          (json['followUpTracks'] as List?)?.map((e) => '$e').toList() ??
          instruction?.followUpTracks ??
          const [],
      lastTransferAt: json['lastTransferAt'] == null
          ? null
          : '${json['lastTransferAt']}',
      lastTransferFileName: json['lastTransferFileName'] == null
          ? null
          : '${json['lastTransferFileName']}',
      lastTransferChecksum: json['lastTransferChecksum'] == null
          ? null
          : '${json['lastTransferChecksum']}',
      lastTransferMode: json['lastTransferMode'] == null
          ? null
          : '${json['lastTransferMode']}',
      lastRemoteJobId: json['lastRemoteJobId'] == null
          ? null
          : '${json['lastRemoteJobId']}',
      lastRemoteCommandId: json['lastRemoteCommandId'] == null
          ? null
          : '${json['lastRemoteCommandId']}',
      lastRemoteAgentId: json['lastRemoteAgentId'] == null
          ? null
          : '${json['lastRemoteAgentId']}',
      lastDeliveryErrorCode: json['lastDeliveryErrorCode'] == null
          ? null
          : '${json['lastDeliveryErrorCode']}',
      lastDeliveryErrorLabel: json['lastDeliveryErrorLabel'] == null
          ? null
          : '${json['lastDeliveryErrorLabel']}',
      versionHistory:
          (json['versionHistory'] as List?)
              ?.map(
                (e) => PlanVersionSnapshot.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      favorite: json['favorite'] == true,
      libraryFolder: '${json['libraryFolder'] ?? ''}',
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
      libraryState: resolveLibraryStateFromJson(json),
      isProtected: json['protected'] == true,
      trashedAt: json['trashedAt'] == null ? null : '${json['trashedAt']}',
    );
  }
}
