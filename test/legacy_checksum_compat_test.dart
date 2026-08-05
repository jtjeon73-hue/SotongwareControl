import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/services/dev_work_doc_fs.dart';
import 'package:sotong_ware_control/services/dev_work_doc_save_pipeline.dart';
import 'package:sotong_ware_control/services/dev_work_doc_types.dart';
import 'package:sotong_ware_control/services/instruction_content_checksum.dart';

/// 운영 구형 fixture (c81f0cc 이전: 전체 JSON checksum, 알고리즘 필드 없음).
Map<String, dynamic> legacyFullJsonFixture({
  String updatedAt = '2026-08-05T01:00:00.000Z',
  String idea = '농촌 AI 전자책',
  String status = 'instruction_ready',
  String? checksumOverride,
  bool includeVersionAlias = false,
  bool includeFollowupAlias = true,
  bool omitContentSubtype = false,
}) {
  final map = <String, dynamic>{
    'schemaVersion': '1.0',
    'instructionId': 'wi_plan_1785892893471',
    'projectId': 'plan_1785892893471',
    'instructionVersion': '1',
    'createdAt': '2026-08-05T00:50:00.000Z',
    'updatedAt': updatedAt,
    'businessIdea': idea,
    'businessPurpose': '실무 적용',
    'customerProblem': '정보 부족',
    'targetCustomer': '농촌 소상공인',
    'deliverableTypes': ['ebook', 'contents'],
    'recommendedSequence': ['ebook', 'contents'],
    'valueProposition': '검증된 전자책부터',
    'requiredMaterials': ['자료'],
    'workflowSteps': [
      {
        'order': 1,
        'id': 's1',
        'title': '기획',
        'applicable': true,
        'statusLabel': '적용',
        'completionCriteria': '완료',
        'notes': '',
      },
      {
        'order': 2,
        'id': 's2',
        'title': '집필',
        'applicable': true,
        'statusLabel': '적용',
        'completionCriteria': '초안',
        'notes': '',
      },
    ],
    'completionCriteria': ['검수'],
    'qualityChecks': ['맞춤법'],
    'risks': ['일정'],
    'monetizationOptions': ['판매'],
    'deploymentTargets': ['스토어'],
    'promotionChannels': ['블로그'],
    'approvalItems': ['승인'],
    'executionStatus': '지시서 준비',
    'notes': '',
    'primaryTrack': 'ebook',
    'followUpTracks': ['contents'],
    if (includeFollowupAlias) 'followupTracks': ['contents'],
    'artifactType': 'ebook',
    if (!omitContentSubtype) 'contentSubtype': '',
    'sourceFileName': 'WI_wi_plan_1785892893471.json',
    'status': status,
  };
  if (includeVersionAlias) {
    map['version'] = '1';
  }
  // 구형: checksum = 전체 JSON(해시 필드 제외 전) 또는 임의 값
  final withoutChecksum = Map<String, dynamic>.from(map)..remove('checksum');
  final legacySum =
      checksumOverride ??
      contentChecksumRaw(
        const JsonEncoder.withIndent('  ').convert(withoutChecksum),
      );
  map['checksum'] = legacySum;
  // checksumAlgorithm 없음 = legacy
  return map;
}

String legacyJson(Map<String, dynamic> map) =>
    const JsonEncoder.withIndent('  ').convert(map);

void main() {
  group('legacy checksum compatibility', () {
    test('1-5: volatile-only changes → sameCore', () {
      final base = legacyFullJsonFixture();
      final a = legacyJson(base);
      final b = legacyJson(
        legacyFullJsonFixture(
          updatedAt: '2026-08-05T12:34:56.789Z',
          status: 'downloaded_pending_import',
          checksumOverride: 'deadbeef',
        ),
      );
      // sourceFileName만 다름
      final cMap = legacyFullJsonFixture();
      cMap['sourceFileName'] = 'other.json';
      cMap['checksum'] = 'ffffffff';
      final c = legacyJson(cMap);

      expect(diffInstructionContent(a, b).isSameCore, isTrue);
      expect(diffInstructionContent(a, c).isSameCore, isTrue);
      expect(diffInstructionContent(a, b).legacyCompatible, isTrue);
      expect(stableContentChecksum(a), stableContentChecksum(b));
      expect(storedChecksumOf(a), isNot(storedChecksumOf(b)));
    });

    test('6: instructionVersion vs version alias', () {
      final a = legacyJson(legacyFullJsonFixture());
      final bMap = legacyFullJsonFixture(includeVersionAlias: true);
      bMap.remove('instructionVersion');
      final b = legacyJson(bMap);
      expect(diffInstructionContent(a, b).isSameCore, isTrue);
      expect(diffInstructionContent(a, b).schemaNormalized, isTrue);
    });

    test('7: omitted contentSubtype vs empty', () {
      final a = legacyJson(legacyFullJsonFixture());
      final b = legacyJson(legacyFullJsonFixture(omitContentSubtype: true));
      expect(diffInstructionContent(a, b).isSameCore, isTrue);
    });

    test(
      '8: pipeline alreadyExists for legacy file + new snapshot meta',
      () async {
        final fs = MemoryDevWorkDocFs();
        fs.dirs.addAll({'/Ebook/', '/Ebook/Active/', '/Ebook/Versions/'});
        final legacy = legacyJson(legacyFullJsonFixture());
        await fs.writeFile(
          ['Ebook', 'Versions', 'wi_plan_1785892893471'],
          'WI_wi_plan_1785892893471_v1.json',
          legacy,
        );
        await fs.writeFile(
          ['Ebook', 'Active'],
          'WI_wi_plan_1785892893471.json',
          legacy,
        );

        // 현재 스냅샷: updatedAt·checksum만 다름 (재생성 시뮬레이션)
        final current = legacyJson(
          legacyFullJsonFixture(
            updatedAt: '2026-08-05T99:00:00.000Z',
            checksumOverride: 'a5290240',
          ),
        );

        final pipeline = DevWorkDocSavePipeline(fs);
        final result = await pipeline.saveInstruction(
          artifactType: 'ebook',
          instructionId: 'wi_plan_1785892893471',
          version: 1,
          jsonText: current,
        );
        expect(result.ok, isTrue);
        expect(result.outcome, DevWorkDocSaveOutcome.alreadyExists);
        expect(result.message, contains('구형 체크섬 호환'));
        // Versions 미덮어쓰기
        expect(
          (await fs.readFile([
            'Ebook',
            'Versions',
            'wi_plan_1785892893471',
          ], 'WI_wi_plan_1785892893471_v1.json')).text,
          legacy,
        );
      },
    );

    test('9: real core change → Conflict, no overwrite', () async {
      final fs = MemoryDevWorkDocFs();
      fs.dirs.addAll({'/Ebook/', '/Ebook/Active/', '/Ebook/Versions/'});
      final legacy = legacyJson(legacyFullJsonFixture(idea: '주제A'));
      await fs.writeFile(
        ['Ebook', 'Versions', 'wi_plan_1785892893471'],
        'WI_wi_plan_1785892893471_v1.json',
        legacy,
      );

      final pipeline = DevWorkDocSavePipeline(fs);
      final result = await pipeline.saveInstruction(
        artifactType: 'ebook',
        instructionId: 'wi_plan_1785892893471',
        version: 1,
        jsonText: legacyJson(legacyFullJsonFixture(idea: '주제B')),
      );
      expect(result.ok, isFalse);
      expect(result.outcome, DevWorkDocSaveOutcome.conflict);
      expect(result.conflictDiffSummary, contains('재계산 안정 checksum'));
      expect(
        (await fs.readFile([
          'Ebook',
          'Versions',
          'wi_plan_1785892893471',
        ], 'WI_wi_plan_1785892893471_v1.json')).text,
        legacy,
      );
    });

    test('10-11: Active confirm + Versions untouched', () async {
      final fs = MemoryDevWorkDocFs();
      fs.dirs.addAll({'/Ebook/', '/Ebook/Active/', '/Ebook/Versions/'});
      final legacy = legacyJson(legacyFullJsonFixture());
      await fs.writeFile(
        ['Ebook', 'Versions', 'wi_plan_1785892893471'],
        'WI_wi_plan_1785892893471_v1.json',
        legacy,
      );
      await fs.writeFile(
        ['Ebook', 'Active'],
        'WI_wi_plan_1785892893471.json',
        legacy,
      );

      final r = await DevWorkDocSavePipeline(fs).saveInstruction(
        artifactType: 'ebook',
        instructionId: 'wi_plan_1785892893471',
        version: 1,
        jsonText: legacy,
      );
      expect(r.activeVerified, isTrue);
      expect(r.versionsVerified, isTrue);
    });

    test('12: Inbox transfer status fields do not cause conflict', () {
      final a = legacyFullJsonFixture();
      final b = legacyFullJsonFixture();
      b['lastTransferAt'] = '2026-08-05T10:00:00.000Z';
      b['lastTransferMode'] = 'folder';
      b['lastTransferChecksum'] = 'a5290240';
      b['status'] = 'transferred';
      expect(diffInstructionContent(a, b).isSameCore, isTrue);
    });

    test('13: wi_plan_1785892893471 production-shaped fixture', () {
      final fixture = legacyFullJsonFixture(checksumOverride: 'a5290240');
      expect(fixture['instructionId'], 'wi_plan_1785892893471');
      expect(fixture.containsKey('checksumAlgorithm'), isFalse);
      final json = legacyJson(fixture);
      final again = legacyJson(
        legacyFullJsonFixture(
          updatedAt: '2099-01-01T00:00:00.000Z',
          checksumOverride: 'a5290240',
        ),
      );
      expect(stableContentChecksum(json), stableContentChecksum(again));
      expect(storedAlgorithmOf(json), checksumAlgorithmLegacyFullJson);
    });

    test('14: repeated same-version compare is stable', () {
      final a = legacyJson(legacyFullJsonFixture());
      for (var i = 0; i < 5; i++) {
        final b = legacyJson(
          legacyFullJsonFixture(
            updatedAt: '2026-08-05T0$i:00:00.000Z',
            checksumOverride: 'a5290240',
          ),
        );
        expect(diffInstructionContent(a, b).isSameCore, isTrue);
        expect(stableContentChecksum(a), stableContentChecksum(b));
      }
    });

    test('new files get canonical_v2 fields', () {
      final map = withCanonicalChecksumFields(legacyFullJsonFixture());
      expect(map['checksumAlgorithm'], checksumAlgorithmCanonicalV2);
      expect(map['contentChecksum'], stableContentChecksum(map));
      expect(map['checksum'], map['contentChecksum']);
    });

    test('coreDiffFieldCount 0 forces same even if raw hashes differ', () {
      final a = legacyJson(legacyFullJsonFixture());
      final b = legacyJson(legacyFullJsonFixture(checksumOverride: '00000000'));
      final diff = diffInstructionContent(a, b);
      expect(diff.coreDiffFieldCount, 0);
      expect(diff.isSameCore, isTrue);
      expect(contentChecksumRaw(a), isNot(contentChecksumRaw(b)));
    });
  });
}
