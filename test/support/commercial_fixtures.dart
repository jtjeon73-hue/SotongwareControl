/// In-memory commercial PASS fixtures for Control tests (no network/send).
/// Shapes mirror Sotong24Work HEAD 5b204b7 fixture paths/enums.
library;

import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/commercial/commercial_quality_attachment.dart';
import 'package:sotong_ware_control/models/commercial/commercial_quality_standard.dart';
import 'package:sotong_ware_control/models/commercial/commercial_track_profiles.dart';
import 'package:sotong_ware_control/models/commercial/work_instruction_brief.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/services/content_subtype_contract.dart';

class CommercialFixtures {
  CommercialFixtures._();

  static CommercialQualityStandard standard({
    String audience = '대상 고객',
    String problem = '고객 문제',
    String outcome = '약속하는 결과',
  }) => CommercialQualityStandard(
    targetAudience: audience,
    customerProblem: problem,
    promisedOutcome: outcome,
    uniqueValue: '차별화 가치',
    reasonsToPay: const ['돈이 아깝지 않은 구체 혜택'],
    commercialGoal: '유료 상용 후보',
    monetizationModel: 'one_time_or_subscription',
    brandDirection: '소통웨어 브랜드 방향',
    referenceLevel: '상용 후보 수준',
    localizationTarget: 'ko_primary',
    accessibilityTarget: 'readable_mobile',
    requiredDeliverables: const ['primary_deliverable', 'owner_review_package'],
    evidenceRequirements: const ['automated_tests', 'real_artifact_evidence'],
    humanReviewRequirements: const ['owner_review'],
    revisionPolicy: 'R_n_preserves_prior',
    releaseReadinessCriteria: const ['human_ok', 'blocker0'],
    explicitlyOutOfScope: const ['external_publish_without_ok'],
    legalPrivacyCopyrightRisks: const ['copyright_review'],
  );

  static WorkInstructionBrief brief({
    String displayTitle = '초보자를 위한 AI 전자책 만들기',
    String original = '50대 초보자가 AI를 이용해 첫 전자책을 만드는 과정을 따라 하는 책',
    bool manualOnly = false,
    String creationMode = 'new_product',
    String? aiAugmented,
    List<String> requestedChanges = const [],
    String sourceInstructionId = '',
    String sourceRevision = '',
    String requestedRevision = '',
    List<String> preservedHashes = const [],
  }) => WorkInstructionBrief(
    displayTitle: displayTitle,
    workingTitle: '작업용 제목',
    suggestedTitles: const ['제안 제목 A'],
    internalProjectId: 'proj_internal_sample',
    repositorySlug: 'repo-slug-sample',
    originalUserBrief: original,
    structuredUserInputs: const {'audience': '명시 입력'},
    aiAugmentedBrief: aiAugmented ?? '장별 실습과 체크리스트를 포함한 따라하기형 설명',
    aiAssumptions: const ['사용자는 스마트폰을 쓸 수 있다'],
    unansweredQuestions: const [],
    acceptedAiSuggestions: const ['실습 체크리스트'],
    rejectedAiSuggestions: const [],
    manualOnlyMode: manualOnly,
    titleSource: manualOnly ? 'manual' : 'ai_refined',
    userConfirmedAt: '2026-09-04T09:00:00+09:00',
    briefVersion: 1,
    creationMode: creationMode,
    sourceInstructionId: sourceInstructionId,
    sourceRevision: sourceRevision,
    requestedRevision: requestedRevision,
    ownerReviewDecisionRef: creationMode == 'revise_existing'
        ? 'owner_review_decisions/R1_changes_requested.json'
        : '',
    preservedArtifactHashes: preservedHashes,
    requestedChanges: requestedChanges,
    nextAllowedAction: creationMode == 'revise_existing'
        ? 'R2 revision only'
        : '',
  );

  static CommercialAppQualityProfile
  appProfile() => CommercialAppQualityProfile(
    targetUsers: '농작업 현장 작업자·관리자',
    realWorldProblem: '전기·농기계 안전 점검을 현장에서 누락 없이 수행',
    primaryUseEnvironment: '야외 농장·설비 현장 휴대 단말',
    coreUserJourneys: const ['점검시작-항목확인-결과저장', '위험항목재검토', '최근기록조회'],
    commercialGoal: '현장 안전 점검 상용 앱 후보',
    monetizationModel: 'B2B_subscription_deferred',
    offlineRequirement: 'required_for_core_journeys',
    loginRequirement: 'deferred_until_owner_review_pass',
    loginRequirementRationale: 'owner_device_review_before_auth_pii',
    privacyRiskLevel: 'medium',
    accessibilityTarget: 'WCAG_AA_mobile',
    localizationTarget: 'ko_primary_en_ready',
    requiredCapabilities: const [
      'checklist',
      'photo_note',
      'filter_sort',
      'offline_save',
    ],
    criticalUserJourneys: const ['점검시작-항목확인-결과저장'],
    domainSpecificCapabilities: const ['전기안전', '고위험작업'],
    dataLifecycle: 'create-read-update-archive',
    importExportShare: const ['share_summary_pdf_later'],
    recoveryBackup: 'local_db_restart_restore',
    notifications: 'local_reminder_optional',
    settingsHelpAbout: 'settings_help_about_without_debug',
    explicitlyOutOfScope: const ['play_store_submit', 'login_r1'],
    designDirection: 'field_safety_clarity',
    brandIdentity: 'sotongware_farm_safety_distinct',
    designTokens: 'color_type_space_component_v1',
    navigationModel: 'bottom_nav_home_list_record_settings',
    screenInventory: const [
      'home',
      'checklist',
      'detail',
      'compose',
      'result',
      'settings',
    ],
    screenPurpose: '각 화면 단일 목적',
    primaryAction: '점검 시작/저장',
    informationHierarchy: 'title>status>primaryCTA>secondary',
    reusableComponents: const ['status_card', 'filter_chip'],
    iconPolicy: 'domain_icons_not_generic_only',
    stateUxRequired: const [
      'empty',
      'loading',
      'error',
      'offline',
      'permission_denied',
    ],
    responsiveRequirements: 'small_phone_first',
    supportedTextScales: const ['1.0', '1.3', '1.5'],
    supportedOrientations: const ['portrait'],
    referenceLevel: 'sotongsamae_quality_characteristics_not_clone',
    prohibitedPatterns: const [
      'placeholder_only_screens',
      'internal_enum_slug_in_ui',
    ],
    performanceBudget: 'cold_start_under_3s_target',
    accessibilityChecks: const ['touch_target_48', 'contrast_aa'],
    visualEvidenceRequirements: const [
      'screenshot_home',
      'screenshot_checklist',
    ],
    deviceMatrix: const ['android_phone_api26+'],
    testMatrix: const ['unit', 'widget', 'journey'],
    ownerReviewRequired: true,
    independentReviewRequired: true,
    externalTesterReviewRequired: true,
    severityPolicy:
        'BLOCKER=0;HIGH=0;required_auto_checks_pass;human_review_required_items_block_until_approved',
    releaseReadinessCriteria: const [
      'owner_ok',
      'independent_review',
      'no_blocker_high',
    ],
  );

  static CommercialEbookQualityProfile ebookProfile() =>
      CommercialEbookQualityProfile(
        standard: standard(
          audience: '50대 AI 초보 독자',
          problem: '전자책 제작 절차를 모름',
          outcome: '첫 전자책 초고를 완성',
        ),
        readerLevel: 'beginner_50s',
        readerOutcome: '첫 전자책 완성 자신감',
        paidValueVsFree: '실습·템플릿·검수 체크리스트',
        chapterOutline: const ['시작하기', '주제잡기', '집필', '편집', '출시준비'],
        targetLengthBasis: '주제 맞춤 80~120페이지',
        practiceAssets: const ['checklist', 'template', 'case'],
        factCheckPolicy: '숫자·사실은 출처 필수',
        plagiarismCopyrightPolicy: '표절/무단전재 금지',
        editorialStyle: '친근한 구어체',
        coverInteriorDesign: '모바일 가독 표지·내지',
        requiredFormats: const ['pdf', 'epub'],
        readabilityTargets: const ['phone', 'tablet'],
        previewSampleRequirements: const ['sample_chapter_pdf'],
        salesCopyRequirements: '독자혜택·판매문구',
        renderEvidenceRequirements: const [
          'page_render',
          'toc',
          'fonts',
          'links',
          'overflow',
          'empty_page',
          'metadata',
        ],
        rejectCriteria: const [
          'scrape_mashup',
          'unsourced_claims',
          'placeholder',
          'no_render_evidence',
        ],
      );

  static CommercialSiteQualityProfile siteProfile({
    String purpose = 'marketing_site',
  }) => CommercialSiteQualityProfile(
    standard: standard(
      audience: '산업자동화 잠재 고객',
      problem: '제작 서비스 문의 창구 부재',
      outcome: '서비스 이해 후 문의',
    ),
    sitePurpose: purpose,
    siteSubtype: purpose,
    requiredRoutes: const ['/', '/services', '/contact'],
    heroMessage: '실무 경험 기반 제작 서비스',
    primaryCtas: const ['문의하기', '포트폴리오'],
    realOffering: '산업자동화·앱·콘텐츠 제작 서비스',
    trustSignals: const ['실적', '프로세스', '연락처'],
    authPaymentsNeed: 'none_at_r1',
    responsiveBreakpoints: const ['360', '768', '1280'],
    designSystemBrand: 'sotongware_site_v1',
    stateUxRequired: const ['empty', 'loading', 'error'],
    seoRequirements: const ['title', 'meta', 'og'],
    performanceBudget: 'lcp_under_2_5s',
    securityPrivacyCookie: const ['https_only', 'cookie_notice'],
    analyticsConversion: const ['contact_submit'],
    browserEvidenceRequirements: const [
      'viewport_screenshots',
      'route_crawl',
      'lighthouse',
    ],
    rejectCriteria: const [
      'empty_cards',
      'fake_testimonials',
      'broken_routes',
      'no_browser_evidence',
    ],
  );

  static CommercialContentQualityProfile contentProfile(String workSubtype) =>
      CommercialContentQualityProfile(
        standard: standard(
          audience: '콘텐츠 시청자',
          problem: '짧은 시간에 핵심을 이해하기 어려움',
          outcome: '60초 내 핵심 이해와 CTA',
        ),
        contentSubtype: ContentSubtypeContract.requireWorkCommercialEnum(
          workSubtype,
        ),
        audience: '콘텐츠 시청자',
        messageEmotion: '신뢰·명확',
        strongHook: '첫 3초 핵심 혜택',
        storyScriptStructure: 'hook-info-cta',
        platformPurpose: 'shorts_or_feed',
        lengthResolutionAspectFps: '60s_1080x1920_30fps',
        audioVisualQuality: const ['no_clipping', 'clear_voice'],
        captionsReadability: const ['safe_area', 'timed'],
        thumbnailTitleDescriptionCta: const [
          'thumbnail',
          'title',
          'description',
          'cta',
        ],
        brandConsistency: 'sotongware_content',
        deliverableVariants: const ['original', 'distribution'],
        rightsClearance: const ['music', 'font', 'image'],
        platformExportSpecs: const ['youtube_shorts'],
        publishPromoPackage: const ['title', 'description', 'thumbnail'],
        derivativeReuse: const ['square_cut'],
        subtypeExtraCriteria: const ['cta_clear'],
        mediaEvidenceRequirements: const [
          'ffprobe',
          'loudness',
          'caption_check',
        ],
        rejectCriteria: const [
          'raw_ai_draft',
          'broken_captions',
          'no_rights',
          'no_media_evidence',
        ],
        humanCreativeReviewRequired: true,
      );

  static CommercialQualityAttachment forTrack(
    String artifactType, {
    String? contentSubtype,
    String? sitePurpose,
    WorkInstructionBrief? briefOverride,
  }) {
    final brief =
        briefOverride ??
        CommercialFixtures.brief(
          displayTitle: switch (ArtifactType.normalize(artifactType)) {
            ArtifactType.app => '농작업 안전 점검 앱',
            ArtifactType.ebook => '초보자를 위한 AI 전자책 만들기',
            ArtifactType.site || ArtifactType.promoSite => '산업자동화 제작 소개 사이트',
            ArtifactType.contents => '농촌 지원사업 60초 알림',
            _ => '상용 작업 표시 제목',
          },
          original: switch (ArtifactType.normalize(artifactType)) {
            ArtifactType.app => '농촌 작업 전에 안전항목을 점검하고 사진과 조치내용을 저장하는 앱',
            ArtifactType.ebook => '50대 초보자가 AI를 이용해 첫 전자책을 만드는 과정을 따라 하는 책',
            ArtifactType.site ||
            ArtifactType.promoSite => '산업자동화 경험과 제작 서비스를 소개하고 문의받는 회사 사이트',
            ArtifactType.contents => '농촌 지원사업을 60초 안에 설명하는 세로형 알림 영상',
            _ => '사용자가 직접 작성한 원문 브리프',
          },
        );
    final track = CommercialQualityAttachment.expectedTrack(artifactType);
    switch (track) {
      case 'app':
        return CommercialQualityAttachment(
          brief: brief,
          appQualityContractVersion: 1,
          appProfile: appProfile(),
        );
      case 'ebook':
        return CommercialQualityAttachment(
          brief: brief,
          ebookQualityContractVersion: 1,
          ebookProfile: ebookProfile(),
        );
      case 'site':
        return CommercialQualityAttachment(
          brief: brief,
          siteQualityContractVersion: 1,
          siteProfile: siteProfile(purpose: sitePurpose ?? 'marketing_site'),
        );
      case 'content':
        return CommercialQualityAttachment(
          brief: brief,
          contentQualityContractVersion: 1,
          contentProfile: contentProfile(
            contentSubtype ?? ContentSubtypeContract.shortsVideo,
          ),
        );
      default:
        return CommercialQualityAttachment(brief: brief);
    }
  }

  /// Merge commercial fields into an existing instruction JSON map.
  static Map<String, dynamic> mergeIntoInstruction(
    Map<String, dynamic> base, {
    String? artifactType,
    String? contentSubtype,
    String? sitePurpose,
    CommercialQualityAttachment? attachment,
  }) {
    final fromBase = '${base['artifactType'] ?? ''}'.trim();
    final artifact = (artifactType != null && artifactType.trim().isNotEmpty)
        ? artifactType.trim()
        : (fromBase.isNotEmpty ? fromBase : ArtifactType.ebook);
    final att =
        attachment ??
        forTrack(
          artifact,
          contentSubtype: contentSubtype,
          sitePurpose: sitePurpose,
        );
    final out = Map<String, dynamic>.from(base);
    out['schemaVersion'] = instructionSchemaVersionCurrent;
    out['artifactType'] = ArtifactType.normalize(artifact);
    if (contentSubtype != null && contentSubtype.isNotEmpty) {
      out['contentSubtype'] = ContentSubtypeContract.requireWorkCommercialEnum(
        contentSubtype,
      );
    }
    out.addAll(att.toInstructionJsonFields());
    out['externalPublished'] = false;
    return out;
  }
}
