import '../models/ops_enums.dart';
import '../models/ops_models.dart';

class DashboardKpis {
  const DashboardKpis({
    required this.unitCount,
    required this.projectCount,
    required this.inProgress,
    required this.completed,
    required this.onHold,
    required this.blocked,
    required this.todayTodos,
    required this.overdue,
    required this.deployNeedsCheck,
    required this.workLogs7d,
  });

  final int unitCount;
  final int projectCount;
  final int inProgress;
  final int completed;
  final int onHold;
  final int blocked;
  final int todayTodos;
  final int overdue;
  final int deployNeedsCheck;
  final int workLogs7d;
}

class DashboardService {
  DashboardKpis computeKpis({
    required List<BusinessUnitDoc> units,
    required List<ProjectDoc> projects,
    required List<TaskDoc> tasks,
    required List<WorkLogDoc> logs,
    required List<DeploymentDoc> deployments,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));

    int inProgress = 0, completed = 0, onHold = 0, blocked = 0;
    for (final p in projects) {
      switch (p.status) {
        case ProjectStatus.inProgress:
        case ProjectStatus.testing:
        case ProjectStatus.planning:
          inProgress++;
          break;
        case ProjectStatus.completed:
          completed++;
          break;
        case ProjectStatus.onHold:
          onHold++;
          break;
        case ProjectStatus.blocked:
          blocked++;
          break;
      }
    }

    final todayTodos = tasks
        .where(
          (t) =>
              t.status == TaskStatus.todo || t.status == TaskStatus.inProgress,
        )
        .length;

    final overdue = tasks.where((t) {
      if (t.dueDate == null) return false;
      if (t.status == TaskStatus.completed ||
          t.status == TaskStatus.cancelled) {
        return false;
      }
      return t.dueDate!.isBefore(todayStart);
    }).length;

    final deployNeeds = deployments.where((d) => !d.isFullyComplete).length;
    final logs7d = logs
        .where((l) => l.workedAt != null && l.workedAt!.isAfter(weekAgo))
        .length;

    return DashboardKpis(
      unitCount: units.length,
      projectCount: projects.length,
      inProgress: inProgress,
      completed: completed,
      onHold: onHold,
      blocked: blocked,
      todayTodos: todayTodos,
      overdue: overdue,
      deployNeedsCheck: deployNeeds,
      workLogs7d: logs7d,
    );
  }

  List<String> attentionItems({
    required List<ProjectDoc> projects,
    required List<TaskDoc> tasks,
    required List<IssueDoc> issues,
    required List<DeploymentDoc> deployments,
  }) {
    final items = <String>[];
    final now = DateTime.now();

    for (final i in issues.where((e) => e.status == 'open')) {
      if (i.severity == 'high' || i.severity == 'critical') {
        items.add('심각한 문제: ${i.title}');
      }
    }

    for (final t in tasks) {
      if (t.dueDate != null &&
          t.status != TaskStatus.completed &&
          t.dueDate!.isBefore(DateTime(now.year, now.month, now.day))) {
        items.add('기한 초과 업무: ${t.title}');
      }
    }

    for (final p in projects) {
      if (p.status == ProjectStatus.inProgress ||
          p.status == ProjectStatus.testing) {
        if (p.nextAction.trim().isEmpty) {
          items.add('다음 작업 미등록: ${p.name}');
        }
        if (p.lastWorkedAt != null &&
            now.difference(p.lastWorkedAt!).inDays >= 14) {
          items.add('장기간 작업 기록 없음: ${p.name}');
        }
      }
    }

    for (final d in deployments.where((e) => !e.isFullyComplete)) {
      if (d.deployOkSitePending) {
        items.add('배포 성공 / 실제 반영 확인 필요: ${d.projectId}');
      } else {
        items.add('배포 확인 미완료: ${d.projectId}');
      }
    }

    if (items.isEmpty) {
      items.add('등록된 긴급 확인 사항이 없습니다.');
    }
    return items;
  }

  /// 사업부 평균 진행률 — 계산 가능한 프로젝트만. 없으면 null.
  int? averageProgress(List<ProjectDoc> projects) {
    final values = projects
        .map((p) => p.computedProgress)
        .whereType<int>()
        .toList();
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }
}
