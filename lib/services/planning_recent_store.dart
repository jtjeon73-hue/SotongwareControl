import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planning_wizard_state.dart';

/// 선택형 기획 도우미 최근·빈도·템플릿 저장.
/// `business_planning_plans_v1` 구조는 변경하지 않는다.
class PlanningRecentStore {
  static const recentDomainsKey = 'planning_recent_domains_v1';
  static const recentAudiencesKey = 'planning_recent_audiences_v1';
  static const domainCountsKey = 'planning_domain_counts_v1';
  static const audienceCountsKey = 'planning_audience_counts_v1';
  static const userTemplatesKey = 'planning_user_templates_v1';

  static const maxRecentItems = 8;
  static const maxTemplates = 20;

  Future<List<String>> loadRecentDomains() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(recentDomainsKey) ?? [];
  }

  Future<List<String>> loadRecentAudiences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(recentAudiencesKey) ?? [];
  }

  Future<Map<String, int>> loadDomainCounts() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeCounts(prefs.getString(domainCountsKey));
  }

  Future<Map<String, int>> loadAudienceCounts() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeCounts(prefs.getString(audienceCountsKey));
  }

  /// 최근 사용 id를 앞에 추가하고, 빈도 카운트를 갱신한다.
  Future<void> recordDomainSelections(Iterable<String> ids) async {
    await _recordSelections(
      ids: ids,
      recentKey: recentDomainsKey,
      countsKey: domainCountsKey,
      loader: loadRecentDomains,
    );
  }

  Future<void> recordAudienceSelections(Iterable<String> ids) async {
    await _recordSelections(
      ids: ids,
      recentKey: recentAudiencesKey,
      countsKey: audienceCountsKey,
      loader: loadRecentAudiences,
    );
  }

  Future<void> _recordSelections({
    required Iterable<String> ids,
    required String recentKey,
    required String countsKey,
    required Future<List<String>> Function() loader,
  }) async {
    final filtered = ids
        .where((id) => id.isNotEmpty && id != 'custom')
        .toList();
    if (filtered.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final recent = await loader();
    final counts = _decodeCounts(prefs.getString(countsKey));

    for (final id in filtered.reversed) {
      recent.remove(id);
      recent.insert(0, id);
      counts[id] = (counts[id] ?? 0) + 1;
    }

    while (recent.length > maxRecentItems) {
      recent.removeLast();
    }

    await prefs.setStringList(recentKey, recent);
    await prefs.setString(countsKey, jsonEncode(counts));
  }

  /// 자주 선택한 id (빈도 내림차순).
  Future<List<String>> frequentDomains({int limit = 5}) async {
    final counts = await loadDomainCounts();
    return _sortedByCount(counts, limit);
  }

  Future<List<String>> frequentAudiences({int limit = 5}) async {
    final counts = await loadAudienceCounts();
    return _sortedByCount(counts, limit);
  }

  Future<List<PlanningWizardState>> loadUserTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(userTemplatesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map(
          (e) =>
              PlanningWizardState.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> saveUserTemplates(List<PlanningWizardState> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = templates.take(maxTemplates).toList();
    await prefs.setString(
      userTemplatesKey,
      jsonEncode(trimmed.map((t) => t.toJson()).toList()),
    );
  }

  /// 나의 기획 템플릿 추가 (앞에 삽입).
  Future<void> addUserTemplate(PlanningWizardState template, {String? title}) {
    final copy = template.deepCopy();
    if (title != null && title.trim().isNotEmpty) {
      copy.customTexts = {...copy.customTexts, 'templateTitle': title.trim()};
    }
    return _upsertTemplate(copy);
  }

  Future<void> removeUserTemplateAt(int index) async {
    final templates = await loadUserTemplates();
    if (index < 0 || index >= templates.length) return;
    templates.removeAt(index);
    await saveUserTemplates(templates);
  }

  Future<void> _upsertTemplate(PlanningWizardState template) async {
    final templates = await loadUserTemplates();
    templates.insert(0, template);
    await saveUserTemplates(templates);
  }

  static Map<String, int> _decodeCounts(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  static List<String> _sortedByCount(Map<String, int> counts, int limit) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }
}
