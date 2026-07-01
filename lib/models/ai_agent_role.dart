class AiAgentRole {
  const AiAgentRole({
    required this.id,
    required this.departmentName,
    required this.title,
    required this.roles,
    required this.todayTasks,
    required this.recentReport,
    required this.nextRecommendation,
    this.cautionNote,
    this.sampleCommand,
  });

  final String id;
  final String departmentName;
  final String title;
  final List<String> roles;
  final List<String> todayTasks;
  final String recentReport;
  final String nextRecommendation;
  final String? cautionNote;
  final String? sampleCommand;
}
