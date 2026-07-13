import '../models/ops_enums.dart';
import '../models/ops_models.dart';

/// 확인된 주소·존재가 있는 프로젝트만 카탈로그에 포함.
class KnownProjectSpec {
  const KnownProjectSpec({
    required this.id,
    required this.businessUnitId,
    required this.name,
    required this.projectType,
    this.description = '',
    this.repositoryUrl = '',
    this.websiteUrl = '',
    this.firebaseUrl = '',
    this.promoUrl = '',
    this.group = '',
  });

  final String id;
  final String businessUnitId;
  final String name;
  final String projectType;
  final String description;
  final String repositoryUrl;
  final String websiteUrl;
  final String firebaseUrl;
  final String promoUrl;
  final String group;

  ProjectDoc toProjectDoc() => ProjectDoc(
    id: id,
    businessUnitId: businessUnitId,
    name: name,
    description: description,
    projectType: projectType,
    status: ProjectStatus.notStarted,
    currentStage: '확인 필요',
    nextAction: '실제 상태 확인',
    repositoryUrl: repositoryUrl,
    websiteUrl: websiteUrl,
    firebaseUrl: firebaseUrl,
    promoUrl: promoUrl,
  );
}

class KnownProjectsCatalog {
  KnownProjectsCatalog._();

  static const all = <KnownProjectSpec>[
    KnownProjectSpec(
      id: 'control_center',
      businessUnitId: 'app_development',
      name: '소통총관제',
      projectType: 'flutter_web',
      group: '주요 운영',
      description: '소통웨어 전체 사업 운영 관제 (본 사이트)',
      repositoryUrl: 'https://github.com/jtjeon73-hue/SotongwareControl',
      firebaseUrl: 'https://sotongware-control.web.app',
      websiteUrl: 'https://sotongware-control.web.app',
    ),
    KnownProjectSpec(
      id: 'sotong24work_hub',
      businessUnitId: 'sotong24work',
      name: '소통24워크',
      projectType: 'mfc_tool',
      group: '주요 운영',
      description: 'MFC 기반 자동화 개발·유지관리 내부 프로그램',
    ),
    KnownProjectSpec(
      id: 'app_sotong_samae',
      businessUnitId: 'app_development',
      name: '소통사매',
      projectType: 'flutter_app',
      group: '앱개발사업부',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongSamaePromo/',
    ),
    KnownProjectSpec(
      id: 'app_farmjigi',
      businessUnitId: 'app_development',
      name: '팜지기',
      projectType: 'flutter_app',
      group: '앱개발사업부',
      promoUrl: 'https://jtjeon73-hue.github.io/FarmjigiPromo/',
    ),
    KnownProjectSpec(
      id: 'app_sotong_ai',
      businessUnitId: 'app_development',
      name: '소통AI',
      projectType: 'flutter_app',
      group: '앱개발사업부',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongAIPromo/',
    ),
    KnownProjectSpec(
      id: 'app_sotong_energy',
      businessUnitId: 'app_development',
      name: '소통에너지',
      projectType: 'flutter_app',
      group: '앱개발사업부',
    ),
    KnownProjectSpec(
      id: 'app_sotong_travel',
      businessUnitId: 'app_development',
      name: '소통여행',
      projectType: 'flutter_app',
      group: '앱개발사업부',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongTravelPromo/',
    ),
    KnownProjectSpec(
      id: 'app_sotong_saju',
      businessUnitId: 'app_development',
      name: '소통사주',
      projectType: 'flutter_app',
      group: '앱개발사업부',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongSajuPromo/',
    ),
    KnownProjectSpec(
      id: 'promo_industrial',
      businessUnitId: 'industrial_automation',
      name: '산업자동화 총괄 프로모',
      projectType: 'promo_site',
      group: '사업부 총괄 프로모',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongAutomationPromo/',
      websiteUrl: 'https://jtjeon73-hue.github.io/SotongAutomationPromo/',
    ),
    KnownProjectSpec(
      id: 'promo_apps',
      businessUnitId: 'app_development',
      name: '앱개발 총괄 프로모',
      projectType: 'promo_site',
      group: '사업부 총괄 프로모',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongAppsPromo/',
      websiteUrl: 'https://jtjeon73-hue.github.io/SotongAppsPromo/',
    ),
    KnownProjectSpec(
      id: 'promo_contents',
      businessUnitId: 'content_music',
      name: '콘텐츠 총괄 프로모',
      projectType: 'promo_site',
      group: '사업부 총괄 프로모',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongContentsPromo/',
      websiteUrl: 'https://jtjeon73-hue.github.io/SotongContentsPromo/',
    ),
    KnownProjectSpec(
      id: 'promo_ebook',
      businessUnitId: 'ebook',
      name: '전자책 총괄 프로모',
      projectType: 'promo_site',
      group: '사업부 총괄 프로모',
      promoUrl: 'https://jtjeon73-hue.github.io/SotongEbookPromo/',
      websiteUrl: 'https://jtjeon73-hue.github.io/SotongEbookPromo/',
    ),
    KnownProjectSpec(
      id: 'sotong24_app_auto',
      businessUnitId: 'sotong24work',
      name: '앱개발자동화',
      projectType: 'sotong24_module',
      group: '소통24워크 모듈',
    ),
    KnownProjectSpec(
      id: 'sotong24_ebook_auto',
      businessUnitId: 'sotong24work',
      name: '전자책개발자동화',
      projectType: 'sotong24_module',
      group: '소통24워크 모듈',
    ),
    KnownProjectSpec(
      id: 'sotong24_marketing_auto',
      businessUnitId: 'sotong24work',
      name: '마케팅개발자동화',
      projectType: 'sotong24_module',
      group: '소통24워크 모듈',
    ),
    KnownProjectSpec(
      id: 'sotong24_youtube_auto',
      businessUnitId: 'sotong24work',
      name: '유튜브개발자동화',
      projectType: 'sotong24_module',
      group: '소통24워크 모듈',
    ),
    KnownProjectSpec(
      id: 'sotong24_mfc_auto',
      businessUnitId: 'sotong24work',
      name: 'MFC개발자동화',
      projectType: 'sotong24_module',
      group: '소통24워크 모듈',
    ),
  ];
}
