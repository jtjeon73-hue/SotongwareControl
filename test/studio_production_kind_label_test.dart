import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/project_design_catalog.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/services/studio_title_recommendations.dart';
import 'package:sotong_ware_control/services/work_instruction_workshop_presentation.dart';

void main() {
  group('AI 자동 제작 라벨 — 6개 businessKind', () {
    final cases = <(String id, String expected)>[
      ('industrial_sw', 'AI 자동 제작 (산업자동화 SW)'),
      ('app', 'AI 자동 제작 (앱)'),
      ('ebook', 'AI 자동 제작 (전자책)'),
      ('knowledge_site', 'AI 자동 제작 (지식·교육 사이트)'),
      ('marketing_site', 'AI 자동 제작 (마케팅 사이트)'),
      ('content', 'AI 자동 제작 (콘텐츠)'),
    ];

    for (final c in cases) {
      test('${c.$1} → ${c.$2}', () {
        final kind = StudioTitleRecommendations.businessKinds.firstWhere(
          (k) => k.id == c.$1,
        );
        final label = StudioTitleRecommendations.aiProductionModeLabel(
          aiPilotEnabled: true,
          artifactType: kind.artifactType,
          siteSubtype: kind.siteSubtype,
          businessKindId: kind.id,
        );
        expect(label, c.$2);
        expect(label.contains('전자책'), c.$1 == 'ebook');
      });
    }

    test('미선택 시 전자책 폴백 없음', () {
      final label = StudioTitleRecommendations.aiProductionModeLabel(
        aiPilotEnabled: true,
        artifactType: ArtifactType.undecided,
      );
      expect(label, 'AI 자동 제작');
      expect(label.contains('전자책'), isFalse);
    });

    test('pilot off → 수동·혼합 제작', () {
      expect(
        StudioTitleRecommendations.aiProductionModeLabel(
          aiPilotEnabled: false,
          businessKindId: 'marketing_site',
          artifactType: ArtifactType.site,
        ),
        '수동·혼합 제작',
      );
    });
  });

  group('marketing siteSubtype 조건부 옵션', () {
    test('marketing_site businessKind → 마케팅 옵션', () {
      final groups = ProjectDesignCatalog.productionGroupsFor(
        ArtifactType.site,
        businessKind: 'marketing_site',
        siteSubtype: 'marketing_site',
      );
      expect(groups.any((g) => g.id == 'marketing_features'), isTrue);
      expect(groups.any((g) => g.id == 'knowledge_content'), isFalse);
      expect(groups.any((g) => g.id == 'format'), isFalse);
      final labels = groups.expand((g) => g.options.map((o) => o.label));
      expect(labels, contains('CTA'));
      expect(labels, contains('SEO'));
      expect(labels, contains('상담/문의'));
    });

    test('siteSubtype만 marketing_site여도 마케팅 옵션', () {
      final groups = ProjectDesignCatalog.productionGroupsFor(
        ArtifactType.site,
        siteSubtype: 'marketing_site',
      );
      expect(groups.any((g) => g.id == 'marketing_features'), isTrue);
    });

    test('knowledge_site와 옵션이 다르다', () {
      final marketing = ProjectDesignCatalog.productionGroupsFor(
        ArtifactType.site,
        businessKind: 'marketing_site',
        siteSubtype: 'marketing_site',
      );
      final knowledge = ProjectDesignCatalog.productionGroupsFor(
        ArtifactType.site,
        businessKind: 'knowledge_site',
        siteSubtype: 'knowledge_site',
      );
      expect(
        marketing.map((g) => g.id).toList(),
        isNot(equals(knowledge.map((g) => g.id).toList())),
      );
      expect(knowledge.any((g) => g.id == 'knowledge_content'), isTrue);
    });
  });

  group('stale 전자책 라벨 regression', () {
    test('전자책 → 마케팅 사이트 변경 시 전자책 문자열 잔존 없음', () {
      final ebook = StudioTitleRecommendations.aiProductionModeLabel(
        aiPilotEnabled: true,
        artifactType: ArtifactType.ebook,
        businessKindId: 'ebook',
      );
      expect(ebook, 'AI 자동 제작 (전자책)');

      final marketing = StudioTitleRecommendations.aiProductionModeLabel(
        aiPilotEnabled: true,
        artifactType: ArtifactType.site,
        siteSubtype: 'marketing_site',
        businessKindId: 'marketing_site',
      );
      expect(marketing, 'AI 자동 제작 (마케팅 사이트)');
      expect(marketing.contains('전자책'), isFalse);

      final viaPresentation =
          WorkInstructionWorkshopPresentation.productionMethodLabel(
            aiPilotEnabled: true,
            artifactType: ArtifactType.site,
            siteSubtype: 'marketing_site',
            businessKindId: 'marketing_site',
          );
      expect(viaPresentation, 'AI 자동 제작 (마케팅 사이트)');
      expect(viaPresentation.contains('전자책'), isFalse);
    });

    test('undecided artifact + empty kind는 전자책으로 강제되지 않음', () {
      final label = WorkInstructionWorkshopPresentation.productionMethodLabel(
        aiPilotEnabled: true,
        artifactType: '',
      );
      expect(label, 'AI 자동 제작');
      expect(label.contains('전자책'), isFalse);
    });
  });
}
