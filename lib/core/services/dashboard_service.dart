import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class DashboardService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<double> getTotalPending() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT SUM(remaining_amount) as total
      FROM transactions
      WHERE status = 'pending'
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalCompleted() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT SUM(total_amount) as total
      FROM transactions
      WHERE status = 'completed'
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getPendingTransactionCount() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM transactions
      WHERE status = 'pending'
    ''');

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getPendingPeopleCount() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT person_id) as count
      FROM transactions
      WHERE status = 'pending'
    ''');

    return (result.first['count'] as int?) ?? 0;
  }
}