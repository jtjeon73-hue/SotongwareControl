import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/remote_e2e_sample.dart';
import '../theme/control_theme.dart';
import '../widgets/sidebar_navigation.dart';

/// 노트북 원격관제 — 샘플 WorkInstruction E2E 테스트 패널.
class RemoteE2eSamplePanel extends StatelessWidget {
  const RemoteE2eSamplePanel({
    super.key,
    required this.view,
    required this.busy,
    required this.onCreateSample,
    required this.onViewContent,
    required this.onSendToAgent,
    required this.onViewStatus,
    required this.onReset,
    this.onOpenProductWorkshop,
  });

  final RemoteE2eSampleView view;
  final bool busy;
  final VoidCallback onCreateSample;
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
        border: Border.all(color: ControlColors.teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '샘플 작업지시서 E2E 테스트',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ControlColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TEST',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: ControlColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            RemoteE2eSampleMarkers.sampleDescription,
            style: const TextStyle(
              color: ControlColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _MetaRow(label: '제목', value: RemoteE2eSampleMarkers.sampleTitle),
          _MetaRow(label: '유형', value: '전자책'),
          _MetaRow(label: '대상 Agent', value: agentName),
          _MetaRow(label: '단계', value: '18단계'),
          _MetaRow(label: '상태', value: view.phase.labelKo),
          if (session.instructionId.isNotEmpty)
            _MetaRow(label: 'instructionId', value: session.instructionId),
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
                onPressed: busy ? null : onCreateSample,
                child: const Text('샘플 작업지시서 생성'),
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
                child: const Text('현재 상태 보기'),
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
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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

Future<void> showRemoteE2eJsonDialog(
  BuildContext context,
  String jsonText,
) async {
  Map<String, dynamic>? pretty;
  try {
    pretty = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
  } catch (_) {}

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('샘플 WorkInstruction JSON'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: SelectableText(
            pretty != null
                ? const JsonEncoder.withIndent('  ').convert(pretty)
                : jsonText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: jsonText));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('복사'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

Future<void> showRemoteE2eStatusSheet(
  BuildContext context,
  RemoteE2eSampleView view,
) async {
  final rows = buildRemoteE2eStatusRows(view);
  final isTest =
      RemoteE2eSampleMarkers.isTestInstructionId(view.session.instructionId) ||
      RemoteE2eSampleMarkers.isTestTitle(view.linkedJob?.title) ||
      RemoteE2eSampleMarkers.isTestTitle(RemoteE2eSampleMarkers.sampleTitle);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final maxHeight = media.size.height * 0.9;
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'E2E 테스트 현재 상태',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isTest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ControlColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'TEST',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: ControlColors.teal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const Key('remote_e2e_status_scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 118,
                                child: Text(
                                  row.label,
                                  style: TextStyle(
                                    color: row.isFooter
                                        ? ControlColors.textSecondary
                                        : ControlColors.textMuted,
                                    fontSize: 13,
                                    fontWeight: row.isFooter
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SelectableText(
                                  row.value,
                                  style: TextStyle(
                                    height: 1.35,
                                    fontSize: 13,
                                    color: row.isFooter
                                        ? ControlColors.textSecondary
                                        : ControlColors.textPrimary,
                                    fontWeight: row.isFooter
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        key: const Key('remote_e2e_status_footer'),
                        '아래로 스크롤하면 Job·오류·진단 참고까지 확인할 수 있습니다.',
                        style: TextStyle(
                          color: ControlColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// productWorkshop 이동 콜백 타입 alias (테스트용).
typedef ProductWorkshopNavigate = void Function(ControlDestination destination);
