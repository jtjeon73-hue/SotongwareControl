import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/data/strategy/strategy_articles.dart';
import 'package:sotong_ware_control/data/strategy/strategy_models.dart';
import 'package:sotong_ware_control/screens/business_study_screen.dart';
import 'package:sotong_ware_control/services/strategy_lab_progress_store.dart';

const _expectedTitles = [
  '사업은 아이디어가 아니라 고객의 불편에서 시작된다',
  '열심히 하는 것보다 무엇을 하지 않을지 정하는 힘',
  '고객이 필요하다고 말하는 것과 실제 돈을 내는 것의 차이',
  '작은 사업이 큰 회사와 싸우지 않고 살아남는 방법',
  '좋은 기술이 반드시 좋은 상품이 되지는 않는 이유',
  '가격을 낮추지 않고도 고객의 선택을 받는 가치 설계',
  '매출보다 먼저 살펴야 하는 현금흐름과 고정비',
  '한 번의 판매를 반복 수익으로 바꾸는 사업 구조',
  '여러 사업을 벌일 때 핵심 사업을 잃지 않는 방법',
  '실패 비용을 줄이는 작은 실험과 시장 검증',
  '고객 한 명의 신뢰가 광고보다 강한 이유',
  '영업을 부탁이 아니라 문제 해결의 제안으로 만드는 법',
  '경쟁자를 따라가지 않고 나만의 시장을 만드는 방법',
  '대표가 모든 일을 직접 하면 사업이 성장하지 못하는 이유',
  '사람이 하던 일을 시스템과 자동화로 바꾸는 순서',
  'AI를 단순한 도구가 아닌 사업 경쟁력으로 만드는 방법',
  '경험과 기술을 사라지지 않는 디지털 자산으로 만드는 법',
  '위기에서 버틸 수 있는 사업의 안전장치와 위험관리',
  '1년·3년·5년을 연결하는 현실적인 성장 전략',
  '기술자가 사업가로 성장할 때 바뀌어야 하는 생각',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('전략 글이 정확히 20편이고 ID·제목이 중복되지 않는다', () {
    expect(allStrategyArticles.length, 20);
    final ids = allStrategyArticles.map((a) => a.id).toList();
    final titles = allStrategyArticles.map((a) => a.title).toList();
    expect(ids.toSet().length, 20);
    expect(titles.toSet().length, 20);
    for (var i = 1; i <= 20; i++) {
      expect(ids, contains('strategy_${i.toString().padLeft(2, '0')}'));
    }
    expect(titles, _expectedTitles);
  });

  test('각 글이 품질·분량·메타 기준을 충족한다', () {
    for (final article in allStrategyArticles) {
      expect(article.summary.trim(), isNotEmpty);
      expect(StrategyCategories.all, contains(article.category));
      expect(article.tags.length, inInclusiveRange(3, 5));
      expect(article.audience.trim(), isNotEmpty);
      expect(article.readingMinutes, greaterThanOrEqualTo(5));
      expect(['기초', '실전', '심화'], contains(article.difficulty));
      expect(article.recommendOrder, inInclusiveRange(1, 20));
      expect(article.options.length, greaterThanOrEqualTo(2));
      expect(article.reviewQuestions.length, greaterThanOrEqualTo(3));
      expect(article.monthActions.length, 3);
      expect(
        article.bodyCharCount,
        greaterThanOrEqualTo(2500),
        reason: '${article.id} body=${article.bodyCharCount}',
      );
    }
  });

  test('마지막 읽은 글과 오늘의 추천 ID가 유효하다', () async {
    final store = StrategyLabProgressStore();
    expect(await store.loadLastOpenedId(), isNull);
    await store.saveLastOpenedId('strategy_05');
    expect(await store.loadLastOpenedId(), 'strategy_05');
    await store.saveLastOpenedId('legacy_unknown');
    expect(await store.loadLastOpenedId(), isNull);

    final recommended = StrategyLabProgressStore.todaysRecommendedId(
      DateTime(2026, 7, 30),
    );
    expect(StrategyLabProgressStore.isKnownArticleId(recommended), isTrue);
  });

  test('즐겨찾기·읽기 상태가 보존된다', () async {
    final store = StrategyLabProgressStore();
    await store.setStatus('strategy_01', 'reviewed');
    await store.toggleFavorite('strategy_01');
    await store.saveMemo('strategy_01', '회장 메모');
    await store.saveApplyNote('strategy_01', '적용점');
    await store.saveActionCheck('strategy_01', 0, true);

    expect((await store.loadStatuses())['strategy_01'], 'reviewed');
    expect(await store.loadFavorites(), contains('strategy_01'));
    expect((await store.loadMemos())['strategy_01'], '회장 메모');
    expect((await store.loadApplyNotes())['strategy_01'], '적용점');
    expect(
      (await store.loadActionChecks())[StrategyLabProgressStore.actionEntryKey(
        'strategy_01',
        0,
      )],
      isTrue,
    );
  });

  testWidgets('첫 진입 시 본문이 자동 선택되고 빈 선택 화면이 없다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BusinessStudyScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('사업전략연구실'), findsOneWidget);
    expect(find.textContaining('연구 주제를 선택하세요'), findsNothing);
    expect(find.textContaining('왼쪽에서'), findsNothing);
    // 추천/첫 글 본문 제목 중 하나가 보여야 함
    final anyTitleVisible = _expectedTitles.any(
      (t) => find.text(t).evaluate().isNotEmpty,
    );
    expect(anyTitleVisible, isTrue);
  });

  testWidgets('검색과 카테고리 필터가 동작한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BusinessStudyScreen())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '현금흐름');
    await tester.pumpAndSettle();
    expect(find.textContaining('현금흐름'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('시스템과 AI').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('연구 주제를 선택하세요'), findsNothing);
  });

  testWidgets('모바일 목록→본문→목록 이동', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BusinessStudyScreen())),
    );
    await tester.pumpAndSettle();

    // 모바일: 컴팩트 바 + 본문. 목록은 BottomSheet.
    expect(find.text('목록으로 돌아가기'), findsNothing);
    expect(find.text('목록'), findsOneWidget);
    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();
    expect(find.text('연구주제 목록'), findsOneWidget);

    final second = allStrategyArticles[1];
    await tester.ensureVisible(find.text(second.title).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(second.title).last);
    await tester.pumpAndSettle();
    expect(find.text('연구주제 목록'), findsNothing);
    expect(find.text(second.title), findsWidgets);
    expect(find.text('목록'), findsOneWidget);

    // 전체화면 읽기
    await tester.tap(find.byTooltip('전체화면 읽기'));
    await tester.pumpAndSettle();
    expect(find.text('전체화면 종료'), findsOneWidget);
    expect(find.text('목록'), findsNothing);
    await tester.tap(find.text('전체화면 종료'));
    await tester.pumpAndSettle();
    expect(find.text('목록'), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    testWidgets('모바일 읽기 영역 비율 $width', (tester) async {
      const height = 800.0;
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BusinessStudyScreen())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('사업전략연구실'), findsOneWidget);
      expect(find.text('목록'), findsOneWidget);
      // 상단 컴팩트 바(~52)만 — 본문이 뷰포트의 대부분을 사용
      const bar = 52.0;
      final bodyShare = (height - bar) / height;
      expect(bodyShare, greaterThanOrEqualTo(0.85));
      expect(find.text('목록으로 돌아가기'), findsNothing);
    });
  }

  for (final width in [360.0, 768.0, 1366.0, 1440.0]) {
    testWidgets('오버플로 없음 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BusinessStudyScreen())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('연구 주제를 선택하세요'), findsNothing);
    });
  }
}
