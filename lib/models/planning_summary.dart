/// 기획 마법사 최종 확인용 순수 요약 데이터.
library;

import '../data/artifact_question_catalog.dart';
import '../services/planning_sentence_composer.dart';
import 'business_planning.dart';
import 'planning_wizard_state.dart';

class PlanningSummary {
  const PlanningSummary({
    required this.artifactLabel,
    required this.primaryTrack,
    required this.mainDeliverables,
    required this.targetUser,
    required this.purpose,
    required this.monetization,
    required this.transferReadyLabel,
  });

  final String artifactLabel;
  final String primaryTrack;
  final String mainDeliverables;
  final String targetUser;
  final String purpose;
  final String monetization;
  final String transferReadyLabel;

  factory PlanningSummary.fromWizard(
    PlanningWizardState state, {
    PlanningSentenceComposer composer = const PlanningSentenceComposer(),
    bool hasInstruction = false,
  }) {
    final input = composer.toBusinessPlanInput(state);
    final artifact = state.effectiveArtifactType ?? ArtifactType.undecided;

    return PlanningSummary(
      artifactLabel: ArtifactType.labelKo(artifact),
      primaryTrack: ArtifactType.primaryTrack(artifact),
      mainDeliverables: _mainDeliverables(state, input),
      targetUser: input.targetCustomer.trim(),
      purpose: input.topic.trim(),
      monetization: _monetization(state, input),
      transferReadyLabel: hasInstruction
          ? '작업지시서 생성됨 — 소통24워크 전달 가능'
          : '작업지시서 미생성 — 전달 준비 전',
    );
  }

  static String _mainDeliverables(
    PlanningWizardState state,
    BusinessPlanInput input,
  ) {
    final parts = <String>[];
    if (input.desiredOutcome.trim().isNotEmpty) {
      parts.add(input.desiredOutcome.trim());
    }

    final artifact = state.effectiveArtifactType;
    if (artifact != null && artifact != ArtifactType.undecided) {
      for (final qId in const [
        'outputFormat',
        'deliverables',
        'ebookKind',
        'formats',
      ]) {
        final labels = _answerLabels(state, artifact, qId);
        if (labels.isNotEmpty) {
          parts.add(labels.join(', '));
        }
      }
    }

    if (parts.isEmpty) return '—';
    return parts.join(' · ');
  }

  static String _monetization(
    PlanningWizardState state,
    BusinessPlanInput input,
  ) {
    if (input.revenueModel.trim().isNotEmpty) {
      return input.revenueModel.trim();
    }

    final artifact = state.effectiveArtifactType;
    if (artifact == null || artifact == ArtifactType.undecided) {
      return '—';
    }

    for (final qId in const ['salesDeploy', 'salesMode', 'monetization']) {
      final labels = _answerLabels(state, artifact, qId);
      if (labels.isNotEmpty) return labels.join(', ');
    }
    return '—';
  }

  static List<String> _answerLabels(
    PlanningWizardState state,
    String artifact,
    String questionId,
  ) {
    final ids = state.artifactAnswers[questionId];
    if (ids == null || ids.isEmpty) return const [];

    final questions = questionsFor(
      artifact: artifact,
      contentSubtype: state.contentSubtype,
    );
    final question = questions.where((q) => q.id == questionId).firstOrNull;
    if (question == null) return const [];

    return ids
        .map((id) {
          if (id == 'custom') {
            return state.customTexts[questionId]?.trim() ?? '직접 입력';
          }
          return question.options.where((o) => o.id == id).firstOrNull?.label ??
              id;
        })
        .where((l) => l.isNotEmpty)
        .toList();
  }
}

extension _FirstOrNullSummary<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
