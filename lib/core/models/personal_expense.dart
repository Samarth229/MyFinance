class PersonalExpense {
  final int? id;
  final double amount;
  final String source; // 'gpay_self', 'split_self', 'partial_self', 'direct'
  final String? description;
  final String? category; // 'Transport', 'Food', 'Family', 'Accessories', 'Others'
  final DateTime createdAt;

  PersonalExpense({
    this.id,
    required this.amount,
    required this.source,
    this.description,
    this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'source': source,
        'description': description,
        'category': category,
        'created_at': createdAt.toIso8601String(),
      };

  factory PersonalExpense.fromMap(Map<String, dynamic> map) => PersonalExpense(
        id: map['id'],
        amount: map['amount'] as double,
        source: map['source'] as String,
        description: map['description'] as String?,
        category: map['category'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
