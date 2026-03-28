class Person {
  final int? id;
  final String name;
  final String? phone;
  final String? upi;
  final DateTime createdAt;
  final bool isTemporary;

  Person({
    this.id,
    required this.name,
    this.phone,
    this.upi,
    required this.createdAt,
    this.isTemporary = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'upi': upi,
      'created_at': createdAt.toIso8601String(),
      'is_temporary': isTemporary ? 1 : 0,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      upi: map['upi'],
      createdAt: DateTime.parse(map['created_at']),
      isTemporary: (map['is_temporary'] ?? 0) == 1,
    );
  }
}