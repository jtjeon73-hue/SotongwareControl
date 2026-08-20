import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/cursor_usage_presentation.dart';

void main() {
  RemoteAgentDoc agent(CursorUsageTelemetry usage) => RemoteAgentDoc(
    agentId: 'agent_9830758291f9c64e',
    ownerUid: 'owner',
    deviceName: 'JT-JEON',
    state: 'idle',
    enabled: true,
    cursorUsage: usage,
  );

  test('unknown Cursor usage is explicit and never fabricated', () {
    final a = agent(
      CursorUsageTelemetry(collectedAt: DateTime.utc(2026, 8, 21, 0, 0)),
    );
    expect(CursorUsagePresentation.headline(a), '확인 불가');
    final lines = CursorUsagePresentation.detailLines(a);
    expect(lines, contains('확인 불가'));
    expect(lines.join(' '), contains('공식 자동 사용량 API'));
    expect(lines.join(' '), isNot(contains('사용 100%')));
  });

  test(
    'trusted manual Cursor quota shows used, remaining, reset and status',
    () {
      final a = agent(
        CursorUsageTelemetry(
          status: 'manual',
          source: 'manual',
          usedPercent: 100,
          remainingPercent: 0,
          resetsAt: DateTime.utc(2026, 8, 28),
          collectedAt: DateTime.utc(2026, 8, 21),
        ),
      );
      expect(CursorUsagePresentation.headline(a), '사용 100% · 잔여 0%');
      final detail = CursorUsagePresentation.detailLines(a).join(' | ');
      expect(detail, contains('8월 28일 초기화'));
      expect(detail, contains('상태: 소진'));
      expect(detail, contains('수동 입력'));
    },
  );
}
