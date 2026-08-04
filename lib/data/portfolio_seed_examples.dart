/// UI 검증용 최소 예시 시드 — 실제 250개 프로젝트를 만들지 않는다.
///
/// 사용자가 「예시 주제 묶음 불러오기」를 탭할 때만 로드한다.
library;

import '../models/portfolio_models.dart';
import '../services/portfolio_score_service.dart';
import '../services/portfolio_store.dart';

class PortfolioSeedExamples {
  PortfolioSeedExamples._();

  static const bundleId = 'pf_seed_bundle_rural_ai_income';
  static const maxSeedCount = 10;

  static const _topic = '시골에서 AI로 온라인 수익 만들기';
  static const _category = '귀촌·부업·AI';

  static ThemeBundle themeBundle() {
    return ThemeBundle(
      id: bundleId,
      coreTopic: _topic,
      description: '전자책·앱·콘텐츠·사이트·홍보사이트를 하나의 주제로 연결한 예시 묶음입니다.',
      linkedProjectIds: [
        'pf_seed_ebook_01',
        'pf_seed_app_01',
        'pf_seed_contents_01',
        'pf_seed_site_01',
        'pf_seed_promo_01',
      ],
      sharedMaterials: [
        '타깃: 귀촌·귀농 준비 40–60대',
        '핵심 문제: 시골에서 온라인 수익 방법을 모름',
        '공통 키워드: AI, 부업, 디지털 전환',
      ],
    );
  }

  static List<PortfolioItem> seedItems([DateTime? now]) {
    final clock = now ?? DateTime.now();
    final score = PortfolioScoreService();

    PortfolioItem base({
      required String id,
      required String artifact,
      required String title,
      required String oneLiner,
      required String status,
      int seq = 0,
      int ci = 3,
      int fn = 4,
      int mk = 4,
      int nc = 4,
      int df = 3,
      int mp = 4,
      int bd = 4,
    }) {
      final breakdown = score.compute(
        chairmanInterest: ci,
        futureNeed: fn,
        marketability: mk,
        necessity: nc,
        differentiation: df,
        monetizationPotential: mp,
        buildability: bd,
        evidenceSource: PortfolioEvidenceSource.aiEstimate,
      );
      return PortfolioItem(
        id: id,
        sequence: seq,
        title: title,
        artifactType: artifact,
        topicCategory: _category,
        oneLiner: oneLiner,
        topicReason: '귀촌·부업 수요와 AI 도구 보급이 맞물린 주제입니다.',
        targetUsers: '귀촌·귀농 준비 40–60대',
        problem: '시골 생활에서 온라인 수익 경로를 모르는 문제',
        mainDeliverables: [ArtifactType.labelShortKo(artifact)],
        chairmanInterest: ci,
        futureNeed: fn,
        marketability: mk,
        necessity: nc,
        differentiation: df,
        monetizationPotential: mp,
        buildability: bd,
        scoreBreakdown: breakdown,
        recommendedTotalScore: breakdown.total,
        status: status,
        themeBundleId: bundleId,
        notes: '[TEST] UI 검증용 예시 시드',
        createdAt: clock,
        updatedAt: clock,
      );
    }

    return [
      base(
        id: 'pf_seed_ebook_01',
        artifact: ArtifactType.ebook,
        title: '시골 AI 부업 전자책',
        oneLiner: '귀촌 준비자를 위한 AI 온라인 수익 가이드',
        status: PortfolioStatus.planningCandidate,
        seq: 1,
      ),
      base(
        id: 'pf_seed_app_01',
        artifact: ArtifactType.app,
        title: '시골 AI 수익 체크리스트 앱',
        oneLiner: '주간 실행 과제와 AI 프롬프트를 제공하는 앱',
        status: PortfolioStatus.planningCandidate,
        seq: 2,
      ),
      base(
        id: 'pf_seed_contents_01',
        artifact: ArtifactType.contents,
        title: '시골 AI 부업 쇼츠 시리즈',
        oneLiner: '3분 쇼츠로 AI 부업 팁 전달',
        status: PortfolioStatus.ideaCandidate,
        seq: 3,
      ),
      base(
        id: 'pf_seed_site_01',
        artifact: ArtifactType.site,
        title: '시골 AI 부업 정보 사이트',
        oneLiner: '블로그·자료실형 정보 사이트',
        status: PortfolioStatus.ideaCandidate,
        seq: 4,
      ),
      base(
        id: 'pf_seed_promo_01',
        artifact: ArtifactType.promoSite,
        title: '시골 AI 부업 랜딩',
        oneLiner: '전자책·앱 홍보용 마케팅 사이트',
        status: PortfolioStatus.planningCandidate,
        seq: 5,
      ),
      base(
        id: 'pf_seed_ebook_02',
        artifact: ArtifactType.ebook,
        title: 'AI 프롬프트 30선 (부업편)',
        oneLiner: '추가 전자책 아이디어',
        status: PortfolioStatus.ideaCandidate,
        seq: 6,
        ci: 2,
        mp: 3,
      ),
      base(
        id: 'pf_seed_app_02',
        artifact: ArtifactType.app,
        title: 'AI 일지 메모 앱',
        oneLiner: '부업 실행 기록용 보조 앱',
        status: PortfolioStatus.ideaCandidate,
        seq: 7,
        ci: 2,
      ),
    ];
  }

  static List<PortfolioItem> allSeedItems([DateTime? now]) => seedItems(now);

  static Future<PortfolioSeedLoadResult> loadIntoStore({
    required Future<List<PortfolioItem>> Function() loadItems,
    required Future<void> Function(List<PortfolioItem>) saveItems,
    required Future<List<ThemeBundle>> Function() loadBundles,
    required Future<void> Function(List<ThemeBundle>) saveBundles,
  }) async {
    final existing = await loadItems();
    final existingIds = existing.map((e) => e.id).toSet();
    final toAdd = seedItems()
        .where((e) => !existingIds.contains(e.id))
        .toList();

    final mergedItems = PortfolioStore.dedupeById([...toAdd, ...existing]);

    final bundles = await loadBundles();
    final bundle = themeBundle();
    final bundleIndex = bundles.indexWhere((b) => b.id == bundle.id);
    final nextBundles = List<ThemeBundle>.from(bundles);
    if (bundleIndex >= 0) {
      nextBundles[bundleIndex] = bundle;
    } else {
      nextBundles.insert(0, bundle);
    }

    await saveItems(mergedItems);
    await saveBundles(nextBundles);

    return PortfolioSeedLoadResult(
      addedCount: toAdd.length,
      totalSeedAvailable: seedItems().length,
    );
  }
}

class PortfolioSeedLoadResult {
  const PortfolioSeedLoadResult({
    required this.addedCount,
    required this.totalSeedAvailable,
  });

  final int addedCount;
  final int totalSeedAvailable;
}
