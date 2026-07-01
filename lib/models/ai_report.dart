class AiReport {
  const AiReport({
    required this.id,
    required this.aiName,
    required this.department,
    required this.summary,
    required this.risk,
    required this.recommendation,
    required this.nextCommand,
    this.reportedAt,
  });

  final String id;
  final String aiName;
  final String department;
  final String summary;
  final String risk;
  final String recommendation;
  final String nextCommand;
  final String? reportedAt;
}

class AiDailySummary {
  const AiDailySummary({
    required this.topProblem,
    required this.fastestRevenueTask,
    required this.promotionNeededProject,
    required this.delayedTask,
    required this.financeCheckItem,
    required this.recommendedActions,
  });

  final String topProblem;
  final String fastestRevenueTask;
  final String promotionNeededProject;
  final String delayedTask;
  final String financeCheckItem;
  final List<String> recommendedActions;
}
