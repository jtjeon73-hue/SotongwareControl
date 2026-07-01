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
    this.englishName,
    this.promoRepositoryName,
    this.promoUrl,
    this.promoStatus,
    this.isPromoLinked = false,
    this.promoSiteId,
  });

  final String name;
  final String? englishName;
  final String purpose;
  final String currentStage;
  final String nextTask;
  final String? promoRepositoryName;
  final String? promoUrl;
  final String? promoStatus;
  final bool isPromoLinked;
  final String? promoSiteId;

  bool get hasPromoLink =>
      isPromoLinked && (promoUrl?.trim().isNotEmpty ?? false);

  bool get needsDeploymentNotice =>
      promoStatus != null && !promoStatus!.contains('운영');
}
