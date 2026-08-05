import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/dev_work_doc_status.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/services/dev_work_doc_fs.dart';
import 'package:sotong_ware_control/services/dev_work_doc_save_pipeline.dart';
import 'package:sotong_ware_control/services/dev_work_doc_types.dart';
import 'package:sotong_ware_control/services/instruction_content_checksum.dart';
import 'package:sotong_ware_control/services/instruction_transfer_types.dart';

void main() {
  Map<String, dynamic> sampleMap({
    String updatedAt = '2026-01-01T00:00:00.000Z',
    String idea = '주제A',
    String version = '1',
    String checksum = 'abc',
  }) => {
    'schemaVersion': '1.0',
    'instructionId': 'wi_plan_1785891643016',
    'projectId': 'plan_x',
    'instructionVersion': version,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'updatedAt': updatedAt,
    'businessIdea': idea,
    'businessPurpose': '결과',
    'customerProblem': '문제',
    'targetCustomer': '고객',
    'deliverableTypes': ['ebook', 'contents'],
    'recommendedSequence': ['ebook', 'contents'],
    'valueProposition': '가치',
    'requiredMaterials': ['m1'],
    'workflowSteps': [
      {'id': '1', 'title': '단계1'},
      {'id': '2', 'title': '단계2'},
    ],
    'completionCriteria': ['c1'],
    'qualityChecks': ['q1'],
    'risks': ['r1'],
    'monetizationOptions': ['mo1'],
    'deploymentTargets': ['d1'],
    'promotionChannels': ['p1'],
    'approvalItems': ['a1'],
    'executionStatus': '지시서 준비',
    'notes': '',
    'primaryTrack': 'ebook',
    'followUpTracks': ['contents'],
    'artifactType': 'ebook',
    'contentSubtype': '',
    'checksum': checksum,
    'sourceFileName': 'WI_wi_plan_1785891643016.json',
    'status': 'instruction_ready',
  };

  String sampleJson({
    String updatedAt = '2026-01-01T00:00:00.000Z',
    String idea = '주제A',
    String version = '1',
    String checksum = 'abc',
  }) => const JsonEncoder.withIndent('  ').convert(
    sampleMap(
      updatedAt: updatedAt,
      idea: idea,
      version: version,
      checksum: checksum,
    ),
  );

  group('stable content checksum', () {
    test('1: same snapshot serialized twice → same checksum', () {
      final a = sampleJson();
      final b = sampleJson();
      expect(stableContentChecksum(a), stableContentChecksum(b));
      expect(contentChecksum(a), contentChecksum(b));
    });

    test('2: updatedAt change does not change content checksum', () {
      final a = sampleJson(updatedAt: '2026-01-01T00:00:00.000Z');
      final b = sampleJson(updatedAt: '2026-08-05T01:02:03.456Z');
      expect(stableContentChecksum(a), stableContentChecksum(b));
      expect(contentChecksumRaw(a), isNot(contentChecksumRaw(b)));
    });

    test('3: key order difference → same checksum', () {
      final m1 = sampleMap();
      final m2 = Map<String, dynamic>.fromEntries(m1.entries.toList().reversed);
      expect(stableContentChecksum(m1), stableContentChecksum(m2));
    });

    test('6: core same metadata only', () {
      final diff = diffInstructionContent(
        sampleJson(updatedAt: 't1', checksum: 'c1'),
        sampleJson(updatedAt: 't2', checksum: 'c2'),
      );
      expect(diff.isSameCore, isTrue);
      expect(diff.metadataOnlyDifferences, isNotEmpty);
    });

    test('7: core different', () {
      final diff = diffInstructionContent(
        sampleJson(idea: '주제A'),
        sampleJson(idea: '주제B'),
      );
      expect(diff.relation, InstructionContentRelation.differentCore);
    });
  });

  group('partial save recovery pipeline', () {
    StrictMemoryFs seeded() {
      final fs = StrictMemoryFs();
      fs.dirs.addAll({
        '/Ebook/',
        '/Ebook/Active/',
        '/Ebook/Versions/',
        '/Ebook/Archive/',
      });
      return fs;
    }

    test(
      '4-5: Versions ok Active fail then retry recovers without conflict',
      () async {
        final fs = seeded();
        final pipeline = DevWorkDocSavePipeline(fs);
        final json = sampleJson(updatedAt: '2026-01-01T00:00:00.000Z');

        fs.failActiveWrite = true;
        final partial = await pipeline.saveInstruction(
          artifactType: 'ebook',
          instructionId: 'wi_plan_1785891643016',
          version: 1,
          jsonText: json,
        );
        expect(partial.outcome, DevWorkDocSaveOutcome.partialSuccess);
        expect(partial.versionsVerified, isTrue);

        fs.failActiveWrite = false;
        // 재시도: updatedAt만 다른 JSON
        final retryJson = sampleJson(updatedAt: '2026-08-05T12:00:00.000Z');
        final retry = await pipeline.saveInstruction(
          artifactType: 'ebook',
          instructionId: 'wi_plan_1785891643016',
          version: 1,
          jsonText: retryJson,
        );
        expect(retry.ok, isTrue);
        expect(
          retry.outcome == DevWorkDocSaveOutcome.recoveredFromPartial ||
              retry.outcome == DevWorkDocSaveOutcome.alreadyExists ||
              retry.outcome == DevWorkDocSaveOutcome.completeSuccess,
          isTrue,
        );
        expect(
          (await fs.readFile([
            'Ebook',
            'Active',
          ], 'WI_wi_plan_1785891643016.json')).text,
          isNotNull,
        );
        // Versions는 최초 스냅샷 유지 (덮어쓰지 않음)
        expect(
          (await fs.readFile([
            'Ebook',
            'Versions',
            'wi_plan_1785891643016',
          ], 'WI_wi_plan_1785891643016_v1.json')).text,
          json,
        );
      },
    );

    test('8: core conflict does not overwrite Versions', () async {
      final fs = seeded();
      final pipeline = DevWorkDocSavePipeline(fs);
      final v1 = sampleJson(idea: '주제A');
      await pipeline.saveInstruction(
        artifactType: 'ebook',
        instructionId: 'wi_plan_1785891643016',
        version: 1,
        jsonText: v1,
      );
      final conflict = await pipeline.saveInstruction(
        artifactType: 'ebook',
        instructionId: 'wi_plan_1785891643016',
        version: 1,
        jsonText: sampleJson(idea: '주제B'),
      );
      expect(conflict.outcome, DevWorkDocSaveOutcome.conflict);
      expect(conflict.ok, isFalse);
      expect(
        (await fs.readFile([
          'Ebook',
          'Versions',
          'wi_plan_1785891643016',
        ], 'WI_wi_plan_1785891643016_v1.json')).text,
        v1,
      );
    });

    test('9: next version only after explicit new version number', () async {
      final fs = seeded();
      final pipeline = DevWorkDocSavePipeline(fs);
      await pipeline.saveInstruction(
        artifactType: 'ebook',
        instructionId: 'wi_plan_1785891643016',
        version: 1,
        jsonText: sampleJson(version: '1', idea: '주제A'),
      );
      final v2 = await pipeline.saveInstruction(
        artifactType: 'ebook',
        instructionId: 'wi_plan_1785891643016',
        version: 2,
        jsonText: sampleJson(version: '2', idea: '주제B'),
        isNewVersion: true,
      );
      expect(v2.ok, isTrue);
      expect(
        await fs.fileExists([
          'Ebook',
          'Versions',
          'wi_plan_1785891643016',
        ], 'WI_wi_plan_1785891643016_v1.json'),
        isTrue,
      );
      expect(
        await fs.fileExists([
          'Ebook',
          'Versions',
          'wi_plan_1785891643016',
        ], 'WI_wi_plan_1785891643016_v2.json'),
        isTrue,
      );
    });

    test(
      '10: partial state keeps version number (no auto bump in pipeline)',
      () async {
        final fs = seeded();
        final pipeline = DevWorkDocSavePipeline(fs);
        fs.failActiveWrite = true;
        final r = await pipeline.saveInstruction(
          artifactType: 'ebook',
          instructionId: 'wi_plan_1785891643016',
          version: 2,
          jsonText: sampleJson(version: '2'),
        );
        expect(r.version, 2);
        expect(r.outcome, DevWorkDocSaveOutcome.partialSuccess);
      },
    );

    test('11-12: v1 v2 exist Active missing → restore from latest', () async {
      final fs = seeded();
      final pipeline = DevWorkDocSavePipeline(fs);
      final v1 = sampleJson(version: '1', idea: 'A');
      final v2 = sampleJson(version: '2', idea: 'B');
      await fs.writeFile(
        ['Ebook', 'Versions', 'wi_plan_1785891643016'],
        'WI_wi_plan_1785891643016_v1.json',
        v1,
      );
      await fs.writeFile(
        ['Ebook', 'Versions', 'wi_plan_1785891643016'],
        'WI_wi_plan_1785891643016_v2.json',
        v2,
      );

      final restored = await pipeline.restoreActiveFromVersionText(
        artifactType: 'ebook',
        instructionId: 'wi_plan_1785891643016',
        version: 2,
        versionJsonText: v2,
      );
      expect(restored.ok, isTrue);
      expect(restored.outcome, DevWorkDocSaveOutcome.recoveredFromPartial);
      expect(
        (await fs.readFile([
          'Ebook',
          'Active',
        ], 'WI_wi_plan_1785891643016.json')).text,
        v2,
      );
    });
  });

  group('error banner version match', () {
    test(
      '13-14: stale v1 error hidden when viewing v2; cleared after success',
      () {
        const input = BusinessPlanInput(
          topic: 't',
          customerProblem: 'p',
          targetCustomer: 'c',
          desiredOutcome: 'o',
          artifactType: ArtifactType.ebook,
        );
        final instruction = WorkInstruction(
          schemaVersion: '1.0',
          instructionId: 'wi_plan_1785891643016',
          projectId: 'p',
          instructionVersion: '2',
          createdAt: 't',
          updatedAt: 't',
          businessIdea: 't',
          businessPurpose: 'o',
          customerProblem: 'p',
          targetCustomer: 'c',
          deliverableTypes: const ['ebook'],
          recommendedSequence: const ['ebook'],
          valueProposition: 'v',
          requiredMaterials: const [],
          workflowSteps: const [],
          completionCriteria: const [],
          qualityChecks: const [],
          risks: const [],
          monetizationOptions: const [],
          deploymentTargets: const [],
          promotionChannels: const [],
          approvalItems: const [],
          executionStatus: '지시서 준비',
        );

        final staleV1 = DevWorkDocWriteResult.failed(
          message: 'v1 충돌',
          outcome: DevWorkDocSaveOutcome.conflict,
          instructionId: 'wi_plan_1785891643016',
          version: 1,
        );
        final statusStale = DevWorkDocStatus.resolve(
          devDocState: const DevWorkDocState(
            supported: true,
            hasRoot: true,
            readyToWrite: true,
            permissionGranted: true,
          ),
          lastSaveResult: staleV1,
          instruction: instruction,
          activeDoc: null,
          transferFolder: null,
          input: input,
        );
        // v2 화면에서 v1 오류는 실패 배너로 남지 않음
        expect(statusStale.kind, isNot(DevWorkDocStatusKind.failed));

        final success = DevWorkDocWriteResult(
          ok: true,
          mode: 'folder',
          outcome: DevWorkDocSaveOutcome.completeSuccess,
          instructionId: 'wi_plan_1785891643016',
          version: 2,
          activeVerified: true,
          versionsVerified: true,
          activePathHint: 'Ebook/Active/x.json',
        );
        final statusOk = DevWorkDocStatus.resolve(
          devDocState: const DevWorkDocState(
            supported: true,
            hasRoot: true,
            readyToWrite: true,
            permissionGranted: true,
          ),
          lastSaveResult: success,
          instruction: instruction,
          activeDoc: null,
          transferFolder: const FolderPermissionState(
            supported: true,
            hasHandle: false,
          ),
          input: input,
        );
        expect(statusOk.kind, isNot(DevWorkDocStatusKind.failed));
      },
    );
  });
}

class StrictMemoryFs extends MemoryDevWorkDocFs {
  bool failActiveWrite = false;

  @override
  Future<void> writeFile(
    List<String> dirSegments,
    String fileName,
    String content,
  ) async {
    if (failActiveWrite &&
        dirSegments.length >= 2 &&
        dirSegments[1] == 'Active') {
      throw FsNotFoundException(
        step: DevWorkDocSaveStep.activeFileWrite,
        relativePath: [...dirSegments, fileName].join('/'),
        message: 'simulated',
      );
    }
    await super.writeFile(dirSegments, fileName, content);
  }
}
