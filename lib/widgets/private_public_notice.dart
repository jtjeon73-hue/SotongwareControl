import 'package:flutter/material.dart';

import '../data/promo_sites_data.dart';
import '../theme/control_theme.dart';

class PrivatePublicNotice extends StatelessWidget {
  const PrivatePublicNotice({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            compact ? Icons.info_outline : Icons.shield_outlined,
            size: compact ? 14 : 16,
            color: ControlColors.accentWarm,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              PromoSitesData.privatePublicNotice,
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
