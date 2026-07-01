class BusinessDivision {
  const BusinessDivision({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
    required this.status,
    this.detailDescription,
    this.detailSections = const {},
    this.projects = const [],
  });

  final String id;
  final String title;
  final String description;
  final List<String> items;
  final String status;
  final String? detailDescription;
  final Map<String, List<String>> detailSections;
  final List<DivisionProject> projects;
}

class DivisionProject {
  const DivisionProject({
    required this.name,
    required this.purpose,
    required this.currentStage,
    required this.nextTask,
    this.promoSitePlaceholder = '프로모 사이트 링크 예정',
  });

  final String name;
  final String purpose;
  final String currentStage;
  final String nextTask;
  final String promoSitePlaceholder;
}
