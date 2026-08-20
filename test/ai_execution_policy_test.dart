import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';

void main() {
  final service = BusinessPlanningService();

  BusinessPlanInput ebookInput() => const BusinessPlanInput(
    topic: '파일럿 소형 전자책',
    customerProblem: '초보자가 첫 전자책 구성을 모른다',
    targetCustomer: '50대 초보 창작자',
    desiredOutcome: '1단계 아이디어 정리 결과물',
    artifactType: ArtifactType.ebook,
  );

  PlanningAnalysisResult analysisFor(BusinessPlanInput input) =>
      service.analyze(input);

  test('새 pilot ebook WI → aiExecution 고정 정책 포함', () {
    final input = ebookInput();
    final wi = service.buildInstruction(
      planId: 'plan_pilot_1',
      input: input,
      analysis: analysisFor(input),
      instructionId: 'wi_plan_pilot_1',
      aiExecution: AiExecutionPolicy.pilotCodexStage1,
    );

    expect(wi.instructionId, startsWith('wi_plan_'));
    expect(wi.artifactType, ArtifactType.ebook);
    expect(wi.workflowSteps.first.id, 'idea_clarify');
    expect(wi.aiExecution, isNotNull);
    expect(wi.aiExecution!.enabled, isTrue);
    expect(wi.aiExecution!.worker, 'codex');
    expect(wi.aiExecution!.maxAutoStageOrder, 1);
    expect(wi.aiExecution!.approvalMode, 'manual');
    expect(wi.aiExecution!.approvalRequired, isTrue);
    expect(wi.aiExecution!.artifactUploadEnabled, isTrue);
    expect(wi.aiExecution!.autoAdvance, isFalse);
    expect(wi.aiExecution!.deploymentAllowed, isFalse);

    final json = wi.toJson();
    expect(json['aiExecution'], isA<Map>());
    expect(json['aiExecution']['maxAutoStageOrder'], 1);
    expect(json.containsKey('executionPolicy'), isFalse);

    final roundTrip = WorkInstruction.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map),
    );
    expect(roundTrip.aiExecution!.worker, 'codex');
    expect(roundTrip.aiExecution!.autoAdvance, isFalse);
    expect(roundTrip.aiExecution!.approvalMode, 'manual');
  });

  test('production ebook approvalMode manual/auto round trip', () {
    final manual = AiExecutionPolicy.productionEbook();
    final automatic = AiExecutionPolicy.productionEbook(approvalMode: 'auto');

    expect(manual.approvalMode, 'manual');
    expect(manual.approvalRequired, isTrue);
    expect(manual.autoAdvance, isFalse);
    expect(manual.maxAutoStageOrder, 12);
    expect(manual.deploymentAllowed, isFalse);

    expect(automatic.approvalMode, 'auto');
    expect(automatic.approvalRequired, isFalse);
    expect(automatic.autoAdvance, isTrue);
    expect(automatic.deploymentAllowed, isFalse);

    final restored = AiExecutionPolicy.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(automatic.toJson())) as Map,
      ),
    );
    expect(restored.approvalMode, 'auto');
    expect(restored.autoAdvance, isTrue);
    expect(restored.deploymentAllowed, isFalse);
  });

  test('legacy approvalRequired keeps safe approval mode compatibility', () {
    final manual = AiExecutionPolicy.fromJson({
      'enabled': true,
      'approvalRequired': true,
    });
    final automatic = AiExecutionPolicy.fromJson({
      'enabled': true,
      'approvalRequired': false,
    });
    expect(manual.approvalMode, 'manual');
    expect(automatic.approvalMode, 'auto');
  });

  test('기본 buildInstruction은 aiExecution 없음 (legacy 보호)', () {
    final input = ebookInput();
    final wi = service.buildInstruction(
      planId: 'plan_legacy_1',
      input: input,
      analysis: analysisFor(input),
      instructionId: 'wi_plan_1785905165067',
    );
    expect(wi.aiExecution, isNull);
    expect(wi.toJson().containsKey('aiExecution'), isFalse);
  });

  test('legacy JSON 로드 시 enabled 기본값 오염 없음', () {
    final input = ebookInput();
    final wi = service.buildInstruction(
      planId: 'plan_legacy_2',
      input: input,
      analysis: analysisFor(input),
      instructionId: 'wi_plan_legacy_roundtrip',
    );
    final map = wi.toJson();
    expect(map.containsKey('aiExecution'), isFalse);
    final loaded = WorkInstruction.fromJson(map);
    expect(loaded.aiExecution, isNull);
  });

  test('executionPolicy alias 읽기 호환', () {
    final input = ebookInput();
    final base = service.buildInstruction(
      planId: 'plan_alias',
      input: input,
      analysis: analysisFor(input),
      instructionId: 'wi_plan_alias_1',
    );
    final map = base.toJson();
    map['executionPolicy'] = AiExecutionPolicy.pilotCodexStage1.toJson();
    final loaded = WorkInstruction.fromJson(map);
    expect(loaded.aiExecution?.enabled, isTrue);
    expect(loaded.aiExecution?.maxAutoStageOrder, 1);
  });

  test('idea_clarify workflow 유지', () {
    final input = ebookInput();
    final wi = service.buildInstruction(
      planId: 'plan_wf',
      input: input,
      analysis: analysisFor(input),
      instructionId: 'wi_plan_wf_1',
      aiExecution: AiExecutionPolicy.pilotCodexStage1,
    );
    expect(wi.workflowSteps.length, 18);
    expect(wi.workflowSteps.first.id, 'idea_clarify');
    expect(wi.contract?.workflow.startStage, 'idea_clarify');
  });
}
