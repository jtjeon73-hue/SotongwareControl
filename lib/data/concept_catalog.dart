/// Concept seed catalog — category + audience weights + artifact variants.
/// Scores are local heuristics, not market statistics.
library;

import '../models/artifact_type.dart';
import '../models/concept_candidate.dart';

/// Commercial positioning metadata for studio UX (not market statistics).
class ConceptCommercialMeta {
  const ConceptCommercialMeta({
    this.shortDescription = '',
    required this.customerProblem,
    required this.promisedOutcome,
    required this.reasonsToPay,
    required this.uniqueValue,
    this.monetizationModels = const [],
    this.qualityProfileTemplate = '',
    this.recommendationReason = '',
    this.difficulty = 'medium',
  });

  final String shortDescription;
  final String customerProblem;
  final String promisedOutcome;
  final List<String> reasonsToPay;
  final String uniqueValue;
  final List<String> monetizationModels;
  final String qualityProfileTemplate;
  final String recommendationReason;
  final String difficulty;
}

class ConceptSeed {
  const ConceptSeed({
    required this.id,
    required this.category,
    required this.tags,
    required this.audienceWeights,
    required this.baseScores,
    required this.variants,
    this.subtypes = const [],
    this.commercial,
    this.active = true,
    this.deprecated = false,
    this.replacementSeedId,
    this.catalogVersion = 1,
    this.updatedAt = '',
  });

  final String id;
  final String category;
  final List<String> tags;

  /// audienceId -> 0..5 affinity
  final Map<String, double> audienceWeights;

  /// Keys: ai, need, business, diff, practical, beginner, longevity (1..5)
  final Map<String, double> baseScores;

  /// artifactType -> (title, description)
  final Map<String, (String, String)> variants;
  final List<String> subtypes;
  final ConceptCommercialMeta? commercial;
  final bool active;
  final bool deprecated;
  final String? replacementSeedId;
  final int catalogVersion;
  final String updatedAt;
}

class ConceptCatalog {
  ConceptCatalog._();

  static Map<String, double> _scores({
    double ai = 3.5,
    double need = 3.5,
    double business = 3.5,
    double diff = 3.5,
    double practical = 3.5,
    double beginner = 3.5,
    double longevity = 3.5,
  }) => {
    'ai': ai,
    'need': need,
    'business': business,
    'diff': diff,
    'practical': practical,
    'beginner': beginner,
    'longevity': longevity,
  };

  static Map<String, double> _w(Map<String, double> m) => m;

  /// Compact seed list — expanded per artifact at recommend time.
  static final seeds = <ConceptSeed>[
    // --- AI ---
    ConceptSeed(
      id: 'ai_second_career',
      category: ConceptCategory.ai,
      tags: const ['AI', '제2직업', '커리어'],
      audienceWeights: _w({
        'retire_prep': 5,
        'age_40_60': 5,
        'office': 4,
        'general': 3,
      }),
      baseScores: _scores(ai: 5, need: 4.5, business: 4, beginner: 3.5),
      commercial: const ConceptCommercialMeta(
        shortDescription: 'AI로 경험을 상품화하는 제2직업 실행 가이드',
        customerProblem:
            '은퇴·직장 전환기에 제2직업을 고민하지만 AI 활용법과 상품화 경로를 모르는 40~60대',
        promisedOutcome:
            'AI 도구로 경험을 정리하고 전자책·코스·앱 중 하나로 실행 가능한 제2직업 로드맵 확보',
        reasonsToPay: [
          '맞춤형 커리어 전환 로드맵',
          'AI 도구별 실전 템플릿',
          '단계별 실행 체크리스트',
        ],
        uniqueValue: '은퇴·전환 경험을 AI 워크플로로 상품화하는 실전형 가이드',
        monetizationModels: ['one_time_ebook', 'online_course', 'subscription_app'],
        qualityProfileTemplate: 'career_transition_commercial',
        recommendationReason: '전환기 고객의 AI 활용·상품화 니즈가 높고 수익화 경로가 명확합니다.',
        difficulty: 'medium',
      ),
      variants: {
        ArtifactType.ebook: (
          'AI로 만드는 제2직업 설계 가이드',
          '은퇴·전환기 경험을 AI 도구로 상품화하는 단계별 전자책',
        ),
        ArtifactType.app: ('제2직업 AI 로드맵 앱', '목표·스킬·실행 체크를 돕는 개인 커리어 앱'),
        ArtifactType.contents: ('제2직업 AI 활용 쇼츠/영상', '짧게 따라 하는 AI 도구 활용 시리즈'),
        ArtifactType.site: ('제2직업 AI 지식관', '전환 사례·도구·체크리스트 허브'),
        ArtifactType.promoSite: ('제2직업 코스 랜딩', '전자책·코스 전환용 홍보 랜딩'),
      },
    ),
    ConceptSeed(
      id: 'ai_daily_assistant',
      category: ConceptCategory.ai,
      tags: const ['AI', '생활', '생산성'],
      audienceWeights: _w({
        'general': 5,
        'office': 4,
        'student': 4,
        'age_40_60': 4,
        'age_60_80': 3,
      }),
      baseScores: _scores(ai: 5, practical: 5, beginner: 4.5, need: 4),
      commercial: const ConceptCommercialMeta(
        shortDescription: '일상 업무·생활에 바로 쓰는 AI 입문 실전 가이드',
        customerProblem:
            'AI를 들어봤지만 검색·요약·문서 초안 등 실생활에 안전하게 쓰는 법을 모르는 초보',
        promisedOutcome:
            '하루 10분 루틴으로 AI를 일상·업무에 적용하고 실수·개인정보 리스크를 줄이는 습관 형성',
        reasonsToPay: [
          '초보 친화 프롬프트 모음',
          '개인정보·사기 주의 체크리스트',
          '직장·가정별 활용 시나리오',
        ],
        uniqueValue: '과장 없이 안전하게 시작하는 생활 밀착형 AI 입문 콘텐츠',
        monetizationModels: ['one_time_ebook', 'freemium_app', 'short_video_series'],
        qualityProfileTemplate: 'ai_beginner_commercial',
        recommendationReason: '범용 니즈가 크고 초보 적합도·실용성이 높아 첫 상품으로 적합합니다.',
        difficulty: 'low',
      ),
      variants: {
        ArtifactType.ebook: ('일상 AI 활용 입문', '검색·요약·일정·문서 초안을 안전하게 쓰는 방법'),
        ArtifactType.app: ('생활 AI 체크 앱', '자주 쓰는 AI 프롬프트·주의사항을 모아 둔 앱'),
        ArtifactType.contents: ('하루 1분 AI 팁 콘텐츠', '쇼츠·영상으로 보는 생활 AI'),
        ArtifactType.site: ('생활 AI 활용관', '초보용 가이드·프롬프트 모음'),
        ArtifactType.promoSite: ('AI 입문 상품 랜딩', '전자책/클래스 홍보'),
      },
    ),
    ConceptSeed(
      id: 'ai_work_boost',
      category: ConceptCategory.productivity,
      tags: const ['AI', '업무', '직장'],
      audienceWeights: _w({
        'office': 5,
        'student': 3,
        'smb': 3,
        'age_40_60': 3,
      }),
      baseScores: _scores(ai: 5, practical: 5, business: 3.5, beginner: 4),
      commercial: const ConceptCommercialMeta(
        customerProblem:
            '보고서·회의록·메일 초안 작성에 시간을 많이 쓰지만 AI를 업무에 안전하게 적용하지 못하는 직장인',
        promisedOutcome:
            '직무별 AI 템플릿으로 문서 작성 시간을 줄이고 품질·보안 기준을 지키는 업무 루틴 확립',
        reasonsToPay: [
          '직무별 프롬프트·템플릿',
          '회사 보안·저작권 주의 가이드',
          'Before/After 업무 시나리오',
        ],
        uniqueValue: '직장인 업무 흐름에 맞춘 AI 생산성 매뉴얼',
        monetizationModels: ['one_time_ebook', 'b2b_training', 'template_app'],
        qualityProfileTemplate: 'productivity_commercial',
        recommendationReason: '직장인 대상 실용 니즈가 뚜렷하고 B2C·사내교육 수익 모델이 가능합니다.',
      ),
      variants: {
        ArtifactType.ebook: ('직장인 AI 업무 가속 매뉴얼', '보고서·회의록·메일 초안을 안전하게'),
        ArtifactType.app: ('업무 AI 템플릿 앱', '직무별 프롬프트·체크리스트'),
        ArtifactType.contents: ('직장 AI 활용 쇼츠', '출근 전 1분 팁'),
        ArtifactType.site: ('업무 AI 지식관', '직무·도구별 가이드'),
        ArtifactType.promoSite: ('업무 생산성 코스 랜딩', 'B2C/사내교육 홍보'),
      },
    ),
    ConceptSeed(
      id: 'ai_study_helper',
      category: ConceptCategory.education,
      tags: const ['AI', '학습', '학생'],
      audienceWeights: _w({'student': 5, 'office': 3, 'general': 3}),
      baseScores: _scores(ai: 5, beginner: 4.5, practical: 4.5, need: 4),
      variants: {
        ArtifactType.ebook: ('AI 학습 도우미 활용법', '요약·퀴즈·오답 정리 루틴'),
        ArtifactType.app: ('학습 퀴즈 AI 앱', '복습 카드·퀴즈 생성'),
        ArtifactType.contents: ('공부 AI 팁 영상', '시험 대비 숏폼'),
        ArtifactType.site: ('학습 AI 허브', '과목별 학습법'),
        ArtifactType.promoSite: ('학습 코스 랜딩', '학생·학부모 대상'),
      },
    ),
    ConceptSeed(
      id: 'ai_senior_safe',
      category: ConceptCategory.ai,
      tags: const ['AI', '시니어', '안전'],
      audienceWeights: _w({
        'age_60_80': 5,
        'age_40_60': 4,
        'retire_prep': 4,
        'rural': 3,
      }),
      baseScores: _scores(ai: 4.5, beginner: 5, need: 4.5, practical: 4.5),
      variants: {
        ArtifactType.ebook: ('시니어를 위한 안전한 AI 사용', '사기 주의·큰글씨·쉬운 예시'),
        ArtifactType.app: ('시니어 AI 도우미 앱', '큰 버튼·음성 안내 중심'),
        ArtifactType.contents: ('시니어 AI 따라하기 영상', '천천히·반복 가능한 구성'),
        ArtifactType.site: ('시니어 AI 안내관', '가족도 함께 보는 가이드'),
        ArtifactType.promoSite: ('시니어 AI 클래스 랜딩', '오프라인/온라인 모집'),
      },
    ),
    // --- Money / side income ---
    ConceptSeed(
      id: 'online_income_start',
      category: ConceptCategory.money,
      tags: const ['수익', '부업', '온라인'],
      audienceWeights: _w({
        'retire_prep': 5,
        'age_40_60': 5,
        'office': 4,
        'rural': 4,
        'returning_farm': 4,
        'smb': 3,
        'general': 4,
      }),
      baseScores: _scores(business: 4.5, need: 4.5, practical: 4, ai: 3.5),
      commercial: const ConceptCommercialMeta(
        customerProblem:
            '온라인 부업·수익을 시작하고 싶지만 과장된 정보에 지치고 실행 순서를 모르는 예비 창업자',
        promisedOutcome:
            '채널·상품·루틴을 현실적으로 설계하고 첫 실험까지 실행하는 온라인 수익 로드맵',
        reasonsToPay: [
          '과장 없는 채널별 비교',
          '첫 30일 실행 체크리스트',
          '비용·시간 현실 점검표',
        ],
        uniqueValue: '기대관리와 실행 순서를 함께 잡는 온라인 수익 입문 가이드',
        monetizationModels: ['one_time_ebook', 'coaching', 'membership'],
        qualityProfileTemplate: 'income_starter_commercial',
        recommendationReason: '부업·노후 준비 니즈가 넓고 전자책·코칭 전환율이 높은 주제입니다.',
      ),
      variants: {
        ArtifactType.ebook: ('온라인 수익 첫걸음', '과장 없는 실행 체크리스트'),
        ArtifactType.app: ('수익 실험 트래커 앱', '채널·매출·비용을 기록'),
        ArtifactType.contents: ('부업 현실 토크 콘텐츠', '기대관리·사례 중심'),
        ArtifactType.site: ('온라인 수익 지식관', '채널별 입문 정리'),
        ArtifactType.promoSite: ('수익 가이드 판매 랜딩', '전자책/코스 CTA'),
      },
    ),
    ConceptSeed(
      id: 'experience_productize',
      category: ConceptCategory.business,
      tags: const ['경험', '상품화', '디지털'],
      audienceWeights: _w({
        'age_40_60': 5,
        'retire_prep': 5,
        'office': 4,
        'smb': 4,
        'rural': 3,
      }),
      baseScores: _scores(diff: 4.5, business: 4.5, need: 4.5, practical: 4),
      commercial: const ConceptCommercialMeta(
        customerProblem:
            '오랜 현장 경험은 있지만 디지털 상품(전자책·코스·앱)으로 패키징하는 방법을 모르는 전문가',
        promisedOutcome:
            '경험을 커리큘럼·콘텐츠·판매 페이지로 구조화해 첫 디지털 상품을 출시',
        reasonsToPay: [
          '경험→커리큘럼 변환 프레임',
          '가격·포지셔닝 가이드',
          '판매 페이지 구성 템플릿',
        ],
        uniqueValue: '50대+ 현장 노하우를 디지털 상품으로 만드는 실전 패키징',
        monetizationModels: ['one_time_ebook', 'online_course', 'consulting'],
        qualityProfileTemplate: 'expert_productize_commercial',
        recommendationReason: '고객 지불 의사가 높은 전문가형 상품화 주제로 마진이 좋습니다.',
        difficulty: 'high',
      ),
      variants: {
        ArtifactType.ebook: ('50대 경험을 디지털 상품으로', '커리큘럼·패키징·판매 초안'),
        ArtifactType.app: ('경험 아카이브 앱', '노하우를 카드로 정리'),
        ArtifactType.contents: ('경험 스토리 시리즈', '쇼츠·영상 에피소드화'),
        ArtifactType.site: ('전문가 경험 허브', '주제별 아카이브'),
        ArtifactType.promoSite: ('경험 상품 판매 페이지', '신뢰·후기·CTA'),
      },
    ),
    ConceptSeed(
      id: 'cashflow_retire',
      category: ConceptCategory.retirement,
      tags: const ['노후', '현금흐름', '은퇴'],
      audienceWeights: _w({'retire_prep': 5, 'age_40_60': 5, 'age_60_80': 4}),
      baseScores: _scores(need: 5, longevity: 5, business: 3.5, beginner: 3.5),
      commercial: const ConceptCommercialMeta(
        customerProblem:
            '은퇴 후 현금흐름과 부수입 시나리오를 구체적으로 설계하지 못한 40~60대',
        promisedOutcome:
            '월별 수입·지출·부수입 시나리오를 시뮬레이션하고 실행 우선순위를 정하는 노후 재무 계획',
        reasonsToPay: [
          '현실적인 시나리오 템플릿',
          '정책·연금 체크 포인트',
          '부수입 연계 실행표',
        ],
        uniqueValue: '과장 없는 노후 현금흐름 설계와 실행 우선순위 가이드',
        monetizationModels: ['one_time_ebook', 'consulting', 'subscription_app'],
        qualityProfileTemplate: 'retirement_planning_commercial',
        recommendationReason: '노후 준비 니즈가 지속적이고 신뢰 기반 상담·콘텐츠 수요가 큽니다.',
      ),
      variants: {
        ArtifactType.ebook: ('노후 현금흐름 설계 노트', '수입·지출·부수입 시나리오'),
        ArtifactType.app: ('노후 현금흐름 앱', '월별 시나리오 시뮬'),
        ArtifactType.contents: ('노후 준비 이야기 콘텐츠', '현실적인 점검 포인트'),
        ArtifactType.site: ('노후 준비 지식관', '정책·체크리스트'),
        ArtifactType.promoSite: ('노후 설계 상담 랜딩', '리드 수집 CTA'),
      },
    ),
    // --- Rural / farm ---
    ConceptSeed(
      id: 'smart_farm_log',
      category: ConceptCategory.rural,
      tags: const ['스마트팜', '기록', '농사'],
      audienceWeights: _w({
        'rural': 5,
        'returning_farm': 5,
        'age_40_60': 3,
        'smb': 2,
      }),
      baseScores: _scores(practical: 5, ai: 4, need: 4.5, diff: 4),
      variants: {
        ArtifactType.ebook: ('AI 농사 기록 활용법', '일지·날씨·수확을 데이터로'),
        ArtifactType.app: ('농작업 기록 앱', '일정·병해충·수확 로그'),
        ArtifactType.contents: ('농사 일상 쇼츠/영상', '현장 스토리·팁'),
        ArtifactType.site: ('스마트팜 지식관', '기술·사례·용어'),
        ArtifactType.promoSite: ('농산물·체험 홍보 랜딩', '직거래·예약 CTA'),
      },
    ),
    ConceptSeed(
      id: 'pest_record',
      category: ConceptCategory.rural,
      tags: const ['병해충', '기록', '농업'],
      audienceWeights: _w({'rural': 5, 'returning_farm': 4}),
      baseScores: _scores(practical: 5, need: 4.5, beginner: 3.5, ai: 3.5),
      variants: {
        ArtifactType.ebook: ('병해충 관찰 기록 가이드', '사진·증상·조치 템플릿'),
        ArtifactType.app: ('병해충 기록 앱', '사진+메모+알림'),
        ArtifactType.contents: ('병해충 대응 영상', '현장 체크 포인트'),
        ArtifactType.site: ('병해충 정보관', '증상별 정리'),
        ArtifactType.promoSite: ('농업 솔루션 랜딩', '도구/교육 홍보'),
      },
    ),
    ConceptSeed(
      id: 'farm_order_mgmt',
      category: ConceptCategory.business,
      tags: const ['주문', '직거래', '농산물'],
      audienceWeights: _w({'rural': 5, 'returning_farm': 4, 'smb': 4}),
      baseScores: _scores(business: 4.5, practical: 4.5, need: 4),
      variants: {
        ArtifactType.ebook: ('농산물 직거래 운영 매뉴얼', '주문·포장·고객응대'),
        ArtifactType.app: ('농산물 주문관리 앱', '주문·재고·배송 메모'),
        ArtifactType.contents: ('직거래 홍보 콘텐츠', '수확·포장 비하인드'),
        ArtifactType.site: ('직거래 안내 사이트', '상품·일정·문의'),
        ArtifactType.promoSite: ('농산물 직거래 랜딩', '주문 CTA 중심'),
      },
    ),
    ConceptSeed(
      id: 'return_farm_guide',
      category: ConceptCategory.rural,
      tags: const ['귀농', '귀촌', '정착'],
      audienceWeights: _w({
        'returning_farm': 5,
        'retire_prep': 4,
        'age_40_60': 4,
        'rural': 3,
      }),
      baseScores: _scores(need: 5, longevity: 4.5, practical: 4, beginner: 3.5),
      commercial: const ConceptCommercialMeta(
        shortDescription: '귀농·귀촌 정착과 지원 정책을 한곳에서 안내',
        customerProblem:
            '귀농·귀촌을 준비하지만 지원 정책·절차·현실 비용 정보가 흩어져 있어 실수하기 쉬운 예비 귀농인',
        promisedOutcome:
            '지원사업·절차·정착 체크리스트를 한곳에서 확인하고 신청·준비 순서를 놓치지 않음',
        reasonsToPay: [
          '지원·절차 카테고리별 정리',
          '마감·서류 체크리스트',
          '정착 실패 포인트 사전 점검',
        ],
        uniqueValue: '귀농 정책 정보와 정착 실전을 통합한 신뢰형 허브',
        monetizationModels: ['membership', 'consulting', 'premium_guide'],
        qualityProfileTemplate: 'rural_policy_commercial',
        recommendationReason: '귀농·귀촌 니즈가 구체적이고 정책·정착 정보 통합 가치가 큽니다.',
      ),
      variants: {
        ArtifactType.ebook: ('귀농·귀촌 정착 실전', '준비·비용·관계·실패 포인트'),
        ArtifactType.app: ('귀촌 준비 체크 앱', '단계별 할 일'),
        ArtifactType.contents: ('귀촌 브이로그/쇼츠', '현실 공감 스토리'),
        ArtifactType.site: ('귀농 정책 정보관', '지원·절차 모음'),
        ArtifactType.promoSite: ('귀촌 체험/교육 랜딩', '신청 CTA'),
      },
    ),
    ConceptSeed(
      id: 'rural_online',
      category: ConceptCategory.money,
      tags: const ['시골', '온라인', '수익'],
      audienceWeights: _w({
        'rural': 5,
        'returning_farm': 5,
        'age_40_60': 4,
        'retire_prep': 3,
      }),
      baseScores: _scores(business: 4, need: 4.5, ai: 3.5, practical: 4),
      variants: {
        ArtifactType.ebook: ('시골에서 온라인 수익 만들기', '채널·상품·루틴'),
        ArtifactType.app: ('시골 비즈니스 메모 앱', '아이디어·고객·매출'),
        ArtifactType.contents: ('시골생활 수익 콘텐츠', '현실적 사례'),
        ArtifactType.site: ('시골 온라인 사업 허브', '사례·도구'),
        ArtifactType.promoSite: ('시골 브랜드 홍보 랜딩', '스토리+구매'),
      },
    ),
    ConceptSeed(
      id: 'farm_machine',
      category: ConceptCategory.tech,
      tags: const ['농기계', '관리', '점검'],
      audienceWeights: _w({'rural': 5, 'returning_farm': 3}),
      baseScores: _scores(practical: 4.5, diff: 4, beginner: 3, need: 4),
      variants: {
        ArtifactType.ebook: ('농기계 점검·관리 노트', '주기·부품·안전'),
        ArtifactType.app: ('농기계 관리 앱', '점검 일정·이력'),
        ArtifactType.contents: ('농기계 팁 영상', '안전 수칙 중심'),
        ArtifactType.site: ('농기계 관리 지식관', '기종별 메모'),
        ArtifactType.promoSite: ('정비/교육 서비스 랜딩', '예약 CTA'),
      },
    ),
    // --- SMB ---
    ConceptSeed(
      id: 'smb_local_promo',
      category: ConceptCategory.marketing,
      tags: const ['소상공인', '홍보', '로컬'],
      audienceWeights: _w({'smb': 5, 'general': 2, 'office': 2}),
      baseScores: _scores(business: 4.5, practical: 4.5, need: 5, beginner: 4),
      variants: {
        ArtifactType.ebook: ('동네 가게 홍보 실전', '사진·문구·채널 루틴'),
        ArtifactType.app: ('매장 홍보 체크 앱', '주간 콘텐츠 할 일'),
        ArtifactType.contents: ('가게 비하인드 쇼츠', '단골 만들기'),
        ArtifactType.site: ('로컬 비즈니스 가이드', '업종별 팁'),
        ArtifactType.promoSite: ('매장/상품 랜딩페이지', '예약·문의 CTA'),
      },
    ),
    ConceptSeed(
      id: 'smb_review_reply',
      category: ConceptCategory.marketing,
      tags: const ['리뷰', '응대', 'AI'],
      audienceWeights: _w({'smb': 5}),
      baseScores: _scores(ai: 4.5, practical: 5, beginner: 4.5, business: 4),
      variants: {
        ArtifactType.ebook: ('리뷰 응대 문장 가이드', '톤·주의·템플릿'),
        ArtifactType.app: ('리뷰 답변 도우미 앱', '초안 생성+수정'),
        ArtifactType.contents: ('리뷰 응대 팁 쇼츠', '실수 사례'),
        ArtifactType.site: ('고객응대 지식관', '업종별 예시'),
        ArtifactType.promoSite: ('응대 코스/도구 랜딩', '체험 CTA'),
      },
    ),
    ConceptSeed(
      id: 'smb_menu_photo',
      category: ConceptCategory.content,
      tags: const ['메뉴', '사진', '홍보'],
      audienceWeights: _w({'smb': 5}),
      baseScores: _scores(practical: 4.5, beginner: 4.5, business: 4),
      variants: {
        ArtifactType.ebook: ('메뉴·상품 사진 촬영법', '폰으로 충분'),
        ArtifactType.app: ('촬영 체크리스트 앱', '조명·각도·문구'),
        ArtifactType.contents: ('메뉴 숏폼 콘텐츠', '식감·분위기'),
        ArtifactType.site: ('비주얼 머천다이징 가이드', '사례'),
        ArtifactType.promoSite: ('메뉴북/세트 홍보 랜딩', '주문 CTA'),
      },
    ),
    ConceptSeed(
      id: 'smb_booking',
      category: ConceptCategory.business,
      tags: const ['예약', '운영', '단골'],
      audienceWeights: _w({'smb': 5}),
      baseScores: _scores(practical: 5, business: 4.5, need: 4.5),
      variants: {
        ArtifactType.ebook: ('예약·고객 관리 입문', '노쇼·리마인드'),
        ArtifactType.app: ('간단 예약 관리 앱', '일정·고객 메모'),
        ArtifactType.contents: ('운영 팁 영상', '피크타임 대응'),
        ArtifactType.site: ('예약 안내 사이트', '시간표·문의'),
        ArtifactType.promoSite: ('예약 전환 랜딩', '바로 예약 CTA'),
      },
    ),
    // --- Health / life ---
    ConceptSeed(
      id: 'health_habit',
      category: ConceptCategory.health,
      tags: const ['건강', '습관', '루틴'],
      audienceWeights: _w({
        'age_40_60': 5,
        'age_60_80': 5,
        'retire_prep': 4,
        'general': 4,
        'office': 3,
      }),
      baseScores: _scores(need: 4.5, longevity: 5, beginner: 4.5, practical: 4),
      variants: {
        ArtifactType.ebook: ('중장년 건강 습관 설계', '운동·수면·식사 루틴'),
        ArtifactType.app: ('건강 루틴 트래커', '간단한 체크만'),
        ArtifactType.contents: ('건강 습관 쇼츠', '과장 없는 팁'),
        ArtifactType.site: ('건강 습관 지식관', '주제별 정리'),
        ArtifactType.promoSite: ('건강 클래스/도구 랜딩', '신청 CTA'),
      },
    ),
    ConceptSeed(
      id: 'sleep_reset',
      category: ConceptCategory.health,
      tags: const ['수면', '회복'],
      audienceWeights: _w({
        'office': 4,
        'age_40_60': 4,
        'general': 4,
        'student': 3,
      }),
      baseScores: _scores(need: 4, practical: 4, beginner: 4.5),
      variants: {
        ArtifactType.ebook: ('수면 리셋 가이드', '카페인·빛·루틴'),
        ArtifactType.app: ('수면 루틴 앱', '취침 전 체크'),
        ArtifactType.contents: ('수면 팁 ASMR/쇼츠', '차분한 톤'),
        ArtifactType.site: ('수면 개선 허브', '체크리스트'),
        ArtifactType.promoSite: ('수면 코스 랜딩', '전환'),
      },
    ),
    ConceptSeed(
      id: 'digital_literacy',
      category: ConceptCategory.education,
      tags: const ['디지털', '스마트폰', '기초'],
      audienceWeights: _w({
        'age_60_80': 5,
        'age_40_60': 4,
        'rural': 4,
        'retire_prep': 4,
      }),
      baseScores: _scores(beginner: 5, need: 4.5, practical: 5, ai: 3),
      variants: {
        ArtifactType.ebook: ('스마트폰·디지털 기초', '큰글씨·스크린샷 중심'),
        ArtifactType.app: ('디지털 기초 연습 앱', '단계별 미션'),
        ArtifactType.contents: ('따라하기 영상', '천천히 반복'),
        ArtifactType.site: ('디지털 기초관', '가족 공유용'),
        ArtifactType.promoSite: ('오프라인 수업 랜딩', '수강 신청'),
      },
    ),
    // --- Student ---
    ConceptSeed(
      id: 'student_portfolio',
      category: ConceptCategory.education,
      tags: const ['포트폴리오', '진로'],
      audienceWeights: _w({'student': 5}),
      baseScores: _scores(need: 4.5, practical: 4.5, beginner: 3.5, ai: 4),
      variants: {
        ArtifactType.ebook: ('학생 포트폴리오 만들기', '주제·증거·발표'),
        ArtifactType.app: ('포트폴리오 빌더 앱', '항목 템플릿'),
        ArtifactType.contents: ('포트폴리오 팁 쇼츠', '실수 사례'),
        ArtifactType.site: ('진로·포트폴리오 허브', '예시 갤러리'),
        ArtifactType.promoSite: ('멘토링/코스 랜딩', '신청'),
      },
    ),
    ConceptSeed(
      id: 'student_side_skill',
      category: ConceptCategory.money,
      tags: const ['스킬', '부업', '학생'],
      audienceWeights: _w({'student': 5, 'office': 2}),
      baseScores: _scores(business: 3.5, beginner: 4, ai: 4, need: 3.5),
      variants: {
        ArtifactType.ebook: ('학생 스킬 수익화 입문', '과한 약속 없이'),
        ArtifactType.app: ('스킬 연습 트래커', '시간·결과물'),
        ArtifactType.contents: ('스킬 챌린지 콘텐츠', '주간 미션'),
        ArtifactType.site: ('스킬 학습관', '로드맵'),
        ArtifactType.promoSite: ('스킬 클래스 랜딩', '수강 CTA'),
      },
    ),
    // --- Tech / PLC ---
    ConceptSeed(
      id: 'plc_intro',
      category: ConceptCategory.tech,
      tags: const ['PLC', '자동화', '전기'],
      audienceWeights: _w({
        'rural': 3,
        'returning_farm': 3,
        'office': 3,
        'age_40_60': 3,
        'smb': 2,
      }),
      baseScores: _scores(diff: 5, beginner: 2.5, longevity: 4.5, practical: 4),
      variants: {
        ArtifactType.ebook: ('PLC·자동화 입문 노트', '용어·안전·실습 순서'),
        ArtifactType.app: ('PLC 용어/체크 앱', '현장 메모'),
        ArtifactType.contents: ('자동화 기초 영상', '짧게·시각적'),
        ArtifactType.site: ('산업자동화 지식관', '모듈별 정리'),
        ArtifactType.promoSite: ('교육/키트 랜딩', '문의 CTA'),
      },
    ),
    ConceptSeed(
      id: 'home_electric_safe',
      category: ConceptCategory.tech,
      tags: const ['전기', '안전', '생활'],
      audienceWeights: _w({
        'rural': 4,
        'general': 4,
        'age_40_60': 3,
        'returning_farm': 3,
      }),
      baseScores: _scores(practical: 5, need: 4, beginner: 3.5),
      variants: {
        ArtifactType.ebook: ('생활 전기 안전 가이드', '하면 안 되는 것 중심'),
        ArtifactType.app: ('전기 점검 체크 앱', '계절별 점검'),
        ArtifactType.contents: ('전기 안전 쇼츠', '주의 강조'),
        ArtifactType.site: ('전기 안전 정보관', 'FAQ'),
        ArtifactType.promoSite: ('점검 서비스 랜딩', '예약'),
      },
    ),
    // --- Content craft ---
    ConceptSeed(
      id: 'shorts_story',
      category: ConceptCategory.content,
      tags: const ['쇼츠', '스토리', '콘텐츠'],
      audienceWeights: _w({
        'general': 4,
        'smb': 4,
        'office': 3,
        'student': 4,
        'rural': 3,
      }),
      baseScores: _scores(ai: 3.5, practical: 4.5, beginner: 4, business: 3.5),
      subtypes: const [
        ContentSubtype.shorts,
        ContentSubtype.video,
        ContentSubtype.songAndShorts,
        ContentSubtype.other,
      ],
      variants: {
        ArtifactType.ebook: ('쇼츠 스토리보드 작성법', '훅·전개·CTA'),
        ArtifactType.app: ('스토리보드 앱', '컷 단위 메모'),
        ArtifactType.contents: ('쇼츠 시리즈 자체 제작', '에피소드 포맷'),
        ArtifactType.site: ('숏폼 제작 가이드관', '예시'),
        ArtifactType.promoSite: ('콘텐츠 대행/코스 랜딩', '상담'),
      },
    ),
    ConceptSeed(
      id: 'song_brand',
      category: ConceptCategory.content,
      tags: const ['노래', '브랜딩', '감성'],
      audienceWeights: _w({
        'general': 4,
        'student': 3,
        'smb': 3,
        'rural': 3,
        'returning_farm': 3,
      }),
      baseScores: _scores(diff: 4.5, longevity: 4, beginner: 3, ai: 3.5),
      subtypes: const [
        ContentSubtype.song,
        ContentSubtype.songAndShorts,
        ContentSubtype.other,
      ],
      variants: {
        ArtifactType.ebook: ('브랜드 노래·사운드 기획', '메시지·길이·공개'),
        ArtifactType.app: ('가사/훅 메모 앱', '버전 관리'),
        ArtifactType.contents: ('테마 노래·쇼츠 연계', '음원+영상'),
        ArtifactType.site: ('사운드 브랜딩 허브', '사례'),
        ArtifactType.promoSite: ('음원/공연 홍보 랜딩', '듣기·예매'),
      },
    ),
    ConceptSeed(
      id: 'asmr_rural',
      category: ConceptCategory.content,
      tags: const ['ASMR', '시골', '힐링'],
      audienceWeights: _w({'rural': 4, 'general': 4, 'age_40_60': 3}),
      baseScores: _scores(diff: 4, longevity: 4, beginner: 4, business: 3),
      subtypes: const [
        ContentSubtype.video,
        ContentSubtype.shorts,
        ContentSubtype.other,
      ],
      variants: {
        ArtifactType.ebook: ('힐링 콘텐츠 기획 노트', '장면·소리·길이'),
        ArtifactType.app: ('촬영 장소/소리 로그 앱', '현장 메모'),
        ArtifactType.contents: ('시골 ASMR·풍경 영상', '시즌 시리즈'),
        ArtifactType.site: ('힐링 콘텐츠 아카이브', '에피소드'),
        ArtifactType.promoSite: ('채널/굿즈 랜딩', '구독·구매'),
      },
    ),
    // --- Relationship / community ---
    ConceptSeed(
      id: 'family_digital',
      category: ConceptCategory.relationship,
      tags: const ['가족', '디지털', '소통'],
      audienceWeights: _w({
        'age_40_60': 4,
        'age_60_80': 4,
        'general': 3,
        'retire_prep': 3,
      }),
      baseScores: _scores(need: 4, beginner: 4.5, practical: 4),
      variants: {
        ArtifactType.ebook: ('가족과 함께하는 디지털', '가르침·경계·안전'),
        ArtifactType.app: ('가족 미션 앱', '함께 배우기'),
        ArtifactType.contents: ('가족 챌린지 콘텐츠', '공감형'),
        ArtifactType.site: ('가족 디지털 가이드', '세대 공용'),
        ArtifactType.promoSite: ('워크숍 랜딩', '신청'),
      },
    ),
    ConceptSeed(
      id: 'local_community',
      category: ConceptCategory.relationship,
      tags: const ['동네', '커뮤니티', '연결'],
      audienceWeights: _w({
        'smb': 4,
        'rural': 4,
        'general': 3,
        'returning_farm': 3,
      }),
      baseScores: _scores(longevity: 4.5, need: 3.5, practical: 3.5),
      variants: {
        ArtifactType.ebook: ('동네 커뮤니티 운영 가이드', '모임·규칙·지속'),
        ArtifactType.app: ('모임 공지 앱', '일정·참석'),
        ArtifactType.contents: ('동네 이야기 콘텐츠', '사람 중심'),
        ArtifactType.site: ('지역 커뮤니티 허브', '공지·자료'),
        ArtifactType.promoSite: ('행사/모임 랜딩', '참가 CTA'),
      },
    ),
    // --- Hobby ---
    ConceptSeed(
      id: 'hobby_to_class',
      category: ConceptCategory.hobby,
      tags: const ['취미', '클래스', '수익'],
      audienceWeights: _w({
        'retire_prep': 4,
        'age_40_60': 4,
        'general': 4,
        'age_60_80': 3,
      }),
      baseScores: _scores(business: 4, beginner: 4, longevity: 4, need: 3.5),
      variants: {
        ArtifactType.ebook: ('취미를 클래스로 만드는 법', '커리큘럼·가격'),
        ArtifactType.app: ('클래스 준비 체크 앱', '재료·일정'),
        ArtifactType.contents: ('취미 클래스 티저', '비포·애프터'),
        ArtifactType.site: ('취미 클래스 허브', '카탈로그'),
        ArtifactType.promoSite: ('클래스 모집 랜딩', '신청'),
      },
    ),
    ConceptSeed(
      id: 'photo_journal',
      category: ConceptCategory.hobby,
      tags: const ['사진', '기록', '일상'],
      audienceWeights: _w({
        'general': 4,
        'student': 3,
        'retire_prep': 3,
        'rural': 3,
      }),
      baseScores: _scores(beginner: 4.5, longevity: 4, practical: 3.5),
      variants: {
        ArtifactType.ebook: ('일상 사진 기록법', '테마·편집·보관'),
        ArtifactType.app: ('포토 저널 앱', '태그·메모'),
        ArtifactType.contents: ('사진 일상 콘텐츠', '시즌 시리즈'),
        ArtifactType.site: ('사진 갤러리 사이트', '테마별'),
        ArtifactType.promoSite: ('프린트/클래스 랜딩', '구매'),
      },
    ),
    // --- More AI / business fillers for depth ---
    ConceptSeed(
      id: 'prompt_library',
      category: ConceptCategory.ai,
      tags: const ['프롬프트', '템플릿', 'AI'],
      audienceWeights: _w({
        'office': 5,
        'smb': 4,
        'student': 4,
        'general': 3,
        'age_40_60': 3,
      }),
      baseScores: _scores(ai: 5, practical: 5, beginner: 4, business: 3.5),
      variants: {
        ArtifactType.ebook: ('실전 프롬프트 라이브러리', '업무·학습·홍보용'),
        ArtifactType.app: ('프롬프트 북마크 앱', '분류·검색'),
        ArtifactType.contents: ('프롬프트 팁 쇼츠', '복붙 가능'),
        ArtifactType.site: ('프롬프트 지식관', '카테고리별'),
        ArtifactType.promoSite: ('프롬프트팩 판매 랜딩', '다운로드'),
      },
    ),
    ConceptSeed(
      id: 'meeting_ai',
      category: ConceptCategory.productivity,
      tags: const ['회의', '요약', 'AI'],
      audienceWeights: _w({'office': 5, 'smb': 3}),
      baseScores: _scores(ai: 5, practical: 5, need: 4),
      variants: {
        ArtifactType.ebook: ('회의 AI 요약 운영법', '동의·보안·템플릿'),
        ArtifactType.app: ('회의 액션아이템 앱', '할 일 추출'),
        ArtifactType.contents: ('회의 생산성 팁', '짧은 예시'),
        ArtifactType.site: ('회의 운영 가이드', '체크리스트'),
        ArtifactType.promoSite: ('팀 도구 랜딩', '도입 문의'),
      },
    ),
    ConceptSeed(
      id: 'policy_rural',
      category: ConceptCategory.rural,
      tags: const ['정책', '지원', '귀농'],
      audienceWeights: _w({'returning_farm': 5, 'rural': 5, 'retire_prep': 3}),
      baseScores: _scores(need: 5, practical: 4, longevity: 4, beginner: 3.5),
      deprecated: true,
      replacementSeedId: 'return_farm_guide',
      variants: {
        ArtifactType.ebook: ('귀농·농촌 지원 정책 읽는 법', '신청 전 체크'),
        ArtifactType.app: ('정책 메모 앱', '마감·서류'),
        ArtifactType.contents: ('정책 해설 쇼츠', '쉬운 말'),
        ArtifactType.site: ('귀농 정책 정보관', '카테고리 검색'),
        ArtifactType.promoSite: ('컨설팅/교육 랜딩', '상담'),
      },
    ),
    ConceptSeed(
      id: 'gov_support_scan',
      category: ConceptCategory.business,
      tags: const ['정부지원', '사업'],
      audienceWeights: _w({
        'smb': 5,
        'returning_farm': 4,
        'retire_prep': 3,
        'age_40_60': 3,
      }),
      baseScores: _scores(need: 4.5, practical: 4, business: 4),
      commercial: const ConceptCommercialMeta(
        customerProblem:
            '정부·지자체 지원사업이 많지만 내 사업에 맞는 것을 빠르게 골라내지 못하는 소상공인·창업자',
        promisedOutcome:
            '조건·마감·주의사항을 필터링해 적합한 지원사업 후보를 선별하고 신청 준비 시작',
        reasonsToPay: [
          '업종·규모별 필터 가이드',
          '신청 전 체크리스트',
          '자주 놓치는 탈락 사유 정리',
        ],
        uniqueValue: '지원사업을 빠르게 훑고 적합도를 판단하는 실무형 스캔 가이드',
        monetizationModels: ['one_time_ebook', 'consulting', 'subscription_updates'],
        qualityProfileTemplate: 'gov_support_commercial',
        recommendationReason: '소상공인·귀농 대상 실질 니즈가 크고 컨설팅·구독 업데이트 모델이 가능합니다.',
      ),
      variants: {
        ArtifactType.ebook: ('소상공인·창업 지원 훑어보기', '조건·주의'),
        ArtifactType.app: ('지원사업 체크 앱', '적합도 메모'),
        ArtifactType.contents: ('지원사업 요약 영상', '핵심만'),
        ArtifactType.site: ('지원사업 안내관', '필터'),
        ArtifactType.promoSite: ('신청 대행/교육 랜딩', '문의'),
      },
    ),
    ConceptSeed(
      id: 'tax_basic_smb',
      category: ConceptCategory.business,
      tags: const ['세무', '기초', '장부'],
      audienceWeights: _w({'smb': 5, 'office': 2}),
      baseScores: _scores(need: 4.5, beginner: 3.5, practical: 4.5),
      variants: {
        ArtifactType.ebook: ('사장님 세무·장부 기초', '전문가 상담 전 준비'),
        ArtifactType.app: ('증빙 메모 앱', '영수증 태그'),
        ArtifactType.contents: ('세무 기초 쇼츠', '용어 풀이'),
        ArtifactType.site: ('세무 기초관', 'FAQ'),
        ArtifactType.promoSite: ('세무 상담 랜딩', '예약'),
      },
    ),
    ConceptSeed(
      id: 'customer_journey',
      category: ConceptCategory.marketing,
      tags: const ['여정', '전환', '랜딩'],
      audienceWeights: _w({'smb': 4, 'office': 3, 'general': 2}),
      baseScores: _scores(business: 4.5, practical: 4, diff: 3.5),
      variants: {
        ArtifactType.ebook: ('고객 여정 설계 입문', '인지→구매'),
        ArtifactType.app: ('퍼널 체크 앱', '단계별 메모'),
        ArtifactType.contents: ('전환 팁 콘텐츠', 'CTA 예시'),
        ArtifactType.site: ('마케팅 기초관', '용어'),
        ArtifactType.promoSite: ('전환 최적화 랜딩', '데모'),
      },
    ),
    ConceptSeed(
      id: 'seo_knowledge',
      category: ConceptCategory.marketing,
      tags: const ['SEO', '검색', '지식'],
      audienceWeights: _w({'office': 3, 'smb': 3, 'student': 3, 'general': 3}),
      baseScores: _scores(longevity: 4.5, practical: 4, beginner: 3),
      variants: {
        ArtifactType.ebook: ('지식사이트 SEO 기초', '제목·구조·내부링크'),
        ArtifactType.app: ('키워드 메모 앱', '주제 클러스터'),
        ArtifactType.contents: ('SEO 팁 쇼츠', '흔한 실수'),
        ArtifactType.site: ('SEO·지식 허브 자체 구축', '카테고리 IA'),
        ArtifactType.promoSite: ('SEO 진단 랜딩', '문의'),
      },
    ),
    ConceptSeed(
      id: 'newsletter_start',
      category: ConceptCategory.content,
      tags: const ['뉴스레터', '구독', '관계'],
      audienceWeights: _w({
        'office': 3,
        'general': 3,
        'retire_prep': 3,
        'smb': 3,
      }),
      baseScores: _scores(longevity: 4.5, business: 3.5, beginner: 3.5),
      variants: {
        ArtifactType.ebook: ('뉴스레터 시작 가이드', '주제·주기·형식'),
        ArtifactType.app: ('발행 캘린더 앱', '초안 보관'),
        ArtifactType.contents: ('뉴스레터 홍보 숏폼', '구독 유도'),
        ArtifactType.site: ('아카이브 사이트', '지난 호'),
        ArtifactType.promoSite: ('구독 랜딩', '이메일 CTA'),
      },
    ),
    ConceptSeed(
      id: 'checklist_product',
      category: ConceptCategory.productivity,
      tags: const ['체크리스트', '템플릿', '상품'],
      audienceWeights: _w({
        'office': 4,
        'smb': 4,
        'age_40_60': 4,
        'retire_prep': 3,
        'general': 3,
      }),
      baseScores: _scores(practical: 5, business: 4, beginner: 4.5, ai: 3),
      variants: {
        ArtifactType.ebook: ('실행 체크리스트 전자책', '바로 쓰는 표'),
        ArtifactType.app: ('체크리스트 앱', '반복 루틴'),
        ArtifactType.contents: ('체크리스트 활용 영상', '데모'),
        ArtifactType.site: ('템플릿 배포 사이트', '다운로드'),
        ArtifactType.promoSite: ('템플릿팩 판매 랜딩', '구매'),
      },
    ),
    ConceptSeed(
      id: 'crisis_comm',
      category: ConceptCategory.marketing,
      tags: const ['위기', '공지', '신뢰'],
      audienceWeights: _w({'smb': 4, 'office': 3}),
      baseScores: _scores(need: 4, practical: 4, beginner: 3.5),
      variants: {
        ArtifactType.ebook: ('소상공인 위기 소통 가이드', '공지 문장'),
        ArtifactType.app: ('공지 초안 앱', '채널별 톤'),
        ArtifactType.contents: ('신뢰 소통 팁', '사례'),
        ArtifactType.site: ('공지/FAQ 허브', '투명성'),
        ArtifactType.promoSite: ('브랜드 신뢰 랜딩', '스토리'),
      },
    ),
    ConceptSeed(
      id: 'retire_hobby_income',
      category: ConceptCategory.retirement,
      tags: const ['은퇴', '취미', '부수입'],
      audienceWeights: _w({'retire_prep': 5, 'age_40_60': 4, 'age_60_80': 4}),
      baseScores: _scores(
        need: 4.5,
        longevity: 4.5,
        business: 3.5,
        beginner: 4,
      ),
      variants: {
        ArtifactType.ebook: ('은퇴 후 취미·부수입 설계', '과로 없이'),
        ArtifactType.app: ('은퇴 활동 플래너', '주간 루틴'),
        ArtifactType.contents: ('은퇴 라이프 콘텐츠', '공감'),
        ArtifactType.site: ('은퇴 라이프 허브', '주제별'),
        ArtifactType.promoSite: ('은퇴 클래스 랜딩', '모집'),
      },
    ),
    ConceptSeed(
      id: 'mobile_pay_safe',
      category: ConceptCategory.life,
      tags: const ['결제', '보안', '모바일'],
      audienceWeights: _w({
        'age_60_80': 5,
        'age_40_60': 4,
        'general': 3,
        'rural': 3,
      }),
      baseScores: _scores(need: 4.5, beginner: 4.5, practical: 4.5),
      variants: {
        ArtifactType.ebook: ('모바일 결제·보안 기초', '피싱 주의'),
        ArtifactType.app: ('보안 체크 앱', '점검 목록'),
        ArtifactType.contents: ('사기 예방 쇼츠', '실제 패턴'),
        ArtifactType.site: ('디지털 안전관', 'FAQ'),
        ArtifactType.promoSite: ('안전 교육 랜딩', '신청'),
      },
    ),
    ConceptSeed(
      id: 'local_specialty',
      category: ConceptCategory.rural,
      tags: const ['특산품', '브랜딩', '지역'],
      audienceWeights: _w({'rural': 5, 'returning_farm': 4, 'smb': 3}),
      baseScores: _scores(business: 4.5, diff: 4.5, practical: 4),
      variants: {
        ArtifactType.ebook: ('지역 특산품 브랜딩', '스토리·패키지'),
        ArtifactType.app: ('재고·주문 메모 앱', '시즌 상품'),
        ArtifactType.contents: ('특산품 스토리 영상', '산지 이야기'),
        ArtifactType.site: ('특산품 소개관', '생산자 소개'),
        ArtifactType.promoSite: ('특산품 홍보 랜딩', '구매·문의'),
      },
    ),
    ConceptSeed(
      id: 'tour_experience',
      category: ConceptCategory.rural,
      tags: const ['체험', '관광', '농촌'],
      audienceWeights: _w({'rural': 5, 'returning_farm': 4, 'smb': 3}),
      baseScores: _scores(business: 4.2, practical: 3.5, diff: 4),
      variants: {
        ArtifactType.ebook: ('농촌체험 프로그램 기획', '안전·일정'),
        ArtifactType.app: ('체험 예약 관리', '인원·날씨'),
        ArtifactType.contents: ('체험 하이라이트 영상', '감성+정보'),
        ArtifactType.site: ('체험 안내 사이트', '코스·요금'),
        ArtifactType.promoSite: ('농촌체험 홍보 랜딩', '예약 CTA'),
      },
    ),
    ConceptSeed(
      id: 'office_burnout',
      category: ConceptCategory.health,
      tags: const ['번아웃', '회복', '직장'],
      audienceWeights: _w({'office': 5, 'age_40_60': 3, 'student': 2}),
      baseScores: _scores(need: 4.5, longevity: 4, beginner: 4),
      variants: {
        ArtifactType.ebook: ('직장인 번아웃 회복 노트', '경계·휴식'),
        ArtifactType.app: ('회복 루틴 앱', '마이크로 휴식'),
        ArtifactType.contents: ('번아웃 공감 콘텐츠', '과한 처방 없이'),
        ArtifactType.site: ('직장 웰빙 허브', '자료'),
        ArtifactType.promoSite: ('웰빙 프로그램 랜딩', '신청'),
      },
    ),
    ConceptSeed(
      id: 'interview_ai',
      category: ConceptCategory.education,
      tags: const ['면접', 'AI', '취업'],
      audienceWeights: _w({'student': 5, 'office': 3}),
      baseScores: _scores(ai: 4.5, practical: 4.5, need: 4),
      variants: {
        ArtifactType.ebook: ('AI 면접 연습법', '질문·피드백'),
        ArtifactType.app: ('모의면접 앱', '타이머·메모'),
        ArtifactType.contents: ('면접 팁 쇼츠', '짧은 예시'),
        ArtifactType.site: ('취업 준비관', '로드맵'),
        ArtifactType.promoSite: ('취업 코스 랜딩', '등록'),
      },
    ),
    ConceptSeed(
      id: 'english_work',
      category: ConceptCategory.education,
      tags: const ['영어', '업무', '학습'],
      audienceWeights: _w({'office': 4, 'student': 4, 'general': 2}),
      baseScores: _scores(practical: 4, ai: 4, beginner: 3.5),
      variants: {
        ArtifactType.ebook: ('업무 영어 최소 세트', '메일·미팅'),
        ArtifactType.app: ('문장 연습 앱', '스페이스드'),
        ArtifactType.contents: ('업무 영어 쇼츠', '상황별'),
        ArtifactType.site: ('업무 영어 허브', '템플릿'),
        ArtifactType.promoSite: ('영어 코스 랜딩', '수강'),
      },
    ),
    ConceptSeed(
      id: 'inventory_simple',
      category: ConceptCategory.business,
      tags: const ['재고', '운영'],
      audienceWeights: _w({'smb': 5, 'rural': 3}),
      baseScores: _scores(practical: 5, need: 4, beginner: 4),
      variants: {
        ArtifactType.ebook: ('작은 가게 재고 관리', '표로 충분'),
        ArtifactType.app: ('간단 재고 앱', '입출고'),
        ArtifactType.contents: ('재고 실수 사례', '예방'),
        ArtifactType.site: ('운영 기초관', '체크'),
        ArtifactType.promoSite: ('재고 도구 랜딩', '체험'),
      },
    ),
    ConceptSeed(
      id: 'price_test',
      category: ConceptCategory.money,
      tags: const ['가격', '실험', '검증'],
      audienceWeights: _w({
        'smb': 4,
        'office': 3,
        'retire_prep': 3,
        'general': 3,
      }),
      baseScores: _scores(business: 4.5, practical: 4, beginner: 3.5),
      variants: {
        ArtifactType.ebook: ('가격 실험 가이드', '저가 검증→조정'),
        ArtifactType.app: ('가격 A/B 메모 앱', '반응 기록'),
        ArtifactType.contents: ('가격 이야기 콘텐츠', '투명성'),
        ArtifactType.site: ('가격 전략 기초', '사례'),
        ArtifactType.promoSite: ('상품 가격 테스트 랜딩', '구매'),
      },
    ),
    ConceptSeed(
      id: 'faq_knowledge',
      category: ConceptCategory.education,
      tags: const ['FAQ', '지식', '검색'],
      audienceWeights: _w({
        'smb': 3,
        'office': 3,
        'general': 3,
        'rural': 3,
        'student': 3,
      }),
      baseScores: _scores(practical: 4.5, longevity: 4.5, beginner: 4),
      variants: {
        ArtifactType.ebook: ('FAQ로 만드는 지식 상품', '질문 수집'),
        ArtifactType.app: ('FAQ 관리 앱', '태그'),
        ArtifactType.contents: ('FAQ 숏폼', '한 질문 한 답'),
        ArtifactType.site: ('FAQ 지식사이트', '검색'),
        ArtifactType.promoSite: ('FAQ 기반 제품 랜딩', '신뢰'),
      },
    ),
    ConceptSeed(
      id: 'before_after',
      category: ConceptCategory.marketing,
      tags: const ['비포애프터', '설득'],
      audienceWeights: _w({'smb': 4, 'general': 3, 'office': 2}),
      baseScores: _scores(business: 4.5, practical: 4, beginner: 4),
      variants: {
        ArtifactType.ebook: ('비포·애프터 스토리텔링', '과장 없이'),
        ArtifactType.app: ('사례 카드 앱', '증거 메모'),
        ArtifactType.contents: ('비포애프터 쇼츠', '시각 대비'),
        ArtifactType.site: ('사례 갤러리', '필터'),
        ArtifactType.promoSite: ('성과 사례 랜딩', '전환'),
      },
    ),
    ConceptSeed(
      id: 'weekly_ops',
      category: ConceptCategory.productivity,
      tags: const ['주간', '루틴', '운영'],
      audienceWeights: _w({
        'smb': 4,
        'office': 4,
        'retire_prep': 3,
        'rural': 3,
      }),
      baseScores: _scores(practical: 5, beginner: 4.5, longevity: 4),
      variants: {
        ArtifactType.ebook: ('주간 운영 루틴 설계', '반복 가능한 일'),
        ArtifactType.app: ('주간 운영 보드', '할 일'),
        ArtifactType.contents: ('루틴 브이로그', '현실'),
        ArtifactType.site: ('운영 루틴 허브', '템플릿'),
        ArtifactType.promoSite: ('운영 코스 랜딩', '등록'),
      },
    ),
    ConceptSeed(
      id: 'voice_guide',
      category: ConceptCategory.content,
      tags: const ['음성', '가이드', '접근성'],
      audienceWeights: _w({
        'age_60_80': 4,
        'age_40_60': 3,
        'general': 3,
        'rural': 3,
      }),
      baseScores: _scores(beginner: 4.5, practical: 4, diff: 3.5),
      subtypes: const [
        ContentSubtype.other,
        ContentSubtype.video,
        ContentSubtype.song,
      ],
      variants: {
        ArtifactType.ebook: ('음성 가이드 콘텐츠 기획', '대본·속도'),
        ArtifactType.app: ('음성 스크립트 앱', '구간 메모'),
        ArtifactType.contents: ('음성 가이드/내레이션', '차분한 톤'),
        ArtifactType.site: ('오디오 아카이브', '재생'),
        ArtifactType.promoSite: ('오디오 상품 랜딩', '듣기'),
      },
    ),
    ConceptSeed(
      id: 'subtitle_access',
      category: ConceptCategory.content,
      tags: const ['자막', '접근성'],
      audienceWeights: _w({
        'general': 3,
        'age_60_80': 4,
        'smb': 3,
        'student': 2,
      }),
      baseScores: _scores(practical: 4.5, beginner: 4, need: 3.5),
      subtypes: const [
        ContentSubtype.shorts,
        ContentSubtype.video,
        ContentSubtype.songAndShorts,
      ],
      variants: {
        ArtifactType.ebook: ('자막·접근성 제작 가이드', '가독성'),
        ArtifactType.app: ('자막 검수 체크 앱', '오탈자'),
        ArtifactType.contents: ('자막 포함 콘텐츠 제작', '기본 포함'),
        ArtifactType.site: ('접근성 가이드관', '체크'),
        ArtifactType.promoSite: ('제작 서비스 랜딩', '문의'),
      },
    ),
    ConceptSeed(
      id: 'seasonal_farm',
      category: ConceptCategory.rural,
      tags: const ['시즌', '작기', '계획'],
      audienceWeights: _w({'rural': 5, 'returning_farm': 4}),
      baseScores: _scores(practical: 5, longevity: 4.5, need: 4),
      variants: {
        ArtifactType.ebook: ('작기·시즌 계획 노트', '월별 할 일'),
        ArtifactType.app: ('시즌 캘린더 앱', '알림'),
        ArtifactType.contents: ('시즌 현장 영상', '달력형'),
        ArtifactType.site: ('시즌 가이드관', '월별'),
        ArtifactType.promoSite: ('시즌 상품 랜딩', '한정'),
      },
    ),
    ConceptSeed(
      id: 'mentor_match',
      category: ConceptCategory.relationship,
      tags: const ['멘토', '연결', '성장'],
      audienceWeights: _w({
        'student': 4,
        'office': 3,
        'retire_prep': 4,
        'age_40_60': 4,
      }),
      baseScores: _scores(longevity: 4, need: 3.5, business: 3.5),
      variants: {
        ArtifactType.ebook: ('멘토링 관계 시작 가이드', '기대·경계'),
        ArtifactType.app: ('멘토링 세션 메모', '질문 리스트'),
        ArtifactType.contents: ('멘토링 스토리', '인터뷰형'),
        ArtifactType.site: ('멘토·자료 허브', '매칭 안내'),
        ArtifactType.promoSite: ('멘토링 프로그램 랜딩', '신청'),
      },
    ),
    ConceptSeed(
      id: 'micro_saas_idea',
      category: ConceptCategory.tech,
      tags: const ['앱', '마이크로', '도구'],
      audienceWeights: _w({'office': 4, 'smb': 3, 'student': 3, 'general': 2}),
      baseScores: _scores(ai: 4, business: 4, diff: 4, beginner: 2.5),
      variants: {
        ArtifactType.ebook: ('작은 도구형 앱 기획', '범위 고정'),
        ArtifactType.app: ('마이크로 유틸 앱 MVP', '한 기능'),
        ArtifactType.contents: ('앱 데모 쇼츠', '30초'),
        ArtifactType.site: ('제품 문서 사이트', '사용법'),
        ArtifactType.promoSite: ('앱 출시 랜딩', '설치'),
      },
    ),
    ConceptSeed(
      id: 'habit_stack',
      category: ConceptCategory.life,
      tags: const ['습관', '스택', '루틴'],
      audienceWeights: _w({
        'general': 4,
        'office': 4,
        'student': 4,
        'retire_prep': 3,
      }),
      baseScores: _scores(practical: 4.5, beginner: 4.5, longevity: 4.5),
      variants: {
        ArtifactType.ebook: ('습관 스택 설계', '작은 행동 연결'),
        ArtifactType.app: ('습관 스택 앱', '연쇄 체크'),
        ArtifactType.contents: ('습관 챌린지', '7일'),
        ArtifactType.site: ('습관 라이브러리', '예시'),
        ArtifactType.promoSite: ('챌린지 랜딩', '참가'),
      },
    ),
    ConceptSeed(
      id: 'local_map_guide',
      category: ConceptCategory.life,
      tags: const ['지도', '로컬', '안내'],
      audienceWeights: _w({
        'rural': 4,
        'smb': 3,
        'general': 3,
        'returning_farm': 3,
      }),
      baseScores: _scores(practical: 4, business: 3.5, beginner: 4),
      variants: {
        ArtifactType.ebook: ('우리 동네 안내 가이드', '장소·팁'),
        ArtifactType.app: ('로컬 스팟 메모 앱', '핀·메모'),
        ArtifactType.contents: ('동네 투어 영상', '걷기'),
        ArtifactType.site: ('로컬 가이드 사이트', '지도'),
        ArtifactType.promoSite: ('투어/가게 랜딩', '예약'),
      },
    ),
  ];

  /// Audience category boost profiles for intersection scoring.
  static const audienceCategoryBoost = <String, Map<String, double>>{
    'general': {
      ConceptCategory.ai: 1.1,
      ConceptCategory.life: 1.2,
      ConceptCategory.money: 1.1,
    },
    'student': {
      ConceptCategory.education: 1.4,
      ConceptCategory.ai: 1.2,
      ConceptCategory.money: 1.1,
    },
    'office': {
      ConceptCategory.productivity: 1.4,
      ConceptCategory.ai: 1.3,
      ConceptCategory.health: 1.1,
    },
    'smb': {
      ConceptCategory.business: 1.4,
      ConceptCategory.marketing: 1.4,
      ConceptCategory.money: 1.2,
    },
    'returning_farm': {
      ConceptCategory.rural: 1.5,
      ConceptCategory.money: 1.2,
      ConceptCategory.ai: 1.1,
    },
    'rural': {
      ConceptCategory.rural: 1.5,
      ConceptCategory.tech: 1.2,
      ConceptCategory.money: 1.2,
    },
    'retire_prep': {
      ConceptCategory.retirement: 1.5,
      ConceptCategory.ai: 1.3,
      ConceptCategory.money: 1.3,
      ConceptCategory.health: 1.2,
    },
    'age_40_60': {
      ConceptCategory.retirement: 1.2,
      ConceptCategory.ai: 1.2,
      ConceptCategory.money: 1.2,
      ConceptCategory.health: 1.2,
    },
    'age_60_80': {
      ConceptCategory.health: 1.3,
      ConceptCategory.ai: 1.1,
      ConceptCategory.life: 1.2,
      ConceptCategory.education: 1.1,
    },
  };
}
