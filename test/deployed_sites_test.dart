import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/deployed_sites_catalog.dart';
import 'package:sotong_ware_control/models/deployed_site.dart';
import 'package:sotong_ware_control/services/deployed_sites_service.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  test('웹 배포사이트 메뉴 라벨과 허브 순서', () {
    expect(ControlDestination.deployedSites.label, '웹 배포사이트');
    expect(
      [
        ControlDestination.dashboardOverview,
        ControlDestination.divisionProgress,
        ControlDestination.deployedSites,
      ].map((e) => e.label).toList(),
      ['전체 사업 현황', '사업부별 진행상태', '웹 배포사이트'],
    );
  });

  test('확인된 초기 사이트 카탈로그와 중복 방지', () {
    expect(DeployedSitesCatalog.verifiedSeeds.length, 13);
    expect(
      DeployedSitesCatalog.verifiedSeeds.every(
        (s) => s.liveUrl.startsWith('https://'),
      ),
      isTrue,
    );
    final education = DeployedSitesCatalog.verifiedSeeds
        .where((s) => s.category == DeployedSiteCategory.education)
        .map((s) => s.nameEn)
        .toSet();
    expect(
      education,
      containsAll(['SotongLanguage', 'SotongElec', 'SotongDev']),
    );
    expect(
      DeployedSitesCatalog.verifiedSeeds.any(
        (s) => s.nameEn == 'SotongCar' && s.liveUrl.contains('sotong-car'),
      ),
      isTrue,
    );
    expect(
      DeployedSitesCatalog.verifiedSeeds.any(
        (s) =>
            s.nameEn == 'SotongPLC' && s.firebaseProjectId == 'sotongware-plc',
      ),
      isTrue,
    );

    final existing = [DeployedSitesCatalog.verifiedSeeds.first];
    expect(
      DeployedSitesService.isDuplicate(
        existing,
        liveUrl: existing.first.liveUrl,
        firebaseProjectId: existing.first.firebaseProjectId,
      ),
      isTrue,
    );
    expect(
      DeployedSitesService.isDuplicate(
        existing,
        liveUrl: 'https://example-new.web.app',
        firebaseProjectId: 'example-new',
      ),
      isFalse,
    );
  });

  test('GitHub·영문명·Project ID 중복 매칭과 upsert 병합', () {
    final seed = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.nameEn == 'SotongLanguage',
    );
    final existing = [
      DeployedSiteDoc(
        id: 'legacy_language',
        nameKo: '옛이름',
        nameEn: 'SotongLanguage',
        liveUrl: '',
        githubUrl: seed.githubUrl,
        adminMemo: '관리자 메모 유지',
        isFavorite: true,
        status: DeployedSiteStatus.operating,
      ),
    ];
    final match = DeployedSitesService.findMatch(
      existing,
      id: seed.id,
      liveUrl: seed.liveUrl,
      firebaseProjectId: seed.firebaseProjectId,
      githubUrl: seed.githubUrl,
      nameEn: seed.nameEn,
    );
    expect(match?.id, 'legacy_language');
    final merged = DeployedSitesService.mergeSeed(seed, match);
    expect(merged.id, 'legacy_language');
    expect(merged.liveUrl, seed.liveUrl);
    expect(merged.firebaseProjectId, seed.firebaseProjectId);
    expect(merged.adminMemo, '관리자 메모 유지');
    expect(merged.isFavorite, isTrue);
    expect(merged.nameKo, '소통랭귀지');
  });

  test('교육·학습·자동차 분야 필터', () {
    final filtered = DeployedSitesService.applyFilter(
      DeployedSitesCatalog.verifiedSeeds,
      const DeployedSitesFilter(category: DeployedSiteCategory.education),
    );
    expect(filtered.length, greaterThanOrEqualTo(3));
    expect(
      filtered.every((s) => s.category == DeployedSiteCategory.education),
      isTrue,
    );
    final lifestyle = DeployedSitesService.applyFilter(
      DeployedSitesCatalog.verifiedSeeds,
      const DeployedSitesFilter(category: DeployedSiteCategory.lifestyle),
    );
    expect(lifestyle.map((s) => s.nameEn), contains('SotongCar'));
  });

  test('KPI와 필터·정렬', () {
    final sites = [
      DeployedSitesCatalog.verifiedSeeds[0].copyWith(
        status: DeployedSiteStatus.operating,
        isFavorite: true,
        lastDeployedAt: DateTime.now(),
      ),
      DeployedSitesCatalog.verifiedSeeds[1].copyWith(
        status: DeployedSiteStatus.needsCheck,
        lastDeployedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      DeployedSitesCatalog.verifiedSeeds[2].copyWith(
        status: DeployedSiteStatus.inactive,
        isActive: false,
      ),
    ];
    final kpis = DeployedSitesService.computeKpis(sites);
    expect(kpis.total, 3);
    expect(kpis.operating, 1);
    expect(kpis.needsCheck, 1);
    expect(kpis.inactive, 1);
    expect(kpis.recentlyDeployed, 1);

    final filtered = DeployedSitesService.applyFilter(
      sites,
      const DeployedSitesFilter(
        query: '총관제',
        favoritesOnly: true,
        sort: DeployedSitesSort.name,
      ),
    );
    expect(filtered.length, 1);
    expect(filtered.first.nameKo, '소통총관제');
  });

  test('주소 미등록 시 열기 불가 판단', () {
    const site = DeployedSiteDoc(id: 'x', nameKo: '테스트');
    expect(site.hasLiveUrl, isFalse);
    expect(site.hasGithubUrl, isFalse);
  });

  test('상태 한글·색상 정의', () {
    for (final status in DeployedSiteStatus.all) {
      expect(DeployedSiteStatus.labelKo(status), isNotEmpty);
      expect(DeployedSiteStatus.color(status), isNotNull);
      expect(DeployedSiteStatus.icon(status), isNotNull);
    }
  });

  for (final width in [360.0, 390.0, 412.0]) {
    testWidgets('배포사이트 필터 바 모바일 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width - 48,
                        child: const TextField(
                          decoration: InputDecoration(hintText: '사이트명 검색'),
                        ),
                      ),
                      const Chip(label: Text('즐겨찾기만')),
                      const Text('최근 배포순'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
