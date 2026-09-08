import 'package:flutter/material.dart';

import '../../models/design_system/design_system_catalog.dart';
import '../../theme/control_theme.dart';

Color _hex(String raw, [Color fallback = const Color(0xFF0F766E)]) {
  final cleaned = raw.trim().replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

/// Compact structural thumbnail that differs by profile code (not color-only).
class DesignProfileThumb extends StatelessWidget {
  const DesignProfileThumb({super.key, required this.profile, this.height = 72});

  final DesignProfile profile;
  final double height;

  @override
  Widget build(BuildContext context) {
    final primary = _hex(profile.primaryColor);
    final bg = _hex(
      profile.previewSwatches.length > 2
          ? profile.previewSwatches[2]
          : '#0F172A',
      const Color(0xFF0F172A),
    );
    final code = profile.profileCode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(code == 'C' ? 16 : 10),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: code == 'E' ? const Color(0xFF030712) : bg,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 8,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.12)),
              ),
              if (code == 'B')
                Positioned.fill(
                  child: CustomPaint(painter: _GridPainter(primary)),
                ),
              if (code == 'D')
                Positioned(
                  left: 14,
                  top: 22,
                  right: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 90,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 4,
                        width: 60,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ],
                  ),
                )
              else
                Positioned(
                  left: 10,
                  top: 18,
                  right: code == 'E' ? 70 : 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 5,
                        width: double.infinity,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 5,
                        width: 48,
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: code == 'C' ? 42 : 34,
                        decoration: BoxDecoration(
                          color: code == 'E' ? const Color(0xFFDB2777) : primary,
                          borderRadius: BorderRadius.circular(
                            code == 'C' ? 999 : 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (code != 'D')
                Positioned(
                  right: 10,
                  top: 16,
                  bottom: 10,
                  width: 64,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: code == 'E'
                          ? const Color(0xFFDB2777).withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        code == 'C' ? 18 : 8,
                      ),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: CustomPaint(painter: _NodePainter(primary)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePainter extends CustomPainter {
  _NodePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final line = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final a = Offset(size.width * 0.25, size.height * 0.3);
    final b = Offset(size.width * 0.7, size.height * 0.55);
    final c = Offset(size.width * 0.35, size.height * 0.78);
    canvas.drawLine(a, b, line);
    canvas.drawLine(b, c, line);
    canvas.drawCircle(a, 3, paint);
    canvas.drawCircle(b, 3, paint);
    canvas.drawCircle(c, 3, paint);
  }

  @override
  bool shouldRepaint(covariant _NodePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var x = 8.0; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 8.0; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Selectable A~E card used in studio + STEP15 design change.
class DesignProfileOptionCard extends StatelessWidget {
  const DesignProfileOptionCard({
    super.key,
    required this.profile,
    required this.selected,
    required this.onTap,
    this.badge,
    this.compact = false,
  });

  final DesignProfile profile;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = _hex(profile.primaryColor);
    return Material(
      color: selected ? const Color(0xFFF0FDFA) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('design_profile_card_${profile.profileCode}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF0D9488) : ControlColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    profile.profileCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.profileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '✓ 선택',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ControlColors.sandLight,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: ControlColors.border),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DesignProfileThumb(profile: profile, height: compact ? 56 : 72),
              const SizedBox(height: 8),
              Text(
                profile.visualMood.isNotEmpty
                    ? profile.visualMood
                    : profile.profileDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: ControlColors.textSecondary,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (profile.moodKeywords.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: profile.moodKeywords
                      .take(3)
                      .map(
                        (k) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            k,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '밀도 ${profile.densityLabel.isEmpty ? profile.contentDensity : profile.densityLabel}'
                ' · CTA ${profile.ctaTone.isEmpty ? '—' : profile.ctaTone}',
                style: TextStyle(
                  fontSize: 11,
                  color: ControlColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
