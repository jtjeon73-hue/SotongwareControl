import 'package:flutter/material.dart';
import '../data/sample_operational_data.dart';
import '../widgets/business_issue_card.dart';
import '../widgets/control_section_title.dart';

class IssuesDashboardScreen extends StatelessWidget {
  const IssuesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final issues = SampleOperationalData.businessIssues;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ControlSectionTitle(
            title: '문제점 파악 및 대응',
            subtitle: '사업부별 현재 문제 · 원인 · 대응 방안 · 담당 AI · 다음 액션',
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: issues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return BusinessIssueCard(issue: issues[index]);
            },
          ),
        ],
      ),
    );
  }
}
