import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sample_operational_data.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/finance_item_card.dart';

class FinanceDashboardScreen extends StatelessWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);
    final checklistItems = SampleOperationalData.financeItems;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final finance = state.finance;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ControlSectionTitle(
                title: '재무 및 세금 (데모)',
                subtitle: '샘플 입력 · 브라우저 저장 · 비전 소개용',
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ControlColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ControlColors.accentWarm.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  '표시·입력 값은 모두 데모용 샘플입니다. 실제 세무 판단은 전문가 확인이 필요하며, '
                  '홈택스 로그인·실제 세무·매출 데이터는 저장하지 않습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: ControlColors.accentWarm,
                    height: 1.4,
                  ),
                ),
              ),
              _FinanceInputPanel(
                revenue: finance.expectedRevenue,
                expense: finance.expectedExpense,
                netProfit: finance.expectedNetProfit,
                vatCheckNeeded: finance.vatCheckNeeded,
                invoiceMemo: finance.invoiceCheckMemo,
                expansionMemo: finance.expansionBudgetMemo,
                onChanged: (revenue, expense, vat, invoice, expansion) {
                  state.updateFinance(
                    finance.copyWith(
                      expectedRevenue: revenue,
                      expectedExpense: expense,
                      vatCheckNeeded: vat,
                      invoiceCheckMemo: invoice,
                      expansionBudgetMemo: expansion,
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const ControlSectionTitle(
                title: '재무 점검 체크리스트',
                subtitle: '참고용 샘플 카드',
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
                    itemCount: checklistItems.length,
                    itemBuilder: (context, index) {
                      return FinanceItemCard(item: checklistItems[index]);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FinanceInputPanel extends StatefulWidget {
  const _FinanceInputPanel({
    required this.revenue,
    required this.expense,
    required this.netProfit,
    required this.vatCheckNeeded,
    required this.invoiceMemo,
    required this.expansionMemo,
    required this.onChanged,
  });

  final double revenue;
  final double expense;
  final double netProfit;
  final bool vatCheckNeeded;
  final String invoiceMemo;
  final String expansionMemo;
  final void Function(
    double revenue,
    double expense,
    bool vat,
    String invoice,
    String expansion,
  )
  onChanged;

  @override
  State<_FinanceInputPanel> createState() => _FinanceInputPanelState();
}

class _FinanceInputPanelState extends State<_FinanceInputPanel> {
  late final TextEditingController _revenue;
  late final TextEditingController _expense;
  late final TextEditingController _invoice;
  late final TextEditingController _expansion;
  late bool _vat;

  @override
  void initState() {
    super.initState();
    _revenue = TextEditingController(
      text: widget.revenue > 0 ? widget.revenue.toStringAsFixed(0) : '',
    );
    _expense = TextEditingController(
      text: widget.expense > 0 ? widget.expense.toStringAsFixed(0) : '',
    );
    _invoice = TextEditingController(text: widget.invoiceMemo);
    _expansion = TextEditingController(text: widget.expansionMemo);
    _vat = widget.vatCheckNeeded;
  }

  @override
  void didUpdateWidget(covariant _FinanceInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revenue != widget.revenue && widget.revenue == 0) {
      _revenue.text = '';
    }
    if (oldWidget.expense != widget.expense && widget.expense == 0) {
      _expense.text = '';
    }
  }

  @override
  void dispose() {
    _revenue.dispose();
    _expense.dispose();
    _invoice.dispose();
    _expansion.dispose();
    super.dispose();
  }

  double get _revenueVal => double.tryParse(_revenue.text) ?? 0;
  double get _expenseVal => double.tryParse(_expense.text) ?? 0;
  double get _net => _revenueVal - _expenseVal;

  void _notify() {
    widget.onChanged(
      _revenueVal,
      _expenseVal,
      _vat,
      _invoice.text,
      _expansion.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이번 달 기초 입력', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth > 700;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _leftFields()),
                          const SizedBox(width: 20),
                          Expanded(child: _rightFields()),
                        ],
                      )
                    : Column(
                        children: [
                          _leftFields(),
                          const SizedBox(height: 12),
                          _rightFields(),
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ControlColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ControlColors.teal.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    color: ControlColors.teal,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '예상 순이익: ${_net.toStringAsFixed(0)}원',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: ControlColors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftFields() {
    return Column(
      children: [
        TextField(
          controller: _revenue,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '이번 달 예상 매출 (원)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _expense,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '이번 달 예상 비용 (원)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notify(),
        ),
      ],
    );
  }

  Widget _rightFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('부가세 확인 필요'),
          value: _vat,
          onChanged: (v) {
            setState(() => _vat = v);
            _notify();
          },
        ),
        TextField(
          controller: _invoice,
          decoration: const InputDecoration(
            labelText: '세금계산서 확인 메모',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _expansion,
          decoration: const InputDecoration(
            labelText: '사업 확장 예산 메모',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (_) => _notify(),
        ),
      ],
    );
  }
}
