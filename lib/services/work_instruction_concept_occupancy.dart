import '../data/concept_catalog.dart';
import '../models/business_planning.dart';
import '../models/concept_candidate.dart';
import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import 'plan_execution_index.dart';
import 'plan_execution_status.dart';
import 'operational_evidence_tags.dart';
import 'sotong24_workshop_presentation.dart';

enum ConceptWorkState { available, inProgress, completed }

class ConceptOccupancyView {
  const ConceptOccupancyView({
    required this.state,
    required this.selectable,
    required this.badgeLabel,
    required this.guidance,
  });

  final ConceptWorkState state;
  final bool selectable;
  final String badgeLabel;
  final String guidance;

  static const available = ConceptOccupancyView(
    state: ConceptWorkState.available,
    selectable: true,
    badgeLabel: '',
    guidance: '',
  );

  static const inProgress = ConceptOccupancyView(
    state: ConceptWorkState.inProgress,
    selectable: false,
    badgeLabel: '제작 중',
    guidance: '현재 AI 제작공정에서 진행 중인 주제입니다.',
  );

  static const completed = ConceptOccupancyView(
    state: ConceptWorkState.completed,
    selectable: false,
    badgeLabel: '제작 완료',
    guidance: '이미 제작 완료된 주제입니다.\n새 버전 제작은 별도 경로에서 시작할 수 있습니다.',
  );

  bool get isOccupied => !selectable;
}

class _OccupancyRecord {
  const _OccupancyRecord(this.state);

  final ConceptWorkState state;
}

/// STEP 3 컨셉 카드의 제작 중/완료 판정.
///
/// 안정 키: artifactType + conceptId(catalog id 또는 `seed__artifact`).
/// conceptId가 없으면 artifactType + normalized topic.
/// 제목만 비교할 때는 audience 교집합이 있으면 함께 본다.
class ConceptOccupancyIndex {
  ConceptOccupancyIndex._(this._byKey);

  final Map<String, _OccupancyRecord> _byKey;

  static final _punct = RegExp(r'''[.,;:!?·~"'“”‘’()\[\]{}/\-_\\]+''');
  static final _spaces = RegExp(r'\s+');

  static String normalizeTopic(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(_punct, ' ');
    s = s.replaceAll(_spaces, ' ').trim();
    return s;
  }

  static List<String> conceptIdsFromInput(BusinessPlanInput input) {
    final ids = <String>[];
    final ws = input.wizardSelections;
    if (ws == null) return ids;
    final answers = ws['artifactAnswers'];
    if (answers is Map) {
      final list = answers['designConcepts'] ?? answers['designTopics'];
      if (list is List) {
        for (final e in list) {
          final id = '$e'.trim();
          if (id.isNotEmpty) ids.add(id);
        }
      }
    }
    final selected = ws['selectedConcepts'];
    if (selected is List) {
      for (final e in selected) {
        if (e is Map) {
          final id = '${e['id'] ?? ''}'.trim();
          if (id.isNotEmpty) ids.add(id);
        } else {
          final id = '$e'.trim();
          if (id.isNotEmpty) ids.add(id);
        }
      }
    }
    return ids.toSet().toList();
  }

  static List<String> audiencesFromInput(BusinessPlanInput input) {
    final ws = input.wizardSelections;
    if (ws != null) {
      final answers = ws['artifactAnswers'];
      if (answers is Map) {
        final list = answers['targetCustomer'] ?? answers['_legacy_audiences'];
        if (list is List) {
          return list
              .map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty && e != 'custom')
              .toList();
        }
      }
    }
    final t = input.targetCustomer.trim();
    return t.isEmpty ? const [] : [t];
  }

  static ConceptOccupancyIndex build({
    required List<BusinessPlanDocument> plans,
    List<Sotong24RemoteProject> projects = const [],
    List<RemoteJobDoc> jobs = const [],
    PlanExecutionIndex? execution,
  }) {
    final byKey = <String, _OccupancyRecord>{};
    final exec =
        execution ??
        PlanExecutionIndex.fromRemoteProjects(projects, jobs: jobs);

    for (final plan in plans) {
      if (!_planBlocksDuplicates(plan)) continue;
      final snap = exec.snapshotFor(plan);
      final state = _stateFromSnapshot(snap, plan: plan);
      if (state == ConceptWorkState.available) continue;
      _indexPlan(byKey, plan, state);
    }

    for (final project in Sotong24WorkshopPresentation.operationalProjects(
      projects,
    )) {
      final state = _stateFromRemoteProject(project);
      if (state == ConceptWorkState.available) continue;
      _indexTitle(
        byKey,
        artifact: project.productType,
        title: project.title,
        state: state,
      );
    }

    for (final job in jobs) {
      final state = _stateFromJob(job);
      if (state == ConceptWorkState.available) continue;
      _indexTitle(
        byKey,
        artifact: ArtifactType.normalize(job.type),
        title: job.title,
        state: state,
      );
    }

    return ConceptOccupancyIndex._(byKey);
  }

  ConceptOccupancyView viewFor({
    String? conceptId,
    required String artifactType,
    String title = '',
    List<String> audiences = const [],
  }) {
    final artifact = ArtifactType.normalize(artifactType);
    ConceptWorkState? best;
    for (final key in _lookupKeys(
      artifact: artifact,
      conceptId: conceptId,
      title: title,
      audiences: audiences,
    )) {
      final hit = _byKey[key];
      if (hit == null) continue;
      best = _prefer(best, hit.state);
    }
    switch (best) {
      case ConceptWorkState.inProgress:
        return ConceptOccupancyView.inProgress;
      case ConceptWorkState.completed:
        return ConceptOccupancyView.completed;
      case ConceptWorkState.available:
      case null:
        return ConceptOccupancyView.available;
    }
  }

  ConceptOccupancyView viewForCandidate(
    ConceptCandidate concept, {
    required String artifactType,
    List<String> audiences = const [],
  }) {
    return viewFor(
      conceptId: concept.id,
      artifactType: artifactType,
      title: concept.title,
      audiences: audiences.isNotEmpty ? audiences : concept.targetCustomers,
    );
  }

  static bool _planBlocksDuplicates(BusinessPlanDocument plan) {
    if (plan.isLibraryArchived || plan.isLibraryTrashed) return false;
    // A transferred local plan is only a soft mirror. Once reconciliation has
    // confirmed its remote operation is gone, it cannot occupy a concept.
    if (plan.tags.contains(OperationalEvidenceTags.staleRemoteMissing)) {
      return false;
    }
    final status = PlanningStatus.normalize(plan.status);
    if (status == PlanningStatus.archived || status == PlanningStatus.trashed) {
      return false;
    }
    if (status == PlanningStatus.transferFailed) return false;
    return plan.wasTransferred ||
        status == PlanningStatus.inProgress ||
        status == PlanningStatus.completed ||
        status == PlanningStatus.imported;
  }

  static ConceptWorkState _stateFromSnapshot(
    PlanExecutionSnapshot snap, {
    required BusinessPlanDocument plan,
  }) {
    final status = PlanningStatus.normalize(plan.status);
    if (status == PlanningStatus.completed ||
        snap.runState == PlanRunState.completed) {
      return ConceptWorkState.completed;
    }
    if (snap.runState == PlanRunState.error ||
        snap.runState == PlanRunState.stopped ||
        snap.runState == PlanRunState.cancelled) {
      return ConceptWorkState.available;
    }
    if (plan.wasTransferred ||
        snap.isPostTransfer ||
        status == PlanningStatus.inProgress) {
      return ConceptWorkState.inProgress;
    }
    return ConceptWorkState.available;
  }

  static ConceptWorkState _stateFromRemoteProject(Sotong24RemoteProject p) {
    if (p.status == Sotong24WorkStatus.completed) {
      return ConceptWorkState.completed;
    }
    if (p.status == Sotong24WorkStatus.error) {
      return ConceptWorkState.available;
    }
    return ConceptWorkState.inProgress;
  }

  static ConceptWorkState _stateFromJob(RemoteJobDoc job) {
    switch (job.status) {
      case 'completed':
      case 'approved':
        return ConceptWorkState.completed;
      case 'failed':
      case 'cancelled':
      case 'paused':
        return ConceptWorkState.available;
      default:
        return ConceptWorkState.inProgress;
    }
  }

  static void _indexPlan(
    Map<String, _OccupancyRecord> byKey,
    BusinessPlanDocument plan,
    ConceptWorkState state,
  ) {
    final artifact = ArtifactType.normalize(plan.input.resolvedArtifactType);
    final audiences = audiencesFromInput(plan.input);
    final conceptIds = conceptIdsFromInput(plan.input);
    for (final id in conceptIds) {
      _put(byKey, _conceptKey(artifact, id), state);
      final seed = _seedId(id);
      if (seed != id) {
        _put(byKey, _conceptKey(artifact, seed), state);
      }
    }
    _indexTitle(
      byKey,
      artifact: artifact,
      title: plan.input.topic,
      state: state,
      audiences: audiences,
    );
    final wiTitle = plan.instruction?.businessIdea ?? '';
    if (wiTitle.trim().isNotEmpty) {
      _indexTitle(
        byKey,
        artifact: artifact,
        title: wiTitle,
        state: state,
        audiences: audiences,
      );
    }
  }

  static void _indexTitle(
    Map<String, _OccupancyRecord> byKey, {
    required String artifact,
    required String title,
    required ConceptWorkState state,
    List<String> audiences = const [],
  }) {
    final normalized = normalizeTopic(title);
    if (normalized.isEmpty) return;
    final art = ArtifactType.normalize(artifact);
    _put(byKey, _topicKey(art, normalized), state);
    if (audiences.isNotEmpty) {
      final audienceKey = _audienceKey(audiences);
      _put(byKey, _topicAudienceKey(art, normalized, audienceKey), state);
    }
    final catalogId = _catalogConceptId(artifact: art, title: title);
    if (catalogId != null) {
      _put(byKey, _conceptKey(art, catalogId), state);
      _put(byKey, _conceptKey(art, _seedId(catalogId)), state);
    }
  }

  static String? _catalogConceptId({
    required String artifact,
    required String title,
  }) {
    final n = normalizeTopic(title);
    if (n.isEmpty) return null;
    for (final seed in ConceptCatalog.seeds) {
      final variant = seed.variants[artifact];
      if (variant == null) continue;
      if (normalizeTopic(variant.$1) == n) {
        return '${seed.id}__$artifact';
      }
    }
    return null;
  }

  static Iterable<String> _lookupKeys({
    required String artifact,
    String? conceptId,
    required String title,
    required List<String> audiences,
  }) sync* {
    final id = (conceptId ?? '').trim();
    if (id.isNotEmpty) {
      yield _conceptKey(artifact, id);
      final seed = _seedId(id);
      if (seed != id) yield _conceptKey(artifact, seed);
    }
    final n = normalizeTopic(title);
    if (n.isNotEmpty) {
      yield _topicKey(artifact, n);
      if (audiences.isNotEmpty) {
        yield _topicAudienceKey(artifact, n, _audienceKey(audiences));
      }
      final catalogId = _catalogConceptId(artifact: artifact, title: title);
      if (catalogId != null) {
        yield _conceptKey(artifact, catalogId);
        yield _conceptKey(artifact, _seedId(catalogId));
      }
    }
  }

  static String _seedId(String conceptId) {
    final i = conceptId.indexOf('__');
    if (i <= 0) return conceptId;
    return conceptId.substring(0, i);
  }

  static String _conceptKey(String artifact, String conceptId) =>
      'c:${ArtifactType.normalize(artifact)}:${conceptId.trim()}';

  static String _topicKey(String artifact, String topic) =>
      't:${ArtifactType.normalize(artifact)}:$topic';

  static String _topicAudienceKey(
    String artifact,
    String topic,
    String audienceKey,
  ) => 'ta:${ArtifactType.normalize(artifact)}:$topic:$audienceKey';

  static String _audienceKey(List<String> audiences) {
    final ids =
        audiences.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          ..sort();
    return ids.join(',');
  }

  static void _put(
    Map<String, _OccupancyRecord> byKey,
    String key,
    ConceptWorkState state,
  ) {
    final prev = byKey[key];
    if (prev == null) {
      byKey[key] = _OccupancyRecord(state);
      return;
    }
    byKey[key] = _OccupancyRecord(_prefer(prev.state, state)!);
  }

  static ConceptWorkState? _prefer(ConceptWorkState? a, ConceptWorkState b) {
    if (a == null) return b;
    if (a == ConceptWorkState.inProgress || b == ConceptWorkState.inProgress) {
      return ConceptWorkState.inProgress;
    }
    if (a == ConceptWorkState.completed || b == ConceptWorkState.completed) {
      return ConceptWorkState.completed;
    }
    return ConceptWorkState.available;
  }
}
