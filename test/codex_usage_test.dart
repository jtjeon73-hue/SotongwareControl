import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/codex_usage_presentation.dart';

RemoteAgentDoc _agentWithCodex({
  String status = 'ok',
  DateTime? collectedAt,
  int used = 18,
  int remaining = 82,
  DateTime? resetAt,
}) {
  return RemoteAgentDoc(
    agentId: 'agent_1',
    ownerUid: 'uid',
    deviceName: 'PC',
    state: 'idle',
    enabled: true,
    codexUsage: CodexUsageTelemetry(
      status: status,
      collectedAt: collectedAt,
      planType: 'plus',
      weekly: CodexWeeklyUsage(
        usedPercent: used,
        remainingPercent: remaining,
        windowDurationMins: 10080,
        resetsAtIso: resetAt,
      ),
    ),
  );
}

void main() {
  group('CodexUsagePresentation', () {
    test('weekly 18/82 정상 표시', () {
      final now = DateTime.utc(2026, 8, 18, 2, 0);
      final agent = _agentWithCodex(
        collectedAt: now.subtract(const Duration(minutes: 10)),
        resetAt: DateTime.utc(2026, 8, 20, 14, 26),
      );
      final view = CodexUsagePresentation.viewFor(agent, now: now);
      expect(view, isNotNull);
      expect(view!.unavailable, isFalse);
      expect(view.detailLines, contains('이번 주 사용 18%'));
      expect(view.detailLines, contains('남음 82%'));
      expect(view.quotaLabel, '충분');
    });

    test('reset 표시', () {
      final now = DateTime.utc(2026, 8, 18, 2, 0);
      final agent = _agentWithCodex(
        collectedAt: now,
        resetAt: DateTime.utc(2026, 8, 20, 14, 26),
      );
      final view = CodexUsagePresentation.viewFor(agent, now: now)!;
      expect(view.detailLines.any((l) => l.startsWith('초기화까지')), isTrue);
    });

    test('field 없음 → 수집 준비 중', () {
      const agent = RemoteAgentDoc(
        agentId: 'a',
        ownerUid: 'u',
        deviceName: 'PC',
        state: 'idle',
        enabled: true,
      );
      expect(CodexUsagePresentation.fallbackUsageText(agent), '수집 준비 중');
    });

    test('status != ok → 사용량 확인 필요', () {
      final agent = _agentWithCodex(status: 'auth_required');
      expect(CodexUsagePresentation.fallbackUsageText(agent), '사용량 확인 필요');
    });

    test('stale telemetry → 사용량 정보 확인 필요', () {
      final now = DateTime.utc(2026, 8, 18, 12, 0);
      final agent = _agentWithCodex(
        collectedAt: now.subtract(const Duration(minutes: 50)),
      );
      expect(
        CodexUsagePresentation.viewFor(agent, now: now)?.headline,
        '사용량 정보 확인 필요',
      );
    });

    test('malformed weekly → 사용량 확인 필요', () {
      final agent = RemoteAgentDoc(
        agentId: 'a',
        ownerUid: 'u',
        deviceName: 'PC',
        state: 'idle',
        enabled: true,
        codexUsage: CodexUsageTelemetry(
          status: 'ok',
          collectedAt: DateTime.utc(2026, 8, 18, 2, 0),
          weekly: const CodexWeeklyUsage(
            usedPercent: null,
            remainingPercent: 82,
          ),
        ),
      );
      expect(CodexUsagePresentation.fallbackUsageText(agent), '사용량 확인 필요');
    });

    test('quota status thresholds', () {
      expect(CodexUsagePresentation.quotaStatusLabel(18), '충분');
      expect(CodexUsagePresentation.quotaStatusLabel(65), '조절 필요');
      expect(CodexUsagePresentation.quotaStatusLabel(85), '사용량 높음');
      expect(CodexUsagePresentation.quotaStatusLabel(98), '한도 임박');
    });
  });
}
