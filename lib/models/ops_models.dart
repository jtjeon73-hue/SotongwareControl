import 'package:cloud_firestore/cloud_firestore.dart';

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
      name: (d['name'] as String?)?.trim() ?? doc.id,
      description: (d['description'] as String?)?.trim() ?? '',
      status: (d['status'] as String?)?.trim() ?? '확인 필요',
      currentFocus: (d['currentFocus'] as String?)?.trim() ?? '',
      nextAction: (d['nextAction'] as String?)?.trim() ?? '',
      displayOrder: (d['displayOrder'] as num?)?.toInt() ?? 0,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
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
    this.priority = 'normal',
    this.nextAction = '',
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
  final String priority;
  final String nextAction;
  final DateTime? lastWorkedAt;
  final DateTime? updatedAt;

  /// 단계 또는 명시 progress만 사용. 데이터 없으면 null = 진행률 미설정
  int? get computedProgress {
    if (progress != null) return progress!.clamp(0, 100);
    if (totalStages > 0) {
      return ((completedStages / totalStages) * 100).round().clamp(0, 100);
    }
    return null;
  }

  factory ProjectDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ProjectDoc(
      id: doc.id,
      businessUnitId: (d['businessUnitId'] as String?) ?? '',
      name: (d['name'] as String?)?.trim() ?? doc.id,
      description: (d['description'] as String?)?.trim() ?? '',
      projectType: (d['projectType'] as String?)?.trim() ?? '',
      status: (d['status'] as String?)?.trim() ?? 'not_started',
      progress: (d['progress'] as num?)?.toInt(),
      currentStage: (d['currentStage'] as String?)?.trim() ?? '',
      totalStages: (d['totalStages'] as num?)?.toInt() ?? 0,
      completedStages: (d['completedStages'] as num?)?.toInt() ?? 0,
      repositoryUrl: (d['repositoryUrl'] as String?)?.trim() ?? '',
      websiteUrl: (d['websiteUrl'] as String?)?.trim() ?? '',
      firebaseUrl: (d['firebaseUrl'] as String?)?.trim() ?? '',
      promoUrl: (d['promoUrl'] as String?)?.trim() ?? '',
      priority: (d['priority'] as String?)?.trim() ?? 'normal',
      nextAction: (d['nextAction'] as String?)?.trim() ?? '',
      lastWorkedAt: (d['lastWorkedAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
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
    'priority': priority,
    'nextAction': nextAction,
    'lastWorkedAt': lastWorkedAt == null
        ? null
        : Timestamp.fromDate(lastWorkedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
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
      title: (d['title'] as String?)?.trim() ?? '',
      projectId: (d['projectId'] as String?) ?? '',
      businessUnitId: (d['businessUnitId'] as String?) ?? '',
      description: (d['description'] as String?)?.trim() ?? '',
      status: (d['status'] as String?) ?? 'todo',
      priority: (d['priority'] as String?) ?? 'normal',
      source: (d['source'] as String?) ?? 'manual',
      approved: d['approved'] == true,
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
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
    this.testResult = '',
    this.buildResult = '',
    this.commitHash = '',
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
  final String testResult;
  final String buildResult;
  final String commitHash;
  final String source;
  final String nextAction;
  final DateTime? workedAt;

  factory WorkLogDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WorkLogDoc(
      id: doc.id,
      title: (d['title'] as String?)?.trim() ?? '',
      projectId: (d['projectId'] as String?) ?? '',
      businessUnitId: (d['businessUnitId'] as String?) ?? '',
      workType: (d['workType'] as String?) ?? '',
      requestSummary: (d['requestSummary'] as String?) ?? '',
      resultSummary: (d['resultSummary'] as String?) ?? '',
      changedFiles: ((d['changedFiles'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      testResult: (d['testResult'] as String?) ?? '',
      buildResult: (d['buildResult'] as String?) ?? '',
      commitHash: (d['commitHash'] as String?) ?? '',
      source: (d['source'] as String?) ?? 'manual',
      nextAction: (d['nextAction'] as String?) ?? '',
      workedAt: (d['workedAt'] as Timestamp?)?.toDate(),
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
    'testResult': testResult,
    'buildResult': buildResult,
    'commitHash': commitHash,
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
    this.analyzePassed = false,
    this.testPassed = false,
    this.buildPassed = false,
    this.gitCommitted = false,
    this.gitPushed = false,
    this.firebaseDeployed = false,
    this.siteVerified = false,
    this.commitHash = '',
    this.siteUrl = '',
    this.verificationNote = '',
    this.deployedAt,
  });

  final String id;
  final String projectId;
  final bool analyzePassed;
  final bool testPassed;
  final bool buildPassed;
  final bool gitCommitted;
  final bool gitPushed;
  final bool firebaseDeployed;
  final bool siteVerified;
  final String commitHash;
  final String siteUrl;
  final String verificationNote;
  final DateTime? deployedAt;

  bool get isFullyComplete =>
      analyzePassed &&
      testPassed &&
      buildPassed &&
      gitCommitted &&
      gitPushed &&
      firebaseDeployed &&
      siteVerified;

  String get statusLabel => isFullyComplete ? '완료' : '확인 필요';

  factory DeploymentDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DeploymentDoc(
      id: doc.id,
      projectId: (d['projectId'] as String?) ?? '',
      analyzePassed: d['analyzePassed'] == true,
      testPassed: d['testPassed'] == true,
      buildPassed: d['buildPassed'] == true,
      gitCommitted: d['gitCommitted'] == true,
      gitPushed: d['gitPushed'] == true,
      firebaseDeployed: d['firebaseDeployed'] == true,
      siteVerified: d['siteVerified'] == true,
      commitHash: (d['commitHash'] as String?) ?? '',
      siteUrl: (d['siteUrl'] as String?) ?? '',
      verificationNote: (d['verificationNote'] as String?) ?? '',
      deployedAt: (d['deployedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'projectId': projectId,
    'analyzePassed': analyzePassed,
    'testPassed': testPassed,
    'buildPassed': buildPassed,
    'gitCommitted': gitCommitted,
    'gitPushed': gitPushed,
    'firebaseDeployed': firebaseDeployed,
    'siteVerified': siteVerified,
    'commitHash': commitHash,
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

  factory IssueDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return IssueDoc(
      id: doc.id,
      title: (d['title'] as String?)?.trim() ?? '',
      projectId: (d['projectId'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      severity: (d['severity'] as String?) ?? 'medium',
      status: (d['status'] as String?) ?? 'open',
      cause: (d['cause'] as String?) ?? '',
      solution: (d['solution'] as String?) ?? '',
      detectedAt: (d['detectedAt'] as Timestamp?)?.toDate(),
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
      departmentId: (d['departmentId'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      reportType: (d['reportType'] as String?) ?? 'summary',
      summary: (d['summary'] as String?) ?? '',
      findings: ((d['findings'] as List?) ?? const []).map((e) => '$e').toList(),
      recommendations: ((d['recommendations'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      approved: d['approved'] == true,
      generatedAt: (d['generatedAt'] as Timestamp?)?.toDate(),
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
