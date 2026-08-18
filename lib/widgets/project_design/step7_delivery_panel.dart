import 'package:flutter/material.dart';

import '../../services/work_instruction_delivery_presentation.dart';
import '../../theme/control_theme.dart';

/// STEP 7 — Agent 상태 + 전달 버튼 (작업지시 제작소).
class Step7DeliveryPanel extends StatelessWidget {
  const Step7DeliveryPanel({
    super.key,
    required this.view,
    this.onTransfer,
    this.onOpenRemoteDiagnostics,
    this.onOpenProductWorkshop,
    this.onViewInstruction,
    this.onDiagnosticAction,
    this.onCopyGptMemo,
    this.onShowValidation,
    this.onRecheckWorkshop,
  });

  final DeliveryStep7View view;
  final VoidCallback? onTransfer;
  final VoidCallback? onOpenRemoteDiagnostics;
  final VoidCallback? onOpenProductWorkshop;
  final VoidCallback? onViewInstruction;
  final void Function(DeliveryDiagnosticAction action)? onDiagnosticAction;
  final VoidCallback? onCopyGptMemo;
  final VoidCallback? onShowValidation;
  final VoidCallback? onRecheckWorkshop;

  @override
  Widget build(BuildContext context) {
    final agent = view.agentStatus;
    final dotColor = switch (agent.dotColorKind) {
      'green' => ControlColors.accentGreen,
      'amber' => ControlColors.accentWarm,
      _ => ControlColors.textMuted,
    };

    return Column(
      key: const Key('planning_step7_delivery'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: ControlColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ControlColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.headline,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  agent.statusLine,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: dotColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  agent.heartbeatLine,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ControlColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  agent.readinessLine,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onOpenRemoteDiagnostics != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onOpenRemoteDiagnostics,
                      child: const Text('노트북 원격관제에서 확인'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (view.showSuccessPanel) ...[
          _SuccessPanel(
            phase: view.workshopPhase,
            onViewInstruction: onViewInstruction,
            onOpenProductWorkshop: onOpenProductWorkshop,
            onRecheckWorkshop: onRecheckWorkshop,
          ),
          const SizedBox(height: 12),
        ] else if (view.failure != null &&
            view.buttonState == DeliveryButtonState.failed) ...[
          _FailurePanel(
            failure: view.failure!,
            onDiagnosticAction: onDiagnosticAction,
            onCopyGptMemo: onCopyGptMemo,
          ),
          const SizedBox(height: 12),
        ] else if (view.buttonState == DeliveryButtonState.blocked &&
            view.validationLines.isNotEmpty) ...[
          _ValidationPanel(
            lines: view.validationLines,
            onShowValidation: onShowValidation,
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          key: const Key('planning_transfer_button'),
          onPressed: view.buttonEnabled ? onTransfer : null,
          icon: view.buttonState == DeliveryButtonState.sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  view.buttonState == DeliveryButtonState.sent
                      ? Icons.check_circle_outline
                      : Icons.upload_outlined,
                  size: 18,
                ),
          label: Text(view.buttonLabel),
        ),
      ],
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    this.phase = WorkshopHandoffPhase.preparing,
    this.onViewInstruction,
    this.onOpenProductWorkshop,
    this.onRecheckWorkshop,
  });

  final WorkshopHandoffPhase phase;
  final VoidCallback? onViewInstruction;
  final VoidCallback? onOpenProductWorkshop;
  final VoidCallback? onRecheckWorkshop;

  @override
  Widget build(BuildContext context) {
    final registered = phase == WorkshopHandoffPhase.registered;
    return Container(
      key: const Key('planning_delivery_success'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✓ 소통24워크에 전달 완료',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Agent가 작업지시를 정상 수신했습니다.',
            style: TextStyle(color: ControlColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            registered ? '제작공정 등록 완료' : 'AI 제작공정을 준비하고 있습니다.',
            key: Key(
              registered
                  ? 'planning_workshop_registered'
                  : 'planning_workshop_preparing',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              TextButton(
                onPressed: onViewInstruction,
                child: const Text('작업지시 내용 보기'),
              ),
              if (registered)
                TextButton(
                  key: const Key('planning_open_workshop'),
                  onPressed: onOpenProductWorkshop,
                  child: const Text('AI 제작공정에서 보기'),
                )
              else ...[
                TextButton(
                  key: const Key('planning_recheck_workshop'),
                  onPressed: onRecheckWorkshop,
                  child: const Text('상태 재확인'),
                ),
                TextButton(
                  key: const Key('planning_workshop_preparing_action'),
                  onPressed: onOpenProductWorkshop,
                  child: const Text('AI 제작공정 준비 중'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({
    required this.failure,
    this.onDiagnosticAction,
    this.onCopyGptMemo,
  });

  final DeliveryFailureView failure;
  final void Function(DeliveryDiagnosticAction action)? onDiagnosticAction;
  final VoidCallback? onCopyGptMemo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('planning_delivery_failure'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failure.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(failure.body),
          const SizedBox(height: 4),
          Text(
            failure.guidance,
            style: const TextStyle(
              fontSize: 12.5,
              color: ControlColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: onDiagnosticAction == null
                    ? null
                    : () => onDiagnosticAction!(failure.primaryAction),
                child: Text(
                  WorkInstructionDeliveryPresentation.actionLabel(
                    failure.primaryAction,
                  ),
                ),
              ),
              if (failure.secondaryAction != null)
                OutlinedButton(
                  onPressed: onDiagnosticAction == null
                      ? null
                      : () => onDiagnosticAction!(failure.secondaryAction!),
                  child: Text(
                    WorkInstructionDeliveryPresentation.actionLabel(
                      failure.secondaryAction!,
                    ),
                  ),
                ),
              if (onCopyGptMemo != null)
                OutlinedButton(
                  onPressed: onCopyGptMemo,
                  child: const Text('GPT에 알려줄 문제 해결 메모 복사'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.lines, this.onShowValidation});

  final List<String> lines;
  final VoidCallback? onShowValidation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '확인할 항목이 ${lines.length}개 있습니다.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final line in lines.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ControlColors.textSecondary,
                ),
              ),
            ),
          if (onShowValidation != null)
            TextButton(
              onPressed: onShowValidation,
              child: const Text('문제 항목 확인'),
            ),
        ],
      ),
    );
  }
}
