import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/person_repository.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _txnRepo = TransactionRepository();
  final _personRepo = PersonRepository();

  List<TransactionModel> _all = [];
  Map<int, String> _personNames = {};
  bool _loading = true;

  // active quick-filter key
  String _activeCard = 'all';

  // card definitions: (key, label, icon, color, statusFilter, typeFilter)
  static const _cards = [
    _CardDef('all',           'All',            Icons.receipt_long_outlined, Color(0xFF3F51B5), 'all',       'all'),
    _CardDef('pending_loans', 'Pending\nLoans',  Icons.handshake_outlined,   Color(0xFFFF9800), 'pending',   'loan'),
    _CardDef('pending_splits','Pending\nSplits', Icons.group_outlined,       Color(0xFF9C27B0), 'pending',   'split'),
    _CardDef('paid',          'Paid',            Icons.check_circle_outline,  Color(0xFF4CAF50), 'completed', 'all'),
  ];

  bool _isLoan(TransactionModel t) =>
      t.type == 'loan' || t.type == 'loan_giving' || t.type == 'loan_taking';

  bool _matchesCard(_CardDef card, TransactionModel t) {
    final statusOk = card.statusFilter == 'all' || t.status == card.statusFilter;
    final typeOk = card.typeFilter == 'all' ||
        (card.typeFilter == 'loan' && _isLoan(t)) ||
        (card.typeFilter == 'split' && t.type == 'split');
    return statusOk && typeOk;
  }

  List<TransactionModel> get _filtered {
    final card = _cards.firstWhere((c) => c.key == _activeCard);
    return _all.where((t) => _matchesCard(card, t)).toList();
  }

  int _countFor(_CardDef card) =>
      _all.where((t) => _matchesCard(card, t)).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _confirmDelete(TransactionModel t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Delete this transaction? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _txnRepo.deleteTransaction(t.id!);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txns = await _txnRepo.getAllTransactions();
      final persons = await _personRepo.getAllPersons();
      setState(() {
        _all = txns;
        _personNames = {for (final p in persons) p.id!: p.name};
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCardRow(),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _all.isEmpty ? 'No transactions yet' : 'No results',
                          subtitle: _all.isEmpty
                              ? 'Create a transaction to get started'
                              : 'Nothing matches this filter',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              return TransactionTile(
                                transaction: t,
                                personName: _personNames[t.personId],
                                onDelete: () => _confirmDelete(t),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransactionDetailScreen(
                                        transaction: t,
                                        personName: _personNames[t.personId],
                                      ),
                                    ),
                                  );
                                  _load();
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF3F51B5),
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x333F51B5),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        children: _cards.map((card) {
          final isActive = _activeCard == card.key;
          final count = _countFor(card);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeCard = card.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? card.color : Colors.white.withValues(alpha: 0.25),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(color: card.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(card.icon,
                        color: isActive ? card.color : Colors.white70, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isActive ? card.color : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.black87 : Colors.white70,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
    );
  }
}

class _CardDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String statusFilter;
  final String typeFilter;

  const _CardDef(this.key, this.label, this.icon, this.color,
      this.statusFilter, this.typeFilter);
}
