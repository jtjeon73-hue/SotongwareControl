import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/remote_agent_models.dart';
import '../models/sotong24_monitoring.dart';
import '../models/sotong24_remote_models.dart';
import '../services/remote_control_api.dart';
import '../theme/control_theme.dart';

typedef CancelRunAction =
    Future<RemoteRunCancelResult> Function({
      required String jobId,
      required String instructionId,
      required String projectId,
    });

/// 정체·실패 알림 상세 화면 후속 조치 (A~F).
class StallFollowUpActionBar extends StatefulWidget {
  const StallFollowUpActionBar({
    super.key,
    required this.project,
    required this.stage,
    required this.job,
    required this.snapshot,
    this.onCancelRun,
    this.onStartNewWork,
    this.api,
  });

  final Sotong24RemoteProject project;
  final Sotong24RemoteStage stage;
  final RemoteJobDoc job;
  final Sotong24StageMonitoringSnapshot snapshot;
  final CancelRunAction? onCancelRun;
  final VoidCallback? onStartNewWork;
  final RemoteControlApi? api;

  @override
  State<StallFollowUpActionBar> createState() => _StallFollowUpActionBarState();
}

class _StallFollowUpActionBarState extends State<StallFollowUpActionBar> {
  RemoteControlApi get _api => widget.api ?? RemoteControlApi();

  var _busyAction = '';
  String? _lastResult;
  bool _lastSuccess = false;
  RemoteStallRecheckResult? _recheck;
  Map<String, dynamic>? _diagnostics;
  bool _recoveryUsed = false;

  bool get _dispatchBlocked =>
      widget.stage.dispatchBlocked ||
      widget.stage.recoveryState == 'safe_stopped' ||
      widget.stage.activityState == 'safe_stopped';

  @override
  void initState() {
    super.initState();
    _recoveryUsed = widget.stage.manualRecoveryUsed;
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _setResult(String action, bool success, String message) {
    setState(() {
      _busyAction = '';
      _lastResult = '$action: $message';
      _lastSuccess = success;
    });
  }

  Future<void> _recheckStatus() async {
    if (_busyAction.isNotEmpty) return;
    setState(() => _busyAction = 'recheck');
    try {
      final result = await _api.recheckStallStatus(
        jobId: widget.job.jobId,
        instructionId: widget.job.instructionId,
        projectId: widget.project.projectId,
        stageId: widget.stage.stageId,
      );
      if (!mounted) return;
      setState(() => _recheck = result);
      _setResult(
        '상태 재확인',
        true,
        'jobId ${widget.job.jobId} · ${result.raw['health'] ?? ''}',
      );
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      _setResult('상태 재확인', false, e.userMessage);
    }
  }

  Future<void> _pauseSafely() async {
    if (_busyAction.isNotEmpty) return;
    final ok = await _confirm(
      '안전 일시정지',
      'jobId ${widget.job.jobId}\n'
          '현재 단계·산출물·로그는 보존되고 신규 dispatch/recovery만 차단됩니다.',
    );
    if (!ok || !mounted) return;
    setState(() => _busyAction = 'pause');
    try {
      final result = await _api.pauseJobSafely(
        jobId: widget.job.jobId,
        instructionId: widget.job.instructionId,
        projectId: widget.project.projectId,
        stageId: widget.stage.stageId,
      );
      if (!mounted) return;
      _setResult(
        '안전 일시정지',
        result.succeeded,
        result.idempotent ? '이미 일시정지됨' : '일시정지 적용',
      );
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      _setResult('안전 일시정지', false, e.userMessage);
    }
  }

  Future<void> _recoveryOnce() async {
    if (_busyAction.isNotEmpty || _recoveryUsed) return;
    final ok = await _confirm(
      '자동복구 1회',
      'jobId ${widget.job.jobId}\n'
          '명시적으로 한 번만 허용됩니다. handoff/session 증거가 없으면 실패하며 무한 재시도하지 않습니다.',
    );
    if (!ok || !mounted) return;
    setState(() => _busyAction = 'recovery');
    try {
      final result = await _api.recoveryOnce(
        jobId: widget.job.jobId,
        instructionId: widget.job.instructionId,
        stageId: widget.stage.stageId,
      );
      if (!mounted) return;
      setState(() => _recoveryUsed = true);
      _setResult(
        '자동복구 1회',
        result.succeeded,
        result.idempotent ? '이미 요청됨' : result.state,
      );
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      setState(() => _recoveryUsed = true);
      _setResult('자동복구 1회', false, e.userMessage);
    }
  }

  Future<void> _cancelPreserve() async {
    final action = widget.onCancelRun;
    if (action == null || _busyAction.isNotEmpty) return;
    final ok = await _confirm(
      '작업 중단·보존',
      'jobId ${widget.job.jobId}\n'
          '작업을 중단하고 진단 snapshot을 자동 생성합니다. 기록은 보존됩니다.',
    );
    if (!ok || !mounted) return;
    setState(() => _busyAction = 'cancel');
    try {
      final result = await action(
        jobId: widget.job.jobId,
        instructionId: widget.job.instructionId,
        projectId: widget.project.projectId,
      );
      if (!mounted) return;
      _setResult(
        '작업 중단·보존',
        result.completed,
        result.completed ? 'cancelled_preserved' : result.state,
      );
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      _setResult('작업 중단·보존', false, e.userMessage);
    }
  }

  Future<void> _startNewWork() async {
    if (_busyAction.isNotEmpty) return;
    final ok = await _confirm(
      '처음부터 새 작업 시작',
      '기존 작업·진단 기록은 보존됩니다. 새 instructionId/jobId로 작업지시 제작소로 이동합니다. '
          '자동으로 Golden Run이나 작업을 시작하지 않습니다.',
    );
    if (!ok || !mounted) return;
    widget.onStartNewWork?.call();
    _setResult('새 작업 시작', true, '작업지시 제작소로 이동');
  }

  Future<void> _loadDiagnostics() async {
    if (_busyAction.isNotEmpty) return;
    setState(() => _busyAction = 'diagnostics');
    try {
      final map = await _api.getCancelDiagnostics(
        instructionId: widget.project.projectId,
      );
      if (!mounted) return;
      setState(() => _diagnostics = map);
      _setResult(
        '진단정보 조회',
        true,
        '항목 ${(map['diagnostics'] as List?)?.length ?? (map['diagnostic'] != null ? 1 : 0)}건',
      );
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      _setResult('진단정보 조회', false, e.userMessage);
    }
  }

  Future<void> _copyDiagnostics() async {
    final text = _buildDiagnosticSummary();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('진단 요약을 복사했습니다.')));
  }

  String _buildDiagnosticSummary() {
    final lines = <String>[
      'Sotong24 정체/실패 진단 요약',
      'instructionId: ${widget.project.projectId}',
      'jobId: ${widget.job.jobId}',
      'stageId: ${widget.stage.stageId}',
      'STEP: ${widget.stage.stageNumber}',
      'worker: ${widget.snapshot.activityLabel}',
      'agentOnline: ${widget.snapshot.agentOnline}',
      'heartbeatAge: ${Sotong24StageMonitoring.relative(widget.snapshot.heartbeatAge)}',
      'recoveryAttempt: ${widget.stage.recoveryAttempt}/${widget.stage.maxRecoveryAttempts}',
      'recoveryState: ${widget.stage.recoveryState}',
      'failureReason: ${widget.stage.failureReason}',
      'dispatchBlocked: $_dispatchBlocked',
    ];
    final recheck = _recheck?.raw;
    if (recheck != null) {
      lines
        ..add('--- recheck ---')
        ..add('effectiveWorker: ${recheck['effectiveWorker'] ?? ''}')
        ..add('workerPid: ${recheck['workerPid'] ?? ''}')
        ..add('handoffSessionId: ${recheck['handoffSessionId'] ?? ''}')
        ..add('agentState: ${recheck['agentState'] ?? ''}')
        ..add('heartbeatAt: ${recheck['heartbeatAt'] ?? ''}')
        ..add('lastActivityAt: ${recheck['lastActivityAt'] ?? ''}')
        ..add('recommendedAction: ${recheck['recommendedAction'] ?? ''}');
    }
    if (_diagnostics != null) {
      lines.add('--- cancelDiagnostics ---');
      final diag = _diagnostics!['diagnostic'];
      if (diag is Map) {
        for (final entry in diag.entries) {
          lines.add('${entry.key}: ${entry.value}');
        }
      }
      final items = _diagnostics!['diagnostics'];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          lines.add('id: ${item['id'] ?? ''}');
          for (final entry in item.entries) {
            if (entry.key == 'id') continue;
            lines.add('  ${entry.key}: ${entry.value}');
          }
        }
      }
    }
    return lines.join('\n');
  }

  Widget _actionButton({
    required Key key,
    required String label,
    required String actionKey,
    required VoidCallback? onPressed,
    bool destructive = false,
  }) {
    final busy = _busyAction == actionKey;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: key,
        onPressed: _busyAction.isNotEmpty && !busy ? null : onPressed,
        style: destructive
            ? OutlinedButton.styleFrom(
                foregroundColor: ControlColors.accentRose,
                side: const BorderSide(color: ControlColors.accentRose),
                minimumSize: const Size.fromHeight(42),
              )
            : OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('stall_followup_action_bar'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.accentRose.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ControlColors.accentRose.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '후속 조치',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '대상 jobId: ${widget.job.jobId}',
            style: const TextStyle(
              fontSize: 12,
              color: ControlColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '권장 순서: 상태 재확인 → 자동복구 1회 → 실패 시 작업 중단·보존',
            style: TextStyle(
              fontSize: 12,
              color: ControlColors.textMuted,
              height: 1.35,
            ),
          ),
          if (_dispatchBlocked) ...[
            const SizedBox(height: 6),
            Text(
              '안전 일시정지 적용 중 · 신규 dispatch/recovery 차단',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _actionButton(
            key: const Key('stall_action_recheck'),
            label: 'A. 상태 재확인',
            actionKey: 'recheck',
            onPressed: _recheckStatus,
          ),
          const SizedBox(height: 6),
          _actionButton(
            key: const Key('stall_action_pause'),
            label: 'B. 안전 일시정지',
            actionKey: 'pause',
            onPressed: _pauseSafely,
          ),
          const SizedBox(height: 6),
          _actionButton(
            key: const Key('stall_action_recovery_once'),
            label: _recoveryUsed ? 'C. 자동복구 1회 (사용됨)' : 'C. 자동복구 1회',
            actionKey: 'recovery',
            onPressed: _recoveryUsed ? null : _recoveryOnce,
          ),
          const SizedBox(height: 6),
          _actionButton(
            key: const Key('stall_action_cancel_preserve'),
            label: 'D. 작업 중단·보존',
            actionKey: 'cancel',
            onPressed: widget.onCancelRun == null ? null : _cancelPreserve,
            destructive: true,
          ),
          const SizedBox(height: 6),
          _actionButton(
            key: const Key('stall_action_new_work'),
            label: 'E. 처음부터 새 작업 시작',
            actionKey: 'new_work',
            onPressed: widget.onStartNewWork == null ? null : _startNewWork,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  key: const Key('stall_action_view_diagnostics'),
                  label: 'F. 진단정보 열람',
                  actionKey: 'diagnostics',
                  onPressed: _loadDiagnostics,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  key: const Key('stall_action_copy_diagnostics'),
                  label: 'F. 진단 복사',
                  actionKey: 'copy',
                  onPressed: _copyDiagnostics,
                ),
              ),
            ],
          ),
          if (_recheck != null) ...[
            const SizedBox(height: 10),
            Text(
              '재확인: worker=${_recheck!.raw['effectiveWorker'] ?? '-'} · '
              'PID=${_recheck!.raw['workerPid'] ?? '-'} · '
              'heartbeat=${_recheck!.raw['heartbeatAt'] ?? '-'}',
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textSecondary,
              ),
            ),
          ],
          if (_lastResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastResult!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _lastSuccess
                    ? ControlColors.teal
                    : ControlColors.accentRose,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
