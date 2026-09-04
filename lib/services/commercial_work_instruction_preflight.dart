/// Local Commercial Work Instruction Preflight — mirrors Work inbox enforce.
/// Does not invent fake defaults. Does not weaken Work gates.
library;

import '../models/artifact_type.dart';
import '../models/commercial/commercial_quality_attachment.dart';
import '../models/commercial/commercial_quality_standard.dart';
import '../models/commercial/work_instruction_brief.dart';
import '../models/instruction_contract.dart';
import 'content_subtype_contract.dart';

enum CommercialIssueSeverity { error, warning, info }

class CommercialPreflightIssue {
  const CommercialPreflightIssue({
    required this.code,
    required this.fieldPath,
    required this.severity,
    required this.userMessageKo,
    required this.developerDetail,
    this.studioStepHint = '',
  });

  final String code;
  final String fieldPath;
  final CommercialIssueSeverity severity;
  final String userMessageKo;
  final String developerDetail;
  final String studioStepHint;
}

class CommercialPreflightResult {
  const CommercialPreflightResult({
    required this.ok,
    required this.issues,
    required this.missingFields,
    required this.track,
    required this.subtype,
    required this.contractVersion,
    this.code = '',
  });

  final bool ok;
  final String code;
  final List<CommercialPreflightIssue> issues;
  final List<String> missingFields;
  final String track;
  final String subtype;
  final int contractVersion;

  List<CommercialPreflightIssue> get errors =>
      issues.where((i) => i.severity == CommercialIssueSeverity.error).toList();
}

class CommercialWorkInstructionPreflight {
  CommercialWorkInstructionPreflight._();

  /// Evaluate instruction JSON as Work DeliverStartJobToInbox would (enforce all).
  static CommercialPreflightResult evaluate(
    Map<String, dynamic> instructionJson, {
    bool enforceBrief = true,
    bool enforceTrackProfiles = true,
  }) {
    final issues = <CommercialPreflightIssue>[];
    final missing = <String>[];
    final schema = '${instructionJson['schemaVersion'] ?? ''}';
    final artifact = ArtifactType.normalize(
      '${instructionJson['artifactType'] ?? ''}',
    );
    final track = CommercialQualityAttachment.expectedTrack(artifact);
    final attachment = CommercialQualityAttachment.fromInstructionJson(
      instructionJson,
    );
    var subtype = '';
    if (track == 'content') {
      final fromProfile = attachment.contentProfile.contentSubtype.trim();
      final raw = fromProfile.isNotEmpty
          ? fromProfile
          : '${instructionJson['contentSubtype'] ?? ''}';
      subtype = raw;
    } else if (track == 'site') {
      subtype = attachment.siteProfile.sitePurpose.isNotEmpty
          ? attachment.siteProfile.sitePurpose
          : attachment.siteProfile.siteSubtype;
    }

    if (schema == '1.0') {
      // Legacy exempt — do not disguise as 1.1.
      return CommercialPreflightResult(
        ok: true,
        code: 'LEGACY_SCHEMA_1_0',
        issues: const [
          CommercialPreflightIssue(
            code: 'CAQP_LEGACY_EXEMPT',
            fieldPath: 'schemaVersion',
            severity: CommercialIssueSeverity.info,
            userMessageKo:
                'schema 1.0은 상용 프로필 면제 경로입니다. 신규는 1.1+brief+profile이 필요합니다.',
            developerDetail: 'legacy exempt; commercial not required',
          ),
        ],
        missingFields: const [],
        track: track,
        subtype: subtype,
        contractVersion: 0,
      );
    }

    if (schema != instructionSchemaVersionCurrent && schema.isNotEmpty) {
      issues.add(
        CommercialPreflightIssue(
          code: 'CQ_BAD_SCHEMA',
          fieldPath: 'schemaVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '지원하지 않는 schemaVersion입니다.',
          developerDetail: 'expected 1.1 or 1.0, got $schema',
        ),
      );
    }

    // Reject 1.1 disguised without contract versions.
    if (schema == instructionSchemaVersionCurrent && enforceTrackProfiles) {
      _checkLegacyDisguise(
        issues: issues,
        missing: missing,
        track: track,
        attachment: attachment,
      );
    }

    if (enforceBrief) {
      _validateBrief(
        issues: issues,
        missing: missing,
        brief: attachment.brief,
        briefContractVersion: attachment.briefContractVersion,
        requirePresent: schema == instructionSchemaVersionCurrent,
      );
    }

    if (enforceTrackProfiles && track.isNotEmpty) {
      switch (track) {
        case 'app':
          _validateApp(issues, missing, attachment);
        case 'ebook':
          _validateEbook(issues, missing, attachment);
        case 'site':
          _validateSite(issues, missing, attachment);
        case 'content':
          _validateContent(issues, missing, attachment, instructionJson);
      }
    }

    // Display title artifact suffix duplication (Control safety).
    final title = attachment.brief.displayTitle.trim();
    if (title.isNotEmpty && _hasDuplicatedArtifactSuffix(title, artifact)) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CQ_DISPLAY_TITLE_ARTIFACT_SUFFIX',
          fieldPath: 'workInstructionBrief.displayTitle',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '표시 제목에 제작 형태 접미사가 중복되어 있습니다.',
          developerDetail: 'e.g. "... 앱 앱" / "... 전자책 전자책" forbidden',
          studioStepHint: '제목 확인',
        ),
      );
    }

    // External publish must stay false if present.
    final external = instructionJson['externalPublished'];
    if (external == true) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CQ_EXTERNAL_PUBLISH_FORBIDDEN',
          fieldPath: 'externalPublished',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '사용자 승인 전 외부 공개는 허용되지 않습니다.',
          developerDetail: 'externalPublished must not be true',
        ),
      );
    }

    final errors = issues
        .where((i) => i.severity == CommercialIssueSeverity.error)
        .toList();
    final primary = errors.isEmpty ? '' : errors.first.code;
    final contractVersion = switch (track) {
      'app' => attachment.appQualityContractVersion ?? 0,
      'ebook' => attachment.ebookQualityContractVersion ?? 0,
      'site' => attachment.siteQualityContractVersion ?? 0,
      'content' => attachment.contentQualityContractVersion ?? 0,
      _ => 0,
    };

    return CommercialPreflightResult(
      ok: errors.isEmpty,
      code: primary,
      issues: issues,
      missingFields: missing.toSet().toList()..sort(),
      track: track,
      subtype: subtype,
      contractVersion: contractVersion,
    );
  }

  static bool isSchema11(Map<String, dynamic> json) =>
      '${json['schemaVersion'] ?? ''}' == instructionSchemaVersionCurrent;

  static void _checkLegacyDisguise({
    required List<CommercialPreflightIssue> issues,
    required List<String> missing,
    required String track,
    required CommercialQualityAttachment attachment,
  }) {
    void disguise(String code, String path, String ko) {
      issues.add(
        CommercialPreflightIssue(
          code: code,
          fieldPath: path,
          severity: CommercialIssueSeverity.error,
          userMessageKo: ko,
          developerDetail:
              'schemaVersion 1.1 cannot use legacy exemption without profile',
          studioStepHint: '상용 품질 입력',
        ),
      );
      missing.add(path);
    }

    switch (track) {
      case 'app':
        if ((attachment.appQualityContractVersion ?? 0) < 1 ||
            !attachment.appProfile.present) {
          disguise(
            'CAQP_LEGACY_DISGUISE',
            'appQualityContractVersion',
            '앱 신규 작업은 appQualityContractVersion과 commercialAppQualityProfile이 필요합니다.',
          );
        }
      case 'ebook':
        if ((attachment.ebookQualityContractVersion ?? 0) < 1 ||
            !attachment.ebookProfile.present) {
          disguise(
            'CEQP_LEGACY_DISGUISE',
            'ebookQualityContractVersion',
            '전자책 신규 작업은 ebookQualityContractVersion과 commercialEbookQualityProfile이 필요합니다.',
          );
        }
      case 'site':
        if ((attachment.siteQualityContractVersion ?? 0) < 1 ||
            !attachment.siteProfile.present) {
          disguise(
            'CSQP_LEGACY_DISGUISE',
            'siteQualityContractVersion',
            '사이트 신규 작업은 siteQualityContractVersion과 commercialSiteQualityProfile이 필요합니다.',
          );
        }
      case 'content':
        if ((attachment.contentQualityContractVersion ?? 0) < 1 ||
            !attachment.contentProfile.present) {
          disguise(
            'CCQP_LEGACY_DISGUISE',
            'contentQualityContractVersion',
            '콘텐츠 신규 작업은 contentQualityContractVersion과 commercialContentQualityProfile이 필요합니다.',
          );
        }
    }

    if (!attachment.brief.present || attachment.briefContractVersion < 1) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_LEGACY_DISGUISE',
          fieldPath: 'briefContractVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo:
              '신규 schema 1.1 작업은 briefContractVersion과 workInstructionBrief가 필요합니다.',
          developerDetail: 'brief required for schema 1.1',
          studioStepHint: '원문·제목 입력',
        ),
      );
      missing.add('briefContractVersion');
    }
  }

  static void _validateBrief({
    required List<CommercialPreflightIssue> issues,
    required List<String> missing,
    required WorkInstructionBrief brief,
    required int briefContractVersion,
    required bool requirePresent,
  }) {
    if (!brief.present) {
      if (requirePresent) {
        issues.add(
          const CommercialPreflightIssue(
            code: 'WIBC_REQUIRED',
            fieldPath: 'instruction.workInstructionBrief',
            severity: CommercialIssueSeverity.error,
            userMessageKo: '작업지시서 원문·제목 계약(brief)이 필요합니다.',
            developerDetail: 'workInstructionBrief v1 required',
            studioStepHint: '원문·제목 입력',
          ),
        );
        missing.add('workInstructionBrief');
      }
      return;
    }
    if (brief.schemaVersion != WorkInstructionBrief.kSchemaVersion ||
        briefContractVersion != WorkInstructionBrief.kBriefContractVersion) {
      issues.add(
        CommercialPreflightIssue(
          code: 'WIBC_BAD_VERSION',
          fieldPath: 'workInstructionBrief.schemaVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo: 'brief 버전은 1이어야 합니다.',
          developerDetail:
              'brief.schemaVersion=${brief.schemaVersion} briefContractVersion=$briefContractVersion',
        ),
      );
    }
    if (brief.displayTitle.trim().isEmpty) {
      _req(
        issues,
        missing,
        'WIBC_DISPLAY_TITLE_REQUIRED',
        'workInstructionBrief.displayTitle',
        '표시 제목을 입력하세요.',
      );
    } else if (_looksLikeInternalId(brief.displayTitle) ||
        brief.displayTitle == brief.internalProjectId ||
        (brief.repositorySlug.isNotEmpty &&
            brief.displayTitle == brief.repositorySlug)) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_DISPLAY_TITLE_IS_INTERNAL_ID',
          fieldPath: 'workInstructionBrief.displayTitle',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '표시 제목은 내부 ID/슬러그와 달라야 합니다.',
          developerDetail: 'displayTitle must be human-friendly',
          studioStepHint: '제목 확인',
        ),
      );
    }
    if (_looksLikePlaceholder(brief.displayTitle) ||
        _looksLikePlaceholder(brief.originalUserBrief)) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_PLACEHOLDER_FORBIDDEN',
          fieldPath: 'workInstructionBrief',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '예시/placeholder 문구는 실제 값으로 저장할 수 없습니다.',
          developerDetail: 'placeholder/example forbidden',
        ),
      );
    }
    final structuredEmpty = brief.structuredUserInputs.isEmpty;
    if (brief.originalUserBrief.trim().isEmpty &&
        !brief.manualOnlyMode &&
        structuredEmpty) {
      _req(
        issues,
        missing,
        'WIBC_ORIGINAL_BRIEF_REQUIRED',
        'workInstructionBrief.originalUserBrief',
        '사용자 원문을 보존해야 합니다.',
      );
    }
    if (brief.manualOnlyMode &&
        (brief.displayTitle.trim().isEmpty ||
            (brief.originalUserBrief.trim().isEmpty && structuredEmpty))) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_MANUAL_ONLY_INCOMPLETE',
          fieldPath: 'workInstructionBrief.manualOnlyMode',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '수동 작성 모드에서도 제목과 원문(또는 구조화 입력)이 필요합니다.',
          developerDetail: 'manualOnlyMode incomplete',
        ),
      );
    }
    if (brief.titleSource.isNotEmpty &&
        brief.titleSource != 'manual' &&
        brief.titleSource != 'ai_suggested' &&
        brief.titleSource != 'ai_refined') {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_BAD_TITLE_SOURCE',
          fieldPath: 'workInstructionBrief.titleSource',
          severity: CommercialIssueSeverity.error,
          userMessageKo: 'titleSource가 올바르지 않습니다.',
          developerDetail: 'manual|ai_suggested|ai_refined',
        ),
      );
    }
    if (brief.titleSource == 'manual' &&
        brief.userConfirmedAt.isEmpty &&
        brief.suggestedTitles.isNotEmpty) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_MANUAL_TITLE_UNCONFIRMED',
          fieldPath: 'workInstructionBrief.userConfirmedAt',
          severity: CommercialIssueSeverity.warning,
          userMessageKo: 'AI 제안이 있을 때 수동 제목은 확인 시각이 필요합니다.',
          developerDetail: 'userConfirmedAt expected',
        ),
      );
    }
    final mode = brief.creationMode.isEmpty
        ? 'new_product'
        : brief.creationMode;
    if (mode != 'new_product' && mode != 'revise_existing') {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_BAD_CREATION_MODE',
          fieldPath: 'workInstructionBrief.creationMode',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '생성 모드가 올바르지 않습니다.',
          developerDetail: 'new_product|revise_existing',
        ),
      );
    }
    if (mode == 'revise_existing') {
      if (brief.sourceInstructionId.trim().isEmpty) {
        _req(
          issues,
          missing,
          'WIBC_REVISION_SOURCE_REQUIRED',
          'workInstructionBrief.sourceInstructionId',
          '보완 작업은 원본 instructionId가 필요합니다.',
        );
      }
      if (brief.requestedChanges.isEmpty) {
        _req(
          issues,
          missing,
          'WIBC_REVISION_CHANGES_REQUIRED',
          'workInstructionBrief.requestedChanges',
          '보완 요청 내용이 필요합니다.',
        );
      }
      if (brief.preservedArtifactHashes.isEmpty) {
        _req(
          issues,
          missing,
          'WIBC_REVISION_HASHES_REQUIRED',
          'workInstructionBrief.preservedArtifactHashes',
          '보존할 결과물 해시가 필요합니다.',
        );
      }
      if (brief.sourceRevision.trim().isEmpty ||
          brief.requestedRevision.trim().isEmpty) {
        _req(
          issues,
          missing,
          'WIBC_REVISION_REVISIONS_REQUIRED',
          'workInstructionBrief.sourceRevision',
          'sourceRevision과 requestedRevision이 필요합니다.',
        );
      }
    }
    if (brief.aiAugmentedBrief.isNotEmpty &&
        brief.aiAugmentedBrief == brief.originalUserBrief &&
        brief.aiAssumptions.isEmpty &&
        !brief.manualOnlyMode) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'WIBC_AI_MUST_BE_SEPARATE',
          fieldPath: 'workInstructionBrief.aiAugmentedBrief',
          severity: CommercialIssueSeverity.warning,
          userMessageKo: 'AI 보완문은 원문과 분리하거나 추정(assumption)을 명시해야 합니다.',
          developerDetail: 'aiAugmentedBrief == originalUserBrief',
        ),
      );
    }
  }

  static void _validateApp(
    List<CommercialPreflightIssue> issues,
    List<String> missing,
    CommercialQualityAttachment a,
  ) {
    if (!a.appProfile.present) {
      _req(
        issues,
        missing,
        'CAQP_REQUIRED_FOR_NEW_APP',
        'commercialAppQualityProfile',
        '앱 상용 품질 프로필이 필요합니다.',
      );
      return;
    }
    final p = a.appProfile;
    if (p.schemaVersion < 1) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CAQP_INVALID_SCHEMA_VERSION',
          fieldPath: 'commercialAppQualityProfile.schemaVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '앱 프로필 버전이 올바르지 않습니다.',
          developerDetail: 'schemaVersion must be >= 1',
        ),
      );
    }
    void need(String code, String path, String v) {
      if (v.trim().isEmpty) {
        _req(issues, missing, code, path, '필수 앱 품질 항목이 비어 있습니다.');
      }
    }

    void needList(String code, String path, List<String> v) {
      if (v.isEmpty) {
        _req(issues, missing, code, path, '필수 앱 품질 목록이 비어 있습니다.');
      }
    }

    need(
      'CAQP_MISSING_TARGET_USERS',
      'commercialAppQualityProfile.targetUsers',
      p.targetUsers,
    );
    need(
      'CAQP_MISSING_REAL_WORLD_PROBLEM',
      'commercialAppQualityProfile.realWorldProblem',
      p.realWorldProblem,
    );
    need(
      'CAQP_MISSING_USE_ENV',
      'commercialAppQualityProfile.primaryUseEnvironment',
      p.primaryUseEnvironment,
    );
    needList(
      'CAQP_MISSING_CORE_JOURNEYS',
      'commercialAppQualityProfile.coreUserJourneys',
      p.coreUserJourneys,
    );
    need(
      'CAQP_MISSING_COMMERCIAL_GOAL',
      'commercialAppQualityProfile.commercialGoal',
      p.commercialGoal,
    );
    needList(
      'CAQP_MISSING_CRITICAL_JOURNEYS',
      'commercialAppQualityProfile.criticalUserJourneys',
      p.criticalUserJourneys,
    );
    needList(
      'CAQP_MISSING_CAPABILITIES',
      'commercialAppQualityProfile.requiredCapabilities',
      p.requiredCapabilities,
    );
    needList(
      'CAQP_MISSING_SCREEN_INVENTORY',
      'commercialAppQualityProfile.screenInventory',
      p.screenInventory,
    );
    need(
      'CAQP_MISSING_DESIGN_DIRECTION',
      'commercialAppQualityProfile.designDirection',
      p.designDirection,
    );
    need(
      'CAQP_MISSING_BRAND',
      'commercialAppQualityProfile.brandIdentity',
      p.brandIdentity,
    );
    need(
      'CAQP_MISSING_NAVIGATION',
      'commercialAppQualityProfile.navigationModel',
      p.navigationModel,
    );
    needList(
      'CAQP_MISSING_STATE_UX',
      'commercialAppQualityProfile.stateUxRequired',
      p.stateUxRequired,
    );
    need(
      'CAQP_MISSING_SEVERITY_POLICY',
      'commercialAppQualityProfile.severityPolicy',
      p.severityPolicy,
    );
    needList(
      'CAQP_MISSING_RELEASE_CRITERIA',
      'commercialAppQualityProfile.releaseReadinessCriteria',
      p.releaseReadinessCriteria,
    );
    need(
      'CAQP_MISSING_LOGIN_REQUIREMENT',
      'commercialAppQualityProfile.loginRequirement',
      p.loginRequirement,
    );
    if (!p.ownerReviewRequired) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CAQP_HUMAN_REVIEW_REQUIRED',
          fieldPath: 'commercialAppQualityProfile.ownerReviewRequired',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '앱은 사용자(owner) 검토가 필수입니다.',
          developerDetail: 'ownerReviewRequired must be true',
        ),
      );
    }
  }

  static void _validateEbook(
    List<CommercialPreflightIssue> issues,
    List<String> missing,
    CommercialQualityAttachment a,
  ) {
    if (!a.ebookProfile.present) {
      _req(
        issues,
        missing,
        'CEQP_REQUIRED',
        'commercialEbookQualityProfile',
        '전자책 상용 품질 프로필이 필요합니다.',
      );
      return;
    }
    final p = a.ebookProfile;
    if (p.schemaVersion != 1) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CEQP_BAD_VERSION',
          fieldPath: 'commercialEbookQualityProfile.schemaVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '전자책 프로필 버전은 1이어야 합니다.',
          developerDetail: 'schemaVersion must be 1',
        ),
      );
    }
    _validateStandard(
      issues,
      missing,
      p.standard,
      'commercialEbookQualityProfile.standard',
    );
    void need(String path, String v) {
      if (v.trim().isEmpty) {
        _req(issues, missing, 'CEQP_REQUIRED', path, '전자책 필수 항목이 비어 있습니다.');
      }
    }

    void needList(String path, List<String> v) {
      if (v.isEmpty) {
        _req(issues, missing, 'CEQP_REQUIRED', path, '전자책 필수 목록이 비어 있습니다.');
      }
    }

    need('commercialEbookQualityProfile.readerLevel', p.readerLevel);
    need('commercialEbookQualityProfile.readerOutcome', p.readerOutcome);
    need('commercialEbookQualityProfile.paidValueVsFree', p.paidValueVsFree);
    needList('commercialEbookQualityProfile.chapterOutline', p.chapterOutline);
    need(
      'commercialEbookQualityProfile.targetLengthBasis',
      p.targetLengthBasis,
    );
    needList('commercialEbookQualityProfile.practiceAssets', p.practiceAssets);
    need('commercialEbookQualityProfile.factCheckPolicy', p.factCheckPolicy);
    need(
      'commercialEbookQualityProfile.plagiarismCopyrightPolicy',
      p.plagiarismCopyrightPolicy,
    );
    need('commercialEbookQualityProfile.editorialStyle', p.editorialStyle);
    need(
      'commercialEbookQualityProfile.coverInteriorDesign',
      p.coverInteriorDesign,
    );
    needList(
      'commercialEbookQualityProfile.requiredFormats',
      p.requiredFormats,
    );
    needList(
      'commercialEbookQualityProfile.readabilityTargets',
      p.readabilityTargets,
    );
    needList(
      'commercialEbookQualityProfile.previewSampleRequirements',
      p.previewSampleRequirements,
    );
    need(
      'commercialEbookQualityProfile.salesCopyRequirements',
      p.salesCopyRequirements,
    );
    needList(
      'commercialEbookQualityProfile.renderEvidenceRequirements',
      p.renderEvidenceRequirements,
    );
    needList('commercialEbookQualityProfile.rejectCriteria', p.rejectCriteria);
  }

  static void _validateSite(
    List<CommercialPreflightIssue> issues,
    List<String> missing,
    CommercialQualityAttachment a,
  ) {
    if (!a.siteProfile.present) {
      _req(
        issues,
        missing,
        'CSQP_REQUIRED',
        'commercialSiteQualityProfile',
        '사이트 상용 품질 프로필이 필요합니다.',
      );
      return;
    }
    final p = a.siteProfile;
    if (p.schemaVersion != 1) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CSQP_BAD_VERSION',
          fieldPath: 'commercialSiteQualityProfile.schemaVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '사이트 프로필 버전은 1이어야 합니다.',
          developerDetail: 'schemaVersion must be 1',
        ),
      );
    }
    _validateStandard(
      issues,
      missing,
      p.standard,
      'commercialSiteQualityProfile.standard',
    );
    void need(String path, String v) {
      if (v.trim().isEmpty) {
        _req(issues, missing, 'CSQP_REQUIRED', path, '사이트 필수 항목이 비어 있습니다.');
      }
    }

    void needList(String path, List<String> v) {
      if (v.isEmpty) {
        _req(issues, missing, 'CSQP_REQUIRED', path, '사이트 필수 목록이 비어 있습니다.');
      }
    }

    need('commercialSiteQualityProfile.sitePurpose', p.sitePurpose);
    needList('commercialSiteQualityProfile.requiredRoutes', p.requiredRoutes);
    need('commercialSiteQualityProfile.heroMessage', p.heroMessage);
    needList('commercialSiteQualityProfile.primaryCtas', p.primaryCtas);
    need('commercialSiteQualityProfile.realOffering', p.realOffering);
    needList('commercialSiteQualityProfile.trustSignals', p.trustSignals);
    need('commercialSiteQualityProfile.authPaymentsNeed', p.authPaymentsNeed);
    needList(
      'commercialSiteQualityProfile.responsiveBreakpoints',
      p.responsiveBreakpoints,
    );
    need('commercialSiteQualityProfile.designSystemBrand', p.designSystemBrand);
    needList('commercialSiteQualityProfile.stateUxRequired', p.stateUxRequired);
    needList('commercialSiteQualityProfile.seoRequirements', p.seoRequirements);
    need('commercialSiteQualityProfile.performanceBudget', p.performanceBudget);
    needList(
      'commercialSiteQualityProfile.securityPrivacyCookie',
      p.securityPrivacyCookie,
    );
    needList(
      'commercialSiteQualityProfile.browserEvidenceRequirements',
      p.browserEvidenceRequirements,
    );
    needList('commercialSiteQualityProfile.rejectCriteria', p.rejectCriteria);
  }

  static void _validateContent(
    List<CommercialPreflightIssue> issues,
    List<String> missing,
    CommercialQualityAttachment a,
    Map<String, dynamic> instructionJson,
  ) {
    if (!a.contentProfile.present) {
      _req(
        issues,
        missing,
        'CCQP_REQUIRED',
        'commercialContentQualityProfile',
        '콘텐츠 상용 품질 프로필이 필요합니다.',
      );
      return;
    }
    final p = a.contentProfile;
    if (p.schemaVersion != 1) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CCQP_BAD_VERSION',
          fieldPath: 'commercialContentQualityProfile.schemaVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '콘텐츠 프로필 버전은 1이어야 합니다.',
          developerDetail: 'schemaVersion must be 1',
        ),
      );
    }
    _validateStandard(
      issues,
      missing,
      p.standard,
      'commercialContentQualityProfile.standard',
    );
    if (p.contentSubtype.trim().isEmpty) {
      _req(
        issues,
        missing,
        'CCQP_REQUIRED',
        'commercialContentQualityProfile.contentSubtype',
        '콘텐츠 하위유형이 필요합니다.',
      );
    } else if (!ContentSubtypeContract.isKnown(p.contentSubtype)) {
      issues.add(
        CommercialPreflightIssue(
          code: 'CCQP_BAD_SUBTYPE',
          fieldPath: 'commercialContentQualityProfile.contentSubtype',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '알 수 없는 콘텐츠 하위유형입니다.',
          developerDetail: 'unknown subtype=${p.contentSubtype}',
        ),
      );
    }
    void need(String path, String v) {
      if (v.trim().isEmpty) {
        _req(issues, missing, 'CCQP_REQUIRED', path, '콘텐츠 필수 항목이 비어 있습니다.');
      }
    }

    void needList(String path, List<String> v) {
      if (v.isEmpty) {
        _req(issues, missing, 'CCQP_REQUIRED', path, '콘텐츠 필수 목록이 비어 있습니다.');
      }
    }

    need('commercialContentQualityProfile.audience', p.audience);
    need('commercialContentQualityProfile.messageEmotion', p.messageEmotion);
    need('commercialContentQualityProfile.strongHook', p.strongHook);
    need(
      'commercialContentQualityProfile.storyScriptStructure',
      p.storyScriptStructure,
    );
    need('commercialContentQualityProfile.platformPurpose', p.platformPurpose);
    need(
      'commercialContentQualityProfile.lengthResolutionAspectFps',
      p.lengthResolutionAspectFps,
    );
    needList(
      'commercialContentQualityProfile.audioVisualQuality',
      p.audioVisualQuality,
    );
    needList(
      'commercialContentQualityProfile.thumbnailTitleDescriptionCta',
      p.thumbnailTitleDescriptionCta,
    );
    need(
      'commercialContentQualityProfile.brandConsistency',
      p.brandConsistency,
    );
    needList(
      'commercialContentQualityProfile.deliverableVariants',
      p.deliverableVariants,
    );
    needList(
      'commercialContentQualityProfile.rightsClearance',
      p.rightsClearance,
    );
    needList(
      'commercialContentQualityProfile.platformExportSpecs',
      p.platformExportSpecs,
    );
    needList(
      'commercialContentQualityProfile.mediaEvidenceRequirements',
      p.mediaEvidenceRequirements,
    );
    needList(
      'commercialContentQualityProfile.rejectCriteria',
      p.rejectCriteria,
    );
    if (!p.humanCreativeReviewRequired) {
      issues.add(
        const CommercialPreflightIssue(
          code: 'CCQP_HUMAN_CREATIVE_REQUIRED',
          fieldPath:
              'commercialContentQualityProfile.humanCreativeReviewRequired',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '콘텐츠는 창작 휴먼 리뷰가 필수입니다.',
          developerDetail: 'humanCreativeReviewRequired must be true',
        ),
      );
    }
  }

  static void _validateStandard(
    List<CommercialPreflightIssue> issues,
    List<String> missing,
    CommercialQualityStandard c,
    String prefix,
  ) {
    if (!c.present) {
      _req(issues, missing, 'CQSTD_MISSING', prefix, '공통 상용 품질 표준이 필요합니다.');
      return;
    }
    if (c.schemaVersion != CommercialQualityStandard.kSchemaVersion) {
      issues.add(
        CommercialPreflightIssue(
          code: 'CQSTD_BAD_VERSION',
          fieldPath: '$prefix.schemaVersion',
          severity: CommercialIssueSeverity.error,
          userMessageKo: '공통 표준 버전은 1이어야 합니다.',
          developerDetail: 'schemaVersion must be 1',
        ),
      );
    }
    void need(String field, String v) {
      if (v.trim().isEmpty) {
        _req(
          issues,
          missing,
          'CQSTD_REQUIRED',
          '$prefix.$field',
          '공통 품질 필수 항목이 비어 있습니다.',
        );
      }
    }

    void needList(String field, List<String> v) {
      if (v.isEmpty) {
        _req(
          issues,
          missing,
          'CQSTD_REQUIRED',
          '$prefix.$field',
          '공통 품질 필수 목록이 비어 있습니다.',
        );
      }
    }

    need('targetAudience', c.targetAudience);
    need('customerProblem', c.customerProblem);
    need('promisedOutcome', c.promisedOutcome);
    need('uniqueValue', c.uniqueValue);
    needList('reasonsToPay', c.reasonsToPay);
    need('commercialGoal', c.commercialGoal);
    need('monetizationModel', c.monetizationModel);
    need('brandDirection', c.brandDirection);
    need('referenceLevel', c.referenceLevel);
    need('localizationTarget', c.localizationTarget);
    need('accessibilityTarget', c.accessibilityTarget);
    needList('requiredDeliverables', c.requiredDeliverables);
    needList('evidenceRequirements', c.evidenceRequirements);
    needList('humanReviewRequirements', c.humanReviewRequirements);
    need('revisionPolicy', c.revisionPolicy);
    needList('releaseReadinessCriteria', c.releaseReadinessCriteria);
    needList('explicitlyOutOfScope', c.explicitlyOutOfScope);
    needList('legalPrivacyCopyrightRisks', c.legalPrivacyCopyrightRisks);
  }

  static void _req(
    List<CommercialPreflightIssue> issues,
    List<String> missing,
    String code,
    String path,
    String ko,
  ) {
    issues.add(
      CommercialPreflightIssue(
        code: code,
        fieldPath: path,
        severity: CommercialIssueSeverity.error,
        userMessageKo: ko,
        developerDetail: '$path is required',
        studioStepHint: '상용 품질 입력',
      ),
    );
    missing.add(path);
  }

  static bool _looksLikeInternalId(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('wi_') || t.startsWith('job_')) return true;
    if (t.contains('stageId')) return true;
    if (t.contains('_') && !t.contains(' ') && t.length > 24) return true;
    return false;
  }

  static bool _looksLikePlaceholder(String s) {
    final low = s.toLowerCase();
    return low.contains('todo') ||
        low.contains('placeholder') ||
        low.contains('lorem ipsum') ||
        low.contains('예시만') ||
        low.contains('example_only');
  }

  static bool _hasDuplicatedArtifactSuffix(String title, String artifact) {
    final t = title.trim();
    switch (artifact) {
      case ArtifactType.app:
        return RegExp(r'앱\s*앱$').hasMatch(t);
      case ArtifactType.ebook:
        return RegExp(r'전자책\s*전자책$').hasMatch(t);
      case ArtifactType.site:
      case ArtifactType.promoSite:
        return RegExp(r'사이트\s*사이트$').hasMatch(t);
      case ArtifactType.contents:
        return RegExp(r'콘텐츠\s*콘텐츠$').hasMatch(t);
      default:
        return false;
    }
  }
}
