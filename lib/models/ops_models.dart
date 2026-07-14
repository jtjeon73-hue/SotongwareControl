import 'package:cloud_firestore/cloud_firestore.dart';

import 'ops_enums.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _str(dynamic v, [String d = '']) =>
    (v is String ? v : v?.toString() ?? d).trim();

class BusinessUnitDoc {
  const BusinessUnitDoc({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    this.currentFocus = '',
    this.nextAction = '',
    this.displayOrder = 0,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String status;
  final String currentFocus;
  final String nextAction;
  final int displayOrder;
  final DateTime? updatedAt;

  factory BusinessUnitDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BusinessUnitDoc(
      id: doc.id,
      name: _str(d['name'], doc.id),
      description: _str(d['description']),
      status: _str(d['status'], '확인 필요'),
      currentFocus: _str(d['currentFocus']),
      nextAction: _str(d['nextAction']),
      displayOrder: (d['displayOrder'] as num?)?.toInt() ?? 0,
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'status': status,
    'currentFocus': currentFocus,
    'nextAction': nextAction,
    'displayOrder': displayOrder,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class ProjectDoc {
  const ProjectDoc({
    required this.id,
    required this.businessUnitId,
    required this.name,
    this.description = '',
    this.projectType = '',
    this.status = 'not_started',
    this.progress,
    this.currentStage = '',
    this.totalStages = 0,
    this.completedStages = 0,
    this.repositoryUrl = '',
    this.websiteUrl = '',
    this.firebaseUrl = '',
    this.promoUrl = '',
    this.apkUrl = '',
    this.pdfUrl = '',
    this.otherUrl = '',
    this.priority = 'normal',
    this.nextAction = '',
    this.holdReason = '',
    this.needsCeoReview = false,
    this.startedAt,
    this.targetDate,
    this.lastWorkedAt,
    this.updatedAt,
  });

  final String id;
  final String businessUnitId;
  final String name;
  final String description;
  final String projectType;
  final String status;
  final int? progress;
  final String currentStage;
  final int totalStages;
  final int completedStages;
  final String repositoryUrl;
  final String websiteUrl;
  final String firebaseUrl;
  final String promoUrl;
  final String apkUrl;
  final String pdfUrl;
  final String otherUrl;
  final String priority;
  final String nextAction;
  final String holdReason;
  final bool needsCeoReview;
  final DateTime? startedAt;
  final DateTime? targetDate;
  final DateTime? lastWorkedAt;
  final DateTime? updatedAt;

  int? get computedProgress {
    if (progress != null) return progress!.clamp(0, 100);
    if (totalStages > 0) {
      return ((completedStages / totalStages) * 100).round().clamp(0, 100);
    }
    return null;
  }

  /// updatedAt 또는 lastWorkedAt 기준 30일 이상이면 true. 기준일 없으면 false.
  bool get isStale {
    final base = updatedAt ?? lastWorkedAt;
    if (base == null) return false;
    return DateTime.now().difference(base).inDays >= 30;
  }

  ProjectDoc copyWith({
    String? businessUnitId,
    String? name,
    String? description,
    String? projectType,
    String? status,
    int? progress,
    bool clearProgress = false,
    String? currentStage,
    int? totalStages,
    int? completedStages,
    String? repositoryUrl,
    String? websiteUrl,
    String? firebaseUrl,
    String? promoUrl,
    String? apkUrl,
    String? pdfUrl,
    String? otherUrl,
    String? priority,
    String? nextAction,
    String? holdReason,
    bool? needsCeoReview,
    DateTime? startedAt,
    DateTime? targetDate,
    DateTime? lastWorkedAt,
  }) {
    return ProjectDoc(
      id: id,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      name: name ?? this.name,
      description: description ?? this.description,
      projectType: projectType ?? this.projectType,
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      currentStage: currentStage ?? this.currentStage,
      totalStages: totalStages ?? this.totalStages,
      completedStages: completedStages ?? this.completedStages,
      repositoryUrl: repositoryUrl ?? this.repositoryUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      firebaseUrl: firebaseUrl ?? this.firebaseUrl,
      promoUrl: promoUrl ?? this.promoUrl,
      apkUrl: apkUrl ?? this.apkUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      otherUrl: otherUrl ?? this.otherUrl,
      priority: priority ?? this.priority,
      nextAction: nextAction ?? this.nextAction,
      holdReason: holdReason ?? this.holdReason,
      needsCeoReview: needsCeoReview ?? this.needsCeoReview,
      startedAt: startedAt ?? this.startedAt,
      targetDate: targetDate ?? this.targetDate,
      lastWorkedAt: lastWorkedAt ?? this.lastWorkedAt,
      updatedAt: updatedAt,
    );
  }

  factory ProjectDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ProjectDoc(
      id: doc.id,
      businessUnitId: _str(d['businessUnitId']),
      name: _str(d['name'], doc.id),
      description: _str(d['description']),
      projectType: _str(d['projectType']),
      status: _str(d['status'], 'not_started'),
      progress: (d['progress'] as num?)?.toInt(),
      currentStage: _str(d['currentStage']),
      totalStages: (d['totalStages'] as num?)?.toInt() ?? 0,
      completedStages: (d['completedStages'] as num?)?.toInt() ?? 0,
      repositoryUrl: _str(d['repositoryUrl']),
      websiteUrl: _str(d['websiteUrl']),
      firebaseUrl: _str(d['firebaseUrl']),
      promoUrl: _str(d['promoUrl']),
      apkUrl: _str(d['apkUrl']),
      pdfUrl: _str(d['pdfUrl']),
      otherUrl: _str(d['otherUrl']),
      priority: _str(d['priority'], 'normal'),
      nextAction: _str(d['nextAction']),
      holdReason: _str(d['holdReason']),
      needsCeoReview: d['needsCeoReview'] == true,
      startedAt: _ts(d['startedAt']),
      targetDate: _ts(d['targetDate']),
      lastWorkedAt: _ts(d['lastWorkedAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) => {
    'businessUnitId': businessUnitId,
    'name': name,
    'description': description,
    'projectType': projectType,
    'status': status,
    'progress': progress,
    'currentStage': currentStage,
    'totalStages': totalStages,
    'completedStages': completedStages,
    'repositoryUrl': repositoryUrl,
    'websiteUrl': websiteUrl,
    'firebaseUrl': firebaseUrl,
    'promoUrl': promoUrl,
    'apkUrl': apkUrl,
    'pdfUrl': pdfUrl,
    'otherUrl': otherUrl,
    'priority': priority,
    'nextAction': nextAction,
    'holdReason': holdReason,
    'needsCeoReview': needsCeoReview,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
    'lastWorkedAt': lastWorkedAt == null
        ? null
        : Timestamp.fromDate(lastWorkedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
  };
}

class TaskDoc {
  const TaskDoc({
    required this.id,
    required this.title,
    this.projectId = '',
    this.businessUnitId = '',
    this.description = '',
    this.status = 'todo',
    this.priority = 'normal',
    this.source = 'manual',
    this.approved = false,
    this.dueDate,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String projectId;
  final String businessUnitId;
  final String description;
  final String status;
  final String priority;
  final String source;
  final bool approved;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  factory TaskDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TaskDoc(
      id: doc.id,
      title: _str(d['title']),
      projectId: _str(d['projectId']),
      businessUnitId: _str(d['businessUnitId']),
      description: _str(d['description']),
      status: _str(d['status'], 'todo'),
      priority: _str(d['priority'], 'normal'),
      source: _str(d['source'], 'manual'),
      approved: d['approved'] == true,
      dueDate: _ts(d['dueDate']),
      completedAt: _ts(d['completedAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'projectId': projectId,
    'businessUnitId': businessUnitId,
    'description': description,
    'status': status,
    'priority': priority,
    'source': source,
    'approved': approved,
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class WorkLogDoc {
  const WorkLogDoc({
    required this.id,
    required this.title,
    this.projectId = '',
    this.businessUnitId = '',
    this.workType = '',
    this.requestSummary = '',
    this.resultSummary = '',
    this.changedFiles = const [],
    this.analyzeResult = '',
    this.testResult = '',
    this.buildResult = '',
    this.commitMessage = '',
    this.commitHash = '',
    this.gitPushed = false,
    this.firebaseDeployed = false,
    this.siteVerified = false,
    this.issuesNote = '',
    this.source = 'manual',
    this.nextAction = '',
    this.workedAt,
  });

  final String id;
  final String title;
  final String projectId;
  final String businessUnitId;
  final String workType;
  final String requestSummary;
  final String resultSummary;
  final List<String> changedFiles;
  final String analyzeResult;
  final String testResult;
  final String buildResult;
  final String commitMessage;
  final String commitHash;
  final bool gitPushed;
  final bool firebaseDeployed;
  final bool siteVerified;
  final String issuesNote;
  final String source;
  final String nextAction;
  final DateTime? workedAt;

  Map<String, dynamic> toJsonExport() => {
    'id': id,
    'projectId': projectId,
    'businessUnitId': businessUnitId,
    'workType': workType,
    'title': title,
    'requestSummary': requestSummary,
    'resultSummary': resultSummary,
    'changedFiles': changedFiles,
    'analyzeResult': analyzeResult,
    'testResult': testResult,
    'buildResult': buildResult,
    'commitMessage': commitMessage,
    'commitHash': commitHash,
    'gitPushed': gitPushed,
    'firebaseDeployed': firebaseDeployed,
    'siteVerified': siteVerified,
    'issuesNote': issuesNote,
    'source': source,
    'nextAction': nextAction,
    'workedAt': workedAt?.toIso8601String(),
  };

  factory WorkLogDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WorkLogDoc(
      id: doc.id,
      title: _str(d['title']),
      projectId: _str(d['projectId']),
      businessUnitId: _str(d['businessUnitId']),
      workType: _str(d['workType']),
      requestSummary: _str(d['requestSummary']),
      resultSummary: _str(d['resultSummary']),
      changedFiles: ((d['changedFiles'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      analyzeResult: _str(d['analyzeResult']),
      testResult: _str(d['testResult']),
      buildResult: _str(d['buildResult']),
      commitMessage: _str(d['commitMessage']),
      commitHash: _str(d['commitHash']),
      gitPushed: d['gitPushed'] == true,
      firebaseDeployed: d['firebaseDeployed'] == true,
      siteVerified: d['siteVerified'] == true,
      issuesNote: _str(d['issuesNote']),
      source: _str(d['source'], 'manual'),
      nextAction: _str(d['nextAction']),
      workedAt: _ts(d['workedAt']),
    );
  }

  factory WorkLogDoc.fromJsonMap(Map<String, dynamic> m, {String id = ''}) {
    return WorkLogDoc(
      id: id,
      title: _str(m['title']),
      projectId: _str(m['projectId'] ?? m['moduleId']),
      businessUnitId: _str(m['businessUnitId']),
      workType: _str(m['workType']),
      requestSummary: _str(m['requestSummary']),
      resultSummary: _str(m['resultSummary']),
      changedFiles: ((m['changedFiles'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      analyzeResult: _str(m['analyzeResult']),
      testResult: _str(m['testResult']),
      buildResult: _str(m['buildResult']),
      commitMessage: _str(m['commitMessage']),
      commitHash: _str(m['commitHash']),
      gitPushed: m['gitPushed'] == true,
      firebaseDeployed: m['firebaseDeployed'] == true,
      siteVerified: m['siteVerified'] == true,
      issuesNote: _str(
        m['issuesNote'] ?? ((m['errors'] as List?) ?? []).join('; '),
      ),
      source: _str(m['source'], WorkLogSource.jsonImport),
      nextAction: _str(m['nextAction']),
      workedAt: _ts(m['workedAt'] ?? m['workDate']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'projectId': projectId,
    'businessUnitId': businessUnitId,
    'workType': workType,
    'requestSummary': requestSummary,
    'resultSummary': resultSummary,
    'changedFiles': changedFiles,
    'analyzeResult': analyzeResult,
    'testResult': testResult,
    'buildResult': buildResult,
    'commitMessage': commitMessage,
    'commitHash': commitHash,
    'gitPushed': gitPushed,
    'firebaseDeployed': firebaseDeployed,
    'siteVerified': siteVerified,
    'issuesNote': issuesNote,
    'source': source,
    'nextAction': nextAction,
    'workedAt': workedAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(workedAt!),
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class DeploymentDoc {
  const DeploymentDoc({
    required this.id,
    required this.projectId,
    this.flutterClean = DeployStepStatus.notChecked,
    this.flutterPubGet = DeployStepStatus.notChecked,
    this.flutterAnalyze = DeployStepStatus.notChecked,
    this.flutterTest = DeployStepStatus.notChecked,
    this.flutterBuildWeb = DeployStepStatus.notChecked,
    this.gitCommit = DeployStepStatus.notChecked,
    this.gitPush = DeployStepStatus.notChecked,
    this.firebaseDeploy = DeployStepStatus.notChecked,
    this.siteVerified = DeployStepStatus.notChecked,
    this.commitHash = '',
    this.commitMessage = '',
    this.siteUrl = '',
    this.verificationNote = '',
    this.deployedAt,
  });

  final String id;
  final String projectId;
  final String flutterClean;
  final String flutterPubGet;
  final String flutterAnalyze;
  final String flutterTest;
  final String flutterBuildWeb;
  final String gitCommit;
  final String gitPush;
  final String firebaseDeploy;
  final String siteVerified;
  final String commitHash;
  final String commitMessage;
  final String siteUrl;
  final String verificationNote;
  final DateTime? deployedAt;

  bool get isFullyComplete =>
      flutterAnalyze == DeployStepStatus.success &&
      flutterTest == DeployStepStatus.success &&
      flutterBuildWeb == DeployStepStatus.success &&
      gitCommit == DeployStepStatus.success &&
      gitPush == DeployStepStatus.success &&
      firebaseDeploy == DeployStepStatus.success &&
      siteVerified == DeployStepStatus.success;

  /// 배포 파이프라인은 됐으나 실사이트 미확인
  bool get deployOkSitePending {
    final pipelineOk =
        flutterAnalyze == DeployStepStatus.success &&
        flutterTest == DeployStepStatus.success &&
        flutterBuildWeb == DeployStepStatus.success &&
        gitCommit == DeployStepStatus.success &&
        gitPush == DeployStepStatus.success &&
        firebaseDeploy == DeployStepStatus.success;
    return pipelineOk && siteVerified != DeployStepStatus.success;
  }

  String get statusLabel {
    if (isFullyComplete) return '배포 완료';
    if (deployOkSitePending) return '배포 성공 / 실제 반영 확인 필요';
    return '확인 필요';
  }

  // 구 bool API 호환
  bool get analyzePassed => flutterAnalyze == DeployStepStatus.success;
  bool get testPassed => flutterTest == DeployStepStatus.success;
  bool get buildPassed => flutterBuildWeb == DeployStepStatus.success;
  bool get gitCommitted => gitCommit == DeployStepStatus.success;
  bool get gitPushed => gitPush == DeployStepStatus.success;
  bool get firebaseDeployed => firebaseDeploy == DeployStepStatus.success;
  bool get siteVerifiedBool => siteVerified == DeployStepStatus.success;

  factory DeploymentDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String step(String key, String? legacyBoolKey) {
      final v = d[key];
      if (v is String && v.isNotEmpty) return v;
      if (legacyBoolKey != null && d.containsKey(legacyBoolKey)) {
        return DeployStepStatus.fromBool(d[legacyBoolKey] == true);
      }
      return DeployStepStatus.notChecked;
    }

    return DeploymentDoc(
      id: doc.id,
      projectId: _str(d['projectId']),
      flutterClean: step('flutterClean', null),
      flutterPubGet: step('flutterPubGet', null),
      flutterAnalyze: step('flutterAnalyze', 'analyzePassed'),
      flutterTest: step('flutterTest', 'testPassed'),
      flutterBuildWeb: step('flutterBuildWeb', 'buildPassed'),
      gitCommit: step('gitCommit', 'gitCommitted'),
      gitPush: step('gitPush', 'gitPushed'),
      firebaseDeploy: step('firebaseDeploy', 'firebaseDeployed'),
      siteVerified: step('siteVerified', 'siteVerified'),
      commitHash: _str(d['commitHash']),
      commitMessage: _str(d['commitMessage']),
      siteUrl: _str(d['siteUrl']),
      verificationNote: _str(d['verificationNote']),
      deployedAt: _ts(d['deployedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'projectId': projectId,
    'flutterClean': flutterClean,
    'flutterPubGet': flutterPubGet,
    'flutterAnalyze': flutterAnalyze,
    'flutterTest': flutterTest,
    'flutterBuildWeb': flutterBuildWeb,
    'gitCommit': gitCommit,
    'gitPush': gitPush,
    'firebaseDeploy': firebaseDeploy,
    'siteVerified': siteVerified,
    // 구 필드 동기화 (대시보드 호환)
    'analyzePassed': analyzePassed,
    'testPassed': testPassed,
    'buildPassed': buildPassed,
    'gitCommitted': gitCommitted,
    'gitPushed': gitPushed,
    'firebaseDeployed': firebaseDeployed,
    'commitHash': commitHash,
    'commitMessage': commitMessage,
    'siteUrl': siteUrl,
    'verificationNote': verificationNote,
    'deployedAt': deployedAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(deployedAt!),
  };
}

class IssueDoc {
  const IssueDoc({
    required this.id,
    required this.title,
    this.projectId = '',
    this.description = '',
    this.severity = 'medium',
    this.status = 'open',
    this.cause = '',
    this.solution = '',
    this.detectedAt,
    this.resolvedAt,
  });

  final String id;
  final String title;
  final String projectId;
  final String description;
  final String severity;
  final String status;
  final String cause;
  final String solution;
  final DateTime? detectedAt;
  final DateTime? resolvedAt;

  factory IssueDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return IssueDoc(
      id: doc.id,
      title: _str(d['title']),
      projectId: _str(d['projectId']),
      description: _str(d['description']),
      severity: _str(d['severity'], 'medium'),
      status: _str(d['status'], 'open'),
      cause: _str(d['cause']),
      solution: _str(d['solution']),
      detectedAt: _ts(d['detectedAt']),
      resolvedAt: _ts(d['resolvedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'projectId': projectId,
    'description': description,
    'severity': severity,
    'status': status,
    'cause': cause,
    'solution': solution,
    'detectedAt': detectedAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(detectedAt!),
    'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
  };
}

class AiReportDoc {
  const AiReportDoc({
    required this.id,
    required this.departmentId,
    required this.title,
    this.reportType = 'summary',
    this.summary = '',
    this.findings = const [],
    this.recommendations = const [],
    this.approved = false,
    this.generatedAt,
    this.aiConnected = false,
  });

  final String id;
  final String departmentId;
  final String title;
  final String reportType;
  final String summary;
  final List<String> findings;
  final List<String> recommendations;
  final bool approved;
  final DateTime? generatedAt;
  final bool aiConnected;

  factory AiReportDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AiReportDoc(
      id: doc.id,
      departmentId: _str(d['departmentId']),
      title: _str(d['title']),
      reportType: _str(d['reportType'], 'summary'),
      summary: _str(d['summary']),
      findings: ((d['findings'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      recommendations: ((d['recommendations'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      approved: d['approved'] == true,
      generatedAt: _ts(d['generatedAt']),
      aiConnected: d['aiConnected'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'departmentId': departmentId,
    'title': title,
    'reportType': reportType,
    'summary': summary,
    'findings': findings,
    'recommendations': recommendations,
    'approved': approved,
    'aiConnected': aiConnected,
    'generatedAt': FieldValue.serverTimestamp(),
  };
}

class ActivityLogDoc {
  const ActivityLogDoc({
    required this.id,
    required this.action,
    required this.collection,
    required this.documentId,
    this.summary = '',
    this.actorUid = '',
    this.actorEmail = '',
    this.createdAt,
  });

  final String id;
  final String action;
  final String collection;
  final String documentId;
  final String summary;
  final String actorUid;
  final String actorEmail;
  final DateTime? createdAt;

  factory ActivityLogDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ActivityLogDoc(
      id: doc.id,
      action: _str(d['action']),
      collection: _str(d['collection']),
      documentId: _str(d['documentId']),
      summary: _str(d['summary']),
      actorUid: _str(d['actorUid']),
      actorEmail: _str(d['actorEmail']),
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'action': action,
    'collection': collection,
    'documentId': documentId,
    'summary': summary,
    'actorUid': actorUid,
    'actorEmail': actorEmail,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class IdeaDoc {
  const IdeaDoc({
    required this.id,
    required this.title,
    this.summary = '',
    this.category = '',
    this.status = IdeaStatus.idea,
    this.relatedBusinessUnitId = '',
    this.evaluation = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String status;
  final String relatedBusinessUnitId;
  final String evaluation;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory IdeaDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return IdeaDoc(
      id: doc.id,
      title: _str(d['title']),
      summary: _str(d['summary']),
      category: _str(d['category']),
      status: _str(d['status'], IdeaStatus.idea),
      relatedBusinessUnitId: _str(d['relatedBusinessUnitId']),
      evaluation: _str(d['evaluation']),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'summary': summary,
    'category': category,
    'status': status,
    'relatedBusinessUnitId': relatedBusinessUnitId,
    'evaluation': evaluation,
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  };
}
