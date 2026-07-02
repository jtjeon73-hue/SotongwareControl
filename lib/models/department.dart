class Department {
  const Department({
    required this.id,
    required this.title,
    required this.role,
    required this.taskCards,
    this.headline,
    this.futureVision,
    this.progressPercent = 0,
  });

  final String id;
  final String title;
  final String role;
  final List<DepartmentTaskCard> taskCards;
  final String? headline;
  final String? futureVision;
  final int progressPercent;
}

class DepartmentTaskCard {
  const DepartmentTaskCard({required this.title, required this.description});

  final String title;
  final String description;
}
