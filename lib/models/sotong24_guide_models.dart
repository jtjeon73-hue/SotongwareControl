import '../data/sotong24_workflows.dart';

/// 단계별 제작 매뉴얼 보강 필드 (workflow stageId로 연결).
class Sotong24StageGuideEnrichment {
  const Sotong24StageGuideEnrichment({
    required this.whyNeeded,
    required this.mainTasks,
    required this.inputs,
    required this.deliverables,
    required this.qualityCriteria,
    required this.approvalCriteria,
    required this.commonProblems,
    required this.cautions,
    required this.completionConditions,
  });

  final String whyNeeded;
  final List<String> mainTasks;
  final List<String> inputs;
  final List<String> deliverables;
  final List<String> qualityCriteria;
  final List<String> approvalCriteria;
  final List<String> commonProblems;
  final List<String> cautions;
  final List<String> completionConditions;

  /// workflow 단계만으로도 가이드가 비지 않도록 기본값 생성.
  factory Sotong24StageGuideEnrichment.fromStage(Sotong24WorkflowStageDef s) {
    return Sotong24StageGuideEnrichment(
      whyNeeded: s.purpose,
      mainTasks: [s.workDescription],
      inputs: const ['이전 단계 산출물', '작업지시/기획 정보'],
      deliverables: s.outputs
          .split(RegExp(r'[·,/]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      qualityCriteria: s.qualityChecks,
      approvalCriteria: s.userChecks,
      commonProblems: const ['산출물 누락', '기준 불명확', '피드백 미반영'],
      cautions: const ['이전 단계 미완료 상태로 진행하지 말 것'],
      completionConditions: s.userChecks.isEmpty
          ? const ['단계 목적 달성 확인']
          : s.userChecks,
    );
  }
}

/// workflow 단계 + 가이드 보강 = 화면용 단계 가이드.
class Sotong24StageGuide {
  const Sotong24StageGuide({
    required this.stage,
    required this.enrichment,
  });

  final Sotong24WorkflowStageDef stage;
  final Sotong24StageGuideEnrichment enrichment;

  String get stageId => stage.id;
  int get order => stage.order;
  String get name => stage.name;
  String get purpose => stage.purpose;
  String get whyNeeded => enrichment.whyNeeded;
  List<String> get mainTasks => enrichment.mainTasks;
  String get aiWork => stage.aiWork;
  List<String> get humanChecks => stage.userChecks;
  List<String> get inputs => enrichment.inputs;
  List<String> get deliverables => enrichment.deliverables.isNotEmpty
      ? enrichment.deliverables
      : [stage.outputs];
  List<String> get qualityCriteria => enrichment.qualityCriteria.isNotEmpty
      ? enrichment.qualityCriteria
      : stage.qualityChecks;
  List<String> get approvalCriteria => enrichment.approvalCriteria;
  List<String> get commonProblems => enrichment.commonProblems;
  List<String> get cautions => enrichment.cautions;
  List<String> get completionConditions => enrichment.completionConditions;
  String get nextStep => stage.nextHint;
  bool get approvalTypicallyRequired => stage.approvalTypicallyRequired;

  bool matchesQuery(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool hit(String s) => s.toLowerCase().contains(q);
    bool hitList(List<String> list) => list.any(hit);
    return hit(name) ||
        hit(purpose) ||
        hit(whyNeeded) ||
        hit(aiWork) ||
        hit(nextStep) ||
        hitList(mainTasks) ||
        hitList(inputs) ||
        hitList(deliverables) ||
        hitList(qualityCriteria) ||
        hitList(approvalCriteria) ||
        hitList(commonProblems) ||
        hitList(cautions) ||
        hitList(completionConditions) ||
        hitList(humanChecks) ||
        hit(stageId);
  }
}

/// 사업(제품) 단위 표준 제작 가이드.
class Sotong24ProductGuide {
  const Sotong24ProductGuide({
    required this.id,
    required this.label,
    required this.guideTitle,
    required this.goal,
    required this.flowOverview,
    required this.keyDeliverables,
    required this.checklist,
    required this.workflow,
    required this.stages,
    this.subtypeNotes = const {},
    this.contentSubtype = '',
  });

  final String id;
  final String label;
  final String guideTitle;
  final String goal;
  final List<String> flowOverview;
  final List<String> keyDeliverables;
  final List<String> checklist;
  final Sotong24WorkflowDef workflow;
  final List<Sotong24StageGuide> stages;
  final String contentSubtype;

  /// contents 하위 유형별 추가 체크/주의 (공통 단계와 병행).
  final Map<String, List<String>> subtypeNotes;

  int get totalStages => stages.length;

  Sotong24StageGuide? byStageId(String id) {
    for (final s in stages) {
      if (s.stageId == id) return s;
    }
    return null;
  }

  Sotong24StageGuide? byOrder(int order) {
    for (final s in stages) {
      if (s.order == order) return s;
    }
    return null;
  }

  List<Sotong24StageGuide> search(String query) =>
      stages.where((s) => s.matchesQuery(query)).toList(growable: false);

  List<String> subtypeExtraNotes(String subtype) {
    if (subtype.isEmpty) return const [];
    return subtypeNotes[subtype] ?? const [];
  }
}
