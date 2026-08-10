import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/idea_bank.dart';

class IdeaBankStore {
  static const storageKey = 'idea_bank_v1';

  Future<List<IdeaBankItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => IdeaBankItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveAll(List<IdeaBankItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsert(IdeaBankItem item) async {
    final items = await load();
    final i = items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      items[i] = item;
    } else {
      items.insert(0, item);
    }
    await saveAll(items);
  }

  Future<void> delete(String id) async {
    final items = await load();
    items.removeWhere((e) => e.id == id);
    await saveAll(items);
  }

  static String newId([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return 'idea_$t';
  }
}
