import 'package:flutter/material.dart';

import '../../models/design_system/design_system_catalog.dart';
import '../../theme/control_theme.dart';
import 'design_profile_option_card.dart';

/// Studio design direction selector — AI recommend default + A~E visual picks.
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
    final selected = catalog.byCode(selectedCode) ?? catalog.defaultProfile;
    final aiSelected = designSource == 'ai_recommended';
    final rec = catalog.byCode(recommendedCode) ?? catalog.defaultProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '디자인 방향',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '기본은 AI 추천입니다. 카드 미리보기로 A~E 성격 차이를 확인한 뒤 고르세요.',
          style: TextStyle(color: ControlColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Material(
          color: aiSelected ? const Color(0xFFECFEFF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('design_profile_ai_recommend'),
            onTap: onSelectAiRecommended,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: aiSelected
                      ? const Color(0xFF0D9488)
                      : ControlColors.border,
                  width: aiSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'AI 추천',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '프로필 ${rec.profileCode}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (aiSelected)
                        const Text(
                          '✓ 적용 중',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${rec.profileName} · ${rec.visualMood.isEmpty ? rec.profileDescription : rec.visualMood}',
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reason.isEmpty ? '맥락 기반 자동 추천' : reason,
                    style: TextStyle(
                      color: ControlColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final profiles = catalog.profiles.where((p) => p.isActive).toList();
            if (wide) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: profiles.map((p) {
                  final selectedNow =
                      !aiSelected &&
                      selectedCode.toUpperCase() == p.profileCode;
                  return SizedBox(
                    width: (constraints.maxWidth - 20) / 3,
                    child: DesignProfileOptionCard(
                      profile: p,
                      selected: selectedNow,
                      badge: p.profileCode == recommendedCode ? '추천' : null,
                      onTap: () => onSelectCode(p.profileCode),
                      compact: true,
                    ),
                  );
                }).toList(),
              );
            }
            return Column(
              children: profiles.map((p) {
                final selectedNow =
                    !aiSelected && selectedCode.toUpperCase() == p.profileCode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DesignProfileOptionCard(
                    profile: p,
                    selected: selectedNow,
                    badge: p.profileCode == recommendedCode ? '추천' : null,
                    onTap: () => onSelectCode(p.profileCode),
                    compact: true,
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ControlColors.sandLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ControlColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '현재 선택 · ${selected.profileCode} ${selected.profileName}'
                '${aiSelected ? ' (AI 추천)' : ' (직접 선택)'}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                selected.heroLabel.isEmpty
                    ? selected.previewHeadline
                    : selected.heroLabel,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'source · $designSource · DS v${catalog.designSystemVersion} · profile v${selected.version}',
                style: TextStyle(
                  fontSize: 11,
                  color: ControlColors.textSecondary,
                ),
              ),
              if (catalog.designQualityProfile['hooks'] is Map) ...[
                const SizedBox(height: 8),
                Text(
                  'preReviewQualityGate 준비됨 · 자동 루프 OFF'
                  ' · recommendedDesignProfile=${selected.profileCode}',
                  style: TextStyle(
                    fontSize: 11,
                    color: ControlColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
