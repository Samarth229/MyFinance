class Person {
  final int? id;
  final String name;
  final String? phone;
  final String? upi;
  final DateTime createdAt;

  Person({
    this.id,
    required this.name,
    this.phone,
    this.upi,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'upi': upi,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      upi: map['upi'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}