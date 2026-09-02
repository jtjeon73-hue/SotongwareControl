/// Instruction Contract 빌더 — 사용자 확정값을 canonical로 고정.
library;

import '../data/project_design_catalog.dart';
import '../models/business_planning.dart';
import '../models/concept_candidate.dart';
import '../models/planning_wizard_state.dart';
import '../models/project_design_state.dart';

class InstructionContractBuilder {
  const InstructionContractBuilder();

  InstructionContract build({
    required BusinessPlanInput input,
    required String planId,
    required String instructionId,
    required int version,
    required String createdAt,
    required String updatedAt,
    required List<WorkflowStep> legacySteps,
    List<String> legacyQualityChecks = const [],
    List<String> legacyCompletion = const [],
  }) {
    final artifact = input.resolvedArtifactType == ArtifactType.undecided
        ? ArtifactType.ebook
        : input.resolvedArtifactType;
    final subtypeRaw = input.contentSubtype.trim();
    final subtype = subtypeRaw.isEmpty
        ? null
        : ContentSubtype.normalize(subtypeRaw);
    final design = _designFromInput(input);
    final topics = _topicLabels(design, input);
    final audiences = _audienceList(input, design);
    final production = _productionSpec(artifact, subtype, design, input);
    final scope = _scope(artifact, subtype, production, topics);
    final statuses = _fieldStatuses(input, design);
    final title = _canonicalFrom(
      input.topic,
      statuses['topic'] ?? DesignFieldStatus.undecided,
    );
    final purpose = _canonicalFrom(
      input.desiredOutcome,
      statuses['outcome'] ?? DesignFieldStatus.undecided,
    );
    final problem = _canonicalFrom(
      input.customerProblem,
      statuses['problem'] ?? DesignFieldStatus.undecided,
    );
    final customerDesc = _canonicalFrom(
      input.targetCustomer,
      statuses['customer'] ?? DesignFieldStatus.undecided,
    );
    final valueProp = _valueProposition(
      title: title,
      problem: problem,
      customer: customerDesc,
      purpose: purpose,
      artifact: artifact,
    );

    final quality = _qualityCriteria(artifact);
    final guards = _aiGuards(artifact);
    final workflow = _workflow(artifact, subtype, legacySteps);
    final validation = ValidationContract(
      requiredFields: const [
        'schemaVersion',
        'instructionId',
        'artifactType',
        'title',
        'targetCustomers',
        'coreProblem',
        'expectedOutcome',
        'productionSpec',
        'workflow',
        'approval',
      ],
      requiredArtifacts: _requiredArtifacts(artifact, subtype),
      qualityChecks: [
        ...quality.where((q) => q.required).map((q) => q.id),
        ...legacyQualityChecks,
      ],
      blockingConditions: const [
        'title.pending',
        'coreProblem.pending',
        'expectedOutcome.pending',
        'targetCustomers.empty',
        'artifactType.undecided',
        'approval.deployment != approved|pending',
      ],
      warnings: [
        if (production.undecidedKeys.isNotEmpty)
          'productionSpec.undecidedKeys: ${production.undecidedKeys.join(', ')}',
        if (input.notes.trim().isEmpty) 'userMemo.empty',
        if (topics.isEmpty) 'selectedTopics.empty',
      ],
    );

    return InstructionContract(
      identity: IdentityContract(
        schemaVersion: instructionSchemaVersionCurrent,
        instructionId: instructionId,
        projectId: planId,
        version: '$version',
        artifactType: artifact,
        artifactSubtype: subtype,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      projectDefinition: ProjectDefinitionContract(
        title: title,
        subtitle: topics.take(2).join(' · '),
        projectPurpose: purpose,
        targetCustomers: audiences,
        targetCustomerDescription: customerDesc,
        coreProblem: problem,
        expectedOutcome: purpose,
        userMemo: input.notes.trim(),
        selectedTopics: topics,
        keywords: [
          ...topics.take(5),
          ...audiences.take(3),
          ArtifactType.labelKo(artifact),
        ].where((e) => e.trim().isNotEmpty).toSet().toList(),
      ),
      positioning: PositioningContract(
        customerNeed: problem,
        valueProposition: valueProp,
        differentiation: design?.designMemo.trim().isNotEmpty == true
            ? _canonicalFrom(
                design!.designMemo.trim(),
                DesignFieldStatus.userEdited,
              )
            : (design?.combinedDirection.trim().isNotEmpty == true
                  ? CanonicalValue(
                      value: design!.combinedDirection.trim(),
                      source: FieldSource.suggested,
                      pending: !(design.planningConfirmed),
                    )
                  : CanonicalValue.derived(
                      '실행 체크리스트·상황 맞춤 예시로 차별화 (미확정 시 제작 단계에서 구체화)',
                    )),
        aiEraRelevance: CanonicalValue.derived(
          'AI 제작 파이프라인에서 확정 기획값만 사용하고 임의 창작을 금지한다.',
        ),
        professionalDirection: CanonicalValue.derived(
          _professionalDirection(artifact, subtype),
        ),
      ),
      scope: scope,
      productionSpec: production,
      qualityCriteria: quality,
      aiGuards: guards,
      workflow: workflow,
      approval: const ApprovalContract(
        planning: ApprovalStatus.approved,
        instructionGeneration: ApprovalStatus.approved,
        production: ApprovalStatus.pending,
        publishing: ApprovalStatus.pending,
        deployment: ApprovalStatus.pending,
      ),
      validation: validation,
    );
  }

  /// 레거시 flat valueProposition — 사용자 확정값 기반, template 우선 금지.
  String legacyValueProposition(InstructionContract contract) {
    final vp = contract.positioning.valueProposition;
    if (!vp.isBlank && vp.source != FieldSource.template) {
      return vp.value;
    }
    final title = contract.projectDefinition.title.value;
    final customer = contract.projectDefinition.targetCustomerDescription.value;
    final problem = contract.projectDefinition.coreProblem.value;
    if (title.isNotEmpty && customer.isNotEmpty && problem.isNotEmpty) {
      return '$customer의 문제($problem)를 해결하기 위한 「$title」.';
    }
    return vp.value;
  }

  ProjectDesignState? _designFromInput(BusinessPlanInput input) {
    final raw = input.wizardSelections;
    if (raw == null || raw.isEmpty) return null;
    try {
      final wizard = PlanningWizardState.fromJson(raw);
      return ProjectDesignState.fromWizardState(wizard);
    } catch (_) {
      return null;
    }
  }

  List<String> _topicLabels(
    ProjectDesignState? design,
    BusinessPlanInput input,
  ) {
    final fromWizard = input.wizardSelections?['selectedConcepts'];
    if (fromWizard is List && fromWizard.isNotEmpty) {
      final titles = <String>[];
      for (final e in fromWizard) {
        if (e is Map && '${e['title'] ?? ''}'.trim().isNotEmpty) {
          titles.add('${e['title']}'.trim());
        }
      }
      if (titles.isNotEmpty) return titles;
    }
    if (design == null) return const [];
    if (design.selectedConceptIds.isNotEmpty) {
      // ids may be concept ids; prefer user-added titles
      final userTitles = design.userAddedConcepts
          .where((c) => design.selectedConceptIds.contains(c.id))
          .map((c) => c.title)
          .toList();
      if (userTitles.isNotEmpty) return userTitles;
    }
    return ProjectDesignCatalog.topics
        .where((t) => design.selectedTopicIds.contains(t.id))
        .map((t) => t.label)
        .toList();
  }

  Map<String, DesignFieldStatus> _fieldStatuses(
    BusinessPlanInput input,
    ProjectDesignState? design,
  ) {
    final raw = input.wizardSelections?['fieldStatuses'];
    if (raw is Map) {
      return {
        'topic': DesignFieldStatusX.parse('${raw['topic'] ?? ''}'),
        'problem': DesignFieldStatusX.parse('${raw['problem'] ?? ''}'),
        'outcome': DesignFieldStatusX.parse('${raw['outcome'] ?? ''}'),
        'customer': DesignFieldStatusX.parse('${raw['customer'] ?? ''}'),
      };
    }
    if (design != null) {
      return {
        'topic': design.topicStatus,
        'problem': design.problemStatus,
        'outcome': design.outcomeStatus,
        'customer': design.customerStatus,
      };
    }
    // Legacy direct input without status → treat non-empty as confirmed
    return {
      'topic': input.topic.trim().isEmpty
          ? DesignFieldStatus.undecided
          : DesignFieldStatus.userConfirmed,
      'problem': input.customerProblem.trim().isEmpty
          ? DesignFieldStatus.undecided
          : DesignFieldStatus.userConfirmed,
      'outcome': input.desiredOutcome.trim().isEmpty
          ? DesignFieldStatus.undecided
          : DesignFieldStatus.userConfirmed,
      'customer': input.targetCustomer.trim().isEmpty
          ? DesignFieldStatus.undecided
          : DesignFieldStatus.userConfirmed,
    };
  }

  CanonicalValue _canonicalFrom(String value, DesignFieldStatus status) {
    final v = value.trim();
    if (v.isEmpty) return CanonicalValue.undecided();
    final pending = !status.isConfirmed;
    return CanonicalValue(
      value: v,
      source: status.fieldSource,
      pending: pending,
    );
  }

  List<String> _audienceList(
    BusinessPlanInput input,
    ProjectDesignState? design,
  ) {
    if (design != null && design.selectedAudiences.isNotEmpty) {
      final labels = <String>[];
      for (final id in design.selectedAudiences) {
        final found = ProjectDesignCatalog.audiences
            .where((a) => a.id == id)
            .map((a) => a.label)
            .toList();
        if (found.isNotEmpty) {
          labels.addAll(found);
        } else if (id.trim().isNotEmpty) {
          labels.add(id.trim());
        }
      }
      if (design.customAudience.trim().isNotEmpty) {
        labels.add(design.customAudience.trim());
      }
      if (labels.isNotEmpty) return labels.toSet().toList();
    }
    return input.targetCustomer
        .split(RegExp(r'[,·/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  CanonicalValue _valueProposition({
    required CanonicalValue title,
    required CanonicalValue problem,
    required CanonicalValue customer,
    required CanonicalValue purpose,
    required String artifact,
  }) {
    if (title.isBlank || problem.isBlank || customer.isBlank) {
      return CanonicalValue.undecided();
    }
    final text =
        '${customer.value}이(가) 겪는 「${problem.value}」을(를) '
        '${ArtifactType.labelKo(artifact)} 「${title.value}」로 해결해 '
        '${purpose.isBlank ? '실행 가능한 결과' : purpose.value}을(를) 제공한다.';
    return CanonicalValue.derived(text);
  }

  ProductionSpecContract _productionSpec(
    String artifact,
    String? subtype,
    ProjectDesignState? design,
    BusinessPlanInput input,
  ) {
    final fromDesign = design?.contentSubtype ?? '';
    final contentSubtype = fromDesign.isNotEmpty
        ? fromDesign
        : (input.contentSubtype.isNotEmpty
              ? input.contentSubtype
              : (subtype ?? ''));
    final groups = ProjectDesignCatalog.productionGroupsFor(
      artifact,
      contentSubtype: contentSubtype,
    );
    final spec = <String, dynamic>{};
    final undecided = <String>[];

    Map<String, List<String>> selections = {};
    if (design != null) {
      selections = design.productionSelections;
    }

    for (final group in groups) {
      final selected = selections[group.id] ?? const <String>[];
      if (selected.isEmpty) {
        undecided.add(group.id);
        continue;
      }
      final labels = group.options
          .where((o) => selected.contains(o.id))
          .map((o) => o.label)
          .toList();
      final ids = selected;
      switch (artifact) {
        case ArtifactType.ebook:
          _putEbookSpec(spec, group.id, ids, labels);
        case ArtifactType.app:
          _putAppSpec(spec, group.id, ids, labels);
        case ArtifactType.contents:
          _putContentsSpec(spec, group.id, ids, labels, subtype);
        case ArtifactType.site:
          _putSiteSpec(spec, group.id, ids, labels);
        case ArtifactType.promoSite:
          _putPromoSpec(spec, group.id, ids, labels);
        default:
          spec[group.id] = labels;
      }
    }

    // artifact별 필수 키 기본 채움 (미선택이면 undecided)
    switch (artifact) {
      case ArtifactType.ebook:
        _ensureKey(spec, undecided, 'outputFormat');
        _ensureKey(spec, undecided, 'pageRange');
        _ensureKey(spec, undecided, 'writingStyle');
        _ensureKey(spec, undecided, 'difficulty');
        _ensureKey(spec, undecided, 'salesDirection');
      case ArtifactType.app:
        _ensureKey(spec, undecided, 'platform');
        _ensureKey(spec, undecided, 'framework');
        _ensureKey(spec, undecided, 'login');
        _ensureKey(spec, undecided, 'ads');
        _ensureKey(spec, undecided, 'payment');
        _ensureKey(spec, undecided, 'backend');
      case ArtifactType.contents:
        if (!spec.containsKey('contentType')) {
          if (subtype != null && subtype != ContentSubtype.undecided) {
            spec['contentType'] = subtype;
          } else {
            undecided.add('contentType');
          }
        }
        _ensureKey(spec, undecided, 'publishingChannel');
      case ArtifactType.site:
        spec.putIfAbsent('sitePurpose', () => 'knowledge');
        _ensureKey(spec, undecided, 'hosting');
        _ensureKey(spec, undecided, 'seo');
      case ArtifactType.promoSite:
        spec.putIfAbsent('campaignGoal', () => 'promotion');
        _ensureKey(spec, undecided, 'CTA');
        _ensureKey(spec, undecided, 'analytics');
    }

    if (input.salesPrice.trim().isNotEmpty) {
      spec['salesPrice'] = input.salesPrice.trim();
    }
    if (input.revenueModel.trim().isNotEmpty) {
      spec['revenueModel'] = input.revenueModel.trim();
    }

    return ProductionSpecContract(
      artifactType: artifact,
      artifactSubtype: subtype,
      spec: spec,
      undecidedKeys: undecided.toSet().toList()..sort(),
    );
  }

  void _ensureKey(
    Map<String, dynamic> spec,
    List<String> undecided,
    String key,
  ) {
    if (!spec.containsKey(key) && !undecided.contains(key)) {
      undecided.add(key);
    }
  }

  void _putEbookSpec(
    Map<String, dynamic> spec,
    String groupId,
    List<String> ids,
    List<String> labels,
  ) {
    switch (groupId) {
      case 'format':
        spec['outputFormat'] = ids;
      case 'pages':
        spec['pageRange'] = labels.isNotEmpty ? labels.first : ids.first;
      case 'tone':
        spec['writingStyle'] = labels.isNotEmpty ? labels.first : ids.first;
      case 'level':
        spec['difficulty'] = labels.isNotEmpty ? labels.first : ids.first;
      case 'pricing':
        spec['salesDirection'] = labels.isNotEmpty ? labels.first : ids.first;
      default:
        spec[groupId] = labels;
    }
  }

  void _putAppSpec(
    Map<String, dynamic> spec,
    String groupId,
    List<String> ids,
    List<String> labels,
  ) {
    switch (groupId) {
      case 'platform':
        spec['platform'] = ids;
        if (ids.contains('flutter')) {
          spec['framework'] = 'flutter';
        } else {
          spec.putIfAbsent('framework', () => 'undecided');
        }
      case 'monetization':
        spec['ads'] = ids.contains('ads');
        spec['payment'] = ids.contains('iap');
        spec['login'] = ids.contains('login');
        spec['backend'] = ids.contains('firebase') ? 'firebase' : 'undecided';
        spec['notifications'] = 'undecided';
      default:
        spec[groupId] = labels;
    }
  }

  void _putContentsSpec(
    Map<String, dynamic> spec,
    String groupId,
    List<String> ids,
    List<String> labels,
    String? subtype,
  ) {
    switch (groupId) {
      case 'channel':
        spec['publishingChannel'] = ids;
        if (ids.contains('song')) spec['contentType'] = ContentSubtype.song;
        if (ids.contains('shorts')) {
          spec['contentType'] = ContentSubtype.shorts;
        }
        if (ids.contains('youtube')) spec['format'] = 'youtube';
        if (ids.contains('voice')) spec['voice'] = true;
        if (ids.contains('subtitle')) spec['subtitles'] = true;
        spec.putIfAbsent(
          'contentType',
          () => subtype ?? ContentSubtype.undecided,
        );
        spec.putIfAbsent('duration', () => 'undecided');
      default:
        spec[groupId] = labels;
    }
  }

  void _putSiteSpec(
    Map<String, dynamic> spec,
    String groupId,
    List<String> ids,
    List<String> labels,
  ) {
    switch (groupId) {
      case 'stack':
        spec['hosting'] = ids.contains('firebase_hosting')
            ? 'firebase_hosting'
            : 'undecided';
        spec['seo'] = ids.contains('seo');
        spec['search'] = ids.contains('seo');
        spec['contentStructure'] = ids.contains('admin')
            ? 'admin_managed'
            : 'static_pages';
        spec['category'] = 'knowledge';
        if (ids.contains('flutter_web')) {
          spec['framework'] = 'flutter_web';
        }
      default:
        spec[groupId] = labels;
    }
  }

  void _putPromoSpec(
    Map<String, dynamic> spec,
    String groupId,
    List<String> ids,
    List<String> labels,
  ) {
    switch (groupId) {
      case 'promo':
        spec['landingStructure'] = ids.contains('landing')
            ? 'single_landing'
            : 'undecided';
        spec['CTA'] = ids.contains('cta') ? 'primary_cta' : 'undecided';
        spec['analytics'] = ids.contains('analytics');
        spec['conversionGoal'] = ids.contains('cta')
            ? 'lead_or_download'
            : 'undecided';
        spec['targetProduct'] = 'undecided';
        if (ids.contains('firebase_hosting')) {
          spec['hosting'] = 'firebase_hosting';
        }
      default:
        spec[groupId] = labels;
    }
  }

  ScopeContract _scope(
    String artifact,
    String? subtype,
    ProductionSpecContract production,
    List<String> topics,
  ) {
    final included = <String>[
      '대상 고객·핵심 문제·기대 결과 명시',
      '결과물 유형: ${ArtifactType.labelKo(artifact)}',
      if (subtype != null && subtype != ContentSubtype.undecided)
        '콘텐츠 하위유형: ${ContentSubtype.labelKo(subtype)}',
      ...topics.take(5).map((t) => '주제: $t'),
      ...production.spec.entries
          .where((e) => e.value != null && '${e.value}' != 'undecided')
          .take(8)
          .map((e) => '${e.key}: ${e.value}'),
    ];
    final excluded = <String>[
      '승인 없는 배포·판매 등록',
      '승인 없는 git push',
      '사실·경험·수익 수치의 임의 창작',
      '현재 단계 외 확장 작업',
    ];
    final required = <String>['확정 제목·고객·문제·목적 반영', '품질 기준·AI Guard 준수'];
    final optional = <String>[
      if (production.undecidedKeys.isNotEmpty)
        '미정 제작 옵션: ${production.undecidedKeys.join(', ')}',
    ];
    final undecided = [...production.undecidedKeys.map((k) => 'production.$k')];
    return ScopeContract(
      included: included,
      excluded: excluded,
      requiredFeatures: required,
      optionalFeatures: optional,
      undecidedItems: undecided,
    );
  }

  List<QualityCriterion> _qualityCriteria(String artifact) {
    final common = <QualityCriterion>[
      const QualityCriterion(
        id: 'accuracy',
        label: '정확성',
        description: '사실·수치·출처를 왜곡하지 않는다.',
      ),
      const QualityCriterion(
        id: 'usefulness',
        label: '유용성',
        description: '대상 고객이 바로 적용할 수 있는 실행 정보를 포함한다.',
      ),
      const QualityCriterion(
        id: 'professionalism',
        label: '전문성',
        description: '문체·구조·용어가 결과물 수준에 맞다.',
      ),
      const QualityCriterion(
        id: 'originality',
        label: '독창성',
        description: '차별화 포인트가 드러나며 단순 복제가 아니다.',
      ),
      const QualityCriterion(
        id: 'copyrightSafety',
        label: '저작권 안전',
        description: '타인의 저작물·상표를 무단 사용하지 않는다.',
      ),
      const QualityCriterion(
        id: 'privacySafety',
        label: '개인정보 안전',
        description: '비밀번호·개인식별정보를 저장·노출하지 않는다.',
      ),
      const QualityCriterion(
        id: 'hallucinationControl',
        label: '환각 통제',
        description: '확인되지 않은 경험·수익·성과를 창작하지 않는다.',
      ),
      const QualityCriterion(
        id: 'completeness',
        label: '완성도',
        description: '필수 산출물과 검수 기준을 충족한다.',
      ),
      const QualityCriterion(
        id: 'userExperience',
        label: '사용자 경험',
        description: '읽기/사용 흐름이 대상 고객 기준으로 자연스럽다.',
        required: false,
      ),
    ];
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.app:
        return [
          ...common,
          const QualityCriterion(
            id: 'appFlowIntegrity',
            label: '앱 흐름 무결성',
            description: '핵심 사용자 행동이 끊기지 않는다.',
          ),
          const QualityCriterion(
            id: 'appProductionUi',
            label: 'Production UI/UX',
            description:
                '모바일 정보 밀도·타이포 계층·spacing token·light/dark·overflow 0·empty/loading/error 상태를 갖춘다.',
          ),
          const QualityCriterion(
            id: 'appFeatureDensity',
            label: '기능 밀도',
            description: '앱 목적 대비 충분한 실제 workflow와 기능을 제공한다. 실행만 되는 수준은 금지.',
          ),
          const QualityCriterion(
            id: 'appAccessibility',
            label: '접근성',
            description: 'text scale·대비·터치 영역·의미 있는 라벨을 기본 수준 이상 만족한다.',
          ),
          const QualityCriterion(
            id: 'appPrivacyMinimization',
            label: '개인정보·권한 최소화',
            description: '목적에 필요한 권한만 요청하고 불필요한 데이터 수집을 하지 않는다.',
          ),
        ];
      case ArtifactType.contents:
        return [
          ...common,
          const QualityCriterion(
            id: 'contentChannelFit',
            label: '채널 적합성',
            description: '길이·형식·자막이 공개 채널에 맞다.',
          ),
        ];
      default:
        return common;
    }
  }

  List<AiGuardRule> _aiGuards(String artifact) {
    final common = <AiGuardRule>[
      const AiGuardRule(id: 'no_fabricated_facts', rule: '사실 창작 금지'),
      const AiGuardRule(
        id: 'no_fabricated_experience',
        rule: '사용자의 실제 경험 임의 생성 금지',
      ),
      const AiGuardRule(id: 'no_guaranteed_revenue', rule: '확인되지 않은 수익 보장 금지'),
      const AiGuardRule(id: 'no_secrets_storage', rule: '개인정보/비밀번호 저장 금지'),
      const AiGuardRule(id: 'no_unapproved_deploy', rule: '승인 없는 배포 금지'),
      const AiGuardRule(id: 'no_unapproved_sales', rule: '승인 없는 판매 등록 금지'),
      const AiGuardRule(
        id: 'no_unapproved_git_push',
        rule: '승인 없는 git push 금지',
      ),
      const AiGuardRule(id: 'stay_in_stage', rule: '현재 단계 외 작업 금지'),
      const AiGuardRule(
        id: 'no_template_overwrite',
        rule: '사용자 확정값을 generic/template 값으로 덮어쓰기 금지',
      ),
    ];
    final a = ArtifactType.normalize(artifact);
    final specific = <AiGuardRule>[];
    switch (a) {
      case ArtifactType.ebook:
        specific.add(
          const AiGuardRule(
            id: 'ebook_keep_title',
            rule: '확정된 전자책 제목·독자·문제를 템플릿 문구로 대체 금지',
            scope: 'ebook',
          ),
        );
      case ArtifactType.app:
        specific.add(
          const AiGuardRule(
            id: 'app_scope_lock',
            rule: '승인되지 않은 플랫폼·결제·로그인 범위를 임의 확장 금지',
            scope: 'app',
          ),
        );
      case ArtifactType.contents:
        specific.add(
          const AiGuardRule(
            id: 'contents_channel_lock',
            rule: '확정되지 않은 채널·형식으로 임의 공개 금지',
            scope: 'contents',
          ),
        );
      case ArtifactType.site:
        specific.add(
          const AiGuardRule(
            id: 'site_no_live_without_approval',
            rule: '승인 없이 프로덕션 호스팅 배포 금지',
            scope: 'site',
          ),
        );
      case ArtifactType.promoSite:
        specific.add(
          const AiGuardRule(
            id: 'promo_no_false_claims',
            rule: '과장 광고·허위 후기 생성 금지',
            scope: 'promo_site',
          ),
        );
    }
    return [...common, ...specific];
  }

  WorkflowContract _workflow(
    String artifact,
    String? subtype,
    List<WorkflowStep> legacySteps,
  ) {
    final stages = <WorkflowStageDef>[
      for (final step in legacySteps)
        if (step.applicable)
          WorkflowStageDef(
            id: step.id,
            order: step.order,
            title: step.title,
            purpose: step.notes.isNotEmpty ? step.notes : step.title,
            completionCriteria: step.completionCriteria.isEmpty
                ? const []
                : [step.completionCriteria],
            requiresApproval:
                step.id.contains('approv') ||
                step.title.contains('승인') ||
                step.order >= 16,
          ),
    ];
    final start = stages.isNotEmpty ? stages.first.id : 'intake';
    final workflowId =
        'sotong24_${ArtifactType.primaryTrackId(artifact)}'
        '${subtype != null && subtype.isNotEmpty ? '_$subtype' : ''}';
    return WorkflowContract(
      workflowId: workflowId,
      currentStage: start,
      startStage: start,
      stages: stages,
      approvalPolicy: 'stage_gate',
      deploymentPolicy: 'manual_approval_required',
    );
  }

  List<String> _requiredArtifacts(String artifact, String? subtype) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return const ['outline', 'chapter_draft', 'export_pdf_or_epub'];
      case ArtifactType.app:
        return const [
          'mvp_screen_map',
          'core_feature_demo',
          'navigation_structure',
          'ux_state_matrix',
          'device_review_criteria',
        ];
      case ArtifactType.contents:
        if (subtype == ContentSubtype.song) {
          return const ['lyrics_or_demo_audio'];
        }
        if (subtype == ContentSubtype.shorts ||
            subtype == ContentSubtype.video) {
          return const ['storyboard_or_draft_video'];
        }
        return const ['content_draft'];
      case ArtifactType.site:
        return const ['ia_menu', 'first_page_draft'];
      case ArtifactType.promoSite:
        return const ['landing_draft', 'cta_path'];
      default:
        return const ['minimum_deliverable_draft'];
    }
  }

  String _professionalDirection(String artifact, String? subtype) {
    switch (ArtifactType.normalize(artifact)) {
      case ArtifactType.ebook:
        return '목차·사례·실행표 중심의 전자책 전문 제작';
      case ArtifactType.app:
        return 'PRODUCTION 등급 Flutter/Android 앱 — MVP/Prototype 완료 금지, 실사용·실기기 검증 전제';
      case ArtifactType.contents:
        return '채널 맞춤 콘텐츠 제작 (${subtype == null ? '유형 미정' : ContentSubtype.labelKo(subtype)})';
      case ArtifactType.site:
        return '지식 구조·SEO를 갖춘 사이트 1차 공개';
      case ArtifactType.promoSite:
        return '전환 CTA 중심 홍보 랜딩 제작';
      default:
        return '결과물 유형에 맞는 전문 제작 방향';
    }
  }
}
