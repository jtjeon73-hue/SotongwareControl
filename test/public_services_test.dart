import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/core/constants/external_site_links.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  test('필수 공개 사이트에 지식·교육 매니저 포함', () {
    expect(ExternalSiteLinks.requiredSites.length, 6);
    expect(ExternalSiteLinks.requiredSites.map((e) => e.url).toSet(), {
      'https://sotongware-apps-promo.web.app',
      'https://sotongware-ebook-promo.web.app',
      'https://sotongware-contents-promo.web.app',
      'https://sotongware-ai-story.web.app',
      'https://sotongware-marketing.web.app',
      'https://sotongsitemanager.web.app',
    });
    expect(
      ExternalSiteLinks.industrialAutomation.url,
      'https://sotong-automation-promo.web.app',
    );
    expect(
      ExternalSiteLinks.siteManager.url,
      'https://sotongsitemanager.web.app',
    );
    expect(ExternalSiteLinks.siteManager.title, contains('지식·교육'));
    expect(ExternalSiteLinks.coreBusinessSites.length, 6);
    expect(ExternalSiteLinks.hubSites.length, 7);
    expect(
      ExternalSiteLinks.hubSites.where((e) => e.id == 'site_manager').length,
      1,
    );
  });

  test('공개 서비스 메뉴 라벨', () {
    expect(ControlDestination.publicServices.label, '공개 서비스');
  });
}
