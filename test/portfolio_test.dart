import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/data/portfolio_seed_examples.dart';
import 'package:sotong_ware_control/models/portfolio_models.dart';
import 'package:sotong_ware_control/services/portfolio_dashboard_service.dart';
import 'package:sotong_ware_control/services/portfolio_score_service.dart';
import 'package:sotong_ware_control/services/portfolio_store.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('기본 목표는 artifact별 50', () {
    const goals = PortfolioArtifactGoals();
    for (final artifact in ArtifactType.allSelectable) {
      expect(goals.goalFor(artifact), 50);
    }
  });

  test('목표는 변경 가능하고 상한이 아니다', () async {
    var goals = const PortfolioArtifactGoals();
    goals = goals.setGoal(ArtifactType.ebook, 120);
    expect(goals.goalFor(ArtifactType.ebook), 120);
    expect(goals.goalFor(ArtifactType.app), 50);

    final store = PortfolioStore();
    await store.saveGoals(goals);
    final loaded = await store.loadGoals();
    expect(loaded.goalFor(ArtifactType.ebook), 120);
  });

  test('한 artifact에 50개를 넘는 항목 등록 가능', () async {
    final store = PortfolioStore();
    final now = DateTime(2026, 1, 1);
    final items = List.generate(
      55,
      (i) => PortfolioItem(
        id: 'pf_test_ebook_$i',
        title: '전자책 $i',
        artifactType: ArtifactType.ebook,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await store.saveItems(items);
    final loaded = await store.loadItems();
    expect(
      loaded.where((e) => e.artifactType == ArtifactType.ebook).length,
      55,
    );
  });

  test('artifact·status 필터', () {
    final now = DateTime(2026, 1, 1);
    final items = [
      PortfolioItem(
        id: 'a1',
        artifactType: ArtifactType.app,
        status: PortfolioStatus.ideaCandidate,
        createdAt: now,
        updatedAt: now,
      ),
      PortfolioItem(
        id: 'a2',
        artifactType: ArtifactType.ebook,
        status: PortfolioStatus.planning,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final filtered = PortfolioStore.filterItems(
      items,
      artifact: ArtifactType.app,
      status: PortfolioStatus.ideaCandidate,
    );
    expect(filtered.length, 1);
    expect(filtered.first.id, 'a1');
  });

  test('점수 계산과 reasons 생성', () {
    const service = PortfolioScoreService();
    final breakdown = service.compute(
      chairmanInterest: 4,
      futureNeed: 4,
      marketability: 4,
      necessity: 4,
      differentiation: 4,
      monetizationPotential: 5,
      buildability: 4,
      evidenceSource: PortfolioEvidenceSource.aiEstimate,
    );
    expect(breakdown.total, greaterThan(0));
    expect(breakdown.total, lessThanOrEqualTo(100));
    expect(breakdown.chairmanInterest, 80);
    expect(breakdown.reasons, isNotEmpty);
    expect(breakdown.evidenceSource, PortfolioEvidenceSource.aiEstimate);
  });

  test('theme bundle 링크', () {
    final bundle = PortfolioSeedExamples.themeBundle();
    expect(bundle.linkedProjectIds.length, 5);
    final seeds = PortfolioSeedExamples.seedItems();
    for (final id in bundle.linkedProjectIds) {
      expect(seeds.any((s) => s.id == id), isTrue);
    }
  });

  test('dedupe by id — 최신 updatedAt 유지', () {
    final early = DateTime(2026, 1, 1);
    final late = DateTime(2026, 2, 1);
    final items = [
      PortfolioItem(
        id: 'dup',
        title: 'old',
        createdAt: early,
        updatedAt: early,
      ),
      PortfolioItem(id: 'dup', title: 'new', createdAt: early, updatedAt: late),
    ];
    final deduped = PortfolioStore.dedupeById(items);
    expect(deduped.length, 1);
    expect(deduped.first.title, 'new');
  });

  test('pagination', () {
    final data = List.generate(45, (i) => i);
    final page0 = PortfolioStore.page(data, 0, 20);
    final page1 = PortfolioStore.page(data, 1, 20);
    final page2 = PortfolioStore.page(data, 2, 20);
    expect(page0.length, 20);
    expect(page1.length, 20);
    expect(page2.length, 5);
    expect(PortfolioStore.pageCount(45, 20), 3);
  });

  test('시드 로드는 소량만 추가', () async {
    final store = PortfolioStore();
    final result = await PortfolioSeedExamples.loadIntoStore(
      loadItems: store.loadItems,
      saveItems: store.saveItems,
      loadBundles: store.loadBundles,
      saveBundles: store.saveBundles,
    );
    expect(
      result.totalSeedAvailable,
      lessThanOrEqualTo(PortfolioSeedExamples.maxSeedCount),
    );
    expect(result.addedCount, PortfolioSeedExamples.seedItems().length);

    final items = await store.loadItems();
    expect(items.length, lessThanOrEqualTo(PortfolioSeedExamples.maxSeedCount));

    final second = await PortfolioSeedExamples.loadIntoStore(
      loadItems: store.loadItems,
      saveItems: store.saveItems,
      loadBundles: store.loadBundles,
      saveBundles: store.saveBundles,
    );
    expect(second.addedCount, 0);
  });

  test('대시보드 stats 집계', () {
    final now = DateTime(2026, 3, 1);
    const goals = PortfolioArtifactGoals();
    final items = [
      PortfolioItem(
        id: '1',
        artifactType: ArtifactType.ebook,
        status: PortfolioStatus.ideaCandidate,
        chairmanInterest: 4,
        monetizationPotential: 4,
        buildability: 4,
        futureNeed: 4,
        marketability: 4,
        necessity: 4,
        differentiation: 4,
        createdAt: now,
        updatedAt: now,
      ),
      PortfolioItem(
        id: '2',
        artifactType: ArtifactType.ebook,
        status: PortfolioStatus.inProduction,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final stats = PortfolioDashboardService().build(
      items: items,
      goals: goals,
      now: now,
    );
    final ebookStats = stats.byArtifact[ArtifactType.ebook]!;
    expect(ebookStats.goal, 50);
    expect(ebookStats.candidates, 1);
    expect(ebookStats.inProduction, 1);
  });

  test('메뉴 라벨 제작 포트폴리오', () {
    expect(ControlDestination.portfolioHub.label, '제작 포트폴리오');
  });
}
