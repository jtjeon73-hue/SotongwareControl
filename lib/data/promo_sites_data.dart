import '../models/promo_site_link.dart';

class PromoSitesData {
  static const publicDemoNotice =
      '본 사이트는 대표 1명이 전체 사업을 관제하는 비공개 본사 시스템 컨셉 데모입니다. '
      '표시되는 수치·진행률·재무 항목은 모두 샘플·예시이며, 실제 개인정보·세무·매출·인증·API Key 등 '
      '민감 정보는 포함하지 않습니다.';

  static const appPromoNotDeployedNotice =
      '프로모 저장소 또는 GitHub Pages 배포 전이면 404가 표시될 수 있습니다.';

  static const appsNeedingDeploymentCheck = <String>[
    '소통사주',
    '팜지기',
    '소통건강',
    '소통AI',
    '소통사매앱',
  ];

  static const centralHubSites = <PromoSiteLink>[
    PromoSiteLink(
      id: 'control_center',
      repoName: 'SotongwareControl',
      title: 'SotongWare Control — 소통컨트롤총괄프로모',
      purpose: '소통총관제 · AI 총괄 관제 · 사업부·AI부서 디지털 프로모 (현재 사이트)',
      visibility: SiteVisibility.publicLive,
      productionStatus: '비공개 관제 데모',
      nextTask: 'AI대표 승인 UI · Firebase/OpenAI/매출 데이터 연동',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongwareControl/',
      internalConnectionStatus: '허브 연결',
    ),
  ];

  static const businessHubSites = <PromoSiteLink>[
    PromoSiteLink(
      id: 'automation_promo',
      repoName: 'SotongAutomationPromo',
      businessName: '소통웨어 산업자동화',
      title: '산업자동화 모니터링 시스템 총괄 홍보사이트',
      purpose: '제조업체, 조립라인, 검사라인 고객 대상 홍보',
      visibility: SiteVisibility.publicLive,
      productionStatus: '제작 완료 / 배포 확인 필요',
      nextTask: 'GitHub Pages 배포 주소 404 여부 확인',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongAutomationPromo/',
      internalConnectionStatus: '프로모 연결',
      isBusinessHub: true,
      divisionId: 'industrial_automation',
    ),
    PromoSiteLink(
      id: 'apps_promo',
      repoName: 'SotongAppsPromo',
      businessName: '소통웨어 앱개발',
      title: '앱개발 사업 총괄 홍보사이트',
      purpose: '개발 중인 앱 전체 소개 및 각 앱 프로모 사이트 연결',
      visibility: SiteVisibility.publicLive,
      productionStatus: '제작 완료 / 배포 확인 필요',
      nextTask: '하위 앱 프로모 링크 연결 상태 점검',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongAppsPromo/',
      internalConnectionStatus: '프로모 연결',
      isBusinessHub: true,
      divisionId: 'app_development',
    ),
    PromoSiteLink(
      id: 'contents_promo',
      repoName: 'SotongContentsPromo',
      businessName: '소통웨어 콘텐츠',
      title: '유튜브/콘텐츠 사업 총괄 홍보사이트',
      purpose: 'AI 음악, 지역 생활 영상, 시골 생활 콘텐츠, 앱 홍보 영상 소개',
      visibility: SiteVisibility.publicLive,
      productionStatus: '제작 완료 / 배포 확인 필요',
      nextTask: 'GitHub Pages 배포 주소 404 여부 확인',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongContentsPromo/',
      internalConnectionStatus: '프로모 연결',
      isBusinessHub: true,
      divisionId: 'youtube_content',
    ),
    PromoSiteLink(
      id: 'ebook_promo',
      repoName: 'SotongEbookPromo',
      businessName: '소통웨어 전자책',
      title: '전자책 개발 사업 총괄 홍보사이트',
      purpose: '전자책 주제, 출간 예정작, 판매 링크 소개',
      visibility: SiteVisibility.publicLive,
      productionStatus: '제작 완료 / 배포 확인 필요',
      nextTask: 'GitHub Pages 배포 주소 404 여부 확인',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongEbookPromo/',
      internalConnectionStatus: '프로모 연결',
      isBusinessHub: true,
      divisionId: 'ebook',
    ),
  ];

  static const appChildSites = <PromoSiteLink>[
    PromoSiteLink(
      id: 'travel_promo',
      repoName: 'SotongTravelPromo',
      businessName: '소통여행',
      title: '소통여행 프로모 사이트',
      purpose: '소통여행 앱 소개·APK 다운로드 안내',
      visibility: SiteVisibility.publicLive,
      productionStatus: '운영중 / 연결됨',
      nextTask: 'APK 다운로드 페이지·배포 흐름 점검',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongTravelPromo/',
      internalConnectionStatus: '프로모 연결',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'saju_promo',
      repoName: 'SotongSajuPromo',
      businessName: '소통사주',
      title: '소통사주 프로모 사이트',
      purpose: '소통사주 앱 소개·기능 안내',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정 / 배포 확인 필요',
      nextTask: 'GitHub Pages 배포 및 소개 페이지 기획',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongSajuPromo/',
      internalConnectionStatus: '프로모 연결',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'farmjigi_promo',
      repoName: 'FarmjigiPromo',
      businessName: '팜지기',
      title: '팜지기 프로모 사이트',
      purpose: '농촌 직거래 앱 컨셉 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정 / 배포 확인 필요',
      nextTask: '저장소·Pages 배포 후 컨셉 페이지 연결',
      defaultUrl: 'https://jtjeon73-hue.github.io/FarmjigiPromo/',
      internalConnectionStatus: '프로모 연결',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'health_promo',
      repoName: 'SotongHealthPromo',
      businessName: '소통건강',
      title: '소통건강 프로모 사이트',
      purpose: 'AI 건강코치 앱 아이디어 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정 / 배포 확인 필요',
      nextTask: '앱 컨셉·기능 정의 후 프로모 연결',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongHealthPromo/',
      internalConnectionStatus: '프로모 연결',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'ai_promo',
      repoName: 'SotongAIPromo',
      businessName: '소통AI',
      title: '소통AI 프로모 사이트',
      purpose: 'AI 활용 플랫폼 컨셉 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정 / 배포 확인 필요',
      nextTask: '서비스 범위·MVP 정의 후 프로모 연결',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongAIPromo/',
      internalConnectionStatus: '프로모 연결',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'samae_promo',
      repoName: 'SotongSamaePromo',
      businessName: '소통사매앱',
      title: '소통사매앱 프로모 사이트',
      purpose: '사매면·지역 생활정보·관광지·마을 소식·생활 편의 정보 지역 밀착형 홍보',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정 / 배포 확인 필요',
      nextTask: 'GitHub Pages 배포 확인·앱 화면 고도화 연동',
      defaultUrl: 'https://jtjeon73-hue.github.io/SotongSamaePromo/',
      internalConnectionStatus: '프로모 연결',
      parentId: 'apps_promo',
    ),
  ];

  static const commerceSites = <PromoSiteLink>[
    PromoSiteLink(
      id: 'warehouse',
      repoName: 'SotongWarehouse',
      title: '소통창고 / 스마트스토어',
      purpose: '소통창고·스마트스토어 판매 채널 연결',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '연결 예정',
      nextTask: '상품 등록·스마트스토어 연동',
    ),
  ];

  static const divisionPromoMap = <String, String>{
    'industrial_automation': 'automation_promo',
    'app_development': 'apps_promo',
    'youtube_content': 'contents_promo',
    'ebook': 'ebook_promo',
  };

  static const projectPromoSiteMap = <String, String>{
    '소통여행': 'travel_promo',
    '소통사주': 'saju_promo',
    '팜지기': 'farmjigi_promo',
    '소통건강': 'health_promo',
    '소통AI': 'ai_promo',
    '소통사매앱': 'samae_promo',
  };

  static List<PromoSiteLink> get allSites => [
    ...centralHubSites,
    ...businessHubSites,
    ...appChildSites,
    ...commerceSites,
  ];

  static List<PromoSiteLink> childrenOf(String parentId) =>
      appChildSites.where((s) => s.parentId == parentId).toList();

  static PromoSiteLink? byId(String id) {
    try {
      return allSites.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static PromoSiteLink? promoForDivision(String divisionId) {
    final promoId = divisionPromoMap[divisionId];
    if (promoId == null) return null;
    return byId(promoId);
  }

  static PromoSiteLink? promoForProject(String projectName) {
    final id = projectPromoSiteMap[projectName];
    if (id == null) return null;
    return byId(id);
  }

  static int get hubCount => businessHubSites.length;

  static int get linkedHubUrlCount =>
      businessHubSites.where((s) => s.hasDefaultUrl).length;

  static int get deploymentCheckNeededCount => businessHubSites
      .where((s) => s.productionStatus.contains('배포 확인'))
      .length;

  static int get appPromoCount => appChildSites.length;

  static int get linkedAppPromoUrlCount =>
      appChildSites.where((s) => s.hasDefaultUrl).length;
}
