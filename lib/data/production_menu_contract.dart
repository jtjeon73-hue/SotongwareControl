/// Production menu card states — sync with Sotong24Work ProductionMenuContract.h
library;

class ProductionMenuStatus {
  static const available = 'available';
  static const pilot = 'pilot';
  static const preparing = 'preparing';
  static const blocked = 'blocked';
}

class ProductionMenuCardDef {
  const ProductionMenuCardDef({
    required this.trackId,
    required this.titleKo,
    required this.status,
    required this.statusLabelKo,
    required this.supportedScopeKo,
    required this.subtypesKo,
    required this.lastValidatedStepKo,
    required this.goldenRunComplete,
    required this.expectedDeliverablesKo,
    required this.cautionKo,
  });

  final String trackId;
  final String titleKo;
  final String status;
  final String statusLabelKo;
  final String supportedScopeKo;
  final String subtypesKo;
  final String lastValidatedStepKo;
  final bool goldenRunComplete;
  final String expectedDeliverablesKo;
  final String cautionKo;
}

class ProductionMenuContract {
  ProductionMenuContract._();

  static const cards = <ProductionMenuCardDef>[
    ProductionMenuCardDef(
      trackId: 'app',
      titleKo: '앱',
      status: ProductionMenuStatus.available,
      statusLabelKo: '사용 가능',
      supportedScopeKo: 'STEP 1~18 앱 전용 공정',
      subtypesKo: '(단일 app track)',
      lastValidatedStepKo:
          'STEP 9 (app_core_implementation_1) / 최신 엔진 Cursor E2E',
      goldenRunComplete: false,
      expectedDeliverablesKo: 'Flutter APK, 소스, 배포 체크리스트',
      cautionKo:
          'verifiedThroughStep=9. goldenRunCompleted=false. 과거 전기점검 완주는 historicalGoldenRun만. externalDeploymentAllowed=false. Play/Firebase/원격 push 금지',
    ),
    ProductionMenuCardDef(
      trackId: 'ebook',
      titleKo: '전자책',
      status: ProductionMenuStatus.available,
      statusLabelKo: '사용 가능',
      supportedScopeKo: 'STEP 1~18 전자책 공정',
      subtypesKo: '(단일 ebook track)',
      lastValidatedStepKo: 'STEP 2 (problem_validate)',
      goldenRunComplete: false,
      expectedDeliverablesKo: '원고, 목차, PDF/ePub 준비 패키지',
      cautionKo: '외부 판매 등록은 사용자 승인 후',
    ),
    ProductionMenuCardDef(
      trackId: 'site',
      titleKo: '사이트',
      status: ProductionMenuStatus.pilot,
      statusLabelKo: '시험 운영',
      supportedScopeKo: 'SiteStageContract STEP 1~18 (검증: STEP 3까지)',
      subtypesKo:
          'corporate_site, marketing_site, knowledge_site, education_site, information_portal',
      lastValidatedStepKo: 'STEP 3 (site_materials_prep)',
      goldenRunComplete: false,
      expectedDeliverablesKo: '기획·IA·페이지·SEO·배포 체크리스트',
      cautionKo:
          'Firebase Hosting 실배포는 사용자 최종 승인 전 금지. STEP 4~18 Cursor E2E 미완료',
    ),
    ProductionMenuCardDef(
      trackId: 'contents',
      titleKo: '콘텐츠',
      status: ProductionMenuStatus.pilot,
      statusLabelKo: '시험 운영',
      supportedScopeKo: 'ContentStageContract STEP 1~18 (검증: shorts STEP 3까지)',
      subtypesKo: 'music (노래·음악), shorts (쇼츠), comic (만화)',
      lastValidatedStepKo: 'STEP 3 (shorts_concept_strategy)',
      goldenRunComplete: false,
      expectedDeliverablesKo: '기획서·대본·스토리보드·메타데이터·게시 준비 패키지',
      cautionKo: '음원·영상·이미지 실제 생성 도구 미연결 단계는 tool_required. YouTube 자동 업로드 금지',
    ),
  ];

  static ProductionMenuCardDef? findByTrack(String trackId) {
    for (final card in cards) {
      if (card.trackId == trackId) return card;
    }
    return null;
  }
}
