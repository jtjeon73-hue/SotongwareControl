import 'package:flutter/material.dart';

import '../services/sotong24_notification_service.dart';
import '../theme/control_theme.dart';

class NotificationDiagnosticsCard extends StatefulWidget {
  const NotificationDiagnosticsCard({super.key, required this.controller});

  final NotificationController controller;

  @override
  State<NotificationDiagnosticsCard> createState() =>
      _NotificationDiagnosticsCardState();
}

class _NotificationDiagnosticsCardState
    extends State<NotificationDiagnosticsCard> {
  NotificationDiagnostics? _diagnostics;
  var _busy = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool clearMessage = true}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      if (clearMessage) _message = '';
    });
    try {
      final value = await widget.controller.diagnostics();
      if (mounted) setState(() => _diagnostics = value);
    } catch (_) {
      if (mounted) setState(() => _message = '알림 진단 정보를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final enabled = await widget.controller.enable();
      if (mounted) {
        setState(() {
          _message = enabled
              ? '이 기기가 운영 알림 수신 대상으로 등록되었습니다.'
              : '알림 권한이 허용되지 않았습니다.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = '알림 기기 등록에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh(clearMessage: false);
  }

  Future<void> _disable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.disable();
      if (mounted) setState(() => _message = '이 기기의 운영 알림을 해제했습니다.');
    } catch (_) {
      if (mounted) setState(() => _message = '알림 해제에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh(clearMessage: false);
  }

  Future<void> _sendTest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final eventId = await widget.controller.sendTestNotification();
      if (mounted) {
        setState(() {
          _message = eventId.isEmpty
              ? '테스트 알림을 요청했습니다.'
              : '테스트 알림을 전송 대기열에 등록했습니다.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = '테스트 알림 전송에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _refresh(clearMessage: false);
  }

  String _permissionLabel(NotificationPermissionState state) {
    return switch (state) {
      NotificationPermissionState.authorized => '허용',
      NotificationPermissionState.provisional => '임시 허용',
      NotificationPermissionState.denied => '차단됨',
      NotificationPermissionState.notDetermined => '요청 전',
      NotificationPermissionState.unsupported => '지원하지 않음',
      NotificationPermissionState.notConfigured => 'VAPID 미설정',
    };
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _diagnostics;
    final registered = diagnostics?.currentDeviceRegistered == true;
    final fcm = diagnostics?.deliveryMode == 'fcm';
    return Card(
      key: const Key('notification_diagnostics_card'),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.notifications_active_outlined),
        title: const Text(
          '모바일 운영 알림',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          diagnostics == null
              ? '권한·기기·FCM 상태를 확인합니다.'
              : registered && fcm
              ? '현재 기기 등록됨 · FCM 활성'
              : '확인 또는 설정이 필요합니다.',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          _StatusRow(
            label: '브라우저 권한',
            value: diagnostics == null
                ? '확인 중'
                : _permissionLabel(diagnostics.permission),
          ),
          _StatusRow(
            label: 'Push 전송',
            value: diagnostics == null
                ? '확인 중'
                : fcm
                ? 'FCM 활성'
                : 'Outbox 전용',
          ),
          _StatusRow(label: '현재 기기', value: registered ? '등록됨' : '등록되지 않음'),
          _StatusRow(
            label: '등록 기기 수',
            value: '${diagnostics?.registeredDeviceCount ?? 0}대',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('notification_enable_button'),
                onPressed: _busy || registered ? null : _enable,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('알림 켜기'),
              ),
              OutlinedButton.icon(
                key: const Key('notification_test_button'),
                onPressed: _busy || !registered || !fcm ? null : _sendTest,
                icon: const Icon(Icons.send_outlined),
                label: const Text('테스트 알림'),
              ),
              if (registered)
                TextButton(
                  key: const Key('notification_disable_button'),
                  onPressed: _busy ? null : _disable,
                  child: const Text('이 기기 알림 끄기'),
                ),
              IconButton(
                key: const Key('notification_refresh_button'),
                tooltip: '새로고침',
                onPressed: _busy ? null : () => _refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _message,
              key: const Key('notification_diagnostics_message'),
              style: const TextStyle(color: ControlColors.textSecondary),
            ),
          ],
          const Divider(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '최근 알림 이력',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          if (diagnostics == null || diagnostics.recentNotifications.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '최근 알림이 없습니다.',
                style: TextStyle(color: ControlColors.textMuted),
              ),
            )
          else
            for (final item in diagnostics.recentNotifications.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_none, size: 20),
                title: Text(item.title),
                subtitle: Text(
                  '${item.body}\n${item.status} · ${item.createdAt}',
                ),
                isThreeLine: true,
              ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: ControlColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
