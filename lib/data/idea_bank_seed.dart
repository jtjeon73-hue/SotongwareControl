import '../models/idea_bank.dart';

/// 뉴아이디어 뱅크 카테고리 (표시·필터용). product 필드와 병행.
class IdeaBankCategories {
  static const worldTrend = 'world_trend';
  static const aiOpportunity = 'ai_opportunity';
  static const kContent = 'k_content';
  static const issueOpportunity = 'issue_opportunity';
  static const rural = 'rural';
  static const industrial = 'industrial';
  static const appIdea = 'app_idea';
  static const ebookIdea = 'ebook_idea';
  static const contentsIdea = 'contents_idea';
  static const siteIdea = 'site_idea';
  static const promoIdea = 'promo_idea';

  static const all = [
    worldTrend,
    aiOpportunity,
    kContent,
    issueOpportunity,
    rural,
    industrial,
    appIdea,
    ebookIdea,
    contentsIdea,
    siteIdea,
    promoIdea,
  ];

  static String labelKo(String id) {
    switch (id) {
      case worldTrend:
        return '세계 트렌드';
      case aiOpportunity:
        return 'AI 사업기회';
      case kContent:
        return 'K-콘텐츠';
      case issueOpportunity:
        return '이슈/기회';
      case rural:
        return '농촌/지역사업';
      case industrial:
        return '산업자동화';
      case appIdea:
        return '앱 아이디어';
      case ebookIdea:
        return '전자책 아이디어';
      case contentsIdea:
        return '콘텐츠 아이디어';
      case siteIdea:
        return '사이트 아이디어';
      case promoIdea:
        return '홍보/마케팅 아이디어';
      default:
        return id;
    }
  }
}

class IdeaBankSourceRef {
  const IdeaBankSourceRef({
    required this.sourceTitle,
    required this.sourceUrl,
    this.sourceType = 'official',
    this.checkedAt = '',
  });

  final String sourceTitle;
  final String sourceUrl;
  final String sourceType;
  final String checkedAt;

  IdeaBankSourceLite toLite() => IdeaBankSourceLite(
    sourceTitle: sourceTitle,
    sourceUrl: sourceUrl,
    sourceType: sourceType,
    checkedAt: checkedAt,
  );

  static bool isTrustedHttpUrl(String url) {
    final u = url.trim().toLowerCase();
    return u.startsWith('https://') || u.startsWith('http://');
  }
}

/// 시드 아이디어 (isSeed=true). 사용자 데이터와 구분. 공식 공개 URL만 사용.
class IdeaBankSeedCatalog {
  IdeaBankSeedCatalog._();

  static const checkedAt = '2026-08-11';

  static List<IdeaBankItem> seeds() {
    const sources = {
      'trends': IdeaBankSourceRef(
        sourceTitle: 'Google Trends',
        sourceUrl: 'https://trends.google.com/',
        checkedAt: checkedAt,
      ),
      'think': IdeaBankSourceRef(
        sourceTitle: 'Think with Google',
        sourceUrl: 'https://www.thinkwithgoogle.com/',
        checkedAt: checkedAt,
      ),
      'oecd': IdeaBankSourceRef(
        sourceTitle: 'OECD',
        sourceUrl: 'https://www.oecd.org/',
        checkedAt: checkedAt,
      ),
      'korea': IdeaBankSourceRef(
        sourceTitle: '대한민국 정책브리핑',
        sourceUrl: 'https://www.korea.kr/',
        checkedAt: checkedAt,
      ),
      'kotra': IdeaBankSourceRef(
        sourceTitle: 'KOTRA',
        sourceUrl: 'https://www.kotra.or.kr/',
        checkedAt: checkedAt,
      ),
      'kocca': IdeaBankSourceRef(
        sourceTitle: '한국콘텐츠진흥원',
        sourceUrl: 'https://www.kocca.kr/',
        checkedAt: checkedAt,
      ),
      'rda': IdeaBankSourceRef(
        sourceTitle: '농촌진흥청',
        sourceUrl: 'https://www.rda.go.kr/',
        checkedAt: checkedAt,
      ),
      'mss': IdeaBankSourceRef(
        sourceTitle: '중소벤처기업부',
        sourceUrl: 'https://www.mss.go.kr/',
        checkedAt: checkedAt,
      ),
      'msit': IdeaBankSourceRef(
        sourceTitle: '과학기술정보통신부',
        sourceUrl: 'https://www.msit.go.kr/',
        checkedAt: checkedAt,
      ),
      'github': IdeaBankSourceRef(
        sourceTitle: 'GitHub Trending',
        sourceUrl: 'https://github.com/trending',
        checkedAt: checkedAt,
      ),
    };

    IdeaBankItem item({
      required String id,
      required String title,
      required String category,
      required String oneLiner,
      required String whyNow,
      required String target,
      required String how,
      required String product,
      required String difficulty,
      required String scoreNote,
      required IdeaBankSourceRef source,
    }) {
      final iso = '${checkedAt}T00:00:00.000Z';
      return IdeaBankItem(
        id: id,
        title: title,
        oneLiner: oneLiner,
        targetCustomer: target,
        product: product,
        recommendReason: whyNow,
        difficulty: difficulty,
        revenueMethod: how,
        memo: scoreNote,
        category: category,
        whyNow: whyNow,
        howToBusiness: how,
        businessUnits: product,
        estimatedScale: difficulty,
        infoAsOf: checkedAt,
        lastCheckedAt: checkedAt,
        isSeed: true,
        sources: [source.toLite()],
        createdAt: iso,
        updatedAt: iso,
        year: 2026,
        month: 8,
      );
    }

    return [
      item(
        id: 'seed_world_ai_productivity',
        title: '생성형 AI로 개인·소상공인 업무 자동화',
        category: IdeaBankCategories.worldTrend,
        oneLiner: '문서·고객응대·콘텐츠 초안을 AI로 줄이는 도구/가이드 수요',
        whyNow: '생성형 AI 도입이 개인·소규모 사업으로 확산되는 흐름',
        target: '1인 사업자, 소상공인, 사무직',
        how: '전자책·앱·자동화 가이드로 제작 가능',
        product: 'ebook',
        difficulty: '중',
        scoreNote: '평가: 트렌드성 높음 · 자동화 가능성 높음 (참고 지표)',
        source: sources['think']!,
      ),
      item(
        id: 'seed_ai_ops_sme',
        title: '중소제조 AI 점검·보고 도우미',
        category: IdeaBankCategories.aiOpportunity,
        oneLiner: '현장 로그·알람을 요약해 경영자가 휴대폰으로 확인',
        whyNow: '스마트공장·디지털 전환 정책과 현장 인력 부족이 겹침',
        target: '중소 제조 경영자·현장 관리자',
        how: '산업자동화SW + 소통총관제 알람/보고와 연계 검토',
        product: 'app',
        difficulty: '상',
        scoreNote: '평가: 시장성 중상 · 제작 난이도 상 (참고 지표)',
        source: sources['mss']!,
      ),
      item(
        id: 'seed_k_food_guide',
        title: 'K-푸드 입문 전자책/숏폼 시리즈',
        category: IdeaBankCategories.kContent,
        oneLiner: '해외 독자에게 한국 식문화를 단계적으로 소개',
        whyNow: '한식·K-콘텐츠 관심 지속 (저작권·상표는 합법 범위만)',
        target: '해외 한식 관심층, 여행·문화 학습자',
        how: '전자책 + 쇼츠로 시리즈화, 홍보 랜딩 연계',
        product: 'contents',
        difficulty: '중',
        scoreNote: '평가: K-콘텐츠 적합성 높음 · 저작권 주의 필요',
        source: sources['kocca']!,
      ),
      item(
        id: 'seed_rural_smartfarm',
        title: '스마트팜 초보 경영 가이드',
        category: IdeaBankCategories.rural,
        oneLiner: '귀농·소규모 농가의 데이터·자동화 입문',
        whyNow: '농촌 인력 부족과 스마트농업 확산',
        target: '귀농 준비자, 소규모 농가',
        how: '전자책·지식사이트·지역 콘텐츠로 확장',
        product: 'ebook',
        difficulty: '중',
        scoreNote: '평가: 지역사업 적합성 높음',
        source: sources['rda']!,
      ),
      item(
        id: 'seed_industrial_vision',
        title: '비전검사 도입 체크리스트 사이트',
        category: IdeaBankCategories.industrial,
        oneLiner: '중소 공장의 비전검사 도입 전 확인 항목을 정리',
        whyNow: '품질·인력 이슈로 검사 자동화 관심 증가',
        target: '제조 품질·설비 담당자',
        how: '지식사이트 + 산업자동화 상담 유입',
        product: 'site',
        difficulty: '중상',
        scoreNote: '평가: 산업자동화 적합성 높음',
        source: sources['msit']!,
      ),
      item(
        id: 'seed_export_digital',
        title: '소상공인 해외 판매 랜딩 템플릿',
        category: IdeaBankCategories.promoIdea,
        oneLiner: '수출·해외 고객용 간단한 홍보 페이지 뼈대',
        whyNow: '디지털 수출·온라인 판로 확대 정책 환경',
        target: '수출 준비 소상공인·중소기업',
        how: '마케팅사이트 워크플로로 제작 검토',
        product: 'promo_site',
        difficulty: '중',
        scoreNote: '평가: 홍보/전환 적합성 중상',
        source: sources['kotra']!,
      ),
      item(
        id: 'seed_dev_trend',
        title: '개발자 도구·오픈소스 트렌드 브리핑',
        category: IdeaBankCategories.issueOpportunity,
        oneLiner: '주간 트렌딩 기술을 사업 관점으로 요약',
        whyNow: '기술 변화 속도가 빨라 선별 요약 수요 존재',
        target: '기술 기반 사업가·개발 리더',
        how: '콘텐츠/뉴스레터형 사이트',
        product: 'site',
        difficulty: '하',
        scoreNote: '평가: 트렌드성 중 · 지속 업데이트 필요',
        source: sources['github']!,
      ),
      item(
        id: 'seed_policy_scan',
        title: '정책·지원사업 아이디어 스캔',
        category: IdeaBankCategories.issueOpportunity,
        oneLiner: '공개 정책 브리핑에서 사업 힌트를 찾는 루틴',
        whyNow: '정부 공개 자료는 출처가 명확해 아이디어 근거로 활용 가능',
        target: '정책 연계 사업·컨설팅 관심자',
        how: '아이디어 뱅크에 주기 기록 → 작업지시 후보',
        product: 'ebook',
        difficulty: '하',
        scoreNote: '평가: 출처 신뢰도 높음',
        source: sources['korea']!,
      ),
      item(
        id: 'seed_oecd_skill',
        title: '성인 재교육·스킬 전자책',
        category: IdeaBankCategories.worldTrend,
        oneLiner: '평생학습·직무 전환을 돕는 실용 가이드',
        whyNow: '노동시장·스킬 변화는 국제기구에서도 지속 다루는 주제',
        target: '재취업·직무전환 준비자',
        how: '전자책 시리즈',
        product: 'ebook',
        difficulty: '중',
        scoreNote: '평가: 장기 수요 가능',
        source: sources['oecd']!,
      ),
      item(
        id: 'seed_search_signal',
        title: '검색 관심사 기반 콘텐츠 기획',
        category: IdeaBankCategories.contentsIdea,
        oneLiner: '검색 관심 변화를 콘텐츠 주제로 연결',
        whyNow: '관심사 변화는 콘텐츠·전자책 주제 발굴에 유용',
        target: '콘텐츠 창작자·마케터',
        how: '쇼츠/전자책 주제 후보로 저장',
        product: 'contents',
        difficulty: '하',
        scoreNote: '평가: 탐색 도구로 활용 (단정 금지)',
        source: sources['trends']!,
      ),
    ];
  }
}
