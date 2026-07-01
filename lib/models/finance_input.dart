class FinanceInput {
  const FinanceInput({
    this.expectedRevenue = 0,
    this.expectedExpense = 0,
    this.vatCheckNeeded = false,
    this.invoiceCheckMemo = '',
    this.expansionBudgetMemo = '',
  });

  final double expectedRevenue;
  final double expectedExpense;
  final bool vatCheckNeeded;
  final String invoiceCheckMemo;
  final String expansionBudgetMemo;

  double get expectedNetProfit => expectedRevenue - expectedExpense;

  FinanceInput copyWith({
    double? expectedRevenue,
    double? expectedExpense,
    bool? vatCheckNeeded,
    String? invoiceCheckMemo,
    String? expansionBudgetMemo,
  }) {
    return FinanceInput(
      expectedRevenue: expectedRevenue ?? this.expectedRevenue,
      expectedExpense: expectedExpense ?? this.expectedExpense,
      vatCheckNeeded: vatCheckNeeded ?? this.vatCheckNeeded,
      invoiceCheckMemo: invoiceCheckMemo ?? this.invoiceCheckMemo,
      expansionBudgetMemo: expansionBudgetMemo ?? this.expansionBudgetMemo,
    );
  }

  Map<String, dynamic> toJson() => {
    'expectedRevenue': expectedRevenue,
    'expectedExpense': expectedExpense,
    'vatCheckNeeded': vatCheckNeeded,
    'invoiceCheckMemo': invoiceCheckMemo,
    'expansionBudgetMemo': expansionBudgetMemo,
  };

  factory FinanceInput.fromJson(Map<String, dynamic> json) {
    return FinanceInput(
      expectedRevenue: (json['expectedRevenue'] as num?)?.toDouble() ?? 0,
      expectedExpense: (json['expectedExpense'] as num?)?.toDouble() ?? 0,
      vatCheckNeeded: json['vatCheckNeeded'] as bool? ?? false,
      invoiceCheckMemo: json['invoiceCheckMemo'] as String? ?? '',
      expansionBudgetMemo: json['expansionBudgetMemo'] as String? ?? '',
    );
  }
}
