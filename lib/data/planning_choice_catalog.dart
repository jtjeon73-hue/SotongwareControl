/// 선택형 기획 도우미 선택지 카탈로그 (순수 Dart, UI 없음).
library;

import '../models/planning_wizard_state.dart';

class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.label,
    this.hint,
    this.recommended = false,
    this.forDeliverables = const {},
    this.forDomains = const {},
    this.forAudiences = const {},
  });

  final String id;
  final String label;
  final String? hint;

  /// UI 「추천」 배지용 기본값 (동적 추천과 별도).
  final bool recommended;

  /// 비어 있으면 모든 결과물에 표시.
  final Set<String> forDeliverables;
  final Set<String> forDomains;
  final Set<String> forAudiences;

  bool matchesContext({
    String? deliverable,
    Set<String> domains = const {},
    Set<String> audiences = const {},
  }) {
    if (forDeliverables.isNotEmpty &&
        deliverable != null &&
        !forDeliverables.contains(deliverable)) {
      return false;
    }
    if (forDomains.isNotEmpty &&
        domains.isNotEmpty &&
        !domains.any(forDomains.contains)) {
      return false;
    }
    if (forAudiences.isNotEmpty &&
        audiences.isNotEmpty &&
        !audiences.any(forAudiences.contains)) {
      return false;
    }
    return true;
  }
}

class PlanningSample {
  const PlanningSample({
    required this.id,
    required this.title,
    required this.description,
    required this.seed,
  });

  final String id;
  final String title;
  final String description;

  /// 원본 시드 — UI에서 deepCopy() 후 사용.
  final PlanningWizardState seed;
}

/// 선택 단계 id 상수.
abstract final class PlanningChoiceSteps {
  static const deliverables = 'deliverables';
  static const domains = 'domains';
  static const audiences = 'audiences';
  static const problems = 'problems';
  static const outcomes = 'outcomes';
  static const formats = 'formats';
  static const scales = 'scales';
  static const durations = 'durations';
  static const budgets = 'budgets';
  static const salesModes = 'salesModes';
}

/// 결과물 id (DeliverableType과 호환).
abstract final class PlanningDeliverables {
  static const ebook = 'ebook';
  static const app = 'app';
  static const youtubeShorts = 'youtube_shorts';
  static const youtubeVideo = 'youtube_video';
  static const webMarketing = 'web_marketing';
  static const educationContent = 'education_content';
  static const musicContent = 'music_content';
  static const industrialAutomation = 'industrial_automation';
  static const undecided = 'undecided';
  static const custom = 'custom';
}

/// 대상 고객 최대 권장 선택 수.
const int maxRecommendedAudienceCount = 3;

// ---------------------------------------------------------------------------
// 정적 선택지
// ---------------------------------------------------------------------------

const _deliverableOptions = <ChoiceOption>[
  ChoiceOption(id: PlanningDeliverables.ebook, label: '전자책'),
  ChoiceOption(id: PlanningDeliverables.app, label: '모바일 앱'),
  ChoiceOption(id: PlanningDeliverables.youtubeShorts, label: '유튜브 쇼츠'),
  ChoiceOption(id: PlanningDeliverables.youtubeVideo, label: '유튜브 일반 영상'),
  ChoiceOption(id: PlanningDeliverables.webMarketing, label: '홍보·마케팅 사이트'),
  ChoiceOption(id: PlanningDeliverables.educationContent, label: '교육 콘텐츠'),
  ChoiceOption(id: PlanningDeliverables.musicContent, label: '음악·노래 콘텐츠'),
  ChoiceOption(
    id: PlanningDeliverables.industrialAutomation,
    label: '산업자동화 소프트웨어',
  ),
  ChoiceOption(id: PlanningDeliverables.undecided, label: '아직 결정하지 못함'),
  ChoiceOption(id: PlanningDeliverables.custom, label: '직접 입력'),
];

const _domainOptions = <ChoiceOption>[
  ChoiceOption(id: 'rural_life', label: '농촌생활'),
  ChoiceOption(id: 'return_farm', label: '귀농·귀촌'),
  ChoiceOption(id: 'online_income', label: '온라인 수익'),
  ChoiceOption(id: 'retirement', label: '노후 준비'),
  ChoiceOption(id: 'health', label: '건강관리'),
  ChoiceOption(id: 'industrial_auto', label: '산업자동화'),
  ChoiceOption(id: 'plc', label: 'PLC'),
  ChoiceOption(id: 'electric', label: '전기'),
  ChoiceOption(id: 'software', label: '소프트웨어 개발'),
  ChoiceOption(id: 'app_dev', label: '앱 개발'),
  ChoiceOption(id: 'ai', label: 'AI 활용'),
  ChoiceOption(id: 'smart_farm', label: '농업·스마트팜'),
  ChoiceOption(id: 'local_tourism', label: '지역 관광'),
  ChoiceOption(id: 'life_info', label: '생활 정보'),
  ChoiceOption(id: 'hobby_music', label: '취미·음악'),
  ChoiceOption(id: 'custom', label: '직접 입력'),
];

const _audienceOptions = <ChoiceOption>[
  ChoiceOption(id: 'rural_resident', label: '농촌·시골 거주자'),
  ChoiceOption(id: 'return_prep', label: '귀농·귀촌 준비자'),
  ChoiceOption(id: 'retirement_prep', label: '은퇴 준비자'),
  ChoiceOption(id: 'sidejob_40_60', label: '40~60대 부업 희망자'),
  ChoiceOption(id: 'small_business', label: '소상공인'),
  ChoiceOption(id: 'farmer', label: '농민'),
  ChoiceOption(id: 'office_worker', label: '직장인'),
  ChoiceOption(id: 'beginner_dev', label: '초보 개발자'),
  ChoiceOption(id: 'industrial_tech', label: '산업자동화 기술자'),
  ChoiceOption(id: 'plc_beginner', label: 'PLC 입문자'),
  ChoiceOption(id: 'local_resident', label: '지역 주민'),
  ChoiceOption(id: 'tourist', label: '관광객'),
  ChoiceOption(id: 'consumer', label: '일반 소비자'),
  ChoiceOption(id: 'enterprise', label: '기업 담당자'),
  ChoiceOption(id: 'age_custom', label: '연령대를 직접 선택'),
  ChoiceOption(id: 'custom', label: '직접 입력'),
];

const _commonProblemOptions = <ChoiceOption>[
  ChoiceOption(id: 'start_unknown', label: '무엇부터 시작해야 할지 모른다'),
  ChoiceOption(id: 'productize_unknown', label: '경험과 기술을 상품으로 만드는 방법을 모른다'),
  ChoiceOption(id: 'sales_channel_unknown', label: '판매할 곳을 모른다'),
  ChoiceOption(id: 'promo_unknown', label: '홍보 방법을 모른다'),
  ChoiceOption(id: 'easy_learn', label: '어려운 정보를 쉽게 배우고 싶다'),
  ChoiceOption(id: 'cost_burden', label: '비용이 부담된다'),
  ChoiceOption(id: 'time_short', label: '시간이 부족하다'),
  ChoiceOption(id: 'repetitive', label: '반복 작업이 많다'),
  ChoiceOption(id: 'complex_manage', label: '관리가 복잡하다'),
  ChoiceOption(id: 'trust_info', label: '신뢰할 수 있는 정보가 부족하다'),
  ChoiceOption(id: 'step_guide', label: '단계별 실행 방법이 필요하다'),
  ChoiceOption(id: 'custom', label: '직접 입력'),
];

const _ebookProblemOptions = <ChoiceOption>[
  ChoiceOption(
    id: 'ebook_topic_unknown',
    label: '자신의 경험을 전자책 주제로 정하지 못한다',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'outline_unknown',
    label: '목차와 원고 구성 방법을 모른다',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'tool_unknown',
    label: '전자책 제작 도구를 모른다',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'register_unknown',
    label: '판매처 등록 방법을 모른다',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'promo_revenue_unknown',
    label: '홍보와 수익 연결 방법을 모른다',
    forDeliverables: {PlanningDeliverables.ebook},
    forDomains: {'online_income'},
  ),
];

const _industrialProblemOptions = <ChoiceOption>[
  ChoiceOption(
    id: 'data_monitor_hard',
    label: '설비 데이터를 한눈에 확인하기 어렵다',
    forDeliverables: {PlanningDeliverables.industrialAutomation},
  ),
  ChoiceOption(
    id: 'plc_pc_hard',
    label: 'PLC와 PC 프로그램 연동이 어렵다',
    forDeliverables: {PlanningDeliverables.industrialAutomation},
  ),
  ChoiceOption(
    id: 'manual_error',
    label: '수작업 기록 때문에 오류가 발생한다',
    forDeliverables: {PlanningDeliverables.industrialAutomation},
  ),
  ChoiceOption(
    id: 'fault_trace_hard',
    label: '고장 원인과 이력을 추적하기 어렵다',
    forDeliverables: {PlanningDeliverables.industrialAutomation},
  ),
];

const _outcomeOptions = <ChoiceOption>[
  ChoiceOption(id: 'follow_through', label: '처음부터 끝까지 따라 할 수 있다'),
  ChoiceOption(id: 'sellable', label: '실제 판매 가능한 결과물을 완성한다'),
  ChoiceOption(id: 'save_time', label: '시간을 절약한다'),
  ChoiceOption(id: 'cut_cost', label: '비용을 줄인다'),
  ChoiceOption(id: 'automate', label: '반복 작업을 자동화한다'),
  ChoiceOption(id: 'start_income', label: '온라인 수익을 시작한다'),
  ChoiceOption(id: 'monthly_plan', label: '월수익 목표를 향한 실행계획을 만든다'),
  ChoiceOption(id: 'learn_sys', label: '기술을 체계적으로 배운다'),
  ChoiceOption(id: 'get_customers', label: '고객을 확보한다'),
  ChoiceOption(id: 'dashboard', label: '업무 현황을 한눈에 관리한다'),
  ChoiceOption(id: 'custom', label: '직접 입력'),
];

const _ebookFormatOptions = <ChoiceOption>[
  ChoiceOption(
    id: 'pdf',
    label: 'PDF 전자책',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'epub',
    label: 'EPUB 전자책',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'both',
    label: 'PDF와 EPUB 모두',
    forDeliverables: {PlanningDeliverables.ebook},
    recommended: true,
  ),
  ChoiceOption(
    id: 'free',
    label: '무료 안내서',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'paid',
    label: '유료 실전 가이드',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'workbook',
    label: '워크북 포함',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'checklist',
    label: '체크리스트 포함',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'consult',
    label: '상담·교육 연계',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
];

const _youtubeFormatOptions = <ChoiceOption>[
  ChoiceOption(
    id: 'shorts30',
    label: '30초 쇼츠',
    forDeliverables: {
      PlanningDeliverables.youtubeShorts,
      PlanningDeliverables.youtubeVideo,
    },
  ),
  ChoiceOption(
    id: 'shorts60',
    label: '60초 쇼츠',
    forDeliverables: {
      PlanningDeliverables.youtubeShorts,
      PlanningDeliverables.youtubeVideo,
    },
    recommended: true,
  ),
  ChoiceOption(
    id: 'min5',
    label: '5분 설명 영상',
    forDeliverables: {PlanningDeliverables.youtubeVideo},
  ),
  ChoiceOption(
    id: 'min10',
    label: '10분 이상 교육 영상',
    forDeliverables: {PlanningDeliverables.youtubeVideo},
  ),
  ChoiceOption(
    id: 'series',
    label: '연재 콘텐츠',
    forDeliverables: {
      PlanningDeliverables.youtubeShorts,
      PlanningDeliverables.youtubeVideo,
    },
  ),
  ChoiceOption(
    id: 'promo',
    label: '전자책 홍보 영상',
    forDeliverables: {
      PlanningDeliverables.youtubeShorts,
      PlanningDeliverables.youtubeVideo,
    },
    forDomains: {'online_income'},
  ),
];

const _appFormatOptions = <ChoiceOption>[
  ChoiceOption(
    id: 'free_ad',
    label: '무료 광고형 앱',
    forDeliverables: {PlanningDeliverables.app},
  ),
  ChoiceOption(
    id: 'paid',
    label: '유료 앱',
    forDeliverables: {PlanningDeliverables.app},
  ),
  ChoiceOption(
    id: 'freemium',
    label: '기본 무료·고급 유료',
    forDeliverables: {PlanningDeliverables.app},
    recommended: true,
  ),
  ChoiceOption(
    id: 'b2b',
    label: '업체 납품형',
    forDeliverables: {PlanningDeliverables.app},
  ),
  ChoiceOption(
    id: 'subscribe',
    label: '회원 구독형',
    forDeliverables: {PlanningDeliverables.app},
  ),
  ChoiceOption(
    id: 'internal',
    label: '내부 업무용',
    forDeliverables: {PlanningDeliverables.app},
  ),
];

const _scaleOptions = <ChoiceOption>[
  ChoiceOption(
    id: 'simple_20_30',
    label: '간단형: 약 20~30쪽',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'basic_40_60',
    label: '기본형: 약 40~60쪽',
    hint: '가장 많이 선택하는 규모',
    recommended: true,
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'practical_70_100',
    label: '실전형: 약 70~100쪽',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'deep_100plus',
    label: '심화형: 100쪽 이상',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(
    id: 'undecided',
    label: '아직 결정하지 않음',
    forDeliverables: {PlanningDeliverables.ebook},
  ),
];

const _durationOptions = <ChoiceOption>[
  ChoiceOption(id: 'week1', label: '빠르게 1주'),
  ChoiceOption(
    id: 'week2',
    label: '기본 2주',
    hint: '검증과 품질의 균형',
    recommended: true,
  ),
  ChoiceOption(id: 'month1', label: '충분하게 1개월'),
  ChoiceOption(id: 'undecided', label: '일정 미정'),
];

const _budgetOptions = <ChoiceOption>[
  ChoiceOption(id: 'free_tools', label: '무료 도구 중심'),
  ChoiceOption(id: 'minimal', label: '최소 비용'),
  ChoiceOption(id: 'quality_first', label: '품질 우선'),
  ChoiceOption(id: 'undecided', label: '예산 미정'),
];

const _salesModeOptions = <ChoiceOption>[
  ChoiceOption(id: 'free_acquire', label: '무료 배포로 고객 확보'),
  ChoiceOption(
    id: 'cheap_validate',
    label: '저가 판매로 초기 검증',
    recommended: true,
    forDeliverables: {PlanningDeliverables.ebook},
  ),
  ChoiceOption(id: 'normal_paid', label: '일반 유료 판매'),
  ChoiceOption(id: 'premium', label: '고급 상품으로 판매'),
  ChoiceOption(id: 'with_consult', label: '상담·교육과 연결'),
  ChoiceOption(id: 'bundle', label: '앱·영상·사이트와 함께 판매'),
  ChoiceOption(id: 'undecided', label: '아직 결정하지 않음'),
];

// ---------------------------------------------------------------------------
// 공개 API
// ---------------------------------------------------------------------------

/// id → 한글 라벨 (문장 조립용).
String labelForChoice(String step, String id) {
  final option = findOption(step, id);
  if (option != null) return option.label;
  return id;
}

ChoiceOption? findOption(String step, String id) {
  for (final o in _allOptionsForStep(step)) {
    if (o.id == id) return o;
  }
  return null;
}

List<ChoiceOption> _allOptionsForStep(String step) {
  switch (step) {
    case PlanningChoiceSteps.deliverables:
      return _deliverableOptions;
    case PlanningChoiceSteps.domains:
      return _domainOptions;
    case PlanningChoiceSteps.audiences:
      return _audienceOptions;
    case PlanningChoiceSteps.problems:
      return [
        ..._commonProblemOptions,
        ..._ebookProblemOptions,
        ..._industrialProblemOptions,
      ];
    case PlanningChoiceSteps.outcomes:
      return _outcomeOptions;
    case PlanningChoiceSteps.formats:
      return [
        ..._ebookFormatOptions,
        ..._youtubeFormatOptions,
        ..._appFormatOptions,
      ];
    case PlanningChoiceSteps.scales:
      return _scaleOptions;
    case PlanningChoiceSteps.durations:
      return _durationOptions;
    case PlanningChoiceSteps.budgets:
      return _budgetOptions;
    case PlanningChoiceSteps.salesModes:
      return _salesModeOptions;
    default:
      return const [];
  }
}

/// 컨텍스트에 맞는 선택지 목록. [recommendedIds]와 병합해 `recommended` 플래그를 갱신한다.
List<ChoiceOption> optionsFor(
  String step, {
  String? deliverable,
  Set<String> domains = const {},
  Set<String> audiences = const {},
  Set<String> recommendedIds = const {},
}) {
  final base = _allOptionsForStep(step);
  final filtered = base
      .where(
        (o) => o.matchesContext(
          deliverable: deliverable,
          domains: domains,
          audiences: audiences,
        ),
      )
      .map(
        (o) => recommendedIds.contains(o.id)
            ? ChoiceOption(
                id: o.id,
                label: o.label,
                hint: o.hint,
                recommended: true,
                forDeliverables: o.forDeliverables,
                forDomains: o.forDomains,
                forAudiences: o.forAudiences,
              )
            : o,
      )
      .toList();

  if (step == PlanningChoiceSteps.formats && deliverable != null) {
    return filtered
        .where(
          (o) =>
              o.forDeliverables.isEmpty ||
              o.forDeliverables.contains(deliverable),
        )
        .toList();
  }

  if (step == PlanningChoiceSteps.scales &&
      deliverable != null &&
      deliverable != PlanningDeliverables.ebook) {
    return const [];
  }

  return filtered;
}

// ---------------------------------------------------------------------------
// 추천 규칙
// ---------------------------------------------------------------------------

/// 고객 문제 추천 id (우선순위 순).
List<String> suggestProblems({
  String? deliverable,
  Set<String> domains = const {},
  Set<String> audiences = const {},
}) {
  final ids = <String>[];

  void add(String id) {
    if (!ids.contains(id)) ids.add(id);
  }

  if (deliverable == PlanningDeliverables.ebook) {
    if (domains.contains('online_income') ||
        domains.contains('rural_life') ||
        domains.contains('return_farm')) {
      add('productize_unknown');
    }
    if (domains.contains('online_income')) {
      add('promo_revenue_unknown');
      add('sales_channel_unknown');
    }
    if (audiences.contains('return_prep') ||
        audiences.contains('sidejob_40_60')) {
      add('ebook_topic_unknown');
    }
    add('outline_unknown');
  }

  if (deliverable == PlanningDeliverables.industrialAutomation ||
      domains.contains('industrial_auto') ||
      domains.contains('plc')) {
    add('data_monitor_hard');
    add('plc_pc_hard');
    add('manual_error');
  }

  if (deliverable == PlanningDeliverables.webMarketing) {
    add('promo_unknown');
    add('get_customers');
  }

  if (deliverable == PlanningDeliverables.youtubeShorts ||
      deliverable == PlanningDeliverables.youtubeVideo) {
    add('promo_unknown');
    add('start_unknown');
  }

  if (deliverable == PlanningDeliverables.app) {
    add('productize_unknown');
    add('start_unknown');
  }

  if (domains.contains('ai') && domains.contains('online_income')) {
    add('productize_unknown');
    add('start_unknown');
  }

  add('start_unknown');
  add('step_guide');

  return ids;
}

List<String> suggestOutcomes({
  String? deliverable,
  Set<String> domains = const {},
}) {
  final ids = <String>[];

  void add(String id) {
    if (!ids.contains(id)) ids.add(id);
  }

  if (deliverable == PlanningDeliverables.ebook) {
    add('sellable');
    if (domains.contains('online_income')) add('start_income');
  }

  if (deliverable == PlanningDeliverables.industrialAutomation) {
    add('dashboard');
    add('automate');
    add('save_time');
  }

  if (deliverable == PlanningDeliverables.webMarketing) {
    add('get_customers');
  }

  if (deliverable == PlanningDeliverables.youtubeShorts ||
      deliverable == PlanningDeliverables.youtubeVideo) {
    add('get_customers');
    add('follow_through');
  }

  if (deliverable == PlanningDeliverables.app) {
    add('follow_through');
    add('save_time');
  }

  add('follow_through');
  return ids;
}

String? suggestScale({String? deliverable, Set<String> domains = const {}}) {
  if (deliverable != PlanningDeliverables.ebook) return null;
  if (domains.contains('plc') || domains.contains('industrial_auto')) {
    return 'practical_70_100';
  }
  return 'basic_40_60';
}

String? suggestDuration() => 'week2';

String? suggestBudget({Set<String> domains = const {}}) {
  if (domains.contains('industrial_auto')) return 'quality_first';
  return 'free_tools';
}

String? suggestSalesMode({
  String? deliverable,
  Set<String> domains = const {},
}) {
  if (deliverable == PlanningDeliverables.ebook) {
    if (domains.contains('online_income') ||
        domains.contains('rural_life') ||
        domains.contains('return_farm')) {
      return 'cheap_validate';
    }
    return 'cheap_validate';
  }
  if (deliverable == PlanningDeliverables.industrialAutomation) {
    return 'normal_paid';
  }
  if (deliverable == PlanningDeliverables.webMarketing) {
    return 'free_acquire';
  }
  if (deliverable == PlanningDeliverables.app) {
    return 'free_acquire';
  }
  return 'undecided';
}

List<String> suggestFormats({
  String? deliverable,
  Set<String> domains = const {},
}) {
  switch (deliverable) {
    case PlanningDeliverables.ebook:
      return ['both', 'paid'];
    case PlanningDeliverables.youtubeShorts:
      return ['shorts60'];
    case PlanningDeliverables.youtubeVideo:
      return ['min5'];
    case PlanningDeliverables.app:
      return ['freemium'];
    case PlanningDeliverables.webMarketing:
      return [];
    default:
      return [];
  }
}

List<String> suggestAudiences({Set<String> domains = const {}}) {
  final ids = <String>[];
  if (domains.contains('rural_life') || domains.contains('return_farm')) {
    ids.addAll(['return_prep', 'rural_resident']);
  }
  if (domains.contains('online_income')) {
    ids.add('sidejob_40_60');
  }
  if (domains.contains('plc')) {
    ids.add('plc_beginner');
  }
  if (domains.contains('industrial_auto')) {
    ids.add('industrial_tech');
  }
  if (domains.contains('local_tourism')) {
    ids.addAll(['local_resident', 'small_business']);
  }
  if (domains.contains('retirement')) {
    ids.add('retirement_prep');
  }
  if (domains.contains('ai')) {
    ids.add('office_worker');
  }
  return ids.take(maxRecommendedAudienceCount).toList();
}

/// 후속 결과물 추천 (주 결과물 외).
List<String> suggestFollowUpDeliverables({
  String? deliverable,
  Set<String> domains = const {},
}) {
  if (deliverable == PlanningDeliverables.ebook &&
      (domains.contains('rural_life') ||
          domains.contains('online_income') ||
          domains.contains('return_farm'))) {
    return [
      PlanningDeliverables.youtubeShorts,
      PlanningDeliverables.webMarketing,
    ];
  }
  if (deliverable == PlanningDeliverables.app) {
    return [PlanningDeliverables.webMarketing];
  }
  if (deliverable == PlanningDeliverables.industrialAutomation) {
    return [PlanningDeliverables.webMarketing];
  }
  return const [];
}

/// 한 줄 추천 이유.
String? recommendationReason({
  required String step,
  required String optionId,
  String? deliverable,
  Set<String> domains = const {},
}) {
  if (step == PlanningChoiceSteps.problems &&
      optionId == 'productize_unknown' &&
      deliverable == PlanningDeliverables.ebook &&
      domains.contains('online_income')) {
    return '온라인 수익 분야에서는 경험 상품화가 가장 흔한 출발점입니다.';
  }
  if (step == PlanningChoiceSteps.scales && optionId == 'basic_40_60') {
    return '검증과 완성도의 균형이 좋은 규모입니다.';
  }
  if (step == PlanningChoiceSteps.salesModes &&
      optionId == 'cheap_validate' &&
      deliverable == PlanningDeliverables.ebook) {
    return '전자책은 저가로 먼저 시장 반응을 확인하는 방식이 안전합니다.';
  }
  if (step == PlanningChoiceSteps.durations && optionId == 'week2') {
    return '2주면 최소 완성본을 만들기에 현실적인 기간입니다.';
  }
  return null;
}

/// `PlanningWizardState`에 추천값을 채운 새 상태 (문장은 composer에서).
PlanningWizardState applyRecommendations(PlanningWizardState state) {
  final deliverable = state.deliverable;
  final domains = state.domains.toSet();
  final audiences = state.audiences.toSet();

  final problems = state.problems.isEmpty
      ? suggestProblems(
          deliverable: deliverable,
          domains: domains,
          audiences: audiences,
        ).take(2).toList()
      : state.problems;

  final suggestedAudiences = state.audiences.isEmpty
      ? suggestAudiences(domains: domains)
      : state.audiences;

  final outcomes = state.outcomes.isEmpty
      ? suggestOutcomes(
          deliverable: deliverable,
          domains: domains,
        ).take(2).toList()
      : state.outcomes;

  final formats = state.formats.isEmpty
      ? suggestFormats(deliverable: deliverable, domains: domains)
      : state.formats;

  return state.copyWith(
    audiences: suggestedAudiences,
    problems: problems,
    outcomes: outcomes,
    formats: formats,
    scale:
        state.scale ?? suggestScale(deliverable: deliverable, domains: domains),
    duration: state.duration ?? suggestDuration(),
    budget: state.budget ?? suggestBudget(domains: domains),
    salesMode:
        state.salesMode ??
        suggestSalesMode(deliverable: deliverable, domains: domains),
    followUpDeliverables: state.followUpDeliverables.isEmpty
        ? suggestFollowUpDeliverables(
            deliverable: deliverable,
            domains: domains,
          )
        : state.followUpDeliverables,
  );
}

// ---------------------------------------------------------------------------
// 샘플 기획 (8종)
// ---------------------------------------------------------------------------

PlanningWizardState _sampleSeed({
  required String deliverable,
  required List<String> domains,
  required List<String> audiences,
  required List<String> problems,
  required List<String> outcomes,
  List<String> formats = const [],
  String? scale,
  String? duration,
  String? budget,
  String? salesMode,
  List<String> followUpDeliverables = const [],
}) {
  return PlanningWizardState(
    mode: 'quick',
    step: 0,
    deliverable: deliverable,
    domains: domains,
    audiences: audiences,
    problems: problems,
    outcomes: outcomes,
    formats: formats,
    scale: scale,
    duration: duration ?? 'week2',
    budget: budget ?? 'free_tools',
    salesMode: salesMode,
    followUpDeliverables: followUpDeliverables,
  );
}

final List<PlanningSample> planningSamples = [
  PlanningSample(
    id: 'sample_rural_ebook',
    title: '시골 경험을 전자책으로 판매하기',
    description: '농촌생활·온라인 수익 경험을 전자책으로 만들어 첫 판매를 시작하는 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.ebook,
      domains: ['rural_life', 'online_income'],
      audiences: ['return_prep', 'sidejob_40_60'],
      problems: ['productize_unknown', 'sales_channel_unknown'],
      outcomes: ['sellable', 'start_income'],
      formats: ['both', 'paid'],
      scale: 'basic_40_60',
      salesMode: 'cheap_validate',
      followUpDeliverables: [
        PlanningDeliverables.youtubeShorts,
        PlanningDeliverables.webMarketing,
      ],
    ),
  ),
  PlanningSample(
    id: 'sample_return_farm_guide',
    title: '귀농·귀촌 초보자를 위한 실전 안내서',
    description: '귀농·귀촌 준비자에게 단계별 실행 방법을 안내하는 전자책 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.ebook,
      domains: ['return_farm', 'rural_life'],
      audiences: ['return_prep', 'retirement_prep'],
      problems: ['start_unknown', 'step_guide'],
      outcomes: ['follow_through', 'sellable'],
      formats: ['both', 'workbook'],
      scale: 'practical_70_100',
      salesMode: 'normal_paid',
      followUpDeliverables: [PlanningDeliverables.youtubeShorts],
    ),
  ),
  PlanningSample(
    id: 'sample_plc_ebook',
    title: 'PLC 입문 학습 전자책',
    description: 'PLC 입문자를 위한 체계적 학습 전자책 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.ebook,
      domains: ['plc', 'industrial_auto'],
      audiences: ['plc_beginner', 'industrial_tech'],
      problems: ['easy_learn', 'step_guide'],
      outcomes: ['learn_sys', 'follow_through'],
      formats: ['pdf', 'checklist'],
      scale: 'practical_70_100',
      salesMode: 'normal_paid',
    ),
  ),
  PlanningSample(
    id: 'sample_rural_shorts',
    title: '농촌생활 유튜브 쇼츠 만들기',
    description: '농촌생활 일상을 60초 쇼츠로 기록·홍보하는 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.youtubeShorts,
      domains: ['rural_life', 'life_info'],
      audiences: ['rural_resident', 'consumer'],
      problems: ['promo_unknown', 'start_unknown'],
      outcomes: ['get_customers', 'follow_through'],
      formats: ['shorts60'],
      salesMode: 'free_acquire',
    ),
  ),
  PlanningSample(
    id: 'sample_local_web',
    title: '지역 업체 홍보 사이트 만들기',
    description: '지역 소상공인을 위한 홍보·마케팅 웹사이트 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.webMarketing,
      domains: ['local_tourism', 'life_info'],
      audiences: ['small_business', 'local_resident'],
      problems: ['promo_unknown', 'sales_channel_unknown'],
      outcomes: ['get_customers'],
      salesMode: 'normal_paid',
      budget: 'minimal',
    ),
  ),
  PlanningSample(
    id: 'sample_life_app',
    title: '생활관리 모바일 앱 만들기',
    description: '일상·생활 정보를 관리하는 모바일 앱 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.app,
      domains: ['life_info', 'app_dev'],
      audiences: ['office_worker', 'consumer'],
      problems: ['complex_manage', 'time_short'],
      outcomes: ['save_time', 'follow_through'],
      formats: ['freemium'],
      salesMode: 'free_acquire',
    ),
  ),
  PlanningSample(
    id: 'sample_equipment_monitor',
    title: '설비 데이터 수집·모니터링 프로그램 만들기',
    description: '공장 설비 데이터를 수집·모니터링하는 산업자동화 SW 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.industrialAutomation,
      domains: ['industrial_auto', 'plc'],
      audiences: ['industrial_tech', 'enterprise'],
      problems: ['data_monitor_hard', 'manual_error'],
      outcomes: ['dashboard', 'automate'],
      salesMode: 'normal_paid',
      budget: 'quality_first',
      duration: 'month1',
    ),
  ),
  PlanningSample(
    id: 'sample_ai_sidejob_ebook',
    title: 'AI를 활용한 온라인 부업 안내서',
    description: 'AI 도구로 온라인 부업을 시작하는 전자책 샘플',
    seed: _sampleSeed(
      deliverable: PlanningDeliverables.ebook,
      domains: ['ai', 'online_income'],
      audiences: ['sidejob_40_60', 'office_worker'],
      problems: ['productize_unknown', 'start_unknown'],
      outcomes: ['start_income', 'monthly_plan'],
      formats: ['both', 'paid'],
      scale: 'basic_40_60',
      salesMode: 'cheap_validate',
      followUpDeliverables: [PlanningDeliverables.youtubeShorts],
    ),
  ),
];

PlanningSample? findPlanningSample(String id) {
  for (final s in planningSamples) {
    if (s.id == id) return s;
  }
  return null;
}

/// 샘플 복제본 (원본 변경 없음).
PlanningWizardState cloneSampleSeed(String sampleId) {
  final sample = findPlanningSample(sampleId);
  if (sample == null) {
    return PlanningWizardState();
  }
  return sample.seed.deepCopy();
}

/// 대상 고객 선택 수가 권장 한도를 넘었는지.
bool exceedsRecommendedAudienceCount(int count) =>
    count > maxRecommendedAudienceCount;

String audienceCountHint(int count) {
  if (count <= maxRecommendedAudienceCount) return '';
  return '대상 고객은 $maxRecommendedAudienceCount명 이하로 좁히면 기획이 선명해집니다. '
      '(현재 $count명 선택)';
}
