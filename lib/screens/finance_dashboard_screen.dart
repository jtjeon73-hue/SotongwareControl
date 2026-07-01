import 'package:flutter/material.dart';
import '../data/sample_operational_data.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/finance_item_card.dart';

class FinanceDashboardScreen extends StatelessWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = SampleOperationalData.financeItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ControlSectionTitle(
            title: '재무 및 세금 관리',
            subtitle: '매출·비용·세무·예산·재테크·사업 확장 예산 (샘플)',
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ControlColors.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ControlColors.accentWarm.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: ControlColors.accentWarm,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '실제 세무 판단은 세무사 또는 전문가 확인이 필요합니다. '
                    '이 화면은 내부 점검 체크리스트용이며 실제 금액·세무 데이터는 저장하지 않습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: ControlColors.accentWarm,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
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
                  mainAxisExtent: 220,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return FinanceItemCard(item: items[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
