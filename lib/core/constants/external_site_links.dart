/// 소통웨어 공개 사업 사이트 링크 (관리자 허브 전용)
class ExternalSiteLink {
  const ExternalSiteLink({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.category,
    required this.description,
    this.statusLabel = '공개 운영',
  });

  final String id;
  final String title;
  final String subtitle;
  final String url;
  final String icon; // Material icon name key for mapping
  final String category;
  final String description;
  final String statusLabel;
}

/// 단일 출처 — URL을 여러 파일에 하드코딩하지 않음
class ExternalSiteLinks {
  ExternalSiteLinks._();

  static const requiredSites = <ExternalSiteLink>[
    ExternalSiteLink(
      id: 'apps',
      title: '소통웨어 앱개발',
      subtitle: '앱 개발 사업',
      url: 'https://sotongware-apps-promo.web.app',
      icon: 'apps',
      category: '공개 서비스',
      description: '소통웨어의 앱 개발 사업과 주요 앱 프로젝트를 소개하는 공개 사이트',
    ),
    ExternalSiteLink(
      id: 'ebook',
      title: '소통웨어 전자책',
      subtitle: '전자책 사업',
      url: 'https://sotongware-ebook-promo.web.app',
      icon: 'ebook',
      category: '공개 서비스',
      description: 'AI 기반 전자책 기획·제작·출판 사업을 소개하는 공개 사이트',
    ),
    ExternalSiteLink(
      id: 'contents',
      title: '소통웨어 콘텐츠',
      subtitle: '콘텐츠·음악',
      url: 'https://sotongware-contents-promo.web.app',
      icon: 'contents',
      category: '공개 서비스',
      description: '영상·음악·AI 콘텐츠 제작 사업을 소개하는 공개 사이트',
    ),
    ExternalSiteLink(
      id: 'ai_story',
      title: '소통AI스토리',
      subtitle: 'AI 지식 플랫폼',
      url: 'https://sotongware-ai-story.web.app',
      icon: 'ai_story',
      category: '공개 서비스',
      description: 'AI 역사·도구·활용·미래 정보를 제공하는 공개 AI 지식 플랫폼',
    ),
    ExternalSiteLink(
      id: 'marketing',
      title: '소통마케팅',
      subtitle: '홍보·마케팅',
      url: 'https://sotongware-marketing.web.app',
      icon: 'marketing',
      category: '공개 서비스',
      description: '고객 맞춤형 홍보·마케팅 사이트 제작 서비스를 소개하는 공개 사이트',
    ),
  ];

  /// 기존 산업자동화 공개 사이트 (유지·선택 표시)
  static const industrialAutomation = ExternalSiteLink(
    id: 'industrial',
    title: '소통웨어 산업자동화',
    subtitle: '산업자동화',
    url: 'https://sotong-automation-promo.web.app',
    icon: 'industrial',
    category: '공개 서비스',
    description: '산업자동화 사업 소개 공개 사이트',
  );

  /// 허브 페이지에 표시할 전체 (요청 5개 + 산업자동화)
  static List<ExternalSiteLink> get hubSites => [
    ...requiredSites,
    industrialAutomation,
  ];
}
