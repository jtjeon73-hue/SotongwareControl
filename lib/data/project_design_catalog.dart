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

  static const contentSubtypes = <DesignOption>[
    DesignOption(id: ContentSubtype.song, label: '노래'),
    DesignOption(id: ContentSubtype.shorts, label: '쇼츠'),
    DesignOption(id: ContentSubtype.video, label: '영상'),
    DesignOption(id: ContentSubtype.songAndShorts, label: '노래+쇼츠'),
    DesignOption(id: ContentSubtype.other, label: '기타'),
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

  static List<DesignOptionGroup> productionGroupsFor(String artifactType) {
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
        return const [
          DesignOptionGroup(
            id: 'channel',
            title: '채널·형식',
            options: [
              DesignOption(id: 'song', label: '노래'),
              DesignOption(id: 'shorts', label: '쇼츠'),
              DesignOption(id: 'youtube', label: '유튜브'),
              DesignOption(id: 'voice', label: '음성'),
              DesignOption(id: 'subtitle', label: '자막'),
            ],
          ),
        ];
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
