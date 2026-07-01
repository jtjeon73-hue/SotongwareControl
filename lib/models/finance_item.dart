enum FinanceCategory {
  revenue,
  expense,
  tax,
  invoice,
  business,
  subscription,
  investment,
  expansion,
}

class FinanceItem {
  const FinanceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.statusText,
    required this.actionNeeded,
    this.amountHint,
    this.cautionNote,
  });

  final String id;
  final String title;
  final String description;
  final FinanceCategory category;
  final String statusText;
  final String actionNeeded;
  final String? amountHint;
  final String? cautionNote;
}

class ExpansionCandidate {
  const ExpansionCandidate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.priority,
    required this.expectedProfitability,
    required this.requiredPreparation,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String priority;
  final String expectedProfitability;
  final List<String> requiredPreparation;
}

class OperationalOverview {
  const OperationalOverview({
    required this.overallHealthScore,
    required this.overallHealthLabel,
    required this.overallHealthDetail,
    required this.todayFocusCount,
    required this.delayedProjectCount,
    required this.revenueReadyCount,
    required this.promotionNeededCount,
    required this.taxCheckCount,
    required this.aiReportPendingCount,
    required this.weeklyPriorityCount,
  });

  final int overallHealthScore;
  final String overallHealthLabel;
  final String overallHealthDetail;
  final int todayFocusCount;
  final int delayedProjectCount;
  final int revenueReadyCount;
  final int promotionNeededCount;
  final int taxCheckCount;
  final int aiReportPendingCount;
  final int weeklyPriorityCount;
}
