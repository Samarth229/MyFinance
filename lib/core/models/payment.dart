class Payment {
  final int? id;
  final int transactionId;
  final double amount;
  final DateTime createdAt;

  Payment({
    this.id,
    required this.transactionId,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      transactionId: map['transaction_id'],
      amount: map['amount'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}