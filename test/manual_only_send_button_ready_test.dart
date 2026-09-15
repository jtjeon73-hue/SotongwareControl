import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/instruction_contract_validator.dart';
import 'package:sotong_ware_control/services/work_instruction_delivery_presentation.dart';

/// READY modal(Contract VALID)과 「로컬 검증 후 보내기」 enable predicate 일치 검증.
void main() {
  final now = DateTime.utc(2026, 9, 15, 15, 0);

  RemoteAgentDoc onlineAgent() => RemoteAgentDoc(
    agentId: 'a1',
    ownerUid: 'u',
    deviceName: 'JT-JEON',
    state: 'idle',
    enabled: true,
    lastHeartbeatAt: now.subtract(const Duration(seconds: 5)),
  );

  RemoteAgentDoc staleAgent() => RemoteAgentDoc(
    agentId: 'a2',
    ownerUid: 'u',
    deviceName: 'STALE',
    state: 'idle',
    enabled: true,
    lastHeartbeatAt: now.subtract(const Duration(minutes: 3)),
  );

  const valid = ContractValidationResult(
    level: ContractValidationLevel.valid,
    issues: [],
  );

  const blockedCanonical = ContractValidationResult(
    level: ContractValidationLevel.blocked,
    issues: [
      ContractValidationIssue(
        field: 'projectDefinition.title',
        reason: 'canonical title이 pending/빈 값입니다.',
        fix: '제목을 확정하세요.',
        level: ContractValidationLevel.blocked,
      ),
    ],
  );

  const blockedProduction = ContractValidationResult(
    level: ContractValidationLevel.blocked,
    issues: [
      ContractValidationIssue(
        field: 'productionSpec.undecidedKeys',
        reason: '미정 제작 옵션: format, pages',
        fix: '제작 정보를 선택하세요.',
        level: ContractValidationLevel.blocked,
      ),
    ],
  );

  group('manualOnly send button ↔ READY SSOT', () {
    test('READY + agent online + not yet local-validated → send enabled', () {
      final view = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: valid,
        agents: [onlineAgent()],
        transferBusy: false,
        now: now,
        localCommercialValidated: false,
      );
      expect(view.buttonEnabled, isTrue);
      expect(view.buttonLabel, '로컬 검증 후 보내기');
      expect(view.buttonState, DeliveryButtonState.ready);
      // 문제 항목 확인 modal과 동일 SSOT (canTransfer)
      expect(valid.canTransfer, isTrue);
      expect(valid.ok, isTrue);
    });

    test('READY + already local-validated → normal transfer label enabled', () {
      final view = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: valid,
        agents: [onlineAgent()],
        transferBusy: false,
        now: now,
        localCommercialValidated: true,
      );
      expect(view.buttonEnabled, isTrue);
      expect(view.buttonLabel, '소통24워크 Agent로 전달');
    });

    test('canonical blocked → send disabled', () {
      final view = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: blockedCanonical,
        agents: [onlineAgent()],
        transferBusy: false,
        now: now,
        localCommercialValidated: false,
      );
      expect(view.buttonEnabled, isFalse);
      expect(view.buttonState, DeliveryButtonState.blocked);
      expect(valid.canTransfer, isTrue);
      expect(blockedCanonical.canTransfer, isFalse);
    });

    test('production undecided blocked → send disabled', () {
      final view = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: blockedProduction,
        agents: [onlineAgent()],
        transferBusy: false,
        now: now,
        localCommercialValidated: false,
      );
      expect(view.buttonEnabled, isFalse);
    });

    test('Agent unavailable → send disabled (policy preserved)', () {
      final noAgent = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: valid,
        agents: const [],
        transferBusy: false,
        now: now,
        localCommercialValidated: false,
      );
      expect(noAgent.buttonEnabled, isFalse);
      expect(noAgent.agentStatus.connectivity, AgentConnectivity.noAgent);

      final stale = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: valid,
        agents: [staleAgent()],
        transferBusy: false,
        now: now,
        localCommercialValidated: false,
      );
      expect(stale.buttonEnabled, isFalse);
      expect(stale.agentStatus.connectivity, AgentConnectivity.stale);
    });

    test('regenerate path: localValidated resets then READY re-enables send', () {
      // After WI create, commercialLocalValidated is reset to false.
      final afterCreate = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: valid,
        agents: [onlineAgent()],
        transferBusy: false,
        now: now,
        localCommercialValidated: false,
      );
      expect(afterCreate.buttonEnabled, isTrue);
      expect(afterCreate.buttonLabel, '로컬 검증 후 보내기');

      // After local validate succeeds.
      final afterValidate = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: valid,
        agents: [onlineAgent()],
        transferBusy: false,
        now: now,
        localCommercialValidated: true,
      );
      expect(afterValidate.buttonEnabled, isTrue);
      expect(afterValidate.buttonLabel, '소통24워크 Agent로 전달');
    });

    test('empty agents + not validated stays fail-closed (AI path regress guard)', () {
      final view = WorkInstructionDeliveryPresentation.resolve(
        plan: null,
        validation: null,
        agents: const [],
        transferBusy: false,
        localCommercialValidated: false,
      );
      expect(view.buttonEnabled, isFalse);
    });
  });
}
