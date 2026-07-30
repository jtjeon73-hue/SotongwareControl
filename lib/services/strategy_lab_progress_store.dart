import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Read status for strategy articles: unread | reading | reviewed
class StrategyLabProgressStore {
  static const statusKey = 'strategy_lab_status_v1';
  static const favoritesKey = 'strategy_lab_favorites_v1';
  static const memoKey = 'strategy_lab_memo_v1';
  static const applyKey = 'strategy_lab_apply_v1';
  static const actionsKey = 'strategy_lab_actions_v1';

  static String actionEntryKey(String articleId, int index) =>
      '$articleId|$index';

  Future<Map<String, String>> loadStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(statusKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveStatuses(Map<String, String> statuses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(statusKey, jsonEncode(statuses));
  }

  Future<void> setStatus(String articleId, String status) async {
    final statuses = await loadStatuses();
    statuses[articleId] = status;
    await saveStatuses(statuses);
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(favoritesKey)?.toSet() ?? {};
  }

  Future<void> saveFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(favoritesKey, favorites.toList());
  }

  Future<void> toggleFavorite(String articleId) async {
    final favorites = await loadFavorites();
    if (!favorites.add(articleId)) favorites.remove(articleId);
    await saveFavorites(favorites);
  }

  Future<Map<String, String>> loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(memoKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveMemo(String articleId, String memo) async {
    final memos = await loadMemos();
    if (memo.trim().isEmpty) {
      memos.remove(articleId);
    } else {
      memos[articleId] = memo;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(memoKey, jsonEncode(memos));
  }

  Future<Map<String, String>> loadApplyNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(applyKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveApplyNote(String articleId, String note) async {
    final notes = await loadApplyNotes();
    if (note.trim().isEmpty) {
      notes.remove(articleId);
    } else {
      notes[articleId] = note;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(applyKey, jsonEncode(notes));
  }

  Future<Map<String, bool>> loadActionChecks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(actionsKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as bool));
  }

  Future<void> saveActionCheck(
    String articleId,
    int index,
    bool checked,
  ) async {
    final checks = await loadActionChecks();
    final key = actionEntryKey(articleId, index);
    if (checked) {
      checks[key] = true;
    } else {
      checks.remove(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(actionsKey, jsonEncode(checks));
  }
}
