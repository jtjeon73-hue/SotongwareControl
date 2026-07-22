import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _str(dynamic v, [String d = '']) =>
    (v is String ? v : v?.toString() ?? d).trim();

class DeployedSiteStatus {
  static const operating = 'operating';
  static const needsCheck = 'needsCheck';
  static const deploying = 'deploying';
  static const preparing = 'preparing';
  static const inactive = 'inactive';

  static const all = [operating, needsCheck, deploying, preparing, inactive];

  static String labelKo(String status) {
    switch (status) {
      case operating:
        return '정상 운영';
      case needsCheck:
        return '점검 필요';
      case deploying:
        return '배포 진행 중';
      case preparing:
        return '준비 중';
      case inactive:
        return '비활성';
      default:
        return '확인 필요';
    }
  }

  static Color color(String status) {
    switch (status) {
      case operating:
        return ControlColors.accentGreen;
      case needsCheck:
        return ControlColors.accentWarm;
      case deploying:
        return ControlColors.sandBeige;
      case preparing:
        return ControlColors.textMuted;
      case inactive:
        return ControlColors.accentRose;
      default:
        return ControlColors.textMuted;
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case operating:
        return Icons.check_circle_outline;
      case needsCheck:
        return Icons.warning_amber_outlined;
      case deploying:
        return Icons.rocket_launch_outlined;
      case preparing:
        return Icons.construction_outlined;
      case inactive:
        return Icons.pause_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  /// 저장된 status만 믿지 않고, 핵심 등록 정보로 표시 상태를 산출한다.
  /// - 상세설명 없음 → 점검 필요
  /// - 서비스 범위·운영 목적 중 하나만 채워진 불완전 입력 → 점검 필요
  /// - 둘 다 비어 있고 상세만 있는 기존(레거시) 문서는 허용
  /// - 과거 '점검 필요' 문구만 issues에 남은 경우는 차단하지 않음
  static String evaluate(DeployedSiteDoc site) {
    if (!site.isActive || site.status == inactive) return inactive;
    if (site.status == deploying || site.status == preparing) {
      return site.status;
    }

    if (!hasRequiredProfile(site)) return needsCheck;

    final url = site.liveUrl.trim().toLowerCase();
    if (url.isEmpty || !url.startsWith('https://')) return needsCheck;

    if (hasSeriousIssues(site.issues)) return needsCheck;

    final deploy = site.lastDeployResult.trim().toLowerCase();
    if (deploy.contains('실패') ||
        deploy.contains('fail') ||
        deploy.contains('error')) {
      return needsCheck;
    }

    return operating;
  }

  static bool hasRequiredProfile(DeployedSiteDoc site) {
    final scope = site.serviceScope.trim();
    final purpose = site.operationPurpose.trim();
    final desc = site.description.trim();
    if (desc.isEmpty) return false;
    if (scope.isEmpty && purpose.isEmpty) return true;
    return scope.isNotEmpty && purpose.isNotEmpty;
  }

  /// 운영을 막는 실질 이슈인지 판별. 과거 점검 안내 문구만 있으면 false.
  static bool hasSeriousIssues(String issues) {
    final t = issues.trim();
    if (t.isEmpty) return false;
    const placeholders = {
      '점검 필요',
      '서비스 범위·운영 목적 상세 점검 필요',
      '서비스 범위·운영 목적 점검 필요',
      '상세 점검 필요',
    };
    if (placeholders.contains(t)) return false;
    return true;
  }
}

class DeployedSiteCategory {
  static const control = '총괄관제';
  static const industrial = '산업자동화';
  static const app = '앱';
  static const ebook = '전자책';
  static const contents = '콘텐츠';
  static const ai = 'AI';
  static const education = '교육·학습';
  static const rural = '지역·농촌';
  static const marketing = '마케팅';
  static const lifestyle = '자동차·생활';
  static const other = '기타';

  static const all = [
    control,
    industrial,
    app,
    ebook,
    contents,
    ai,
    education,
    rural,
    marketing,
    lifestyle,
    other,
  ];
}

class DeployedHostingType {
  static const firebase = 'Firebase Hosting';
  static const githubPages = 'GitHub Pages';
  static const other = '기타';

  static const all = [firebase, githubPages, other];
}

class DeployedSiteDoc {
  const DeployedSiteDoc({
    required this.id,
    required this.nameKo,
    this.nameEn = '',
    this.description = '',
    this.serviceScope = '',
    this.operationPurpose = '',
    this.category = DeployedSiteCategory.other,
    this.hostingType = DeployedHostingType.firebase,
    this.firebaseProjectId = '',
    this.liveUrl = '',
    this.githubUrl = '',
    this.strategyUrl = '',
    this.status = DeployedSiteStatus.needsCheck,
    this.isFavorite = false,
    this.iconName = 'public',
    this.lastDeployedAt,
    this.lastCheckedAt,
    this.mobileChecked = false,
    this.desktopChecked = false,
    this.httpsChecked = false,
    this.lastDeployResult = '',
    this.recentWork = '',
    this.issues = '',
    this.nextAction = '',
    this.adminMemo = '',
    this.sortOrder = 100,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nameKo;
  final String nameEn;
  final String description;
  final String serviceScope;
  final String operationPurpose;
  final String category;
  final String hostingType;
  final String firebaseProjectId;
  final String liveUrl;
  final String githubUrl;
  final String strategyUrl;
  final String status;
  final bool isFavorite;
  final String iconName;
  final DateTime? lastDeployedAt;
  final DateTime? lastCheckedAt;
  final bool mobileChecked;
  final bool desktopChecked;
  final bool httpsChecked;
  final String lastDeployResult;
  final String recentWork;
  final String issues;
  final String nextAction;
  final String adminMemo;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasLiveUrl => liveUrl.trim().isNotEmpty;
  bool get hasGithubUrl => githubUrl.trim().isNotEmpty;
  bool get hasStrategyUrl => strategyUrl.trim().isNotEmpty;

  /// 화면·KPI용 상태. 저장값만 보지 않고 핵심 정보 충족 여부를 반영한다.
  String get effectiveStatus => DeployedSiteStatus.evaluate(this);

  DeployedSiteDoc copyWith({
    String? nameKo,
    String? nameEn,
    String? description,
    String? serviceScope,
    String? operationPurpose,
    String? category,
    String? hostingType,
    String? firebaseProjectId,
    String? liveUrl,
    String? githubUrl,
    String? strategyUrl,
    String? status,
    bool? isFavorite,
    String? iconName,
    DateTime? lastDeployedAt,
    DateTime? lastCheckedAt,
    bool? mobileChecked,
    bool? desktopChecked,
    bool? httpsChecked,
    String? lastDeployResult,
    String? recentWork,
    String? issues,
    String? nextAction,
    String? adminMemo,
    int? sortOrder,
    bool? isActive,
    bool clearLastDeployedAt = false,
    bool clearLastCheckedAt = false,
  }) {
    return DeployedSiteDoc(
      id: id,
      nameKo: nameKo ?? this.nameKo,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      serviceScope: serviceScope ?? this.serviceScope,
      operationPurpose: operationPurpose ?? this.operationPurpose,
      category: category ?? this.category,
      hostingType: hostingType ?? this.hostingType,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      liveUrl: liveUrl ?? this.liveUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      strategyUrl: strategyUrl ?? this.strategyUrl,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      iconName: iconName ?? this.iconName,
      lastDeployedAt: clearLastDeployedAt
          ? null
          : (lastDeployedAt ?? this.lastDeployedAt),
      lastCheckedAt: clearLastCheckedAt
          ? null
          : (lastCheckedAt ?? this.lastCheckedAt),
      mobileChecked: mobileChecked ?? this.mobileChecked,
      desktopChecked: desktopChecked ?? this.desktopChecked,
      httpsChecked: httpsChecked ?? this.httpsChecked,
      lastDeployResult: lastDeployResult ?? this.lastDeployResult,
      recentWork: recentWork ?? this.recentWork,
      issues: issues ?? this.issues,
      nextAction: nextAction ?? this.nextAction,
      adminMemo: adminMemo ?? this.adminMemo,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory DeployedSiteDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DeployedSiteDoc(
      id: doc.id,
      nameKo: _str(d['nameKo'], doc.id),
      nameEn: _str(d['nameEn']),
      description: _str(d['description']),
      serviceScope: _str(d['serviceScope']),
      operationPurpose: _str(d['operationPurpose']),
      category: _str(d['category'], DeployedSiteCategory.other),
      hostingType: _str(d['hostingType'], DeployedHostingType.firebase),
      firebaseProjectId: _str(d['firebaseProjectId']),
      liveUrl: _str(d['liveUrl']),
      githubUrl: _str(d['githubUrl']),
      strategyUrl: _str(d['strategyUrl']),
      status: _str(d['status'], DeployedSiteStatus.needsCheck),
      isFavorite: d['isFavorite'] == true,
      iconName: _str(d['iconName'], 'public'),
      lastDeployedAt: _ts(d['lastDeployedAt']),
      lastCheckedAt: _ts(d['lastCheckedAt']),
      mobileChecked: d['mobileChecked'] == true,
      desktopChecked: d['desktopChecked'] == true,
      httpsChecked: d['httpsChecked'] == true,
      lastDeployResult: _str(d['lastDeployResult']),
      recentWork: _str(d['recentWork']),
      issues: _str(d['issues']),
      nextAction: _str(d['nextAction']),
      adminMemo: _str(d['adminMemo']),
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 100,
      isActive: d['isActive'] != false,
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) => {
    'nameKo': nameKo,
    'nameEn': nameEn,
    'description': description,
    'serviceScope': serviceScope,
    'operationPurpose': operationPurpose,
    'category': category,
    'hostingType': hostingType,
    'firebaseProjectId': firebaseProjectId,
    'liveUrl': liveUrl,
    'githubUrl': githubUrl,
    'strategyUrl': strategyUrl,
    'status': status,
    'isFavorite': isFavorite,
    'iconName': iconName,
    'lastDeployedAt': lastDeployedAt == null
        ? null
        : Timestamp.fromDate(lastDeployedAt!),
    'lastCheckedAt': lastCheckedAt == null
        ? null
        : Timestamp.fromDate(lastCheckedAt!),
    'mobileChecked': mobileChecked,
    'desktopChecked': desktopChecked,
    'httpsChecked': httpsChecked,
    'lastDeployResult': lastDeployResult,
    'recentWork': recentWork,
    'issues': issues,
    'nextAction': nextAction,
    'adminMemo': adminMemo,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
  };

  IconData get materialIcon {
    switch (iconName) {
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'industrial':
        return Icons.precision_manufacturing_outlined;
      case 'apps':
        return Icons.phone_android_outlined;
      case 'ebook':
        return Icons.auto_stories_outlined;
      case 'contents':
        return Icons.play_circle_outline;
      case 'ai':
        return Icons.smart_toy_outlined;
      case 'marketing':
        return Icons.campaign_outlined;
      case 'rural':
        return Icons.agriculture_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'car':
        return Icons.directions_car_outlined;
      case 'plc':
        return Icons.memory_outlined;
      case 'dev':
        return Icons.code_outlined;
      case 'elec':
        return Icons.bolt_outlined;
      case 'language':
        return Icons.translate_outlined;
      default:
        return Icons.public_outlined;
    }
  }
}

class DeployedSitesKpis {
  const DeployedSitesKpis({
    required this.total,
    required this.operating,
    required this.needsCheck,
    required this.preparingOrDeploying,
    required this.inactive,
    required this.recentlyDeployed,
  });

  final int total;
  final int operating;
  final int needsCheck;
  final int preparingOrDeploying;
  final int inactive;
  final int recentlyDeployed;
}
