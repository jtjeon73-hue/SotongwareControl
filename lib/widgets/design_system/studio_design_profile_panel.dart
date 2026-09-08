import 'package:flutter/material.dart';

import '../../models/design_system/design_system_catalog.dart';
import '../../theme/control_theme.dart';

/// Studio design direction selector — AI recommend default + A~E manual pick.
class StudioDesignProfilePanel extends StatelessWidget {
  const StudioDesignProfilePanel({
    super.key,
    required this.catalog,
    required this.selectedCode,
    required this.recommendedCode,
    required this.designSource,
    required this.reason,
    required this.onSelectAiRecommended,
    required this.onSelectCode,
  });

  final DesignSystemCatalog catalog;
  final String selectedCode;
  final String recommendedCode;
  final String designSource;
  final String reason;
  final VoidCallback onSelectAiRecommended;
  final ValueChanged<String> onSelectCode;

  @override
  Widget build(BuildContext context) {
    final selected =
        catalog.byCode(selectedCode) ?? catalog.defaultProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '디자인 방향',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '기본은 AI 추천입니다. 필요할 때만 A~E를 직접 고르세요.',
          style: TextStyle(color: ControlColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('design_profile_ai_recommend'),
              label: Text('AI 추천 · $recommendedCode'),
              selected: designSource == 'ai_recommended',
              onSelected: (_) => onSelectAiRecommended(),
            ),
            ...catalog.profiles.where((p) => p.isActive).map((p) {
              final selectedNow =
                  designSource == 'user_selected' &&
                  selectedCode.toUpperCase() == p.profileCode;
              return ChoiceChip(
                key: Key('design_profile_${p.profileCode}'),
                label: Text('${p.profileCode} ${p.profileName}'),
                selected: selectedNow,
                onSelected: (_) => onSelectCode(p.profileCode),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ControlColors.sandLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(
                int.parse(
                  selected.primaryColor.replaceFirst('#', '0xFF'),
                ),
              ).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selected.profileCode} · ${selected.profileName}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(selected.profileDescription),
              const SizedBox(height: 8),
              Text(
                reason,
                style: TextStyle(
                  color: ControlColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: selected.previewSwatches
                    .map(
                      (c) => Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(c.replaceFirst('#', '0xFF')),
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),
              Text(
                selected.heroLabel.isEmpty
                    ? selected.previewHeadline
                    : selected.heroLabel,
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'source · $designSource · v${selected.version}',
                style: TextStyle(
                  fontSize: 11,
                  color: ControlColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
