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
      case error:
        return '오류';
      case revision:
      case 'revision_requested':
      case 'reworking':
        return '보완 중';
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
    this.approvalStatus = ApprovalStatus.notRequired,
    this.activeRequestId = '',
    this.updatedAt = '',
    this.revision = 0,
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
  final String approvalStatus;
  final String activeRequestId;
  final String updatedAt;

  /// Agent/stage_sync가 보낸 최신 revision. 0이면 미보고.
  final int revision;

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
    'approvalStatus': approvalStatus,
    'activeRequestId': activeRequestId,
    'updatedAt': updatedAt,
    if (revision > 0) 'revision': revision,
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
      approvalStatus: '${map['approvalStatus'] ?? ApprovalStatus.notRequired}',
      activeRequestId: '${map['activeRequestId'] ?? ''}',
      updatedAt: '${map['updatedAt'] ?? ''}',
      revision: _asInt(map['revision']),
    );
  }

  Sotong24RemoteStage copyWith({
    String? status,
    String? summary,
    String? approvalStatus,
    String? activeRequestId,
    String? updatedAt,
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
      approvalStatus: approvalStatus ?? this.approvalStatus,
      activeRequestId: activeRequestId ?? this.activeRequestId,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision,
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
    this.createdAt = '',
    this.updatedAt = '',
    this.isDemo = false,
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
  final String createdAt;
  final String updatedAt;
  final bool isDemo;
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
    if (status == Sotong24WorkStatus.completed) return 100;
    final total = totalStages > 0
        ? totalStages
        : (stages.isNotEmpty ? stages.length : 0);
    if (total <= 0) return reportedProgressPercent;
    if (stages.isEmpty) return reportedProgressPercent;
    final completed = stages
        .where((s) => s.status == Sotong24WorkStatus.completed)
        .length;
    return ((completed * 100) / total).round().clamp(0, 100);
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
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'isDemo': isDemo,
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
      createdAt: '${map['createdAt'] ?? ''}',
      updatedAt: '${map['updatedAt'] ?? ''}',
      isDemo: map['isDemo'] == true,
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDemo: isDemo,
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
  /// - 이미 approved/revision_requested 로 처리된 id면 **새 id** (보완 후 r2 재승인)
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
      if (!alreadyDecided) {
        return hint;
      }
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
        stage.status == Sotong24WorkStatus.awaitingApproval ||
        stage.approvalStatus == ApprovalStatus.pending;
    if (!awaiting) {
      return '승인 대기 상태가 아닙니다. 잠시 후 상태를 새로 확인해 주세요.';
    }

    Sotong24RemoteRequest? activeReq;
    for (final r in existingRequests) {
      if (r.requestId == stage.activeRequestId) {
        activeReq = r;
      }
      if (r.stageId != stageId) continue;

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
