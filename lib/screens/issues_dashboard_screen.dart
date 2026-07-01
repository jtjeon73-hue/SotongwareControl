import 'package:flutter/material.dart';

import '../models/business_issue.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import '../widgets/business_issue_card.dart';
import '../widgets/business_issue_editor_dialog.dart';
import '../widgets/control_section_title.dart';

class IssuesDashboardScreen extends StatelessWidget {
  const IssuesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final open = state.issues.where((i) => !i.isResolved).toList();
        final resolved = state.issues.where((i) => i.isResolved).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: ControlSectionTitle(
                      title: '문제점 파악 및 대응',
                      subtitle: '등록 · 상태 변경 · 대응 수정 · 해결 · 로컬 저장',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('새 문제'),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                children: [
                  _chip(
                    '미해결 ${open.where((i) => i.status == IssueStatus.unresolved).length}',
                    ControlColors.accentWarm,
                  ),
                  _chip(
                    '대응중 ${open.where((i) => i.status == IssueStatus.responding).length}',
                    ControlColors.teal,
                  ),
                  _chip(
                    '긴급 ${open.where((i) => i.urgencyLevel == UrgencyLevel.high).length}',
                    ControlColors.sandBeige,
                  ),
                  _chip('해결 ${resolved.length}', ControlColors.textMuted),
                ],
              ),
              const SizedBox(height: 20),
              ControlSectionTitle(
                title: '진행 중 문제',
                subtitle: '${open.length}건',
              ),
              ...open.map((issue) => _IssueManageTile(issue: issue)),
              const SizedBox(height: 24),
              ControlSectionTitle(
                title: '해결된 문제',
                subtitle: '${resolved.length}건',
              ),
              if (resolved.isEmpty)
                Text(
                  '해결된 문제가 없습니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                ...resolved.map((issue) => _IssueManageTile(issue: issue)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final state = ControlScope.of(context);
    final issue = await BusinessIssueEditorDialog.show(context);
    if (issue != null) await state.addIssue(issue);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _IssueManageTile extends StatelessWidget {
  const _IssueManageTile({required this.issue});

  final BusinessIssue issue;

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);

    return Column(
      children: [
        BusinessIssueCard(issue: issue),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
          child: Row(
            children: [
              if (issue.memo.isNotEmpty)
                Expanded(
                  child: Text(
                    '메모: ${issue.memo}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: ControlColors.textMuted,
                    ),
                  ),
                )
              else
                const Spacer(),
              TextButton(
                onPressed: () async {
                  final updated = await BusinessIssueEditorDialog.show(
                    context,
                    issue: issue,
                  );
                  if (updated != null) await state.updateIssue(updated);
                },
                child: const Text('수정'),
              ),
              if (!issue.isResolved)
                TextButton(
                  onPressed: () => state.resolveIssue(issue.id),
                  child: const Text('해결'),
                ),
              PopupMenuButton<IssueStatus>(
                tooltip: '상태 변경',
                onSelected: (s) => state.updateIssue(issue.copyWith(status: s)),
                itemBuilder: (_) => IssueStatus.values
                    .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                child: Chip(
                  label: Text(
                    issue.status.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => state.deleteIssue(issue.id),
                tooltip: '삭제',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
