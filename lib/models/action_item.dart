enum ActionPriority { high, medium, low }

enum ActionStatus { scheduled, inProgress, done, delayed }

extension ActionPriorityX on ActionPriority {
  String get label {
    switch (this) {
      case ActionPriority.high:
        return '높음';
      case ActionPriority.medium:
        return '보통';
      case ActionPriority.low:
        return '낮음';
    }
  }

  static ActionPriority fromLabel(String value) {
    switch (value) {
      case '높음':
      case 'high':
      case 'critical':
        return ActionPriority.high;
      case '낮음':
      case 'low':
        return ActionPriority.low;
      default:
        return ActionPriority.medium;
    }
  }
}

extension ActionStatusX on ActionStatus {
  String get label {
    switch (this) {
      case ActionStatus.scheduled:
        return '예정';
      case ActionStatus.inProgress:
        return '진행중';
      case ActionStatus.done:
        return '완료';
      case ActionStatus.delayed:
        return '지연';
    }
  }

  static ActionStatus fromLabel(String value) {
    switch (value) {
      case '진행중':
      case 'inProgress':
        return ActionStatus.inProgress;
      case '완료':
      case 'done':
        return ActionStatus.done;
      case '지연':
      case 'delayed':
        return ActionStatus.delayed;
      case '예정':
      case 'scheduled':
      case 'pending':
      default:
        return ActionStatus.scheduled;
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
    this.status = ActionStatus.scheduled,
    this.memo = '',
    this.dueDateIso,
  });

  final String id;
  final String title;
  final String department;
  final ActionPriority priority;
  final ActionStatus status;
  final String dueText;
  final String expectedResult;
  final String memo;
  final String? dueDateIso;

  bool get isDone => status == ActionStatus.done;

  ActionItem copyWith({
    String? id,
    String? title,
    String? department,
    ActionPriority? priority,
    ActionStatus? status,
    String? dueText,
    String? expectedResult,
    String? memo,
    String? dueDateIso,
  }) {
    return ActionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      department: department ?? this.department,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueText: dueText ?? this.dueText,
      expectedResult: expectedResult ?? this.expectedResult,
      memo: memo ?? this.memo,
      dueDateIso: dueDateIso ?? this.dueDateIso,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'department': department,
    'priority': priority.name,
    'status': status.name,
    'dueText': dueText,
    'expectedResult': expectedResult,
    'memo': memo,
    'dueDateIso': dueDateIso,
  };

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id'] as String,
      title: json['title'] as String,
      department: json['department'] as String,
      priority: _parsePriority(json['priority'] as String?),
      status: ActionStatusX.fromLabel(json['status'] as String? ?? 'scheduled'),
      dueText: json['dueText'] as String? ?? '',
      expectedResult: json['expectedResult'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      dueDateIso: json['dueDateIso'] as String?,
    );
  }

  static ActionPriority _parsePriority(String? value) {
    if (value == null) return ActionPriority.medium;
    try {
      return ActionPriority.values.byName(value);
    } catch (_) {
      return ActionPriorityX.fromLabel(value);
    }
  }
}
