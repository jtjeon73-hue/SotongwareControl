import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/commercial/production_review_status_envelope.dart';
import 'package:sotong_ware_control/services/production_review_status_presentation.dart';
import 'package:sotong_ware_control/services/production_review_status_store.dart';
import 'package:sotong_ware_control/services/production_review_status_validator.dart';

import 'support/production_review_fixtures.dart';

void main() {
  group('ProductionReviewStatusValidator', () {
    test('rejects bad schemaVersion', () {
      final r = ProductionReviewStatusValidator.validate(
        incoming: ProductionReviewFixtures.malformedBadSchema(),
      );
      expect(r.ok, isFalse);
      expect(r.code, 'PRSE_SCHEMA_VERSION');
    });

    test('rejects missing IDs', () {
      final r = ProductionReviewStatusValidator.validate(
        incoming: ProductionReviewFixtures.malformedMissingIds(),
      );
      expect(r.ok, isFalse);
      expect(r.code, 'PRSE_MISSING_IDS');
    });

    test('rejects sensitive Windows path fields', () {
      final r = ProductionReviewStatusValidator.validate(
        incoming: ProductionReviewFixtures.malformedSensitivePath(),
      );
      expect(r.ok, isFalse);
      expect(r.code, 'PRSE_SENSITIVE_FIELD');
    });

    test('rejects revision rollback', () {
      final store = ProductionReviewStatusStore();
      store.apply(ProductionReviewFixtures.appR1ChangesRequested());
      final r = store.apply(ProductionReviewFixtures.revisionRollbackR1());
      expect(r.ok, isFalse);
      expect(r.code, 'PRSE_REVISION_ROLLBACK');
    });

    test('rejects stale emittedAt for same instruction+revision', () {
      final store = ProductionReviewStatusStore();
      store.apply(ProductionReviewFixtures.appR1ChangesRequested());
      final r = store.apply(ProductionReviewFixtures.staleAppR1());
      expect(r.ok, isFalse);
      expect(r.code, 'PRSE_STALE_EVENT');
    });

    test('duplicate eventId is idempotent accept', () {
      final store = ProductionReviewStatusStore();
      final first = store.apply(ProductionReviewFixtures.appR1ChangesRequested());
      expect(first.applied, isTrue);
      final dup = store.apply(ProductionReviewFixtures.duplicateAppR1());
      expect(dup.ok, isTrue);
      expect(dup.duplicate, isTrue);
      expect(dup.sideEffectCount, 0);
      expect(store.count, 1);
    });

    test('changes_requested enforces readiness and step16Blocked', () {
      final bad = ProductionReviewFixtures.appR1ChangesRequested().copyWith(
        readiness: const ProductionReviewReadiness(
          technicalValidationCompleted: true,
          ownerReviewRequired: true,
          revisionRequired: true,
          registrationEligible: true,
          externalPublicationAllowed: true,
        ),
      );
      final r = ProductionReviewStatusValidator.validate(incoming: bad);
      expect(r.ok, isFalse);
      expect(r.code, anyOf('PRSE_CHANGES_EXTERNAL', 'PRSE_CHANGES_REGISTRATION'));
    });
  });

  group('app R1 fixture assertions', () {
    late ProductionReviewStatusEnvelope appR1;

    setUp(() {
      appR1 = ProductionReviewFixtures.appR1ChangesRequested();
    });

    test('technicalValidationCompleted true', () {
      expect(appR1.readiness.technicalValidationCompleted, isTrue);
      expect(appR1.technicalValidation.completed, isTrue);
    });

    test('ownerReview changes_requested with step16Blocked', () {
      expect(appR1.ownerReview.decision, 'changes_requested');
      expect(appR1.ownerReview.step16Blocked, isTrue);
    });

    test('revisionRequired true, registration and publication blocked', () {
      expect(appR1.readiness.revisionRequired, isTrue);
      expect(appR1.readiness.registrationEligible, isFalse);
      expect(appR1.readiness.externalPublicationAllowed, isFalse);
    });

    test('userLabel contains 기술검증 / 보완요청 / R2 hints', () {
      expect(appR1.userLabelKo, contains('기술검증'));
      expect(appR1.userLabelKo, contains('보완요청'));
      expect(appR1.userLabelKo, contains('R2'));
      final labels = appR1.userFacingLabels.join(' ');
      expect(labels, contains('기술검증'));
      expect(labels, contains('보완요청'));
      final hints = ProductionReviewStatusPresentation.r2DraftHints(appR1);
      expect(hints.any((h) => h.contains('R2') || h.contains('자동 전송')), isTrue);
    });

    test('live Work fixture JSON parses under Control model', () async {
      final file = File(
        'test/support/production_review_fixtures/work_app_r1_changes_requested.json',
      );
      expect(file.existsSync(), isTrue);
      final map =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final envelope = ProductionReviewStatusEnvelope.fromJson(map);
      final result = ProductionReviewStatusValidator.validate(
        incoming: envelope,
      );
      expect(result.ok, isTrue, reason: '${result.code}');
      expect(envelope.instructionId, ProductionReviewFixtures.appR1InstructionId);
      expect(envelope.ownerReview.decision, 'changes_requested');
      expect(envelope.ownerReview.step16Blocked, isTrue);
      expect(envelope.readiness.revisionRequired, isTrue);
      expect(envelope.readiness.registrationEligible, isFalse);
      expect(envelope.readiness.externalPublicationAllowed, isFalse);
      expect(envelope.execution.terminalBlockCount, 3);
      expect(
        envelope.technicalValidation.artifactSha256,
        ProductionReviewFixtures.liveApkSha256,
      );
      expect(envelope.userLabelKo, contains('R2 준비 대기'));
    });

    test('revisionRank R1=1', () {
      expect(appR1.revisionRank, 1);
      expect(ProductionReviewStatusEnvelope.revisionRankOf('R2'), 2);
    });

    test('isStaleVs detects older envelope', () {
      final newer = appR1;
      final older = ProductionReviewFixtures.staleAppR1();
      expect(older.isStaleVs(newer), isTrue);
      expect(newer.isStaleVs(older), isFalse);
    });
  });

  group('tracks dry-run store', () {
    test('ebook/site/content tracks apply with sideEffect=0', () {
      final store = ProductionReviewStatusStore();
      for (final fixture in [
        ProductionReviewFixtures.ebookR1Approved(),
        ProductionReviewFixtures.siteR1Pending(),
        ProductionReviewFixtures.contentR1Pending(),
      ]) {
        final r = store.apply(fixture);
        expect(r.ok, isTrue, reason: fixture.instructionId);
        expect(r.sideEffectCount, 0);
      }
      expect(store.count, 3);
    });

    test('presentation lines for app R1', () {
      final appR1 = ProductionReviewFixtures.appR1ChangesRequested();
      final summary = ProductionReviewStatusPresentation.dashboardSummary(appR1);
      expect(summary.any((l) => l.contains('기술검증')), isTrue);
      expect(
        ProductionReviewStatusPresentation.recommendedActions(appR1),
        isNotEmpty,
      );
    });
  });
}
