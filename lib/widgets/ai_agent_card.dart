import 'package:flutter/material.dart';
import '../models/ai_agent_role.dart';
import '../theme/control_theme.dart';

class AiAgentCard extends StatelessWidget {
  const AiAgentCard({super.key, required this.agent});

  final AiAgentRole agent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ControlColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: ControlColors.teal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        agent.departmentName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ControlColors.teal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: '담당 역할',
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: agent.roles.map((role) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ControlColors.slate.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 10,
                        color: ControlColors.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            _Section(
              title: '오늘 시킬 수 있는 작업',
              child: Column(
                children: agent.todayTasks.map((task) {
                  return _Bullet(text: task);
                }).toList(),
              ),
            ),
            _Section(
              title: '최근 보고',
              child: Text(
                agent.recentReport,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
            _Section(
              title: '다음 추천 작업',
              child: Text(
                agent.nextRecommendation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ControlColors.teal,
                  fontSize: 12,
                ),
              ),
            ),
            if (agent.cautionNote != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ControlColors.warningBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ControlColors.accentWarm.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      size: 14,
                      color: ControlColors.accentWarm,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        agent.cautionNote!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: ControlColors.accentWarm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.send_outlined, size: 16),
              label: Text(
                agent.sampleCommand ?? '작업 지시 (샘플)',
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ControlColors.teal,
                side: const BorderSide(color: ControlColors.teal),
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 5, color: ControlColors.teal),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
