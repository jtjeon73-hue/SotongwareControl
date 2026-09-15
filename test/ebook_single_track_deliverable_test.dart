import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/concept_candidate.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/commercial_studio_builder.dart';

/// Track identity: deliverableTypes must not absorb analyze() recommendations.
void main() {
  final service = BusinessPlanningService();

  /// Work validator equivalent (WorkInstructionValidator.cpp hasApp/hasContent).
  bool workHasApp(WorkInstruction wi) {
    return wi.artifactType == ArtifactType.app ||
        wi.deliverableTypes.any((t) => t.toLowerCase() == 'app') ||
        wi.recommendedSequence.any((t) => t.toLowerCase() == 'app');
  }

  bool workHasContent(WorkInstruction wi) {
    final types = [...wi.deliverableTypes, ...wi.recommendedSequence]
        .map((t) => t.toLowerCase());
    return wi.artifactType == ArtifactType.contents ||
        wi.artifactType == 'content' ||
        types.any(
          (t) =>
              t == 'contents' ||
              t == 'content' ||
              t == 'youtube_shorts' ||
              t == 'content_music',
        );
  }

  group('CASE A — manualOnly ebook single track', () {
    test('deliverableTypes stays ebook-only despite heuristic recommendations', () {
      final input = BusinessPlanInput(
        topic: '하루 10분, 생활이 편해지는 AI 활용법',
        customerProblem:
            'AI를 접해봤지만 무엇을 어떻게 질문해야 하는지 모르고, '
            '검색·문서작성·일정관리·정보정리 등 일상과 업무에 '
            'AI를 실제로 활용하는 방법이 어렵다.',
        targetCustomer: 'AI 초보 일반 성인, 직장인, 주부, 40~60대 중장년층',
        desiredOutcome:
            '상용 수준 전자책 + PDF/EPUB + SotongWare Reader 등록을 고려한 결과',
        artifactType: ArtifactType.ebook,
        deliverableTypes: const [DeliverableType.ebook],
        wizardSelections: {
          'mode': 'advanced',
          'customTexts': {'manualOnlyMode': 'true'},
          'fieldStatuses': {
            'topic': 'userConfirmed',
            'problem': 'userConfirmed',
            'outcome': 'userConfirmed',
            'customer': 'userConfirmed',
          },
        },
      );

      final analysis = service.analyze(input);
      // Heuristics still recommend app/shorts — must NOT enter deliverableTypes.
      expect(
        analysis.recommendations.map((r) => r.type),
        containsAll([DeliverableType.ebook, DeliverableType.app]),
      );

      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        topic: input.topic,
        customerProblem: input.customerProblem,
        targetCustomer: input.targetCustomer,
        desiredOutcome: input.desiredOutcome,
        displayTitle: input.topic,
        manualOnlyMode: true,
        planningConfirmed: true,
        topicStatus: DesignFieldStatus.userConfirmed,
        problemStatus: DesignFieldStatus.userConfirmed,
        outcomeStatus: DesignFieldStatus.userConfirmed,
        customerStatus: DesignFieldStatus.userConfirmed,
        customAudience: input.targetCustomer,
        originalUserBriefConfirmed: true,
        reasonsToPay: const ['실전 체크리스트'],
        uniqueValue: input.desiredOutcome,
        userConfirmedAt: '2026-09-16T00:00:00Z',
      );
      final attachment = const CommercialStudioBuilder().tryBuild(
        state: state,
        input: input,
        instructionId: 'wi_ebook_single',
        projectId: 'plan_ebook_single',
      );
      expect(attachment, isNotNull);

      final wi = service.buildInstruction(
        planId: 'plan_ebook_single',
        input: input,
        analysis: analysis,
        instructionId: 'wi_ebook_single',
        version: 1,
        commercialQuality: attachment,
      );

      expect(wi.artifactType, ArtifactType.ebook);
      expect(wi.deliverableTypes, [ArtifactType.ebook]);
      expect(wi.recommendedSequence, [ArtifactType.ebook]);
      expect(workHasApp(wi), isFalse);
      expect(workHasContent(wi), isFalse);
      expect(wi.workflowSteps.length, 18);
      expect(wi.notes, contains('ebookProductionContractVersion=2'));
      expect(wi.commercialQuality?.ebookProfile.present, isTrue);
      expect(wi.commercialQuality?.appProfile.present, isFalse);
      expect(wi.commercialQuality?.contentProfile.present, isFalse);

      final json = wi.toJson();
      expect(json['deliverableTypes'], ['ebook']);
      expect(json['recommendedSequence'], ['ebook']);
      expect(json['artifactType'], 'ebook');
      expect(json.containsKey('commercialEbookQualityProfile'), isTrue);
      expect(json.containsKey('commercialAppQualityProfile'), isFalse);
      expect(json.containsKey('commercialContentQualityProfile'), isFalse);

      // follow-up ideas may remain as tracks, not deliverable identity
      expect(wi.followUpTracks, isNotEmpty);
    });
  });

  group('CASE B — app single track preserved', () {
    test('app WI stays app-only', () {
      final input = BusinessPlanInput(
        topic: '현장 안전 점검 앱',
        customerProblem: '점검 누락이 반복된다',
        targetCustomer: '현장 작업자',
        desiredOutcome: '점검 기록 보존',
        artifactType: ArtifactType.app,
        deliverableTypes: const [DeliverableType.app],
      );
      final wi = service.buildInstruction(
        planId: 'plan_app',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_app',
      );
      expect(wi.artifactType, ArtifactType.app);
      expect(wi.deliverableTypes, [ArtifactType.app]);
      expect(wi.recommendedSequence, [ArtifactType.app]);
      expect(workHasContent(wi), isFalse);
    });
  });

  group('CASE C — contents single track preserved', () {
    test('contents WI stays contents-only', () {
      final input = BusinessPlanInput(
        topic: 'AI 팁 쇼츠',
        customerProblem: '짧은 영상 소재가 부족하다',
        targetCustomer: '직장인',
        desiredOutcome: '주 3회 쇼츠 발행',
        artifactType: ArtifactType.contents,
        contentSubtype: ContentSubtype.shorts,
        deliverableTypes: const [DeliverableType.youtubeShorts],
      );
      final wi = service.buildInstruction(
        planId: 'plan_contents',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_contents',
      );
      expect(wi.artifactType, ArtifactType.contents);
      expect(wi.deliverableTypes, [ArtifactType.contents]);
      expect(wi.recommendedSequence, [ArtifactType.contents]);
      expect(workHasApp(wi), isFalse);
    });
  });

  group('CASE D — explicit multi-deliverable preserved', () {
    test('user-selected secondary deliverables remain', () {
      final input = BusinessPlanInput(
        topic: '전자책+앱 패키지',
        customerProblem: '학습 후 실행 도구가 없다',
        targetCustomer: '직장인',
        desiredOutcome: '전자책과 보조 앱',
        artifactType: ArtifactType.ebook,
        deliverableTypes: const [
          DeliverableType.ebook,
          DeliverableType.app,
        ],
      );
      final wi = service.buildInstruction(
        planId: 'plan_multi',
        input: input,
        analysis: service.analyze(input),
        instructionId: 'wi_multi',
      );
      expect(wi.artifactType, ArtifactType.ebook);
      expect(wi.deliverableTypes.first, ArtifactType.ebook);
      expect(wi.deliverableTypes, contains(ArtifactType.app));
      // Heuristic contents must still not appear unless selected.
      expect(wi.deliverableTypes, isNot(contains(ArtifactType.contents)));
    });
  });
}
