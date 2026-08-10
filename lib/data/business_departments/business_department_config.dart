import '../../core/constants/external_site_links.dart';

/// 연동 사이트 요약 (수동/로컬). 향후 API Provider로 교체 가능.
class LinkedSiteSummary {
  const LinkedSiteSummary({
    required this.name,
    required this.url,
    required this.serviceName,
    this.status = '운영',
    this.lastChecked = '',
    this.recentChanges = const [],
    this.mainFeatures = const [],
    this.contentStatus = '',
    this.improvements = const [],
  });

  final String name;
  final String url;
  final String serviceName;
  final String status;
  final String lastChecked;
  final List<String> recentChanges;
  final List<String> mainFeatures;
  final String contentStatus;
  final List<String> improvements;

  factory LinkedSiteSummary.fromLink(
    ExternalSiteLink link, {
    String lastChecked = '',
    List<String> recentChanges = const [],
    List<String> mainFeatures = const [],
    String contentStatus = '',
    List<String> improvements = const [],
  }) {
    return LinkedSiteSummary(
      name: link.title,
      url: link.url,
      serviceName: link.subtitle,
      status: link.statusLabel,
      lastChecked: lastChecked,
      recentChanges: recentChanges,
      mainFeatures: mainFeatures,
      contentStatus: contentStatus,
      improvements: improvements,
    );
  }
}

class KnowledgeItem {
  const KnowledgeItem({required this.title, required this.body});

  final String title;
  final String body;
}

class TrendSummary {
  const TrendSummary({
    this.coreTech = const [],
    this.changingTech = const [],
    this.aiPoints = const [],
    this.watchlist = const [],
    this.applyNow = const [],
  });

  final List<String> coreTech;
  final List<String> changingTech;
  final List<String> aiPoints;
  final List<String> watchlist;
  final List<String> applyNow;
}

class SalesStrategySummary {
  const SalesStrategySummary({
    this.customerGroups = const [],
    this.whereToFind = const [],
    this.methods = const [],
    this.proposal = const [],
    this.freeToPaid = const [],
    this.existingCustomers = const [],
    this.referral = const [],
    this.online = const [],
    this.offline = const [],
  });

  final List<String> customerGroups;
  final List<String> whereToFind;
  final List<String> methods;
  final List<String> proposal;
  final List<String> freeToPaid;
  final List<String> existingCustomers;
  final List<String> referral;
  final List<String> online;
  final List<String> offline;
}

class RevenueModelSummary {
  const RevenueModelSummary({required this.items});

  final List<String> items;
}

/// 사업부 화면 설정 — 6개 사업부가 공유하는 구조.
class BusinessDepartmentConfig {
  const BusinessDepartmentConfig({
    required this.id,
    required this.title,
    required this.purpose,
    required this.linkedSites,
    required this.knowledge,
    required this.trends,
    required this.sales,
    required this.revenue,
    this.artifactType = '',
  });

  final String id;
  final String title;
  final String purpose;
  final List<LinkedSiteSummary> linkedSites;
  final List<KnowledgeItem> knowledge;
  final TrendSummary trends;
  final SalesStrategySummary sales;
  final RevenueModelSummary revenue;
  final String artifactType;
}
