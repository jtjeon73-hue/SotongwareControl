import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/strategy/strategy_articles.dart';
import 'package:sotong_ware_control/data/strategy/strategy_models.dart';

const _expectedTitles = [
  '소통웨어는 어떤 문제를 해결하는 회사가 되어야 하는가',
  '많은 아이디어 중 돈이 되는 사업을 선별하는 기준',
  '산업자동화 경험을 온라인 자산으로 전환하는 전략',
  '앱을 많이 만드는 것과 성공하는 앱을 만드는 것의 차이',
  '고객이 실제로 돈을 지불하는 문제를 발견하는 방법',
  '1인 개발기업이 선택과 집중을 해야 하는 이유',
  '여섯 개 사업부를 하나의 수익 구조로 연결하는 방법',
  '소통사이트매니저를 사업 플랫폼으로 발전시키는 전략',
  '무료 정보 사이트를 유료 수익으로 연결하는 현실적인 경로',
  '광고수익에만 의존하지 않는 앱 수익모델 설계',
  'AI 자동화로 줄일 일과 사람이 직접 판단해야 할 일',
  '반복 가능한 소프트웨어 상품을 만드는 표준화 전략',
  '지역과 산업 현장의 문제를 온라인 사업으로 만드는 방법',
  '경쟁이 심한 시장에서 소통웨어만의 차별성을 만드는 방법',
  '고객 신뢰를 쌓는 포트폴리오와 실제 사례의 중요성',
  '실패 가능성이 높은 사업을 적은 비용으로 검증하는 방법',
  '여러 프로젝트가 중단되지 않도록 우선순위를 관리하는 방법',
  '월 수익 목표를 방문자·고객·전환율로 분해하는 방법',
  '소통웨어의 1년·3년·5년 성장 경로 설계',
  '소통회장이 기술자에서 사업가로 성장하기 위해 필요한 변화',
];

int _bodyCharCount(StrategyArticle article) {
  var count =
      article.problem.length +
      article.whyImportant.length +
      article.corePrinciples.length +
      article.sotongwareApplication.length +
      article.scenario.length +
      article.conclusion.length;

  for (final option in article.options) {
    count +=
        option.title.length +
        option.description.length +
        option.pros.length +
        option.risks.length;
  }
  return count;
}

void main() {
  test('allStrategyArticles has exactly 20 entries', () {
    expect(allStrategyArticles.length, 20);
  });

  test('strategy_01..strategy_20 ids exist', () {
    final ids = allStrategyArticles.map((a) => a.id).toSet();
    for (var i = 1; i <= 20; i++) {
      final id = 'strategy_${i.toString().padLeft(2, '0')}';
      expect(ids, contains(id), reason: 'missing $id');
    }
    expect(ids.length, 20);
  });

  test('article titles match required list', () {
    expect(allStrategyArticles.map((a) => a.title).toList(), _expectedTitles);
  });

  test('each article meets content structure requirements', () {
    for (final article in allStrategyArticles) {
      expect(
        article.options.length,
        greaterThanOrEqualTo(2),
        reason: '${article.id} options',
      );
      expect(
        article.reviewQuestions.length,
        greaterThanOrEqualTo(3),
        reason: '${article.id} reviewQuestions',
      );
      expect(
        article.monthActions.length,
        3,
        reason: '${article.id} monthActions',
      );
      expect(
        _bodyCharCount(article),
        greaterThanOrEqualTo(1400),
        reason: '${article.id} body length',
      );
    }
  });
}
