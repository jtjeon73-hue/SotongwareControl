import 'package:flutter/material.dart';
import '../data/promo_sites_data.dart';
import '../models/business_division.dart';
import '../models/promo_site_link.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import 'result_link_button.dart';

class BusinessStatusCard extends StatelessWidget {
  const BusinessStatusCard({
    super.key,
    required this.division,
    this.onTap,
    this.promoSite,
  });

  final BusinessDivision division;
  final VoidCallback? onTap;
  final PromoSiteLink? promoSite;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ControlColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.business_center_outlined,
                      color: ControlColors.teal,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: ControlColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                division.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                division.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: division.items.take(6).map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ControlColors.slate.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: ControlColors.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ControlColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ControlColors.teal.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  division.status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ControlColors.teal,
                    fontSize: 12,
                  ),
                ),
              ),
              if (promoSite != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ResultLinkButton(
                    url: ControlScope.of(context).promoUrlFor(promoSite!.id),
                    label: '프로모 사이트 보기',
                    style: ResultLinkStyle.outlined,
                    fullWidth: true,
                  ),
                ),
              ],
              if (division.id == 'app_development') ...[
                const SizedBox(height: 8),
                Text(
                  '개별 프로모 ${PromoSitesData.linkedAppPromoUrlCount}/${PromoSitesData.appPromoCount} URL 연결',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: ControlColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
