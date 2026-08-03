import 'package:flutter/material.dart';
import '../theme/control_theme.dart';

class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final Widget? trailing;

  /// 세로 공간을 줄인 소개 영역 (사업 기획 탭 등).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 28,
        vertical: compact ? 12 : 28,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ControlColors.heroGradientStart,
            ControlColors.heroGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ControlColors.tealSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ControlColors.teal,
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final textContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: compact
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: compact ? 4 : 10),
                  Text(
                    subtitle,
                    style: compact
                        ? Theme.of(context).textTheme.bodyMedium
                        : Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              );

              if (trailing == null) return textContent;

              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textContent,
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerLeft, child: trailing!),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: textContent),
                  const SizedBox(width: 16),
                  trailing!,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
