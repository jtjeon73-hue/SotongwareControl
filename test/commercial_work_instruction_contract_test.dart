import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/commercial/work_instruction_brief.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/services/commercial_work_instruction_preflight.dart';
import 'package:sotong_ware_control/services/content_subtype_contract.dart';

import 'support/commercial_fixtures.dart';

void main() {
  group('ContentSubtypeContract', () {
    test('maps Control UI aliases to Work commercial enums', () {
      expect(
        ContentSubtypeContract.toWorkCommercialEnum('music'),
        'song_audio',
      );
      expect(
        ContentSubtypeContract.toWorkCommercialEnum('shorts'),
        'shorts_video',
      );
      expect(
        ContentSubtypeContract.toWorkCommercialEnum('comic'),
        'comic_video',
      );
      expect(
        ContentSubtypeContract.toWorkCommercialEnum('notification_promo_video'),
        'notification_promo_video',
      );
      expect(
        ContentSubtypeContract.toWorkCommercialEnum('image_design'),
        'image_design',
      );
    });

    test('rejects unknown subtype without silent default', () {
      expect(
        () => ContentSubtypeContract.toWorkCommercialEnum('totally_unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PASS fixtures', () {
    Map<String, dynamic> base(String artifact) => {
      'schemaVersion': instructionSchemaVersionCurrent,
      'instructionId': 'wi_commercial_pass_$artifact',
      'projectId': 'proj_$artifact',
      'artifactType': artifact,
      'businessIdea': 'idea',
      'customerProblem': 'problem',
      'targetCustomer': 'customer',
      'deliverableTypes': [artifact],
      'workflowSteps': [
        {'order': 1, 'id': 'step1', 'title': 't', 'applicable': true},
      ],
      'externalPublished': false,
    };

    test('app new_product', () {
      final json = CommercialFixtures.mergeIntoInstruction(
        base(ArtifactType.app),
      );
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.code).join(','));
      expect(json['briefContractVersion'], 1);
      expect(json['appQualityContractVersion'], 1);
      expect(json['commercialAppQualityProfile'], isA<Map>());
      expect(json['workInstructionBrief']['originalUserBrief'], isNotEmpty);
      expect(
        json['workInstructionBrief']['aiAugmentedBrief'],
        isNot(equals(json['workInstructionBrief']['originalUserBrief'])),
      );
    });

    test('ebook new_product', () {
      final r = CommercialWorkInstructionPreflight.evaluate(
        CommercialFixtures.mergeIntoInstruction(base(ArtifactType.ebook)),
      );
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.code).join(','));
      expect(r.track, 'ebook');
    });

    test('marketing site', () {
      final r = CommercialWorkInstructionPreflight.evaluate(
        CommercialFixtures.mergeIntoInstruction(
          base(ArtifactType.site),
          sitePurpose: 'marketing_site',
        ),
      );
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.code).join(','));
      expect(r.subtype, 'marketing_site');
    });

    test('knowledge/education site', () {
      for (final purpose in ['knowledge_site', 'education_site']) {
        final r = CommercialWorkInstructionPreflight.evaluate(
          CommercialFixtures.mergeIntoInstruction(
            base(ArtifactType.site),
            sitePurpose: purpose,
          ),
        );
        expect(r.ok, isTrue, reason: '$purpose ${r.errors}');
      }
    });

    test('content subtypes song/shorts/comic/notification/image', () {
      for (final sub in [
        'music',
        'shorts',
        'comic',
        'notification_promo_video',
        'image_design',
      ]) {
        final json = CommercialFixtures.mergeIntoInstruction(
          base(ArtifactType.contents),
          contentSubtype: sub,
        );
        final r = CommercialWorkInstructionPreflight.evaluate(json);
        expect(r.ok, isTrue, reason: '$sub ${r.errors.map((e) => e.code)}');
        expect(
          json['commercialContentQualityProfile']['contentSubtype'],
          ContentSubtypeContract.requireWorkCommercialEnum(sub),
        );
      }
    });

    test('manualOnlyMode complete', () {
      final att = CommercialFixtures.forTrack(
        ArtifactType.ebook,
        briefOverride: CommercialFixtures.brief(
          manualOnly: true,
          aiAugmented: '',
        ),
      );
      final json = CommercialFixtures.mergeIntoInstruction(
        base(ArtifactType.ebook),
        attachment: att,
      );
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.code).join(','));
      expect(json['workInstructionBrief']['manualOnlyMode'], isTrue);
    });

    test('revise_existing complete', () {
      final att = CommercialFixtures.forTrack(
        ArtifactType.app,
        briefOverride: CommercialFixtures.brief(
          displayTitle: '농작업 안전 점검 앱',
          original: '기존 앱 보완 요청 원문',
          creationMode: 'revise_existing',
          sourceInstructionId: 'wi_source_r1',
          sourceRevision: 'R1',
          requestedRevision: 'R2',
          requestedChanges: const ['긴 제목 줄바꿈', '필터 칩 수정'],
          preservedHashes: const [
            '6c151c739ca1fd9eb9ff7ac631396db677083004af48d67344c9785fa120c481',
          ],
        ),
      );
      final r = CommercialWorkInstructionPreflight.evaluate(
        CommercialFixtures.mergeIntoInstruction(
          base(ArtifactType.app),
          attachment: att,
        ),
      );
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.code).join(','));
    });
  });

  group('FAIL fixtures', () {
    Map<String, dynamic> bare11(String artifact) => {
      'schemaVersion': instructionSchemaVersionCurrent,
      'instructionId': 'wi_fail_$artifact',
      'artifactType': artifact,
      'businessIdea': 'x',
      'customerProblem': 'y',
      'targetCustomer': 'z',
      'deliverableTypes': [artifact],
      'workflowSteps': [
        {'order': 1, 'id': 'a', 'title': 't', 'applicable': true},
      ],
    };

    test('brief missing → WIBC_LEGACY_DISGUISE or WIBC_REQUIRED', () {
      final r = CommercialWorkInstructionPreflight.evaluate(
        bare11(ArtifactType.ebook),
      );
      expect(r.ok, isFalse);
      expect(
        r.errors.any(
          (e) =>
              e.code == 'WIBC_LEGACY_DISGUISE' ||
              e.code == 'WIBC_REQUIRED' ||
              e.code == 'CEQP_LEGACY_DISGUISE',
        ),
        isTrue,
      );
    });

    test('profile missing → *_LEGACY_DISGUISE', () {
      final json = bare11(ArtifactType.app);
      json['briefContractVersion'] = 1;
      json['workInstructionBrief'] = CommercialFixtures.brief().toJson();
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isFalse);
      expect(r.errors.any((e) => e.code.contains('LEGACY_DISGUISE')), isTrue);
    });

    test('displayTitle is internal id', () {
      final json = CommercialFixtures.mergeIntoInstruction(
        bare11(ArtifactType.ebook),
        attachment: CommercialFixtures.forTrack(
          ArtifactType.ebook,
          briefOverride: CommercialFixtures.brief(
            displayTitle: 'wi_internal_only_id_value_too_long_without_spaces',
          ),
        ),
      );
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isFalse);
      expect(
        r.errors.any((e) => e.code == 'WIBC_DISPLAY_TITLE_IS_INTERNAL_ID'),
        isTrue,
      );
    });

    test('artifact suffix duplication', () {
      final json = CommercialFixtures.mergeIntoInstruction(
        bare11(ArtifactType.app),
        attachment: CommercialFixtures.forTrack(
          ArtifactType.app,
          briefOverride: CommercialFixtures.brief(
            displayTitle: '생활 AI 체크 앱 앱',
            original: '원문',
          ),
        ),
      );
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isFalse);
      expect(
        r.errors.any((e) => e.code == 'CQ_DISPLAY_TITLE_ARTIFACT_SUFFIX'),
        isTrue,
      );
    });

    test('placeholder forbidden', () {
      final json = CommercialFixtures.mergeIntoInstruction(
        bare11(ArtifactType.ebook),
        attachment: CommercialFixtures.forTrack(
          ArtifactType.ebook,
          briefOverride: CommercialFixtures.brief(
            displayTitle: 'TODO placeholder title',
            original: '예시만 적어둔 원문',
          ),
        ),
      );
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(
        r.errors.any((e) => e.code == 'WIBC_PLACEHOLDER_FORBIDDEN'),
        isTrue,
      );
    });

    test('reasonsToPay / promisedOutcome missing', () {
      final att = CommercialFixtures.forTrack(ArtifactType.ebook);
      final broken = att.ebookProfile.toJson();
      broken['standard'] = {
        ...Map<String, dynamic>.from(broken['standard'] as Map),
        'reasonsToPay': <String>[],
        'promisedOutcome': '',
      };
      final json = CommercialFixtures.mergeIntoInstruction(
        bare11(ArtifactType.ebook),
      );
      json['commercialEbookQualityProfile'] = broken;
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isFalse);
      expect(r.errors.any((e) => e.code == 'CQSTD_REQUIRED'), isTrue);
    });

    test('unknown content subtype', () {
      final json = CommercialFixtures.mergeIntoInstruction(
        bare11(ArtifactType.contents),
        contentSubtype: 'shorts',
      );
      json['commercialContentQualityProfile'] = {
        ...Map<String, dynamic>.from(
          json['commercialContentQualityProfile'] as Map,
        ),
        'contentSubtype': 'not_a_real_subtype',
      };
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.errors.any((e) => e.code == 'CCQP_BAD_SUBTYPE'), isTrue);
    });

    test('revise without source/changes/hashes', () {
      final json = CommercialFixtures.mergeIntoInstruction(
        bare11(ArtifactType.app),
        attachment: CommercialFixtures.forTrack(
          ArtifactType.app,
          briefOverride: CommercialFixtures.brief(
            displayTitle: '농작업 안전 점검 앱',
            original: '원문',
            creationMode: 'revise_existing',
          ),
        ),
      );
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isFalse);
      expect(r.errors.any((e) => e.code.startsWith('WIBC_REVISION_')), isTrue);
    });

    test('externalPublished true blocked', () {
      final json = CommercialFixtures.mergeIntoInstruction(
        bare11(ArtifactType.ebook),
      );
      json['externalPublished'] = true;
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(
        r.errors.any((e) => e.code == 'CQ_EXTERNAL_PUBLISH_FORBIDDEN'),
        isTrue,
      );
    });

    test('schema 1.0 is exempt (not disguised as 1.1)', () {
      final r = CommercialWorkInstructionPreflight.evaluate({
        'schemaVersion': '1.0',
        'instructionId': 'wi_legacy',
        'artifactType': 'ebook',
      });
      expect(r.ok, isTrue);
      expect(r.code, 'LEGACY_SCHEMA_1_0');
    });
  });

  group('Cross-contract path parity with Work fixtures', () {
    test('Work ebook PASS fixture keys validate under Control preflight', () {
      final workPath =
          r'C:\Users\user\Documents\GitHub\Sotong24Work\scripts\fixtures\cross_track_commercial_quality\wi_ebook_pass.json';
      final file = File(workPath);
      expect(file.existsSync(), isTrue);
      final json = Map<String, dynamic>.from(
        jsonDecode(file.readAsStringSync()) as Map,
      );
      // Work fixture is minimal on workflow; Control preflight focuses commercial.
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(
        r.ok,
        isTrue,
        reason: r.errors.map((e) => '${e.code}:${e.fieldPath}').join(' | '),
      );
      expect(json.containsKey('workInstructionBrief'), isTrue);
      expect(json.containsKey('commercialEbookQualityProfile'), isTrue);
      expect(json['briefContractVersion'], 1);
      expect(json['ebookQualityContractVersion'], 1);
      expect(
        (json['workInstructionBrief'] as Map)['schemaVersion'],
        WorkInstructionBrief.kSchemaVersion,
      );
    });

    test('Work app PASS fixture keys present', () {
      final workPath =
          r'C:\Users\user\Documents\GitHub\Sotong24Work\scripts\fixtures\app_commercial_quality\wi_with_profile_pass.json';
      final json = Map<String, dynamic>.from(
        jsonDecode(File(workPath).readAsStringSync()) as Map,
      );
      expect(json['appQualityContractVersion'], 1);
      expect(json['commercialAppQualityProfile'], isA<Map>());
      expect(json['workInstructionBrief'], isA<Map>());
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.code).join(','));
    });

    test('Work content PASS uses notification_promo_video enum', () {
      final workPath =
          r'C:\Users\user\Documents\GitHub\Sotong24Work\scripts\fixtures\cross_track_commercial_quality\wi_content_pass.json';
      final json = Map<String, dynamic>.from(
        jsonDecode(File(workPath).readAsStringSync()) as Map,
      );
      expect(
        json['commercialContentQualityProfile']['contentSubtype'],
        'notification_promo_video',
      );
      final r = CommercialWorkInstructionPreflight.evaluate(json);
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.code).join(','));
    });

    test('serialized Control attachment paths match Work SSOT names', () {
      final fields = CommercialFixtures.forTrack(
        ArtifactType.app,
      ).toInstructionJsonFields();
      expect(
        fields.keys,
        containsAll([
          'briefContractVersion',
          'workInstructionBrief',
          'appQualityContractVersion',
          'commercialAppQualityProfile',
        ]),
      );
      expect(fields.containsKey('briefContract'), isFalse);
    });
  });
}
