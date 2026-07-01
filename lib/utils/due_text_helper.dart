import '../models/action_item.dart';

/// dueText 기반 지연 감지. 추후 [dueDateIso] 날짜 비교로 확장 가능.
class DueTextHelper {
  static const delayKeywords = ['지연', '기한 초과', '미완료', 'overdue'];

  static bool suggestsDelayed(String dueText) {
    final normalized = dueText.trim().toLowerCase();
    return delayKeywords.any(normalized.contains);
  }

  static ActionStatus effectiveStatus(ActionItem item) {
    if (item.status == ActionStatus.done) {
      return ActionStatus.done;
    }
    if (item.status == ActionStatus.delayed || suggestsDelayed(item.dueText)) {
      return ActionStatus.delayed;
    }
    return item.status;
  }

  /// 추후 dueDateIso와 오늘 날짜를 비교해 지연 여부 판단
  static bool isOverdueByDate(String? dueDateIso) {
    if (dueDateIso == null || dueDateIso.isEmpty) return false;
    try {
      final due = DateTime.parse(dueDateIso);
      final today = DateTime.now();
      final dueDay = DateTime(due.year, due.month, due.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      return dueDay.isBefore(todayDay);
    } catch (_) {
      return false;
    }
  }

  static ActionStatus resolveEffectiveStatus(ActionItem item) {
    if (item.status == ActionStatus.done) return ActionStatus.done;
    if (item.status == ActionStatus.delayed ||
        suggestsDelayed(item.dueText) ||
        isOverdueByDate(item.dueDateIso)) {
      return ActionStatus.delayed;
    }
    return item.status;
  }
}
