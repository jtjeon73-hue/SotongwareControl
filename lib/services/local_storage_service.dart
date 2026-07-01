import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/action_item.dart';
import '../models/business_issue.dart';
import '../models/finance_input.dart';

class LocalStorageService {
  static const actionsKey = 'swc_action_items_v2';
  static const issuesKey = 'swc_business_issues_v2';
  static const financeKey = 'swc_finance_input_v1';
  static const promoUrlsKey = 'swc_promo_urls_v1';

  Future<Map<String, String>> loadPromoUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(promoUrlsKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> savePromoUrls(Map<String, String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(promoUrlsKey, jsonEncode(urls));
  }

  Future<List<ActionItem>> loadActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(actionsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveActions(List<ActionItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(actionsKey, encoded);
  }

  Future<List<BusinessIssue>> loadIssues() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(issuesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => BusinessIssue.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveIssues(List<BusinessIssue> issues) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(issues.map((e) => e.toJson()).toList());
    await prefs.setString(issuesKey, encoded);
  }

  Future<FinanceInput?> loadFinance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(financeKey);
    if (raw == null) return null;
    return FinanceInput.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveFinance(FinanceInput input) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(financeKey, jsonEncode(input.toJson()));
  }
}
