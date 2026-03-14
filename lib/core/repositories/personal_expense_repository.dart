import '../database/database_helper.dart';
import '../models/personal_expense.dart';

class PersonalExpenseRepository {
  final _db = DatabaseHelper();

  Future<int> insert(PersonalExpense expense) async {
    final db = await _db.database;
    return db.insert('personal_expenses', expense.toMap());
  }

  Future<List<PersonalExpense>> getAll() async {
    final db = await _db.database;
    final maps =
        await db.query('personal_expenses', orderBy: 'created_at DESC');
    return maps.map((m) => PersonalExpense.fromMap(m)).toList();
  }

  Future<double> getTotalAmount() async {
    final db = await _db.database;
    final result = await db
        .rawQuery('SELECT SUM(amount) as total FROM personal_expenses');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getThisMonthAmount() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String();
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM personal_expenses WHERE created_at >= ?',
      [start],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Returns last 6 months data grouped as:
  /// { 'Mar 2026': { 'Transport': { 'descriptions': ['Auto', 'Bus'], 'total': 450.0 } } }
  Future<Map<String, Map<String, CategoryData>>> getLast6MonthsGrouped() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 5, 1).toIso8601String();

    final rows = await db.rawQuery(
      'SELECT * FROM personal_expenses WHERE created_at >= ? ORDER BY created_at ASC',
      [start],
    );

    final expenses = rows.map((m) => PersonalExpense.fromMap(m)).toList();

    // Build ordered list of 6 month keys
    final monthKeys = <String>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      monthKeys.add(_monthKey(d));
    }

    final result = <String, Map<String, CategoryData>>{};
    for (final key in monthKeys) {
      result[key] = {};
    }

    for (final e in expenses) {
      final key = _monthKey(e.createdAt);
      if (!result.containsKey(key)) continue;

      // Self split expenses are handled separately in the PDF
      if (e.source == 'split_self' || e.source == 'partial_self') continue;

      final categoryLabel = e.category ?? _sourceLabel(e.source);
      final desc = (e.description != null && e.description!.isNotEmpty)
          ? e.description!
          : categoryLabel;

      result[key]!.putIfAbsent(categoryLabel, () => CategoryData());
      result[key]![categoryLabel]!.total += e.amount;
      if (!result[key]![categoryLabel]!.descriptions.contains(desc)) {
        result[key]![categoryLabel]!.descriptions.add(desc);
      }
    }

    return result;
  }

  /// Returns self split totals grouped by month key for last 6 months.
  /// Includes split_self and partial_self sources.
  Future<Map<String, double>> getSelfAmountsByMonth() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 5, 1).toIso8601String();

    final rows = await db.rawQuery(
      "SELECT * FROM personal_expenses WHERE created_at >= ? AND source IN ('split_self', 'partial_self') ORDER BY created_at ASC",
      [start],
    );

    final result = <String, double>{};
    for (final row in rows) {
      final e = PersonalExpense.fromMap(row);
      final key = _monthKey(e.createdAt);
      result[key] = (result[key] ?? 0) + e.amount;
    }
    return result;
  }

  String _monthKey(DateTime d) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'gpay_self': return 'GPay';
      case 'split_self': return 'Split (self)';
      case 'partial_self': return 'Split (partial)';
      default: return 'Others';
    }
  }
}

class CategoryData {
  double total = 0;
  List<String> descriptions = [];
}
