import '../models/business_planning.dart';
import '../models/commercial/commercial_quality_attachment.dart';
import '../models/problem_validate_contract.dart';
import 'instruction_contract_builder.dart';

/// 로컬 규칙 기반 사업 기획 분석. 외부 AI API를 사용하지 않는다.
class BusinessPlanningService {
  BusinessPlanningService({InstructionContractBuilder? contractBuilder})
    : _contractBuilder = contractBuilder ?? const InstructionContractBuilder();

  final InstructionContractBuilder _contractBuilder;

  static const standardWorkflowTitles = <(String, String)>[
    ('idea_clarify', '아이디어 정리'),
    ('problem_validate', '고객 문제 검증'),
    ('materials_prep', '자료 준비'),
    ('planning', '기획'),
    ('project_setup', '프로젝트 생성 또는 불러오기'),
    ('prompt_generate', 'AI/Cursor 작업 프롬프트 생성'),
    ('draft', '초안 제작'),
    ('build_test', '실행 및 기능 검사'),
    ('user_review', '사용자 확인'),
    ('revise', '보완 수정'),
    ('quality', '품질 검사'),
    ('publish_prep', '등록 준비'),
    ('deploy', '배포'),
    ('promo', '홍보자료 제작'),
    ('launch', '출시자료 준비'),
    ('measure', '출시 후 운영·측정 설계'),
    ('iterate', '개선 백로그 점검'),
    ('maintain', '최종 패키지 검증'),
  ];

  /// Sotong24Work AppStageContract와 동일한 Android/Flutter Production 18단계.
  /// 앱 지시서는 전자책/공통 단계 ID를 재사용하면 Agent Inbox 검증에서 거부된다.
  static const appWorkflowStages = <(String, String, String)>[
    ('app_idea', '앱 아이디어 정리', '문제·핵심 가치·대상 사용자·한 줄 정의를 만든다.'),
    ('app_problem_validate', '고객 문제 검증', '필요성·대체수단·경쟁 앱을 검토한다.'),
    ('app_market_analysis', '시장·경쟁 분석', '유사 앱·차별점·수익 가능성·위험을 정리한다.'),
    ('app_requirements', '제품 요구사항 정의', 'MVP·제외 기능·성공 기준을 고정한다.'),
    (
      'app_project_setup',
      '프로젝트 셋업',
      '독립 저장소에 실제 Android Flutter 프로젝트를 생성·검증한다.',
    ),
    ('app_ux_flow', 'UX 흐름 설계', '주요 화면·전환·사용자 흐름을 설계한다.'),
    ('app_design_system', 'UI 디자인 시스템', '색상·타이포그래피·공통 컴포넌트를 정의한다.'),
    ('app_data_state', '데이터·상태 구조 설계', '모델·상태관리·데이터·Firebase 필요성을 결정한다.'),
    ('app_core_implementation_1', '핵심 기능 구현 1', 'MVP 핵심 기능 첫 묶음을 구현한다.'),
    ('app_core_implementation_2', '핵심 기능 구현 2', '나머지 MVP 기능과 화면 흐름을 구현한다.'),
    (
      'app_integration_errors',
      '통합 및 예외처리',
      'loading/error/empty/offline을 포함해 통합한다.',
    ),
    ('app_code_quality', '코드 품질 점검', 'flutter analyze·lint·구조·보안을 점검한다.'),
    ('app_automated_tests', '자동 테스트', 'unit/widget/integration 가능한 테스트를 실행한다.'),
    (
      'app_android_release',
      'Android Release Build',
      '설치 가능한 release APK를 빌드·검증한다.',
    ),
    ('app_device_review_prep', '실기기 검증 준비', 'APK·설치 안내·권한·체크리스트를 준비한다.'),
    ('app_user_review_package', '사용자 검토 패키지', '휴대폰 다운로드·설치·확인 결과물을 준비한다.'),
    ('app_revision_quality', '보완·최종 품질 검증', '보완 요청과 최종 regression을 처리한다.'),
    (
      'app_production_complete',
      'Production Complete',
      '최종 APK·소스·테스트·설치·출시 준비자료를 확정한다.',
    ),
  ];

  PlanningAnalysisResult analyze(BusinessPlanInput input) {
    final criteria = _scoreCriteria(input);
    final average =
        criteria.map((c) => c.score).reduce((a, b) => a + b) / criteria.length;
    final verdict = _verdict(average, criteria, input);
    final recommendations = recommendDeliverables(input, criteria);
    final summary = _summary(input, average, verdict, criteria);

    return PlanningAnalysisResult(
      criteria: criteria,
      verdict: verdict,
      summary: summary,
      recommendations: recommendations,
      averageScore: double.parse(average.toStringAsFixed(2)),
    );
  }

  List<DeliverableRecommendation> recommendDeliverables(
    BusinessPlanInput input,
    List<CriterionScore> criteria,
  ) {
    final problem = input.customerProblem.toLowerCase();
    final outcome = input.desiredOutcome.toLowerCase();
    final topic = input.topic.toLowerCase();
    final skills = input.experienceSkills.toLowerCase();
    final text = '$topic $problem $outcome $skills ${input.notes}';

    final scores = <String, int>{
      DeliverableType.ebook: 10,
      DeliverableType.youtubeShorts: 10,
      DeliverableType.webMarketing: 10,
      DeliverableType.app: 8,
      DeliverableType.content: 6,
      DeliverableType.industrialAutomation: 5,
    };

    void bump(String type, int delta) {
      scores[type] = (scores[type] ?? 0) + delta;
    }

    if (_containsAny(text, ['방법', '가이드', '노하우', '체크리스트', '정리', '공부', '전자책'])) {
      bump(DeliverableType.ebook, 8);
      bump(DeliverableType.youtubeShorts, 4);
    }
    if (_containsAny(text, ['홍보', '문의', '랜딩', '사이트', '고객 확보', '소개', '마케팅'])) {
      bump(DeliverableType.webMarketing, 9);
    }
    if (_containsAny(text, ['앱', '알림', '기록', '관리', '모바일', '반복 사용'])) {
      bump(DeliverableType.app, 10);
    }
    if (_containsAny(text, ['쇼츠', '유튜브', '영상', '짧게', '바이럴', '콘텐츠'])) {
      bump(DeliverableType.youtubeShorts, 9);
      bump(DeliverableType.content, 3);
    }
    if (_containsAny(text, ['노래', '음악', '음원', '브금', '콘텐츠'])) {
      bump(DeliverableType.content, 8);
    }
    if (_containsAny(text, ['산업', '자동화', 'plc', '현장', '설비'])) {
      bump(DeliverableType.industrialAutomation, 12);
    }
    if (_containsAny(skills, ['산업', '자동화', 'plc', '현장', '개발', 'flutter'])) {
      bump(DeliverableType.app, 3);
      bump(DeliverableType.ebook, 2);
      bump(DeliverableType.industrialAutomation, 4);
    }
    if (input.existingMaterials.trim().isNotEmpty) {
      bump(DeliverableType.ebook, 3);
      bump(DeliverableType.youtubeShorts, 2);
    }
    // 정보 신뢰성이 약하면 전자책 단독 확정을 피한다.
    final clarity = criteria.firstWhere((c) => c.id == 'problem_clarity').score;
    final pay = criteria.firstWhere((c) => c.id == 'paid_willingness').score;
    if (clarity < 3 || pay < 3) {
      bump(DeliverableType.youtubeShorts, 4);
      bump(DeliverableType.webMarketing, 2);
      bump(DeliverableType.ebook, -3);
    }

    final selected = input.deliverableTypes
        .where((t) => t != DeliverableType.undecided)
        .toSet();
    if (selected.isNotEmpty) {
      for (final type in selected) {
        bump(type, 6);
      }
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (var i = 0; i < ranked.length; i++)
        _recommendationFor(ranked[i].key, i + 1, input),
    ];
  }

  WorkInstruction buildInstruction({
    required String planId,
    required BusinessPlanInput input,
    required PlanningAnalysisResult analysis,
    DateTime? now,
    String? instructionId,
    int version = 1,
    String? createdAt,
    String? updatedAt,
    List<String>? followUpTracks,
    String status = 'active',
    String checksum = '',
    String sourceFileName = '',
    AiExecutionPolicy? aiExecution,
    CommercialQualityAttachment? commercialQuality,
  }) {
    final stamp = (now ?? DateTime.now()).toUtc();
    final iso = stamp.toIso8601String();
    final artifact = input.resolvedArtifactType == ArtifactType.undecided
        ? ArtifactType.ebook
        : input.resolvedArtifactType;
    final subtype = input.contentSubtype.trim().isEmpty
        ? ''
        : ContentSubtype.normalize(input.contentSubtype);
    final selected = input.normalizedDeliverables;
    final recommended = analysis.recommendations.map((r) => r.type).toList();
    final types = {
      artifact,
      if (selected.isNotEmpty)
        ...selected.where((t) => ArtifactType.normalize(t) != artifact),
      ...recommended
          .map(ArtifactType.normalize)
          .where((t) => t != artifact && t != ArtifactType.undecided),
    }.take(3).toList();
    final primaryTrack = ArtifactType.primaryTrackId(artifact);
    final followUps =
        followUpTracks ?? _defaultFollowUpTracks(artifact, subtype: subtype);
    final steps = _workflowForArtifact(artifact, subtype: subtype);
    final stableId = (instructionId != null && instructionId.isNotEmpty)
        ? instructionId
        : 'wi_$planId';
    final fileName = sourceFileName.isNotEmpty
        ? sourceFileName
        : 'WI_$stableId.json';
    final qualityChecks = _qualityFor(artifact, subtype: subtype);
    final completion = _completionFor(artifact, subtype: subtype);

    final contract = _contractBuilder.build(
      input: input,
      planId: planId,
      instructionId: stableId,
      version: version,
      createdAt: createdAt ?? iso,
      updatedAt: updatedAt ?? iso,
      legacySteps: steps,
      legacyQualityChecks: qualityChecks,
      legacyCompletion: completion,
    );
    final valueProp = _contractBuilder.legacyValueProposition(contract);

    return WorkInstruction(
      schemaVersion: instructionSchemaVersionCurrent,
      instructionId: stableId,
      projectId: planId,
      instructionVersion: '$version',
      createdAt: createdAt ?? iso,
      updatedAt: updatedAt ?? iso,
      businessIdea: input.topic.trim(),
      businessPurpose: input.desiredOutcome.trim(),
      customerProblem: input.customerProblem.trim(),
      targetCustomer: input.targetCustomer.trim(),
      deliverableTypes: types,
      recommendedSequence: types,
      valueProposition: valueProp,
      requiredMaterials: _materialsFor(artifact, input, subtype: subtype),
      workflowSteps: steps,
      completionCriteria: completion,
      qualityChecks: qualityChecks,
      risks: [
        ...analysis.criteria
            .where((c) => c.score <= 2)
            .map((c) => '${c.label}: ${c.risks}'),
        ..._riskHintsFor(artifact, subtype: subtype),
      ],
      monetizationOptions: [
        if (input.revenueModel.trim().isNotEmpty) input.revenueModel.trim(),
        if (input.salesPrice.trim().isNotEmpty)
          '희망 가격: ${input.salesPrice.trim()}',
        ..._monetizationHints(artifact),
      ],
      deploymentTargets: _deployTargets(artifact, subtype: subtype),
      promotionChannels: _promoChannels(artifact, subtype: subtype),
      approvalItems: [
        '제작 형태·범위 최종 확정',
        '최종 가격·판매·배포 채널',
        '공개 문구·과장 표현 검토',
        '저작권·출처·개인정보 확인',
        '소통24워크 Agent 실행 전 사용자 승인',
      ],
      executionStatus: '지시서 준비',
      notes: ArtifactType.normalize(artifact) == ArtifactType.app
          ? _appProductionInstructionNotes(input)
          : input.notes.trim(),
      primaryTrack: primaryTrack,
      followUpTracks: followUps,
      artifactType: artifact,
      contentSubtype: subtype,
      checksum: checksum,
      sourceFileName: fileName,
      status: status,
      contract: contract,
      aiExecution: aiExecution,
      commercialQuality: commercialQuality,
    );
  }

  String _appProductionInstructionNotes(BusinessPlanInput input) {
    final userMemo = input.notes.trim();
    final sections = <String>[
      '[앱 Production 품질 계약]',
      '목표 등급: PRODUCTION (Prototype/MVP 완료 금지)',
      '',
      '## 앱 목적',
      input.desiredOutcome.trim().isEmpty
          ? '(사용자 확인 필요)'
          : input.desiredOutcome.trim(),
      '',
      '## 목표 사용자',
      input.targetCustomer.trim().isEmpty
          ? '(사용자 확인 필요)'
          : input.targetCustomer.trim(),
      '',
      '## 핵심 사용자 가치 / 문제',
      input.customerProblem.trim().isEmpty
          ? '(사용자 확인 필요)'
          : input.customerProblem.trim(),
      '',
      '## 필수 포함 항목 (작업지시서 구조)',
      '- 실제 사용 시나리오·핵심 workflow',
      '- 필수/보조 기능·데이터 구조·navigation 구조',
      '- 주요 화면 목록·상태별 UX(empty/loading/error)',
      '- 디자인 방향·최신 Android/Flutter UI·접근성',
      '- 개인정보/권한 최소화·오류 UX·실기기 검토 기준',
      '- 출시 전 품질 기준(overflow 0, placeholder/debug UI 금지)',
      '',
      '## UI/UX Production 기준',
      '- 과도하게 큰 글자·불필요한 대형 카드/공백 금지',
      '- typography hierarchy·spacing/token consistency',
      '- modern Material/Flutter UI·light/dark·responsive layout',
      '- confirmation/destructive UX·실사용자 관점 화면 구성',
      '',
      if (userMemo.isNotEmpty) ...['## 사용자 메모', userMemo],
    ];
    return sections.join('\n');
  }

  List<String> _defaultFollowUpTracks(String artifact, {String subtype = ''}) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return [
          ArtifactType.primaryTrackId(ArtifactType.contents),
          ArtifactType.primaryTrackId(ArtifactType.promoSite),
        ];
      case ArtifactType.app:
        return [
          ArtifactType.primaryTrackId(ArtifactType.promoSite),
          ArtifactType.primaryTrackId(ArtifactType.ebook),
        ];
      case ArtifactType.contents:
        if (subtype == ContentSubtype.song) {
          return [ArtifactType.primaryTrackId(ArtifactType.contents)];
        }
        return [
          ArtifactType.primaryTrackId(ArtifactType.promoSite),
          ArtifactType.primaryTrackId(ArtifactType.ebook),
        ];
      case ArtifactType.site:
        return [ArtifactType.primaryTrackId(ArtifactType.promoSite)];
      case ArtifactType.promoSite:
        return [ArtifactType.primaryTrackId(ArtifactType.contents)];
      default:
        return const [];
    }
  }

  List<String> _materialsFor(
    String artifact,
    BusinessPlanInput input, {
    String subtype = '',
  }) {
    final base = <String>[
      if (input.existingMaterials.trim().isNotEmpty)
        input.existingMaterials.trim()
      else
        '고객 문제·대상·결과 설명을 문장으로 정리한 기획 메모',
      '사례·근거 자료(실제 경험·출처·수치) 목록',
    ];
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return [...base, '목차 초안', '표지·삽화 필요 여부 메모'];
      case ArtifactType.app:
        return [...base, '핵심 화면·기능 목록', '플랫폼(Android/iOS/Web) 선택'];
      case ArtifactType.contents:
        if (subtype == ContentSubtype.song ||
            subtype == ContentSubtype.songAndShorts) {
          return [...base, '장르·분위기·가사 방향', '공개 플랫폼 목록'];
        }
        if (subtype == ContentSubtype.shorts) {
          return [...base, '핵심 메시지 한 줄', '영상 소스·자막·음악 필요 여부'];
        }
        return [...base, '콘텐츠 형식·공개 채널'];
      case ArtifactType.site:
        return [...base, '메뉴 구조 초안', '도메인·호스팅 방향'];
      case ArtifactType.promoSite:
        return [...base, '상품·서비스 한 줄 소개', '연락·상담 경로', '사진·후기 자료'];
      default:
        return base;
    }
  }

  List<String> _completionFor(String artifact, {String subtype = ''}) {
    final common = ['고객 문제·대상·결과가 한 페이지로 설명 가능', '사용자 확인 항목이 체크리스트로 남아 있음'];
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return [...common, '목차와 1장 초안이 존재', '출력 형식(PDF/EPUB)이 확정됨'];
      case ArtifactType.app:
        return [
          ...common,
          '핵심 사용자 workflow가 end-to-end로 완결됨',
          'Production UI/UX·접근성·empty/loading/error 기준 충족',
          'release APK·device review package·prelaunch_review 준비 완료',
        ];
      case ArtifactType.contents:
        if (subtype == ContentSubtype.song) {
          return [...common, '데모/가이드 음원 또는 가사 초안이 존재'];
        }
        if (subtype == ContentSubtype.shorts) {
          return [...common, '쇼츠 스토리보드·초안 영상이 존재'];
        }
        return [...common, '콘텐츠 초안 1건이 존재'];
      case ArtifactType.site:
        return [...common, '메뉴·페이지 구조와 첫 페이지 초안이 존재'];
      case ArtifactType.promoSite:
        return [...common, '랜딩 초안과 CTA(상담·문의) 경로가 존재'];
      default:
        return [...common, '최소 결과물 1개가 초안 수준으로 존재'];
    }
  }

  List<String> _qualityFor(String artifact, {String subtype = ''}) {
    final common = [
      '사실·경험·출처를 과장하지 않았는가',
      '성공·매출 보장 표현이 없는가',
      '비밀번호·API 키·고객 개인정보가 문서에 없는가',
    ];
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.app:
        return [
          ...common,
          'Prototype/MVP 수준으로 완료 처리하지 않았는가',
          '핵심 사용자 행동이 끊기지 않는가',
          '과도한 대형 카드·불필요한 공백·과대 글자가 없는가',
          'typography hierarchy·spacing token·navigation 일관성이 있는가',
          'light/dark·text scale·overflow 0·empty/loading/error 상태가 있는가',
          'placeholder/debug/test UI·visible TODO가 없는가',
          '권한·알림 요청이 목적에 맞고 최소화됐는가',
          '앱 목적 대비 기능 밀도가 충분한가',
        ];
      case ArtifactType.contents:
        return [
          ...common,
          if (subtype == ContentSubtype.shorts ||
              subtype == ContentSubtype.songAndShorts)
            '자막·메시지·길이(15/30/60초)가 채널에 맞는가',
          '저작권·상업 이용 방향이 명시됐는가',
        ];
      case ArtifactType.site:
      case ArtifactType.promoSite:
        return [...common, '모바일에서 읽기·문의 경로가 끊기지 않는가'];
      default:
        return [...common, '모바일에서 읽기 경로가 끊기지 않는가'];
    }
  }

  List<String> _riskHintsFor(String artifact, {String subtype = ''}) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return ['목차 없이 본문만 쓰면 완독·판매 전환이 약해질 수 있음'];
      case ArtifactType.app:
        return ['기능 범위가 넓으면 첫 버전 출시가 지연될 수 있음'];
      case ArtifactType.contents:
        return subtype == ContentSubtype.song
            ? ['저작권·보컬·공개 채널이 불명확하면 배포가 막힐 수 있음']
            : ['메시지 없이 영상만 만들면 유입·전환이 약해질 수 있음'];
      case ArtifactType.site:
        return ['메뉴가 많으면 핵심 목적 페이지가 희석될 수 있음'];
      case ArtifactType.promoSite:
        return ['CTA·연락처 없이 소개만 있으면 문의가 발생하지 않을 수 있음'];
      default:
        return const [];
    }
  }

  List<String> _monetizationHints(String artifact) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return ['무료·저가 검증 후 일반 판매', '상담·맞춤 의뢰 연계'];
      case ArtifactType.app:
        return ['무료+광고', '유료·구독(검증 후)', '문의·B2B 연계'];
      case ArtifactType.contents:
        return ['채널 구독·후원', '전자책·앱·사이트로 유입 연계'];
      case ArtifactType.promoSite:
        return ['상담·견적 전환', '상품·서비스 판매 페이지'];
      default:
        return ['단품 판매', '문의·맞춤 의뢰 연계'];
    }
  }

  List<String> _deployTargets(String artifact, {String subtype = ''}) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.app:
        return ['Play Store 또는 내부 배포', 'Web 배포(해당 시)', '소통사이트매니저 등록 검토'];
      case ArtifactType.ebook:
        return ['전자책 판매 채널', 'PDF/EPUB 배포', '소통사이트매니저 등록 검토'];
      case ArtifactType.contents:
        return [
          if (subtype == ContentSubtype.shorts ||
              subtype == ContentSubtype.songAndShorts)
            'YouTube Shorts / Instagram / TikTok',
          if (subtype == ContentSubtype.song ||
              subtype == ContentSubtype.songAndShorts)
            '음원·영상 공개 플랫폼',
          '소통사이트매니저 등록 검토',
        ];
      case ArtifactType.site:
        return ['Firebase Hosting 또는 선택 호스팅', '도메인 연결', '소통사이트매니저 등록 검토'];
      case ArtifactType.promoSite:
        return ['Firebase Hosting', '도메인 연결', '광고·SNS 랜딩 URL'];
      default:
        return ['소통사이트매니저 등록 검토'];
    }
  }

  List<String> _promoChannels(String artifact, {String subtype = ''}) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return ['쇼츠 요약', '마케팅 사이트 CTA', 'SNS 소개'];
      case ArtifactType.app:
        return ['마케팅 사이트', '스토어 설명', '쇼츠 데모'];
      case ArtifactType.contents:
        return ['채널 고정 댓글·설명', '마케팅 사이트 연계', '시리즈 업로드'];
      case ArtifactType.promoSite:
        return ['검색·지역 광고', 'SNS 링크', '명함·오프라인 QR'];
      default:
        return ['웹마케팅 사이트 CTA', '쇼츠·콘텐츠 유입'];
    }
  }

  List<WorkflowStep> _workflowForArtifact(
    String artifact, {
    String subtype = '',
  }) {
    final primary = ArtifactType.normalize(artifact);
    if (primary == ArtifactType.app) {
      return [
        for (var i = 0; i < appWorkflowStages.length; i++)
          WorkflowStep(
            order: i + 1,
            id: appWorkflowStages[i].$1,
            title: appWorkflowStages[i].$2,
            applicable: true,
            completionCriteria: appWorkflowStages[i].$3,
          ),
      ];
    }
    return [
      for (var i = 0; i < standardWorkflowTitles.length; i++)
        WorkflowStep(
          order: i + 1,
          id: standardWorkflowTitles[i].$1,
          title: standardWorkflowTitles[i].$2,
          applicable: _stepApplicableArtifact(
            standardWorkflowTitles[i].$1,
            primary: primary,
            subtype: subtype,
          ),
          completionCriteria: _stepCriteriaArtifact(
            standardWorkflowTitles[i].$1,
            primary: primary,
            subtype: subtype,
          ),
          notes:
              _stepApplicableArtifact(
                standardWorkflowTitles[i].$1,
                primary: primary,
                subtype: subtype,
              )
              ? _stepNotesArtifact(
                  standardWorkflowTitles[i].$1,
                  primary: primary,
                  subtype: subtype,
                )
              : '해당 없음',
        ),
    ];
  }

  bool _stepApplicableArtifact(
    String id, {
    required String primary,
    String subtype = '',
  }) {
    switch (id) {
      case 'build_test':
        return primary == ArtifactType.app;
      case 'deploy':
        return primary == ArtifactType.app ||
            primary == ArtifactType.site ||
            primary == ArtifactType.promoSite;
      case 'publish_prep':
        return primary != ArtifactType.undecided;
      default:
        return true;
    }
  }

  String _stepCriteriaArtifact(
    String id, {
    required String primary,
    String subtype = '',
  }) {
    final base = _stepCriteria(id);
    switch (id) {
      case 'draft':
        switch (primary) {
          case ArtifactType.ebook:
            return '목차·1장 초안 파일이 존재함';
          case ArtifactType.app:
            return '핵심 화면·기능 초안이 존재함';
          case ArtifactType.contents:
            return subtype == ContentSubtype.song
                ? '가사·가이드 음원 초안이 존재함'
                : '쇼츠/콘텐츠 스토리보드·초안이 존재함';
          case ArtifactType.site:
            return '사이트 첫 페이지·메뉴 초안이 존재함';
          case ArtifactType.promoSite:
            return '랜딩 초안과 CTA가 존재함';
          default:
            return base;
        }
      case 'quality':
        return '$base / ${ArtifactType.labelKo(primary)} 전용 품질 항목 통과';
      default:
        return base;
    }
  }

  String _stepNotesArtifact(
    String id, {
    required String primary,
    String subtype = '',
  }) {
    if (id == 'planning') {
      return '주 트랙: ${ArtifactType.primaryTrack(primary)}'
          '${subtype.isNotEmpty ? ' / 하위: ${ContentSubtype.labelKo(subtype)}' : ''}';
    }
    return '';
  }

  String buildReadableInstruction(WorkInstruction instruction) {
    final buffer = StringBuffer()
      ..writeln('【소통24워크 Agent 표준 작업지시서】')
      ..writeln('schemaVersion: ${instruction.schemaVersion}')
      ..writeln('지시서 ID: ${instruction.instructionId}')
      ..writeln('프로젝트 ID: ${instruction.projectId}')
      ..writeln('실행 상태: ${instruction.executionStatus}')
      ..writeln('생성: ${instruction.createdAt}')
      ..writeln()
      ..writeln('■ 사업 주제')
      ..writeln(instruction.businessIdea)
      ..writeln()
      ..writeln('■ 고객 문제')
      ..writeln(instruction.customerProblem)
      ..writeln()
      ..writeln('■ 대상 고객')
      ..writeln(instruction.targetCustomer)
      ..writeln()
      ..writeln('■ 핵심 가치 제안')
      ..writeln(instruction.valueProposition)
      ..writeln()
      ..writeln('■ 추천 제작 순서')
      ..writeln(
        instruction.recommendedSequence
            .map(DeliverableType.labelKo)
            .join(' → '),
      )
      ..writeln()
      ..writeln('■ 작업 단계');
    for (final step in instruction.workflowSteps) {
      buffer.writeln(
        '${step.order}. ${step.title} '
        '(${step.applicable ? '적용' : '해당 없음'}) — ${step.completionCriteria}',
      );
    }
    buffer
      ..writeln()
      ..writeln('■ 품질 검사')
      ..writeln(instruction.qualityChecks.map((e) => '- $e').join('\n'))
      ..writeln()
      ..writeln('■ 사용자 승인 필요')
      ..writeln(instruction.approvalItems.map((e) => '- $e').join('\n'))
      ..writeln()
      ..writeln(
        '※ 본 지시서는 로컬 규칙 기반 기획 도우미가 생성했습니다. '
        '외부 AI가 내용을 만들어 낸 것이 아니며, 소통24워크 Agent 자동 실행은 포함하지 않습니다.',
      );
    return buffer.toString();
  }

  String buildCursorPrompt({
    required BusinessPlanInput input,
    required WorkInstruction instruction,
  }) {
    return '''
당신은 소통웨어 실행 보조다. 아래 작업지시서를 바탕으로 초안 제작만 돕는다.
매출·성공을 보장하는 문장을 쓰지 말고, 사실과 검증 가능한 단계만 제안한다.

주제: ${input.topic}
고객 문제: ${input.customerProblem}
대상 고객: ${input.targetCustomer}
원하는 결과: ${input.desiredOutcome}
제작 순서: ${instruction.recommendedSequence.map(DeliverableType.labelKo).join(' → ')}

다음을 출력하라:
1) 최소 결과물 정의
2) 필요한 자료 체크리스트
3) 첫 번째 적용 단계의 구체 작업 목록
4) 품질 검사 항목
5) 사용자가 승인해야 할 항목

지시서 ID: ${instruction.instructionId}
실행 상태: ${instruction.executionStatus} (자동 실행 금지)
''';
  }

  List<CriterionScore> _scoreCriteria(BusinessPlanInput input) {
    int lengthScore(String text, {int good = 40, int fair = 18}) {
      final n = text.trim().length;
      if (n >= good) return 4;
      if (n >= fair) return 3;
      if (n >= 8) return 2;
      return 1;
    }

    CriterionScore build({
      required String id,
      required String label,
      required int score,
      required String rationale,
      required String missing,
      required String risks,
      required String improvement,
    }) {
      return CriterionScore(
        id: id,
        label: label,
        score: score.clamp(1, 5),
        rationale: rationale,
        missingInfo: missing,
        risks: risks,
        improvement: improvement,
      );
    }

    final problemScore = lengthScore(input.customerProblem);
    final customerScore = lengthScore(input.targetCustomer, good: 30, fair: 12);
    final outcomeScore = lengthScore(input.desiredOutcome);
    final skillScore = input.experienceSkills.trim().isEmpty
        ? 2
        : lengthScore(input.experienceSkills, good: 30, fair: 10);
    final paidHints = _containsAny(input.desiredOutcome + input.revenueModel, [
      '판매',
      '유료',
      '결제',
      '구독',
      '문의',
      '견적',
      '광고',
    ]);
    final paidScore = paidHints
        ? (input.revenueModel.trim().isEmpty ? 3 : 4)
        : (input.revenueModel.trim().isEmpty ? 2 : 3);
    final repeatScore =
        _containsAny(input.desiredOutcome + input.topic, [
          '반복',
          '시리즈',
          '템플릿',
          '구독',
          '재사용',
          '표준',
        ])
        ? 4
        : 2;
    final autoScore =
        _containsAny(input.experienceSkills + input.desiredOutcome, [
          '자동',
          '템플릿',
          '표준',
          '시스템',
          'AI',
        ])
        ? 4
        : 2;
    final costScore = input.expectedDuration.trim().isEmpty ? 2 : 3;
    final maintainScore = input.deliverableTypes.contains(DeliverableType.app)
        ? 2
        : 3;
    final linkScore =
        _containsAny(input.experienceSkills + input.notes, [
          '산업',
          '앱',
          '전자책',
          '콘텐츠',
          '마케팅',
          '사이트',
          '자동화',
        ])
        ? 4
        : 2;
    final diffScore = input.experienceSkills.trim().length > 20 ? 3 : 2;
    final difficultyScore = input.deliverableTypes.contains(DeliverableType.app)
        ? 2
        : 3;

    return [
      build(
        id: 'problem_clarity',
        label: '고객 문제의 명확성',
        score: problemScore,
        rationale: problemScore >= 3
            ? '불편·손실이 문장으로 드러난다.'
            : '문제가 추상적이거나 너무 짧다.',
        missing: problemScore < 4 ? '누가 언제 어떤 손해를 보는지 구체 사례' : '추가 정보 없음',
        risks: '문제가 흐리면 제작물이 기능 나열이 된다.',
        improvement: '최근 실제 사례 1건을 숫자·상황과 함께 적는다.',
      ),
      build(
        id: 'customer_specificity',
        label: '대상 고객의 구체성',
        score: customerScore,
        rationale: customerScore >= 3 ? '대상이 어느 정도 구분된다.' : '대상이 “모두”에 가깝다.',
        missing: customerScore < 4 ? '직업·지역·상황 조건' : '추가 정보 없음',
        risks: '대상이 넓으면 메시지와 가격이 흔들린다.',
        improvement: '첫 고객 10명을 상상해 공통점을 적는다.',
      ),
      build(
        id: 'paid_willingness',
        label: '유료 구매 가능성',
        score: paidScore,
        rationale: paidHints ? '유료·문의 관련 단서가 있다. 확정은 아니다.' : '유료 전환 단서가 부족하다.',
        missing: '실제 지불 의사 확인(대화·사전예약·유사 상품)',
        risks: '관심과 지불을 동일시하면 재고·시간만 소비한다.',
        improvement: '유료로 살 이유를 한 문장으로 쓰고 2명에게 확인해 본다.',
      ),
      build(
        id: 'differentiation',
        label: '차별화 가능성',
        score: diffScore,
        rationale: diffScore >= 3 ? '보유 경험 단서가 있어 차별화 여지가 있다.' : '차별화 근거가 약하다.',
        missing: '경쟁 대비 “나만이 줄일 수 있는 손해”',
        risks: '일반론 콘텐츠는 가격 경쟁에 끌려간다.',
        improvement: '현장·앱·콘텐츠 중 실제 경험 증거를 하나 붙인다.',
      ),
      build(
        id: 'skill_fit',
        label: '보유 기술 활용도',
        score: skillScore,
        rationale: skillScore >= 3
            ? '기술·경험 입력이 있어 연계 가능하다.'
            : '기술 입력이 비어 평가가 보수적이다.',
        missing: skillScore < 3 ? '보유 기술·도구·현장 경험' : '추가 정보 없음',
        risks: '익숙하지 않은 영역부터 시작하면 제작비가 커진다.',
        improvement: '이미 할 수 있는 일과 배워야 할 일을 나눈다.',
      ),
      build(
        id: 'build_difficulty',
        label: '제작 난이도',
        score: difficultyScore,
        rationale: difficultyScore >= 3
            ? '비교적 가벼운 형태부터 시작할 여지가 있다.'
            : '앱 등 난이도 높은 형태가 포함되어 있다.',
        missing: '첫 버전에 넣을 기능/분량의 상한',
        risks: '처음부터 완성품을 노리면 중단 위험이 커진다.',
        improvement: '2주 안에 만들 최소 결과물만 남긴다.',
      ),
      build(
        id: 'repeat_sales',
        label: '반복 판매 가능성',
        score: repeatScore,
        rationale: repeatScore >= 3 ? '시리즈·재사용 단서가 있다.' : '단발 판매 가능성이 높다.',
        missing: '재구매·시리즈 확장 가설',
        risks: '단발이면 마케팅 비용 대비 회수가 어렵다.',
        improvement: '같은 문제를 단계별로 나눈 시리즈 구조를 스케치한다.',
      ),
      build(
        id: 'automation',
        label: '자동화 가능성',
        score: autoScore,
        rationale: autoScore >= 3 ? '표준화·자동화 키워드가 있다.' : '수작업 비중이 클 수 있다.',
        missing: '반복 가능한 체크리스트·템플릿',
        risks: '모든 주문을 맞춤으로 받으면 확장되지 않는다.',
        improvement: '공통 70%를 템플릿으로 고정한다.',
      ),
      build(
        id: 'initial_cost',
        label: '초기 비용 부담',
        score: costScore,
        rationale: costScore >= 3 ? '기간 입력이 있어 일정 가설이 있다.' : '기간·비용 정보가 부족하다.',
        missing: '유료 도구·광고·외주 예상 비용',
        risks: '고정비를 먼저 올리면 검증 전에 현금이 샌다.',
        improvement: '유료 지출 없이 검증할 최소 경로를 정한다.',
      ),
      build(
        id: 'maintenance',
        label: '유지관리 부담',
        score: maintainScore,
        rationale: maintainScore >= 3
            ? '상대적으로 유지관리가 가벼운 형태다.'
            : '앱·지속 운영 부담이 클 수 있다.',
        missing: '업데이트 주기와 담당',
        risks: '출시 후 방치되면 신뢰가 떨어진다.',
        improvement: '월 1회 점검 항목을 미리 적는다.',
      ),
      build(
        id: 'scalability',
        label: '확장 가능성',
        score: outcomeScore >= 3 ? 3 : 2,
        rationale: '결과물 설명이 구체할수록 확장 설계가 쉽다.',
        missing: '1차 결과물 이후 2차 상품',
        risks: '확장을 먼저 그리면 1차가 끝나지 않는다.',
        improvement: '1차 검증 기준을 숫자로 정한다.',
      ),
      build(
        id: 'sotongware_link',
        label: '소통웨어 기존 사업과의 연계성',
        score: linkScore,
        rationale: linkScore >= 3
            ? '기존 사업 키워드와 연결 단서가 있다.'
            : '기존 사업 연계가 명확하지 않다.',
        missing: '어느 사업부 자산·고객을 재사용할지',
        risks: '신규만 추가하면 선택과 집중이 깨진다.',
        improvement: '기존 6개 사업부 중 연결 1곳을 지정한다.',
      ),
    ];
  }

  String _verdict(
    double average,
    List<CriterionScore> criteria,
    BusinessPlanInput input,
  ) {
    final lowCount = criteria.where((c) => c.score <= 2).length;
    if (!input.hasRequiredFields || average < 2.2 || lowCount >= 5) {
      return PlanningVerdict.hold;
    }
    if (average < 2.8 || lowCount >= 3) {
      return PlanningVerdict.needsRefine;
    }
    if (average < 3.5 ||
        criteria.any((c) => c.id == 'paid_willingness' && c.score <= 2)) {
      return PlanningVerdict.validateFirst;
    }
    return PlanningVerdict.readyToBuild;
  }

  String _summary(
    BusinessPlanInput input,
    double average,
    String verdict,
    List<CriterionScore> criteria,
  ) {
    final lows = criteria
        .where((c) => c.score <= 2)
        .map((c) => c.label)
        .toList();
    return '로컬 규칙 기반 평가(외부 AI 생성 아님). 평균 ${average.toStringAsFixed(1)}/5, '
        '판단: ${PlanningVerdict.labelKo(verdict)}. '
        '${lows.isEmpty ? '치명적으로 낮은 항목은 없다.' : '보완 우선: ${lows.take(3).join(', ')}. '} '
        '성공·매출을 보장하지 않으며, 입력되지 않은 사실은 점수를 올리지 않았다.';
  }

  DeliverableRecommendation _recommendationFor(
    String type,
    int rank,
    BusinessPlanInput input,
  ) {
    switch (type) {
      case DeliverableType.app:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '반복 기록·알림·관리가 핵심이면 앱이 적합하다. 단, 초기 제작·유지 비용이 크다.',
          minimumOutput: '핵심 화면 3개와 저장 기능만 있는 최소 앱',
          requiredMaterials: '사용자 흐름, 데이터 항목, 테스트 계정',
          workSteps: '문제 정의 → 화면 스케치 → Flutter 초안 → 테스트 → 사용자 확인',
          nextExpansion: '웹 홍보 사이트와 쇼츠로 유입을 붙인다.',
          monetizationOptions: '앱 내 유료·광고·맞춤 구축 연계',
          risks: '기능 과다·스토어 심사·지속 업데이트 부담',
        );
      case DeliverableType.ebook:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '방법·체크리스트형 지식 전달에 적합하다. 근거와 경험이 있어야 신뢰가 생긴다.',
          minimumOutput: '목차+핵심 3장+실행 체크리스트 PDF 초안',
          requiredMaterials: '실제 사례, 출처, 금지 표현 목록',
          workSteps: '독자 문제 → 목차 → 초고 → 편집 → 판매 페이지',
          nextExpansion: '쇼츠로 핵심만 쪼개고, 웹사이트로 판매를 연결한다.',
          monetizationOptions: '단품 판매, 시리즈, 상담 연계',
          risks: '일반론·과장 시 환불·신뢰 하락',
        );
      case DeliverableType.youtubeShorts:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '관심 검증과 유입에 빠르다. 판매 확정이 아니라 수요 신호 확인에 쓴다.',
          minimumOutput: '60초 이내 문제-해결 힌트 영상 3편',
          requiredMaterials: '스크립트, 썸네일 문구, 출처',
          workSteps: '주제 분해 → 스크립트 → 촬영/생성 → 업로드 → 반응 확인',
          nextExpansion: '반응 좋은 주제를 전자책·사이트로 확장한다.',
          monetizationOptions: '유입 → 사이트 문의/전자책',
          risks: '조회와 매출을 동일시하는 착각',
        );
      case DeliverableType.content:
      case DeliverableType.contentMusic:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '브랜드·분위기 자산에 유리하다. 직접 매출보다 유입·차별화 보조에 가깝다.',
          minimumOutput: '테마곡 1곡+사용 장면 설명',
          requiredMaterials: '저작권 확인, 사용 범위',
          workSteps: '콘셉트 → 초안 → 검수 → 채널/사이트 배치',
          nextExpansion: '쇼츠·앱 오프닝과 결합한다.',
          monetizationOptions: '콘텐츠 유입, 제작 의뢰',
          risks: '저작권·취향 의존·단독 수익화 난이도',
        );
      case DeliverableType.industrialAutomation:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '현장·설비·자동화 요구가 분명할 때 적합하다. 제작·검증 주기가 길다.',
          minimumOutput: '핵심 공정 1개의 최소 동작 데모',
          requiredMaterials: '현장 요구사항, 입출력 정의, 안전 제약',
          workSteps: '요구 정의 → 설계 → 구현 → 현장 검증',
          nextExpansion: '모니터링 대시보드·교육 자료로 확장한다.',
          monetizationOptions: '구축 용역, 유지보수 계약',
          risks: '현장 의존·납기·안전 규제',
        );
      case DeliverableType.webMarketing:
      default:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '신뢰·문의·판매 연결의 허브다. 다른 제작물의 착륙점으로 유용하다.',
          minimumOutput: '문제-해결-사례-CTA 1페이지',
          requiredMaterials: '연락 수단, 사례, 가격 가설',
          workSteps: '메시지 → 와이어 → Hosting 배포 → CTA 점검',
          nextExpansion: '전자책/앱 링크와 쇼츠를 연결한다.',
          monetizationOptions: '문의 전환, 상품 판매 페이지',
          risks: '예쁜 페이지만 있고 제안이 없으면 문의가 없다',
        );
    }
  }

  String _stepCriteria(String id) {
    switch (id) {
      case 'idea_clarify':
        return '주제·문제·고객·결과가 한 페이지로 정리됨';
      case 'problem_validate':
        return ProblemValidateContract.completionCriteria;
      case 'materials_prep':
        return '필요 자료 목록과 확보 상태가 체크됨';
      case 'planning':
        return '최소 결과물과 비범위가 명시됨';
      case 'project_setup':
        return '저장소/프로젝트 폴더가 준비됨';
      case 'prompt_generate':
        return 'Cursor용 시작 프롬프트가 복사 가능함';
      case 'draft':
        return '초안 파일이 존재함';
      case 'build_test':
        return '핵심 기능 테스트 통과 또는 해당 없음';
      case 'user_review':
        return '사용자 확인 의견이 기록됨';
      case 'revise':
        return '피드백 반영 또는 보류 사유 기록';
      case 'quality':
        return '품질 체크리스트 통과';
      case 'publish_prep':
        return '등록 정보·가격·약관 초안 준비';
      case 'deploy':
        return '배포 URL/채널 기록 또는 해당 없음';
      case 'promo':
        return '홍보 문구·채널 초안 준비';
      case 'launch':
        return '공개 시점과 채널이 기록됨';
      case 'measure':
        return '1주 관찰 지표가 정의됨';
      case 'iterate':
        return '개선 항목이 다음 지시서로 연결됨';
      case 'maintain':
        return '월간 점검 항목이 지정됨';
      default:
        return '완료 조건 확인';
    }
  }

  bool _containsAny(String text, List<String> keys) {
    final lower = text.toLowerCase();
    return keys.any(lower.contains);
  }
}
