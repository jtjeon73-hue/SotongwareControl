import '../models/business_planning.dart';
import '../models/concept_candidate.dart';
import '../models/planning_wizard_state.dart';
import '../models/project_design_state.dart';
import 'work_instruction_concept_occupancy.dart';

/// 새 작업 vs 이어하기를 구분하는 wizard session helper.
/// autosave(draft)는 유지하되, 새 작업 기본값으로 복원하지 않는다.
class WorkInstructionWizardSession {
  WorkInstructionWizardSession._();

  static String newId([DateTime? now]) {
    final stamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return 'wiz_$stamp';
  }

  static ProjectDesignState emptyDesign({DateTime? now}) {
    return ProjectDesignState(wizardSessionId: newId(now));
  }

  static String sessionIdOf(BusinessPlanInput? input) {
    if (input == null) return '';
    final ws = input.wizardSelections;
    if (ws == null) return '';
    final direct = '${ws['wizardSessionId'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;
    final texts = ws['customTexts'];
    if (texts is Map) {
      return '${texts['wizardSessionId'] ?? ''}'.trim();
    }
    return '';
  }

  static bool hasProgress(BusinessPlanInput? input) {
    if (input == null) return false;
    final artifact = input.resolvedArtifactType;
    if (artifact.isNotEmpty && artifact != ArtifactType.undecided) {
      return true;
    }
    if (input.topic.trim().isNotEmpty ||
        input.customerProblem.trim().isNotEmpty ||
        input.targetCustomer.trim().isNotEmpty ||
        input.desiredOutcome.trim().isNotEmpty ||
        input.notes.trim().isNotEmpty) {
      return true;
    }
    final design = restoreDesign(input);
    return design.hasArtifact ||
        design.selectedAudiences.isNotEmpty ||
        design.customAudience.trim().isNotEmpty ||
        design.selectedConceptIds.isNotEmpty ||
        design.selectedTopicIds.isNotEmpty ||
        design.userAddedConcepts.isNotEmpty ||
        design.designMemo.trim().isNotEmpty ||
        design.topic.trim().isNotEmpty;
  }

  /// 미전송 draft만 이어하기 대상으로 본다.
  /// 이미 전송된 작업의 leftover draft는 복원하지 않는다.
  static bool isUnsentResumable(
    BusinessPlanInput? input,
    List<BusinessPlanDocument> plans,
  ) {
    if (!hasProgress(input)) return false;
    final sid = sessionIdOf(input);
    final topic = ConceptOccupancyIndex.normalizeTopic(input!.topic);
    final artifact = input.resolvedArtifactType;
    final conceptIds = ConceptOccupancyIndex.conceptIdsFromInput(input);

    for (final plan in plans) {
      if (plan.isLibraryArchived || plan.isLibraryTrashed) continue;
      if (!plan.wasTransferred) continue;
      final planSid = sessionIdOf(plan.input);
      if (sid.isNotEmpty && planSid == sid) return false;
      if (artifact.isNotEmpty &&
          artifact != ArtifactType.undecided &&
          ArtifactType.normalize(plan.input.resolvedArtifactType) ==
              ArtifactType.normalize(artifact)) {
        final planTopic = ConceptOccupancyIndex.normalizeTopic(
          plan.input.topic,
        );
        if (topic.isNotEmpty && topic == planTopic) return false;
        final planConcepts = ConceptOccupancyIndex.conceptIdsFromInput(
          plan.input,
        );
        if (conceptIds.isNotEmpty && planConcepts.any(conceptIds.contains)) {
          return false;
        }
      }
    }
    return true;
  }

  static ProjectDesignState restoreDesign(BusinessPlanInput input) {
    final ws = input.wizardSelections;
    if (ws == null) {
      return ProjectDesignState(
        wizardSessionId: sessionIdOf(input),
        artifactType: input.artifactType.isEmpty ? null : input.artifactType,
        contentSubtype: input.contentSubtype.isEmpty
            ? null
            : input.contentSubtype,
        topic: input.topic,
        customerProblem: input.customerProblem,
        targetCustomer: input.targetCustomer,
        desiredOutcome: input.desiredOutcome,
      );
    }
    final wizard = PlanningWizardState.fromJson(ws);
    final design = ProjectDesignState.fromWizardState(wizard);
    final selectedRaw = ws['selectedConcepts'];
    if (selectedRaw is List) {
      final userAdded = <ConceptCandidate>[];
      final ids = <String>[...design.selectedConceptIds];
      for (final e in selectedRaw) {
        if (e is! Map) continue;
        final c = ConceptCandidate.fromJson(Map<String, dynamic>.from(e));
        if (c.id.isEmpty) continue;
        if (!ids.contains(c.id)) ids.add(c.id);
        if (c.isUserAdded) userAdded.add(c);
      }
      design.selectedConceptIds = ids;
      if (userAdded.isNotEmpty) {
        design.userAddedConcepts = userAdded;
      }
    }
    if (design.wizardSessionId.isEmpty) {
      design.wizardSessionId = sessionIdOf(input);
    }
    return design;
  }
}
