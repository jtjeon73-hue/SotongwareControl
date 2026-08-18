import '../data/planning_choice_catalog.dart';
import '../data/project_design_catalog.dart';
import '../models/business_planning.dart';
import '../services/business_planning_store.dart';
import '../services/instruction_contract_validator.dart';
import '../services/plan_execution_status.dart';

/// 작업지시 제작소 — 운영 UI 표시 helper.
class WorkInstructionWorkshopPresentation {
  WorkInstructionWorkshopPresentation._();

  /// Sotong24Work 원격 전송 성공(wasTransferred)만 목록에 포함.
  static List<BusinessPlanDocument> successfulTransfers(
    List<BusinessPlanDocument> all,
  ) {
    final latest = BusinessPlanningStore.latestByInstructionId(all);
    final sent = latest.where((p) => p.wasTransferred).toList();
    sent.sort((a, b) {
      final ta =
          DateTime.tryParse(a.lastTransferAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          DateTime.tryParse(b.lastTransferAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return sent;
  }

  /// 전송 목록용 간단 상태 (승인/보완 조작 없음).
  static String transferListBriefStatus(PlanExecutionSnapshot exec) {
    if (!exec.isPostTransfer) return '전송 완료';
    switch (exec.runState) {
      case PlanRunState.awaitingApproval:
        return '승인 대기';
      case PlanRunState.revisionRequested:
        return '보완 요청';
      case PlanRunState.working:
      case PlanRunState.reworking:
        if (exec.productionCurrentStage > 0) {
          return '진행 중 · ${exec.productionCurrentStage}단계';
        }
        return '진행 중';
      case PlanRunState.completed:
        return '완료';
      case PlanRunState.error:
        return '오류';
      default:
        if (exec.hasActualExecution && exec.productionCurrentStage > 0) {
          return '진행 중 · ${exec.productionCurrentStage}단계';
        }
        return '전송 완료';
    }
  }

  static String humanizeAudienceOrField(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final parts = text.split(RegExp(r'[,·/]')).map((e) => e.trim());
    final labels = <String>[];
    for (final part in parts) {
      if (part.isEmpty) continue;
      labels.add(_labelForToken(part));
    }
    return labels.isEmpty ? text : labels.join(', ');
  }

  static String _labelForToken(String token) {
    for (final a in ProjectDesignCatalog.audiences) {
      if (a.id == token) return a.label;
    }
    for (final step in [
      PlanningChoiceSteps.audiences,
      PlanningChoiceSteps.domains,
      PlanningChoiceSteps.deliverables,
      PlanningChoiceSteps.problems,
      PlanningChoiceSteps.outcomes,
      PlanningChoiceSteps.formats,
      PlanningChoiceSteps.scales,
      PlanningChoiceSteps.durations,
      PlanningChoiceSteps.budgets,
      PlanningChoiceSteps.salesModes,
    ]) {
      final label = labelForChoice(step, token);
      if (label != token) return label;
    }
    return token;
  }

  static String productionMethodLabel({
    required bool aiPilotEnabled,
    required String artifactType,
  }) {
    if (aiPilotEnabled &&
        ArtifactType.normalize(artifactType) == ArtifactType.ebook) {
      return 'AI 자동 제작 (승인 후 단계 진행)';
    }
    return '수동·혼합 제작';
  }

  static String approvalModeLabel({required bool approvalRequired}) {
    return approvalRequired ? '단계별 승인' : '자동 진행';
  }

  static String qualityLevelLabel(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '—';
    return _labelForToken(v);
  }

  static String blockedTransferButtonLabel() => '보내기 전 확인 필요';

  static String validationHeadline(ContractValidationResult result) {
    if (result.canTransfer) {
      return result.level == ContractValidationLevel.warning
          ? '확인 후 보낼 수 있습니다'
          : '보낼 준비가 되었습니다';
    }
    return '작업지시를 보내기 전에 확인이 필요합니다';
  }

  static List<String> validationProblemLines(ContractValidationResult result) {
    final issues = result.blockers.isNotEmpty
        ? result.blockers
        : result.issues.where((i) => !result.canTransfer).toList();
    if (issues.isEmpty && result.warnings.isNotEmpty) {
      return result.warnings.take(6).map((i) => '• ${_humanIssue(i)}').toList();
    }
    return issues.take(8).map((i) => '• ${_humanIssue(i)}').toList();
  }

  static String _humanIssue(ContractValidationIssue issue) {
    final field = humanizeAudienceOrField(issue.field);
    final reason = issue.reason.trim();
    if (field.isEmpty || field == issue.field) return reason;
    return '$field: $reason';
  }

  /// schema 기반 최소 completeness (향후 품질 점검 확장용).
  static List<InstructionQualityHint> qualityHints(WorkInstruction wi) {
    final hints = <InstructionQualityHint>[];
    void add(String area, String status, {String? note}) {
      hints.add(InstructionQualityHint(area: area, status: status, note: note));
    }

    add('대상 고객', wi.targetCustomer.trim().length >= 4 ? '명확' : '보완 필요');
    add('제작 목적', wi.businessPurpose.trim().length >= 6 ? '명확' : '보완 필요');
    add('핵심 문제', wi.customerProblem.trim().length >= 8 ? '명확' : '보완 필요');

    final c = wi.contract;
    if (c != null) {
      final specCount = c.productionSpec.spec.length;
      add('분량·제작 조건', specCount >= 2 ? '명확' : '부족');
      if (c.qualityCriteria.isEmpty) {
        add('품질 기준', '부족');
      } else {
        add('품질 기준', '명확');
      }
    } else {
      add('제작 조건', 'legacy — 상세 contract 없음', note: '고급 원문 참고');
    }

    return hints;
  }

  static String formatTransferTime(String? iso) {
    final t = DateTime.tryParse(iso ?? '');
    if (t == null) return '—';
    final local = t.toLocal();
    final now = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '오늘 $hh:$mm';
    }
    return '${local.month}/${local.day} $hh:$mm';
  }

  /// Wizard 7단계 감사용 메타 (코드 정리 보고).
  static const wizardAuditSteps = [
    _WizardAuditStep(
      step: '1/7',
      title: '사업유형 선택',
      items: '전자책·앱·콘텐츠·지식사이트·홍보사이트',
      choices: 'artifactType + contentSubtype(콘텐츠)',
      customInput: '콘텐츠 기타 subtype',
      fields: 'artifactType, contentSubtype, deliverableTypes',
      notes: '역할 핵심 — 유지',
    ),
    _WizardAuditStep(
      step: '2/7',
      title: '대상 고객',
      items: 'DesignAudience 카드 + customAudience',
      choices: '다중 선택 + 직접 입력',
      customInput: 'customAudience 텍스트',
      fields: 'selectedAudiences → targetCustomer',
      notes: '선택+직접입력 OK — 다음 세션에서 라벨 검증',
    ),
    _WizardAuditStep(
      step: '3/7',
      title: '핵심 내용',
      items: 'ConceptPicker — 주제/컨셉',
      choices: '추천 컨셉 + 사용자 추가 concept',
      customInput: 'userAddedConcepts',
      fields: 'selectedConceptIds, topic(자동문장)',
      notes: '직접 추가 concept 지원',
    ),
    _WizardAuditStep(
      step: '4/7',
      title: '세부 기획',
      items: 'topic, customerProblem, desiredOutcome, designMemo',
      choices: 'AI 제안 문장 + 사용자 편집',
      customInput: '각 필드 free text',
      fields: 'topic, customerProblem, desiredOutcome, designMemo',
      notes: '다음 세션에서 분량·사례 필드 충분성 검토',
    ),
    _WizardAuditStep(
      step: '5/7',
      title: '제작 설정',
      items: 'productionGroupsFor — 형식·분량·문체·난이도 등',
      choices: 'artifact별 option group',
      customInput: '그룹별 선택만 (free text 옵션 없음)',
      fields: 'productionSelections → constraints/notes',
      notes: '제작 언어(ko/en) field 아직 없음 — 설계 필요',
    ),
    _WizardAuditStep(
      step: '6/7',
      title: '최종 확인',
      items: '확정 버튼 + 종합 판정',
      choices: 'planningConfirmed',
      customInput: '—',
      fields: 'planningConfirmed, combinedDirection',
      notes: 'internal enum label 변환 이번 작업에서 개선',
    ),
    _WizardAuditStep(
      step: '7/7',
      title: '작업지시 생성·전송',
      items: '작업지시서 생성 + Agent 전송',
      choices: '—',
      customInput: '—',
      fields: 'WorkInstruction + remote deliver',
      notes: '전송 성공만 목록 표시 — 이번 작업',
    ),
  ];
}

enum InstructionCreateButtonKind { create, completed, recreate }

/// 작업지시서 생성 버튼·스낵바 (일반 운영 UX).
class InstructionCreateUx {
  InstructionCreateUx._();

  static const createdMessage = '작업지시서 생성 완료';
  static const alreadyCreatedMessage = '이미 작업지시서가 생성되었습니다.';
  static const jsonDownloadedMessage = 'JSON 파일을 다운로드했습니다.';
  static const createLabel = '작업지시서 생성';
  static const completedLabel = '✓ 작업지시서 생성 완료';
  static const recreateLabel = '변경사항으로 작업지시서 다시 생성';

  static InstructionCreateButtonKind kind({
    required bool generated,
    required bool stale,
  }) {
    if (!generated) return InstructionCreateButtonKind.create;
    if (stale) return InstructionCreateButtonKind.recreate;
    return InstructionCreateButtonKind.completed;
  }

  static String label(InstructionCreateButtonKind kind) {
    switch (kind) {
      case InstructionCreateButtonKind.create:
        return createLabel;
      case InstructionCreateButtonKind.completed:
        return completedLabel;
      case InstructionCreateButtonKind.recreate:
        return recreateLabel;
    }
  }

  static bool enabled(
    InstructionCreateButtonKind kind, {
    required bool canCreate,
  }) {
    if (!canCreate) return false;
    return kind != InstructionCreateButtonKind.completed;
  }

  /// 일반 운영 화면에 보이면 안 되는 DevWorkDoc/수동가져오기 표현.
  static bool isInternalOperatorMessage(String message) {
    return message.contains('JSON 다운로드 완료') ||
        message.contains('수동 가져오기 대기') ||
        message.contains('전달됨 아님') ||
        message.contains('전달 된 아님');
  }
}

class InstructionQualityHint {
  const InstructionQualityHint({
    required this.area,
    required this.status,
    this.note,
  });

  final String area;
  final String status;
  final String? note;
}

class _WizardAuditStep {
  const _WizardAuditStep({
    required this.step,
    required this.title,
    required this.items,
    required this.choices,
    required this.customInput,
    required this.fields,
    required this.notes,
  });

  final String step;
  final String title;
  final String items;
  final String choices;
  final String customInput;
  final String fields;
  final String notes;
}
