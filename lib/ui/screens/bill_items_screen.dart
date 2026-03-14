import 'package:flutter/material.dart';
import '../../core/models/person.dart';
import '../../core/models/personal_expense.dart';
import '../../core/repositories/person_repository.dart';
import '../../core/repositories/personal_expense_repository.dart';
import '../../core/services/transaction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/person_picker_popup.dart';

class BillItemEntry {
  String name;
  double basePrice;
  List<PersonAssignment> assignments;
  bool selfIncluded;

  BillItemEntry({
    this.name = '',
    this.basePrice = 0,
    List<PersonAssignment>? assignments,
    this.selfIncluded = false,
  }) : assignments = assignments ?? [];
}

class BillItemsScreen extends StatefulWidget {
  final String type;
  final List<BillItemEntry>? initialItems;

  const BillItemsScreen({
    super.key,
    required this.type,
    this.initialItems,
  });

  @override
  State<BillItemsScreen> createState() => _BillItemsScreenState();
}

class _BillItemsScreenState extends State<BillItemsScreen> {
  final _personRepo = PersonRepository();
  final _txnService = TransactionService();
  final _personalRepo = PersonalExpenseRepository();
  late List<BillItemEntry> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems?.isNotEmpty == true
        ? widget.initialItems!
        : [BillItemEntry()];
  }

  double get _total => _items.fold(0, (sum, item) {
        final totalQty =
            item.assignments.fold(0.0, (s, a) => s + a.quantity);
        return sum + item.basePrice * totalQty;
      });

  void _addItem() => setState(() => _items.add(BillItemEntry()));

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() => _items.removeAt(index));
  }

  Future<void> _assignPeople(int index) async {
    final result = await showPersonPickerWithSelf(
      context,
      existing: _items[index].assignments,
      selfSelected: _items[index].selfIncluded,
    );
    if (result != null) {
      setState(() {
        _items[index].assignments = result.assignments;
        _items[index].selfIncluded = result.selfIncluded;
      });
    }
  }

  Future<void> _update() async {
    for (final item in _items) {
      if (item.name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fill in all item names'),
              backgroundColor: Colors.orange),
        );
        return;
      }
      if (item.basePrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All item prices must be greater than 0'),
              backgroundColor: Colors.orange),
        );
        return;
      }
    }

    final Map<String, _PersonTotal> totals = {};
    double selfTotal = 0.0;

    for (final item in _items) {
      final friendsQty =
          item.assignments.fold(0.0, (s, a) => s + a.quantity);
      final totalQty = friendsQty + (item.selfIncluded ? 1.0 : 0.0);
      if (totalQty == 0) continue;

      // Divide item price proportionally among all participants (friends + self)
      for (final a in item.assignments) {
        final share = item.basePrice * a.quantity / totalQty;
        final key = a.person.id?.toString() ?? a.person.name;
        if (totals.containsKey(key)) {
          totals[key]!.amount += share;
        } else {
          totals[key] = _PersonTotal(a.person, share);
        }
      }
      if (item.selfIncluded) {
        selfTotal += item.basePrice / totalQty;
      }
    }

    if (totals.isEmpty && selfTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Assign at least one item to a person or Self'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      for (final entry in totals.values) {
        var person = entry.person;
        if (person.id == null) {
          final id = await _personRepo.insertPerson(person);
          person = Person(id: id, name: person.name, createdAt: person.createdAt);
        }
        await _txnService.createEqualSplit(
          totalAmount: entry.amount,
          persons: [person],
          type: widget.type,
        );
      }

      if (selfTotal > 0) {
        await _personalRepo.insert(PersonalExpense(
          amount: selfTotal,
          source: 'partial_self',
          description: 'Partial split self share',
          createdAt: DateTime.now(),
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Transactions created!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                'Total: ₹${_fmt(_total)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: _saving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Creating transactions...'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        );
                      }
                      return _buildItemRow(i);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _update,
                    icon: const Icon(Icons.check),
                    label: const Text('Update & Save Transactions'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemRow(int i) {
    final item = _items[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.name,
                    decoration: const InputDecoration(
                        labelText: 'Item name', isDense: true),
                    onChanged: (v) => item.name = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue:
                        item.basePrice == 0 ? '' : item.basePrice.toString(),
                    decoration: const InputDecoration(
                        labelText: '₹ Price', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (v) {
                      final p = double.tryParse(v);
                      if (p != null) setState(() => item.basePrice = p);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _assignPeople(i),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add,
                        color: AppTheme.primary, size: 20),
                  ),
                  tooltip: 'Assign people',
                ),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(i),
                    icon: Icon(Icons.close,
                        color: Colors.red.shade300, size: 18),
                    tooltip: 'Remove item',
                  ),
              ],
            ),
            if (item.selfIncluded) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.35)),
                ),
                child: const Text('✓ Self included',
                    style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            if (item.assignments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: item.assignments.map((a) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      child: Text(a.person.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    label: Text(
                      '${a.person.name} ×${a.quantity % 1 == 0 ? a.quantity.toInt() : a.quantity}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    onDeleted: () {
                      setState(() => item.assignments.remove(a));
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text('Tap + to assign people',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class _PersonTotal {
  Person person;
  double amount;
  _PersonTotal(this.person, this.amount);
}
