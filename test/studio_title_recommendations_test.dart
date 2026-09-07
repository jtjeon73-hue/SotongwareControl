import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/services/studio_title_recommendations.dart';

void main() {
  test('사업부별 추천 제목은 최대 50개, 기술명-only/과장 금지', () {
    for (final kind in StudioTitleRecommendations.businessKinds) {
      final titles = StudioTitleRecommendations.recommend(
        artifactType: kind.artifactType,
        siteSubtype: kind.siteSubtype,
        audienceIds: const ['general'],
        businessKindId: kind.id,
        limit: 50,
      );
      expect(titles, isNotEmpty, reason: kind.label);
      expect(titles.length, lessThanOrEqualTo(50));
      expect(titles.length, greaterThanOrEqualTo(20), reason: kind.label);
      expect(titles.toSet().length, titles.length, reason: 'no exact dup ${kind.label}');
      for (final t in titles) {
        expect(t.length, greaterThanOrEqualTo(8));
        expect(t.contains('%'), isFalse);
        expect(RegExp(r'월\s*\d+|억\s*매출').hasMatch(t), isFalse);
      }
    }
  });

  test('고객/사이트 문맥이 바뀌면 추천이 달라진다', () {
    final marketing = StudioTitleRecommendations.recommend(
      artifactType: ArtifactType.site,
      siteSubtype: 'marketing_site',
      audienceIds: const ['소상공인'],
    );
    final knowledge = StudioTitleRecommendations.recommend(
      artifactType: ArtifactType.site,
      siteSubtype: 'knowledge_site',
      audienceIds: const ['학생'],
    );
    expect(marketing.first, isNot(equals(knowledge.first)));
  });

  test('직접입력 placeholder는 저장값이 아닌 안내문', () {
    final p = StudioTitleRecommendations.ideaPlaceholder(
      artifactType: ArtifactType.ebook,
    );
    expect(p.startsWith('예:'), isTrue);
    expect(p.contains('전자책'), isTrue);
  });
}
