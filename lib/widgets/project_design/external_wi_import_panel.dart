import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/external_work_instruction_import.dart';
import '../../services/remote_agent_repository.dart';
import '../../services/work_instruction_remote_delivery.dart';
import '../../theme/control_theme.dart';
import 'external_wi_file_pick.dart';

/// Operator-only: import external Commercial V2 WI / handoff, review, then
/// deliver via existing WorkInstructionRemoteDelivery.deliver (no auto-send).
class ExternalWiImportPanel extends StatefulWidget {
  const ExternalWiImportPanel({
    super.key,
    this.delivery,
    this.agentRepo,
    this.onDelivered,
  });

  /// Injectable for tests. Defaults to WorkInstructionRemoteDeliveryService.
  final WorkInstructionRemoteDeliveryService? delivery;
  final RemoteAgentRepository? agentRepo;
  final void Function(RemoteDeliveryResult result)? onDelivered;

  static Future<void> show(
    BuildContext context, {
    WorkInstructionRemoteDeliveryService? delivery,
    RemoteAgentRepository? agentRepo,
    void Function(RemoteDeliveryResult result)? onDelivered,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: ExternalWiImportPanel(
            delivery: delivery,
            agentRepo: agentRepo,
            onDelivered: onDelivered,
          ),
        ),
      ),
    );
  }

  @override
  State<ExternalWiImportPanel> createState() => _ExternalWiImportPanelState();
}

class _ExternalWiImportPanelState extends State<ExternalWiImportPanel> {
  final _jsonCtrl = TextEditingController();
  ExternalWiImportResult? _imported;
  String? _error;
  bool _busy = false;
  int _apiCalls = 0;

  WorkInstructionRemoteDeliveryService get _delivery =>
      widget.delivery ?? WorkInstructionRemoteDeliveryService();

  RemoteAgentRepository get _agents =>
      widget.agentRepo ?? RemoteAgentRepository();

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  void _runImport() {
    setState(() {
      _error = null;
      _imported = ExternalWorkInstructionImport.parseText(_jsonCtrl.text);
      if (_imported?.ok != true) {
        _error = (_imported?.issues.isNotEmpty == true)
            ? _imported!.issues.map((e) => '${e.code}: ${e.message}').join('\n')
            : 'import 실패';
      }
    });
  }

  Future<void> _pickFile() async {
    final text = await pickExternalWiJsonText();
    if (!mounted) return;
    if (text == null) return;
    setState(() {
      _jsonCtrl.text = text;
      _error = null;
      _imported = null;
    });
    _runImport();
  }

  Future<void> _confirmAndDeliver() async {
    final imp = _imported;
    if (imp == null || !imp.ok) return;
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() => _error = '로그인이 필요합니다.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('작업을 전송할까요?'),
        content: Text(
          '「${imp.title}」\n'
          'instructionId: ${imp.instructionId}\n\n'
          '연결된 노트북 Agent로 전달합니다.\n'
          '전송이 성공해야 전달됨으로 표시됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('external_wi_confirm_deliver'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('전달'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      var preferred = imp.assignedAgentId;
      if (preferred.isEmpty) {
        final agents = await _agents.watchAgents(ownerUid: uid).first;
        final pick = WorkInstructionRemoteDelivery.pickTargetAgent(agents);
        preferred = pick?.agentId ?? '';
      }
      _apiCalls += 1;
      final result = await _delivery.deliver(
        instructionId: imp.instructionId,
        title: imp.title,
        type: imp.type,
        payload: Map<String, dynamic>.from(imp.payload),
        totalStages: imp.totalStages,
        ownerUid: uid,
        preferredAgentId: preferred.isEmpty ? null : preferred,
      );
      if (!mounted) return;
      widget.onDelivered?.call(result);
      if (result.delivered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소통24워크 Agent로 전달했습니다.')),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error = result.userMessage.isNotEmpty
              ? result.userMessage
              : (result.errorCode ?? '전달 실패');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '전달 오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imp = _imported;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '외부 작업지시 불러오기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('external_wi_close'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '운영자 전용 · 기존 Commercial V2 WI/handoff를 검증 후 기존 「전달」 경로로만 전송합니다. '
            'import만으로는 전송되지 않습니다.',
            style: TextStyle(fontSize: 12.5, color: ControlColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('external_wi_pick_file'),
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('JSON 파일 선택'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('external_wi_paste_import'),
                onPressed: _busy ? null : _runImport,
                icon: const Icon(Icons.playlist_add_check),
                label: const Text('붙여넣기 검증'),
              ),
              const Spacer(),
              Text(
                'API calls(this panel): $_apiCalls',
                style: const TextStyle(fontSize: 11, color: ControlColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              key: const Key('external_wi_json_field'),
              controller: _jsonCtrl,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Commercial V2 WI JSON 또는 START_JOB handoff JSON을 붙여넣으세요',
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('external_wi_error'),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ],
          if (imp != null && imp.ok) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('external_wi_review'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: ControlColors.teal.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
                color: ControlColors.teal.withValues(alpha: 0.06),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('제목: ${imp.title}'),
                  Text('instructionId: ${imp.instructionId}'),
                  Text('사업유형: ${imp.type}'),
                  Text('총 단계: ${imp.totalStages}'),
                  Text('approvalMode: ${imp.approvalMode}'),
                  Text('executionMode: ${imp.executionMode}'),
                  Text(
                    'assignedAgentId: ${imp.assignedAgentId.isEmpty ? '(전달 시 online Agent 자동 선택)' : imp.assignedAgentId}',
                  ),
                  if (imp.sourceWasHandoff)
                    Text(
                      'handoff ignored jobId/commandId: '
                      '${imp.ignoredHandoffJobId}/${imp.ignoredHandoffCommandId}',
                      style: const TextStyle(fontSize: 11, color: ControlColors.textMuted),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        final pretty = const JsonEncoder.withIndent('  ')
                            .convert({'hint': 'import 후 검토→전달'});
                        Clipboard.setData(ClipboardData(text: pretty));
                      },
                child: const Text('도움말 복사'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('external_wi_deliver'),
                onPressed: (!_busy && imp != null && imp.ok)
                    ? _confirmAndDeliver
                    : null,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('전달'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
