enum AiSystemStatus {
  monitoring,
  automaticReportPending,
  notificationPending,
  approvalRequired,
  completed,
  warning,
  failed,
}

extension AiSystemStatusX on AiSystemStatus {
  String get label {
    switch (this) {
      case AiSystemStatus.monitoring:
        return 'AI 감시 중';
      case AiSystemStatus.automaticReportPending:
        return '자동 보고 대기';
      case AiSystemStatus.notificationPending:
        return '알림 대기';
      case AiSystemStatus.approvalRequired:
        return '승인 필요';
      case AiSystemStatus.completed:
        return '실행 완료';
      case AiSystemStatus.warning:
        return '주의';
      case AiSystemStatus.failed:
        return '실패';
    }
  }
}

enum AiOpinionStance { approve, oppose, caution }

extension AiOpinionStanceX on AiOpinionStance {
  String get label {
    switch (this) {
      case AiOpinionStance.approve:
        return '찬성';
      case AiOpinionStance.oppose:
        return '반대';
      case AiOpinionStance.caution:
        return '주의';
    }
  }
}

enum AiNotificationType {
  urgent,
  approvalRequired,
  developmentDone,
  customerInquiry,
  revenueGenerated,
  downloadGenerated,
  marketingDone,
  taxSchedule,
  investmentCheck,
  systemError,
}

extension AiNotificationTypeX on AiNotificationType {
  String get label {
    switch (this) {
      case AiNotificationType.urgent:
        return '긴급';
      case AiNotificationType.approvalRequired:
        return '승인 필요';
      case AiNotificationType.developmentDone:
        return '개발 완료';
      case AiNotificationType.customerInquiry:
        return '고객 문의';
      case AiNotificationType.revenueGenerated:
        return '매출 발생';
      case AiNotificationType.downloadGenerated:
        return '다운로드 발생';
      case AiNotificationType.marketingDone:
        return '마케팅 완료';
      case AiNotificationType.taxSchedule:
        return '세무 일정';
      case AiNotificationType.investmentCheck:
        return '투자 점검';
      case AiNotificationType.systemError:
        return '시스템 오류';
    }
  }
}

class AiDepartment {
  const AiDepartment({
    required this.id,
    required this.name,
    required this.leaderRole,
    required this.summary,
    required this.status,
    required this.progressPercent,
    required this.monitoredWorks,
    required this.nextAction,
  });

  final String id;
  final String name;
  final String leaderRole;
  final String summary;
  final AiSystemStatus status;
  final int progressPercent;
  final List<String> monitoredWorks;
  final String nextAction;
}

class AiExecutiveReport {
  const AiExecutiveReport({
    required this.title,
    required this.department,
    required this.summary,
    required this.status,
    required this.generatedAt,
    this.priority = '보통',
    this.tags = const [],
  });

  final String title;
  final String department;
  final String summary;
  final AiSystemStatus status;
  final String generatedAt;
  final String priority;
  final List<String> tags;
}

class AiStrategyMeeting {
  const AiStrategyMeeting({
    required this.weekLabel,
    required this.coreAgenda,
    required this.agendaExamples,
    required this.opinions,
    required this.expectedEffect,
    required this.expectedCost,
    required this.risk,
    required this.finalProposal,
  });

  final String weekLabel;
  final String coreAgenda;
  final List<String> agendaExamples;
  final List<AiStrategyOpinion> opinions;
  final String expectedEffect;
  final String expectedCost;
  final String risk;
  final String finalProposal;
}

class AiStrategyOpinion {
  const AiStrategyOpinion({
    required this.department,
    required this.role,
    required this.stance,
    required this.opinion,
    required this.reason,
  });

  final String department;
  final String role;
  final AiOpinionStance stance;
  final String opinion;
  final String reason;
}

class AiIdeaProposal {
  const AiIdeaProposal({
    required this.title,
    required this.marketScore,
    required this.developmentDifficulty,
    required this.estimatedDevelopmentPeriod,
    required this.expectedProfitability,
    required this.competitionIntensity,
    required this.sotongwareFit,
    required this.departmentOpinions,
    required this.finalJudgement,
  });

  final String title;
  final int marketScore;
  final String developmentDifficulty;
  final String estimatedDevelopmentPeriod;
  final String expectedProfitability;
  final String competitionIntensity;
  final String sotongwareFit;
  final List<String> departmentOpinions;
  final String finalJudgement;
}

class AiNotification {
  const AiNotification({
    required this.title,
    required this.department,
    required this.type,
    required this.importance,
    required this.occurredAt,
    required this.status,
    required this.detail,
  });

  final String title;
  final String department;
  final AiNotificationType type;
  final String importance;
  final String occurredAt;
  final AiSystemStatus status;
  final String detail;
}

class AiApprovalTask {
  const AiApprovalTask({
    required this.title,
    required this.department,
    required this.requestedBy,
    required this.reason,
    required this.dueLabel,
    required this.status,
  });

  final String title;
  final String department;
  final String requestedBy;
  final String reason;
  final String dueLabel;
  final AiSystemStatus status;
}

class BusinessDivisionStatus {
  const BusinessDivisionStatus({
    required this.name,
    required this.healthScore,
    required this.status,
    required this.revenueSignal,
    required this.nextAction,
  });

  final String name;
  final int healthScore;
  final String status;
  final String revenueSignal;
  final String nextAction;
}

class RevenueSummary {
  const RevenueSummary({
    required this.todayRevenue,
    required this.orderCount,
    required this.topSource,
    required this.forecast,
  });

  final String todayRevenue;
  final int orderCount;
  final String topSource;
  final String forecast;
}

class DownloadSummary {
  const DownloadSummary({
    required this.todayDownloads,
    required this.mostDownloaded,
    required this.conversionSignal,
    required this.trend,
  });

  final int todayDownloads;
  final String mostDownloaded;
  final String conversionSignal;
  final String trend;
}

class CustomerInquirySummary {
  const CustomerInquirySummary({
    required this.unansweredCount,
    required this.urgentCount,
    required this.topCategory,
    required this.summary,
  });

  final int unansweredCount;
  final int urgentCount;
  final String topCategory;
  final String summary;
}

class AiOfficeDashboardCard {
  const AiOfficeDashboardCard({
    required this.title,
    required this.value,
    required this.summary,
    required this.status,
    required this.department,
  });

  final String title;
  final String value;
  final String summary;
  final AiSystemStatus status;
  final String department;
}

class ProductTechRecommendation {
  const ProductTechRecommendation({
    required this.aiOrTech,
    required this.category,
    required this.feature,
    required this.utility,
    required this.application,
  });

  final String aiOrTech;
  final String category;
  final String feature;
  final String utility;
  final String application;
}

class DivisionProductDevGuide {
  const DivisionProductDevGuide({
    required this.divisionName,
    required this.currentProducts,
    required this.developmentFocus,
    required this.recommendations,
    required this.productEnhancements,
    required this.nextProductAction,
  });

  final String divisionName;
  final String currentProducts;
  final String developmentFocus;
  final List<ProductTechRecommendation> recommendations;
  final List<String> productEnhancements;
  final String nextProductAction;
}

enum ProductRegistrationStage {
  planning,
  development,
  review,
  registration,
  deployment,
  operation,
}

extension ProductRegistrationStageX on ProductRegistrationStage {
  String get label {
    switch (this) {
      case ProductRegistrationStage.planning:
        return '기획·구성';
      case ProductRegistrationStage.development:
        return '개발';
      case ProductRegistrationStage.review:
        return '검수';
      case ProductRegistrationStage.registration:
        return '등록';
      case ProductRegistrationStage.deployment:
        return '배포';
      case ProductRegistrationStage.operation:
        return '운영';
    }
  }

  int get order => index + 1;
}

class ProductRegistrationItem {
  const ProductRegistrationItem({
    required this.productName,
    required this.divisionName,
    required this.currentStage,
    required this.summary,
    required this.checklist,
    required this.owner,
    required this.updatedAt,
  });

  final String productName;
  final String divisionName;
  final ProductRegistrationStage currentStage;
  final String summary;
  final List<String> checklist;
  final String owner;
  final String updatedAt;
}

class RegisteredProduct {
  const RegisteredProduct({
    required this.name,
    required this.divisionName,
    required this.version,
    required this.registeredAt,
    required this.productType,
    required this.channels,
    required this.status,
    required this.catalogId,
  });

  final String name;
  final String divisionName;
  final String version;
  final String registeredAt;
  final String productType;
  final List<String> channels;
  final AiSystemStatus status;
  final String catalogId;
}

class ProductMaintenanceRecord {
  const ProductMaintenanceRecord({
    required this.productName,
    required this.divisionName,
    required this.currentVersion,
    required this.healthScore,
    required this.lastCheckedAt,
    required this.maintenanceTasks,
    required this.scheduledUpdates,
    required this.knownIssues,
    required this.nextMaintenanceAction,
  });

  final String productName;
  final String divisionName;
  final String currentVersion;
  final int healthScore;
  final String lastCheckedAt;
  final List<String> maintenanceTasks;
  final List<String> scheduledUpdates;
  final List<String> knownIssues;
  final String nextMaintenanceAction;
}
