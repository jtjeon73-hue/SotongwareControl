import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/screens/ai_business_analysis_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> ensureProductionSettingsVisible(WidgetTester tester) async {
    final label = find.byKey(const Key('planning_ai_production_mode_label'));
    if (label.evaluate().isNotEmpty) {
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      return;
    }
    final title = find.text('상세 제작 설정 (선택)');
    await tester.ensureVisible(title.first);
    await tester.tap(title.first);
    await tester.pumpAndSettle();
    expect(label, findsOneWidget);
  }

  testWidgets('사업유형 변경 시 AI 자동 제작 라벨이 즉시 동기화 (전자책→마케팅)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiBusinessAnalysisScreen())),
    );
    await tester.pumpAndSettle();

    final ebook = find.byKey(const ValueKey('biz-kind-ebook'));
    await tester.ensureVisible(ebook);
    await tester.tap(ebook);
    await tester.pumpAndSettle();

    await ensureProductionSettingsVisible(tester);
    expect(find.text('AI 자동 제작 (전자책)'), findsWidgets);

    final marketing = find.byKey(const ValueKey('biz-kind-marketing_site'));
    await tester.ensureVisible(marketing);
    await tester.tap(marketing);
    await tester.pumpAndSettle();

    final siteKind = find.byKey(const ValueKey('site-kind-marketing_site'));
    if (siteKind.evaluate().isNotEmpty) {
      await tester.ensureVisible(siteKind);
      await tester.tap(siteKind);
      await tester.pumpAndSettle();
    }

    await ensureProductionSettingsVisible(tester);
    expect(find.text('AI 자동 제작 (마케팅 사이트)'), findsWidgets);
    expect(find.text('AI 자동 제작 (전자책)'), findsNothing);
  });
}
