/// Production review status card render smoke + manifest (no network).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/widgets/production_review_status_card.dart';
import 'package:sotong_ware_control/widgets/review_apk_download_button.dart';

import 'support/production_review_fixtures.dart';

class _RenderCase {
  const _RenderCase({
    required this.screenId,
    required this.viewport,
    required this.textScale,
    required this.compact,
  });

  final String screenId;
  final Size viewport;
  final double textScale;
  final bool compact;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifestEntries = <Map<String, dynamic>>[];
  final envelope = ProductionReviewFixtures.appR1ChangesRequested();
  var r2PrepareTaps = 0;

  Future<void> pumpCase(WidgetTester tester, _RenderCase c) async {
    tester.view.physicalSize = c.viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: c.viewport,
          textScaler: TextScaler.linear(c.textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ProductionReviewStatusCard(
                  envelope: envelope,
                  compact: c.compact,
                  onPrepareR2Draft: () => r2PrepareTaps += 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(exception, isNull, reason: c.screenId);
    expect(find.textContaining('OVERFLOWED'), findsNothing);
    expect(find.byKey(const Key('production_review_status_card')), findsOneWidget);
    // Live mobile/dashboard always use compact:true; review download must stay mounted.
    expect(find.byType(ReviewApkDownloadButton), findsOneWidget);

    final hashInput =
        '${c.screenId}|${c.viewport.width.toInt()}x${c.viewport.height.toInt()}|${c.textScale}|${c.compact}|${envelope.instructionId}';
    manifestEntries.add({
      'screenId': c.screenId,
      'viewport': {
        'width': c.viewport.width.toInt(),
        'height': c.viewport.height.toInt(),
      },
      'textScale': c.textScale,
      'compact': c.compact,
      'instructionId': envelope.instructionId,
      'userLabelKo': envelope.userLabelKo,
      'overflow': 0,
      'exception': null,
      'fixtureHash': hashInput.hashCode.toRadixString(16),
    });
  }

  testWidgets('card × viewport × textScale renders without overflow', (
    tester,
  ) async {
    final viewports = <(String, Size)>[
      ('desktop', const Size(1440, 900)),
      ('tablet', const Size(768, 1024)),
      ('mobile', const Size(390, 844)),
    ];
    final scales = [1.0, 1.3, 1.5];

    for (final (name, size) in viewports) {
      for (final scale in scales) {
        for (final compact in [false, true]) {
          await pumpCase(
            tester,
            _RenderCase(
              screenId: 'production_review_${compact ? 'compact' : 'full'}_$name',
              viewport: size,
              textScale: scale,
              compact: compact,
            ),
          );
        }
      }
    }

    expect(find.textContaining('기술검증'), findsWidgets);
    expect(find.textContaining('보완요청'), findsWidgets);

    final r2Button = find.byKey(const Key('production_review_r2_prepare'));
    expect(r2Button, findsOneWidget);
    await tester.tap(r2Button);
    await tester.pump();
    expect(r2PrepareTaps, greaterThan(0));

    final manifestDir = Directory(
      'test/support/production_review_render_manifest',
    );
    if (!manifestDir.existsSync()) manifestDir.createSync(recursive: true);
    final manifestFile = File('${manifestDir.path}/render_manifest.json');
    manifestFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'cases': manifestEntries,
        'totalCases': manifestEntries.length,
        'r2PrepareTaps': r2PrepareTaps,
      }),
    );
    expect(manifestFile.existsSync(), isTrue);
    expect(manifestEntries.length, 18);
  });
}
