import '../database/database_helper.dart';
import 'financial_summary.dart';
import 'person_report.dart';

class AnalyticsService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<FinancialSummary> getFinancialSummary() async {
    final db = await _databaseHelper.database;

    final totalCreatedResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total
      FROM transactions
    ''');

    final totalRemainingResult = await db.rawQuery('''
      SELECT SUM(remaining_amount) as total
      FROM transactions
    ''');

    final totalTransactionsResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM transactions
    ''');

    final completedTransactionsResult = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM transactions
      WHERE status = 'completed'
    ''');

    final pendingTransactionsResult = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM transactions
      WHERE status = 'pending'
    ''');

    final totalCreated =
        (totalCreatedResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final totalRemaining =
        (totalRemainingResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final totalPaid = totalCreated - totalRemaining;

    final totalTransactions =
        (totalTransactionsResult.first['count'] as num?)?.toInt() ?? 0;

    final completedTransactions =
        (completedTransactionsResult.first['count'] as num?)?.toInt() ?? 0;

    final pendingTransactions =
        (pendingTransactionsResult.first['count'] as num?)?.toInt() ?? 0;

    final completionRate =
        totalCreated == 0 ? 0.0 : (totalPaid / totalCreated) * 100;

    final debtRatio =
        totalCreated == 0 ? 0.0 : totalRemaining / totalCreated;

    return FinancialSummary(
      totalCreated: totalCreated,
      totalPaid: totalPaid,
      totalRemaining: totalRemaining,
      totalTransactions: totalTransactions,
      completedTransactions: completedTransactions,
      pendingTransactions: pendingTransactions,
      completionRate: completionRate,
      debtRatio: debtRatio,
    );
  }

  Future<List<PersonReport>> getPersonReports() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        p.id as person_id,
        p.name as name,
        SUM(t.total_amount) as total_created,
        SUM(t.remaining_amount) as total_remaining,
        COUNT(t.id) as transaction_count
      FROM persons p
      LEFT JOIN transactions t
      ON p.id = t.person_id
      GROUP BY p.id
    ''');

    return result.map((row) {
      final totalCreated =
          (row['total_created'] as num?)?.toDouble() ?? 0.0;

      final totalRemaining =
          (row['total_remaining'] as num?)?.toDouble() ?? 0.0;

      final totalPaid = totalCreated - totalRemaining;

      final completionRate =
          totalCreated == 0 ? 0.0 : (totalPaid / totalCreated) * 100;

      return PersonReport(
        personId: row['person_id'] as int,
        name: row['name'] as String,
        totalCreated: totalCreated,
        totalPaid: totalPaid,
        totalRemaining: totalRemaining,
        transactionCount:
            (row['transaction_count'] as num?)?.toInt() ?? 0,
        completionRate: completionRate,
      );
    }).toList();
  }

  Future<Map<String, double>> getMonthlyTotals() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        substr(created_at, 1, 7) as month,
        SUM(total_amount) as total
      FROM transactions
      GROUP BY month
      ORDER BY month ASC
    ''');

    final Map<String, double> monthlyData = {};

    for (final row in result) {
      final month = row['month'] as String;
      final total =
          (row['total'] as num?)?.toDouble() ?? 0.0;

      monthlyData[month] = total;
    }

    return monthlyData;
  }
}