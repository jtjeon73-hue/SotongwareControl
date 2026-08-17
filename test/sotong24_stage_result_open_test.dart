import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/sotong24_workflows.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/widgets/sotong24_stage_widgets.dart';

Sotong24RemoteStage _stage({
  required int number,
  required String id,
  String resultUrl = '',
  String previewUrl = '',
  String status = Sotong24WorkStatus.completed,
}) {
  return Sotong24RemoteStage(
    stageId: id,
    stageNumber: number,
    stageName: id,
    status: status,
    resultUrl: resultUrl,
    previewUrl: previewUrl,
  );
}

void main() {
  group('Sotong24RemoteStage openable links', () {
    test('past stage resultUrl is openable', () {
      const url =
          'https://storage.googleapis.com/sotongware-control.firebasestorage.app/sotong24/artifacts/test/wi_test/draft/r2/a.md';
      final s = _stage(number: 7, id: 'draft', resultUrl: url);
      expect(s.hasOpenableResult, isTrue);
      expect(s.openableResultUrl, url);
      expect(s.openablePreviewUrl, isNull);
    });

    test('resultUrl == previewUrl → one openable result only', () {
      const url = 'https://storage.googleapis.com/bucket/o.md';
      final s = _stage(number: 7, id: 'draft', resultUrl: url, previewUrl: url);
      expect(s.openableResultUrl, url);
      expect(s.openablePreviewUrl, isNull);
    });

    test('distinct previewUrl is openable separately', () {
      const result = 'https://storage.googleapis.com/bucket/result.md';
      const preview = 'https://storage.googleapis.com/bucket/preview.md';
      final s = _stage(
        number: 18,
        id: 'maintain',
        resultUrl: result,
        previewUrl: preview,
      );
      expect(s.openableResultUrl, result);
      expect(s.openablePreviewUrl, preview);
    });

    test('previewUrl only', () {
      const preview = 'https://storage.googleapis.com/bucket/preview.md';
      final s = _stage(number: 3, id: 'outline', previewUrl: preview);
      expect(s.openableResultUrl, isNull);
      expect(s.openablePreviewUrl, preview);
      expect(s.hasOpenableResult, isTrue);
    });

    test('no urls → not openable', () {
      final s = _stage(number: 1, id: 'idea');
      expect(s.hasOpenableResult, isFalse);
      expect(s.openableResultUrl, isNull);
      expect(s.openablePreviewUrl, isNull);
    });

    test('unsafe schemes rejected', () {
      for (final bad in [
        'javascript:alert(1)',
        'data:text/plain,hi',
        'file:///C:/tmp/a.md',
        r'C:\Users\a.md',
        r'\\server\share\a.md',
      ]) {
        expect(
          Sotong24RemoteStage.isOpenableHttpUrl(bad),
          isFalse,
          reason: bad,
        );
        final s = _stage(number: 7, id: 'draft', resultUrl: bad);
        expect(s.hasOpenableResult, isFalse, reason: bad);
      }
    });

    test('draft and maintain urls stay distinct on stages', () {
      const draftUrl =
          'https://storage.googleapis.com/b/sotong24/artifacts/test/x/draft/r2/07.md';
      const maintainUrl =
          'https://storage.googleapis.com/b/sotong24/artifacts/test/x/maintain/r1/18.md';
      final draft = _stage(number: 7, id: 'draft', resultUrl: draftUrl);
      final maintain = _stage(
        number: 18,
        id: 'maintain',
        resultUrl: maintainUrl,
      );
      expect(draft.openableResultUrl, draftUrl);
      expect(maintain.openableResultUrl, maintainUrl);
      expect(draft.openableResultUrl, isNot(maintain.openableResultUrl));
    });
  });

  group('Sotong24ExpandableStageTile result buttons', () {
    Future<void> pumpTile(
      WidgetTester tester, {
      required Sotong24RemoteStage stage,
      bool isCurrent = false,
      double width = 390,
    }) async {
      final workflow = Sotong24WorkflowCatalog.ebook;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: Sotong24ExpandableStageTile(
                  stage: stage,
                  isCurrent: isCurrent,
                  def:
                      workflow.byId(stage.stageId) ??
                      workflow.byOrder(stage.stageNumber),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Expand if collapsed (current starts open).
      if (!isCurrent) {
        await tester.tap(find.text(stage.stageName));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('past stage with resultUrl shows 결과물 보기 (not current)', (
      tester,
    ) async {
      const url =
          'https://storage.googleapis.com/sotongware-control.firebasestorage.app/sotong24/artifacts/test/wi/draft/r2/07.md';
      await pumpTile(
        tester,
        stage: _stage(number: 7, id: 'draft', resultUrl: url),
        isCurrent: false,
      );
      expect(find.text('결과물 보기'), findsOneWidget);
      expect(find.textContaining('X-Goog-Signature'), findsNothing);
      expect(find.textContaining(url), findsNothing);
    });

    testWidgets('no resultUrl → no open button', (tester) async {
      await pumpTile(
        tester,
        stage: _stage(number: 7, id: 'draft'),
        isCurrent: true,
      );
      expect(find.text('결과물 보기'), findsNothing);
      expect(find.text('미리보기'), findsNothing);
    });

    testWidgets('preview only → 미리보기', (tester) async {
      await pumpTile(
        tester,
        stage: _stage(
          number: 7,
          id: 'draft',
          previewUrl: 'https://storage.googleapis.com/b/preview.md',
        ),
        isCurrent: true,
      );
      expect(find.text('결과물 보기'), findsNothing);
      expect(find.text('미리보기'), findsOneWidget);
    });

    testWidgets('same result/preview → one button', (tester) async {
      const url = 'https://storage.googleapis.com/b/same.md';
      await pumpTile(
        tester,
        stage: _stage(
          number: 18,
          id: 'maintain',
          resultUrl: url,
          previewUrl: url,
        ),
        isCurrent: true,
      );
      expect(find.text('결과물 보기'), findsOneWidget);
      expect(find.text('미리보기'), findsNothing);
    });

    testWidgets('distinct result/preview → two buttons', (tester) async {
      await pumpTile(
        tester,
        stage: _stage(
          number: 18,
          id: 'maintain',
          resultUrl: 'https://storage.googleapis.com/b/result.md',
          previewUrl: 'https://storage.googleapis.com/b/preview.md',
        ),
        isCurrent: true,
      );
      expect(find.text('결과물 보기'), findsOneWidget);
      expect(find.text('미리보기'), findsOneWidget);
    });

    testWidgets('unsafe url → no button', (tester) async {
      await pumpTile(
        tester,
        stage: _stage(number: 7, id: 'draft', resultUrl: 'javascript:alert(1)'),
        isCurrent: true,
      );
      expect(find.text('결과물 보기'), findsNothing);
    });

    testWidgets('narrow width has no overflow', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.toString().contains('overflowed')) errors.add(d);
        old?.call(d);
      };
      addTearDown(() => FlutterError.onError = old);

      await pumpTile(
        tester,
        width: 320,
        stage: _stage(
          number: 7,
          id: 'draft',
          resultUrl:
              'https://storage.googleapis.com/sotongware-control.firebasestorage.app/sotong24/artifacts/test/wi_test_remote_e2e_1786792704742/draft/r2/07_draft_e2e_result_r2.md?X-Goog-Signature=LONGTOKEN',
        ),
        isCurrent: false,
      );
      expect(errors, isEmpty);
      expect(find.text('결과물 보기'), findsOneWidget);
    });
  });
}
