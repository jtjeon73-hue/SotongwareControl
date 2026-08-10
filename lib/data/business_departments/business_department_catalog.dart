import '../../core/constants/external_site_links.dart';
import 'business_department_config.dart';

/// 6개 사업부 config 카탈로그.
class BusinessDepartmentCatalog {
  BusinessDepartmentCatalog._();

  static BusinessDepartmentConfig byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => industrial);
  }

  static final all = <BusinessDepartmentConfig>[
    industrial,
    ebook,
    app,
    knowledgeSite,
    marketingSite,
    contents,
  ];

  static const industrial = BusinessDepartmentConfig(
    id: 'industrial_automation',
    title: '산업자동화SW개발부',
    purpose: '산업자동화·공장자동화 소프트웨어 기술을 실제 사업으로 연결합니다.',
    artifactType: '',
    linkedSites: [
      LinkedSiteSummary(
        name: '소통웨어 산업자동화',
        url: 'https://sotong-automation-promo.web.app',
        serviceName: '산업자동화 소개',
        status: '공개 운영',
        lastChecked: '로컬 요약',
        mainFeatures: ['사업 소개', '서비스 안내'],
        contentStatus: '프로모 사이트 운영 중',
        improvements: ['사례 페이지 보강', '문의 CTA 명확화'],
      ),
    ],
    knowledge: [
      KnowledgeItem(
        title: '사업 정의',
        body:
            '생산라인 모니터링, PLC/MES 연동, Vision 검사, 데이터 수집·설비 통신을 포함한 산업용 소프트웨어 개발.',
      ),
      KnowledgeItem(
        title: '주요 고객',
        body: '제조업체, 시스템 통합업체, 설비·자동화 업체, 스마트공장 구축업체.',
      ),
      KnowledgeItem(
        title: '해결하는 문제',
        body: '현장 데이터 파편화, 품질 이력 미비, 설비 장애 대응 지연, OT/IT 단절.',
      ),
      KnowledgeItem(
        title: '핵심 기술',
        body: 'Modbus, OPC UA, MES, Vision, 생산이력, 품질 데이터, 유지보수.',
      ),
      KnowledgeItem(
        title: '핵심 상품',
        body: '모니터링 솔루션, 조립툴/검사 SW, 데이터 수집 게이트웨이, 관제 대시보드.',
      ),
      KnowledgeItem(
        title: '수익이 발생하는 방식',
        body: '프로젝트 개발비, 설비당 라이선스, 유지보수·연간 계약, 업그레이드·현장 지원.',
      ),
      KnowledgeItem(title: '주요 경쟁 요소', body: '현장 적합성, 안정성, 통신 호환, 납품·유지보수 신뢰.'),
    ],
    trends: TrendSummary(
      coreTech: ['PLC', 'MES', 'Modbus', 'Vision 검사', '생산이력'],
      changingTech: ['AI 제조', 'Edge AI', 'Digital Twin', 'OT/IT 통합'],
      aiPoints: ['Predictive Maintenance', 'Vision AI', '제조 데이터 분석'],
      watchlist: ['스마트팩토리', 'Edge 추론', '디지털 트윈'],
      applyNow: ['품질 이상 탐지', '예지보전 알람', '라인 모니터링 고도화'],
    ),
    sales: SalesStrategySummary(
      customerGroups: ['기존 제조업 고객', 'SI', '설비업체', '자동화 업체'],
      whereToFind: ['산업 전시회', '기존 거래처', '스마트공장 사업단'],
      methods: ['현장 진단', 'PoC', '유지보수 계약'],
      proposal: ['문제-해결 중심 제안서', 'ROI·장애 대응 시나리오'],
      freeToPaid: ['진단 미팅 → PoC → 본계약'],
      existingCustomers: ['정기 점검', '업그레이드 제안'],
      referral: ['SI·설비 파트너 소개'],
      online: ['프로모 사이트', '사례 자료'],
      offline: ['공장 방문', '데모'],
    ),
    revenue: RevenueModelSummary(
      items: [
        '프로젝트 개발비',
        '설비당 라이선스',
        '유지보수',
        '연간 계약',
        '모니터링 솔루션',
        '업그레이드',
        '현장 기술지원',
      ],
    ),
  );

  static final ebook = BusinessDepartmentConfig(
    id: 'ebook',
    title: '전자책 개발부',
    purpose: '경험 지식을 전자책 상품으로 기획·제작·판매합니다.',
    artifactType: 'ebook',
    linkedSites: [
      LinkedSiteSummary.fromLink(
        ExternalSiteLinks.ebook,
        lastChecked: '로컬 요약',
        mainFeatures: ['사업 소개', '전자책 안내'],
        contentStatus: '프로모 사이트 운영 중',
        improvements: ['판매 링크 정리', '후기 섹션'],
      ),
    ],
    knowledge: const [
      KnowledgeItem(
        title: '사업 정의',
        body: '주제 선정부터 집필·검수·PDF·표지·판매·홍보·업데이트까지 전자책 전 주기.',
      ),
      KnowledgeItem(title: '주요 고객', body: '귀촌·부업·실무 학습 등 구체 문제를 가진 독자.'),
      KnowledgeItem(
        title: '해결하는 문제',
        body: '정보가 흩어져 실행이 어려운 독자에게 검증된 실행 가이드 제공.',
      ),
      KnowledgeItem(title: '핵심 기술', body: '목차 설계, AI 집필 보조, 편집·디자인, PDF/EPUB.'),
      KnowledgeItem(title: '핵심 상품', body: '단권 전자책, 패키지, 강의 연계 콘텐츠.'),
      KnowledgeItem(title: '수익이 발생하는 방식', body: '단권 판매, 패키지, 상담·강의 연계, 라이선스.'),
      KnowledgeItem(title: '주요 경쟁 요소', body: '실행 가능성, 독자 공감, 업데이트 신뢰.'),
    ],
    trends: const TrendSummary(
      coreTech: ['주제 선정', '목차', '집필', '검수', 'PDF'],
      changingTech: ['AI 집필 보조', 'AI 편집/디자인', '다국어 전자책'],
      aiPoints: ['경험 지식 상품화', '개인화 콘텐츠', '콘텐츠 재가공'],
      watchlist: ['숏폼 연계', '오디오북'],
      applyNow: ['작업지시 제작소 기반 전자책 파이프라인'],
    ),
    sales: const SalesStrategySummary(
      customerGroups: ['실무 학습 독자', '부업·귀촌 관심층'],
      whereToFind: ['크몽', '탈잉', '자체 사이트', 'SNS', '블로그'],
      methods: ['랜딩·후기', '쇼츠/유튜브 연계'],
      proposal: ['문제 해결형 목차 미리보기'],
      freeToPaid: ['샘플 챕터 → 본권'],
      existingCustomers: ['개정판', '후속권'],
      referral: ['독자 추천·리뷰'],
      online: ['크몽', 'SNS', '블로그'],
      offline: ['강연·워크숍 연계'],
    ),
    revenue: const RevenueModelSummary(
      items: ['단권 판매', '패키지', '강의 연계', '상담', '콘텐츠 재판매', '라이선스'],
    ),
  );

  static final app = BusinessDepartmentConfig(
    id: 'app_development',
    title: '앱 개발부',
    purpose: 'Flutter·Firebase 기반으로 사용자 문제를 해결하는 앱을 제품화합니다.',
    artifactType: 'app',
    linkedSites: [
      LinkedSiteSummary.fromLink(
        ExternalSiteLinks.apps,
        lastChecked: '로컬 요약',
        mainFeatures: ['앱 소개', '프로젝트 안내'],
        contentStatus: '프로모 사이트 운영 중',
        improvements: ['스토어 링크 정리'],
      ),
    ],
    knowledge: const [
      KnowledgeItem(
        title: '사업 정의',
        body: '고객 문제 → 기능설계 → UI/UX → Flutter/Firebase → 스토어 → 운영.',
      ),
      KnowledgeItem(title: '주요 고객', body: '일반 사용자, 소상공인, 기업용·니치 앱 수요.'),
      KnowledgeItem(
        title: '해결하는 문제',
        body: '반복 업무·정보 관리·현장 기록 등 모바일로 해결 가능한 문제.',
      ),
      KnowledgeItem(
        title: '핵심 기술',
        body: 'Flutter, Firebase, Android, 수익화, 스토어 등록.',
      ),
      KnowledgeItem(title: '핵심 상품', body: '니치앱, 구독형 앱, 기업용 앱, 광고 기반 무료앱.'),
      KnowledgeItem(
        title: '수익이 발생하는 방식',
        body: '광고, 유료 다운로드, 인앱, 구독, 기업 라이선스, 개발대행.',
      ),
      KnowledgeItem(title: '주요 경쟁 요소', body: '문제 적합성, UX, 안정성, 업데이트 속도.'),
    ],
    trends: const TrendSummary(
      coreTech: ['Flutter', 'Firebase', 'Play Store'],
      changingTech: ['AI Agent App', 'On-device AI', '생성형 AI'],
      aiPoints: ['자동화', '개인화', '음성', '비전'],
      watchlist: ['구독 모델', '에이전트 UX'],
      applyNow: ['니치 문제 앱 + 작업지시 제작소 연동'],
    ),
    sales: const SalesStrategySummary(
      customerGroups: ['Play Store 사용자', '소상공인', '기업'],
      whereToFind: ['Play Store', '프로모 사이트', '지인·파트너'],
      methods: ['무료+광고', '구독', '맞춤 개발'],
      proposal: ['문제-기능 매핑 데모'],
      freeToPaid: ['무료 → 프리미엄/구독'],
      existingCustomers: ['업데이트·부가 모듈'],
      referral: ['스토어 리뷰·입소문'],
      online: ['스토어 ASO', 'SNS'],
      offline: ['현장 데모'],
    ),
    revenue: const RevenueModelSummary(
      items: ['광고', '유료 다운로드', '인앱결제', '구독', '기업 라이선스', '개발대행'],
    ),
  );

  static final knowledgeSite = BusinessDepartmentConfig(
    id: 'site_manager',
    title: '지식사이트 개발부',
    purpose: '전문 지식을 검색·학습 가능한 사이트로 구조화합니다.',
    artifactType: 'site',
    linkedSites: [
      LinkedSiteSummary.fromLink(
        ExternalSiteLinks.siteManager,
        lastChecked: '로컬 요약',
        mainFeatures: ['지식 허브', '사이트 연결'],
        contentStatus: '통합 허브 운영 중',
        improvements: ['카테고리 SEO', 'Q&A 보강'],
      ),
      LinkedSiteSummary.fromLink(
        ExternalSiteLinks.aiStory,
        lastChecked: '로컬 요약',
        mainFeatures: ['AI 지식', '콘텐츠'],
        contentStatus: '공개 운영',
        improvements: ['검색 품질'],
      ),
    ],
    knowledge: const [
      KnowledgeItem(
        title: '사업 정의',
        body: '전문분야 선정, 콘텐츠 구조, 검색·카테고리·SEO, 학습·정보 갱신.',
      ),
      KnowledgeItem(title: '주요 고객', body: '특정 분야를 학습·검색하는 사용자, 전문 서비스 리드.'),
      KnowledgeItem(title: '해결하는 문제', body: '흩어진 전문 정보의 구조화와 신뢰 가능한 진입점.'),
      KnowledgeItem(title: '핵심 기술', body: '정보 구조, SEO, 검색, 콘텐츠 운영.'),
      KnowledgeItem(title: '핵심 상품', body: '지식 전문관, Q&A, 유료 콘텐츠, 전문 서비스 연결.'),
      KnowledgeItem(title: '수익이 발생하는 방식', body: '광고, 제휴, 유료 콘텐츠, 리드, 구독.'),
      KnowledgeItem(title: '주요 경쟁 요소', body: '전문성, 검색 품질, 최신성.'),
    ],
    trends: const TrendSummary(
      coreTech: ['콘텐츠 구조', 'SEO', '카테고리'],
      changingTech: ['AI 검색', 'RAG', '지식 그래프'],
      aiPoints: ['AI Q&A', '개인화 지식', '자동 콘텐츠 갱신'],
      watchlist: ['멀티모달 검색'],
      applyNow: ['전문관 + 작업지시 기반 콘텐츠 생산'],
    ),
    sales: const SalesStrategySummary(
      customerGroups: ['검색 유입 사용자', '전문 서비스 수요'],
      whereToFind: ['검색', '콘텐츠 마케팅', '커뮤니티'],
      methods: ['전문성 브랜딩', '제휴'],
      proposal: ['문제 해결형 랜딩'],
      freeToPaid: ['무료 지식 → 유료/서비스'],
      existingCustomers: ['뉴스레터·업데이트'],
      referral: ['커뮤니티 공유'],
      online: ['SEO', '블로그'],
      offline: ['세미나'],
    ),
    revenue: const RevenueModelSummary(
      items: ['광고', '제휴', '유료 콘텐츠', '리드 생성', '전문 서비스', '구독'],
    ),
  );

  static final marketingSite = BusinessDepartmentConfig(
    id: 'web_marketing',
    title: '마케팅사이트 개발부',
    purpose: '랜딩·CTA·전환 중심의 마케팅/프로모 사이트를 제작·운영합니다.',
    artifactType: 'promo_site',
    linkedSites: [
      LinkedSiteSummary.fromLink(
        ExternalSiteLinks.marketing,
        lastChecked: '로컬 요약',
        mainFeatures: ['마케팅 소개', '서비스 안내'],
        contentStatus: '프로모 사이트 운영 중',
        improvements: ['사례·후기', '문의 전환'],
      ),
    ],
    knowledge: const [
      KnowledgeItem(
        title: '사업 정의',
        body: '랜딩페이지, CTA, 고객 전환, 상품 설명, 후기, 신뢰 요소, 문의·분석.',
      ),
      KnowledgeItem(title: '주요 고객', body: '상품·서비스를 홍보하려는 사업자, 자체 상품 런칭.'),
      KnowledgeItem(title: '해결하는 문제', body: '방문은 있으나 전환이 약한 홍보·판매 페이지.'),
      KnowledgeItem(title: '핵심 기술', body: '카피, 레이아웃, 분석, A/B, 리드 관리.'),
      KnowledgeItem(title: '핵심 상품', body: '랜딩 제작, 관리, 광고대행, 월구독형 운영.'),
      KnowledgeItem(
        title: '수익이 발생하는 방식',
        body: '제작비, 관리비, 광고대행, 성과 수수료, SaaS 월구독.',
      ),
      KnowledgeItem(title: '주요 경쟁 요소', body: '전환율, 메시지 명확성, 속도.'),
    ],
    trends: const TrendSummary(
      coreTech: ['랜딩', 'CTA', '후기', '분석'],
      changingTech: ['AI 카피', '개인화 랜딩', '자동 A/B'],
      aiPoints: ['AI 광고 소재', '자동 리드 관리'],
      watchlist: ['리타게팅 자동화'],
      applyNow: ['promo_site 작업지시 + 전환 체크리스트'],
    ),
    sales: const SalesStrategySummary(
      customerGroups: ['소상공인', '자체 상품', '지역 사업'],
      whereToFind: ['검색광고', 'SNS', '블로그', '지역광고'],
      methods: ['패키지 제안', '성과형'],
      proposal: ['전환 개선 Before/After'],
      freeToPaid: ['진단 → 제작/관리'],
      existingCustomers: ['관리 구독', '광고 확장'],
      referral: ['제휴·리타게팅'],
      online: ['검색·SNS'],
      offline: ['지역 네트워크'],
    ),
    revenue: const RevenueModelSummary(
      items: ['사이트 제작비', '관리비', '광고대행', '성과형 수수료', 'SaaS형 월구독'],
    ),
  );

  static final contents = BusinessDepartmentConfig(
    id: 'content_music',
    title: '컨텐츠 개발부',
    purpose: '노래·쇼츠·영상 등 콘텐츠를 제작해 YouTube·사이트·SNS에 활용합니다.',
    artifactType: 'contents',
    linkedSites: [
      LinkedSiteSummary.fromLink(
        ExternalSiteLinks.contents,
        lastChecked: '로컬 요약',
        mainFeatures: ['콘텐츠 소개', '음악·영상'],
        contentStatus: '프로모 사이트 운영 중',
        improvements: ['채널 링크', '대표 작품'],
      ),
    ],
    knowledge: const [
      KnowledgeItem(
        title: '사업 정의',
        body: '아이디어·가사·음악·영상·쇼츠·썸네일·제목·SEO·업로드·저작권.',
      ),
      KnowledgeItem(title: '주요 고객', body: '시청자, 브랜드 홍보 수요, 자체 상품 유입.'),
      KnowledgeItem(title: '해결하는 문제', body: '메시지가 없는 홍보, 반복 제작 비용.'),
      KnowledgeItem(title: '핵심 기술', body: 'AI 음악/영상/음성, 편집, Shorts SEO.'),
      KnowledgeItem(title: '핵심 상품', body: '쇼츠, 일반 영상, 음원, 홍보 콘텐츠.'),
      KnowledgeItem(
        title: '수익이 발생하는 방식',
        body: 'YouTube 광고, 음원, 콘텐츠 판매, 제휴, 상품 유입, 제작 대행.',
      ),
      KnowledgeItem(title: '주요 경쟁 요소', body: '훅, 썸네일, 꾸준한 업로드, 저작권 안전.'),
    ],
    trends: const TrendSummary(
      coreTech: ['쇼츠', '썸네일', 'SEO', '업로드'],
      changingTech: ['AI 음악', 'AI 영상', '자동 편집'],
      aiPoints: ['생성형 영상', '다국어 콘텐츠', 'AI 음성'],
      watchlist: ['Shorts 알고리즘', '멀티플랫폼'],
      applyNow: ['contents 작업지시 + 채널 운영 루틴'],
    ),
    sales: const SalesStrategySummary(
      customerGroups: ['YouTube 시청자', '브랜드', '자체 상품'],
      whereToFind: ['YouTube', 'Shorts', 'SNS'],
      methods: ['시리즈화', '상품 연계'],
      proposal: ['콘텐츠→상품 유입 설계'],
      freeToPaid: ['무료 시청 → 상품/멤버십'],
      existingCustomers: ['시즌·시리즈 확장'],
      referral: ['공유·콜라보'],
      online: ['YouTube', 'SNS', '사이트'],
      offline: ['행사·공연 연계'],
    ),
    revenue: const RevenueModelSummary(
      items: ['YouTube 광고', '음원', '콘텐츠 판매', '홍보 수익', '제휴', '상품 유입', '제작 대행'],
    ),
  );
}
