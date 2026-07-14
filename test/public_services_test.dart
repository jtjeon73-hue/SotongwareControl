import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/core/constants/external_site_links.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';

void main() {
  test('필수 공개 사이트 5개와 산업자동화 포함', () {
    expect(ExternalSiteLinks.requiredSites.length, 5);
    expect(ExternalSiteLinks.requiredSites.map((e) => e.url).toSet(), {
      'https://sotongware-apps-promo.web.app',
      'https://sotongware-ebook-promo.web.app',
      'https://sotongware-contents-promo.web.app',
      'https://sotongware-ai-story.web.app',
      'https://sotongware-marketing.web.app',
    });
    expect(
      ExternalSiteLinks.industrialAutomation.url,
      'https://sotong-automation-promo.web.app',
    );
    expect(ExternalSiteLinks.hubSites.length, 6);
  });

  test('공개 서비스 메뉴 라벨', () {
    expect(ControlDestination.publicServices.label, '공개 서비스');
  });
}
