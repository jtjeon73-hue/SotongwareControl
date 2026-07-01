enum ActionPriority { low, medium, high, critical }

enum ActionStatus { pending, inProgress, done }

extension ActionPriorityX on ActionPriority {
  String get label {
    switch (this) {
      case ActionPriority.low:
        return '낮음';
      case ActionPriority.medium:
        return '보통';
      case ActionPriority.high:
        return '높음';
      case ActionPriority.critical:
        return '긴급';
    }
  }
}

class ActionItem {
  const ActionItem({
    required this.id,
    required this.title,
    required this.department,
    required this.priority,
    required this.dueText,
    required this.expectedResult,
    this.status = ActionStatus.pending,
  });

  final String id;
  final String title;
  final String department;
  final ActionPriority priority;
  final String dueText;
  final String expectedResult;
  final ActionStatus status;
}
