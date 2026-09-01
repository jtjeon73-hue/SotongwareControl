import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/instruction_contract_validator.dart';
import 'package:sotong_ware_control/services/work_instruction_requirement_enhancer.dart';
import 'package:sotong_ware_control/services/work_instruction_studio_preflight.dart';

void main() {
  test(
    'requirement enhancer structures app input without starting production',
    () {
      final state = ProjectDesignState(
        artifactType: ArtifactType.app,
        topic: '농촌 전기 점검 앱',
        customerProblem: '농촌에서 전기 점검할 수 있는 간단한 앱',
        targetCustomer: '농촌 자영업자',
      );
      final result = WorkInstructionRequirementEnhancer.enhance(state);
      expect(result.sections, isNotEmpty);
      expect(result.suggestedNotes, contains('AI 요구사항 보완'));
      expect(result.suggestedOutcome, contains('APK'));
    },
  );

  test('preflight blocks when required fields missing', () {
    final input = const BusinessPlanInput(
      topic: '',
      customerProblem: '',
      targetCustomer: '',
      desiredOutcome: '',
      artifactType: ArtifactType.app,
    );
    final report = WorkInstructionStudioPreflight.evaluate(
      input: input,
      instruction: null,
      agents: const [],
    );
    expect(report.canStartProduction, isFalse);
    expect(
      report.checks.any(
        (c) =>
            c.id == 'required_fields' &&
            c.status == StudioPreflightStatus.blocked,
      ),
      isTrue,
    );
  });

  test('preflight blocks when agent offline', () {
    final input = BusinessPlanInput(
      topic: '테스트 앱',
      customerProblem: '문제',
      targetCustomer: '사용자',
      desiredOutcome: '결과',
      artifactType: ArtifactType.app,
    );
    final report = WorkInstructionStudioPreflight.evaluate(
      input: input,
      instruction: null,
      agents: const [
        RemoteAgentDoc(
          agentId: 'a1',
          ownerUid: 'u1',
          deviceName: 'pc',
          state: 'idle',
          enabled: true,
        ),
      ],
    );
    expect(
      report.checks.any(
        (c) =>
            c.id == 'agent_relay' && c.status == StudioPreflightStatus.blocked,
      ),
      isTrue,
    );
    expect(report.canStartProduction, isFalse);
  });

  test('production site/contents policies support worker preference', () {
    final site = AiExecutionPolicy.productionSite().withWorkerPreference(
      'cursor',
    );
    final contents = AiExecutionPolicy.productionContents(approvalMode: 'auto');
    expect(site.worker, 'cursor');
    expect(contents.approvalMode, 'auto');
    expect(contents.executionMode, 'continuous');
  });

  test('preflight uses contract validation when instruction present', () {
    final input = BusinessPlanInput(
      topic: '앱',
      customerProblem: '문제',
      targetCustomer: '사용자',
      desiredOutcome: '결과',
      artifactType: ArtifactType.app,
    );
    final report = WorkInstructionStudioPreflight.evaluate(
      input: input,
      instruction: null,
      agents: const [],
      contractValidation: const ContractValidationResult(
        level: ContractValidationLevel.blocked,
        issues: [
          ContractValidationIssue(
            field: 'test',
            reason: 'blocked',
            fix: 'fix',
            level: ContractValidationLevel.blocked,
          ),
        ],
      ),
    );
    expect(report.checks.any((c) => c.id == 'instruction_missing'), isTrue);
  });
}
