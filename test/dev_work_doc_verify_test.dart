import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/services/dev_work_doc_types.dart';
import 'package:sotong_ware_control/services/dev_work_doc_verify.dart';
import 'package:sotong_ware_control/services/work_instruction_validator.dart';

void main() {
  const instructionId = 'wi_verify_test';
  const version = 1;

  String sampleJson({String id = instructionId, int ver = version}) {
    final map = {
      'instructionId': id,
      'instructionVersion': '$ver',
      'schemaVersion': '1.0',
      'artifactType': 'ebook',
      'topic': 'verify test',
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  group('classifySelection', () {
    test('DevWorkDoc folder name → devWorkDocRoot', () {
      expect(
        classifySelection(folderName: 'DevWorkDoc', childNames: const []),
        DevWorkDocSelectionKind.devWorkDocRoot,
      );
    });

    test('artifact children → devWorkDocRoot', () {
      expect(
        classifySelection(
          folderName: 'MyDocs',
          childNames: const ['Ebook', 'App'],
        ),
        DevWorkDocSelectionKind.devWorkDocRoot,
      );
    });

    test('DevWorkDoc child → repoRootWithDevWorkDoc', () {
      expect(
        classifySelection(
          folderName: 'SotongWareControl',
          childNames: const ['DevWorkDoc', 'lib'],
        ),
        DevWorkDocSelectionKind.repoRootWithDevWorkDoc,
      );
    });

    test('sotongware name → ambiguous', () {
      expect(
        classifySelection(
          folderName: 'SotongWareControl',
          childNames: const ['lib', 'test'],
        ),
        DevWorkDocSelectionKind.ambiguous,
      );
    });
  });

  group('verifyWrittenPair', () {
    test('complete success when Active and Versions match', () {
      final json = sampleJson();
      final result = verifyWrittenPair(
        DevWorkDocVerifyInput(
          expectedJson: json,
          activeText: json,
          versionsText: json,
          instructionId: instructionId,
          version: version,
        ),
      );

      expect(result.outcome, DevWorkDocSaveOutcome.completeSuccess);
      expect(result.activeVerified, isTrue);
      expect(result.versionsVerified, isTrue);
      expect(result.isComplete, isTrue);
    });

    test('partial success when only Active matches', () {
      final json = sampleJson();
      final result = verifyWrittenPair(
        DevWorkDocVerifyInput(
          expectedJson: json,
          activeText: json,
          versionsText: null,
          instructionId: instructionId,
          version: version,
        ),
      );

      expect(result.outcome, DevWorkDocSaveOutcome.partialSuccess);
      expect(result.activeVerified, isTrue);
      expect(result.versionsVerified, isFalse);
    });

    test('failed when both sides empty', () {
      final json = sampleJson();
      final result = verifyWrittenPair(
        DevWorkDocVerifyInput(
          expectedJson: json,
          activeText: '',
          versionsText: '',
          instructionId: instructionId,
          version: version,
        ),
      );

      expect(result.outcome, DevWorkDocSaveOutcome.failed);
      expect(result.activeVerified, isFalse);
      expect(result.versionsVerified, isFalse);
    });

    test('failed on bad JSON', () {
      final json = sampleJson();
      final result = verifyWrittenPair(
        DevWorkDocVerifyInput(
          expectedJson: json,
          activeText: '{not json',
          versionsText: json,
          instructionId: instructionId,
          version: version,
        ),
      );

      expect(result.outcome, DevWorkDocSaveOutcome.partialSuccess);
      expect(result.activeVerified, isFalse);
      expect(result.versionsVerified, isTrue);
    });

    test('failed on instructionId mismatch', () {
      final json = sampleJson();
      final wrong = sampleJson(id: 'wi_other');
      final result = verifyWrittenPair(
        DevWorkDocVerifyInput(
          expectedJson: json,
          activeText: wrong,
          versionsText: json,
          instructionId: instructionId,
          version: version,
        ),
      );

      expect(result.outcome, DevWorkDocSaveOutcome.partialSuccess);
      expect(result.activeVerified, isFalse);
    });
  });

  group('compareExistingFile', () {
    test('alreadyExists for identical checksum', () {
      final json = sampleJson();
      expect(
        compareExistingFile(existingText: json, expectedJson: json),
        DevWorkDocSaveOutcome.alreadyExists,
      );
    });

    test('conflict for different content', () {
      final existing = sampleJson();
      final expected = sampleJson(ver: 2);
      expect(
        compareExistingFile(existingText: existing, expectedJson: expected),
        DevWorkDocSaveOutcome.conflict,
      );
    });

    test('conflict for invalid existing JSON', () {
      expect(
        compareExistingFile(
          existingText: 'not-json',
          expectedJson: sampleJson(),
        ),
        DevWorkDocSaveOutcome.conflict,
      );
    });
  });

  group('DevWorkDocWriteResult.download', () {
    test('download result always has ok false', () {
      final result = DevWorkDocWriteResult.download(
        fileName: 'WI_test_v1.json',
        message: '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님).',
        activePathHint: 'Ebook/Active/WI_test.json',
        versionPathHint: 'Ebook/Versions/test/WI_test_v1.json',
      );

      expect(result.ok, isFalse);
      expect(result.mode, 'download');
      expect(result.outcome, DevWorkDocSaveOutcome.downloadOnly);
    });
  });

  test('contentChecksum is stable for verify tests', () {
    final json = sampleJson();
    expect(contentChecksum(json), isNotEmpty);
  });
}
