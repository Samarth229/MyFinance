class FinancialSummary {
  final double totalCreated;
  final double totalPaid;
  final double totalRemaining;
  final int totalTransactions;
  final int completedTransactions;
  final int pendingTransactions;
  final double completionRate;
  final double debtRatio;

  const FinancialSummary({
    required this.totalCreated,
    required this.totalPaid,
    required this.totalRemaining,
    required this.totalTransactions,
    required this.completedTransactions,
    required this.pendingTransactions,
    required this.completionRate,
    required this.debtRatio,
  });
}