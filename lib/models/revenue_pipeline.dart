class RevenuePipeline {
  const RevenuePipeline({
    required this.id,
    required this.businessName,
    required this.targetCustomer,
    required this.revenueModel,
    required this.currentStage,
    required this.nextStep,
    required this.expectedRevenueLevel,
    required this.requiredTasks,
  });

  final String id;
  final String businessName;
  final String targetCustomer;
  final String revenueModel;
  final String currentStage;
  final String nextStep;
  final String expectedRevenueLevel;
  final List<String> requiredTasks;
}
