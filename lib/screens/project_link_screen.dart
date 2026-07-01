import 'package:flutter/material.dart';
import '../data/sample_business_data.dart';
import '../models/project_item.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/project_link_card.dart';

class ProjectLinkScreen extends StatelessWidget {
  const ProjectLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final links = SampleBusinessData.projectLinks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ControlColors.charcoal,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ControlColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '프로젝트 링크맵',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '내부 총괄 사이트와 공개 홍보사이트·커머스 연결 관계를 관리합니다.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _LinkMapDiagram(),
          const SizedBox(height: 32),
          const ControlSectionTitle(
            title: '전체 프로젝트 링크',
            subtitle: 'URL은 추후 연결 예정',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 3
                  : constraints.maxWidth > 700
                  ? 2
                  : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 200,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: links.length,
                itemBuilder: (context, index) {
                  return ProjectLinkCard(item: links[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LinkMapDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _DiagramNode(
              label: 'SotongWare Control Center',
              type: ProjectLinkType.internal,
              isCenter: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: ControlColors.border),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '관리 · 연결',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: ControlColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: ControlColors.border),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _DiagramNode(
                  label: 'SotongAutomationPromo',
                  type: ProjectLinkType.publicPromo,
                ),
                _DiagramNode(
                  label: 'SotongAppsPromo',
                  type: ProjectLinkType.publicPromo,
                ),
                _DiagramNode(
                  label: 'SotongYouTubePromo',
                  type: ProjectLinkType.publicPromo,
                ),
                _DiagramNode(
                  label: 'SotongEbookPromo',
                  type: ProjectLinkType.publicPromo,
                ),
                _DiagramNode(
                  label: 'SotongWarehouse',
                  type: ProjectLinkType.commerce,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _DiagramNode(
                  label: 'SotongTravelPromo',
                  type: ProjectLinkType.publicPromo,
                  compact: true,
                ),
                _DiagramNode(
                  label: 'SotongSajuPromo',
                  type: ProjectLinkType.publicPromo,
                  compact: true,
                ),
                _DiagramNode(
                  label: 'FarmjigiPromo',
                  type: ProjectLinkType.publicPromo,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagramNode extends StatelessWidget {
  const _DiagramNode({
    required this.label,
    required this.type,
    this.isCenter = false,
    this.compact = false,
  });

  final String label;
  final ProjectLinkType type;
  final bool isCenter;
  final bool compact;

  Color get _color {
    switch (type) {
      case ProjectLinkType.internal:
        return ControlColors.teal;
      case ProjectLinkType.publicPromo:
        return ControlColors.accentWarm;
      case ProjectLinkType.commerce:
        return ControlColors.sandBeige;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: isCenter ? color.withValues(alpha: 0.15) : ControlColors.slate,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCenter ? color : ControlColors.border,
          width: isCenter ? 1.5 : 0.5,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isCenter ? color : ControlColors.textSecondary,
          fontWeight: isCenter ? FontWeight.w600 : FontWeight.normal,
          fontSize: compact ? 11 : 13,
        ),
      ),
    );
  }
}
