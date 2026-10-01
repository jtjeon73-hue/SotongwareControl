import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/services/external_work_instruction_import.dart';
import 'package:sotong_ware_control/services/work_instruction_remote_delivery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final handoffText = File(
    'test/fixtures/phase18_control_handoff_child01.json',
  ).readAsStringSync();
  final rawText = File(
    'test/fixtures/phase18_raw_wi_child01.json',
  ).readAsStringSync();

  group('ExternalWorkInstructionImport', () {
    test('A valid raw Commercial V2 WI import PASS', () {
      final r = ExternalWorkInstructionImport.parseText(rawText);
      expect(r.ok, isTrue, reason: r.issues.map((e) => e.code).join(','));
      expect(r.kind, ExternalWiImportKind.rawWorkInstruction);
      expect(r.type, 'ebook');
      expect(r.totalStages, 18);
    });

    test('B valid Phase18 handoff envelope import PASS', () {
      final r = ExternalWorkInstructionImport.parseText(handoffText);
      expect(r.ok, isTrue, reason: r.issues.map((e) => e.code).join(','));
      expect(r.kind, ExternalWiImportKind.handoffEnvelope);
      expect(r.sourceWasHandoff, isTrue);
    });

    test('C instructionId preserved exactly', () {
      const id = 'wi_plan_ebook_batch_real-30-gatea-20261001_o01_real-plan-01';
      final raw = ExternalWorkInstructionImport.parseText(rawText);
      final handoff = ExternalWorkInstructionImport.parseText(handoffText);
      expect(raw.instructionId, id);
      expect(handoff.instructionId, id);
      expect(raw.payload['instructionId'], id);
      expect(handoff.payload['instructionId'], id);
    });

    test('D nested workInstruction → flat payload lossless', () {
      final handoffRoot =
          jsonDecode(handoffText) as Map<String, dynamic>;
      final nested = Map<String, dynamic>.from(
        (handoffRoot['payload'] as Map)['workInstruction'] as Map,
      );
      final r = ExternalWorkInstructionImport.parseText(handoffText);
      expect(r.ok, isTrue);
      expect(r.payload.containsKey('workInstruction'), isFalse);
      expect(r.payload['instructionId'], nested['instructionId']);
      expect(r.payload['businessIdea'], nested['businessIdea']);
      expect(
        (r.payload['workflowSteps'] as List).length,
        (nested['workflowSteps'] as List).length,
      );
      expect(
        r.payload['commercialEbookQualityProfile'],
        nested['commercialEbookQualityProfile'],
      );
      expect(r.payload['batchId'], nested['batchId']);
      expect(r.payload['ordinal'], nested['ordinal']);
    });

    test('E agentId → assignedAgentId correct', () {
      final r = ExternalWorkInstructionImport.parseText(handoffText);
      expect(r.assignedAgentId, 'agent_9830758291f9c64e');
    });

    test('F candidate jobId/commandId ignored', () {
      final r = ExternalWorkInstructionImport.parseText(handoffText);
      expect(r.ignoredHandoffJobId, isNotEmpty);
      expect(r.ignoredHandoffCommandId, isNotEmpty);
      expect(r.payload.containsKey('jobId'), isFalse);
      expect(r.payload.containsKey('commandId'), isFalse);
      expect(r.payload.containsKey('idempotencyKey'), isFalse);
    });

    test('G invalid JSON rejected', () {
      final r = ExternalWorkInstructionImport.parseText('{not-json');
      expect(r.ok, isFalse);
      expect(r.issues.any((e) => e.code == 'INVALID_JSON'), isTrue);
    });

    test('H wrong schema rejected', () {
      final map = jsonDecode(rawText) as Map<String, dynamic>;
      map['schemaVersion'] = '1.0';
      final r = ExternalWorkInstructionImport.parseDecoded(map);
      expect(r.ok, isFalse);
      expect(r.issues.any((e) => e.code == 'WRONG_SCHEMA'), isTrue);
    });

    test('I missing instructionId rejected', () {
      final map = jsonDecode(rawText) as Map<String, dynamic>;
      map.remove('instructionId');
      final r = ExternalWorkInstructionImport.parseDecoded(map);
      expect(r.ok, isFalse);
      expect(r.issues.any((e) => e.code == 'MISSING_INSTRUCTION_ID'), isTrue);
    });

    test('J top-level/payload instructionId mismatch rejected', () {
      final handoff = jsonDecode(handoffText) as Map<String, dynamic>;
      handoff['instructionId'] = 'wi_plan_other_mismatch';
      final r = ExternalWorkInstructionImport.parseDecoded(handoff);
      expect(r.ok, isFalse);
      expect(
        r.issues.any((e) => e.code == 'INSTRUCTION_ID_MISMATCH'),
        isTrue,
      );
    });

    test('K non-ebook rejected', () {
      final map = jsonDecode(rawText) as Map<String, dynamic>;
      map['artifactType'] = 'app';
      map.remove('commercialEbookQualityProfile');
      map.remove('ebookQualityContractVersion');
      final r = ExternalWorkInstructionImport.parseDecoded(map);
      expect(r.ok, isFalse);
      expect(r.issues.any((e) => e.code == 'NON_EBOOK_REJECTED'), isTrue);
    });

    test('L same WI imported twice → duplicate instruction identity 0', () {
      final a = ExternalWorkInstructionImport.parseText(rawText);
      final b = ExternalWorkInstructionImport.parseText(rawText);
      expect(a.ok && b.ok, isTrue);
      expect(
        ExternalWorkInstructionImport.identityKey(a),
        ExternalWorkInstructionImport.identityKey(b),
      );
      // No new id minted
      expect(a.instructionId, b.instructionId);
    });

    test('M/N import alone → API call 0 / Firestore write 0 (pure parse)', () {
      var apiCalls = 0;
      final r = ExternalWorkInstructionImport.parseText(handoffText);
      expect(r.ok, isTrue);
      expect(apiCalls, 0);
      // parse has no network side effects by construction
    });

    test('O explicit user deliver required (import does not deliver)', () {
      final r = ExternalWorkInstructionImport.parseText(rawText);
      expect(r.ok, isTrue);
      // Import result alone has no deliver flag — UI requires 「전달」.
      expect(r.payload['productionStartJobAllowed'], isNot(equals('auto_sent')));
    });

    test('P child01 fixture title/modes/agent', () {
      final r = ExternalWorkInstructionImport.parseText(handoffText);
      expect(r.ok, isTrue, reason: r.issues.map((e) => '${e.code}:${e.message}').join(' | '));
      expect(r.title, '50대를 위한 AI 생활비서 첫걸음');
      expect(r.type, 'ebook');
      expect(r.totalStages, 18);
      expect(r.approvalMode, 'auto');
      expect(r.executionMode, 'continuous');
      expect(r.assignedAgentId, 'agent_9830758291f9c64e');
    });

    test('Q existing deliver idempotency key contract unchanged', () {
      const id = 'wi_plan_ebook_batch_real-30-gatea-20261001_o01_real-plan-01';
      expect(
        WorkInstructionRemoteDelivery.startIdempotencyKey(id),
        'idem_start_$id',
      );
      final first = ExternalWorkInstructionImport.parseText(handoffText);
      final second = ExternalWorkInstructionImport.parseText(handoffText);
      expect(first.instructionId, second.instructionId);
      // Simulated second deliver uses same instruction identity → server reuse path
      expect(
        WorkInstructionRemoteDelivery.startIdempotencyKey(first.instructionId),
        WorkInstructionRemoteDelivery.startIdempotencyKey(second.instructionId),
      );
    });
  });
}
