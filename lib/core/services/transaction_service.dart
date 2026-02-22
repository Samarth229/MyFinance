import '../models/person.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../repositories/transaction_repository.dart';
import '../services/split_service.dart';

class TransactionService {
  final TransactionRepository _transactionRepository =
      TransactionRepository();

  final SplitService _splitService = SplitService();

  Future<void> createEqualSplit({
    required double totalAmount,
    required List<Person> persons,
    required String type,
  }) async {
    if (totalAmount <= 0) {
      throw Exception("Total amount must be greater than 0");
    }

    if (persons.isEmpty) {
      throw Exception("Person list cannot be empty");
    }

    if (type != 'loan' && type != 'split') {
      throw Exception("Invalid transaction type");
    }

    final uniqueIds = persons.map((p) => p.id).toSet();
    if (uniqueIds.length != persons.length) {
      throw Exception("Duplicate persons detected");
    }

    final perPersonAmount =
        _splitService.calculateEqualSplit(totalAmount, persons.length);

    for (final person in persons) {
      if (person.id == null) {
        throw Exception(
            "Person must be saved before creating transaction");
      }

      final transaction = TransactionModel(
        personId: person.id!,
        totalAmount: perPersonAmount,
        remainingAmount: perPersonAmount,
        type: type,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _transactionRepository.createTransaction(transaction);
    }
  }

  Future<void> createCustomSplit({
    required double totalAmount,
    required Map<Person, double> personAmounts,
    required String type,
  }) async {
    if (totalAmount <= 0) {
      throw Exception("Total amount must be greater than 0");
    }

    if (personAmounts.isEmpty) {
      throw Exception("At least one person must be assigned");
    }

    if (type != 'loan' && type != 'split') {
      throw Exception("Invalid transaction type");
    }

    final uniqueIds = personAmounts.keys.map((p) => p.id).toSet();
    if (uniqueIds.length != personAmounts.length) {
      throw Exception("Duplicate persons detected");
    }

    final mapped = {
      for (var entry in personAmounts.entries)
        entry.key.name: entry.value
    };

    _splitService.calculateCustomSplit(totalAmount, mapped);

    for (final entry in personAmounts.entries) {
      if (entry.key.id == null) {
        throw Exception(
            "Person must be saved before creating transaction");
      }

      if (entry.value <= 0) {
        throw Exception("Split amount must be greater than 0");
      }

      final transaction = TransactionModel(
        personId: entry.key.id!,
        totalAmount: entry.value,
        remainingAmount: entry.value,
        type: type,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _transactionRepository.createTransaction(transaction);
    }
  }

  Future<void> recordPayment({
    required int transactionId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw Exception("Payment amount must be greater than 0");
    }

    await _transactionRepository.addPayment(
      Payment(
        transactionId: transactionId,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
  }
}