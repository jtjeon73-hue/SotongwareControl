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
        return '진행 중';
      case awaitingApproval:
        return '승인 대기';
      case completed:
        return '완료';
      case error:
        return '오류';
      case revision:
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

  bool get hasOpenableResult {
    final u = resultUrl.trim();
    final p = previewUrl.trim();
    return _isHttpUrl(u) || _isHttpUrl(p);
  }

  static bool _isHttpUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
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

  /// null이면 통과, 문자열이면 거부 사유.
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
      return '현재 단계가 아닙니다. (요청 stageId 검증 실패)';
    }
    final awaiting =
        stage.status == Sotong24WorkStatus.awaitingApproval ||
        stage.approvalStatus == ApprovalStatus.pending;
    if (!awaiting) {
      return '승인 대기 상태가 아닙니다.';
    }

    for (final r in existingRequests) {
      if (r.stageId != stageId) continue;
      if (r.requestId == requestId &&
          (r.status == ApprovalStatus.approved ||
              r.status == ApprovalStatus.revisionRequested)) {
        return '이미 처리된 requestId 입니다.';
      }
      if (r.requestId != requestId &&
          (r.status == ApprovalStatus.approved ||
              r.status == ApprovalStatus.revisionRequested) &&
          r.processedAt.isNotEmpty) {
        return '이 단계의 승인 요청이 이미 처리되었습니다.';
      }
    }

    // activeRequestId가 있으면 동일 requestId로만 응답 가능 (위조·중복 방지)
    if (stage.activeRequestId.isNotEmpty &&
        stage.activeRequestId != requestId) {
      return 'requestId가 현재 대기 요청과 일치하지 않습니다.';
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

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
