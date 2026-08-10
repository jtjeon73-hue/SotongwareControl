import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/data/business_departments/business_department_catalog.dart';
import 'package:sotong_ware_control/models/idea_bank.dart';
import 'package:sotong_ware_control/services/idea_bank_store.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('canonical 메뉴는 15개이며 지정 순서·라벨을 따른다', () {
    final menus = SidebarNavigation.canonicalDestinations;
    expect(menus.length, 15);
    expect(menus.map((e) => e.label).toList(), [
      '산업자동화SW개발부',
      '전자책 개발부',
      '앱 개발부',
      '지식사이트 개발부',
      '마케팅사이트 개발부',
      '컨텐츠 개발부',
      '작업지시 제작소',
      '제품제작 공작실',
      '자동 홍보 전략실',
      '자동판매전략실',
      '수익세금 자동 재무실',
      '시스템 설정',
      '알람센터',
      '사업 전략연구실',
      '뉴 아이디어 뱅크',
    ]);
  });

  test('작업지시 제작소 라벨은 aiBusinessAnalysis에 매핑된다', () {
    expect(ControlDestination.aiBusinessAnalysis.label, '작업지시 제작소');
  });

  test('6개 사업부 config가 로드되고 필수 섹션을 가진다', () {
    expect(BusinessDepartmentCatalog.all.length, 6);
    for (final c in BusinessDepartmentCatalog.all) {
      expect(c.title, isNotEmpty);
      expect(c.linkedSites, isNotEmpty);
      expect(c.knowledge, isNotEmpty);
      expect(c.trends.coreTech, isNotEmpty);
      expect(c.sales.customerGroups, isNotEmpty);
      expect(c.revenue.items, isNotEmpty);
    }
  });

  test('Idea Bank 저장·검색·년월 필터', () async {
    final store = IdeaBankStore();
    final now = DateTime.utc(2026, 3, 10);
    final a = IdeaBankItem(
      id: 'idea_a',
      title: 'AI 전자책 아이디어',
      targetCustomer: '귀촌 준비자',
      product: 'ebook',
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      year: 2026,
      month: 3,
      favorite: true,
    );
    final b = IdeaBankItem(
      id: 'idea_b',
      title: '쇼츠 채널',
      product: 'contents',
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      year: 2026,
      month: 1,
    );
    await store.saveAll([a, b]);
    final loaded = await store.load();
    expect(loaded.length, 2);
    expect(loaded.where((e) => e.year == 2026 && e.month == 3).length, 1);
    expect(
      loaded.where((e) => e.title.contains('전자책')).single.favorite,
      isTrue,
    );
  });

  test('IdeaToPlanningSeed는 제목·고객을 전달한다', () {
    const seed = IdeaToPlanningSeed(
      title: '테스트 아이디어',
      targetCustomer: '고객A',
      memo: '메모',
    );
    expect(seed.title, '테스트 아이디어');
    expect(seed.targetCustomer, '고객A');
  });
}
