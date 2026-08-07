import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/project_design_catalog.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/project_design_engine.dart';

void main() {
  final engine = ProjectDesignEngine();

  test('결과물 미선택 시 다음 단계 불가', () {
    final state = ProjectDesignState();
    expect(state.canProceedFromArtifact, isFalse);
  });

  test('전자책 선택 후 고객·주제로 입력 생성', () {
    var state = ProjectDesignState(
      artifactType: ArtifactType.ebook,
      selectedAudiences: const ['rural', 'age_40_60'],
      selectedTopicIds: const ['ai_usage', 'online_income'],
    );
    expect(state.canProceedFromArtifact, isTrue);
    expect(state.canProceedFromAudience, isTrue);
    final topics = engine.recommendTopics(state);
    expect(topics.any((t) => t.id == 'ai_usage'), isTrue);
    state = engine.syncSentences(state);
    expect(state.topicStatus.name, 'suggested');
    expect(state.canCreateInstruction, isFalse);
    state = engine.confirmPlanning(state);
    expect(state.canCreateInstruction, isTrue);
    final input = engine.toBusinessPlanInput(state);
    expect(input.resolvedArtifactType, ArtifactType.ebook);
    expect(input.topic, isNotEmpty);
    expect(input.targetCustomer, contains('농촌'));
    expect(input.customerProblem, isNotEmpty);
  });

  test('제작 옵션 그룹이 결과물별로 다르다', () {
    final ebook = ProjectDesignCatalog.productionGroupsFor(ArtifactType.ebook);
    final app = ProjectDesignCatalog.productionGroupsFor(ArtifactType.app);
    expect(ebook.any((g) => g.id == 'format'), isTrue);
    expect(app.any((g) => g.id == 'platform'), isTrue);
    expect(ebook.map((g) => g.id), isNot(equals(app.map((g) => g.id))));
  });

  test('AI 검토 리포트 생성', () {
    final state = ProjectDesignState(
      artifactType: ArtifactType.ebook,
      selectedAudiences: const ['rural'],
      selectedTopicIds: const ['smart_farm'],
      designMemo: '현장 체크리스트 강조',
    );
    final synced = engine.syncSentences(state);
    final report = engine.buildReview(synced);
    expect(report.insights, isNotEmpty);
    expect(report.verdictLabel, isNotEmpty);
  });

  test('wizardState 왕복 호환', () {
    final state = ProjectDesignState(
      artifactType: ArtifactType.app,
      selectedAudiences: const ['smb'],
      selectedTopicIds: const ['local_biz'],
      designMemo: '메모',
      productionSelections: {
        'platform': ['flutter'],
      },
    );
    final wizard = state.toWizardState();
    final restored = ProjectDesignState.fromWizardState(wizard);
    expect(restored.artifactType, ArtifactType.app);
    expect(restored.selectedTopicIds, contains('local_biz'));
    expect(restored.designMemo, '메모');
  });
}
