class Department {
  const Department({
    required this.id,
    required this.title,
    required this.role,
    required this.taskCards,
  });

  final String id;
  final String title;
  final String role;
  final List<DepartmentTaskCard> taskCards;
}

class DepartmentTaskCard {
  const DepartmentTaskCard({required this.title, required this.description});

  final String title;
  final String description;
}
