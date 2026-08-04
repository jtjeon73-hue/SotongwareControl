import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/portfolio_models.dart';

/// 제작 포트폴리오 로컬 저장 (SharedPreferences + JSON).
class PortfolioStore {
  static const itemsKey = 'portfolio_items_v1';
  static const goalsKey = 'portfolio_goals_v1';
  static const bundlesKey = 'portfolio_theme_bundles_v1';

  Future<List<PortfolioItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(itemsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final items = list
        .map((e) => PortfolioItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final deduped = dedupeById(items);
    if (deduped.length != items.length) {
      await saveItems(deduped);
    }
    return deduped;
  }

  Future<void> saveItems(List<PortfolioItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      itemsKey,
      jsonEncode(dedupeById(items).map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsertItem(PortfolioItem item) async {
    final items = await loadItems();
    final index = items.indexWhere((p) => p.id == item.id);
    if (index >= 0) {
      items[index] = item;
    } else {
      items.insert(0, item);
    }
    await saveItems(items);
  }

  Future<void> deleteItem(String id) async {
    final items = await loadItems();
    items.removeWhere((p) => p.id == id);
    await saveItems(items);
  }

  Future<PortfolioArtifactGoals> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(goalsKey);
    if (raw == null || raw.isEmpty) {
      return const PortfolioArtifactGoals(
        targets: PortfolioArtifactGoals.defaultTargets,
      );
    }
    return PortfolioArtifactGoals.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> saveGoals(PortfolioArtifactGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(goalsKey, jsonEncode(goals.toJson()));
  }

  Future<List<ThemeBundle>> loadBundles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(bundlesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ThemeBundle.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveBundles(List<ThemeBundle> bundles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      bundlesKey,
      jsonEncode(bundles.map((e) => e.toJson()).toList()),
    );
  }

  /// 동일 id가 여러 번 있으면 최신 updatedAt 1건만 남긴다.
  static List<PortfolioItem> dedupeById(List<PortfolioItem> items) {
    final byId = <String, PortfolioItem>{};
    for (final item in items) {
      final existing = byId[item.id];
      if (existing == null ||
          item.updatedAt.compareTo(existing.updatedAt) >= 0) {
        byId[item.id] = item;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static String newItemId([DateTime? now]) {
    final stamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return 'pf_$stamp';
  }

  static List<PortfolioItem> filterItems(
    List<PortfolioItem> items, {
    String search = '',
    String? artifact,
    String? status,
    String? category,
  }) {
    final q = search.trim().toLowerCase();
    return items.where((item) {
      if (artifact != null &&
          artifact.isNotEmpty &&
          ArtifactType.normalize(item.artifactType) !=
              ArtifactType.normalize(artifact)) {
        return false;
      }
      if (status != null &&
          status.isNotEmpty &&
          PortfolioStatus.normalize(item.status) !=
              PortfolioStatus.normalize(status)) {
        return false;
      }
      if (category != null &&
          category.isNotEmpty &&
          item.topicCategory != category) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = [
        item.title,
        item.oneLiner,
        item.topicCategory,
        item.topicReason,
        item.targetUsers,
        item.problem,
        item.notes,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  static List<PortfolioItem> sortItems(
    List<PortfolioItem> items, {
    PortfolioSortField field = PortfolioSortField.updatedAt,
    bool descending = true,
  }) {
    final sorted = List<PortfolioItem>.from(items);
    int compare(PortfolioItem a, PortfolioItem b) {
      switch (field) {
        case PortfolioSortField.updatedAt:
          return a.updatedAt.compareTo(b.updatedAt);
        case PortfolioSortField.score:
          final sa = a.recommendedTotalScore;
          final sb = b.recommendedTotalScore;
          return sa.compareTo(sb);
        case PortfolioSortField.status:
          final ia = PortfolioStatus.all.indexOf(
            PortfolioStatus.normalize(a.status),
          );
          final ib = PortfolioStatus.all.indexOf(
            PortfolioStatus.normalize(b.status),
          );
          return ia.compareTo(ib);
        case PortfolioSortField.priority:
          return a.priority.compareTo(b.priority);
      }
    }

    sorted.sort(compare);
    if (descending) {
      return sorted.reversed.toList();
    }
    return sorted;
  }

  static List<String> distinctCategories(List<PortfolioItem> items) {
    final set = <String>{};
    for (final item in items) {
      if (item.topicCategory.isNotEmpty) set.add(item.topicCategory);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 0-based page index.
  static List<T> page<T>(List<T> items, int pageIndex, int pageSize) {
    if (pageSize <= 0 || items.isEmpty) return [];
    final start = pageIndex * pageSize;
    if (start >= items.length) return [];
    final end = (start + pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  static int pageCount(int itemCount, int pageSize) {
    if (pageSize <= 0 || itemCount <= 0) return 0;
    return (itemCount / pageSize).ceil();
  }
}

enum PortfolioSortField { updatedAt, score, status, priority }
