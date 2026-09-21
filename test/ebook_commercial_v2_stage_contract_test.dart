import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/services/business_planning_service.dart';

/// Work kStagesV2 ↔ Flutter ebookWorkflowStages ↔ Control functions allowlist.
void main() {
  final fixtureFile = File('test/fixtures/ebook_commercial_v2_stages.json');
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture = jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
  });

  test('Flutter ebookWorkflowStages matches commercial v2 fixture', () {
    final stages = fixture['stages'] as List<dynamic>;
    expect(BusinessPlanningService.ebookWorkflowStages.length, 18);
    expect(stages.length, 18);
    for (var i = 0; i < stages.length; i++) {
      final expected = stages[i] as Map<String, dynamic>;
      final actual = BusinessPlanningService.ebookWorkflowStages[i];
      expect(
        actual.$1,
        expected['stageId'],
        reason: 'ebook stage contract drift at order ${expected['order']}',
      );
      expect(actual.$2, expected['displayName']);
    }
  });

  test('STEP13-18 Flutter ids are format_build…publication_package', () {
    final ids = BusinessPlanningService.ebookWorkflowStages.map((e) => e.$1).toList();
    expect(ids.sublist(12), [
      'format_build',
      'reader_accessibility_test',
      'package_user_review',
      'final_polish',
      'final_user_approval',
      'publication_package',
    ]);
  });

  test('guessed final_policy/release_package are not Flutter contract', () {
    final ids = BusinessPlanningService.ebookWorkflowStages.map((e) => e.$1).toSet();
    expect(ids.contains('final_policy'), isFalse);
    expect(ids.contains('release_package'), isFalse);
    expect(ids.contains('package_user_review'), isTrue);
  });
}
