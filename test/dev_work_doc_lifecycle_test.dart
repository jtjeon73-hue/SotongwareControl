import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/dev_work_doc_status.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';
import 'package:sotong_ware_control/services/dev_work_doc_paths.dart';
import 'package:sotong_ware_control/services/dev_work_doc_service.dart';
import 'package:sotong_ware_control/services/instruction_transfer_types.dart';

void main() {
  final service = BusinessPlanningService();
  const iid = 'wi_lifecycle_test';

  BusinessPlanInput sampleInput() => const BusinessPlanInput(
    topic: '[TEST] lifecycle',
    customerProblem: '문제',
    targetCustomer: '고객',
    desiredOutcome: '결과',
    artifactType: ArtifactType.ebook,
    deliverableTypes: [ArtifactType.ebook],
  );

  String sampleJson() {
    final instruction = service.buildInstruction(
      planId: 'plan_lifecycle',
      input: sampleInput(),
      analysis: service.analyze(sampleInput()),
      instructionId: iid,
      version: 1,
    );
    return const JsonEncoder.withIndent('  ').convert(instruction.toJson());
  }

  test(
    'stub saveInstruction returns failed (not fake download success)',
    () async {
      final devWorkDoc = DevWorkDocService();
      final result = await devWorkDoc.saveInstruction(
        artifactType: ArtifactType.ebook,
        instructionId: iid,
        version: 1,
        jsonText: sampleJson(),
      );

      expect(result.ok, isFalse);
      expect(result.mode, 'failed');
      expect(result.outcome, DevWorkDocSaveOutcome.failed);
      expect(
        result.activePathHint,
        DevWorkDocPaths.activeRelative(ArtifactType.ebook, iid),
      );
      expect(
        result.versionPathHint,
        DevWorkDocPaths.versionRelative(ArtifactType.ebook, iid, 1),
      );
    },
  );

  test(
    'downloadInstructionJson is explicit download-only with ok false',
    () async {
      final devWorkDoc = DevWorkDocService();
      final result = await devWorkDoc.downloadInstructionJson(
        artifactType: ArtifactType.ebook,
        instructionId: iid,
        version: 1,
        jsonText: sampleJson(),
      );

      expect(result.ok, isFalse);
      expect(result.mode, 'download');
      expect(result.outcome, DevWorkDocSaveOutcome.downloadOnly);
      expect(result.errorCode, 'download_only');
      expect(result.message, contains('DevWorkDoc 직접 저장 아님'));
    },
  );

  test('DevWorkDocStatus.resolve for folder-not-set vs download complete', () {
    const unsupported = DevWorkDocState(supported: false, hasRoot: false);
    final notSet = DevWorkDocStatus.resolve(
      devDocState: unsupported,
      lastSaveResult: null,
      instruction: null,
      activeDoc: null,
      transferFolder: null,
      input: sampleInput(),
    );
    expect(notSet.kind, DevWorkDocStatusKind.folderNotSet);
    expect(notSet.nextAction, contains('JSON 다운로드'));

    final downloaded = DevWorkDocStatus.resolve(
      devDocState: unsupported,
      lastSaveResult: DevWorkDocWriteResult.download(
        fileName: 'WI_test_v1.json',
        message: '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님)',
        activePathHint: 'Ebook/Active/WI_test.json',
        versionPathHint: 'Ebook/Versions/test/WI_test_v1.json',
      ),
      instruction: null,
      activeDoc: null,
      transferFolder: null,
      input: sampleInput(),
    );
    expect(downloaded.kind, DevWorkDocStatusKind.browserDownloadComplete);
    expect(downloaded.label, contains('DevWorkDoc 직접 저장 아님'));
  });

  test('DevWorkDocStatus.resolve for transfer-ready', () {
    final input = sampleInput();
    final instruction = service.buildInstruction(
      planId: 'plan_lifecycle',
      input: input,
      analysis: service.analyze(input),
      instructionId: iid,
      version: 1,
    );
    final ready = DevWorkDocStatus.resolve(
      devDocState: const DevWorkDocState(
        supported: true,
        hasRoot: true,
        rootFolderName: 'DevWorkDoc',
        permissionGranted: true,
        selectionKind: DevWorkDocSelectionKind.devWorkDocRoot,
        structureOk: true,
        readyToWrite: true,
      ),
      lastSaveResult: DevWorkDocWriteResult(
        ok: true,
        mode: 'folder',
        outcome: DevWorkDocSaveOutcome.completeSuccess,
        activePathHint: DevWorkDocPaths.activeRelative(ArtifactType.ebook, iid),
        activeVerified: true,
        versionsVerified: true,
      ),
      instruction: instruction,
      activeDoc: BusinessPlanDocument(
        id: 'plan_lifecycle',
        input: input,
        status: PlanningStatus.instructionReady,
        createdAt: '2026-08-05T00:00:00Z',
        updatedAt: '2026-08-05T00:00:00Z',
        instructionId: iid,
        instruction: instruction,
        version: 1,
      ),
      transferFolder: const FolderPermissionState(
        supported: true,
        hasHandle: true,
        folderName: 'Inbox',
      ),
      input: input,
    );
    expect(ready.kind, DevWorkDocStatusKind.transferReady);
  });
}
