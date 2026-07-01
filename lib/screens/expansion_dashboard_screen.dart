import 'package:flutter/material.dart';
import '../data/sample_operational_data.dart';
import '../widgets/control_section_title.dart';
import '../widgets/expansion_candidate_card.dart';

class ExpansionDashboardScreen extends StatelessWidget {
  const ExpansionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final candidates = SampleOperationalData.expansionCandidates;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ControlSectionTitle(
            title: '사업 확장 로드맵',
            subtitle: '신규 후보 · 우선순위 · 예상 수익성 · 필요 준비물',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 260,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  return ExpansionCandidateCard(candidate: candidates[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
