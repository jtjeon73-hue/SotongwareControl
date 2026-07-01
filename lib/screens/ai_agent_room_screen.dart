import 'package:flutter/material.dart';
import '../data/sample_operational_data.dart';
import '../theme/control_theme.dart';
import '../widgets/ai_agent_card.dart';
import '../widgets/control_section_title.dart';

class AiAgentRoomScreen extends StatelessWidget {
  const AiAgentRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agents = SampleOperationalData.aiAgents;
    final reports = SampleOperationalData.aiReports;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ControlSectionTitle(
            title: 'AI 직원실',
            subtitle: '부서 AI에게 작업 지시 · 결과 보고 확인 (샘플, API 미연결)',
          ),
          ControlSectionTitle(
            title: '최근 AI 보고',
            subtitle: '${reports.length}건 보고 대기/확인',
          ),
          ...reports.map((report) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            report.aiName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (report.reportedAt != null)
                            Text(
                              report.reportedAt!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 11,
                                    color: ControlColors.textMuted,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '위험: ${report.risk}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: ControlColors.accentWarm,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '권장: ${report.recommendation}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: ControlColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          ControlSectionTitle(
            title: '부서별 AI',
            subtitle: '${agents.length}명 AI 직원 (샘플)',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100 ? 2 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 480,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  return AiAgentCard(agent: agents[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
