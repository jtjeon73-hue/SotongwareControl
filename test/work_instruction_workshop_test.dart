import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/screens/ai_business_analysis_screen.dart';
import 'package:sotong_ware_control/services/instruction_contract_validator.dart';
import 'package:sotong_ware_control/services/plan_execution_status.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';
import 'package:sotong_ware_control/services/work_instruction_workshop_presentation.dart';
import 'package:sotong_ware_control/widgets/project_design/instruction_preview_panel.dart';

BusinessPlanDocument _plan({
  required String id,
  required String topic,
  required String status,
  String? lastTransferAt,
  String? lastTransferMode,
  String? lastRemoteJobId,
  String? lastRemoteCommandId,
}) {
  return BusinessPlanDocument(
    id: id,
    status: status,
    version: 1,
    createdAt: '2026-08-01T00:00:00.000Z',
    updatedAt: '2026-08-01T00:00:00.000Z',
    lastTransferAt: lastTransferAt,
    lastTransferMode: lastTransferMode,
    lastRemoteJobId: lastRemoteJobId,
    lastRemoteCommandId: lastRemoteCommandId,
    input: BusinessPlanInput(
      topic: topic,
      customerProblem: '문제',
      targetCustomer: 'rural_resident',
      desiredOutcome: '목적',
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [ArtifactType.ebook],
    ),
    instruction: WorkInstruction(
      schemaVersion: '1.0',
      instructionId: 'wi_$id',
      projectId: 'proj',
      instructionVersion: '1',
      createdAt: '2026-08-01T00:00:00.000Z',
      updatedAt: '2026-08-01T00:00:00.000Z',
      businessIdea: topic,
      businessPurpose: '목적',
      customerProblem: '문제',
      targetCustomer: 'rural_resident',
      deliverableTypes: const ['ebook'],
      recommendedSequence: const ['ebook'],
      valueProposition: '가치',
      requiredMaterials: const [],
      workflowSteps: const [],
      completionCriteria: const [],
      qualityChecks: const [],
      risks: const [],
      monetizationOptions: const [],
      deploymentTargets: const [],
      promotionChannels: const [],
      approvalItems: const [],
      executionStatus: 'draft',
      artifactType: 'ebook',
      checksum: 'abc',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkInstructionWorkshopPresentation', () {
    test('전송 실패 항목은 성공 목록에 포함되지 않음', () {
      final plans = [
        _plan(
          id: 'p_ok',
          topic: '성공',
          status: PlanningStatus.transferred,
          lastTransferAt: '2026-08-18T05:00:00.000Z',
          lastTransferMode: PlanProgressStatus.remoteMode,
          lastRemoteJobId: 'job_1',
          lastRemoteCommandId: 'cmd_1',
        ),
        _plan(
          id: 'p_fail',
          topic: '실패',
          status: PlanningStatus.transferFailed,
          lastTransferAt: '2026-08-05T05:00:00.000Z',
        ),
        _plan(
          id: 'p_old',
          topic: '가이드 전자책개발',
          status: PlanningStatus.transferred,
          lastTransferAt: '2026-08-05T05:00:00.000Z',
          lastTransferMode: 'download',
        ),
      ];

      final sent = WorkInstructionWorkshopPresentation.successfulTransfers(
        plans,
      );
      expect(sent.length, 1);
      expect(sent.first.input.topic, '성공');
    });

    test('internal enum label 사용자 친화 변환', () {
      expect(
        WorkInstructionWorkshopPresentation.humanizeAudienceOrField(
          'rural_resident',
        ),
        '농촌·시골 거주자',
      );
    });

    test('BLOCKED 대신 확인 필요 문구', () {
      expect(
        WorkInstructionWorkshopPresentation.blockedTransferButtonLabel(),
        '보내기 전 확인 필요',
      );
    });

    test('validation problem 사용자 메시지', () {
      const result = ContractValidationResult(
        level: ContractValidationLevel.blocked,
        issues: [
          ContractValidationIssue(
            level: ContractValidationLevel.blocked,
            field: 'targetCustomer',
            reason: '대상 고객 세부 설명이 필요합니다.',
            fix: '입력',
          ),
        ],
      );
      final lines = WorkInstructionWorkshopPresentation.validationProblemLines(
        result,
      );
      expect(lines.first, contains('대상 고객'));
      expect(lines.first, contains('세부 설명'));
    });

    test('진행 중 상태 brief', () {
      const exec = PlanExecutionSnapshot(
        instructionId: 'wi_x',
        planId: 'p',
        isPostTransfer: true,
        transferState: PlanTransferState.delivered,
        pcReceiveState: PlanPcReceiveState.received,
        runState: PlanRunState.working,
        instructionDesignStep: 7,
        instructionDesignTotal: 7,
        productionCurrentStage: 3,
        productionTotalStages: 18,
        displayTitle: 't',
        primaryStatusLabel: '진행중',
        instructionProgressLine: '',
        productionProgressLine: '',
        transferLine: '',
        currentStageLabel: '',
        hasActualExecution: true,
        isDeliveredOnly: false,
        isActivelyRunning: true,
        isAwaitingApproval: false,
        agentOnline: true,
      );
      expect(
        WorkInstructionWorkshopPresentation.transferListBriefStatus(exec),
        '진행 중 · 3단계',
      );
    });
  });

  testWidgets('작업지시 제작소 — 저장된 기획·고급/진단 UI 미노출', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('저장된 기획 목록'), findsNothing);
    expect(find.text('고급/진단정보'), findsNothing);
    expect(find.text('전달 차단(BLOCKED)'), findsNothing);
    expect(find.byKey(const Key('planning_other_actions')), findsOneWidget);
  });

  testWidgets('InstructionPreviewPanel — raw JSON 기본 미노출', (tester) async {
    const wi = WorkInstruction(
      schemaVersion: '1.0',
      instructionId: 'wi_test',
      projectId: 'p',
      instructionVersion: '1',
      createdAt: '2026-08-01T00:00:00.000Z',
      updatedAt: '2026-08-01T00:00:00.000Z',
      businessIdea: '테스트',
      businessPurpose: '목적',
      customerProblem: '문제',
      targetCustomer: '일반',
      deliverableTypes: ['ebook'],
      recommendedSequence: ['ebook'],
      valueProposition: 'v',
      requiredMaterials: [],
      workflowSteps: [],
      completionCriteria: [],
      qualityChecks: [],
      risks: [],
      monetizationOptions: [],
      deploymentTargets: [],
      promotionChannels: [],
      approvalItems: [],
      executionStatus: 'draft',
      artifactType: 'ebook',
      checksum: 'x',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InstructionPreviewPanel(instruction: wi),
          ),
        ),
      ),
    );

    expect(find.text('고급 원문 보기'), findsOneWidget);
    expect(find.textContaining('"instructionId"'), findsNothing);
  });

  testWidgets('InstructionPreviewPanel — 모바일 단일 열 + 390px overflow 없음', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    const long =
        '온라인에서 수익을 내고 싶지만 무엇을 팔아야 할지, 누구를 대상으로 해야 할지, '
        '첫 전자책을 어떻게 구성해야 할지 막막한 초보 창업자를 위한 실전 안내입니다. '
        '주제 선정부터 목차, 판매 페이지까지 한 권으로 따라 할 수 있게 정리합니다.';

    const wi = WorkInstruction(
      schemaVersion: '1.0',
      instructionId: 'wi_plan_1787030423574',
      projectId: 'proj',
      instructionVersion: '1',
      createdAt: '2026-08-01T00:00:00.000Z',
      updatedAt: '2026-08-01T00:00:00.000Z',
      businessIdea: '온라인 수익 첫걸음 전자책',
      businessPurpose: long,
      customerProblem: long,
      targetCustomer: '초보 창업자',
      deliverableTypes: ['ebook'],
      recommendedSequence: ['ebook'],
      valueProposition: long,
      requiredMaterials: [],
      workflowSteps: [],
      completionCriteria: [],
      qualityChecks: ['맞춤법 검토', '초보도 따라 할 수 있는 난이도'],
      risks: [],
      monetizationOptions: [],
      deploymentTargets: [],
      promotionChannels: [],
      approvalItems: ['단계별 승인'],
      executionStatus: 'draft',
      artifactType: 'ebook',
      notes: '표지 시안은 따뜻한 톤으로',
      checksum: 'x',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: SingleChildScrollView(
              child: InstructionPreviewPanel(instruction: wi),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('instruction_preview_doc')), findsOneWidget);
    expect(find.text('기본'), findsOneWidget);
    expect(find.text('대상과 문제'), findsOneWidget);
    expect(find.text('제작 목표'), findsOneWidget);
    expect(find.text('제작 조건'), findsOneWidget);
    expect(find.text('사업유형'), findsOneWidget);
    expect(find.text('작업 제목'), findsOneWidget);
    expect(find.text('온라인 수익 첫걸음 전자책'), findsWidgets);
    expect(find.text('내용 복사'), findsOneWidget);
    expect(find.textContaining('"instructionId"'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
