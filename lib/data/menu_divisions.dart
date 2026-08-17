import '../widgets/sidebar_navigation.dart';

/// 좌측 메뉴 5개 업무 부문 (표시용). destination enum/key는 변경하지 않는다.
class MenuDivision {
  const MenuDivision({
    required this.id,
    required this.title,
    required this.destinations,
  });

  final String id;
  final String title;
  final List<ControlDestination> destinations;

  bool contains(ControlDestination d) => destinations.contains(d);
}

class MenuDivisionCatalog {
  MenuDivisionCatalog._();

  static const planningExecution = MenuDivision(
    id: 'planning_execution',
    title: '운영 관제',
    destinations: [
      ControlDestination.aiBusinessAnalysis,
      ControlDestination.productWorkshop,
      ControlDestination.sotong24RemoteControl,
      ControlDestination.standardProductionGuide,
    ],
  );

  static const development = MenuDivision(
    id: 'development',
    title: '개발부',
    destinations: [
      ControlDestination.industrialAutomation,
      ControlDestination.ebook,
      ControlDestination.appDevelopment,
      ControlDestination.siteManager,
      ControlDestination.webMarketing,
      ControlDestination.youtubeContent,
    ],
  );

  static const marketingFinance = MenuDivision(
    id: 'marketing_finance',
    title: '마케팅재무부',
    destinations: [
      ControlDestination.autoPromotion,
      ControlDestination.autoSales,
      ControlDestination.autoFinance,
    ],
  );

  static const settings = MenuDivision(
    id: 'settings',
    title: '설정부',
    destinations: [
      ControlDestination.systemSettings,
      ControlDestination.alertCenter,
    ],
  );

  static const strategy = MenuDivision(
    id: 'strategy',
    title: '사업전략부',
    destinations: [
      ControlDestination.businessStudy,
      ControlDestination.ideaBank,
    ],
  );

  static const all = <MenuDivision>[
    planningExecution,
    development,
    marketingFinance,
    settings,
    strategy,
  ];

  /// 부문 순서를 펼친 canonical 목록 (기존 flat API 호환).
  static List<ControlDestination> get flattenedDestinations => [
    for (final d in all) ...d.destinations,
  ];

  static MenuDivision? divisionOf(ControlDestination destination) {
    for (final d in all) {
      if (d.contains(destination)) return d;
    }
    return null;
  }
}
