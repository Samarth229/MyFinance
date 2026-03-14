import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/person_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';
import 'transaction_detail_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _txnRepo = TransactionRepository();
  final _personRepo = PersonRepository();

  List<TransactionModel> _all = [];
  Map<int, String> _personNames = {};
  bool _loading = true;
  // 'all', 'giving', 'taking'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txns = await _txnRepo.getAllTransactions();
      final persons = await _personRepo.getAllPersons();
      setState(() {
        _all = txns
            .where((t) =>
                t.type == 'loan' ||
                t.type == 'loan_giving' ||
                t.type == 'loan_taking')
            .toList();
        _personNames = {for (final p in persons) p.id!: p.name};
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<TransactionModel> get _filtered {
    if (_filter == 'giving') {
      return _all
          .where((t) => t.type == 'loan_giving' || t.type == 'loan')
          .toList();
    }
    if (_filter == 'taking') {
      return _all.where((t) => t.type == 'loan_taking').toList();
    }
    return _all;
  }

  double get _totalGiving => _all
      .where((t) => t.type == 'loan_giving' || t.type == 'loan')
      .fold(0, (s, t) => s + t.remainingAmount);

  double get _totalTaking => _all
      .where((t) => t.type == 'loan_taking')
      .fold(0, (s, t) => s + t.remainingAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  _buildSummaryRow(),
                  _buildFilterRow(),
                  Expanded(
                    child: _filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.handshake_outlined,
                            title: 'No loans',
                            subtitle: _filter == 'all'
                                ? 'No loan transactions yet'
                                : 'No ${_filter == 'giving' ? 'lent' : 'borrowed'} loans',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final t = _filtered[i];
                              return TransactionTile(
                                transaction: t,
                                personName: _personNames[t.personId],
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
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _summaryTile(
              label: 'To Collect',
              amount: _totalGiving,
              color: AppTheme.success,
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryTile(
              label: 'To Repay',
              amount: _totalTaking,
              color: AppTheme.danger,
              icon: Icons.arrow_downward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
              Text(
                '₹${_fmt(amount)}',
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(child: _filterBtn('all', 'All')),
          const SizedBox(width: 8),
          Expanded(child: _filterBtn('giving', 'Lent')),
          const SizedBox(width: 8),
          Expanded(child: _filterBtn('taking', 'Borrowed')),
        ],
      ),
    );
  }

  Widget _filterBtn(String value, String label) {
    final selected = _filter == value;
    final color = value == 'giving'
        ? AppTheme.success
        : value == 'taking'
            ? AppTheme.danger
            : AppTheme.loanColor;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(0);
  }
}
