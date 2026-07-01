enum ProjectLinkType { internal, publicPromo, commerce }

class ProjectLinkItem {
  const ProjectLinkItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.urlPlaceholder = 'URL 연결 예정',
  });

  final String id;
  final String name;
  final String description;
  final ProjectLinkType type;
  final String urlPlaceholder;
}
