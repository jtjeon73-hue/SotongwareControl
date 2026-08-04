import '../models/portfolio_models.dart';
import 'portfolio_score_service.dart';

/// 포트폴리오 대시보드 집계 (UI 없음).
class PortfolioDashboardService {
  const PortfolioDashboardService({
    this.stalledAfterDays = 21,
    this.scoreService = const PortfolioScoreService(),
  });

  final int stalledAfterDays;
  final PortfolioScoreService scoreService;

  PortfolioDashboardStats build({
    required List<PortfolioItem> items,
    required PortfolioArtifactGoals goals,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final active = items
        .where(
          (i) =>
              PortfolioStatus.normalize(i.status) != PortfolioStatus.archived,
        )
        .toList();

    final byArtifact = <String, ArtifactPortfolioStats>{};
    for (final artifact in ArtifactType.allSelectable) {
      final artifactItems = active
          .where((i) => ArtifactType.normalize(i.artifactType) == artifact)
          .toList();
      final goal = goals.goalFor(artifact);
      final candidates = artifactItems
          .where((i) => PortfolioStatus.isCandidate(i.status))
          .length;
      final planned = artifactItems
          .where((i) => PortfolioStatus.isPlanned(i.status))
          .length;
      final inProduction = artifactItems
          .where((i) => PortfolioStatus.isInProduction(i.status))
          .length;
      final launched = artifactItems
          .where((i) => PortfolioStatus.isLaunched(i.status))
          .length;
      final progress = goal > 0
          ? ((launched / goal) * 100).round().clamp(0, 999)
          : 0;

      final next = _nextForArtifact(artifactItems);

      byArtifact[artifact] = ArtifactPortfolioStats(
        artifact: artifact,
        goal: goal,
        candidates: candidates,
        planned: planned,
        inProduction: inProduction,
        launched: launched,
        progress: progress,
        nextRecommended: next,
      );
    }

    final scored = active.map(scoreService.applyScoresToItem).toList();

    final nextRecommended = _topCandidates(scored, limit: 5);

    final actionNeeded = scored.where((i) {
      final s = PortfolioStatus.normalize(i.status);
      return s == PortfolioStatus.researchNeeded ||
          s == PortfolioStatus.planningCandidate ||
          s == PortfolioStatus.reviewRevise ||
          s == PortfolioStatus.improve;
    }).toList();

    final transferWaiting = scored
        .where(
          (i) =>
              PortfolioStatus.normalize(i.status) ==
              PortfolioStatus.productionApproved,
        )
        .toList();

    final reviewWaiting = scored
        .where(
          (i) =>
              PortfolioStatus.normalize(i.status) ==
              PortfolioStatus.reviewRevise,
        )
        .toList();

    final stalledThreshold = clock.subtract(Duration(days: stalledAfterDays));
    final stalled = scored.where((i) {
      final s = PortfolioStatus.normalize(i.status);
      if (s == PortfolioStatus.archived ||
          s == PortfolioStatus.launchedOps ||
          s == PortfolioStatus.performanceWatch) {
        return false;
      }
      return i.updatedAt.isBefore(stalledThreshold);
    }).toList();

    final launchedWithResults = scored
        .where(
          (i) =>
              PortfolioStatus.isLaunched(i.status) &&
              i.postLaunchResults.isNotEmpty,
        )
        .toList();

    return PortfolioDashboardStats(
      byArtifact: byArtifact,
      nextRecommended: nextRecommended,
      actionNeeded: actionNeeded,
      transferWaiting: transferWaiting,
      reviewWaiting: reviewWaiting,
      stalled: stalled,
      launchedWithResults: launchedWithResults,
    );
  }

  PortfolioItem? _nextForArtifact(List<PortfolioItem> items) {
    if (items.isEmpty) return null;
    final scored = items.map(scoreService.applyScoresToItem).toList();
    final early = scored
        .where((i) => PortfolioStatus.isCandidate(i.status))
        .toList();
    if (early.isEmpty) {
      early.addAll(scored.where((i) => PortfolioStatus.isPlanned(i.status)));
    }
    if (early.isEmpty) return null;
    early.sort(
      (a, b) => b.recommendedTotalScore.compareTo(a.recommendedTotalScore),
    );
    return early.first;
  }

  List<PortfolioItem> _topCandidates(
    List<PortfolioItem> items, {
    int limit = 5,
  }) {
    final candidates =
        items.where((i) => PortfolioStatus.isCandidate(i.status)).toList()
          ..sort(
            (a, b) =>
                b.recommendedTotalScore.compareTo(a.recommendedTotalScore),
          );
    return candidates.take(limit).toList();
  }
}
