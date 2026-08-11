import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/data/idea_bank_seed.dart';
import 'package:sotong_ware_control/screens/idea_bank_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpBank(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IdeaBankScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('모바일 compact header · 목록 모드', (tester) async {
    await pumpBank(tester, 390);
    expect(find.text('뉴 아이디어 뱅크'), findsOneWidget);
    expect(find.text('필터'), findsOneWidget);
    expect(find.textContaining('기회와 제작 아이디어'), findsNothing);
    expect(find.text('전체 연도'), findsNothing);
    // 시드 카드가 목록에 보임
    expect(find.textContaining('시드'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 필터 열기/닫기 · 카테고리 · 검색', (tester) async {
    await pumpBank(tester, 390);
    await tester.tap(find.text('필터'));
    await tester.pumpAndSettle();
    expect(find.text('필터 · 검색'), findsOneWidget);
    expect(find.text('전체 카테고리'), findsOneWidget);
    expect(find.text('세계 트렌드'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '트렌드');
    await tester.pumpAndSettle();
    await tester.tap(find.text('세계 트렌드'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('적용'));
    await tester.pumpAndSettle();

    expect(find.text('필터 · 검색'), findsNothing);
    expect(find.text('필터'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 목록→읽기→목록 · 본문 상단 · CTA', (tester) async {
    await pumpBank(tester, 390);
    final seeds = IdeaBankSeedCatalog.seeds();
    expect(seeds, isNotEmpty);
    final title = seeds.first.title;

    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();

    expect(find.text('목록'), findsOneWidget);
    expect(find.text('왜 지금 주목할 만한가'), findsWidgets);
    expect(find.text('전자책으로 검토'), findsOneWidget);
    expect(find.text('전체화면 종료'), findsNothing);

    // 본문이 목록 소개문 없이 제목부터
    expect(find.textContaining('기회와 제작 아이디어'), findsNothing);

    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsWidgets);
    expect(find.text('목록'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 전체화면 읽기', (tester) async {
    await pumpBank(tester, 390);
    final title = IdeaBankSeedCatalog.seeds().first.title;
    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('전체화면 읽기'));
    await tester.pumpAndSettle();
    expect(find.text('전체화면 종료'), findsOneWidget);
    await tester.tap(find.text('전체화면 종료'));
    await tester.pumpAndSettle();
    expect(find.text('필터'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('아이디어뱅크 모바일 읽기 overflow ${width.toInt()}px', (
      tester,
    ) async {
      await pumpBank(tester, width);
      final title = IdeaBankSeedCatalog.seeds().first.title;
      await tester.tap(find.text(title).first);
      await tester.pumpAndSettle();
      expect(find.text('전자책으로 검토'), findsOneWidget);
      expect(find.text('홍보사업으로 검토'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('768은 모바일 compact(900 미만)', (tester) async {
    await pumpBank(tester, 768);
    expect(find.text('필터'), findsOneWidget);
    expect(find.textContaining('기회와 제작 아이디어'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop은 기존 탐색 UI 유지', (tester) async {
    await pumpBank(tester, 1280);
    expect(find.textContaining('기회와 제작 아이디어'), findsOneWidget);
    expect(find.text('전체 카테고리'), findsOneWidget);
    expect(find.text('추가'), findsOneWidget);
    expect(find.text('필터'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1600 desktop overflow 없음', (tester) async {
    await pumpBank(tester, 1600);
    expect(find.text('뉴 아이디어 뱅크'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
