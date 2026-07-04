import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

/// 소통총관제 · 소통웨어 브랜드 상징 아이콘
/// (연결 허브 = 소통 + 총괄 관제)
class SotongBrandIcon extends StatelessWidget {
  const SotongBrandIcon({
    super.key,
    this.size = 22,
    this.padding = 9,
    this.compact = false,
  });

  final double size;
  final double padding;
  final bool compact;

  static const IconData icon = Icons.hub_rounded;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ControlColors.tealSoft, ControlColors.sandLight],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ControlColors.teal.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: ControlColors.teal.withValues(alpha: 0.12),
            blurRadius: compact ? 4 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: ControlColors.teal, size: size),
    );
  }
}
