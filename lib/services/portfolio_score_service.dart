import '../models/portfolio_models.dart';

/// 포트폴리오 7차원 점수 계산 (순수 Dart, 테스트 가능).
///
/// 각 차원은 0–5 또는 0–100 정수를 받으며, 내부적으로 0–100 스케일로 정규화한다.
/// 0–5 값은 ×20으로 환산한다.
///
/// 가중치 (합 100%, 자동 승인 없음 — 참고용 총점만 산출):
/// | 차원 | 가중치 |
/// |------|--------|
/// | 회장 관심 (chairmanInterest) | 15% |
/// | 미래 필요 (futureNeed) | 15% |
/// | 시장성 (marketability) | 15% |
/// | 필요성 (necessity) | 10% |
/// | 차별성 (differentiation) | 15% |
/// | 수익화 잠재 (monetizationPotential) | 20% |
/// | 제작 가능성 (buildability) | 10% |
class PortfolioScoreService {
  const PortfolioScoreService();

  static const weights = {
    'chairmanInterest': 0.15,
    'futureNeed': 0.15,
    'marketability': 0.15,
    'necessity': 0.10,
    'differentiation': 0.15,
    'monetizationPotential': 0.20,
    'buildability': 0.10,
  };

  /// 단일 차원을 0–100으로 정규화.
  static int normalizeDimension(int raw) {
    if (raw <= 0) return 0;
    if (raw <= 5) return (raw * 20).clamp(0, 100);
    return raw.clamp(0, 100);
  }

  PortfolioScoreBreakdown compute({
    required int chairmanInterest,
    required int futureNeed,
    required int marketability,
    required int necessity,
    required int differentiation,
    required int monetizationPotential,
    required int buildability,
    String evidenceSource = PortfolioEvidenceSource.userJudgment,
  }) {
    final ci = normalizeDimension(chairmanInterest);
    final fn = normalizeDimension(futureNeed);
    final mk = normalizeDimension(marketability);
    final nc = normalizeDimension(necessity);
    final df = normalizeDimension(differentiation);
    final mp = normalizeDimension(monetizationPotential);
    final bd = normalizeDimension(buildability);

    final total = _weightedTotal(
      chairmanInterest: ci,
      futureNeed: fn,
      marketability: mk,
      necessity: nc,
      differentiation: df,
      monetizationPotential: mp,
      buildability: bd,
    );

    final reasons = <String>[];
    final cautions = <String>[];

    if (ci >= 70) {
      reasons.add('회장 관심도가 높습니다.');
    } else if (ci < 40) {
      cautions.add('회장 관심도가 낮습니다.');
    }
    if (mp >= 70) {
      reasons.add('수익화 잠재가 큽니다.');
    } else if (mp < 40) {
      cautions.add('수익화 경로가 불명확합니다.');
    }
    if (bd >= 70) {
      reasons.add('제작 가능성이 높습니다.');
    } else if (bd < 40) {
      cautions.add('제작 난이도·리소스 부담을 검토하세요.');
    }
    if (df >= 70) {
      reasons.add('차별 포인트가 뚜렷합니다.');
    }
    if (mk >= 70 && nc >= 60) {
      reasons.add('시장성과 필요성이 균형 있습니다.');
    }
    if (fn >= 70) {
      reasons.add('미래 수요 전망이 좋습니다.');
    }

    return PortfolioScoreBreakdown(
      chairmanInterest: ci,
      futureNeed: fn,
      marketability: mk,
      necessity: nc,
      differentiation: df,
      monetizationPotential: mp,
      buildability: bd,
      total: total,
      reasons: reasons,
      cautions: cautions,
      evidenceSource: evidenceSource,
    );
  }

  PortfolioScoreBreakdown computeFromItem(PortfolioItem item) {
    return compute(
      chairmanInterest: item.chairmanInterest,
      futureNeed: item.futureNeed,
      marketability: item.marketability,
      necessity: item.necessity,
      differentiation: item.differentiation,
      monetizationPotential: item.monetizationPotential,
      buildability: item.buildability,
      evidenceSource:
          item.scoreBreakdown?.evidenceSource ??
          PortfolioEvidenceSource.userJudgment,
    );
  }

  PortfolioItem applyScoresToItem(PortfolioItem item) {
    final breakdown = computeFromItem(item);
    return item.copyWith(
      scoreBreakdown: breakdown,
      recommendedTotalScore: breakdown.total,
    );
  }

  static int _weightedTotal({
    required int chairmanInterest,
    required int futureNeed,
    required int marketability,
    required int necessity,
    required int differentiation,
    required int monetizationPotential,
    required int buildability,
  }) {
    final sum =
        chairmanInterest * weights['chairmanInterest']! +
        futureNeed * weights['futureNeed']! +
        marketability * weights['marketability']! +
        necessity * weights['necessity']! +
        differentiation * weights['differentiation']! +
        monetizationPotential * weights['monetizationPotential']! +
        buildability * weights['buildability']!;
    return sum.round().clamp(0, 100);
  }
}
