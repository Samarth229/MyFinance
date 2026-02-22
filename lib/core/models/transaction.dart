class TransactionModel {
  final int? id;
  final int personId;
  final String type;
  final double totalAmount;
  final double remainingAmount;
  final String status;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.personId,
    required this.type,
    required this.totalAmount,
    required this.remainingAmount,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'type': type,
      'total_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      personId: map['person_id'],
      type: map['type'],
      totalAmount: map['total_amount'],
      remainingAmount: map['remaining_amount'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}