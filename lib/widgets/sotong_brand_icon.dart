import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

/// 소통총관제 · 소통웨어 공식 브랜드 로고
class SotongBrandIcon extends StatelessWidget {
  const SotongBrandIcon({
    super.key,
    this.size = 40,
    this.padding = 0,
    this.compact = false,
  });

  static const assetPath = 'assets/images/sotong_control_logo.png';

  final double size;
  final double padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final box = compact ? size : size;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        child: Image.asset(
          assetPath,
          width: box,
          height: box,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, error, stackTrace) => Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
              color: ControlColors.tealSoft,
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
            ),
            child: Icon(
              Icons.hub_rounded,
              color: ControlColors.teal,
              size: box * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
