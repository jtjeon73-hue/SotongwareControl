import 'package:flutter/material.dart';
import '../data/sample_operational_data.dart';
import '../widgets/control_section_title.dart';
import '../widgets/revenue_pipeline_card.dart';

class RevenueDashboardScreen extends StatelessWidget {
  const RevenueDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pipelines = SampleOperationalData.revenuePipelines;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ControlSectionTitle(
            title: '수익화 흐름 관리',
            subtitle: '사업별 대상 고객 · 수익 방식 · 현재 단계 · 필요 작업',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 340,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: pipelines.length,
                itemBuilder: (context, index) {
                  return RevenuePipelineCard(pipeline: pipelines[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
