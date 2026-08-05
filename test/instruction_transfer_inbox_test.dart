import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/services/instruction_content_checksum.dart';
import 'package:sotong_ware_control/services/instruction_transfer_service.dart';
import 'package:sotong_ware_control/services/plan_progress_status.dart';

Map<String, dynamic> _sampleInstruction({
  String id = 'wi_plan_1785892893471',
  int version = 1,
  String topic = '시골 AI 수익',
  String artifactType = 'ebook',
}) {
  return withCanonicalChecksumFields({
    'schemaVersion': '1',
    'instructionId': id,
    'instructionVersion': '$version',
    'businessIdea': topic,
    'customerProblem': '문제',
    'targetCustomer': '고객',
    'artifactType': artifactType,
    'deliverableTypes': [artifactType],
    'workflowSteps': [
      {'order': 1, 'id': 's1', 'title': '조사', 'applicable': true},
    ],
    'notes': '',
    'contentSubtype': '',
    'status': 'instruction_ready',
    'updatedAt': '2026-08-05T00:00:00Z',
  });
}

String _encode(Map<String, dynamic> map) =>
    const JsonEncoder.withIndent('  ').convert(map);

void main() {
  late Map<String, String> inbox;
  late int writeCount;

  setUp(() {
    inbox = {};
    writeCount = 0;
    resetInstructionTransferManualDownloadCalls();
  });

  Future<TransferWriteResult> transferDirect({
    required Map<String, dynamic> payload,
    String? fileName,
  }) {
    final jsonText = _encode(payload);
    final id = '${payload['instructionId']}';
    final ver = int.parse('${payload['instructionVersion']}');
    final sum = stableContentChecksum(payload);
    final name =
        fileName ??
        inboxTransferFileName(
          instructionId: id,
          version: ver,
          artifactType: '${payload['artifactType']}',
        );
    return performInboxDirectTransfer(
      fileName: name,
      jsonText: jsonText,
      instructionId: id,
      version: ver,
      expectedChecksum: sum,
      readExisting: (n) async {
        final t = inbox[n];
        return (text: t, size: t?.length ?? 0);
      },
      writeFile: (n, content) async {
        writeCount++;
        inbox[n] = content;
      },
    );
  }

  test('1. Inbox 핸들 선택 후 전달 → 직접 파일 쓰기', () async {
    final payload = _sampleInstruction();
    final result = await transferDirect(payload: payload);
    expect(result.ok, isTrue);
    expect(result.mode, 'folder');
    expect(result.outcome, TransferOutcome.transferred);
    expect(writeCount, 1);
    expect(inbox.length, 1);
  });

  test('2. 직접 전달 시 다운로드 helper 호출 0회', () async {
    await transferDirect(payload: _sampleInstruction());
    expect(instructionTransferManualDownloadCalls, 0);
  });

  test('3. Inbox 쓰기 실패 → 다운로드 helper 호출 0회', () async {
    final payload = _sampleInstruction();
    final jsonText = _encode(payload);
    final result = await performInboxDirectTransfer(
      fileName: 'WI_fail_v1.json',
      jsonText: jsonText,
      instructionId: '${payload['instructionId']}',
      version: 1,
      expectedChecksum: stableContentChecksum(payload),
      readExisting: (_) async => (text: null, size: 0),
      writeFile: (name, content) async {
        throw StateError('disk full');
      },
    );
    expect(result.ok, isFalse);
    expect(result.mode, 'failed');
    expect(instructionTransferManualDownloadCalls, 0);
  });

  test('4. 수동 다운로드 버튼에서만 다운로드 helper 1회', () async {
    final transfer = InstructionTransferService();
    final payload = _sampleInstruction();
    final r = await transfer.downloadJsonFile(
      fileName: 'manual.json',
      jsonText: _encode(payload),
    );
    expect(r.outcome, TransferOutcome.downloadOnly);
    expect(r.mode, PlanProgressStatus.downloadMode);
    expect(r.ok, isFalse); // 전달됨 아님
    expect(instructionTransferManualDownloadCalls, 1);

    // write 실패 경로( stub )도 다운로드 증가 없음
    final fail = await transfer.writeJsonFile(
      fileName: 'x.json',
      jsonText: _encode(payload),
    );
    expect(fail.ok, isFalse);
    expect(instructionTransferManualDownloadCalls, 1);
  });

  test('5. Inbox 핸들 이름만 있고 실제 핸들 없음 → 전달 차단', () {
    final state = buildInboxFolderState(
      supported: true,
      hasHandle: false,
      folderName: 'Inbox',
      permissionGranted: false,
    );
    expect(state.readyToWrite, isFalse);
    expect(state.needsReselect, isTrue);
    expect(state.statusMessage, contains('핸들'));
  });

  test('6. 권한 만료 → 재선택 안내', () {
    final state = buildInboxFolderState(
      supported: true,
      hasHandle: true,
      folderName: 'Inbox',
      permissionGranted: false,
    );
    expect(state.readyToWrite, isFalse);
    expect(state.needsReselect, isTrue);
    expect(state.statusMessage, contains('재승인'));
  });

  test('7. 직접 저장 후 재읽기 검증', () async {
    final payload = _sampleInstruction();
    final result = await transferDirect(payload: payload);
    expect(result.verified, isTrue);
    expect(result.bytes, greaterThan(0));
    final name = result.fileName!;
    final v = verifyInboxReadBack(
      text: inbox[name],
      size: inbox[name]!.length,
      expected: InboxReadBackExpectation(
        instructionId: '${payload['instructionId']}',
        version: 1,
        contentChecksum: stableContentChecksum(payload),
      ),
    );
    expect(v.ok, isTrue);
  });

  test('8. instructionId/version/checksum 불일치 → 전달 실패', () async {
    final payload = _sampleInstruction();
    final jsonText = _encode(payload);
    // 쓰기는 성공하지만 재읽기 내용이 조작됨
    final result = await performInboxDirectTransfer(
      fileName: 'WI_bad_v1.json',
      jsonText: jsonText,
      instructionId: '${payload['instructionId']}',
      version: 1,
      expectedChecksum: stableContentChecksum(payload),
      readExisting: (n) async {
        if (!inbox.containsKey(n)) return (text: null, size: 0);
        final tampered = Map<String, dynamic>.from(payload)
          ..['businessIdea'] = '다른 내용';
        final t = _encode(tampered);
        return (text: t, size: t.length);
      },
      writeFile: (n, content) async {
        inbox[n] = content;
      },
    );
    expect(result.ok, isFalse);
    expect(result.errorCode, 'checksum_mismatch');
  });

  test('9. 동일 파일 재전달 → 기존 파일 확인', () async {
    final payload = _sampleInstruction();
    final first = await transferDirect(payload: payload);
    expect(first.outcome, TransferOutcome.transferred);
    final second = await transferDirect(payload: payload);
    expect(second.outcome, TransferOutcome.alreadyExists);
    expect(second.ok, isTrue);
    expect(second.message, contains('기존 Inbox 파일 확인'));
    expect(writeCount, 1); // 덮어쓰기 없음
  });

  test('10. 동일 버전 다른 내용 → 충돌·미덮어쓰기', () async {
    final a = _sampleInstruction(topic: 'A안');
    await transferDirect(payload: a);
    final b = _sampleInstruction(topic: 'B안');
    final conflict = await transferDirect(payload: b);
    expect(conflict.outcome, TransferOutcome.conflict);
    expect(conflict.ok, isFalse);
    expect(writeCount, 1);
    // 기존 내용 유지
    final stored = jsonDecode(inbox.values.single) as Map;
    expect(stored['businessIdea'], 'A안');
  });

  test('11. 현재 선택 기획과 Active 불일치 → 차단', () {
    final active = _encode(_sampleInstruction(id: 'wi_other'));
    final gate = gateActiveSnapshotForTransfer(
      activeText: active,
      selectedInstructionId: 'wi_plan_1785892893471',
      selectedVersion: 1,
      selectedArtifactType: 'ebook',
    );
    expect(gate.allowed, isFalse);
    expect(gate.message, contains('일치하지 않습니다'));
  });

  test('12. 전달 성공 시에만 lastTransferMode=folder', () async {
    final result = await transferDirect(payload: _sampleInstruction());
    expect(result.mode, PlanProgressStatus.folderMode);
    expect(result.isFolderSuccess, isTrue);
    expect(
      PlanProgressStatus.statusAfterTransferAttempt(mode: result.mode),
      'transferred',
    );
  });

  test('13. 다운로드 시 lastTransferMode=download', () async {
    final r = await InstructionTransferService().downloadJsonFile(
      fileName: 'd.json',
      jsonText: _encode(_sampleInstruction()),
    );
    expect(r.mode, PlanProgressStatus.downloadMode);
    expect(
      PlanProgressStatus.statusAfterTransferAttempt(mode: r.mode),
      isNot('transferred'),
    );
  });

  test('14. 다운로드 상태가 전달됨 배지로 표시되지 않음', () {
    expect(TransferWriteResult.downloadOnly(fileName: 'x.json').ok, isFalse);
    expect(
      TransferWriteResult.downloadOnly(fileName: 'x.json').outcome,
      TransferOutcome.downloadOnly,
    );
  });

  test('15. 실제 전달 준비 완료 상태와 파일명 규칙', () {
    final ready = buildInboxFolderState(
      supported: true,
      hasHandle: true,
      folderName: 'Inbox',
      permissionGranted: true,
    );
    expect(ready.readyToWrite, isTrue);
    expect(ready.statusMessage, contains('전달 준비'));

    final name = inboxTransferFileName(
      instructionId: 'wi_plan_1785892893471',
      version: 1,
      artifactType: 'ebook',
    );
    expect(name, 'WI_wi_plan_1785892893471_v1_ebook.json');
  });
}
