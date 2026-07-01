import 'package:flutter/material.dart';
import '../data/sample_operational_data.dart';
import '../widgets/control_section_title.dart';
import '../widgets/promotion_channel_card.dart';

class PromotionDashboardScreen extends StatelessWidget {
  const PromotionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sites = SampleOperationalData.promoSites;
    final channels = SampleOperationalData.promotionChannels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ControlSectionTitle(
            title: '지속 영업 및 홍보 관리',
            subtitle: '홍보사이트 · 프로모 링크 · 제안서 · 채널별 홍보 액션',
          ),
          const ControlSectionTitle(
            title: '홍보사이트 제작 현황',
            subtitle: '프로젝트별 프로모 사이트 상태',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1000
                  ? 3
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 150,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: sites.length,
                itemBuilder: (context, index) {
                  return PromoSiteCard(site: sites[index]);
                },
              );
            },
          ),
          const SizedBox(height: 32),
          const ControlSectionTitle(
            title: '영업·홍보 채널 현황',
            subtitle: '제안서 · 문의 · 온라인 채널 · 다음 홍보 액션',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 160,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  return PromotionChannelCard(channel: channels[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
