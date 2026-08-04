/// artifact 유형별 기획 질문·선택지 카탈로그 (순수 Dart, UI 없음).
library;

import '../models/artifact_type.dart';

class ArtifactQuestionOption {
  const ArtifactQuestionOption({
    required this.id,
    required this.label,
    this.recommended = false,
  });

  final String id;
  final String label;
  final bool recommended;
}

class ArtifactQuestion {
  const ArtifactQuestion({
    required this.id,
    required this.label,
    this.multi = false,
    this.allowCustom = false,
    required this.options,
  });

  final String id;
  final String label;
  final bool multi;
  final bool allowCustom;
  final List<ArtifactQuestionOption> options;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ArtifactQuestionOption _opt(
  String id,
  String label, {
  bool recommended = false,
}) => ArtifactQuestionOption(id: id, label: label, recommended: recommended);

ArtifactQuestion _q(
  String id,
  String label,
  List<ArtifactQuestionOption> options, {
  bool multi = false,
  bool allowCustom = false,
}) => ArtifactQuestion(
  id: id,
  label: label,
  multi: multi,
  allowCustom: allowCustom,
  options: options,
);

const _yesNoUndecided = [
  ArtifactQuestionOption(id: 'yes', label: '필요함'),
  ArtifactQuestionOption(id: 'no', label: '불필요'),
  ArtifactQuestionOption(id: 'undecided', label: '아직 모름'),
];

const _maintenanceOptions = [
  ArtifactQuestionOption(id: 'self', label: '직접 관리'),
  ArtifactQuestionOption(id: 'minimal', label: '최소 유지'),
  ArtifactQuestionOption(id: 'periodic', label: '정기 점검', recommended: true),
  ArtifactQuestionOption(id: 'outsource', label: '외주·대행'),
  ArtifactQuestionOption(id: 'undecided', label: '아직 모름'),
];

// ---------------------------------------------------------------------------
// 공통 질문 (사업주제 topic 은 문장 필드 — 제외)
// ---------------------------------------------------------------------------

List<ArtifactQuestion> commonQuestions() => [
  _q(
    'customerProblem',
    '고객 문제',
    [
      _opt('start_unknown', '무엇부터 시작해야 할지 모른다'),
      _opt('productize_unknown', '경험과 기술을 상품으로 만드는 방법을 모른다'),
      _opt('sales_channel_unknown', '판매할 곳을 모른다'),
      _opt('promo_unknown', '홍보 방법을 모른다'),
      _opt('easy_learn', '어려운 정보를 쉽게 배우고 싶다'),
      _opt('cost_burden', '비용이 부담된다'),
      _opt('time_short', '시간이 부족하다'),
      _opt('custom', '직접 입력'),
    ],
    multi: true,
    allowCustom: true,
  ),
  _q(
    'targetCustomer',
    '대상 고객',
    [
      _opt('rural_resident', '농촌·시골 거주자'),
      _opt('return_prep', '귀농·귀촌 준비자'),
      _opt('retirement_prep', '은퇴 준비자'),
      _opt('sidejob_40_60', '40~60대 부업 희망자'),
      _opt('small_business', '소상공인'),
      _opt('office_worker', '직장인'),
      _opt('consumer', '일반 소비자'),
      _opt('custom', '직접 입력'),
    ],
    multi: true,
    allowCustom: true,
  ),
  _q(
    'desiredOutcome',
    '원하는 결과',
    [
      _opt('follow_through', '처음부터 끝까지 따라 할 수 있다'),
      _opt('sellable', '실제 판매 가능한 결과물을 완성한다'),
      _opt('save_time', '시간을 절약한다'),
      _opt('start_income', '온라인 수익을 시작한다'),
      _opt('get_customers', '고객을 확보한다'),
      _opt('learn_sys', '기술을 체계적으로 배운다'),
      _opt('custom', '직접 입력'),
    ],
    multi: true,
    allowCustom: true,
  ),
  _q(
    'materialsExperience',
    '보유 자료·경험',
    [
      _opt('notes', '메모·원고 초안'),
      _opt('photos', '사진·영상'),
      _opt('expertise', '실무·전문 경험'),
      _opt('data', '데이터·기록'),
      _opt('brand', '브랜드·로고'),
      _opt('none', '아직 없음'),
      _opt('custom', '직접 입력'),
    ],
    multi: true,
    allowCustom: true,
  ),
  _q('schedule', '일정', [
    _opt('week1', '빠르게 1주'),
    _opt('week2', '기본 2주', recommended: true),
    _opt('month1', '충분하게 1개월'),
    _opt('undecided', '일정 미정'),
  ]),
  _q('budget', '예산', [
    _opt('free_tools', '무료 도구 중심'),
    _opt('minimal', '최소 비용'),
    _opt('quality_first', '품질 우선'),
    _opt('undecided', '예산 미정'),
  ]),
  _q('salesDeploy', '판매·배포 방식', [
    _opt('free_acquire', '무료 배포로 고객 확보'),
    _opt('cheap_validate', '저가 판매로 초기 검증', recommended: true),
    _opt('normal_paid', '일반 유료 판매'),
    _opt('premium', '고급 상품으로 판매'),
    _opt('with_consult', '상담·교육과 연결'),
    _opt('bundle', '다른 결과물과 함께 판매'),
    _opt('undecided', '아직 결정하지 않음'),
  ]),
];

// ---------------------------------------------------------------------------
// 유형별 질문
// ---------------------------------------------------------------------------

List<ArtifactQuestion> _ebookQuestions() => [
  _q('ebookKind', '전자책 종류', [
    _opt('practical', '실용서'),
    _opt('education', '교육서'),
    _opt('experience', '경험담'),
    _opt('guide', '가이드', recommended: true),
    _opt('workbook', '워크북'),
  ]),
  _q('readerLevel', '독자 수준', [
    _opt('beginner', '완전 초보'),
    _opt('basic', '기초 수준'),
    _opt('intermediate', '중급', recommended: true),
    _opt('advanced', '고급·전문가'),
  ]),
  _q('pageVolume', '분량(쪽 수)', [
    _opt('pages_20_30', '약 20~30쪽'),
    _opt('pages_40_60', '약 40~60쪽', recommended: true),
    _opt('pages_70_100', '약 70~100쪽'),
    _opt('pages_100_plus', '100쪽 이상'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('outputFormat', '출력 형식', [
    _opt('pdf', 'PDF'),
    _opt('epub', 'EPUB'),
    _opt('both', 'PDF와 EPUB 모두', recommended: true),
    _opt('undecided', '아직 모름'),
  ]),
  _q('tone', '글 톤·분위기', [
    _opt('friendly', '친근·대화체'),
    _opt('practical', '실용·간결', recommended: true),
    _opt('formal', '격식·전문'),
    _opt('story', '스토리·경험 중심'),
  ]),
  _q('salesMode', '판매 방식', [
    _opt('free', '무료 배포'),
    _opt('cheap', '저가 검증', recommended: true),
    _opt('paid', '유료 판매'),
    _opt('bundle', '패키지·번들'),
    _opt('consult', '상담·교육 연계'),
  ]),
  _q('needCover', '표지 필요', _yesNoUndecided),
  _q('needIllustrations', '삽화·도표 필요', _yesNoUndecided),
  _q('salesChannel', '판매 채널', [
    _opt('ridibooks', '리디북스'),
    _opt('yes24', 'YES24'),
    _opt('own_site', '자체 사이트'),
    _opt('coupang', '쿠팡·마켓'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('followPromo', '후속 홍보', [
    _opt('shorts', '유튜브 쇼츠'),
    _opt('site', '홍보 사이트'),
    _opt('sns', 'SNS 게시'),
    _opt('none', '당장 없음'),
    _opt('undecided', '아직 모름'),
  ], multi: true),
];

List<ArtifactQuestion> _appQuestions() => [
  _q('appKind', '앱 종류', [
    _opt('life', '생활·정보'),
    _opt('productivity', '업무·생산성'),
    _opt('education', '교육·학습'),
    _opt('business', '비즈니스·납품', recommended: true),
    _opt('utility', '도구·유틸리티'),
  ]),
  _q(
    'coreFeatures',
    '핵심 기능',
    [
      _opt('record', '기록·메모'),
      _opt('notify', '알림·일정'),
      _opt('search', '검색·조회'),
      _opt('share', '공유·협업'),
      _opt('custom', '직접 입력'),
    ],
    multi: true,
    allowCustom: true,
  ),
  _q('userActions', '사용자 행동', [
    _opt('daily', '매일 반복 사용'),
    _opt('on_demand', '필요할 때 사용'),
    _opt('one_time', '1회성 작업'),
    _opt('subscribe', '구독·정기 이용', recommended: true),
  ]),
  _q('platforms', '대상 플랫폼', [
    _opt('android', 'Android', recommended: true),
    _opt('ios', 'iOS'),
    _opt('web', '웹'),
    _opt('windows', 'Windows'),
  ], multi: true),
  _q('needLogin', '로그인 필요', _yesNoUndecided),
  _q('needDataStore', '데이터 저장 필요', _yesNoUndecided),
  _q('deviceFeatures', '기기 기능 활용', [
    _opt('camera', '카메라'),
    _opt('gps', '위치(GPS)'),
    _opt('push', '푸시 알림'),
    _opt('offline', '오프라인 동작'),
    _opt('none', '없음'),
  ], multi: true),
  _q('monetization', '수익화 방식', [
    _opt('free', '무료'),
    _opt('ad', '광고'),
    _opt('freemium', '기본 무료·고급 유료', recommended: true),
    _opt('paid', '유료'),
    _opt('b2b', 'B2B 납품'),
  ]),
  _q('needAdmin', '관리자 기능 필요', _yesNoUndecided),
  _q('playStore', '스토어 등록', [
    _opt('play', 'Google Play'),
    _opt('appstore', 'App Store'),
    _opt('both', '둘 다'),
    _opt('apk_only', 'APK 직접 배포'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('maintenance', '유지관리', _maintenanceOptions),
];

List<ArtifactQuestion> _songQuestions() => [
  _q('songPurpose', '노래 목적', [
    _opt('brand', '브랜드·채널 음원'),
    _opt('promo', '홍보·광고'),
    _opt('education', '교육·안내'),
    _opt('emotion', '감성·스토리', recommended: true),
    _opt('product', '상품·판매용'),
  ]),
  _q('genre', '장르', [
    _opt('ballad', '발라드'),
    _opt('pop', '팝'),
    _opt('folk', '포크·어쿠스틱'),
    _opt('electronic', '일렉트로닉'),
    _opt('custom', '직접 입력'),
  ], allowCustom: true),
  _q('mood', '분위기', [
    _opt('warm', '따뜻·힐링'),
    _opt('bright', '밝고 경쾌'),
    _opt('calm', '차분·잔잔', recommended: true),
    _opt('powerful', '힘 있고 웅장'),
  ]),
  _q('storyTheme', '스토리·주제', [
    _opt('daily_life', '일상·생활'),
    _opt('growth', '성장·도전'),
    _opt('nature', '자연·농촌'),
    _opt('custom', '직접 입력'),
  ], allowCustom: true),
  _q('listeners', '청취 대상', [
    _opt('general', '일반 대중'),
    _opt('niche', '특정 관심층'),
    _opt('family', '가족·지인'),
    _opt('business', '고객·업체'),
  ]),
  _q('length', '곡 길이', [
    _opt('short_60', '약 1분'),
    _opt('standard_3', '약 3분', recommended: true),
    _opt('long_5', '약 5분'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('vocalType', '보컬 유형', [
    _opt('male', '남성'),
    _opt('female', '여성'),
    _opt('duet', '듀엣'),
    _opt('instrumental', '연주만'),
  ]),
  _q('needLyrics', '가사 필요', _yesNoUndecided),
  _q('withVideo', '영상 연계', _yesNoUndecided),
  _q('platforms', '배포 플랫폼', [
    _opt('youtube', '유튜브'),
    _opt('spotify', 'Spotify 등 스트리밍'),
    _opt('sns', 'SNS 숏클립'),
    _opt('own', '자체 사이트'),
  ], multi: true),
  _q('copyright', '저작권·라이선스', [
    _opt('original', '완전 오리지널'),
    _opt('cover', '커버·리메이크'),
    _opt('ai_assist', 'AI 보조 창작'),
    _opt('undecided', '아직 모름'),
  ]),
];

List<ArtifactQuestion> _shortsQuestions() => [
  _q('videoPurpose', '영상 목적', [
    _opt('promo', '홍보·소개'),
    _opt('education', '교육·설명'),
    _opt('story', '스토리·브이로그', recommended: true),
    _opt('tips', '팁·노하우'),
  ]),
  _q('keyMessage', '핵심 메시지', [
    _opt('problem_solution', '문제 해결'),
    _opt('how_to', '방법·절차'),
    _opt('experience', '경험 공유'),
    _opt('custom', '직접 입력'),
  ], allowCustom: true),
  _q('viewers', '시청 대상', [
    _opt('general', '일반 시청자'),
    _opt('beginner', '초보·입문자'),
    _opt('local', '지역 주민'),
    _opt('business', '고객·사업주'),
  ]),
  _q('length15_30_60', '영상 길이', [
    _opt('sec15', '약 15초'),
    _opt('sec30', '약 30초'),
    _opt('sec60', '약 60초', recommended: true),
    _opt('undecided', '아직 모름'),
  ]),
  _q('aspectRatio', '화면 비율', [
    _opt('vertical_9_16', '세로 9:16 (쇼츠)', recommended: true),
    _opt('square_1_1', '정사각 1:1'),
    _opt('horizontal_16_9', '가로 16:9'),
  ]),
  _q('narration', '내레이션', [
    _opt('voice', '음성 내레이션'),
    _opt('subtitle_only', '자막만'),
    _opt('none', '없음'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('captions', '자막', [
    _opt('burn_in', '영상에 포함'),
    _opt('platform', '플랫폼 자막'),
    _opt('none', '없음'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('mediaSource', '영상 소스', [
    _opt('self_shot', '직접 촬영'),
    _opt('stock', '스톡·소스 영상'),
    _opt('screen', '화면 녹화'),
    _opt('mixed', '혼합'),
  ]),
  _q('needMusic', '배경음악 필요', _yesNoUndecided),
  _q('publishChannels', '게시 채널', [
    _opt('youtube_shorts', '유튜브 쇼츠', recommended: true),
    _opt('instagram', '인스타 릴스'),
    _opt('tiktok', '틱톡'),
    _opt('multiple', '여러 채널'),
  ], multi: true),
  _q('linkArtifacts', '연계 결과물', [
    _opt('ebook', '전자책'),
    _opt('site', '사이트'),
    _opt('app', '앱'),
    _opt('song', '노래'),
    _opt('none', '없음'),
  ], multi: true),
];

List<ArtifactQuestion> _songAndShortsQuestions() => [
  _q('songPurpose', '콘텐츠 목적', [
    _opt('brand', '브랜드·채널'),
    _opt('promo', '홍보·광고', recommended: true),
    _opt('education', '교육·안내'),
    _opt('emotion', '감성·스토리'),
  ]),
  _q('genre', '음악 장르', [
    _opt('ballad', '발라드'),
    _opt('pop', '팝', recommended: true),
    _opt('folk', '포크·어쿠스틱'),
    _opt('electronic', '일렉트로닉'),
  ]),
  _q('mood', '분위기', [
    _opt('warm', '따뜻·힐링'),
    _opt('bright', '밝고 경쾌', recommended: true),
    _opt('calm', '차분·잔잔'),
    _opt('powerful', '힘 있고 웅장'),
  ]),
  _q('length', '곡·영상 길이', [
    _opt('short_60', '약 1분'),
    _opt('sec30', '약 30초'),
    _opt('sec60', '약 60초', recommended: true),
    _opt('standard_3', '약 3분'),
  ]),
  _q('vocalType', '보컬 유형', [
    _opt('male', '남성'),
    _opt('female', '여성'),
    _opt('duet', '듀엣'),
    _opt('instrumental', '연주만'),
  ]),
  _q('videoPurpose', '쇼츠 목적', [
    _opt('promo', '홍보·소개', recommended: true),
    _opt('education', '교육·설명'),
    _opt('story', '스토리·브이로그'),
    _opt('tips', '팁·노하우'),
  ]),
  _q('length15_30_60', '쇼츠 길이', [
    _opt('sec15', '약 15초'),
    _opt('sec30', '약 30초'),
    _opt('sec60', '약 60초', recommended: true),
  ]),
  _q('aspectRatio', '화면 비율', [
    _opt('vertical_9_16', '세로 9:16 (쇼츠)', recommended: true),
    _opt('square_1_1', '정사각 1:1'),
    _opt('horizontal_16_9', '가로 16:9'),
  ]),
  _q('publishChannels', '게시 채널', [
    _opt('youtube_shorts', '유튜브 쇼츠', recommended: true),
    _opt('instagram', '인스타 릴스'),
    _opt('tiktok', '틱톡'),
    _opt('multiple', '여러 채널'),
  ], multi: true),
  _q('linkArtifacts', '연계 결과물', [
    _opt('ebook', '전자책'),
    _opt('site', '사이트'),
    _opt('app', '앱'),
    _opt('none', '없음'),
  ], multi: true),
];

List<ArtifactQuestion> _contentOtherQuestions() => [
  _q('contentGoal', '콘텐츠 목표', [
    _opt('inform', '정보 전달'),
    _opt('educate', '교육·학습', recommended: true),
    _opt('promote', '홍보·마케팅'),
    _opt('entertain', '재미·오락'),
  ]),
  _q('format', '형식', [
    _opt('video', '영상'),
    _opt('audio', '오디오'),
    _opt('text', '글·문서'),
    _opt('mixed', '혼합'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('audience', '대상', [
    _opt('general', '일반 대중'),
    _opt('beginner', '초보·입문자'),
    _opt('business', '사업·업무'),
    _opt('local', '지역 주민'),
  ]),
  _q('length', '길이·분량', [
    _opt('short', '짧게 (1~3분)'),
    _opt('medium', '중간 (5~10분)', recommended: true),
    _opt('long', '길게 (10분+)'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('channel', '배포 채널', [
    _opt('youtube', '유튜브'),
    _opt('sns', 'SNS'),
    _opt('own', '자체 사이트'),
    _opt('undecided', '아직 모름'),
  ]),
];

List<ArtifactQuestion> _siteQuestions() => [
  _q('sitePurpose', '사이트 목적', [
    _opt('info', '정보 제공'),
    _opt('service', '서비스 안내'),
    _opt('community', '커뮤니티'),
    _opt('portfolio', '포트폴리오', recommended: true),
  ]),
  _q('siteType', '사이트 유형', [
    _opt('info', '정보형'),
    _opt('edu', '교육형'),
    _opt('portfolio', '포트폴리오'),
    _opt('community', '커뮤니티'),
    _opt('work', '업무·내부용', recommended: true),
  ]),
  _q('visitors', '방문자', [
    _opt('general', '일반 방문자'),
    _opt('customer', '고객·문의자'),
    _opt('member', '회원'),
    _opt('internal', '내부 직원'),
  ]),
  _q(
    'menus',
    '주요 메뉴',
    [
      _opt('about', '소개'),
      _opt('service', '서비스·기능'),
      _opt('board', '게시판'),
      _opt('contact', '문의'),
      _opt('custom', '직접 입력'),
    ],
    multi: true,
    allowCustom: true,
  ),
  _q('needSearch', '검색 기능', _yesNoUndecided),
  _q('needMembers', '회원 기능', _yesNoUndecided),
  _q('needAdmin', '관리자 기능', _yesNoUndecided),
  _q('needDownload', '다운로드 기능', _yesNoUndecided),
  _q('needContact', '문의·연락 기능', _yesNoUndecided),
  _q('responsive', '반응형(모바일)', [
    _opt('yes', '필요함', recommended: true),
    _opt('no', 'PC만'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('domainHosting', '도메인·호스팅', [
    _opt('have', '이미 있음'),
    _opt('need_setup', '새로 필요'),
    _opt('github_pages', 'GitHub Pages'),
    _opt('firebase', 'Firebase Hosting'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('maintenance', '유지관리', _maintenanceOptions),
];

List<ArtifactQuestion> _promoSiteQuestions() => [
  _q('productService', '제품·서비스', [
    _opt('physical', '실물 상품'),
    _opt('digital', '디지털·콘텐츠'),
    _opt('service', '서비스·상담', recommended: true),
    _opt('custom', '직접 입력'),
  ], allowCustom: true),
  _q('coreCustomer', '핵심 고객', [
    _opt('consumer', '일반 소비자'),
    _opt('small_business', '소상공인'),
    _opt('enterprise', '기업·기관'),
    _opt('local', '지역 주민'),
  ]),
  _q('customerPain', '고객 고민', [
    _opt('trust', '신뢰·정보 부족'),
    _opt('compare', '비교·선택 어려움'),
    _opt('contact', '문의·연락 불편'),
    _opt('custom', '직접 입력'),
  ], allowCustom: true),
  _q(
    'keyBenefits',
    '핵심 혜택',
    [
      _opt('save_time', '시간 절약'),
      _opt('save_cost', '비용 절감'),
      _opt('expert', '전문성·신뢰'),
      _opt('custom', '직접 입력'),
    ],
    multi: true,
    allowCustom: true,
  ),
  _q('ctaAction', '행동 유도(CTA)', [
    _opt('contact', '문의하기', recommended: true),
    _opt('call', '전화하기'),
    _opt('apply', '신청·예약'),
    _opt('download', '다운로드'),
  ]),
  _q('contactMethods', '연락 수단', [
    _opt('form', '문의 폼'),
    _opt('phone', '전화'),
    _opt('kakao', '카카오·메신저'),
    _opt('email', '이메일'),
  ], multi: true),
  _q('mediaAssets', '홍보 자료', [
    _opt('logo', '로고·브랜드'),
    _opt('photos', '사진'),
    _opt('video', '영상'),
    _opt('none', '아직 없음'),
  ], multi: true),
  _q('testimonials', '후기·사례', [
    _opt('have', '이미 있음'),
    _opt('need', '필요·수집 예정'),
    _opt('none', '없음'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('showPrice', '가격 표시', [
    _opt('show', '표시함'),
    _opt('hide', '표시 안 함'),
    _opt('consult', '상담 후 안내', recommended: true),
  ]),
  _q('serviceArea', '서비스 지역', [
    _opt('local', '지역 한정'),
    _opt('nationwide', '전국'),
    _opt('online', '온라인만'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('pageStructure', '페이지 구성', [
    _opt('landing', '랜딩 1페이지', recommended: true),
    _opt('multi', '다중 페이지'),
    _opt('undecided', '아직 모름'),
  ]),
  _q('adsSns', '광고·SNS 연동', [
    _opt('meta', 'Meta·페이스북'),
    _opt('google', 'Google Ads'),
    _opt('youtube', '유튜브'),
    _opt('none', '당장 없음'),
  ], multi: true),
  _q('saveInquiries', '문의 저장', [
    _opt('email', '이메일 알림'),
    _opt('sheet', '스프레드시트'),
    _opt('firebase', 'Firebase DB', recommended: true),
    _opt('none', '저장 안 함'),
  ]),
  _q('firebaseDomain', 'Firebase·도메인', [
    _opt('have', '이미 있음'),
    _opt('need_setup', '새로 설정'),
    _opt('github_pages', 'GitHub Pages만'),
    _opt('undecided', '아직 모름'),
  ]),
];

List<ArtifactQuestion> _typeSpecificQuestions(
  String artifact,
  String? contentSubtype,
) {
  switch (ArtifactType.normalize(artifact)) {
    case ArtifactType.ebook:
      return _ebookQuestions();
    case ArtifactType.app:
      return _appQuestions();
    case ArtifactType.contents:
      switch (ContentSubtype.normalize(contentSubtype ?? '')) {
        case ContentSubtype.song:
          return _songQuestions();
        case ContentSubtype.shorts:
          return _shortsQuestions();
        case ContentSubtype.songAndShorts:
          return _songAndShortsQuestions();
        case ContentSubtype.other:
        case ContentSubtype.undecided:
        default:
          return _contentOtherQuestions();
      }
    case ArtifactType.site:
      return _siteQuestions();
    case ArtifactType.promoSite:
      return _promoSiteQuestions();
    default:
      return const [];
  }
}

// ---------------------------------------------------------------------------
// 공개 API
// ---------------------------------------------------------------------------

List<ArtifactQuestion> questionsFor({
  required String artifact,
  String? contentSubtype,
}) {
  return [
    ...commonQuestions(),
    ..._typeSpecificQuestions(artifact, contentSubtype),
  ];
}

List<ArtifactQuestionOption> artifactTypeOptions() => [
  _opt(ArtifactType.ebook, ArtifactType.labelKo(ArtifactType.ebook)),
  _opt(ArtifactType.app, ArtifactType.labelKo(ArtifactType.app)),
  _opt(ArtifactType.contents, ArtifactType.labelKo(ArtifactType.contents)),
  _opt(ArtifactType.site, ArtifactType.labelKo(ArtifactType.site)),
  _opt(ArtifactType.promoSite, ArtifactType.labelKo(ArtifactType.promoSite)),
  _opt(ArtifactType.undecided, ArtifactType.labelKo(ArtifactType.undecided)),
];

List<ArtifactQuestionOption> contentSubtypeOptions() => [
  for (final id in ContentSubtype.allSelectable)
    _opt(id, ContentSubtype.labelKo(id)),
  _opt(
    ContentSubtype.undecided,
    ContentSubtype.labelKo(ContentSubtype.undecided),
  ),
];

/// domains·problems 키워드 기반 artifact 추천 (로컬 휴리스틱).
String recommendArtifact({
  required List<String> domains,
  required List<String> problems,
}) {
  final scores = <String, int>{
    ArtifactType.ebook: 10,
    ArtifactType.app: 8,
    ArtifactType.contents: 8,
    ArtifactType.site: 8,
    ArtifactType.promoSite: 8,
  };

  void bump(String artifact, int delta) {
    scores[artifact] = (scores[artifact] ?? 0) + delta;
  }

  bool hasDomain(String id) => domains.contains(id);
  bool hasProblem(String id) => problems.contains(id);

  if (hasDomain('online_income') ||
      hasDomain('rural_life') ||
      hasDomain('return_farm')) {
    bump(ArtifactType.ebook, 6);
    bump(ArtifactType.contents, 3);
  }
  if (hasDomain('app_dev') || hasDomain('software')) {
    bump(ArtifactType.app, 8);
  }
  if (hasDomain('industrial_auto') || hasDomain('plc')) {
    bump(ArtifactType.app, 6);
    bump(ArtifactType.site, 4);
  }
  if (hasDomain('local_tourism') || hasDomain('life_info')) {
    bump(ArtifactType.promoSite, 7);
    bump(ArtifactType.contents, 4);
  }
  if (hasDomain('hobby_music')) {
    bump(ArtifactType.contents, 10);
  }
  if (hasDomain('ai')) {
    bump(ArtifactType.ebook, 3);
    bump(ArtifactType.app, 3);
  }

  if (hasProblem('productize_unknown') ||
      hasProblem('outline_unknown') ||
      hasProblem('sales_channel_unknown')) {
    bump(ArtifactType.ebook, 5);
  }
  if (hasProblem('promo_unknown') || hasProblem('get_customers')) {
    bump(ArtifactType.promoSite, 6);
    bump(ArtifactType.contents, 4);
  }
  if (hasProblem('complex_manage') || hasProblem('repetitive')) {
    bump(ArtifactType.app, 6);
  }
  if (hasProblem('data_monitor_hard') ||
      hasProblem('plc_pc_hard') ||
      hasProblem('manual_error')) {
    bump(ArtifactType.app, 5);
    bump(ArtifactType.site, 3);
  }
  if (hasProblem('start_unknown') || hasProblem('step_guide')) {
    bump(ArtifactType.ebook, 2);
    bump(ArtifactType.contents, 2);
  }

  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  if (ranked.isEmpty || ranked.first.value <= 0) {
    return ArtifactType.undecided;
  }
  return ranked.first.key;
}

/// 질문 id → 추천 선택 id 목록.
Map<String, List<String>> defaultSelectionsFor(
  String artifact, {
  String? contentSubtype,
}) {
  final normalized = ArtifactType.normalize(artifact);
  final subtype = ContentSubtype.normalize(contentSubtype ?? '');
  final defaults = <String, List<String>>{
    'schedule': ['week2'],
    'budget': ['free_tools'],
    'salesDeploy': ['cheap_validate'],
  };

  switch (normalized) {
    case ArtifactType.ebook:
      defaults.addAll({
        'ebookKind': ['guide'],
        'readerLevel': ['intermediate'],
        'pageVolume': ['pages_40_60'],
        'outputFormat': ['both'],
        'tone': ['practical'],
        'salesMode': ['cheap'],
        'needCover': ['yes'],
        'needIllustrations': ['undecided'],
        'salesChannel': ['undecided'],
        'followPromo': ['shorts'],
      });
    case ArtifactType.app:
      defaults.addAll({
        'appKind': ['business'],
        'coreFeatures': ['record'],
        'userActions': ['subscribe'],
        'platforms': ['android'],
        'needLogin': ['undecided'],
        'needDataStore': ['yes'],
        'deviceFeatures': ['none'],
        'monetization': ['freemium'],
        'needAdmin': ['undecided'],
        'playStore': ['play'],
        'maintenance': ['periodic'],
      });
    case ArtifactType.contents:
      switch (subtype) {
        case ContentSubtype.song:
          defaults.addAll({
            'songPurpose': ['emotion'],
            'genre': ['pop'],
            'mood': ['calm'],
            'length': ['standard_3'],
            'vocalType': ['female'],
            'needLyrics': ['yes'],
            'withVideo': ['undecided'],
            'platforms': ['youtube'],
            'copyright': ['original'],
          });
        case ContentSubtype.shorts:
          defaults.addAll({
            'videoPurpose': ['story'],
            'length15_30_60': ['sec60'],
            'aspectRatio': ['vertical_9_16'],
            'narration': ['voice'],
            'captions': ['burn_in'],
            'mediaSource': ['self_shot'],
            'needMusic': ['yes'],
            'publishChannels': ['youtube_shorts'],
            'linkArtifacts': ['none'],
          });
        case ContentSubtype.songAndShorts:
          defaults.addAll({
            'songPurpose': ['promo'],
            'genre': ['pop'],
            'mood': ['bright'],
            'length': ['sec60'],
            'vocalType': ['female'],
            'videoPurpose': ['promo'],
            'length15_30_60': ['sec60'],
            'aspectRatio': ['vertical_9_16'],
            'publishChannels': ['youtube_shorts'],
            'linkArtifacts': ['none'],
          });
        default:
          defaults.addAll({
            'contentGoal': ['educate'],
            'format': ['undecided'],
            'audience': ['general'],
            'length': ['medium'],
            'channel': ['undecided'],
          });
      }
    case ArtifactType.site:
      defaults.addAll({
        'sitePurpose': ['portfolio'],
        'siteType': ['work'],
        'visitors': ['general'],
        'menus': ['about', 'contact'],
        'needSearch': ['no'],
        'needMembers': ['no'],
        'needAdmin': ['undecided'],
        'needDownload': ['no'],
        'needContact': ['yes'],
        'responsive': ['yes'],
        'domainHosting': ['undecided'],
        'maintenance': ['periodic'],
      });
    case ArtifactType.promoSite:
      defaults.addAll({
        'productService': ['service'],
        'coreCustomer': ['consumer'],
        'ctaAction': ['contact'],
        'contactMethods': ['form'],
        'showPrice': ['consult'],
        'serviceArea': ['online'],
        'pageStructure': ['landing'],
        'saveInquiries': ['firebase'],
        'firebaseDomain': ['undecided'],
      });
    default:
      break;
  }

  return defaults;
}
