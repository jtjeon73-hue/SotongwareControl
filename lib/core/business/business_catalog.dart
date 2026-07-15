import '../constants/external_site_links.dart';

enum BusinessType {
  industrialAutomation,
  appDevelopment,
  ebookDevelopment,
  contentDevelopment,
  webMarketingDevelopment,
}

class BusinessDefinition {
  const BusinessDefinition({
    required this.type,
    required this.id,
    required this.name,
    required this.shortName,
    required this.purpose,
    required this.direction,
    required this.customers,
    required this.revenueModel,
    required this.aliases,
    required this.knowledge,
    required this.todayKnowledge,
    required this.site,
  });

  final BusinessType type;
  final String id;
  final String name;
  final String shortName;
  final String purpose;
  final String direction;
  final String customers;
  final String revenueModel;
  final List<String> aliases;
  final List<String> knowledge;
  final String todayKnowledge;
  final ExternalSiteLink site;

  bool matches(String businessUnitId) {
    final normalized = businessUnitId.trim().toLowerCase();
    return normalized == id || aliases.contains(normalized);
  }
}

class BusinessCatalog {
  BusinessCatalog._();

  static const businesses = <BusinessDefinition>[
    BusinessDefinition(
      type: BusinessType.industrialAutomation,
      id: 'industrial_automation',
      name: '사업자동화SW제작사업부',
      shortName: '산업자동화',
      purpose: '산업·공장 현장의 설비 데이터 수집, 모니터링, 관제 및 자동화 소프트웨어를 제작합니다.',
      direction: '현장 요구 분석부터 납품·유지보수까지 재사용 가능한 산업용 소프트웨어 제품군을 구축합니다.',
      customers: '제조업체, 공장 운영사, 설비 제작사, 자동화 SI 업체',
      revenueModel: '맞춤 개발비, 납품비, 유지보수비, 표준 제품 라이선스',
      aliases: ['industrialautomation', 'automation', 'factory_automation'],
      knowledge: [
        '산업자동화와 공장자동화',
        'PLC·센서·현장 네트워크',
        'Modbus RTU/TCP와 OPC UA',
        '설비·생산 데이터 수집',
        'CSV·데이터베이스 저장',
        '모니터링·관제·알람·이력',
        'MES·ERP 연동',
        'AI 분석과 예지보전',
        '산업용 PC와 장애 대응',
        '고객 요구사항·견적·납품·사후관리',
      ],
      todayKnowledge:
          '현장 자동화 프로젝트는 기능 목록보다 신호 목록, 통신 규격, 장애 시 동작, 검수 기준을 먼저 확정해야 재작업을 줄일 수 있습니다.',
      site: ExternalSiteLinks.industrialAutomation,
    ),
    BusinessDefinition(
      type: BusinessType.appDevelopment,
      id: 'app_development',
      name: '앱제작사업부',
      shortName: '앱개발',
      purpose: '실제 사용자 문제를 해결하는 모바일 앱을 기획·개발·출시하고 지속적으로 운영합니다.',
      direction: 'Flutter와 Firebase를 중심으로 앱을 제품화하고 출시·피드백·수익화의 반복 체계를 만듭니다.',
      customers: '일반 사용자, 소상공인, 지역 사업자, 특정 문제를 가진 틈새 사용자',
      revenueModel: '앱 판매, 광고, 구독, 인앱 결제, 맞춤 개발·유지관리',
      aliases: ['appdevelopment', 'apps', 'mobile_app'],
      knowledge: [
        '앱 아이디어와 문제 정의',
        '사용자 분석과 UI/UX',
        'Flutter·Firebase',
        '로그인·데이터베이스·알림',
        '광고·결제·수익화',
        'APK·AAB·Play Store',
        '버전·업데이트·유지관리',
        '사용자 피드백과 품질 개선',
        'ASO와 다운로드 증가',
        '앱 포트폴리오 전략',
      ],
      todayKnowledge:
          '앱의 진행률은 화면 수가 아니라 핵심 사용자 흐름이 실제 데이터와 연결되어 반복 사용 가능한지로 판단해야 합니다.',
      site: ExternalSiteLinks.apps,
    ),
    BusinessDefinition(
      type: BusinessType.ebookDevelopment,
      id: 'ebook',
      name: '전자책제작사업부',
      shortName: '전자책개발',
      purpose: '실용 지식을 독자가 구매하고 활용할 수 있는 전자책 상품으로 제작합니다.',
      direction: '주제 검증부터 집필·편집·판매·업데이트까지 반복 가능한 출판 프로세스를 구축합니다.',
      customers: '실용 정보 학습자, 직무·취미 독자, 소프트웨어와 AI 활용에 관심 있는 독자',
      revenueModel: '전자책 단품 판매, 시리즈 판매, 업데이트판, 연계 교육·콘텐츠',
      aliases: ['ebook_development', 'ebookdevelopment', 'digital_publishing'],
      knowledge: [
        '전자책 주제와 독자 분석',
        '목차·집필·AI 활용',
        '편집·표지·PDF·ePub',
        '판매 플랫폼과 가격',
        '마케팅과 상세 페이지',
        '시리즈화와 업데이트',
        '저작권과 출처 관리',
        '반복 판매 구조',
        '전자책 상품 포트폴리오',
      ],
      todayKnowledge:
          '전자책은 원고 완성보다 독자의 문제, 구매 이유, 읽은 뒤 얻는 결과를 먼저 한 문장으로 정의하는 것이 중요합니다.',
      site: ExternalSiteLinks.ebook,
    ),
    BusinessDefinition(
      type: BusinessType.contentDevelopment,
      id: 'content_music',
      name: '콘텐츠음악제작사업부',
      shortName: '콘텐츠개발',
      purpose: '영상·음악·이미지와 AI 콘텐츠를 제작하여 소통웨어 브랜드와 상품의 유입을 만듭니다.',
      direction: '기획부터 제작·업로드·성과 검토까지 반복 가능한 콘텐츠 워크플로를 만듭니다.',
      customers: '영상·음악·정보 콘텐츠 소비자와 소통웨어 잠재 고객',
      revenueModel: '플랫폼 수익, 제작 서비스, 브랜드 유입, 앱·전자책·웹 서비스 연계',
      aliases: ['content_development', 'contents', 'youtube_content'],
      knowledge: [
        '콘텐츠 기획과 채널 전략',
        '유튜브·쇼츠',
        '음악·AI 음악 제작',
        '이미지·영상·썸네일',
        '제목·스크립트·업로드',
        '저작권과 출처',
        '채널 운영과 수익화',
        '반복 제작과 자동화',
        '콘텐츠 포트폴리오',
      ],
      todayKnowledge:
          '콘텐츠 자동화는 많이 만드는 것이 아니라 기획 기준, 품질 확인, 저작권 확인을 반복 가능한 체크리스트로 만드는 일입니다.',
      site: ExternalSiteLinks.contents,
    ),
    BusinessDefinition(
      type: BusinessType.webMarketingDevelopment,
      id: 'web_marketing',
      name: '웹마케팅제작사업부',
      shortName: '마케팅사이트개발',
      purpose: '고객의 사업과 소통웨어 상품을 소개하고 문의·구매로 연결하는 반응형 웹사이트를 제작합니다.',
      direction: 'Firebase Hosting 기반 제작 표준과 템플릿을 구축하여 빠르고 안정적으로 반복 납품합니다.',
      customers: '소상공인, 개인사업자, 지역 업체, 홍보·문의 사이트가 필요한 고객',
      revenueModel: '사이트 제작비, 유지보수비, 도메인·콘텐츠 관리, 반복 제작',
      aliases: [
        'online_expansion',
        'web_marketing_development',
        'marketing',
        'marketing_site',
      ],
      knowledge: [
        '홍보 웹사이트와 랜딩페이지',
        '고객 요구 분석',
        '반응형 웹·모바일 최적화',
        'SEO·도메인·Firebase Hosting',
        '문의 전환과 CTA',
        '카카오톡 공유·OG 이미지',
        '고객 연락처와 개인정보',
        '제작 가격·유지보수',
        '템플릿화와 반복 제작',
        '온라인 영업과 고객 확보',
      ],
      todayKnowledge:
          '마케팅 사이트의 완성은 배포가 아니라 방문자가 신뢰하고 문의할 수 있도록 명확한 고객 문제, 제공 가치, CTA가 연결된 상태입니다.',
      site: ExternalSiteLinks.marketing,
    ),
  ];

  static BusinessDefinition? byId(String id) {
    for (final business in businesses) {
      if (business.matches(id)) return business;
    }
    return null;
  }

  static String canonicalId(String legacyId) =>
      byId(legacyId)?.id ?? legacyId.trim();
}
