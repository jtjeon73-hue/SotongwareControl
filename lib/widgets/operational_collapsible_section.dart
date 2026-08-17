import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

/// 운영 화면에서 긴 블록을 기본 접힘으로 제공.
class OperationalCollapsibleSection extends StatelessWidget {
  const OperationalCollapsibleSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
    this.sectionKey,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;
  final Key? sectionKey;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Card(
        key: sectionKey,
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textMuted,
                    height: 1.3,
                  ),
                ),
          children: [child],
        ),
      ),
    );
  }
}
