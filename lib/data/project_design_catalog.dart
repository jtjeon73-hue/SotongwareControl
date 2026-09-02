/// Project Design Engine — 결과물·고객·추천 주제·제작 옵션 카탈로그 (로컬 규칙).
library;

import '../models/artifact_type.dart';

class DesignAudience {
  const DesignAudience({required this.id, required this.label});

  final String id;
  final String label;
}

class DesignTopic {
  const DesignTopic({
    required this.id,
    required this.label,
    required this.audienceIds,
    this.artifacts = const [],
  });

  final String id;
  final String label;
  final List<String> audienceIds;

  /// 비어 있으면 모든 결과물에 해당.
  final List<String> artifacts;
}

class DesignOption {
  const DesignOption({required this.id, required this.label});

  final String id;
  final String label;
}

class DesignOptionGroup {
  const DesignOptionGroup({
    required this.id,
    required this.title,
    required this.options,
    this.multi = true,
  });

  final String id;
  final String title;
  final List<DesignOption> options;
  final bool multi;
}

class ArtifactCardDef {
  const ArtifactCardDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconName;
}

/// Project Design Engine 정적 카탈로그.
class ProjectDesignCatalog {
  ProjectDesignCatalog._();

  static const audiences = <DesignAudience>[
    DesignAudience(id: 'general', label: '일반 소비자'),
    DesignAudience(id: 'student', label: '학생'),
    DesignAudience(id: 'office', label: '직장인'),
    DesignAudience(id: 'smb', label: '소상공인'),
    DesignAudience(id: 'returning_farm', label: '귀농귀촌인'),
    DesignAudience(id: 'rural', label: '농촌·시골 거주자'),
    DesignAudience(id: 'retire_prep', label: '은퇴 준비자'),
    DesignAudience(id: 'age_40_60', label: '40~60대'),
    DesignAudience(id: 'age_60_80', label: '60~80대'),
    DesignAudience(id: 'custom', label: '기타 직접 입력'),
  ];

  static const artifactCards = <ArtifactCardDef>[
    ArtifactCardDef(
      id: ArtifactType.ebook,
      title: '전자책',
      subtitle: '가이드·실전 매뉴얼·수익 노하우',
      iconName: 'menu_book',
    ),
    ArtifactCardDef(
      id: ArtifactType.app,
      title: '앱',
      subtitle: 'Android · Flutter 실행형 제품',
      iconName: 'phone_android',
    ),
    ArtifactCardDef(
      id: ArtifactType.contents,
      title: '콘텐츠',
      subtitle: '노래 · 쇼츠 · 영상 · 기타',
      iconName: 'play_circle',
    ),
    ArtifactCardDef(
      id: ArtifactType.site,
      title: '지식사이트',
      subtitle: 'SEO · 지식 허브 · 관리 페이지',
      iconName: 'language',
    ),
    ArtifactCardDef(
      id: ArtifactType.promoSite,
      title: '홍보사이트',
      subtitle: '랜딩 · 전환 · 프로모 허브',
      iconName: 'campaign',
    ),
  ];

  /// 작업지시서 제작소 4대 유형 카드 (STEP A).
  static const studioMainCards = <ArtifactCardDef>[
    ArtifactCardDef(
      id: ArtifactType.ebook,
      title: '전자책 개발',
      subtitle: '가이드·매뉴얼·판매용 PDF/ePub',
      iconName: 'menu_book',
    ),
    ArtifactCardDef(
      id: ArtifactType.app,
      title: '앱 개발',
      subtitle: 'Android Flutter 상용 앱 · APK 배포',
      iconName: 'phone_android',
    ),
    ArtifactCardDef(
      id: ArtifactType.site,
      title: '사이트 개발',
      subtitle: '홈페이지·랜딩·지식·판매 사이트 (시험 운영)',
      iconName: 'language',
    ),
    ArtifactCardDef(
      id: ArtifactType.contents,
      title: '콘텐츠 개발',
      subtitle: '음악·쇼츠·만화 (시험 운영)',
      iconName: 'play_circle',
    ),
  ];

  static const siteKinds = <DesignOption>[
    DesignOption(id: 'corporate_site', label: '기업·기관 홈페이지'),
    DesignOption(id: 'marketing_site', label: '홍보·마케팅 사이트'),
    DesignOption(id: 'knowledge_site', label: '지식·정보 사이트'),
    DesignOption(id: 'education_site', label: '교육·학습 사이트'),
    DesignOption(id: 'information_portal', label: '분야별 정보 포털'),
  ];

  static const contentSubtypes = <DesignOption>[
    DesignOption(id: ContentSubtype.music, label: '노래·음악'),
    DesignOption(id: ContentSubtype.shorts, label: '쇼츠'),
    DesignOption(id: ContentSubtype.comic, label: '만화'),
  ];

  static const topics = <DesignTopic>[
    DesignTopic(
      id: 'ai_usage',
      label: 'AI 활용법',
      audienceIds: [
        'rural',
        'returning_farm',
        'age_40_60',
        'age_60_80',
        'office',
      ],
    ),
    DesignTopic(
      id: 'online_income',
      label: '온라인 수익',
      audienceIds: [
        'rural',
        'returning_farm',
        'smb',
        'retire_prep',
        'age_40_60',
      ],
    ),
    DesignTopic(
      id: 'smartphone',
      label: '스마트폰 활용',
      audienceIds: ['rural', 'age_60_80', 'age_40_60', 'general'],
    ),
    DesignTopic(
      id: 'health',
      label: '건강',
      audienceIds: ['age_40_60', 'age_60_80', 'retire_prep', 'rural'],
    ),
    DesignTopic(
      id: 'returning_farm_guide',
      label: '귀농',
      audienceIds: ['returning_farm', 'retire_prep', 'rural'],
    ),
    DesignTopic(
      id: 'agri_auto',
      label: '농업 자동화',
      audienceIds: ['rural', 'returning_farm', 'smb'],
      artifacts: [ArtifactType.ebook, ArtifactType.app, ArtifactType.site],
    ),
    DesignTopic(
      id: 'electric',
      label: '전기',
      audienceIds: ['rural', 'returning_farm', 'smb', 'office'],
    ),
    DesignTopic(
      id: 'plc',
      label: 'PLC',
      audienceIds: ['rural', 'returning_farm', 'smb', 'office'],
      artifacts: [ArtifactType.ebook, ArtifactType.app, ArtifactType.site],
    ),
    DesignTopic(
      id: 'retirement',
      label: '노후',
      audienceIds: ['retire_prep', 'age_40_60', 'age_60_80'],
    ),
    DesignTopic(
      id: 'gov_support',
      label: '정부지원',
      audienceIds: ['rural', 'returning_farm', 'smb', 'retire_prep'],
    ),
    DesignTopic(
      id: 'smart_farm',
      label: '스마트팜',
      audienceIds: ['rural', 'returning_farm'],
      artifacts: [ArtifactType.ebook, ArtifactType.app, ArtifactType.site],
    ),
    DesignTopic(
      id: 'side_hustle',
      label: '부업·사이드프로젝트',
      audienceIds: ['office', 'student', 'general', 'age_40_60'],
    ),
    DesignTopic(
      id: 'study_skill',
      label: '학습·스킬 업',
      audienceIds: ['student', 'office', 'general'],
    ),
    DesignTopic(
      id: 'local_biz',
      label: '동네·로컬 비즈니스',
      audienceIds: ['smb', 'rural', 'returning_farm'],
    ),
    DesignTopic(
      id: 'marketing',
      label: '홍보·마케팅',
      audienceIds: ['smb', 'office', 'general'],
      artifacts: [
        ArtifactType.promoSite,
        ArtifactType.contents,
        ArtifactType.ebook,
      ],
    ),
  ];

  static List<DesignTopic> topicsFor({
    required List<String> audienceIds,
    required String artifactType,
  }) {
    final artifact = ArtifactType.normalize(artifactType);
    final set = audienceIds.toSet();
    return topics.where((t) {
      final audienceOk =
          t.audienceIds.any(set.contains) || set.contains('custom');
      final artifactOk = t.artifacts.isEmpty || t.artifacts.contains(artifact);
      return audienceOk && artifactOk;
    }).toList();
  }

  static List<DesignOptionGroup> productionGroupsFor(
    String artifactType, {
    String contentSubtype = '',
  }) {
    switch (ArtifactType.normalize(artifactType)) {
      case ArtifactType.ebook:
        return const [
          DesignOptionGroup(
            id: 'format',
            title: '파일 형식',
            options: [
              DesignOption(id: 'pdf', label: 'PDF'),
              DesignOption(id: 'epub', label: 'EPUB'),
            ],
          ),
          DesignOptionGroup(
            id: 'pages',
            title: '페이지 수',
            multi: false,
            options: [
              DesignOption(id: 'p30', label: '30페이지 내외'),
              DesignOption(id: 'p50', label: '50페이지 내외'),
              DesignOption(id: 'p100', label: '100페이지 내외'),
            ],
          ),
          DesignOptionGroup(
            id: 'tone',
            title: '문체',
            multi: false,
            options: [
              DesignOption(id: 'friendly', label: '친절·쉬운 설명'),
              DesignOption(id: 'practical', label: '실전·체크리스트'),
              DesignOption(id: 'professional', label: '전문·체계적'),
            ],
          ),
          DesignOptionGroup(
            id: 'level',
            title: '난이도',
            multi: false,
            options: [
              DesignOption(id: 'beginner', label: '초급'),
              DesignOption(id: 'intermediate', label: '중급'),
              DesignOption(id: 'advanced', label: '고급'),
            ],
          ),
          DesignOptionGroup(
            id: 'pricing',
            title: '가격 정책',
            multi: false,
            options: [
              DesignOption(id: 'free', label: '무료'),
              DesignOption(id: 'low', label: '저가'),
              DesignOption(id: 'mid', label: '중간가'),
              DesignOption(id: 'premium', label: '프리미엄'),
            ],
          ),
        ];
      case ArtifactType.app:
        return const [
          DesignOptionGroup(
            id: 'platform',
            title: '플랫폼',
            options: [
              DesignOption(id: 'android', label: 'Android'),
              DesignOption(id: 'flutter', label: 'Flutter'),
            ],
          ),
          DesignOptionGroup(
            id: 'monetization',
            title: '수익·기능',
            options: [
              DesignOption(id: 'ads', label: '광고'),
              DesignOption(id: 'iap', label: '인앱 결제'),
              DesignOption(id: 'login', label: '로그인'),
              DesignOption(id: 'firebase', label: 'Firebase'),
            ],
          ),
        ];
      case ArtifactType.contents:
        return productionGroupsForContentSubtype(contentSubtype);
      case ArtifactType.site:
        return const [
          DesignOptionGroup(
            id: 'stack',
            title: '기술·구성',
            options: [
              DesignOption(id: 'flutter_web', label: 'Flutter Web'),
              DesignOption(id: 'seo', label: 'SEO'),
              DesignOption(id: 'firebase_hosting', label: 'Firebase Hosting'),
              DesignOption(id: 'admin', label: '관리자 페이지'),
            ],
          ),
        ];
      case ArtifactType.promoSite:
        return const [
          DesignOptionGroup(
            id: 'promo',
            title: '홍보 구성',
            options: [
              DesignOption(id: 'landing', label: '랜딩 페이지'),
              DesignOption(id: 'cta', label: '전환 CTA'),
              DesignOption(id: 'firebase_hosting', label: 'Firebase Hosting'),
              DesignOption(id: 'analytics', label: '유입 분석'),
            ],
          ),
        ];
      default:
        return const [];
    }
  }

  /// Subtype-specific production inputs for contents (music | shorts | comic).
  static List<DesignOptionGroup> productionGroupsForContentSubtype(
    String contentSubtype,
  ) {
    switch (ContentSubtype.normalize(contentSubtype)) {
      case ContentSubtype.music:
        return const [
          DesignOptionGroup(
            id: 'music_genre',
            title: '장르',
            options: [
              DesignOption(id: 'pop', label: '팝'),
              DesignOption(id: 'ballad', label: '발라드'),
              DesignOption(id: 'lofi', label: '로파이'),
              DesignOption(id: 'classical', label: '클래식'),
            ],
          ),
          DesignOptionGroup(
            id: 'music_mood',
            title: '분위기',
            options: [
              DesignOption(id: 'calm', label: '차분'),
              DesignOption(id: 'energetic', label: '활기'),
              DesignOption(id: 'focus', label: '집중'),
              DesignOption(id: 'sleep', label: '수면'),
            ],
          ),
          DesignOptionGroup(
            id: 'music_vocal',
            title: '보컬',
            multi: false,
            options: [
              DesignOption(id: 'instrumental', label: '연주곡'),
              DesignOption(id: 'vocal_ko', label: '한국어 보컬'),
              DesignOption(id: 'vocal_en', label: '영어 보컬'),
            ],
          ),
          DesignOptionGroup(
            id: 'music_instrument',
            title: '악기',
            options: [
              DesignOption(id: 'piano', label: '피아노'),
              DesignOption(id: 'guitar', label: '기타'),
              DesignOption(id: 'synth', label: '신스'),
              DesignOption(id: 'orchestra', label: '오케스트라'),
            ],
          ),
          DesignOptionGroup(
            id: 'music_language',
            title: '언어',
            multi: false,
            options: [
              DesignOption(id: 'ko', label: '한국어'),
              DesignOption(id: 'en', label: '영어'),
              DesignOption(id: 'instrumental_only', label: '가사 없음'),
            ],
          ),
          DesignOptionGroup(
            id: 'music_track_count',
            title: '곡 수',
            multi: false,
            options: [
              DesignOption(id: 'tracks_10', label: '약 10곡'),
              DesignOption(id: 'tracks_20', label: '약 20곡'),
              DesignOption(id: 'tracks_custom', label: '직접 지정'),
            ],
          ),
          DesignOptionGroup(
            id: 'music_video_length',
            title: '영상 길이',
            multi: false,
            options: [
              DesignOption(id: '1h', label: '1시간'),
              DesignOption(id: '2h', label: '2시간'),
              DesignOption(id: 'long', label: '장시간'),
            ],
          ),
          DesignOptionGroup(
            id: 'music_channel',
            title: '대상 채널',
            options: [
              DesignOption(id: 'sotong_music', label: '소통뮤직'),
              DesignOption(id: 'youtube', label: 'YouTube'),
            ],
          ),
        ];
      case ContentSubtype.shorts:
        return const [
          DesignOptionGroup(
            id: 'shorts_topic',
            title: '주제',
            multi: false,
            options: [
              DesignOption(id: 'howto', label: '정보·방법'),
              DesignOption(id: 'story', label: '스토리'),
              DesignOption(id: 'promo', label: '홍보'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_audience',
            title: '대상 시청자',
            multi: false,
            options: [
              DesignOption(id: 'general', label: '일반'),
              DesignOption(id: 'beginner', label: '초보'),
              DesignOption(id: 'professional', label: '전문가'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_length',
            title: '길이',
            multi: false,
            options: [
              DesignOption(id: '15s', label: '15초'),
              DesignOption(id: '30s', label: '30초'),
              DesignOption(id: '60s', label: '60초'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_engagement',
            title: '재미·정보 요소',
            options: [
              DesignOption(id: 'hook', label: '강한 훅'),
              DesignOption(id: 'tips', label: '핵심 팁'),
              DesignOption(id: 'twist', label: '반전·유머'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_format',
            title: '형식',
            multi: false,
            options: [
              DesignOption(id: 'info', label: '정보형'),
              DesignOption(id: 'promo', label: '홍보형'),
              DesignOption(id: 'story', label: '스토리형'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_visual',
            title: '화면 스타일',
            options: [
              DesignOption(id: 'live', label: '실사'),
              DesignOption(id: 'motion', label: '모션 그래픽'),
              DesignOption(id: 'screen', label: '화면 녹화'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_voice',
            title: '음성',
            multi: false,
            options: [
              DesignOption(id: 'narration', label: '내레이션'),
              DesignOption(id: 'dialogue', label: '대화'),
              DesignOption(id: 'none', label: '무음+자막'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_subtitle',
            title: '자막',
            multi: false,
            options: [
              DesignOption(id: 'on', label: '자막 포함'),
              DesignOption(id: 'off', label: '자막 없음'),
            ],
          ),
          DesignOptionGroup(
            id: 'shorts_channel',
            title: '게시 채널',
            options: [
              DesignOption(id: 'youtube_shorts', label: 'YouTube Shorts'),
              DesignOption(id: 'internal', label: '내부 검토만'),
            ],
          ),
        ];
      case ContentSubtype.comic:
        return const [
          DesignOptionGroup(
            id: 'comic_genre',
            title: '장르',
            options: [
              DesignOption(id: 'daily', label: '일상'),
              DesignOption(id: 'fantasy', label: '판타지'),
              DesignOption(id: 'edu', label: '교육'),
              DesignOption(id: 'info', label: '정보'),
            ],
          ),
          DesignOptionGroup(
            id: 'comic_age',
            title: '독자 연령',
            multi: false,
            options: [
              DesignOption(id: 'all', label: '전연령'),
              DesignOption(id: 'teen', label: '청소년'),
              DesignOption(id: 'adult', label: '성인'),
            ],
          ),
          DesignOptionGroup(
            id: 'comic_character',
            title: '캐릭터',
            options: [
              DesignOption(id: 'single', label: '단일 주인공'),
              DesignOption(id: 'ensemble', label: '다인물'),
              DesignOption(id: 'mascot', label: '마스코트'),
            ],
          ),
          DesignOptionGroup(
            id: 'comic_art_style',
            title: '그림 스타일',
            multi: false,
            options: [
              DesignOption(id: 'simple', label: '심플'),
              DesignOption(id: 'webtoon', label: '웹툰'),
              DesignOption(id: 'sketch', label: '스케치'),
            ],
          ),
          DesignOptionGroup(
            id: 'comic_episode_length',
            title: '에피소드 길이',
            multi: false,
            options: [
              DesignOption(id: 'short', label: '짧은 편'),
              DesignOption(id: 'standard', label: '표준'),
              DesignOption(id: 'long', label: '긴 편'),
            ],
          ),
          DesignOptionGroup(
            id: 'comic_panel_count',
            title: '컷 수',
            multi: false,
            options: [
              DesignOption(id: 'panels_4', label: '4컷'),
              DesignOption(id: 'panels_8', label: '8컷'),
              DesignOption(id: 'panels_scroll', label: '스크롤형'),
            ],
          ),
          DesignOptionGroup(
            id: 'comic_serial',
            title: '연재 방식',
            multi: false,
            options: [
              DesignOption(id: 'one_shot', label: '단편'),
              DesignOption(id: 'series', label: '연재'),
            ],
          ),
          DesignOptionGroup(
            id: 'comic_channel',
            title: '게시 채널',
            options: [
              DesignOption(id: 'webtoon', label: '웹툰 플랫폼'),
              DesignOption(id: 'sns', label: 'SNS'),
              DesignOption(id: 'internal', label: '내부 검토만'),
            ],
          ),
        ];
      default:
        return const [];
    }
  }

  static const libraryFolders = <String>[
    'all',
    'in_progress',
    'instruction_created',
    'transferred',
    'completed',
    'archived',
    'trashed',
    'duplicate_candidates',
    'stale',
    'ebook',
    'app',
    'contents',
    'site',
    'promo_site',
    'favorite',
  ];

  static String libraryFolderLabel(String id) {
    switch (id) {
      case 'ebook':
        return '전자책';
      case 'app':
        return '앱';
      case 'contents':
        return '콘텐츠';
      case 'site':
        return '지식사이트';
      case 'promo_site':
        return '홍보사이트';
      case 'favorite':
        return '즐겨찾기';
      case 'completed':
        return '완료';
      case 'archived':
        return '보관';
      case 'trashed':
        return '휴지통';
      case 'in_progress':
        return '진행중';
      case 'instruction_created':
        return '작업지시 생성';
      case 'transferred':
        return '전달 완료';
      case 'duplicate_candidates':
        return '중복 후보';
      case 'stale':
        return '오래된 기획';
      case 'all':
        return '전체';
      default:
        return id;
    }
  }
}
