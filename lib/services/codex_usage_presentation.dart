import '../models/remote_agent_models.dart';

/// Codex 주간 사용량 UI helper (운영 보조 표시 — 제품 quota 정책 아님).
class CodexUsagePresentation {
  CodexUsagePresentation._();

  static const staleThreshold = Duration(minutes: 45);

  static const sufficientMax = 59;
  static const moderateMax = 79;
  static const highMax = 94;

  static CodexUsageView? viewFor(RemoteAgentDoc? agent, {DateTime? now}) {
    final usage = agent?.codexUsage;
    if (usage == null) return null;

    final clock = now ?? DateTime.now().toUtc();
    final collectedAt = usage.collectedAt;
    if (collectedAt != null &&
        clock.difference(collectedAt.toUtc()) > staleThreshold) {
      return const CodexUsageView(
        headline: '사용량 정보 확인 필요',
        detailLines: [],
        quotaLabel: '',
        unavailable: true,
      );
    }

    if (usage.status != 'ok') {
      return CodexUsageView(
        headline: '사용량 확인 필요',
        detailLines: [],
        quotaLabel: '',
        unavailable: true,
      );
    }

    final weekly = usage.weekly;
    final used = weekly?.usedPercent;
    final remaining = weekly?.remainingPercent;
    if (used == null || remaining == null) {
      return const CodexUsageView(
        headline: '사용량 확인 필요',
        detailLines: [],
        quotaLabel: '',
        unavailable: true,
      );
    }

    final resetLine = _resetLine(weekly?.resetAt, now: clock);
    final quotaLabel = quotaStatusLabel(used);
    final lines = <String>[
      '이번 주 사용 $used%',
      '남음 $remaining%',
      if (resetLine.isNotEmpty) resetLine,
      if (quotaLabel.isNotEmpty) '상태: $quotaLabel',
    ];

    return CodexUsageView(
      headline: '이번 주 사용 $used%',
      detailLines: lines,
      quotaLabel: quotaLabel,
      unavailable: false,
    );
  }

  static String quotaStatusLabel(int usedPercent) {
    if (usedPercent <= sufficientMax) return '충분';
    if (usedPercent <= moderateMax) return '조절 필요';
    if (usedPercent <= highMax) return '사용량 높음';
    return '한도 임박';
  }

  static String fallbackUsageText(RemoteAgentDoc? agent) {
    final view = viewFor(agent);
    if (view != null) return view.displayText;
    return '수집 준비 중';
  }

  static String _resetLine(DateTime? resetAt, {DateTime? now}) {
    if (resetAt == null) return '';
    final localReset = resetAt.toLocal();
    final clock = (now ?? DateTime.now().toUtc()).toLocal();
    final diff = localReset.difference(clock);
    if (diff.isNegative) return '초기화 예정';

    if (diff.inHours >= 48) {
      final days = diff.inDays;
      final hours = diff.inHours.remainder(24);
      if (hours > 0) return '초기화까지 $days일 $hours시간';
      return '초기화까지 $days일';
    }
    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      final mins = diff.inMinutes.remainder(60);
      if (mins > 0) return '초기화까지 $hours시간 $mins분';
      return '초기화까지 $hours시간';
    }
    if (diff.inMinutes >= 1) return '초기화까지 ${diff.inMinutes}분';

    final month = localReset.month;
    final day = localReset.day;
    final hour = localReset.hour.toString().padLeft(2, '0');
    final minute = localReset.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute 초기화';
  }
}

class CodexUsageView {
  const CodexUsageView({
    required this.headline,
    required this.detailLines,
    required this.quotaLabel,
    required this.unavailable,
  });

  final String headline;
  final List<String> detailLines;
  final String quotaLabel;
  final bool unavailable;

  String get displayText {
    if (unavailable) return headline;
    if (detailLines.isEmpty) return headline;
    return detailLines.join('\n');
  }
}
