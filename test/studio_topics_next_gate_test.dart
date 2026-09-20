import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/studio_title_recommendations.dart';
import 'package:sotong_ware_control/widgets/project_design/project_design_wizard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('canProceedFromTopics — title SSOT', () {
    test('A: TOP10 제목만 있어도 진행 가능 (컨셉 불필요)', () {
      const title = '50대 초보자가 AI로 첫 전자책을 만드는 방법';
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        selectedAudiences: const ['general'],
        step: ProjectDesignStep.topics,
        topic: title,
        displayTitle: title,
        titleSource: 'ai_suggested',
        manualOnlyMode: false,
      );
      expect(state.canProceedFromTopics, isTrue);
      expect(state.topicsProceedBlockedReason, isEmpty);
    });

    test('B: 제목 직접 수정 후에도 진행 가능', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        selectedAudiences: const ['general'],
        step: ProjectDesignStep.topics,
        topic: '직접 수정한 전자책 제목',
        displayTitle: '직접 수정한 전자책 제목',
        titleSource: 'user',
      );
      expect(state.canProceedFromTopics, isTrue);
    });

    test('C: 제목 비어 있으면 진행 불가 + 안내 문구', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        selectedAudiences: const ['general'],
        step: ProjectDesignStep.topics,
      );
      expect(state.canProceedFromTopics, isFalse);
      expect(state.topicsProceedBlockedReason, contains('추천 제목을 선택하거나'));
    });

    test('D: 직접 입력 모드도 제목만으로 topics 통과 (세부 필수는 details)', () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.ebook,
        selectedAudiences: const ['general'],
        step: ProjectDesignStep.topics,
        topic: '수동 모드 제목',
        displayTitle: '수동 모드 제목',
        manualOnlyMode: true,
        titleSource: 'manual',
      );
      expect(state.canProceedFromTopics, isTrue);
      expect(state.canCreateInstruction, isFalse);
    });
  });

  testWidgets('TOP10 선택 시 다음 버튼 활성 + 빈 제목이면 안내', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final titles = StudioTitleRecommendations.recommend(
      artifactType: ArtifactType.ebook,
      audienceIds: const ['general'],
      limit: 10,
    );
    expect(titles, isNotEmpty);
    final pick = titles.first;
    final chipKey = Key('studio_title_rec_${pick.hashCode}');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectDesignWizard(
              initial: ProjectDesignState(
                artifactType: ArtifactType.ebook,
                selectedAudiences: const ['general'],
                step: ProjectDesignStep.topics,
                creationMode: 'new',
                manualOnlyMode: false,
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final next = find.byKey(const Key('studio_wizard_next'));
    expect(next, findsOneWidget);
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    expect(find.byKey(const Key('studio_next_blocked_hint')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(chipKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(chipKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
    expect(find.byKey(const Key('studio_next_blocked_hint')), findsNothing);

    // Clear title via text field → disabled again.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    expect(find.byKey(const Key('studio_next_blocked_hint')), findsOneWidget);
  });
}
