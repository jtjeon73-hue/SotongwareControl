/// ProductionReviewStatusEnvelope v1 — mirrors Sotong24Work production review contract.
library;

class ProductionReviewTechnicalValidation {
  const ProductionReviewTechnicalValidation({
    this.status = '',
    this.completed = false,
    this.validatorResult = '',
    this.artifactKind = '',
    this.artifactSha256 = '',
    this.completedAt = '',
  });

  final String status;
  final bool completed;
  final String validatorResult;
  final String artifactKind;
  final String artifactSha256;
  final String completedAt;

  Map<String, dynamic> toJson() => {
    'status': status,
    'completed': completed,
    'validatorResult': validatorResult,
    'artifactKind': artifactKind,
    'artifactSha256': artifactSha256,
    'completedAt': completedAt,
  };

  factory ProductionReviewTechnicalValidation.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json.isEmpty) {
      return const ProductionReviewTechnicalValidation();
    }
    return ProductionReviewTechnicalValidation(
      status: '${json['status'] ?? ''}',
      completed: json['completed'] == true,
      validatorResult: '${json['validatorResult'] ?? ''}',
      artifactKind: '${json['artifactKind'] ?? ''}',
      artifactSha256: '${json['artifactSha256'] ?? ''}',
      completedAt: '${json['completedAt'] ?? ''}',
    );
  }

  ProductionReviewTechnicalValidation copyWith({
    String? status,
    bool? completed,
    String? validatorResult,
    String? artifactKind,
    String? artifactSha256,
    String? completedAt,
  }) {
    return ProductionReviewTechnicalValidation(
      status: status ?? this.status,
      completed: completed ?? this.completed,
      validatorResult: validatorResult ?? this.validatorResult,
      artifactKind: artifactKind ?? this.artifactKind,
      artifactSha256: artifactSha256 ?? this.artifactSha256,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class ProductionReviewOwnerReview {
  const ProductionReviewOwnerReview({
    this.decision = '',
    this.revision = '',
    this.step16Blocked = false,
    this.nextAllowedAction = '',
    this.findingCount = 0,
    this.blockerCount = 0,
    this.highCount = 0,
    this.decisionRef = '',
    this.reviewedAt = '',
  });

  final String decision;
  final String revision;
  final bool step16Blocked;
  final String nextAllowedAction;
  final int findingCount;
  final int blockerCount;
  final int highCount;
  final String decisionRef;
  final String reviewedAt;

  Map<String, dynamic> toJson() => {
    'decision': decision,
    'revision': revision,
    'step16Blocked': step16Blocked,
    'nextAllowedAction': nextAllowedAction,
    'findingCount': findingCount,
    'blockerCount': blockerCount,
    'highCount': highCount,
    'decisionRef': decisionRef,
    'reviewedAt': reviewedAt,
  };

  factory ProductionReviewOwnerReview.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ProductionReviewOwnerReview();
    }
    return ProductionReviewOwnerReview(
      decision: '${json['decision'] ?? ''}',
      revision: '${json['revision'] ?? ''}',
      step16Blocked: json['step16Blocked'] == true,
      nextAllowedAction: '${json['nextAllowedAction'] ?? ''}',
      findingCount: _asInt(json['findingCount']),
      blockerCount: _asInt(json['blockerCount']),
      highCount: _asInt(json['highCount']),
      decisionRef: '${json['decisionRef'] ?? ''}',
      reviewedAt: '${json['reviewedAt'] ?? ''}',
    );
  }

  ProductionReviewOwnerReview copyWith({
    String? decision,
    String? revision,
    bool? step16Blocked,
    String? nextAllowedAction,
    int? findingCount,
    int? blockerCount,
    int? highCount,
    String? decisionRef,
    String? reviewedAt,
  }) {
    return ProductionReviewOwnerReview(
      decision: decision ?? this.decision,
      revision: revision ?? this.revision,
      step16Blocked: step16Blocked ?? this.step16Blocked,
      nextAllowedAction: nextAllowedAction ?? this.nextAllowedAction,
      findingCount: findingCount ?? this.findingCount,
      blockerCount: blockerCount ?? this.blockerCount,
      highCount: highCount ?? this.highCount,
      decisionRef: decisionRef ?? this.decisionRef,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}

class ProductionReviewExecution {
  const ProductionReviewExecution({
    this.agentState = '',
    this.currentJobId = '',
    this.paused = false,
    this.recoveryState = '',
    this.permitState = '',
    this.worker = '',
    this.heartbeatAt = '',
    this.terminalBlockCount = 0,
  });

  final String agentState;
  final String currentJobId;
  final bool paused;
  final String recoveryState;
  final String permitState;
  final String worker;
  final String heartbeatAt;
  final int terminalBlockCount;

  Map<String, dynamic> toJson() => {
    'agentState': agentState,
    'currentJobId': currentJobId,
    'paused': paused,
    'recoveryState': recoveryState,
    'permitState': permitState,
    'worker': worker,
    'heartbeatAt': heartbeatAt,
    'terminalBlockCount': terminalBlockCount,
  };

  factory ProductionReviewExecution.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ProductionReviewExecution();
    }
    return ProductionReviewExecution(
      agentState: '${json['agentState'] ?? ''}',
      currentJobId: '${json['currentJobId'] ?? ''}',
      paused: json['paused'] == true,
      recoveryState: '${json['recoveryState'] ?? ''}',
      permitState: '${json['permitState'] ?? ''}',
      worker: '${json['worker'] ?? ''}',
      heartbeatAt: '${json['heartbeatAt'] ?? ''}',
      terminalBlockCount: _asInt(json['terminalBlockCount']),
    );
  }

  ProductionReviewExecution copyWith({
    String? agentState,
    String? currentJobId,
    bool? paused,
    String? recoveryState,
    String? permitState,
    String? worker,
    String? heartbeatAt,
    int? terminalBlockCount,
  }) {
    return ProductionReviewExecution(
      agentState: agentState ?? this.agentState,
      currentJobId: currentJobId ?? this.currentJobId,
      paused: paused ?? this.paused,
      recoveryState: recoveryState ?? this.recoveryState,
      permitState: permitState ?? this.permitState,
      worker: worker ?? this.worker,
      heartbeatAt: heartbeatAt ?? this.heartbeatAt,
      terminalBlockCount: terminalBlockCount ?? this.terminalBlockCount,
    );
  }
}

class ProductionReviewReadiness {
  const ProductionReviewReadiness({
    this.technicalValidationCompleted = false,
    this.ownerReviewRequired = false,
    this.revisionRequired = false,
    this.revisionReady = false,
    this.registrationEligible = false,
    this.externalPublicationAllowed = false,
  });

  final bool technicalValidationCompleted;
  final bool ownerReviewRequired;
  final bool revisionRequired;
  final bool revisionReady;
  final bool registrationEligible;
  final bool externalPublicationAllowed;

  Map<String, dynamic> toJson() => {
    'technicalValidationCompleted': technicalValidationCompleted,
    'ownerReviewRequired': ownerReviewRequired,
    'revisionRequired': revisionRequired,
    'revisionReady': revisionReady,
    'registrationEligible': registrationEligible,
    'externalPublicationAllowed': externalPublicationAllowed,
  };

  factory ProductionReviewReadiness.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ProductionReviewReadiness();
    }
    return ProductionReviewReadiness(
      technicalValidationCompleted:
          json['technicalValidationCompleted'] == true,
      ownerReviewRequired: json['ownerReviewRequired'] == true,
      revisionRequired: json['revisionRequired'] == true,
      revisionReady: json['revisionReady'] == true,
      registrationEligible: json['registrationEligible'] == true,
      externalPublicationAllowed: json['externalPublicationAllowed'] == true,
    );
  }

  ProductionReviewReadiness copyWith({
    bool? technicalValidationCompleted,
    bool? ownerReviewRequired,
    bool? revisionRequired,
    bool? revisionReady,
    bool? registrationEligible,
    bool? externalPublicationAllowed,
  }) {
    return ProductionReviewReadiness(
      technicalValidationCompleted:
          technicalValidationCompleted ?? this.technicalValidationCompleted,
      ownerReviewRequired: ownerReviewRequired ?? this.ownerReviewRequired,
      revisionRequired: revisionRequired ?? this.revisionRequired,
      revisionReady: revisionReady ?? this.revisionReady,
      registrationEligible: registrationEligible ?? this.registrationEligible,
      externalPublicationAllowed:
          externalPublicationAllowed ?? this.externalPublicationAllowed,
    );
  }
}

class ProductionReviewProblem {
  const ProductionReviewProblem({
    this.code = '',
    this.severity = '',
    this.userSummary = '',
    this.recommendedActions = const [],
    this.occurredAt = '',
  });

  final String code;
  final String severity;
  final String userSummary;
  final List<String> recommendedActions;
  final String occurredAt;

  Map<String, dynamic> toJson() => {
    'code': code,
    'severity': severity,
    'userSummary': userSummary,
    'recommendedActions': recommendedActions,
    'occurredAt': occurredAt,
  };

  factory ProductionReviewProblem.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ProductionReviewProblem();
    }
    return ProductionReviewProblem(
      code: '${json['code'] ?? ''}',
      severity: '${json['severity'] ?? ''}',
      userSummary: '${json['userSummary'] ?? ''}',
      recommendedActions: _asStringList(json['recommendedActions']),
      occurredAt: '${json['occurredAt'] ?? ''}',
    );
  }

  ProductionReviewProblem copyWith({
    String? code,
    String? severity,
    String? userSummary,
    List<String>? recommendedActions,
    String? occurredAt,
  }) {
    return ProductionReviewProblem(
      code: code ?? this.code,
      severity: severity ?? this.severity,
      userSummary: userSummary ?? this.userSummary,
      recommendedActions: recommendedActions ?? this.recommendedActions,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }
}

class ProductionReviewStatusEnvelope {
  const ProductionReviewStatusEnvelope({
    this.schemaVersion = kSchemaVersion,
    this.eventId = '',
    this.instructionId = '',
    this.projectId = '',
    this.jobId = '',
    this.artifactType = '',
    this.contentSubtype = '',
    this.siteSubtype = '',
    this.displayTitle = '',
    this.revision = '',
    this.sourceRevision = '',
    this.stageId = '',
    this.stageOrder = 0,
    this.stageStatus = '',
    this.verifiedThroughStep = 0,
    this.lastVerifiedStage = '',
    this.productionStatus = '',
    this.updatedAt = '',
    this.emittedAt = '',
    this.sequence = 0,
    this.technicalValidation = const ProductionReviewTechnicalValidation(),
    this.ownerReview = const ProductionReviewOwnerReview(),
    this.execution = const ProductionReviewExecution(),
    this.readiness = const ProductionReviewReadiness(),
    this.problem = const ProductionReviewProblem(),
    this.userLabelKo = '',
    this.nextActionKo = '',
    this.initialSync = false,
    this.syncKind = '',
    this.contentFingerprint = '',
  });

  static const kSchemaVersion = 1;

  final int schemaVersion;
  final String eventId;
  final String instructionId;
  final String projectId;
  final String jobId;
  final String artifactType;
  final String contentSubtype;
  final String siteSubtype;
  final String displayTitle;
  final String revision;
  final String sourceRevision;
  final String stageId;
  final int stageOrder;
  final String stageStatus;
  final int verifiedThroughStep;
  final String lastVerifiedStage;
  final String productionStatus;
  final String updatedAt;
  final String emittedAt;
  final int sequence;
  final ProductionReviewTechnicalValidation technicalValidation;
  final ProductionReviewOwnerReview ownerReview;
  final ProductionReviewExecution execution;
  final ProductionReviewReadiness readiness;
  final ProductionReviewProblem problem;
  final String userLabelKo;
  final String nextActionKo;
  /// True for first-connect / cold sync payloads (notification suppressed).
  final bool initialSync;
  /// '' | baseline | transition
  final String syncKind;
  /// Stable hash of status fields excluding volatile timestamps.
  final String contentFingerprint;

  /// R1 → 1, R2 → 2, numeric fallback.
  int get revisionRank => revisionRankOf(revision);

  static int revisionRankOf(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.startsWith('R')) {
      return int.tryParse(trimmed.substring(1)) ?? 0;
    }
    return int.tryParse(trimmed) ?? 0;
  }

  /// True when [other] is strictly newer (same revision, higher sequence or emittedAt).
  bool isStaleVs(ProductionReviewStatusEnvelope other) {
    if (instructionId != other.instructionId) return false;
    if (revisionRank != other.revisionRank) return false;
    final otherEmitted = DateTime.tryParse(other.emittedAt);
    final thisEmitted = DateTime.tryParse(emittedAt);
    if (otherEmitted != null && thisEmitted != null) {
      if (thisEmitted.isBefore(otherEmitted)) return true;
      if (thisEmitted.isAtSameMomentAs(otherEmitted) &&
          sequence < other.sequence) {
        return true;
      }
    } else if (sequence < other.sequence) {
      return true;
    }
    return false;
  }

  List<String> get userFacingLabels {
    final labels = <String>[];
    if (technicalValidation.completed) {
      labels.add('기술검증 완료');
    } else if (technicalValidation.status.isNotEmpty) {
      labels.add('기술검증 ${technicalValidation.status}');
    }
    switch (ownerReview.decision) {
      case 'approved':
        labels.add('소유자 승인');
      case 'changes_requested':
        labels.add('보완요청');
      case 'pending':
        labels.add('소유자 검토 대기');
    }
    if (revision.isNotEmpty) labels.add(revision);
    if (readiness.revisionRequired && !readiness.revisionReady) {
      labels.add('R2 준비 필요');
    }
    if (readiness.revisionReady) labels.add('R2 준비 완료');
    if (ownerReview.step16Blocked) labels.add('16단계 차단');
    if (userLabelKo.isNotEmpty && !labels.contains(userLabelKo)) {
      labels.insert(0, userLabelKo);
    }
    return labels;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion > 0 ? schemaVersion : kSchemaVersion,
    'eventId': eventId,
    'instructionId': instructionId,
    'projectId': projectId,
    'jobId': jobId,
    'artifactType': artifactType,
    'contentSubtype': contentSubtype,
    'siteSubtype': siteSubtype,
    'displayTitle': displayTitle,
    'revision': revision,
    'sourceRevision': sourceRevision,
    'stageId': stageId,
    'stageOrder': stageOrder,
    'stageStatus': stageStatus,
    'verifiedThroughStep': verifiedThroughStep,
    'lastVerifiedStage': lastVerifiedStage,
    'productionStatus': productionStatus,
    'updatedAt': updatedAt,
    'emittedAt': emittedAt,
    'sequence': sequence,
    'technicalValidation': technicalValidation.toJson(),
    'ownerReview': ownerReview.toJson(),
    'execution': execution.toJson(),
    'readiness': readiness.toJson(),
    'problem': problem.toJson(),
    'userLabelKo': userLabelKo,
    'nextActionKo': nextActionKo,
    'initialSync': initialSync,
    'syncKind': syncKind,
    'contentFingerprint': contentFingerprint,
  };

  factory ProductionReviewStatusEnvelope.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ProductionReviewStatusEnvelope(schemaVersion: 0);
    }
    final tech = json['technicalValidation'];
    final owner = json['ownerReview'];
    final exec = json['execution'];
    final ready = json['readiness'];
    final prob = json['problem'];
    final syncKindRaw = '${json['syncKind'] ?? ''}'.trim();
    final syncKind = (syncKindRaw == 'baseline' || syncKindRaw == 'transition')
        ? syncKindRaw
        : '';
    return ProductionReviewStatusEnvelope(
      schemaVersion: _asInt(json['schemaVersion'], kSchemaVersion),
      eventId: '${json['eventId'] ?? ''}',
      instructionId: '${json['instructionId'] ?? ''}',
      projectId: '${json['projectId'] ?? ''}',
      jobId: '${json['jobId'] ?? ''}',
      artifactType: '${json['artifactType'] ?? ''}',
      contentSubtype: '${json['contentSubtype'] ?? ''}',
      siteSubtype: '${json['siteSubtype'] ?? ''}',
      displayTitle: '${json['displayTitle'] ?? ''}',
      revision: '${json['revision'] ?? ''}',
      sourceRevision: '${json['sourceRevision'] ?? ''}',
      stageId: '${json['stageId'] ?? ''}',
      stageOrder: _asInt(json['stageOrder']),
      stageStatus: '${json['stageStatus'] ?? ''}',
      verifiedThroughStep: _asInt(json['verifiedThroughStep']),
      lastVerifiedStage: '${json['lastVerifiedStage'] ?? ''}',
      productionStatus: '${json['productionStatus'] ?? ''}',
      updatedAt: '${json['updatedAt'] ?? ''}',
      emittedAt: '${json['emittedAt'] ?? ''}',
      sequence: _asInt(json['sequence']),
      technicalValidation: ProductionReviewTechnicalValidation.fromJson(
        tech is Map ? Map<String, dynamic>.from(tech) : null,
      ),
      ownerReview: ProductionReviewOwnerReview.fromJson(
        owner is Map ? Map<String, dynamic>.from(owner) : null,
      ),
      execution: ProductionReviewExecution.fromJson(
        exec is Map ? Map<String, dynamic>.from(exec) : null,
      ),
      readiness: ProductionReviewReadiness.fromJson(
        ready is Map ? Map<String, dynamic>.from(ready) : null,
      ),
      problem: ProductionReviewProblem.fromJson(
        prob is Map ? Map<String, dynamic>.from(prob) : null,
      ),
      userLabelKo: '${json['userLabelKo'] ?? ''}',
      nextActionKo: '${json['nextActionKo'] ?? ''}',
      initialSync: json['initialSync'] == true,
      syncKind: syncKind,
      contentFingerprint: '${json['contentFingerprint'] ?? ''}',
    );
  }

  ProductionReviewStatusEnvelope copyWith({
    int? schemaVersion,
    String? eventId,
    String? instructionId,
    String? projectId,
    String? jobId,
    String? artifactType,
    String? contentSubtype,
    String? siteSubtype,
    String? displayTitle,
    String? revision,
    String? sourceRevision,
    String? stageId,
    int? stageOrder,
    String? stageStatus,
    int? verifiedThroughStep,
    String? lastVerifiedStage,
    String? productionStatus,
    String? updatedAt,
    String? emittedAt,
    int? sequence,
    ProductionReviewTechnicalValidation? technicalValidation,
    ProductionReviewOwnerReview? ownerReview,
    ProductionReviewExecution? execution,
    ProductionReviewReadiness? readiness,
    ProductionReviewProblem? problem,
    String? userLabelKo,
    String? nextActionKo,
    bool? initialSync,
    String? syncKind,
    String? contentFingerprint,
  }) {
    return ProductionReviewStatusEnvelope(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      eventId: eventId ?? this.eventId,
      instructionId: instructionId ?? this.instructionId,
      projectId: projectId ?? this.projectId,
      jobId: jobId ?? this.jobId,
      artifactType: artifactType ?? this.artifactType,
      contentSubtype: contentSubtype ?? this.contentSubtype,
      siteSubtype: siteSubtype ?? this.siteSubtype,
      displayTitle: displayTitle ?? this.displayTitle,
      revision: revision ?? this.revision,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      stageId: stageId ?? this.stageId,
      stageOrder: stageOrder ?? this.stageOrder,
      stageStatus: stageStatus ?? this.stageStatus,
      verifiedThroughStep: verifiedThroughStep ?? this.verifiedThroughStep,
      lastVerifiedStage: lastVerifiedStage ?? this.lastVerifiedStage,
      productionStatus: productionStatus ?? this.productionStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      emittedAt: emittedAt ?? this.emittedAt,
      sequence: sequence ?? this.sequence,
      technicalValidation: technicalValidation ?? this.technicalValidation,
      ownerReview: ownerReview ?? this.ownerReview,
      execution: execution ?? this.execution,
      readiness: readiness ?? this.readiness,
      problem: problem ?? this.problem,
      userLabelKo: userLabelKo ?? this.userLabelKo,
      nextActionKo: nextActionKo ?? this.nextActionKo,
      initialSync: initialSync ?? this.initialSync,
      syncKind: syncKind ?? this.syncKind,
      contentFingerprint: contentFingerprint ?? this.contentFingerprint,
    );
  }
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((e) => '$e').toList();
}
