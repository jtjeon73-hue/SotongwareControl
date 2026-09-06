/// Builds CommercialQualityAttachment from studio inputs (no fake evidence).
/// Profile fields are fabrication *requirements*, not completed-work claims.
library;

import '../models/business_planning.dart';
import '../models/commercial/commercial_depth_plan.dart';
import '../models/commercial/commercial_quality_attachment.dart';
import '../models/commercial/commercial_quality_standard.dart';
import '../models/commercial/commercial_track_profiles.dart';
import '../models/commercial/work_instruction_brief.dart';
import '../models/project_design_state.dart';
import '../data/concept_catalog.dart';
import '../data/concept_commercial_catalog.dart';
import 'content_subtype_contract.dart';

class CommercialStudioBuilder {
  const CommercialStudioBuilder();

  /// Human display title: never append artifact suffix twice.
  static String sanitizeDisplayTitle(String raw, String artifactType) {
    var t = raw.trim();
    if (t.isEmpty) return t;
    final a = ArtifactType.normalize(artifactType);
    switch (a) {
      case ArtifactType.app:
        while (RegExp(r'앱\s*앱$').hasMatch(t)) {
          t = t.replaceFirst(RegExp(r'\s*앱$'), '');
        }
      case ArtifactType.ebook:
        while (RegExp(r'전자책\s*전자책$').hasMatch(t)) {
          t = t.replaceFirst(RegExp(r'\s*전자책$'), '');
        }
      case ArtifactType.site:
      case ArtifactType.promoSite:
        while (RegExp(r'사이트\s*사이트$').hasMatch(t)) {
          t = t.replaceFirst(RegExp(r'\s*사이트$'), '');
        }
      case ArtifactType.contents:
        while (RegExp(r'콘텐츠\s*콘텐츠$').hasMatch(t)) {
          t = t.replaceFirst(RegExp(r'\s*콘텐츠$'), '');
        }
    }
    return t.trim();
  }

  CommercialQualityAttachment? tryBuild({
    required ProjectDesignState state,
    required BusinessPlanInput input,
    required String instructionId,
    required String projectId,
  }) {
    final artifact = ArtifactType.normalize(
      input.resolvedArtifactType.isEmpty
          ? (state.artifactType ?? '')
          : input.resolvedArtifactType,
    );
    if (artifact == ArtifactType.undecided) return null;

    final displayTitle = sanitizeDisplayTitle(
      state.displayTitle.trim().isNotEmpty ? state.displayTitle : input.topic,
      artifact,
    );
    if (displayTitle.isEmpty) return null;

    final original = state.originalUserBrief.trim().isNotEmpty
        ? state.originalUserBrief.trim()
        : _composeOriginalBrief(state, input);
    if (original.isEmpty && !state.manualOnlyMode) return null;

    final seedMeta = _selectedSeedMeta(state);
    final reasons = state.reasonsToPay.isNotEmpty
        ? state.reasonsToPay
        : (seedMeta?.reasonsToPay ?? const <String>[]);
    final uniqueValue = state.uniqueValue.trim().isNotEmpty
        ? state.uniqueValue.trim()
        : (seedMeta?.uniqueValue ?? input.desiredOutcome.trim());
    final problem = input.customerProblem.trim().isNotEmpty
        ? input.customerProblem.trim()
        : (seedMeta?.customerProblem ?? '');
    final outcome = input.desiredOutcome.trim().isNotEmpty
        ? input.desiredOutcome.trim()
        : (seedMeta?.promisedOutcome ?? '');

    if (problem.isEmpty || outcome.isEmpty) return null;
    if (reasons.isEmpty) return null;

    final structured = <String, dynamic>{
      'topic': input.topic.trim(),
      'targetCustomer': input.targetCustomer.trim(),
      'customerProblem': problem,
      'desiredOutcome': outcome,
      'experienceSkills': input.experienceSkills.trim(),
      'existingMaterials': input.existingMaterials.trim(),
      'expectedScale': input.expectedScale.trim(),
      'budgetEstimate': input.budgetEstimate.trim(),
      'salesPrice': input.salesPrice.trim(),
      'references': input.references.trim(),
      'constraints': input.constraints.trim(),
      'extraRequests': input.extraRequests.trim(),
      'notes': input.notes.trim(),
      'selectedAudiences': state.selectedAudiences,
      'selectedConceptIds': state.selectedConceptIds,
      'productionSelections': state.productionSelections,
      'uniqueValue': uniqueValue,
      'reasonsToPay': reasons,
      if (state.contentSubtype != null) 'contentSubtype': state.contentSubtype,
    };

    final brief = WorkInstructionBrief(
      displayTitle: displayTitle,
      workingTitle: state.workingTitle.trim().isNotEmpty
          ? state.workingTitle.trim()
          : displayTitle,
      suggestedTitles: state.suggestedTitles,
      internalProjectId: projectId,
      repositorySlug: _slugFrom(displayTitle, projectId),
      originalUserBrief: original,
      structuredUserInputs: structured,
      aiAugmentedBrief: state.manualOnlyMode
          ? ''
          : state.aiAugmentedBrief.trim(),
      aiAssumptions: List<String>.from(state.aiAssumptions),
      unansweredQuestions: List<String>.from(state.unansweredQuestions),
      acceptedAiSuggestions: List<String>.from(state.acceptedAiSuggestions),
      rejectedAiSuggestions: List<String>.from(state.rejectedAiSuggestions),
      manualOnlyMode: state.manualOnlyMode,
      titleSource: state.titleSource.isNotEmpty
          ? state.titleSource
          : (state.manualOnlyMode ? 'manual' : 'ai_refined'),
      userConfirmedAt: state.userConfirmedAt.isNotEmpty
          ? state.userConfirmedAt
          : DateTime.now().toUtc().toIso8601String(),
      briefVersion: 1,
      creationMode: state.creationMode.isEmpty
          ? 'new_product'
          : state.creationMode,
      sourceInstructionId: state.sourceInstructionId,
      sourceRevision: state.sourceRevision,
      requestedRevision: state.requestedRevision,
      ownerReviewDecisionRef: state.ownerReviewDecisionRef,
      preservedArtifactHashes: List<String>.from(state.preservedArtifactHashes),
      requestedChanges: List<String>.from(state.requestedChanges),
      nextAllowedAction: state.creationMode == 'revise_existing'
          ? 'R2 revision only'
          : '',
    );

    final standard = CommercialQualityStandard(
      targetAudience: input.targetCustomer.trim(),
      customerProblem: problem,
      promisedOutcome: outcome,
      uniqueValue: uniqueValue,
      reasonsToPay: reasons,
      commercialGoal: outcome,
      monetizationModel: input.revenueModel.trim().isNotEmpty
          ? input.revenueModel.trim()
          : (seedMeta?.monetizationModels.isNotEmpty == true
                ? seedMeta!.monetizationModels.first
                : 'one_time_or_subscription'),
      brandDirection: 'sotongware_brand_direction',
      referenceLevel: 'commercial_candidate_not_skeleton',
      localizationTarget: 'ko_primary',
      accessibilityTarget: 'readable_mobile',
      requiredDeliverables: _deliverables(artifact, state.contentSubtype),
      evidenceRequirements: const [
        'automated_checks',
        'real_artifact_evidence',
        'owner_review',
      ],
      humanReviewRequirements: const ['owner_review'],
      revisionPolicy: 'R_n_preserves_prior_artifacts',
      releaseReadinessCriteria: const [
        'human_ok',
        'blocker0',
        'high0',
        'external_publish_false',
      ],
      explicitlyOutOfScope: const [
        'external_publish_without_ok',
        'store_registration_without_ok',
      ],
      legalPrivacyCopyrightRisks: const ['privacy_and_copyright_review'],
    );

    final track = CommercialQualityAttachment.expectedTrack(artifact);
    switch (track) {
      case 'app':
        return CommercialQualityAttachment(
          brief: brief,
          appQualityContractVersion: CommercialAppQualityProfile.kSchemaVersion,
          appProfile: _appProfile(input, problem, outcome, uniqueValue),
        );
      case 'ebook':
        return CommercialQualityAttachment(
          brief: brief,
          ebookQualityContractVersion: 1,
          ebookProfile: CommercialEbookQualityProfile(
            standard: standard,
            readerLevel: 'beginner_friendly',
            readerOutcome: outcome,
            paidValueVsFree: reasons.join(' · '),
            chapterOutline: const ['시작', '핵심 실습', '점검', '마무리'],
            targetLengthBasis: '주제 맞춤 분량',
            practiceAssets: const ['checklist', 'template'],
            factCheckPolicy: '숫자·사실은 출처 필수',
            plagiarismCopyrightPolicy: '표절·무단전재 금지',
            editorialStyle: '친근한 구어체',
            coverInteriorDesign: '모바일 가독 표지·내지',
            requiredFormats: const ['pdf', 'epub'],
            readabilityTargets: const ['phone', 'tablet'],
            previewSampleRequirements: const ['sample_chapter'],
            salesCopyRequirements: '독자 혜택·판매 문구',
            renderEvidenceRequirements: const [
              'page_render',
              'toc',
              'fonts',
              'links',
              'overflow',
              'metadata',
            ],
            rejectCriteria: const [
              'placeholder',
              'unsourced_claims',
              'no_render_evidence',
            ],
          ),
        );
      case 'site':
        final purpose = _sitePurpose(state);
        return CommercialQualityAttachment(
          brief: brief,
          siteQualityContractVersion: 1,
          siteProfile: CommercialSiteQualityProfile(
            standard: standard,
            sitePurpose: purpose,
            siteSubtype: purpose,
            requiredRoutes: const ['/', '/about', '/contact'],
            heroMessage: displayTitle,
            primaryCtas: const ['문의하기', '자세히 보기'],
            realOffering: outcome,
            trustSignals: const ['실적', '연락처', '프로세스'],
            authPaymentsNeed: 'none_unless_required',
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
            ],
            rejectCriteria: const [
              'empty_cards',
              'broken_routes',
              'no_browser_evidence',
            ],
          ),
        );
      case 'content':
        final rawSubtype = (state.contentSubtype ?? input.contentSubtype)
            .trim();
        final subtype = ContentSubtypeContract.requireWorkCommercialEnum(
          rawSubtype,
        );
        return CommercialQualityAttachment(
          brief: brief,
          contentQualityContractVersion: 1,
          contentProfile: CommercialContentQualityProfile(
            standard: standard,
            contentSubtype: subtype,
            audience: input.targetCustomer.trim(),
            messageEmotion: '명확·신뢰',
            strongHook: displayTitle,
            storyScriptStructure: 'hook-info-cta',
            platformPurpose: 'feed_or_shorts',
            lengthResolutionAspectFps: '60s_1080x1920_30fps',
            audioVisualQuality: const ['clear_voice', 'no_clipping'],
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
          ),
        );
      default:
        return null;
    }
  }

  CommercialAppQualityProfile _appProfile(
    BusinessPlanInput input,
    String problem,
    String outcome,
    String uniqueValue,
  ) {
    final users = input.targetCustomer.trim();
    final depth = CommercialDepthPlan.defaultsForStandardApp(
      appPurpose: problem.trim().isNotEmpty
          ? problem.trim()
          : (outcome.trim().isNotEmpty
                ? outcome.trim()
                : 'declare_before_implementation'),
      targetUsers: users,
    );
    return CommercialAppQualityProfile(
      schemaVersion: CommercialAppQualityProfile.kSchemaVersion,
      targetUsers: users,
      realWorldProblem: problem,
      primaryUseEnvironment: 'mobile_primary',
      coreUserJourneys: const ['핵심여정-시작-저장-확인'],
      commercialGoal: outcome,
      monetizationModel: input.revenueModel.trim().isNotEmpty
          ? input.revenueModel.trim()
          : 'deferred_until_owner_review',
      offlineRequirement: 'required_for_core_journeys',
      loginRequirement: 'deferred_until_owner_review_pass',
      loginRequirementRationale: 'owner_device_review_before_auth_pii',
      privacyRiskLevel: 'medium',
      accessibilityTarget: 'WCAG_AA_mobile',
      localizationTarget: 'ko_primary',
      requiredCapabilities: const ['core_flow', 'save', 'review'],
      criticalUserJourneys: const ['핵심여정-시작-저장-확인'],
      domainSpecificCapabilities: const ['domain_checklist'],
      dataLifecycle: 'create-read-update-archive',
      importExportShare: const ['export_later'],
      recoveryBackup: 'local_restore',
      notifications: 'optional_local',
      settingsHelpAbout: 'settings_help_about_without_debug',
      explicitlyOutOfScope: const [
        'play_store_submit',
        'external_publish_without_ok',
      ],
      designDirection: 'clarity_first',
      brandIdentity: uniqueValue,
      designTokens: 'color_type_space_v1',
      navigationModel: 'bottom_or_simple_nav',
      screenInventory: const ['home', 'main', 'detail', 'settings'],
      screenPurpose: '각 화면 단일 목적',
      primaryAction: '핵심 작업 시작/저장',
      informationHierarchy: 'title>status>primaryCTA',
      reusableComponents: const ['status_card', 'primary_button'],
      iconPolicy: 'domain_icons_preferred',
      stateUxRequired: const [
        'empty',
        'loading',
        'error',
        'offline',
        'permission_denied',
      ],
      responsiveRequirements:
          'galaxy_widths_320_360_390_412_430;textScale_2_0;no_one_glyph_wrap;no_overflow_clip;touch_target_48',
      supportedTextScales: const ['1.0', '1.3', '1.5', '2.0'],
      supportedOrientations: const ['portrait'],
      referenceLevel: 'commercial_candidate_not_clone',
      prohibitedPatterns: const [
        'placeholder_only_screens',
        'internal_enum_slug_in_ui',
        'listtile_trailing_title_squeeze',
        'one_glyph_vertical_wrap',
        'shallow_domain_templates',
      ],
      performanceBudget: 'cold_start_under_3s_target',
      accessibilityChecks: const ['touch_target_48', 'contrast_aa'],
      visualEvidenceRequirements: const ['screenshot_home', 'screenshot_main'],
      deviceMatrix: const ['android_phone_api26+'],
      testMatrix: const ['unit', 'widget', 'journey'],
      ownerReviewRequired: true,
      independentReviewRequired: true,
      externalTesterReviewRequired: true,
      severityPolicy:
          'BLOCKER=0;HIGH=0;required_auto_checks_pass;human_review_required',
      releaseReadinessCriteria: const [
        'owner_ok',
        'independent_review',
        'no_blocker_high',
      ],
      commercialDepthPlan: depth,
    );
  }

  String _composeOriginalBrief(
    ProjectDesignState state,
    BusinessPlanInput input,
  ) {
    final parts = <String>[
      if (input.topic.trim().isNotEmpty) input.topic.trim(),
      if (input.customerProblem.trim().isNotEmpty) input.customerProblem.trim(),
      if (input.desiredOutcome.trim().isNotEmpty) input.desiredOutcome.trim(),
      if (input.targetCustomer.trim().isNotEmpty)
        '대상: ${input.targetCustomer.trim()}',
    ];
    return parts.join('\n');
  }

  ConceptCommercialMeta? _selectedSeedMeta(ProjectDesignState state) {
    for (final id in state.selectedConceptIds) {
      final seedId = ConceptCommercialCatalog.seedIdFromCandidateId(id);
      try {
        return ConceptCommercialCatalog.requireForSeedId(seedId);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  List<String> _deliverables(String artifact, String? subtype) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.app:
        return const ['release_apk', 'owner_review_package'];
      case ArtifactType.ebook:
        return const ['pdf', 'epub', 'preview'];
      case ArtifactType.site:
      case ArtifactType.promoSite:
        return const ['responsive_site', 'contact_flow'];
      case ArtifactType.contents:
        return const ['media_deliverable', 'thumbnail', 'captions'];
      default:
        return const ['primary_deliverable'];
    }
  }

  String _sitePurpose(ProjectDesignState state) {
    final fromProd =
        state.productionSelections['site_kind'] ??
        state.productionSelections['siteKind'] ??
        const [];
    if (fromProd.isNotEmpty) return fromProd.first;
    return 'marketing_site';
  }

  String _slugFrom(String title, String projectId) {
    final cleaned = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9가-힣]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (cleaned.length >= 4) return cleaned;
    return 'proj-$projectId';
  }
}
