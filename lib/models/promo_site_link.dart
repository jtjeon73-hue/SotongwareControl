enum SiteVisibility { private, publicPlanned, publicLive }

extension SiteVisibilityX on SiteVisibility {
  String get label {
    switch (this) {
      case SiteVisibility.private:
        return 'PRIVATE';
      case SiteVisibility.publicPlanned:
        return 'PUBLIC 예정';
      case SiteVisibility.publicLive:
        return 'PUBLIC';
    }
  }

  bool get isPublic =>
      this == SiteVisibility.publicPlanned || this == SiteVisibility.publicLive;
}

class PromoSiteLink {
  const PromoSiteLink({
    required this.id,
    required this.repoName,
    required this.title,
    required this.purpose,
    required this.visibility,
    required this.productionStatus,
    required this.nextTask,
    this.businessName,
    this.defaultUrl,
    this.internalConnectionStatus,
    this.parentId,
    this.isBusinessHub = false,
    this.divisionId,
  });

  final String id;
  final String repoName;
  final String title;
  final String purpose;
  final SiteVisibility visibility;
  final String productionStatus;
  final String nextTask;
  final String? businessName;
  final String? defaultUrl;
  final String? internalConnectionStatus;
  final String? parentId;
  final bool isBusinessHub;
  final String? divisionId;

  String get displayName => businessName ?? title;

  bool get hasDefaultUrl => defaultUrl != null && defaultUrl!.trim().isNotEmpty;
}
