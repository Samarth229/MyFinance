class PersonReport {
  final int personId;
  final String name;
  final double totalCreated;
  final double totalPaid;
  final double totalRemaining;
  final int transactionCount;
  final double completionRate;

  const PersonReport({
    required this.personId,
    required this.name,
    required this.totalCreated,
    required this.totalPaid,
    required this.totalRemaining,
    required this.transactionCount,
    required this.completionRate,
  });
}