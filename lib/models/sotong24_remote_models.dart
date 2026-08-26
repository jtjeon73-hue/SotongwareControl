import '../services/business_planning_service.dart';
import 'artifact_type.dart';
import 'instruction_contract.dart';

/// PC Sotong24Work ↔ 소통총관제 원격 관제 상태.
class Sotong24PcLinkStatus {
  static const online = 'online';
  static const delayed = 'delayed';
  static const offline = 'offline';

  static String labelKo(String status) {
    switch (status) {
      case online:
        return '온라인';
      case delayed:
        return '연결 지연';
      case offline:
      default:
        return '오프라인';
    }
  }

  /// [lastHeartbeat] ISO8601 또는 null.
  /// 2분 이내 online, 10분 이내 delayed, 그 외 offline.
  static String fromHeartbeat(
    String? lastHeartbeat, {
    DateTime? now,
    Duration onlineWithin = const Duration(minutes: 2),
    Duration delayedWithin = const Duration(minutes: 10),
  }) {
    if (lastHeartbeat == null || lastHeartbeat.trim().isEmpty) {
      return offline;
    }
    final parsed = DateTime.tryParse(lastHeartbeat);
    if (parsed == null) return offline;
    final clock = now ?? DateTime.now().toUtc();
    final hb = parsed.toUtc();
    final age = clock.difference(hb);
    if (age <= onlineWithin) return online;
    if (age <= delayedWithin) return delayed;
    return offline;
  }
}

/// 프로젝트/단계 공통 진행 상태 (표시용).
class Sotong24WorkStatus {
  static const ready = 'ready';
  static const inProgress = 'in_progress';
  static const awaitingApproval = 'awaiting_approval';
  static const completed = 'completed';
  static const error = 'error';
  static const revision = 'revision';
  static const prelaunchReview = 'prelaunch_review';
  static const awaitingLaunchApproval = 'awaiting_launch_approval';
  static const launchApproved = 'launch_approved';
  static const launching = 'launching';
  static const launched = 'launched';
  static const notApplicable = 'not_applicable';
  static const pausedQuota = 'paused_quota';
  static const pausedNetwork = 'paused_network';
  static const stalled = 'stalled';
  static const aiProcessFailed = 'ai_process_failed';
  static const resultValidationFailed = 'result_validation_failed';
  static const resultValidationRetrying = 'result_validation_retrying';
  static const stageTransitionFailed = 'stage_transition_failed';

  static bool isNotApplicable(String? status) =>
      Sotong24UserFacingStatus.normalize(status) == notApplicable;

  static bool countsAsCompleted(String? status) =>
      Sotong24UserFacingStatus.normalize(status) == completed;

  static String labelKo(String status) {
    switch (status) {
      case ready:
        return '준비';
      case inProgress:
      case 'running':
        return '진행 중';
      case awaitingApproval:
      case 'waiting_approval':
      case 'awaiting_user_approval':
      case 'pending_review':
        return '승인 대기';
      case completed:
        return '완료';
      case prelaunchReview:
        return '제작 완료 · 출시 전 검토';
      case awaitingLaunchApproval:
        return '출시 승인 대기';
      case launchApproved:
        return '출시 승인 · 수동 등록 필요';
      case launching:
        return '출시 진행 중';
      case launched:
        return '출시 완료';
      case error:
        return '오류';
      case revision:
      case 'revision_requested':
      case 'reworking':
        return '보완 중';
      case notApplicable:
        return '해당 없음';
      case pausedQuota:
        return 'AI 사용량 초기화 대기';
      case pausedNetwork:
        return '네트워크 복구 대기';
      case stalled:
        return '작업 정체';
      case aiProcessFailed:
        return 'AI 실행 실패';
      case resultValidationFailed:
        return '결과 검증 최종 실패';
      case resultValidationRetrying:
        return '결과 검증 실패 · 자동 재시도 대기';
      case stageTransitionFailed:
        return '단계 전환 실패';
      default:
        return status;
    }
  }
}

class Sotong24RemoteStage {
  const Sotong24RemoteStage({
    required this.stageId,
    required this.stageNumber,
    required this.stageName,
    required this.status,
    this.summary = '',
    this.resultPreview = '',
    this.workReport = '',
    this.errorMessage = '',
    this.userAttention = '',
    this.resultUrl = '',
    this.previewUrl = '',
    this.approvalRequired = false,
    this.criteriaMet = false,
    this.approvalStatus = ApprovalStatus.notRequired,
    this.activeRequestId = '',
    this.updatedAt = '',
    this.revision = 0,
    this.startedAt = '',
    this.completedAt = '',
    this.workDurationMs = 0,
    this.lastActivityAt = '',
    this.activityState = '',
    this.activityType = '',
    this.activityProgress = 0,
    this.attemptCount = 0,
    this.maxAttempts = 0,
    this.retryCount = 0,
    this.maxRetries = 0,
    this.nextRetryAt = '',
    this.retryable = false,
    this.failureReason = '',
    this.failureType = '',
    this.recoveryAttempt = 0,
    this.maxRecoveryAttempts = 0,
    this.recoveryState = '',
  });

  final String stageId;
  final int stageNumber;
  final String stageName;
  final String status;
  final String summary;
  final String resultPreview;
  final String workReport;
  final String errorMessage;
  final String userAttention;
  final String resultUrl;
  final String previewUrl;
  final bool approvalRequired;
  final bool criteriaMet;
  final String approvalStatus;
  final String activeRequestId;
  final String updatedAt;

  /// Agent/stage_sync가 보낸 최신 revision. 0이면 미보고.
  final int revision;

  /// 실제 작업 시작. 없으면 빈 문자열 — 가짜 소요시간을 계산하지 않는다.
  final String startedAt;

  /// 실제 작업 완료. 없으면 빈 문자열.
  final String completedAt;

  /// Agent가 보고한 실제 AI 작업시간(ms). 승인 대기 제외. 0이면 미보고.
  final int workDurationMs;
  final String lastActivityAt;
  final String activityState;
  final String activityType;
  final int activityProgress;
  final int attemptCount;
  final int maxAttempts;
  final int retryCount;
  final int maxRetries;
  final String nextRetryAt;
  final bool retryable;
  final String failureReason;
  final String failureType;
  final int recoveryAttempt;
  final int maxRecoveryAttempts;
  final String recoveryState;

  bool get hasOpenableResult =>
      openableResultUrl != null || openablePreviewUrl != null;

  /// http(s) resultUrl — UI에 전체 URL 문자열을 노출하지 말고 버튼만 사용.
  String? get openableResultUrl {
    final u = resultUrl.trim();
    return isOpenableHttpUrl(u) ? u : null;
  }

  /// http(s) previewUrl. resultUrl과 동일하면 null (중복 버튼 방지).
  String? get openablePreviewUrl {
    final p = previewUrl.trim();
    if (!isOpenableHttpUrl(p)) return null;
    final r = resultUrl.trim();
    if (isOpenableHttpUrl(r) && p == r) return null;
    return p;
  }

  static bool isOpenableHttpUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('file:') ||
        lower.startsWith('vbscript:')) {
      return false;
    }
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(trimmed) ||
        trimmed.startsWith(r'\\') ||
        trimmed.contains(r'\')) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  Map<String, dynamic> toMap() => {
    'stageId': stageId,
    'stageNumber': stageNumber,
    'stageName': stageName,
    'status': status,
    'summary': summary,
    'resultPreview': resultPreview,
    'workReport': workReport,
    'errorMessage': errorMessage,
    'userAttention': userAttention,
    'resultUrl': resultUrl,
    'previewUrl': previewUrl,
    'approvalRequired': approvalRequired,
    'criteriaMet': criteriaMet,
    'approvalStatus': approvalStatus,
    'activeRequestId': activeRequestId,
    'updatedAt': updatedAt,
    if (revision > 0) 'revision': revision,
    if (startedAt.trim().isNotEmpty) 'startedAt': startedAt,
    if (completedAt.trim().isNotEmpty) 'completedAt': completedAt,
    if (workDurationMs > 0) 'workDurationMs': workDurationMs,
    if (lastActivityAt.trim().isNotEmpty) 'lastActivityAt': lastActivityAt,
    if (activityState.trim().isNotEmpty) 'activityState': activityState,
    if (activityType.trim().isNotEmpty) 'activityType': activityType,
    if (activityProgress > 0) 'activityProgress': activityProgress,
    if (attemptCount > 0) 'attemptCount': attemptCount,
    if (maxAttempts > 0) 'maxAttempts': maxAttempts,
    if (retryCount > 0) 'retryCount': retryCount,
    if (maxRetries > 0) 'maxRetries': maxRetries,
    if (nextRetryAt.trim().isNotEmpty) 'nextRetryAt': nextRetryAt,
    'retryable': retryable,
    if (failureReason.trim().isNotEmpty) 'failureReason': failureReason,
    if (failureType.trim().isNotEmpty) 'failureType': failureType,
    if (recoveryAttempt > 0) 'recoveryAttempt': recoveryAttempt,
    if (maxRecoveryAttempts > 0) 'maxRecoveryAttempts': maxRecoveryAttempts,
    if (recoveryState.trim().isNotEmpty) 'recoveryState': recoveryState,
  };

  factory Sotong24RemoteStage.fromMap(Map<String, dynamic> map, {String? id}) {
    final stageId = '${map['stageId'] ?? id ?? ''}'.trim();
    return Sotong24RemoteStage(
      stageId: stageId,
      stageNumber: _asInt(map['stageNumber']),
      stageName: '${map['stageName'] ?? ''}',
      status: '${map['status'] ?? Sotong24WorkStatus.ready}',
      summary: '${map['summary'] ?? ''}',
      resultPreview: '${map['resultPreview'] ?? ''}',
      workReport: '${map['workReport'] ?? ''}',
      errorMessage: '${map['errorMessage'] ?? ''}',
      userAttention: '${map['userAttention'] ?? ''}',
      resultUrl: '${map['resultUrl'] ?? ''}',
      previewUrl: '${map['previewUrl'] ?? ''}',
      approvalRequired: map['approvalRequired'] == true,
      criteriaMet: map['criteriaMet'] == true,
      approvalStatus: '${map['approvalStatus'] ?? ApprovalStatus.notRequired}',
      activeRequestId: '${map['activeRequestId'] ?? ''}',
      updatedAt: '${map['updatedAt'] ?? ''}',
      revision: _asInt(map['revision']),
      startedAt: '${map['startedAt'] ?? ''}',
      completedAt: '${map['completedAt'] ?? ''}',
      workDurationMs: _asInt(map['workDurationMs']),
      lastActivityAt: '${map['lastActivityAt'] ?? ''}',
      activityState: '${map['activityState'] ?? ''}',
      activityType: '${map['activityType'] ?? ''}',
      activityProgress: _asInt(map['activityProgress']).clamp(0, 100),
      attemptCount: _asInt(map['attemptCount']),
      maxAttempts: _asInt(map['maxAttempts']),
      retryCount: _asInt(map['retryCount']),
      maxRetries: _asInt(map['maxRetries']),
      nextRetryAt: '${map['nextRetryAt'] ?? ''}',
      retryable: map['retryable'] == true,
      failureReason: '${map['failureReason'] ?? ''}',
      failureType: '${map['failureType'] ?? ''}',
      recoveryAttempt: _asInt(map['recoveryAttempt']),
      maxRecoveryAttempts: _asInt(map['maxRecoveryAttempts']),
      recoveryState: '${map['recoveryState'] ?? ''}',
    );
  }

  Sotong24RemoteStage copyWith({
    String? status,
    String? summary,
    String? approvalStatus,
    bool? criteriaMet,
    String? activeRequestId,
    String? updatedAt,
    int? revision,
  }) {
    return Sotong24RemoteStage(
      stageId: stageId,
      stageNumber: stageNumber,
      stageName: stageName,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      resultPreview: resultPreview,
      workReport: workReport,
      errorMessage: errorMessage,
      userAttention: userAttention,
      resultUrl: resultUrl,
      previewUrl: previewUrl,
      approvalRequired: approvalRequired,
      criteriaMet: criteriaMet ?? this.criteriaMet,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      activeRequestId: activeRequestId ?? this.activeRequestId,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      startedAt: startedAt,
      completedAt: completedAt,
      workDurationMs: workDurationMs,
      lastActivityAt: lastActivityAt,
      activityState: activityState,
      activityType: activityType,
      activityProgress: activityProgress,
      attemptCount: attemptCount,
      maxAttempts: maxAttempts,
      retryCount: retryCount,
      maxRetries: maxRetries,
      nextRetryAt: nextRetryAt,
      retryable: retryable,
      failureReason: failureReason,
      failureType: failureType,
      recoveryAttempt: recoveryAttempt,
      maxRecoveryAttempts: maxRecoveryAttempts,
      recoveryState: recoveryState,
    );
  }
}

class Sotong24RemoteRequest {
  const Sotong24RemoteRequest({
    required this.requestId,
    required this.projectId,
    required this.stageId,
    required this.requestType,
    required this.status,
    this.message = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.processedAt = '',
    this.revision = 0,
    this.processed = false,
    this.workflowApplied = false,
    this.workflowAppliedAt = '',
  });

  final String requestId;
  final String projectId;
  final String stageId;

  /// approve | revision_request
  final String requestType;
  final String status;
  final String message;
  final String createdAt;
  final String updatedAt;
  final String processedAt;
  final int revision;
  final bool processed;
  final bool workflowApplied;
  final String workflowAppliedAt;

  Map<String, dynamic> toMap() => {
    'requestId': requestId,
    'projectId': projectId,
    'stageId': stageId,
    'requestType': requestType,
    'status': status,
    'message': message,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'processedAt': processedAt,
    if (revision > 0) 'revision': revision,
    'processed': processed,
    'workflowApplied': workflowApplied,
    if (workflowAppliedAt.isNotEmpty) 'workflowAppliedAt': workflowAppliedAt,
  };

  factory Sotong24RemoteRequest.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return Sotong24RemoteRequest(
      requestId: '${map['requestId'] ?? id ?? ''}',
      projectId: '${map['projectId'] ?? ''}',
      stageId: '${map['stageId'] ?? ''}',
      requestType: '${map['requestType'] ?? ''}',
      status: '${map['status'] ?? ApprovalStatus.pending}',
      message: '${map['message'] ?? ''}',
      createdAt: '${map['createdAt'] ?? ''}',
      updatedAt: '${map['updatedAt'] ?? ''}',
      processedAt: '${map['processedAt'] ?? ''}',
      revision: _asInt(map['revision']),
      processed: map['processed'] == true,
      workflowApplied: map['workflowApplied'] == true,
      workflowAppliedAt: '${map['workflowAppliedAt'] ?? ''}',
    );
  }
}

class Sotong24RemoteProject {
  const Sotong24RemoteProject({
    required this.projectId,
    required this.title,
    required this.productType,
    required this.currentStage,
    required this.totalStages,
    required this.progress,
    required this.status,
    this.contentSubtype = '',
    this.approvalStatus = ApprovalStatus.notRequired,
    this.pcStatus = Sotong24PcLinkStatus.offline,
    this.lastHeartbeat = '',
    this.startedAt = '',
    this.lastActivityAt = '',
    this.activityState = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.isDemo = false,
    this.environment = 'production',
    this.isTest = false,
    this.approvalMode = 'manual',
    this.productionStatus = 'ai_production',
    this.launchStatus = 'not_started',
    this.finalRevision = 1,
    this.productionCompletedAt = '',
    this.externalPublished = false,
    this.stages = const [],
  });

  final String projectId;
  final String title;
  final String productType;
  final String contentSubtype;
  final int currentStage;
  final int totalStages;
  final int progress;
  final String status;
  final String approvalStatus;
  final String pcStatus;
  final String lastHeartbeat;
  final String startedAt;
  final String lastActivityAt;
  final String activityState;
  final String createdAt;
  final String updatedAt;
  final bool isDemo;
  final String environment;
  final bool isTest;
  final String approvalMode;
  final String productionStatus;
  final String launchStatus;
  final int finalRevision;
  final String productionCompletedAt;
  final bool externalPublished;
  final List<Sotong24RemoteStage> stages;

  String get productTypeLabel {
    final base = ArtifactType.labelKo(productType);
    if (productType == ArtifactType.contents && contentSubtype.isNotEmpty) {
      return '$base · ${ContentSubtype.labelKo(contentSubtype)}';
    }
    return base;
  }

  String get resolvedPcStatus => pcStatus.isNotEmpty
      ? pcStatus
      : Sotong24PcLinkStatus.fromHeartbeat(lastHeartbeat);

  Sotong24RemoteStage? get currentStageDoc {
    if (stages.isEmpty) return null;
    for (final s in stages) {
      if (s.stageNumber == currentStage) return s;
    }
    return stages.last;
  }

  /// Agent/Firestore `progress` 필드(보고값). 단계 내부·보고 진행률일 수 있음.
  int get reportedProgressPercent => progress.clamp(0, 100);

  /// 완료 단계 수 기반 전체 제작 진행률. stages가 없으면 reportedProgress로 폴백.
  /// 프로젝트 상태가 completed이면 100으로 고정한다.
  int get overallProgressPercent {
    if (status == Sotong24WorkStatus.completed ||
        status == Sotong24WorkStatus.prelaunchReview ||
        productionStatus == 'prelaunch_review') {
      return 100;
    }
    final total = totalStages > 0
        ? totalStages
        : (stages.isNotEmpty ? stages.length : 0);
    if (total <= 0) return reportedProgressPercent;
    if (stages.isEmpty) return reportedProgressPercent;
    final notApplicable = stages
        .where((s) => Sotong24WorkStatus.isNotApplicable(s.status))
        .length;
    final completed = stages
        .where((s) => Sotong24WorkStatus.countsAsCompleted(s.status))
        .length;
    final denom = total - notApplicable;
    if (denom <= 0) return 0;
    return ((completed * 100) / denom).round().clamp(0, 100);
  }

  /// 카드/상세용 요약 — 「현재 단계」와 「전체 진행률」을 분리해 표시.
  String get progressSummaryLine {
    final pct = overallProgressPercent;
    if (status == Sotong24WorkStatus.completed || pct >= 100) {
      final n = totalStages > 0 ? totalStages : currentStage;
      return '전체 진행률 100%\n전체 $n단계 완료';
    }
    final name = currentStageDoc?.stageName.trim() ?? '';
    final stageLine = name.isEmpty
        ? (currentStage > 0 ? '$currentStage단계' : '단계 정보 없음')
        : '$currentStage단계 · $name';
    return '$stageLine\n전체 진행률 $pct%';
  }

  /// 목록에서 불완전/stale로 분류할 항목 (삭제하지 않고 UI만 구분).
  bool get isIncompleteListing {
    final t = title.trim();
    if (t.isEmpty) return true;
    if (t == '아직 찾지 못함' || t.contains('아직 찾지 못함')) return true;
    if (totalStages <= 0 && stages.isEmpty) return true;
    if (currentStage == 0 && totalStages == 0) return true;
    return false;
  }

  /// raw Agent progress를 진단용으로 보여줄지 (전체와 다를 때만).
  bool get showReportedProgressDiagnostic =>
      !isIncompleteListing &&
      stages.isNotEmpty &&
      reportedProgressPercent != overallProgressPercent;

  /// 「지금 할 일」 한 줄 문구 — project/stage 불일치 시 action 우선.
  String nowTodoHeadline({Sotong24RemoteStage? stage}) {
    return Sotong24UserFacingStatus.nowTodoHeadline(this, stageHint: stage);
  }

  /// 승인·보완 버튼 노출 (승인 대기일 때만, stage roll-up 포함).
  bool get showApprovalActions =>
      Sotong24UserFacingStatus.showApprovalActions(this);

  /// 목록/상세에 쓸 사용자용 상태 (stage roll-up).
  String get userFacingStatus => Sotong24UserFacingStatus.effective(this);

  String get userFacingStatusLabel =>
      Sotong24WorkStatus.labelKo(userFacingStatus);

  bool get isProductionComplete =>
      productionStatus == 'production_complete' ||
      productionStatus == 'prelaunch_review' ||
      status == Sotong24WorkStatus.completed ||
      status == Sotong24WorkStatus.prelaunchReview ||
      status == Sotong24WorkStatus.awaitingLaunchApproval ||
      status == Sotong24WorkStatus.launchApproved ||
      status == Sotong24WorkStatus.launching ||
      status == Sotong24WorkStatus.launched;

  bool get isLaunched => launchStatus == 'launched' && externalPublished;

  Map<String, dynamic> toMap() => {
    'projectId': projectId,
    'title': title,
    'productType': productType,
    'contentSubtype': contentSubtype,
    'currentStage': currentStage,
    'totalStages': totalStages,
    'progress': progress,
    'status': status,
    'approvalStatus': approvalStatus,
    'pcStatus': pcStatus,
    'lastHeartbeat': lastHeartbeat,
    'startedAt': startedAt,
    'lastActivityAt': lastActivityAt,
    'activityState': activityState,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'isDemo': isDemo,
    'environment': environment,
    'isTest': isTest,
    'approvalMode': approvalMode,
    'productionStatus': productionStatus,
    'launchStatus': launchStatus,
    'finalRevision': finalRevision,
    'productionCompletedAt': productionCompletedAt,
    'externalPublished': externalPublished,
  };

  factory Sotong24RemoteProject.fromMap(
    Map<String, dynamic> map, {
    String? id,
    List<Sotong24RemoteStage> stages = const [],
  }) {
    final projectId = '${map['projectId'] ?? id ?? ''}'.trim();
    final total = _asInt(map['totalStages']);
    final current = _asInt(map['currentStage']);
    return Sotong24RemoteProject(
      projectId: projectId,
      title: '${map['title'] ?? ''}',
      productType: ArtifactType.normalize('${map['productType'] ?? ''}'),
      contentSubtype: '${map['contentSubtype'] ?? ''}',
      currentStage: current,
      totalStages: total > 0 ? total : (stages.isNotEmpty ? stages.length : 0),
      progress: _asInt(map['progress']).clamp(0, 100),
      status: '${map['status'] ?? Sotong24WorkStatus.inProgress}',
      approvalStatus: '${map['approvalStatus'] ?? ApprovalStatus.notRequired}',
      pcStatus: '${map['pcStatus'] ?? ''}',
      lastHeartbeat: '${map['lastHeartbeat'] ?? ''}',
      startedAt: '${map['startedAt'] ?? ''}',
      lastActivityAt: '${map['lastActivityAt'] ?? ''}',
      activityState: '${map['activityState'] ?? ''}',
      createdAt: '${map['createdAt'] ?? ''}',
      updatedAt: '${map['updatedAt'] ?? ''}',
      isDemo: map['isDemo'] == true,
      environment: '${map['environment'] ?? 'production'}',
      isTest: map['isTest'] == true,
      approvalMode: '${map['approvalMode'] ?? ''}' == 'auto'
          ? 'auto'
          : 'manual',
      productionStatus:
          '${map['productionStatus'] ?? (map['status'] == 'prelaunch_review' ? 'prelaunch_review' : 'ai_production')}',
      launchStatus: '${map['launchStatus'] ?? 'not_started'}',
      finalRevision: _asInt(map['finalRevision']) > 0
          ? _asInt(map['finalRevision'])
          : 1,
      productionCompletedAt: '${map['productionCompletedAt'] ?? ''}',
      externalPublished: map['externalPublished'] == true,
      stages: stages,
    );
  }

  Sotong24RemoteProject copyWith({
    String? status,
    String? approvalStatus,
    String? updatedAt,
    List<Sotong24RemoteStage>? stages,
    int? progress,
    int? currentStage,
    String? productionStatus,
    String? launchStatus,
    int? finalRevision,
    String? productionCompletedAt,
    bool? externalPublished,
  }) {
    return Sotong24RemoteProject(
      projectId: projectId,
      title: title,
      productType: productType,
      contentSubtype: contentSubtype,
      currentStage: currentStage ?? this.currentStage,
      totalStages: totalStages,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      pcStatus: pcStatus,
      lastHeartbeat: lastHeartbeat,
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
      activityState: activityState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDemo: isDemo,
      environment: environment,
      isTest: isTest,
      approvalMode: approvalMode,
      productionStatus: productionStatus ?? this.productionStatus,
      launchStatus: launchStatus ?? this.launchStatus,
      finalRevision: finalRevision ?? this.finalRevision,
      productionCompletedAt:
          productionCompletedAt ?? this.productionCompletedAt,
      externalPublished: externalPublished ?? this.externalPublished,
      stages: stages ?? this.stages,
    );
  }
}

/// 승인/보완 요청 시 중복·스테이지 불일치 검증.
class Sotong24RemoteApprovalGuard {
  const Sotong24RemoteApprovalGuard();

  static bool isTerminalDecisionStatus(String status) {
    return status == ApprovalStatus.approved ||
        status == ApprovalStatus.revisionRequested;
  }

  /// 사용자 액션용 requestId 할당.
  ///
  /// - active/preferred 가 아직 없거나 pending(미처리)이면 재사용 (더블클릭·Agent 슬롯)
  /// - 같은 revision의 terminal id는 재사용해 guard가 중복 제출을 차단
  /// - stage revision이 증가한 경우에만 새 id 발급 (보완 후 r2 재승인)
  static String allocateRequestId({
    required Sotong24RemoteStage stage,
    required Iterable<Sotong24RemoteRequest> existingRequests,
    String preferred = '',
    DateTime? now,
  }) {
    final hint = preferred.trim().isNotEmpty
        ? preferred.trim()
        : stage.activeRequestId.trim();

    if (hint.isNotEmpty) {
      Sotong24RemoteRequest? found;
      for (final r in existingRequests) {
        if (r.requestId == hint) {
          found = r;
          break;
        }
      }
      final alreadyDecided =
          found != null && isTerminalDecisionStatus(found.status);
      final stageRevision = stage.revision > 0 ? stage.revision : 1;
      final requestRevision = found != null && found.revision > 0
          ? found.revision
          : 1;
      final sameRevision = requestRevision == stageRevision;
      if (!alreadyDecided) {
        return hint;
      }
      if (sameRevision) return hint;
    }

    final stamp = (now ?? DateTime.now().toUtc()).microsecondsSinceEpoch;
    return 'req_${stage.stageId}_$stamp';
  }

  /// null이면 통과, 문자열이면 거부 사유 (사용자용 문구).
  String? validateSubmit({
    required Sotong24RemoteProject project,
    required String stageId,
    required String requestId,
    required Iterable<Sotong24RemoteRequest> existingRequests,
  }) {
    if (project.projectId.trim().isEmpty) {
      return 'projectId가 없습니다.';
    }
    if (stageId.trim().isEmpty) {
      return 'stageId가 없습니다.';
    }
    if (requestId.trim().isEmpty) {
      return 'requestId가 없습니다.';
    }

    Sotong24RemoteStage? stage;
    for (final s in project.stages) {
      if (s.stageId == stageId) {
        stage = s;
        break;
      }
    }
    if (stage == null) {
      return '해당 단계를 찾을 수 없습니다.';
    }
    if (stage.stageNumber != project.currentStage) {
      return '현재 단계가 아닙니다. 화면을 새로고침한 뒤 다시 시도해 주세요.';
    }
    final awaiting =
        Sotong24UserFacingStatus.normalize(stage.status) ==
        Sotong24WorkStatus.awaitingApproval;
    if (!awaiting || !stage.approvalRequired || !stage.criteriaMet) {
      return '승인 대기 상태가 아닙니다. 잠시 후 상태를 새로 확인해 주세요.';
    }
    if (isTerminalDecisionStatus(stage.approvalStatus)) {
      return '승인·보완 요청을 Agent가 처리 중입니다. 잠시 후 상태를 새로 확인해 주세요.';
    }

    Sotong24RemoteRequest? activeReq;
    for (final r in existingRequests) {
      if (r.requestId == stage.activeRequestId) {
        activeReq = r;
      }
      if (r.stageId != stageId) continue;

      final stageRevision = stage.revision > 0 ? stage.revision : 1;
      final requestRevision = r.revision > 0 ? r.revision : 1;
      if (isTerminalDecisionStatus(r.status) &&
          requestRevision == stageRevision) {
        return '현재 결과 버전의 승인·보완 요청은 이미 Agent가 처리 중입니다. '
            '다음 단계 또는 새 보완 결과를 기다려 주세요.';
      }

      // 동일 requestId 재전송(더블클릭/재시도) 차단
      if (r.requestId == requestId && isTerminalDecisionStatus(r.status)) {
        return '이 승인·보완 요청은 이미 처리 중이거나 완료되었습니다. '
            '잠시 후 상태를 새로 확인해 주세요.';
      }

      // 아직 미처리 pending 이 다른 id 로 열려 있으면 그 슬롯에만 응답
      if (r.status == ApprovalStatus.pending && r.requestId != requestId) {
        return '이 단계에 대기 중인 다른 요청이 있습니다. '
            '화면을 새로고침한 뒤 다시 시도해 주세요.';
      }
    }

    // activeRequestId 가 "열린 슬롯"(문서 없음 또는 pending)일 때만 일치 강제.
    // 이미 처리된 revision_request id가 active에 남아 있는 r2 재승인 사이클은 새 id 허용.
    final activeId = stage.activeRequestId.trim();
    if (activeId.isNotEmpty && activeId != requestId) {
      final activeIsOpen =
          activeReq == null || activeReq.status == ApprovalStatus.pending;
      if (activeIsOpen) {
        return '현재 대기 요청과 일치하지 않습니다. '
            '화면을 새로고침한 뒤 다시 시도해 주세요.';
      }
    }
    return null;
  }
}

class Sotong24RemoteDemoCatalog {
  Sotong24RemoteDemoCatalog._();

  static const demoProjectId = 'demo_sotong24_ebook_001';

  static List<Sotong24RemoteProject> demoProjects({DateTime? now}) {
    final clock = now ?? DateTime.now().toUtc();
    final iso = clock.toIso8601String();
    final heartbeat = clock
        .subtract(const Duration(seconds: 40))
        .toIso8601String();
    final titles = BusinessPlanningService.standardWorkflowTitles;
    final stages = <Sotong24RemoteStage>[
      for (var i = 0; i < titles.length; i++)
        Sotong24RemoteStage(
          stageId: titles[i].$1,
          stageNumber: i + 1,
          stageName: titles[i].$2,
          status: i + 1 < 13
              ? Sotong24WorkStatus.completed
              : i + 1 == 13
              ? Sotong24WorkStatus.awaitingApproval
              : Sotong24WorkStatus.ready,
          summary: i + 1 == 13
              ? '표지·목차·3장까지 초안 완료. 사용자 확인이 필요합니다.'
              : i + 1 < 13
              ? '완료'
              : '',
          resultPreview: i + 1 == 13
              ? '전자책 초안 미리보기(데모). 실제 PDF는 PC/Storage URL로 연결됩니다.'
              : '',
          workReport: i + 1 == 13 ? '데모: 단계 작업 보고 샘플입니다.' : '',
          userAttention: i + 1 == 13 ? '표지 제목 크기와 3장 사례 구성을 확인해 주세요.' : '',
          previewUrl: i + 1 == 13 ? 'https://sotongware-control.web.app' : '',
          approvalRequired: i + 1 == 13 || i + 1 >= 16,
          criteriaMet: i + 1 <= 13,
          approvalStatus: i + 1 == 13
              ? ApprovalStatus.pending
              : ApprovalStatus.notRequired,
          activeRequestId: i + 1 == 13 ? 'demo_req_pending_13' : '',
          updatedAt: iso,
        ),
    ];

    final ebook = Sotong24RemoteProject(
      projectId: demoProjectId,
      title: '50대 초보도 따라 하는 AI 전자책 첫 출간',
      productType: ArtifactType.ebook,
      currentStage: 13,
      totalStages: titles.length,
      progress: 72,
      status: Sotong24WorkStatus.awaitingApproval,
      approvalStatus: ApprovalStatus.pending,
      pcStatus: Sotong24PcLinkStatus.online,
      lastHeartbeat: heartbeat,
      startedAt: clock.subtract(const Duration(days: 5)).toIso8601String(),
      createdAt: clock.subtract(const Duration(days: 5)).toIso8601String(),
      updatedAt: iso,
      isDemo: true,
      stages: stages,
    );

    final completed = Sotong24RemoteProject(
      projectId: 'demo_sotong24_site_done',
      title: '데모 · 지식사이트 1차 공개 (완료 샘플)',
      productType: ArtifactType.site,
      currentStage: 18,
      totalStages: 18,
      progress: 100,
      status: Sotong24WorkStatus.completed,
      approvalStatus: ApprovalStatus.approved,
      pcStatus: Sotong24PcLinkStatus.offline,
      lastHeartbeat: clock.subtract(const Duration(hours: 3)).toIso8601String(),
      startedAt: clock.subtract(const Duration(days: 20)).toIso8601String(),
      createdAt: clock.subtract(const Duration(days: 20)).toIso8601String(),
      updatedAt: clock.subtract(const Duration(days: 1)).toIso8601String(),
      isDemo: true,
      stages: [
        for (var i = 0; i < titles.length; i++)
          Sotong24RemoteStage(
            stageId: 'site_${titles[i].$1}',
            stageNumber: i + 1,
            stageName: titles[i].$2,
            status: Sotong24WorkStatus.completed,
            approvalStatus: ApprovalStatus.approved,
            updatedAt: iso,
          ),
      ],
    );

    return [ebook, completed];
  }
}

/// 제작공정 UI용 상태 roll-up (API contract 변경 없음).
class Sotong24UserFacingStatus {
  Sotong24UserFacingStatus._();

  static String normalize(String? raw) {
    final s = (raw ?? '').trim();
    switch (s) {
      case 'waiting_approval':
      case 'awaiting_user_approval':
      case 'pending_review':
        return Sotong24WorkStatus.awaitingApproval;
      case 'revision_requested':
      case 'reworking':
        return Sotong24WorkStatus.revision;
      case 'running':
        return Sotong24WorkStatus.inProgress;
      default:
        return s;
    }
  }

  static String effective(Sotong24RemoteProject project) {
    final projectStatus = normalize(project.status);
    final stage = project.currentStageDoc;
    final stageStatus = normalize(stage?.status);
    final approval = project.approvalStatus.trim();
    final stageApproval = (stage?.approvalStatus ?? '').trim();

    const interruptions = {
      Sotong24WorkStatus.pausedQuota,
      Sotong24WorkStatus.pausedNetwork,
      Sotong24WorkStatus.stalled,
      Sotong24WorkStatus.aiProcessFailed,
      Sotong24WorkStatus.resultValidationFailed,
      Sotong24WorkStatus.resultValidationRetrying,
      Sotong24WorkStatus.stageTransitionFailed,
    };
    if (interruptions.contains(stageStatus)) return stageStatus;
    if (interruptions.contains(projectStatus)) return projectStatus;

    if (projectStatus == Sotong24WorkStatus.error ||
        stageStatus == Sotong24WorkStatus.error) {
      return Sotong24WorkStatus.error;
    }
    if (projectStatus == Sotong24WorkStatus.revision ||
        stageStatus == Sotong24WorkStatus.revision ||
        approval == ApprovalStatus.revisionRequested ||
        stageApproval == ApprovalStatus.revisionRequested) {
      return Sotong24WorkStatus.revision;
    }
    if (projectStatus == Sotong24WorkStatus.awaitingApproval ||
        stageStatus == Sotong24WorkStatus.awaitingApproval ||
        approval == ApprovalStatus.pending ||
        stageApproval == ApprovalStatus.pending) {
      return Sotong24WorkStatus.awaitingApproval;
    }
    if (projectStatus == Sotong24WorkStatus.notApplicable) {
      return Sotong24WorkStatus.notApplicable;
    }
    if (projectStatus == Sotong24WorkStatus.launched || project.isLaunched) {
      return Sotong24WorkStatus.launched;
    }
    if (projectStatus == Sotong24WorkStatus.launching) {
      return Sotong24WorkStatus.launching;
    }
    if (projectStatus == Sotong24WorkStatus.launchApproved) {
      return Sotong24WorkStatus.launchApproved;
    }
    if (projectStatus == Sotong24WorkStatus.awaitingLaunchApproval) {
      return Sotong24WorkStatus.awaitingLaunchApproval;
    }
    if (projectStatus == Sotong24WorkStatus.prelaunchReview ||
        project.productionStatus == 'prelaunch_review') {
      return Sotong24WorkStatus.prelaunchReview;
    }
    if (projectStatus == Sotong24WorkStatus.completed) {
      return Sotong24WorkStatus.completed;
    }
    if (projectStatus == Sotong24WorkStatus.inProgress ||
        stageStatus == Sotong24WorkStatus.inProgress) {
      return Sotong24WorkStatus.inProgress;
    }
    if (projectStatus == Sotong24WorkStatus.ready) {
      final anyActive = project.stages.any((s) {
        final st = normalize(s.status);
        return st == Sotong24WorkStatus.inProgress ||
            st == Sotong24WorkStatus.awaitingApproval ||
            st == Sotong24WorkStatus.revision;
      });
      if (anyActive) return Sotong24WorkStatus.inProgress;
      return Sotong24WorkStatus.ready;
    }
    return projectStatus.isEmpty
        ? Sotong24WorkStatus.inProgress
        : projectStatus;
  }

  static bool showApprovalActions(Sotong24RemoteProject project) {
    final status = effective(project);
    if (status == Sotong24WorkStatus.completed) return false;
    if (status == Sotong24WorkStatus.error) return false;
    final stageApproval = project.currentStageDoc?.approvalStatus ?? '';
    final stage = project.currentStageDoc;
    if (stage == null ||
        !stage.approvalRequired ||
        !stage.criteriaMet ||
        Sotong24UserFacingStatus.normalize(stage.status) !=
            Sotong24WorkStatus.awaitingApproval) {
      return false;
    }
    if (Sotong24RemoteApprovalGuard.isTerminalDecisionStatus(stageApproval)) {
      return false;
    }
    // auto 모드에서는 일반 승인 버튼을 숨긴다. 확인 필요(userAttention)만 수동 개입.
    if (project.approvalMode == 'auto' && stage.userAttention.trim().isEmpty) {
      return false;
    }
    return status == Sotong24WorkStatus.awaitingApproval;
  }

  static String nowTodoHeadline(
    Sotong24RemoteProject project, {
    Sotong24RemoteStage? stageHint,
  }) {
    final status = effective(project);
    final stage = stageHint ?? project.currentStageDoc;
    final stageLabel = () {
      if (stage == null) return '현재 단계';
      final name = stage.stageName.trim();
      final n = stage.stageNumber;
      if (name.isEmpty) return '$n단계';
      return '$n단계 · $name';
    }();

    switch (status) {
      case Sotong24WorkStatus.error:
        return '작업 중 오류가 발생했습니다. 상세 내용을 확인해 주세요.';
      case Sotong24WorkStatus.revision:
        return '보완 작업이 진행될 예정입니다.';
      case Sotong24WorkStatus.awaitingApproval:
        if (stage?.approvalStatus == ApprovalStatus.approved) {
          return '승인 요청을 전송했습니다. Agent가 다음 단계를 준비 중입니다.';
        }
        if (stage?.hasOpenableResult == true) {
          return '결과물을 확인한 뒤 승인 또는 보완을 선택하세요.';
        }
        return '$stageLabel 결과를 확인해 주세요.';
      case Sotong24WorkStatus.inProgress:
        return 'AI가 작업 중입니다. 완료되면 결과를 확인할 수 있습니다.';
      case Sotong24WorkStatus.completed:
        return '작업이 완료되었습니다.';
      case Sotong24WorkStatus.ready:
        return '다음 단계 시작을 기다리고 있습니다.';
      case Sotong24WorkStatus.pausedQuota:
        return 'AI 사용량이 초기화되면 이 단계부터 자동으로 다시 시작합니다.';
      case Sotong24WorkStatus.pausedNetwork:
        return '네트워크 연결이 복구되면 이 단계부터 다시 시도합니다.';
      case Sotong24WorkStatus.stalled:
        return '작업 활동이 제한시간 동안 없어 복구 확인이 필요합니다.';
      case Sotong24WorkStatus.aiProcessFailed:
        return 'AI 프로세스 실행이 실패했습니다. 제한된 재시도 후 상세 원인을 표시합니다.';
      case Sotong24WorkStatus.resultValidationFailed:
        final retries = stage?.maxRetries ?? 0;
        return retries > 0
            ? '결과 검증이 최종 실패했습니다. 자동 재시도 $retries회가 모두 소진되었습니다.'
            : '생성 결과가 단계 완료 기준을 통과하지 못했습니다.';
      case Sotong24WorkStatus.resultValidationRetrying:
        final current = stage?.retryCount ?? 0;
        final max = stage?.maxRetries ?? 3;
        return '결과 검증 실패 · 자동 재시도 $current/$max 대기 중입니다.';
      case Sotong24WorkStatus.stageTransitionFailed:
        return '결과는 준비됐지만 다음 단계 전환에 실패했습니다.';
      default:
        return '$stageLabel 상태를 확인해 주세요.';
    }
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
