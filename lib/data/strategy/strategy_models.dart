/// 사업 전략 아티클 데이터 모델.
///
/// 순수 Dart 상수 데이터로만 구성되며 외부 API나 Flutter 의존성이 없다.
class StrategyArticle {
  const StrategyArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.tags,
    required this.audience,
    required this.readingMinutes,
    required this.difficulty,
    required this.recommendOrder,
    required this.whyRead,
    required this.keyQuestion,
    required this.opening,
    required this.wrongJudgment,
    required this.principle,
    required this.successVsFailure,
    required this.caseStudy,
    required this.application,
    required this.options,
    required this.reviewQuestions,
    required this.monthActions,
    required this.insight,
  });

  final String id;
  final String title;

  /// 한 줄 소개.
  final String summary;

  /// 6개 카테고리 중 하나.
  final String category;

  /// 핵심 키워드 3~5개.
  final List<String> tags;

  /// 추천 대상.
  final String audience;

  /// 예상 읽기 시간(분).
  final int readingMinutes;

  /// 기초 | 실전 | 심화
  final String difficulty;

  /// 1..20, 낮을수록 먼저 읽기를 권한다.
  final int recommendOrder;

  final String whyRead;
  final String keyQuestion;

  /// 현실적인 문제 상황.
  final String opening;

  /// 흔히 저지르는 잘못된 판단.
  final String wrongJudgment;

  /// 핵심 원리와 그 이유.
  final String principle;

  final String successVsFailure;

  /// 작은 사업 / 1인 기업 사례.
  final String caseStudy;

  /// 실제 적용 방법.
  final String application;

  /// 선택 가능한 대안 2~3개.
  final List<StrategyOption> options;

  /// 생각해 볼 질문 3~5개.
  final List<String> reviewQuestions;

  /// 이번 달 실행 항목 3개.
  final List<String> monthActions;

  /// 핵심 깨달음.
  final String insight;

  /// TOC용 본문 섹션 (질문·행동은 UI에서 별도 블록).
  List<StrategySection> get readingSections => [
    StrategySection(id: 'opening', title: '현실의 문제', body: opening),
    StrategySection(
      id: 'wrongJudgment',
      title: '자주 하는 잘못된 판단',
      body: wrongJudgment,
    ),
    StrategySection(id: 'principle', title: '핵심 원리', body: principle),
    StrategySection(
      id: 'successVsFailure',
      title: '성공과 실패의 차이',
      body: successVsFailure,
    ),
    StrategySection(id: 'caseStudy', title: '현실 사례', body: caseStudy),
    StrategySection(id: 'application', title: '내 사업에 적용', body: application),
    StrategySection(id: 'insight', title: '핵심 깨달음', body: insight),
  ];

  /// 품질 검사용 본문 분량(공백 포함).
  int get bodyCharCount {
    var count =
        whyRead.length +
        keyQuestion.length +
        opening.length +
        wrongJudgment.length +
        principle.length +
        successVsFailure.length +
        caseStudy.length +
        application.length +
        insight.length;
    for (final option in options) {
      count +=
          option.title.length +
          option.description.length +
          option.pros.length +
          option.risks.length;
    }
    for (final q in reviewQuestions) {
      count += q.length;
    }
    for (final a in monthActions) {
      count += a.length;
    }
    return count;
  }
}

class StrategySection {
  const StrategySection({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;
}

class StrategyOption {
  const StrategyOption({
    required this.title,
    required this.description,
    required this.pros,
    required this.risks,
  });

  final String title;
  final String description;
  final String pros;
  final String risks;
}

/// 사업전략연구실 카테고리 (6개).
class StrategyCategories {
  static const thinking = '사업가의 사고';
  static const market = '고객과 시장';
  static const product = '상품과 수익';
  static const sales = '영업과 신뢰';
  static const systems = '시스템과 AI';
  static const growth = '성장과 위험관리';

  static const all = <String>[
    thinking,
    market,
    product,
    sales,
    systems,
    growth,
  ];
}
