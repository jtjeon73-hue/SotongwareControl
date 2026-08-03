import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_planning.dart';

/// 사업 기획안·작업지시서 로컬 저장 (SharedPreferences).
/// Firestore/유료 API를 사용하지 않는다.
class BusinessPlanningStore {
  static const plansKey = 'business_planning_plans_v1';
  static const draftInputKey = 'business_planning_draft_input_v1';

  Future<List<BusinessPlanDocument>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(plansKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map(
          (e) => BusinessPlanDocument.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> savePlans(List<BusinessPlanDocument> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      plansKey,
      jsonEncode(plans.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsertPlan(BusinessPlanDocument plan) async {
    final plans = await loadPlans();
    final index = plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.insert(0, plan);
    }
    await savePlans(plans);
  }

  Future<void> deletePlan(String id) async {
    final plans = await loadPlans();
    plans.removeWhere((p) => p.id == id);
    await savePlans(plans);
  }

  Future<BusinessPlanInput?> loadDraftInput() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftInputKey);
    if (raw == null || raw.isEmpty) return null;
    return BusinessPlanInput.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> saveDraftInput(BusinessPlanInput input) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(draftInputKey, jsonEncode(input.toJson()));
  }

  static String newPlanId([DateTime? now]) {
    final stamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return 'plan_$stamp';
  }
}
