import 'package:flutter/foundation.dart';

import '../data/sample_operational_data.dart';
import '../models/action_item.dart';
import '../models/business_issue.dart';
import '../models/finance_input.dart';
import '../services/local_storage_service.dart';
import '../utils/due_text_helper.dart';

class DashboardStats {
  const DashboardStats({
    required this.inProgressCount,
    required this.doneCount,
    required this.delayedCount,
    required this.unresolvedIssueCount,
    required this.urgentIssueCount,
    required this.aiReportNeededCount,
    required this.healthScore,
    required this.healthLabel,
    required this.healthDetail,
  });

  final int inProgressCount;
  final int doneCount;
  final int delayedCount;
  final int unresolvedIssueCount;
  final int urgentIssueCount;
  final int aiReportNeededCount;
  final int healthScore;
  final String healthLabel;
  final String healthDetail;
}

class ControlState extends ChangeNotifier {
  ControlState({LocalStorageService? storage})
    : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;

  List<ActionItem> _actions = [];
  List<BusinessIssue> _issues = [];
  FinanceInput _finance = const FinanceInput();
  Map<String, String> _promoUrls = {};
  bool _initialized = false;

  List<ActionItem> get actions => List.unmodifiable(_actions);
  List<BusinessIssue> get issues => List.unmodifiable(_issues);
  FinanceInput get finance => _finance;
  Map<String, String> get promoUrls => Map.unmodifiable(_promoUrls);
  bool get isInitialized => _initialized;

  String promoUrlFor(String siteId) => _promoUrls[siteId] ?? '';

  String promoUrlDisplay(String siteId) {
    final url = promoUrlFor(siteId).trim();
    return url.isEmpty ? '준비 중' : url;
  }

  bool hasPromoUrl(String siteId) => promoUrlFor(siteId).trim().isNotEmpty;

  List<ActionItem> get activeActions =>
      _actions.where((a) => !a.isDone).toList();

  List<ActionItem> get doneActions => _actions.where((a) => a.isDone).toList();

  List<BusinessIssue> get openIssues =>
      _issues.where((i) => !i.isResolved).toList();

  ActionItem effectiveAction(ActionItem item) {
    final status = DueTextHelper.resolveEffectiveStatus(item);
    if (status == item.status) return item;
    return item.copyWith(status: status);
  }

  List<ActionItem> get actionsWithEffectiveStatus =>
      _actions.map(effectiveAction).toList();

  DashboardStats get dashboardStats {
    final effective = actionsWithEffectiveStatus;
    final inProgress = effective
        .where(
          (a) =>
              DueTextHelper.resolveEffectiveStatus(a) ==
              ActionStatus.inProgress,
        )
        .length;
    final done = effective.where((a) => a.isDone).length;
    final delayed = effective
        .where(
          (a) =>
              DueTextHelper.resolveEffectiveStatus(a) == ActionStatus.delayed,
        )
        .length;
    final unresolved = _issues
        .where((i) => i.status == IssueStatus.unresolved)
        .length;
    final responding = _issues
        .where((i) => i.status == IssueStatus.responding)
        .length;
    final urgent = _issues
        .where((i) => i.urgencyLevel == UrgencyLevel.high && !i.isResolved)
        .length;
    final aiNeeded = responding + delayed + urgent;

    var score = 100;
    score -= delayed * 5;
    score -= unresolved * 4;
    score -= urgent * 3;
    score = score.clamp(40, 100);

    final label = score >= 85
        ? '양호'
        : score >= 70
        ? '주의 필요'
        : '즉시 점검';

    final detail =
        '진행 ${inProgress + effective.where((a) => a.status == ActionStatus.scheduled).length}건 · '
        '지연 $delayed건 · 미해결 $unresolved건 · 긴급 $urgent건';

    return DashboardStats(
      inProgressCount: inProgress,
      doneCount: done,
      delayedCount: delayed,
      unresolvedIssueCount: unresolved,
      urgentIssueCount: urgent,
      aiReportNeededCount: aiNeeded,
      healthScore: score,
      healthLabel: label,
      healthDetail: detail,
    );
  }

  Future<void> initialize() async {
    final storedActions = await _storage.loadActions();
    final storedIssues = await _storage.loadIssues();
    final storedFinance = await _storage.loadFinance();
    final storedPromoUrls = await _storage.loadPromoUrls();

    _actions = storedActions.isNotEmpty
        ? storedActions
        : List<ActionItem>.from(SampleOperationalData.defaultActions);
    _issues = storedIssues.isNotEmpty
        ? storedIssues
        : List<BusinessIssue>.from(SampleOperationalData.businessIssues);
    _finance = storedFinance ?? const FinanceInput();
    _promoUrls = storedPromoUrls;

    _applyDelayDetection();
    _initialized = true;
    notifyListeners();
  }

  void _applyDelayDetection() {
    _actions = _actions.map((item) {
      final effective = DueTextHelper.resolveEffectiveStatus(item);
      if (effective != item.status && item.status != ActionStatus.done) {
        return item.copyWith(status: effective);
      }
      return item;
    }).toList();
  }

  Future<void> _persistActions() async {
    await _storage.saveActions(_actions);
    notifyListeners();
  }

  Future<void> _persistIssues() async {
    await _storage.saveIssues(_issues);
    notifyListeners();
  }

  Future<void> _persistFinance() async {
    await _storage.saveFinance(_finance);
    notifyListeners();
  }

  Future<void> addAction(ActionItem item) async {
    _actions = [..._actions, item];
    await _persistActions();
  }

  Future<void> updateAction(ActionItem item) async {
    _actions = _actions.map((a) => a.id == item.id ? item : a).toList();
    _applyDelayDetection();
    await _persistActions();
  }

  Future<void> deleteAction(String id) async {
    _actions = _actions.where((a) => a.id != id).toList();
    await _persistActions();
  }

  Future<void> toggleActionDone(String id) async {
    final index = _actions.indexWhere((a) => a.id == id);
    if (index < 0) return;
    final item = _actions[index];
    final newStatus = item.isDone ? ActionStatus.scheduled : ActionStatus.done;
    await updateAction(item.copyWith(status: newStatus));
  }

  Future<void> addIssue(BusinessIssue issue) async {
    _issues = [..._issues, issue];
    await _persistIssues();
  }

  Future<void> updateIssue(BusinessIssue issue) async {
    _issues = _issues.map((i) => i.id == issue.id ? issue : i).toList();
    await _persistIssues();
  }

  Future<void> deleteIssue(String id) async {
    _issues = _issues.where((i) => i.id != id).toList();
    await _persistIssues();
  }

  Future<void> resolveIssue(String id) async {
    final index = _issues.indexWhere((i) => i.id == id);
    if (index < 0) return;
    await updateIssue(_issues[index].copyWith(status: IssueStatus.resolved));
  }

  Future<void> updateFinance(FinanceInput input) async {
    _finance = input;
    await _persistFinance();
  }

  Future<void> setPromoUrl(String siteId, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _promoUrls = Map.from(_promoUrls)..remove(siteId);
    } else {
      _promoUrls = Map.from(_promoUrls)..[siteId] = trimmed;
    }
    await _storage.savePromoUrls(_promoUrls);
    notifyListeners();
  }

  static String newId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
}
