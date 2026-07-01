enum ImpactLevel { low, medium, high }

enum UrgencyLevel { low, medium, high }

enum IssueStatus { unresolved, responding, resolved, onHold }

extension ImpactLevelX on ImpactLevel {
  String get label {
    switch (this) {
      case ImpactLevel.low:
        return '낮음';
      case ImpactLevel.medium:
        return '보통';
      case ImpactLevel.high:
        return '높음';
    }
  }
}

extension UrgencyLevelX on UrgencyLevel {
  String get label {
    switch (this) {
      case UrgencyLevel.low:
        return '낮음';
      case UrgencyLevel.medium:
        return '보통';
      case UrgencyLevel.high:
        return '긴급';
    }
  }
}

extension IssueStatusX on IssueStatus {
  String get label {
    switch (this) {
      case IssueStatus.unresolved:
        return '미해결';
      case IssueStatus.responding:
        return '대응중';
      case IssueStatus.resolved:
        return '해결';
      case IssueStatus.onHold:
        return '보류';
    }
  }

  static IssueStatus fromLabel(String value) {
    switch (value) {
      case '대응중':
      case 'responding':
      case 'inProgress':
        return IssueStatus.responding;
      case '해결':
      case 'resolved':
        return IssueStatus.resolved;
      case '보류':
      case 'onHold':
        return IssueStatus.onHold;
      case '미해결':
      case 'unresolved':
      case 'open':
      default:
        return IssueStatus.unresolved;
    }
  }
}

class BusinessIssue {
  const BusinessIssue({
    required this.id,
    required this.title,
    required this.divisionName,
    required this.problem,
    required this.cause,
    required this.impactLevel,
    required this.urgencyLevel,
    required this.responsePlan,
    required this.assignedAiRole,
    required this.nextAction,
    this.status = IssueStatus.unresolved,
    this.memo = '',
  });

  final String id;
  final String title;
  final String divisionName;
  final String problem;
  final String cause;
  final ImpactLevel impactLevel;
  final UrgencyLevel urgencyLevel;
  final String responsePlan;
  final String assignedAiRole;
  final String nextAction;
  final IssueStatus status;
  final String memo;

  bool get isResolved => status == IssueStatus.resolved;

  BusinessIssue copyWith({
    String? id,
    String? title,
    String? divisionName,
    String? problem,
    String? cause,
    ImpactLevel? impactLevel,
    UrgencyLevel? urgencyLevel,
    String? responsePlan,
    String? assignedAiRole,
    String? nextAction,
    IssueStatus? status,
    String? memo,
  }) {
    return BusinessIssue(
      id: id ?? this.id,
      title: title ?? this.title,
      divisionName: divisionName ?? this.divisionName,
      problem: problem ?? this.problem,
      cause: cause ?? this.cause,
      impactLevel: impactLevel ?? this.impactLevel,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      responsePlan: responsePlan ?? this.responsePlan,
      assignedAiRole: assignedAiRole ?? this.assignedAiRole,
      nextAction: nextAction ?? this.nextAction,
      status: status ?? this.status,
      memo: memo ?? this.memo,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'divisionName': divisionName,
    'problem': problem,
    'cause': cause,
    'impactLevel': impactLevel.name,
    'urgencyLevel': urgencyLevel.name,
    'responsePlan': responsePlan,
    'assignedAiRole': assignedAiRole,
    'nextAction': nextAction,
    'status': status.name,
    'memo': memo,
  };

  factory BusinessIssue.fromJson(Map<String, dynamic> json) {
    return BusinessIssue(
      id: json['id'] as String,
      title: json['title'] as String,
      divisionName: json['divisionName'] as String,
      problem: json['problem'] as String,
      cause: json['cause'] as String,
      impactLevel: _parseImpact(json['impactLevel'] as String?),
      urgencyLevel: _parseUrgency(json['urgencyLevel'] as String?),
      responsePlan: json['responsePlan'] as String? ?? '',
      assignedAiRole: json['assignedAiRole'] as String? ?? '',
      nextAction: json['nextAction'] as String? ?? '',
      status: IssueStatusX.fromLabel(json['status'] as String? ?? 'unresolved'),
      memo: json['memo'] as String? ?? '',
    );
  }

  static ImpactLevel _parseImpact(String? value) {
    if (value == null) return ImpactLevel.medium;
    try {
      return ImpactLevel.values.byName(value);
    } catch (_) {
      return ImpactLevel.medium;
    }
  }

  static UrgencyLevel _parseUrgency(String? value) {
    if (value == null) return UrgencyLevel.medium;
    try {
      return UrgencyLevel.values.byName(value);
    } catch (_) {
      return UrgencyLevel.medium;
    }
  }
}
