/// SotongwareControl ↔ Sotong24Work 작업지시서 Contract (schema 1.1+).
///
/// 레거시 flat 필드와 병행하며, 새 구조는 중첩 객체로 전달한다.
library;

/// 필드 출처 — 사용자 확정값이 template보다 우선.
class FieldSource {
  static const userConfirmed = 'user_confirmed';
  static const userSelected = 'user_selected';
  static const suggested = 'suggested';
  static const designEngine = 'design_engine';
  static const derived = 'derived';
  static const template = 'template';
  static const undecided = 'undecided';
  static const legacyDefault = 'legacy_default';
}

class CanonicalValue {
  const CanonicalValue({
    required this.value,
    required this.source,
    this.pending = false,
  });

  final String value;
  final String source;
  final bool pending;

  bool get isBlank => value.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'value': value,
    'source': source,
    if (pending) 'pending': true,
  };

  factory CanonicalValue.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CanonicalValue(
        value: '',
        source: FieldSource.undecided,
        pending: true,
      );
    }
    final v = '${json['value'] ?? ''}'.trim();
    return CanonicalValue(
      value: v,
      source: '${json['source'] ?? FieldSource.undecided}',
      pending: json['pending'] == true || v.isEmpty,
    );
  }

  static CanonicalValue confirmed(String value) {
    final v = value.trim();
    if (v.isEmpty) {
      return const CanonicalValue(
        value: '',
        source: FieldSource.undecided,
        pending: true,
      );
    }
    return CanonicalValue(value: v, source: FieldSource.userConfirmed);
  }

  static CanonicalValue derived(String value) {
    final v = value.trim();
    if (v.isEmpty) {
      return const CanonicalValue(
        value: '',
        source: FieldSource.undecided,
        pending: true,
      );
    }
    return CanonicalValue(value: v, source: FieldSource.derived);
  }

  static CanonicalValue undecided() => const CanonicalValue(
    value: '',
    source: FieldSource.undecided,
    pending: true,
  );
}

class QualityCriterion {
  const QualityCriterion({
    required this.id,
    required this.label,
    required this.description,
    this.required = true,
  });

  final String id;
  final String label;
  final String description;
  final bool required;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'description': description,
    'required': required,
  };

  factory QualityCriterion.fromJson(Map<String, dynamic> json) =>
      QualityCriterion(
        id: '${json['id'] ?? ''}',
        label: '${json['label'] ?? ''}',
        description: '${json['description'] ?? ''}',
        required: json['required'] != false,
      );
}

class AiGuardRule {
  const AiGuardRule({
    required this.id,
    required this.rule,
    this.scope = 'common',
    this.isBlocking = true,
  });

  final String id;
  final String rule;
  final String scope; // common | ebook | app | contents | site | promo_site
  final bool isBlocking;

  Map<String, dynamic> toJson() => {
    'id': id,
    'rule': rule,
    'scope': scope,
    'blocking': isBlocking,
  };

  factory AiGuardRule.fromJson(Map<String, dynamic> json) => AiGuardRule(
    id: '${json['id'] ?? ''}',
    rule: '${json['rule'] ?? ''}',
    scope: '${json['scope'] ?? 'common'}',
    isBlocking: json['blocking'] != false,
  );
}

class WorkflowStageDef {
  const WorkflowStageDef({
    required this.id,
    required this.order,
    required this.title,
    required this.purpose,
    this.requiredInputs = const [],
    this.expectedArtifacts = const [],
    this.completionCriteria = const [],
    this.requiresApproval = false,
  });

  final String id;
  final int order;
  final String title;
  final String purpose;
  final List<String> requiredInputs;
  final List<String> expectedArtifacts;
  final List<String> completionCriteria;
  final bool requiresApproval;

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'title': title,
    'purpose': purpose,
    if (requiredInputs.isNotEmpty) 'requiredInputs': requiredInputs,
    if (expectedArtifacts.isNotEmpty) 'expectedArtifacts': expectedArtifacts,
    if (completionCriteria.isNotEmpty) 'completionCriteria': completionCriteria,
    'requiresApproval': requiresApproval,
  };

  factory WorkflowStageDef.fromJson(Map<String, dynamic> json) =>
      WorkflowStageDef(
        id: '${json['id'] ?? ''}',
        order: (json['order'] as num?)?.toInt() ?? 0,
        title: '${json['title'] ?? ''}',
        purpose: '${json['purpose'] ?? ''}',
        requiredInputs:
            (json['requiredInputs'] as List?)?.map((e) => '$e').toList() ??
            const [],
        expectedArtifacts:
            (json['expectedArtifacts'] as List?)?.map((e) => '$e').toList() ??
            const [],
        completionCriteria:
            (json['completionCriteria'] as List?)?.map((e) => '$e').toList() ??
            const [],
        requiresApproval: json['requiresApproval'] == true,
      );
}

class WorkflowContract {
  const WorkflowContract({
    required this.workflowId,
    required this.currentStage,
    required this.startStage,
    required this.stages,
    this.approvalPolicy = 'stage_gate',
    this.deploymentPolicy = 'manual_approval_required',
  });

  final String workflowId;
  final String currentStage;
  final String startStage;
  final List<WorkflowStageDef> stages;
  final String approvalPolicy;
  final String deploymentPolicy;

  Map<String, dynamic> toJson() => {
    'workflowId': workflowId,
    'currentStage': currentStage,
    'startStage': startStage,
    'stages': stages.map((e) => e.toJson()).toList(),
    'approvalPolicy': approvalPolicy,
    'deploymentPolicy': deploymentPolicy,
  };

  factory WorkflowContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WorkflowContract(
        workflowId: '',
        currentStage: '',
        startStage: '',
        stages: [],
      );
    }
    return WorkflowContract(
      workflowId: '${json['workflowId'] ?? ''}',
      currentStage: '${json['currentStage'] ?? ''}',
      startStage: '${json['startStage'] ?? ''}',
      stages:
          (json['stages'] as List?)
              ?.map(
                (e) => WorkflowStageDef.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      approvalPolicy: '${json['approvalPolicy'] ?? 'stage_gate'}',
      deploymentPolicy:
          '${json['deploymentPolicy'] ?? 'manual_approval_required'}',
    );
  }
}

class ApprovalStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const revisionRequested = 'revision_requested';
  static const notRequired = 'not_required';
}

class ApprovalContract {
  const ApprovalContract({
    this.planning = ApprovalStatus.pending,
    this.instructionGeneration = ApprovalStatus.pending,
    this.production = ApprovalStatus.pending,
    this.publishing = ApprovalStatus.pending,
    this.deployment = ApprovalStatus.pending,
  });

  final String planning;
  final String instructionGeneration;
  final String production;
  final String publishing;
  final String deployment;

  Map<String, dynamic> toJson() => {
    'planning': planning,
    'instructionGeneration': instructionGeneration,
    'production': production,
    'publishing': publishing,
    'deployment': deployment,
  };

  factory ApprovalContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ApprovalContract();
    return ApprovalContract(
      planning: '${json['planning'] ?? ApprovalStatus.pending}',
      instructionGeneration:
          '${json['instructionGeneration'] ?? ApprovalStatus.pending}',
      production: '${json['production'] ?? ApprovalStatus.pending}',
      publishing: '${json['publishing'] ?? ApprovalStatus.pending}',
      deployment: '${json['deployment'] ?? ApprovalStatus.pending}',
    );
  }
}

class ValidationContract {
  const ValidationContract({
    this.requiredFields = const [],
    this.requiredArtifacts = const [],
    this.qualityChecks = const [],
    this.blockingConditions = const [],
    this.warnings = const [],
  });

  final List<String> requiredFields;
  final List<String> requiredArtifacts;
  final List<String> qualityChecks;
  final List<String> blockingConditions;
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'requiredFields': requiredFields,
    'requiredArtifacts': requiredArtifacts,
    'qualityChecks': qualityChecks,
    'blockingConditions': blockingConditions,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };

  factory ValidationContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ValidationContract();
    return ValidationContract(
      requiredFields:
          (json['requiredFields'] as List?)?.map((e) => '$e').toList() ??
          const [],
      requiredArtifacts:
          (json['requiredArtifacts'] as List?)?.map((e) => '$e').toList() ??
          const [],
      qualityChecks:
          (json['qualityChecks'] as List?)?.map((e) => '$e').toList() ??
          const [],
      blockingConditions:
          (json['blockingConditions'] as List?)?.map((e) => '$e').toList() ??
          const [],
      warnings:
          (json['warnings'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}

class ScopeContract {
  const ScopeContract({
    this.included = const [],
    this.excluded = const [],
    this.requiredFeatures = const [],
    this.optionalFeatures = const [],
    this.undecidedItems = const [],
  });

  final List<String> included;
  final List<String> excluded;
  final List<String> requiredFeatures;
  final List<String> optionalFeatures;
  final List<String> undecidedItems;

  Map<String, dynamic> toJson() => {
    'included': included,
    'excluded': excluded,
    'requiredFeatures': requiredFeatures,
    'optionalFeatures': optionalFeatures,
    'undecidedItems': undecidedItems,
  };

  factory ScopeContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScopeContract();
    return ScopeContract(
      included:
          (json['included'] as List?)?.map((e) => '$e').toList() ?? const [],
      excluded:
          (json['excluded'] as List?)?.map((e) => '$e').toList() ?? const [],
      requiredFeatures:
          (json['requiredFeatures'] as List?)?.map((e) => '$e').toList() ??
          const [],
      optionalFeatures:
          (json['optionalFeatures'] as List?)?.map((e) => '$e').toList() ??
          const [],
      undecidedItems:
          (json['undecidedItems'] as List?)?.map((e) => '$e').toList() ??
          const [],
    );
  }
}

class PositioningContract {
  const PositioningContract({
    required this.customerNeed,
    required this.valueProposition,
    required this.differentiation,
    required this.aiEraRelevance,
    required this.professionalDirection,
  });

  final CanonicalValue customerNeed;
  final CanonicalValue valueProposition;
  final CanonicalValue differentiation;
  final CanonicalValue aiEraRelevance;
  final CanonicalValue professionalDirection;

  Map<String, dynamic> toJson() => {
    'customerNeed': customerNeed.toJson(),
    'valueProposition': valueProposition.toJson(),
    'differentiation': differentiation.toJson(),
    'aiEraRelevance': aiEraRelevance.toJson(),
    'professionalDirection': professionalDirection.toJson(),
  };

  factory PositioningContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PositioningContract(
        customerNeed: CanonicalValue.undecided(),
        valueProposition: CanonicalValue.undecided(),
        differentiation: CanonicalValue.undecided(),
        aiEraRelevance: CanonicalValue.undecided(),
        professionalDirection: CanonicalValue.undecided(),
      );
    }
    return PositioningContract(
      customerNeed: CanonicalValue.fromJson(
        json['customerNeed'] is Map
            ? Map<String, dynamic>.from(json['customerNeed'] as Map)
            : null,
      ),
      valueProposition: CanonicalValue.fromJson(
        json['valueProposition'] is Map
            ? Map<String, dynamic>.from(json['valueProposition'] as Map)
            : null,
      ),
      differentiation: CanonicalValue.fromJson(
        json['differentiation'] is Map
            ? Map<String, dynamic>.from(json['differentiation'] as Map)
            : null,
      ),
      aiEraRelevance: CanonicalValue.fromJson(
        json['aiEraRelevance'] is Map
            ? Map<String, dynamic>.from(json['aiEraRelevance'] as Map)
            : null,
      ),
      professionalDirection: CanonicalValue.fromJson(
        json['professionalDirection'] is Map
            ? Map<String, dynamic>.from(json['professionalDirection'] as Map)
            : null,
      ),
    );
  }
}

class ProjectDefinitionContract {
  const ProjectDefinitionContract({
    required this.title,
    this.subtitle = '',
    required this.projectPurpose,
    required this.targetCustomers,
    required this.targetCustomerDescription,
    required this.coreProblem,
    required this.expectedOutcome,
    this.userMemo = '',
    this.selectedTopics = const [],
    this.keywords = const [],
  });

  final CanonicalValue title;
  final String subtitle;
  final CanonicalValue projectPurpose;
  final List<String> targetCustomers;
  final CanonicalValue targetCustomerDescription;
  final CanonicalValue coreProblem;
  final CanonicalValue expectedOutcome;
  final String userMemo;
  final List<String> selectedTopics;
  final List<String> keywords;

  Map<String, dynamic> toJson() => {
    'title': title.toJson(),
    if (subtitle.trim().isNotEmpty) 'subtitle': subtitle.trim(),
    'projectPurpose': projectPurpose.toJson(),
    'targetCustomers': targetCustomers,
    'targetCustomerDescription': targetCustomerDescription.toJson(),
    'coreProblem': coreProblem.toJson(),
    'expectedOutcome': expectedOutcome.toJson(),
    if (userMemo.trim().isNotEmpty) 'userMemo': userMemo.trim(),
    'selectedTopics': selectedTopics,
    'keywords': keywords,
  };

  factory ProjectDefinitionContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ProjectDefinitionContract(
        title: CanonicalValue.undecided(),
        projectPurpose: CanonicalValue.undecided(),
        targetCustomers: const [],
        targetCustomerDescription: CanonicalValue.undecided(),
        coreProblem: CanonicalValue.undecided(),
        expectedOutcome: CanonicalValue.undecided(),
      );
    }
    Map<String, dynamic>? asMap(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    return ProjectDefinitionContract(
      title: CanonicalValue.fromJson(asMap(json['title'])),
      subtitle: '${json['subtitle'] ?? ''}',
      projectPurpose: CanonicalValue.fromJson(asMap(json['projectPurpose'])),
      targetCustomers:
          (json['targetCustomers'] as List?)?.map((e) => '$e').toList() ??
          const [],
      targetCustomerDescription: CanonicalValue.fromJson(
        asMap(json['targetCustomerDescription']),
      ),
      coreProblem: CanonicalValue.fromJson(asMap(json['coreProblem'])),
      expectedOutcome: CanonicalValue.fromJson(asMap(json['expectedOutcome'])),
      userMemo: '${json['userMemo'] ?? ''}',
      selectedTopics:
          (json['selectedTopics'] as List?)?.map((e) => '$e').toList() ??
          const [],
      keywords:
          (json['keywords'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}

class IdentityContract {
  const IdentityContract({
    required this.schemaVersion,
    required this.instructionId,
    required this.projectId,
    required this.version,
    required this.artifactType,
    this.artifactSubtype,
    required this.createdAt,
    required this.updatedAt,
  });

  final String schemaVersion;
  final String instructionId;
  final String projectId;
  final String version;
  final String artifactType;
  final String? artifactSubtype;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'instructionId': instructionId,
    'projectId': projectId,
    'version': version,
    'artifactType': artifactType,
    if (artifactSubtype != null && artifactSubtype!.trim().isNotEmpty)
      'artifactSubtype': artifactSubtype!.trim(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory IdentityContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const IdentityContract(
        schemaVersion: '',
        instructionId: '',
        projectId: '',
        version: '',
        artifactType: '',
        createdAt: '',
        updatedAt: '',
      );
    }
    final subtype = '${json['artifactSubtype'] ?? ''}'.trim();
    return IdentityContract(
      schemaVersion: '${json['schemaVersion'] ?? ''}',
      instructionId: '${json['instructionId'] ?? ''}',
      projectId: '${json['projectId'] ?? ''}',
      version: '${json['version'] ?? json['instructionVersion'] ?? ''}',
      artifactType: '${json['artifactType'] ?? ''}',
      artifactSubtype: subtype.isEmpty ? null : subtype,
      createdAt: '${json['createdAt'] ?? ''}',
      updatedAt: '${json['updatedAt'] ?? ''}',
    );
  }
}

/// 결과물별 제작 조건 — 공통 맵 + 명시 키.
class ProductionSpecContract {
  const ProductionSpecContract({
    required this.artifactType,
    this.artifactSubtype,
    this.spec = const {},
    this.undecidedKeys = const [],
  });

  final String artifactType;
  final String? artifactSubtype;
  final Map<String, dynamic> spec;
  final List<String> undecidedKeys;

  Map<String, dynamic> toJson() => {
    'artifactType': artifactType,
    if (artifactSubtype != null && artifactSubtype!.trim().isNotEmpty)
      'artifactSubtype': artifactSubtype!.trim(),
    ...spec,
    if (undecidedKeys.isNotEmpty) 'undecidedKeys': undecidedKeys,
  };

  factory ProductionSpecContract.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ProductionSpecContract(artifactType: '');
    }
    final copy = Map<String, dynamic>.from(json);
    final artifactType = '${copy.remove('artifactType') ?? ''}';
    final subtypeRaw = '${copy.remove('artifactSubtype') ?? ''}'.trim();
    final undecided =
        (copy.remove('undecidedKeys') as List?)?.map((e) => '$e').toList() ??
        const <String>[];
    return ProductionSpecContract(
      artifactType: artifactType,
      artifactSubtype: subtypeRaw.isEmpty ? null : subtypeRaw,
      spec: copy,
      undecidedKeys: undecided,
    );
  }
}

/// schema 1.1+ 표준 Contract 블록.
class InstructionContract {
  const InstructionContract({
    required this.identity,
    required this.projectDefinition,
    required this.positioning,
    required this.scope,
    required this.productionSpec,
    required this.qualityCriteria,
    required this.aiGuards,
    required this.workflow,
    required this.approval,
    required this.validation,
  });

  final IdentityContract identity;
  final ProjectDefinitionContract projectDefinition;
  final PositioningContract positioning;
  final ScopeContract scope;
  final ProductionSpecContract productionSpec;
  final List<QualityCriterion> qualityCriteria;
  final List<AiGuardRule> aiGuards;
  final WorkflowContract workflow;
  final ApprovalContract approval;
  final ValidationContract validation;

  /// 레거시 flat 필드와 함께 직렬화할 중첩 블록.
  Map<String, dynamic> toNestedJson() => {
    'identity': identity.toJson(),
    'projectDefinition': projectDefinition.toJson(),
    'positioning': positioning.toJson(),
    'scope': scope.toJson(),
    'productionSpec': productionSpec.toJson(),
    'qualityCriteria': qualityCriteria.map((e) => e.toJson()).toList(),
    'aiGuards': aiGuards.map((e) => e.toJson()).toList(),
    'workflow': workflow.toJson(),
    'approval': approval.toJson(),
    'validation': validation.toJson(),
  };

  factory InstructionContract.fromNestedJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> listOf(Object? raw) =>
        (raw as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];

    return InstructionContract(
      identity: IdentityContract.fromJson(
        json['identity'] is Map
            ? Map<String, dynamic>.from(json['identity'] as Map)
            : null,
      ),
      projectDefinition: ProjectDefinitionContract.fromJson(
        json['projectDefinition'] is Map
            ? Map<String, dynamic>.from(json['projectDefinition'] as Map)
            : null,
      ),
      positioning: PositioningContract.fromJson(
        json['positioning'] is Map
            ? Map<String, dynamic>.from(json['positioning'] as Map)
            : null,
      ),
      scope: ScopeContract.fromJson(
        json['scope'] is Map
            ? Map<String, dynamic>.from(json['scope'] as Map)
            : null,
      ),
      productionSpec: ProductionSpecContract.fromJson(
        json['productionSpec'] is Map
            ? Map<String, dynamic>.from(json['productionSpec'] as Map)
            : null,
      ),
      qualityCriteria: listOf(
        json['qualityCriteria'],
      ).map(QualityCriterion.fromJson).toList(),
      aiGuards: listOf(json['aiGuards']).map(AiGuardRule.fromJson).toList(),
      workflow: WorkflowContract.fromJson(
        json['workflow'] is Map
            ? Map<String, dynamic>.from(json['workflow'] as Map)
            : null,
      ),
      approval: ApprovalContract.fromJson(
        json['approval'] is Map
            ? Map<String, dynamic>.from(json['approval'] as Map)
            : null,
      ),
      validation: ValidationContract.fromJson(
        json['validation'] is Map
            ? Map<String, dynamic>.from(json['validation'] as Map)
            : null,
      ),
    );
  }

  /// 중첩 블록이 없으면 null (schema 1.0 레거시).
  static InstructionContract? tryParse(Map<String, dynamic> json) {
    final hasContract =
        json.containsKey('projectDefinition') ||
        json.containsKey('productionSpec') ||
        json.containsKey('workflow') ||
        json.containsKey('qualityCriteria');
    if (!hasContract) return null;
    return InstructionContract.fromNestedJson(json);
  }
}

/// 현재 신규 생성 schema.
const instructionSchemaVersionCurrent = '1.1';
const instructionSchemaVersionLegacy = '1.0';

bool isSupportedInstructionSchema(String version) =>
    version == instructionSchemaVersionCurrent ||
    version == instructionSchemaVersionLegacy;
