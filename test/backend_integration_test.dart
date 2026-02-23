import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:myfinance/core/services/transaction_service.dart';
import 'package:myfinance/core/analytics/analytics_service.dart';
import 'package:myfinance/core/models/person.dart';
import 'package:myfinance/core/repositories/person_repository.dart';
import 'package:myfinance/core/database/database_helper.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  TestWidgetsFlutterBinding.ensureInitialized();

  late TransactionService transactionService;
  late AnalyticsService analyticsService;
  late PersonRepository personRepository;
  late DatabaseHelper databaseHelper;

  Future<void> clearTables() async {
    final db = await databaseHelper.database;
    await db.delete('payments');
    await db.delete('transactions');
    await db.delete('persons');
  }

  Future<int> getLatestTransactionId() async {
    final db = await databaseHelper.database;
    final result = await db.query(
      'transactions',
      orderBy: 'id DESC',
      limit: 1,
    );
    return result.first['id'] as int;
  }

  setUp(() async {
    transactionService = TransactionService();
    analyticsService = AnalyticsService();
    personRepository = PersonRepository();
    databaseHelper = DatabaseHelper();
    await clearTables();
  });

  group("Industry-Level Backend Tests", () {

    test("Equal Split distributes correctly", () async {
      final a = Person(name: "A", createdAt: DateTime.now());
      final b = Person(name: "B", createdAt: DateTime.now());

      final idA = await personRepository.insertPerson(a);
      final idB = await personRepository.insertPerson(b);

      await transactionService.createEqualSplit(
        totalAmount: 200,
        persons: [
          Person(id: idA, name: "A", createdAt: a.createdAt),
          Person(id: idB, name: "B", createdAt: b.createdAt),
        ],
        type: 'split',
      );

      final summary = await analyticsService.getFinancialSummary();

      expect(summary.totalCreated, 200);
      expect(summary.totalRemaining, 200);
    });

    test("Partial Payment updates remaining", () async {
      final p = Person(name: "A", createdAt: DateTime.now());
      final id = await personRepository.insertPerson(p);

      await transactionService.createEqualSplit(
        totalAmount: 100,
        persons: [Person(id: id, name: "A", createdAt: p.createdAt)],
        type: 'split',
      );

      final transactionId = await getLatestTransactionId();

      await transactionService.recordPayment(
        transactionId: transactionId,
        amount: 40,
      );

      final summary = await analyticsService.getFinancialSummary();

      expect(summary.totalPaid, 40);
      expect(summary.totalRemaining, 60);
    });

    test("Full Payment marks completed", () async {
      final p = Person(name: "A", createdAt: DateTime.now());
      final id = await personRepository.insertPerson(p);

      await transactionService.createEqualSplit(
        totalAmount: 100,
        persons: [Person(id: id, name: "A", createdAt: p.createdAt)],
        type: 'split',
      );

      final transactionId = await getLatestTransactionId();

      await transactionService.recordPayment(
        transactionId: transactionId,
        amount: 100,
      );

      final summary = await analyticsService.getFinancialSummary();

      expect(summary.totalRemaining, 0);
      expect(summary.completedTransactions, 1);
    });

    test("Overpayment blocked", () async {
      final p = Person(name: "A", createdAt: DateTime.now());
      final id = await personRepository.insertPerson(p);

      await transactionService.createEqualSplit(
        totalAmount: 100,
        persons: [Person(id: id, name: "A", createdAt: p.createdAt)],
        type: 'split',
      );

      final transactionId = await getLatestTransactionId();

      expect(
        () async => await transactionService.recordPayment(
          transactionId: transactionId,
          amount: 150,
        ),
        throwsException,
      );
    });

    test("Invalid transaction type blocked", () async {
      final p = Person(name: "A", createdAt: DateTime.now());
      final id = await personRepository.insertPerson(p);

      expect(
        () async => await transactionService.createEqualSplit(
          totalAmount: 100,
          persons: [Person(id: id, name: "A", createdAt: p.createdAt)],
          type: 'invalid',
        ),
        throwsException,
      );
    });

    test("Custom split invalid sum blocked", () async {
      final a = Person(name: "A", createdAt: DateTime.now());
      final b = Person(name: "B", createdAt: DateTime.now());

      final idA = await personRepository.insertPerson(a);
      final idB = await personRepository.insertPerson(b);

      expect(
        () async => await transactionService.createCustomSplit(
          totalAmount: 100,
          personAmounts: {
            Person(id: idA, name: "A", createdAt: a.createdAt): 80,
            Person(id: idB, name: "B", createdAt: b.createdAt): 50,
          },
          type: 'split',
        ),
        throwsException,
      );
    });

    test("Analytics formulas correct", () async {
      final p = Person(name: "A", createdAt: DateTime.now());
      final id = await personRepository.insertPerson(p);

      await transactionService.createEqualSplit(
        totalAmount: 200,
        persons: [Person(id: id, name: "A", createdAt: p.createdAt)],
        type: 'split',
      );

      final transactionId = await getLatestTransactionId();

      await transactionService.recordPayment(
        transactionId: transactionId,
        amount: 50,
      );

      final summary = await analyticsService.getFinancialSummary();

      expect(summary.totalCreated, 200);
      expect(summary.totalPaid, 50);
      expect(summary.totalRemaining, 150);

      expect(summary.completionRate, 25);
    });
  });
}