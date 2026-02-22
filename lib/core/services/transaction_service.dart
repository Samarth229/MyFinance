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
    final perPersonAmount =
        _splitService.calculateEqualSplit(totalAmount, persons.length);

    for (final person in persons) {
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
    final mapped = {
      for (var entry in personAmounts.entries)
        entry.key.name: entry.value
    };

    _splitService.calculateCustomSplit(totalAmount, mapped);

    for (final entry in personAmounts.entries) {
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
    final payment = Payment(
      transactionId: transactionId,
      amount: amount,
      createdAt: DateTime.now(),
    );

    await _transactionRepository.addPayment(payment);
  }
}