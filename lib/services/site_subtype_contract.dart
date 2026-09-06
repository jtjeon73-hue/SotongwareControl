/// Control UI siteSubtype ↔ Sotong24Work BusinessTypeCanonical site subtypes.
///
/// Canonical tokens (disjoint from content subtypes):
/// corporate_site | marketing_site | knowledge_site | education_site |
/// information_portal
library;

class SiteSubtypeContract {
  SiteSubtypeContract._();

  static const corporateSite = 'corporate_site';
  static const marketingSite = 'marketing_site';
  static const knowledgeSite = 'knowledge_site';
  static const educationSite = 'education_site';
  static const informationPortal = 'information_portal';

  /// Selectable studio site kinds (single-choice).
  static const allSelectable = <String>[
    corporateSite,
    marketingSite,
    knowledgeSite,
    educationSite,
    informationPortal,
  ];

  static const knownWorkSubtypes = <String>{
    corporateSite,
    marketingSite,
    knowledgeSite,
    educationSite,
    informationPortal,
  };

  static bool isKnown(String? raw) {
    final s = (raw ?? '').trim();
    return s.isNotEmpty && knownWorkSubtypes.contains(s);
  }

  /// Canonical token or empty. Never invents a default subtype.
  static String normalizeOrEmpty(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    // Legacy aliases that must map to marketing_site (not corporate).
    switch (s) {
      case 'promo_site':
      case 'web_marketing':
      case 'marketing':
        return marketingSite;
      default:
        return isKnown(s) ? s : '';
    }
  }

  /// Require a known subtype for new commercial site work.
  static String requireKnown(String? raw) {
    final n = normalizeOrEmpty(raw);
    if (n.isEmpty) {
      throw ArgumentError('siteSubtype is required');
    }
    return n;
  }

  static String labelKo(String id) {
    switch (normalizeOrEmpty(id)) {
      case corporateSite:
        return '기업·기관 홈페이지';
      case marketingSite:
        return '홍보·마케팅 사이트';
      case knowledgeSite:
        return '지식·정보 사이트';
      case educationSite:
        return '교육·학습 사이트';
      case informationPortal:
        return '분야별 정보 포털';
      default:
        return id;
    }
  }
}
