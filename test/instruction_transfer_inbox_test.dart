import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/services/browser_json_download_service.dart';
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
    ensureBrowserJsonDownloadRegistered();
    resetBrowserJsonDownloadCallCount();
    browserJsonDownloadBlocked = false;
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
    final before = browserJsonDownloadCallCount;
    browserJsonDownloadBlocked = true;
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
        // 전달 중 다운로드 시도가 있으면 차단되어야 함
        expect(browserJsonDownloadCallCount, before);
        inbox[n] = content;
      },
    ).whenComplete(() {
      browserJsonDownloadBlocked = false;
    });
  }

  test('Inbox 폴더 선택 상태에서 전달 클릭: download 0회, writeJsonFile 1회', () async {
    final before = browserJsonDownloadCallCount;
    final result = await transferDirect(payload: _sampleInstruction());
    expect(result.ok, isTrue);
    expect(result.mode, 'folder');
    expect(result.outcome, TransferOutcome.transferred);
    expect(writeCount, 1);
    expect(browserJsonDownloadCallCount, before);
  });

  test('Inbox 쓰기 실패: download 0회, 오류 표시', () async {
    final before = browserJsonDownloadCallCount;
    final payload = _sampleInstruction();
    browserJsonDownloadBlocked = true;
    final result = await performInboxDirectTransfer(
      fileName: 'WI_fail_v1.json',
      jsonText: _encode(payload),
      instructionId: '${payload['instructionId']}',
      version: 1,
      expectedChecksum: stableContentChecksum(payload),
      readExisting: (_) async => (text: null, size: 0),
      writeFile: (name, content) async {
        throw StateError('disk full');
      },
    );
    browserJsonDownloadBlocked = false;
    expect(result.ok, isFalse);
    expect(result.mode, 'failed');
    expect(result.errorCode, 'write_failed');
    expect(browserJsonDownloadCallCount, before);
  });

  test('수동 다운로드 버튼: downloadJsonFile 1회, writeJsonFile 0회', () async {
    final transfer = InstructionTransferService();
    final payload = _sampleInstruction();
    final before = browserJsonDownloadCallCount;
    final r = await transfer.downloadJsonFile(
      fileName: 'manual.json',
      jsonText: _encode(payload),
    );
    expect(r.outcome, TransferOutcome.downloadOnly);
    expect(r.mode, PlanProgressStatus.downloadMode);
    expect(r.ok, isFalse);
    expect(browserJsonDownloadCallCount, before + 1);
    expect(writeCount, 0);

    final fail = await transfer.writeJsonFile(
      fileName: 'x.json',
      jsonText: _encode(payload),
    );
    expect(fail.ok, isFalse);
    expect(browserJsonDownloadCallCount, before + 1);
  });

  test('동일 지시서 재전달: 기존 Inbox 파일 확인, Conflict 없음', () async {
    final payload = _sampleInstruction();
    final first = await transferDirect(payload: payload);
    expect(first.outcome, TransferOutcome.transferred);
    final second = await transferDirect(payload: payload);
    expect(second.outcome, TransferOutcome.alreadyExists);
    expect(second.ok, isTrue);
    expect(second.message, contains('기존 Inbox 파일 확인'));
    expect(writeCount, 1);
    expect(browserJsonDownloadCallCount, 0);
  });

  test('전달 중 다운로드 게이트가 다운로드를 차단한다', () {
    browserJsonDownloadBlocked = true;
    expect(
      () => triggerBrowserJsonDownload(fileName: 'x.json', jsonText: '{}'),
      throwsA(isA<StateError>()),
    );
    expect(browserJsonDownloadCallCount, 1); // 시도는 기록
    browserJsonDownloadBlocked = false;
  });

  test('핸들 이름만 있고 실제 핸들 없음 → 전달 준비 false', () {
    final state = buildInboxFolderState(
      supported: true,
      hasHandle: false,
      folderName: 'Inbox',
      permissionGranted: false,
    );
    expect(state.readyToWrite, isFalse);
    expect(state.needsReselect, isTrue);
  });

  test('권한 만료 → 재선택 안내', () {
    final state = buildInboxFolderState(
      supported: true,
      hasHandle: true,
      folderName: 'Inbox',
      permissionGranted: false,
    );
    expect(state.readyToWrite, isFalse);
    expect(state.statusMessage, contains('재승인'));
  });

  test('재읽기 검증 instructionId/version/checksum', () async {
    final payload = _sampleInstruction();
    final result = await transferDirect(payload: payload);
    expect(result.verified, isTrue);
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

  test('동일 버전 다른 내용 → 충돌·미덮어쓰기', () async {
    final a = _sampleInstruction(topic: 'A안');
    await transferDirect(payload: a);
    final b = _sampleInstruction(topic: 'B안');
    final conflict = await transferDirect(payload: b);
    expect(conflict.outcome, TransferOutcome.conflict);
    expect(conflict.ok, isFalse);
    expect(writeCount, 1);
    final stored = jsonDecode(inbox.values.single) as Map;
    expect(stored['businessIdea'], 'A안');
  });

  test('Active 불일치 → 차단', () {
    final active = _encode(_sampleInstruction(id: 'wi_other'));
    final gate = gateActiveSnapshotForTransfer(
      activeText: active,
      selectedInstructionId: 'wi_plan_1785892893471',
      selectedVersion: 1,
      selectedArtifactType: 'ebook',
    );
    expect(gate.allowed, isFalse);
  });
}
