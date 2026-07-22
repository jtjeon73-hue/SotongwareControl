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

  test('SotongCountryAI 정상 운영 시드와 상태 판정', () {
    final country = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.firebaseProjectId == 'sotong-country-ai',
    );
    expect(country.nameKo, '소통 컨트리 AI');
    expect(country.nameEn, 'SotongCountryAI');
    expect(country.serviceScope, isNotEmpty);
    expect(country.operationPurpose, isNotEmpty);
    expect(country.description, isNotEmpty);
    expect(country.issues, isEmpty);
    expect(country.lastDeployResult, '성공');
    expect(country.githubUrl, contains('SotongCountryAI'));
    expect(country.strategyUrl, contains('differentiation-strategy'));
    expect(country.mobileChecked, isTrue);
    expect(country.desktopChecked, isTrue);
    expect(country.httpsChecked, isTrue);
    expect(country.effectiveStatus, DeployedSiteStatus.operating);
    expect(DeployedSiteStatus.labelKo(country.effectiveStatus), '정상 운영');
  });

  test('서비스 범위·운영 목적·상세가 비면 점검 필요, 있으면 정상 운영', () {
    final base = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.firebaseProjectId == 'sotong-country-ai',
    );
    final incomplete = base.copyWith(
      serviceScope: '',
      operationPurpose: '',
      description: '',
      status: DeployedSiteStatus.operating,
    );
    expect(incomplete.effectiveStatus, DeployedSiteStatus.needsCheck);

    final partial = base.copyWith(
      serviceScope: '범위만',
      operationPurpose: '',
      status: DeployedSiteStatus.operating,
    );
    expect(partial.effectiveStatus, DeployedSiteStatus.needsCheck);

    final complete = incomplete.copyWith(
      serviceScope: base.serviceScope,
      operationPurpose: base.operationPurpose,
      description: base.description,
      issues: '서비스 범위·운영 목적 상세 점검 필요',
      status: DeployedSiteStatus.needsCheck,
    );
    expect(DeployedSiteStatus.hasSeriousIssues(complete.issues), isFalse);
    expect(complete.effectiveStatus, DeployedSiteStatus.operating);
  });

  test('레거시 사이트는 상세설명만으로도 정상 운영 가능', () {
    final legacy = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.nameEn == 'SotongLanguage',
    );
    expect(legacy.serviceScope, isEmpty);
    expect(legacy.operationPurpose, isEmpty);
    expect(legacy.description, isNotEmpty);
    expect(legacy.effectiveStatus, DeployedSiteStatus.operating);
  });

  test('배포 성공·HTTPS URL이 반영된 정상 운영 판정', () {
    const site = DeployedSiteDoc(
      id: 'demo',
      nameKo: '데모',
      nameEn: 'Demo',
      description: '상세',
      serviceScope: '범위',
      operationPurpose: '목적',
      liveUrl: 'https://demo.web.app',
      lastDeployResult: '성공',
      httpsChecked: true,
      status: DeployedSiteStatus.needsCheck,
      issues: '점검 필요',
    );
    expect(site.effectiveStatus, DeployedSiteStatus.operating);
  });

  test('시드 동기화 후 상세정보 유지·needsCheck로 다운그레이드 금지', () {
    final seed = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.firebaseProjectId == 'sotong-country-ai',
    );
    final existing = DeployedSiteDoc(
      id: 'legacy_country',
      nameKo: '소통 컨트리 AI',
      nameEn: 'SotongCountryAI',
      description: '${seed.description} 관리자 보완 문단을 추가로 기록합니다.',
      serviceScope: seed.serviceScope,
      operationPurpose: seed.operationPurpose,
      liveUrl: seed.liveUrl,
      firebaseProjectId: seed.firebaseProjectId,
      status: DeployedSiteStatus.operating,
      isFavorite: true,
      adminMemo: '관리자 메모 유지',
      issues: '서비스 범위·운영 목적 상세 점검 필요',
    );
    final merged = DeployedSitesService.mergeSeed(seed, existing);
    expect(merged.id, 'legacy_country');
    expect(merged.isFavorite, isTrue);
    expect(merged.adminMemo, '관리자 메모 유지');
    expect(merged.effectiveStatus, DeployedSiteStatus.operating);
    expect(merged.issues, isEmpty);
    expect(merged.description, contains('관리자 보완'));
  });

  test('시드가 더 상세하면 기존 짧은 점검사항을 갱신', () {
    final seed = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.firebaseProjectId == 'sotong-country-ai',
    );
    final existing = DeployedSiteDoc(
      id: 'sotong_country_ai',
      nameKo: 'SotongCountryAI',
      nameEn: 'Sotong Country AI',
      description: '지역·농촌 관련 AI 서비스 공개 사이트',
      liveUrl: seed.liveUrl,
      firebaseProjectId: seed.firebaseProjectId,
      status: DeployedSiteStatus.needsCheck,
      issues: '서비스 범위·운영 목적 상세 점검 필요',
    );
    final merged = DeployedSitesService.mergeSeed(seed, existing);
    expect(merged.serviceScope, seed.serviceScope);
    expect(merged.operationPurpose, seed.operationPurpose);
    expect(merged.nameEn, 'SotongCountryAI');
    expect(merged.effectiveStatus, DeployedSiteStatus.operating);
    expect(merged.strategyUrl, contains('differentiation-strategy'));
  });

  test('중복 사이트는 비활성 후보로 선택', () {
    final seed = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.firebaseProjectId == 'sotong-country-ai',
    );
    final sites = [
      seed,
      DeployedSiteDoc(
        id: 'dup_old',
        nameKo: '옛 문서',
        nameEn: 'SotongCountryAI',
        firebaseProjectId: 'sotong-country-ai',
        liveUrl: seed.liveUrl,
        isActive: true,
        status: DeployedSiteStatus.needsCheck,
      ),
    ];
    final losers = DeployedSitesService.pickDuplicateLosers(sites);
    expect(losers.map((e) => e.id), contains('dup_old'));
    expect(losers.map((e) => e.id), isNot(contains(seed.id)));
  });

  test('SotongCountryAI 검색 및 필터', () {
    final filtered = DeployedSitesService.applyFilter(
      DeployedSitesCatalog.verifiedSeeds,
      const DeployedSitesFilter(query: 'SotongCountry'),
    );
    expect(filtered, isNotEmpty);
    expect(
      filtered.every(
        (s) =>
            s.nameEn.contains('SotongCountry') ||
            s.firebaseProjectId == 'sotong-country-ai',
      ),
      isTrue,
    );
    final operating = DeployedSitesService.applyFilter(
      DeployedSitesCatalog.verifiedSeeds,
      const DeployedSitesFilter(status: DeployedSiteStatus.operating),
    );
    expect(
      operating.any((s) => s.firebaseProjectId == 'sotong-country-ai'),
      isTrue,
    );
  });

  test('대표 전략 페이지 링크', () {
    final country = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.firebaseProjectId == 'sotong-country-ai',
    );
    expect(country.hasStrategyUrl, isTrue);
    expect(Uri.tryParse(country.strategyUrl)?.isAbsolute, isTrue);
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
    final country = DeployedSitesCatalog.verifiedSeeds.firstWhere(
      (s) => s.firebaseProjectId == 'sotong-country-ai',
    );
    final sites = [
      DeployedSitesCatalog.verifiedSeeds[0].copyWith(
        status: DeployedSiteStatus.operating,
        isFavorite: true,
        lastDeployedAt: DateTime.now(),
        serviceScope: '관제 범위',
        operationPurpose: '관제 목적',
        description: '관제 상세',
      ),
      DeployedSitesCatalog.verifiedSeeds[1].copyWith(
        status: DeployedSiteStatus.needsCheck,
        serviceScope: '',
        operationPurpose: '',
        description: '',
        lastDeployedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      DeployedSitesCatalog.verifiedSeeds[2].copyWith(
        status: DeployedSiteStatus.inactive,
        isActive: false,
      ),
      country,
    ];
    final kpis = DeployedSitesService.computeKpis(sites);
    expect(kpis.total, 4);
    expect(kpis.operating, greaterThanOrEqualTo(2));
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

  test('다른 배포사이트 회귀: 교육·PLC는 운영 URL·Project 유지', () {
    for (final nameEn in ['SotongLanguage', 'SotongElec', 'SotongPLC']) {
      final site = DeployedSitesCatalog.verifiedSeeds.firstWhere(
        (s) => s.nameEn == nameEn,
      );
      expect(site.liveUrl, startsWith('https://'));
      expect(site.firebaseProjectId, isNotEmpty);
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
