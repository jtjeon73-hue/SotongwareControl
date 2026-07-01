enum ImpactLevel { low, medium, high }

enum UrgencyLevel { low, medium, high }

enum IssueStatus { open, inProgress, resolved }

extension ImpactLevelX on ImpactLevel {
  String get label {
    switch (this) {
      case ImpactLevel.low:
        return '낮음';
      case ImpactLevel.medium:
        return '중간';
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
        return '중간';
      case UrgencyLevel.high:
        return '높음';
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
    this.status = IssueStatus.open,
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
}
