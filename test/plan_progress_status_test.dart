import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/planning_summary.dart';
import 'package:sotong_ware_control/models/planning_wizard_state.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/business_planning_store.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/planning_sentence_composer.dart';

void main() {
  const composer = PlanningSentenceComposer();

  BusinessPlanDocument plan({
    required String status,
    String? lastTransferMode,
    String? lastTransferAt,
    bool withInstruction = true,
  }) {
    const input = BusinessPlanInput(
      topic: '테스트 주제',
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '결과',
      artifactType: ArtifactType.ebook,
      deliverableTypes: [ArtifactType.ebook],
    );
    final service = BusinessPlanningService();
    final analysis = service.analyze(input);
    final instruction = withInstruction
        ? service.buildInstruction(
            planId: 'plan_1',
            input: input,
            analysis: analysis,
            instructionId: 'wi_plan_1',
            version: 1,
          )
        : null;

    return BusinessPlanDocument(
      id: 'plan_1',
      input: input,
      status: status,
      createdAt: '2026-08-05T00:00:00Z',
      updatedAt: '2026-08-05T01:00:00Z',
      instructionId: 'wi_plan_1',
      version: 1,
      analysis: analysis,
      lastTransferAt: lastTransferAt ?? '2026-08-05T02:00:00Z',
      lastTransferMode: lastTransferMode,
      instruction: instruction,
    );
  }

  test('download success without folder is not 전달됨', () {
    final doc = plan(
      status: PlanningStatus.downloadedPendingImport,
      lastTransferMode: PlanProgressStatus.downloadMode,
    );
    final view = PlanProgressStatus.resolve(
      doc,
      hasDevWorkDocRoot: true,
      hasTransferFolder: false,
    );

    expect(view.isTrulyTransferred, isFalse);
    expect(view.badgeLabel, 'JSON 다운로드 완료');
    expect(view.badgeLabel, isNot('전달됨'));
    expect(PlanProgressStatus.isTrulyTransferred(doc), isFalse);
  });

  test('folder write shows 전달됨', () {
    final doc = plan(
      status: PlanningStatus.transferred,
      lastTransferMode: PlanProgressStatus.folderMode,
    );
    final view = PlanProgressStatus.resolve(
      doc,
      hasDevWorkDocRoot: true,
      hasTransferFolder: true,
    );

    expect(view.isTrulyTransferred, isTrue);
    expect(view.badgeLabel, '전달됨');
    expect(doc.wasTransferred, isTrue);
  });

  test('reconcile transferred+download mode to downloaded_pending_import', () {
    final legacy = plan(
      status: PlanningStatus.transferred,
      lastTransferMode: PlanProgressStatus.downloadMode,
    );
    final fixed = PlanProgressStatus.reconcile(legacy);
    expect(fixed.status, PlanningStatus.downloadedPendingImport);
    expect(fixed.wasTransferred, isFalse);
  });

  test('artifact 전자책 vs track 전자책개발 vs deliverables distinct', () {
    final state = PlanningWizardState(
      artifactType: ArtifactType.ebook,
      topic: 'AI 수익 가이드',
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '90일 실행계획과 체크리스트',
      artifactAnswers: {
        'outputFormat': ['both'],
        'ebookKind': ['guide'],
      },
    );
    final summary = PlanningSummary.fromWizard(state);
    final input = composer.toBusinessPlanInput(state);

    expect(summary.artifactLabel, '전자책');
    expect(summary.primaryTrack, '전자책개발');
    expect(input.primaryTrack, 'ebook_dev');
    expect(summary.deliverableItems, isNot(contains('전자책개발')));
    expect(summary.deliverableItems, contains('PDF'));
    expect(summary.deliverableItems, contains('EPUB'));
  });

  test('PlanningSummary sections avoid duplicate customerProblem', () {
    const problem = '고객 문제 문장';
    final state = PlanningWizardState(
      artifactType: ArtifactType.ebook,
      topic: '주제',
      customerProblem: problem,
      targetCustomer: '고객',
      desiredOutcome: '결과',
      artifactAnswers: {
        'customerProblem': ['productize_unknown'],
      },
    );
    final summary = PlanningSummary.fromWizard(state);
    final basic = summary.sections.firstWhere((s) => s.title == '기본 기획');
    final production = summary.sections.firstWhere(
      (s) => s.title == '제작·판매 계획',
    );

    expect(
      basic.fields.any((f) => f.label == '고객 문제' && f.value == problem),
      isTrue,
    );
    expect(production.fields.where((f) => f.value == problem).length, 0);
    expect(summary.allFieldValues.where((v) => v == problem).length, 1);
  });

  test('autofill preserves user topic', () {
    var state = PlanningWizardState(
      artifactType: ArtifactType.ebook,
      topic: '사용자 지정 주제',
      domains: ['rural_life', 'online_income'],
      artifactAnswers: {
        'customerProblem': ['productize_unknown'],
        'targetCustomer': ['return_prep'],
        'desiredOutcome': ['ebook_first'],
      },
    );
    state = composer.applyAutoComplete(state);
    expect(state.topic, '사용자 지정 주제');
    expect(state.customTexts.containsKey('_recommended:topic'), isFalse);
  });

  test('latestByInstructionId dedupe still works', () {
    const iid = 'wi_same';
    final a1 = BusinessPlanDocument(
      id: 'a1',
      input: const BusinessPlanInput(topic: '동일'),
      status: PlanningStatus.draft,
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-01T00:00:00Z',
      instructionId: iid,
      version: 1,
    );
    final a2 = a1.copyWith(
      status: PlanningStatus.instructionReady,
      updatedAt: '2026-08-04T00:00:00Z',
      version: 2,
    );
    final latest = BusinessPlanningStore.latestByInstructionId([a1, a2]);
    expect(latest.length, 1);
    expect(latest.single.version, 2);
  });

  test('wasTransferred false when lastTransferAt set without folder mode', () {
    final doc = plan(
      status: PlanningStatus.transferred,
      lastTransferMode: PlanProgressStatus.downloadMode,
    );
    expect(doc.wasTransferred, isFalse);
    expect(doc.isManualImportPending, isTrue);
  });
}
