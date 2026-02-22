import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/payment.dart';

class TransactionRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<int> createTransaction(TransactionModel transaction) async {
    final db = await _databaseHelper.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<void> createMultipleTransactions(
      List<TransactionModel> transactions) async {
    final db = await _databaseHelper.database;

    if (transactions.isEmpty) {
      throw Exception("Transaction list cannot be empty");
    }

    await db.transaction((txn) async {
      for (final transaction in transactions) {
        await txn.insert('transactions', transaction.toMap());
      }
    });
  }

  Future<List<TransactionModel>> getTransactionsByPerson(int personId) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'transactions',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'created_at DESC',
    );

    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<void> addPayment(Payment payment) async {
    final db = await _databaseHelper.database;

    if (payment.amount <= 0) {
      throw Exception("Payment amount must be greater than 0");
    }

    await db.transaction((txn) async {
      final transactionResult = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [payment.transactionId],
      );

      if (transactionResult.isEmpty) {
        throw Exception("Transaction not found");
      }

      final transaction =
          TransactionModel.fromMap(transactionResult.first);

      if (transaction.status == 'completed') {
        throw Exception("Transaction already completed");
      }

      if (payment.amount > transaction.remainingAmount) {
        throw Exception("Payment exceeds remaining amount");
      }

      await txn.insert('payments', payment.toMap());

      final newRemaining =
          transaction.remainingAmount - payment.amount;

      final newStatus =
          newRemaining <= 0 ? 'completed' : 'pending';

      await txn.update(
        'transactions',
        {
          'remaining_amount': newRemaining,
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    });
  }

  Future<double> getTotalPendingForPerson(int personId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT SUM(remaining_amount) as total
      FROM transactions
      WHERE person_id = ? AND status = 'pending'
    ''', [personId]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Payment>> getPaymentsForTransaction(int transactionId) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'payments',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'created_at DESC',
    );

    return result.map((map) => Payment.fromMap(map)).toList();
  }
}