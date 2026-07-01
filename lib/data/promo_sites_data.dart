import '../models/promo_site_link.dart';

class PromoSitesData {
  static const privateSites = <PromoSiteLink>[
    PromoSiteLink(
      id: 'control_center',
      repoName: 'SotongwareControl',
      title: 'SotongWare Control Center',
      purpose: '개인용 내부 사업 총괄 관제센터 (현재 사이트)',
      visibility: SiteVisibility.private,
      productionStatus: '운영 중',
      nextTask: '업무 상태 관리·AI 지시 구조 고도화',
    ),
  ];

  static const businessHubSites = <PromoSiteLink>[
    PromoSiteLink(
      id: 'automation_promo',
      repoName: 'SotongAutomationPromo',
      title: '산업자동화 모니터링 시스템 총괄 홍보사이트',
      purpose: '제조업체, 조립라인, 검사라인 고객 대상 홍보',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '핵심 기능 소개·포트폴리오 페이지 기획',
      isBusinessHub: true,
    ),
    PromoSiteLink(
      id: 'apps_promo',
      repoName: 'SotongAppsPromo',
      title: '앱개발 사업 총괄 홍보사이트',
      purpose: '개발 중인 앱 전체 소개 및 각 앱 프로모 사이트 연결',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '앱 포트폴리오 구조·하위 링크맵 설계',
      isBusinessHub: true,
    ),
    PromoSiteLink(
      id: 'contents_promo',
      repoName: 'SotongContentsPromo',
      title: '유튜브/콘텐츠 사업 총괄 홍보사이트',
      purpose: 'AI 음악, 지역 생활 영상, 시골 생활 콘텐츠, 앱 홍보 영상 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '채널·콘텐츠 카테고리 구조 기획',
      isBusinessHub: true,
    ),
    PromoSiteLink(
      id: 'ebook_promo',
      repoName: 'SotongEbookPromo',
      title: '전자책 개발 사업 총괄 홍보사이트',
      purpose: '전자책 주제, 출간 예정작, 판매 링크 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '출간 예정작 목록·판매 채널 연결 구조',
      isBusinessHub: true,
    ),
  ];

  static const appChildSites = <PromoSiteLink>[
    PromoSiteLink(
      id: 'travel_promo',
      repoName: 'SotongTravelPromo',
      title: '소통여행 프로모 사이트',
      purpose: '소통여행 앱 소개·APK 다운로드 안내',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: 'APK 다운로드 페이지 완성',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'saju_promo',
      repoName: 'SotongSajuPromo',
      title: '소통사주 프로모 사이트',
      purpose: '소통사주 앱 소개·기능 안내',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '기존 앱 소개 페이지 기획',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'farmjigi_promo',
      repoName: 'FarmjigiPromo',
      title: '팜지기 프로모 사이트',
      purpose: '농촌 직거래 앱 컨셉 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '앱 컨셉 정리 후 기획',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'health_promo',
      repoName: 'SotongHealthPromo',
      title: '소통건강 프로모 사이트',
      purpose: 'AI 건강코치 앱 아이디어 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '앱 컨셉·기능 정의',
      parentId: 'apps_promo',
    ),
    PromoSiteLink(
      id: 'ai_promo',
      repoName: 'SotongAIPromo',
      title: '소통AI 프로모 사이트',
      purpose: 'AI 활용 플랫폼 컨셉 소개',
      visibility: SiteVisibility.publicPlanned,
      productionStatus: '제작 예정',
      nextTask: '서비스 범위·MVP 정의',
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

  static List<PromoSiteLink> get allSites => [
    ...privateSites,
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
}
