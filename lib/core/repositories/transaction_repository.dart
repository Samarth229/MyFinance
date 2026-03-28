import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../exceptions/app_exceptions.dart';

class TransactionRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<int> createTransaction(TransactionModel transaction) async {
    final db = await _databaseHelper.database;
    try {
      return await db.insert('transactions', transaction.toMap());
    } catch (e) {
      throw const AppDatabaseException("Failed to create transaction");
    }
  }

  Future<void> createMultipleTransactions(
      List<TransactionModel> transactions) async {
    if (transactions.isEmpty) {
      throw const ValidationException("Transaction list cannot be empty");
    }

    final db = await _databaseHelper.database;

    try {
      await db.transaction((txn) async {
        for (final transaction in transactions) {
          await txn.insert('transactions', transaction.toMap());
        }
      });
    } catch (e) {
      throw const AppDatabaseException("Failed to create multiple transactions");
    }
  }

  Future<void> addPayment(Payment payment) async {
    if (payment.amount <= 0) {
      throw const ValidationException("Payment amount must be greater than 0");
    }

    final db = await _databaseHelper.database;

    try {
      await db.transaction((txn) async {
        final transactionResult = await txn.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [payment.transactionId],
        );

        if (transactionResult.isEmpty) {
          throw const NotFoundException("Transaction not found");
        }

        final transaction = TransactionModel.fromMap(transactionResult.first);

        if (transaction.status == 'completed') {
          throw const BusinessLogicException("Transaction already completed");
        }

        if (payment.amount > transaction.remainingAmount) {
          throw const BusinessLogicException("Payment exceeds remaining amount");
        }

        await txn.insert('payments', payment.toMap());

        final newRemaining = transaction.remainingAmount - payment.amount;
        final newStatus = newRemaining <= 0 ? 'completed' : 'pending';

        await txn.update(
          'transactions',
          {'remaining_amount': newRemaining, 'status': newStatus},
          where: 'id = ?',
          whereArgs: [transaction.id],
        );
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppDatabaseException("Payment operation failed");
    }
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await _databaseHelper.database;
    final result =
        await db.query('transactions', orderBy: 'created_at DESC');
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByPersonId(
      int personId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'transactions',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await _databaseHelper.database;
    final result =
        await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) return TransactionModel.fromMap(result.first);
    return null;
  }

  Future<List<Payment>> getPaymentsByTransactionId(
      int transactionId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'payments',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Payment.fromMap(map)).toList();
  }

  /// Returns pending transactions for [personId] whose type is in [types],
  /// ordered oldest-first (for repayment application).
  Future<List<TransactionModel>> getPendingByPersonAndTypes(
      int personId, List<String> types) async {
    final db = await _databaseHelper.database;
    final placeholders = types.map((_) => '?').join(', ');
    final result = await db.query(
      'transactions',
      where: 'person_id = ? AND type IN ($placeholders) AND status = ?',
      whereArgs: [personId, ...types, 'pending'],
      orderBy: 'created_at ASC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _databaseHelper.database;
    try {
      await db.transaction((txn) async {
        await txn.delete('payments',
            where: 'transaction_id = ?', whereArgs: [id]);
        await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw const AppDatabaseException("Failed to delete transaction");
    }
  }

  /// Updates remaining_amount and status of a single transaction.
  Future<void> updateTransactionRemaining(
      int id, double newRemaining, String newStatus) async {
    final db = await _databaseHelper.database;
    await db.update(
      'transactions',
      {'remaining_amount': newRemaining, 'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
