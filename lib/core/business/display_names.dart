import 'business_catalog.dart';
import '../../data/known_projects_catalog.dart';

/// 내부 ID → 사용자 화면용 한글 표시명.
class DisplayNames {
  DisplayNames._();

  static const _projectNames = <String, String>{
    'control_center': '소통총관제',
    'sotongware_control': '소통총관제',
    'sotong24work': '소통24워크',
    'sotong24work_hub': '소통24워크',
    'sotong_site_manager': '소통사이트매니저',
    'sotongsitemanager': '소통사이트매니저',
  };

  static String project(String id, {String? fallbackName}) {
    final key = id.trim();
    if (key.isEmpty) {
      return fallbackName?.trim().isNotEmpty == true
          ? fallbackName!.trim()
          : '미지정 프로젝트';
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName.trim();
    }
    final mapped = _projectNames[key];
    if (mapped != null) return mapped;
    for (final known in KnownProjectsCatalog.all) {
      if (known.id == key) return known.name;
    }
    final business = BusinessCatalog.byId(key);
    if (business != null) return business.name;
    return key;
  }

  static String businessUnit(String id) {
    return BusinessCatalog.byId(id)?.name ??
        (id.trim().isEmpty ? '미지정 사업부' : id.trim());
  }

  /// 메시지 안의 내부 프로젝트 ID를 한글 표시명으로 치환한다.
  static String replaceIdsInMessage(String message) {
    var result = message;
    final pairs = <MapEntry<String, String>>[
      ..._projectNames.entries,
      ...KnownProjectsCatalog.all.map((k) => MapEntry(k.id, k.name)),
    ];
    // 긴 ID부터 치환해 부분 충돌을 줄인다.
    pairs.sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in pairs) {
      if (entry.key.isEmpty) continue;
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
