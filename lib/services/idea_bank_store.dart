import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/idea_bank_seed.dart';
import '../models/idea_bank.dart';

class IdeaBankStore {
  static const storageKey = 'idea_bank_v1';

  Future<List<IdeaBankItem>> load({bool includeSeeds = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final user = <IdeaBankItem>[];
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      user.addAll(
        list.map(
          (e) => IdeaBankItem.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    }
    if (!includeSeeds) {
      return user..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    final ids = user.map((e) => e.id).toSet();
    final merged = [
      ...user,
      for (final s in IdeaBankSeedCatalog.seeds())
        if (!ids.contains(s.id)) s,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return merged;
  }

  Future<void> saveAll(List<IdeaBankItem> items) async {
    // 시드는 SharedPreferences에 강제 저장하지 않음 (사용자가 수정한 항목만 저장).
    final toSave = items.where((e) => !e.isSeed).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(toSave.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsert(IdeaBankItem item) async {
    final items = await load(includeSeeds: false);
    final saved = item.isSeed ? item.copyWith(isSeed: false) : item;
    // copyWith doesn't clear isSeed to false easily if we need force - add flag
    final persisted = IdeaBankItem(
      id: saved.id,
      title: saved.title,
      oneLiner: saved.oneLiner,
      targetCustomer: saved.targetCustomer,
      product: saved.product,
      aiUse: saved.aiUse,
      revenueMethod: saved.revenueMethod,
      difficulty: saved.difficulty,
      initialCost: saved.initialCost,
      automationPotential: saved.automationPotential,
      recommendReason: saved.recommendReason,
      status: saved.status,
      memo: saved.memo,
      createdAt: saved.createdAt,
      updatedAt: saved.updatedAt,
      year: saved.year,
      month: saved.month,
      favorite: saved.favorite,
      category: saved.category,
      whyNow: saved.whyNow,
      howToBusiness: saved.howToBusiness,
      businessUnits: saved.businessUnits,
      estimatedScale: saved.estimatedScale,
      infoAsOf: saved.infoAsOf,
      lastCheckedAt: saved.lastCheckedAt,
      isSeed: false,
      sources: saved.sources,
      scoreTrend: saved.scoreTrend,
      scoreMarket: saved.scoreMarket,
      scoreFit: saved.scoreFit,
    );
    final i = items.indexWhere((e) => e.id == persisted.id);
    if (i >= 0) {
      items[i] = persisted;
    } else {
      items.insert(0, persisted);
    }
    await saveAll(items);
  }

  Future<void> delete(String id) async {
    final items = await load(includeSeeds: false);
    items.removeWhere((e) => e.id == id);
    await saveAll(items);
  }

  static String newId([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return 'idea_$t';
  }
}
