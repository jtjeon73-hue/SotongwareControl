enum PromotionStatus { notStarted, inProgress, ready, active }

extension PromotionStatusX on PromotionStatus {
  String get label {
    switch (this) {
      case PromotionStatus.notStarted:
        return '미착수';
      case PromotionStatus.inProgress:
        return '진행 중';
      case PromotionStatus.ready:
        return '준비 완료';
      case PromotionStatus.active:
        return '운영 중';
    }
  }
}

class PromotionChannel {
  const PromotionChannel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.nextAction,
    this.projectName,
    this.urlPlaceholder = 'URL 연결 예정',
  });

  final String id;
  final String title;
  final String description;
  final PromotionStatus status;
  final String nextAction;
  final String? projectName;
  final String urlPlaceholder;
}

class PromoSiteStatus {
  const PromoSiteStatus({
    required this.projectName,
    required this.siteName,
    required this.status,
    required this.nextAction,
    this.urlPlaceholder = 'URL 연결 예정',
  });

  final String projectName;
  final String siteName;
  final PromotionStatus status;
  final String nextAction;
  final String urlPlaceholder;
}
