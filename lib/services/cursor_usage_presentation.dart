import '../models/remote_agent_models.dart';

class CursorUsagePresentation {
  CursorUsagePresentation._();

  static List<String> detailLines(RemoteAgentDoc? agent) {
    final usage = agent?.cursorUsage;
    if (usage == null || !usage.hasQuota) {
      return [
        '확인 불가',
        '공식 자동 사용량 API가 없어 값을 추정하지 않습니다.',
        if (usage?.collectedAt != null) '최근 확인 ${_time(usage!.collectedAt!)}',
        '향후 공식 provider 또는 수동 입력으로 연결 가능',
      ];
    }
    final used = usage.usedPercent!;
    final remaining = usage.remainingPercent!;
    return [
      '사용 $used%',
      '잔여 $remaining%',
      if (usage.resetsAt != null) '${_date(usage.resetsAt!)} 초기화',
      '상태: ${statusLabel(used)}',
      if (usage.collectedAt != null) '최근 확인 ${_time(usage.collectedAt!)}',
      '수동 입력',
    ];
  }

  static String headline(RemoteAgentDoc? agent) {
    final usage = agent?.cursorUsage;
    if (usage == null || !usage.hasQuota) return '확인 불가';
    return '사용 ${usage.usedPercent}% · 잔여 ${usage.remainingPercent}%';
  }

  static String statusLabel(int usedPercent) {
    if (usedPercent >= 100) return '소진';
    if (usedPercent >= 90) return '한도 임박';
    return '사용 가능';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.month}월 ${local.day}일';
  }

  static String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hour:$minute';
  }
}
