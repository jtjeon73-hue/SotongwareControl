import 'package:flutter/material.dart';

import '../models/remote_e2e_sample.dart';
import '../theme/control_theme.dart';

/// 노트북 원격관제 — Cursor 자동실행 전용 TEST 패널 (기존 E2E와 분리).
class RemoteCursorAutostartPanel extends StatelessWidget {
  const RemoteCursorAutostartPanel({
    super.key,
    required this.view,
    required this.busy,
    required this.onCreate,
    required this.onViewContent,
    required this.onSendToAgent,
    required this.onReset,
  });

  final RemoteE2eSampleView view;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onViewContent;
  final VoidCallback onSendToAgent;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final session = view.session;
    final agentName =
        view.targetAgent?.deviceName ??
        (session.sentAgentName.isNotEmpty ? session.sentAgentName : '—');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ControlColors.accentWarm.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Cursor 자동실행 TEST',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ControlColors.accentWarm.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CURSOR',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: ControlColors.accentWarm,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            RemoteCursorAutostartMarkers.sampleDescription,
            style: const TextStyle(
              color: ControlColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ControlColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '주의: 위 샘플 E2E와 다른 전용 TEST입니다. '
              '전송 전 Cursor를 완전히 종료하세요.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _row('제목', RemoteCursorAutostartMarkers.sampleTitle),
          _row('유형', '전자책 · Cursor required'),
          _row('대상 Agent', agentName),
          _row('상태', view.phase.labelKo),
          if (session.instructionId.isNotEmpty)
            _row('instructionId', session.instructionId),
          if (view.detailMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              view.detailMessage,
              style: TextStyle(
                color: ControlColors.accentGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          if (view.sendBlockedReason.isNotEmpty && !view.canSend) ...[
            const SizedBox(height: 8),
            Text(
              view.sendBlockedReason,
              style: const TextStyle(
                color: ControlColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: busy ? null : onCreate,
                child: const Text('Cursor 자동실행 TEST 만들기'),
              ),
              OutlinedButton(
                onPressed: session.isCreated ? onViewContent : null,
                child: const Text('내용 보기'),
              ),
              FilledButton(
                onPressed: busy || !view.canSend ? null : onSendToAgent,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(view.session.isSent ? '전송 완료' : 'Agent로 보내기'),
              ),
              OutlinedButton(
                onPressed: busy ? null : onReset,
                child: const Text('테스트 초기화'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: ControlColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
