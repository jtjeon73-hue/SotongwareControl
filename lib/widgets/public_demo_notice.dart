import 'package:flutter/material.dart';

import '../data/promo_sites_data.dart';
import '../theme/control_theme.dart';

/// 비공개 관제 시스템 컨셉 데모임을 안내하는 배너 (샘플 데이터).
class PublicDemoNotice extends StatelessWidget {
  const PublicDemoNotice({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            compact ? Icons.info_outline : Icons.public_outlined,
            size: compact ? 14 : 16,
            color: ControlColors.teal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              PromoSitesData.publicDemoNotice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: compact ? 11 : 12,
                color: ControlColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
