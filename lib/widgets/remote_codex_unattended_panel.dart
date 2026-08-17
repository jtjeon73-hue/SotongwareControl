import 'package:flutter/material.dart';

import '../models/remote_e2e_sample.dart';
import '../theme/control_theme.dart';

/// 노트북 원격관제 — Codex 무인작업 전용 TEST 패널.
class RemoteCodexUnattendedPanel extends StatelessWidget {
  const RemoteCodexUnattendedPanel({
    super.key,
    required this.view,
    required this.busy,
    required this.onCreate,
    required this.onViewContent,
    required this.onSendToAgent,
    required this.onViewStatus,
    required this.onReset,
    this.onOpenProductWorkshop,
  });

  final RemoteE2eSampleView view;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onViewContent;
  final VoidCallback onSendToAgent;
  final VoidCallback onViewStatus;
  final VoidCallback onReset;
  final VoidCallback? onOpenProductWorkshop;

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
          color: ControlColors.sandBeige.withValues(alpha: 0.55),
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
                  'Codex 무인작업 TEST',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ControlColors.sandLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CODEX · TEST',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: ControlColors.sandBeige,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            RemoteCodexUnattendedMarkers.sampleDescription,
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
            child: Text(
              'smoke: stage=${RemoteCodexUnattendedMarkers.smokeStageId} · '
              '산출물 ${RemoteCodexUnattendedMarkers.expectedOutputPath}\n'
              'git/deploy/install/외부 destructive/workspace 밖 수정 금지',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _row('제목', RemoteCodexUnattendedMarkers.sampleTitle),
          _row('유형', '전자책 · Codex required'),
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
                child: const Text('Codex TEST 만들기'),
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
                onPressed: session.isCreated ? onViewStatus : null,
                child: const Text('현재 상태'),
              ),
              OutlinedButton(
                onPressed: busy ? null : onReset,
                child: const Text('테스트 초기화'),
              ),
              if (onOpenProductWorkshop != null && session.isSent)
                OutlinedButton(
                  onPressed: onOpenProductWorkshop,
                  child: const Text('AI 제작공정에서 보기'),
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
