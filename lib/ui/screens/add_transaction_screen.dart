import 'package:flutter/material.dart';
import '../../core/models/person.dart';
import '../../core/models/personal_expense.dart';
import '../../core/repositories/person_repository.dart';
import '../../core/repositories/personal_expense_repository.dart';
import '../../core/services/transaction_service.dart';
import '../theme/app_theme.dart';
import 'bill_items_screen.dart';
import 'bill_scan_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final Person? preselectedPerson;
  final String? preselectedType; // 'split', 'loan', 'personal'
  const AddTransactionScreen({super.key, this.preselectedPerson, this.preselectedType});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _personRepo = PersonRepository();
  final _txnService = TransactionService();
  final _personalRepo = PersonalExpenseRepository();

  List<Person> _allPersons = [];
  Set<int> _selectedIds = {};
  String _type = 'split';
  String? _splitSubtype; // 'equal' or 'partial'
  String _loanSubtype = 'giving'; // 'giving' or 'taking'
  bool _includeSelf = false; // Self toggle for equal split
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedType != null) {
      _type = widget.preselectedType!;
      if (_type == 'loan') _splitSubtype = 'equal';
      if (_type == 'split') _splitSubtype = null;
    }
    _loadPersons();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPersons() async {
    try {
      final persons = await _personRepo.getAllPersons();
      setState(() {
        _allPersons = persons;
        _loading = false;
        if (widget.preselectedPerson != null) {
          _selectedIds = {widget.preselectedPerson!.id!};
        }
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _togglePerson(Person p) {
    setState(() {
      if (_selectedIds.contains(p.id)) {
        _selectedIds.remove(p.id);
      } else {
        _selectedIds.add(p.id!);
      }
    });
  }

  List<Person> get _selectedPersons =>
      _allPersons.where((p) => _selectedIds.contains(p.id)).toList();

  // ── Type button taps ──────────────────────────────────────────────────────

  void _onTypeTap(String type) {
    if (type == 'split') {
      _showSplitSubtypeDialog();
    } else if (type == 'loan') {
      _showLoanSubtypeDialog();
    } else if (type == 'personal') {
      _showPersonalEntryDialog();
    }
  }

  Future<void> _showSplitSubtypeDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Choose Split Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption(icon: Icons.balance, label: 'Equal Split',
                subtitle: 'Divide evenly among all', value: 'equal'),
            const SizedBox(height: 10),
            _dialogOption(icon: Icons.receipt_long, label: 'Partial Split',
                subtitle: 'Per-item bill splitting', value: 'partial'),
          ],
        ),
      ),
    );
    if (choice != null) {
      setState(() {
        _type = 'split';
        _splitSubtype = choice;
        _includeSelf = false;
      });
      if (choice == 'partial') _showPartialEntryDialog();
    }
  }

  Future<void> _showLoanSubtypeDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Loan Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption(icon: Icons.arrow_upward, label: 'Lend',
                subtitle: 'You are lending money', value: 'giving',
                color: AppTheme.success),
            const SizedBox(height: 10),
            _dialogOption(icon: Icons.arrow_downward, label: 'Borrow',
                subtitle: 'You are borrowing money', value: 'taking',
                color: AppTheme.danger),
          ],
        ),
      ),
    );
    if (choice != null) {
      setState(() {
        _type = 'loan';
        _loanSubtype = choice;
        _splitSubtype = 'equal';
      });
    }
  }

  Future<void> _showPartialEntryDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Bill Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption(icon: Icons.edit_note, label: 'Manual Entry',
                subtitle: 'Type item names and prices', value: 'manual'),
            const SizedBox(height: 10),
            _dialogOption(icon: Icons.camera_alt, label: 'Scan Bill',
                subtitle: 'Photo → auto extract items', value: 'scan'),
            const SizedBox(height: 10),
            _dialogOption(icon: Icons.photo_library, label: 'Upload Bill',
                subtitle: 'Pick from gallery → auto extract', value: 'upload'),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'manual') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => BillItemsScreen(type: _type)));
    } else if (choice == 'scan') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => BillScanScreen(type: _type)));
    } else {
      Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => BillScanScreen(type: _type, useGallery: true)));
    }
  }

  Future<void> _showPersonalEntryDialog() async {
    // Step 1: pick category
    final category = await _showCategoryPickerDialog();
    if (category == null || !mounted) return;

    // Step 2: enter description + amount
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: saved
              ? null
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _categoryColor(category).withValues(alpha: 0.15),
                      child: Icon(_categoryIcon(category),
                          color: _categoryColor(category), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(category,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
          content: saved
              ? _buildSuccessTick()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
          actions: saved
              ? null
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      final desc = descCtrl.text.trim();
                      await _personalRepo.insert(PersonalExpense(
                        amount: amount,
                        source: 'direct',
                        description: desc.isNotEmpty ? desc : null,
                        category: category,
                        createdAt: DateTime.now(),
                      ));
                      setS(() => saved = true);
                      await Future.delayed(const Duration(milliseconds: 2200));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Done'),
                  ),
                ],
        ),
      ),
    );
  }

  Future<String?> _showCategoryPickerDialog() {
    final categories = [
      ('Transport', Icons.directions_bus, const Color(0xFF1565C0)),
      ('Food', Icons.restaurant, const Color(0xFFE65100)),
      ('Family', Icons.family_restroom, const Color(0xFF6A1B9A)),
      ('Accessories', Icons.shopping_bag, const Color(0xFF00838F)),
      ('Others', Icons.category, const Color(0xFF558B2F)),
    ];

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Category',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: categories.map((c) {
            return InkWell(
              onTap: () => Navigator.pop(ctx, c.$1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.$3.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.$3.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: c.$3.withValues(alpha: 0.15),
                      child: Icon(c.$2, color: c.$3, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(c.$1,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Transport': return Icons.directions_bus;
      case 'Food': return Icons.restaurant;
      case 'Family': return Icons.family_restroom;
      case 'Accessories': return Icons.shopping_bag;
      default: return Icons.category;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Transport': return const Color(0xFF1565C0);
      case 'Food': return const Color(0xFFE65100);
      case 'Family': return const Color(0xFF6A1B9A);
      case 'Accessories': return const Color(0xFF00838F);
      default: return const Color(0xFF558B2F);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one person'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final total = double.tryParse(_amountController.text.trim()) ?? 0;
    final persons = _selectedPersons;

    // For equal split with Self: split among persons+self
    double perPerson = total;
    if (_type == 'split' && _splitSubtype == 'equal' && _includeSelf && persons.isNotEmpty) {
      perPerson = total / (persons.length + 1);
    } else if (_type == 'split' && _splitSubtype == 'equal' && persons.isNotEmpty) {
      perPerson = total / persons.length;
    }

    setState(() => _saving = true);
    try {
      final txnType = _type == 'loan'
          ? 'loan_$_loanSubtype'
          : _type;

      if (_type == 'split' && _splitSubtype == 'equal' && _includeSelf) {
        // Create transaction for each person at their share amount
        for (final p in persons) {
          await _txnService.createEqualSplit(
            totalAmount: perPerson,
            persons: [p],
            type: txnType,
          );
        }
        // Add self share to personal expenses
        await _personalRepo.insert(PersonalExpense(
          amount: perPerson,
          source: 'split_self',
          description: 'Equal split self share',
          createdAt: DateTime.now(),
        ));
      } else {
        await _txnService.createEqualSplit(
          totalAmount: total,
          persons: persons,
          type: txnType,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction created'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _splitButtonLabel {
    if (_type == 'split') {
      if (_splitSubtype == 'equal') return 'Equal Split ▼';
      if (_splitSubtype == 'partial') return 'Partial Split ▼';
    }
    return 'Split';
  }

  String get _loanButtonLabel {
    if (_type == 'loan') {
      return _loanSubtype == 'giving' ? 'Lend ▼' : 'Borrow ▼';
    }
    return 'Loan';
  }

  bool get _showPeopleSection =>
      _type != 'personal' && _splitSubtype != 'partial';

  bool get _showSubmitButton =>
      _type != 'personal' && _splitSubtype != 'partial';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _label('AMOUNT & TYPE'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Total Amount *',
                      prefixIcon: Icon(Icons.currency_rupee),
                      hintText: '0.00',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (_type == 'personal') return null;
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _typeBtn('split', Icons.call_split, _splitButtonLabel)),
                      const SizedBox(width: 8),
                      Expanded(child: _typeBtn('loan', Icons.handshake_outlined, _loanButtonLabel)),
                      const SizedBox(width: 8),
                      Expanded(child: _typeBtn('personal', Icons.person, 'Personal')),
                    ],
                  ),
                  if (_type == 'split' && _splitSubtype == 'partial') ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showPartialEntryDialog,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Enter Bill Items'),
                    ),
                  ],
                  if (_showPeopleSection) ...[
                    const SizedBox(height: 24),
                    _label('SELECT PEOPLE'),
                    const SizedBox(height: 10),
                    if (_allPersons.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Text('No people added yet. Go to the People tab first.'),
                      )
                    else
                      ..._allPersons.map(_personRow),
                  ],
                  if (_showSubmitButton) ...[
                    const SizedBox(height: 24),
                    // Self toggle (only for equal split)
                    if (_type == 'split' && _splitSubtype == 'equal')
                      _buildSelfToggle(),
                    const SizedBox(height: 16),
                    _saving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.check),
                            label: const Text('Create Transaction'),
                          ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSelfToggle() {
    return GestureDetector(
      onTap: () => setState(() => _includeSelf = !_includeSelf),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _includeSelf
              ? AppTheme.success.withValues(alpha: 0.10)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _includeSelf ? AppTheme.success : Theme.of(context).dividerColor,
            width: _includeSelf ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _includeSelf ? AppTheme.success : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _includeSelf ? AppTheme.success : Colors.grey.shade400,
                ),
              ),
              child: _includeSelf
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            const Icon(Icons.person, size: 20, color: AppTheme.success),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Include Self',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    _includeSelf
                        ? 'Your share will be added to Personal Expense'
                        : 'Tap to include your own share',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Colors.grey, letterSpacing: 0.8),
      );

  Widget _typeBtn(String value, IconData icon, String label) {
    final selected = _type == value;
    final color = value == 'loan'
        ? AppTheme.loanColor
        : value == 'personal'
            ? AppTheme.success
            : AppTheme.splitColor;
    return GestureDetector(
      onTap: () => _onTypeTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: selected ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _personRow(Person p) {
    final selected = _selectedIds.contains(p.id);
    return GestureDetector(
      onTap: () => _togglePerson(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.10) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.primary : Colors.grey.shade400,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(p.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary, fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (p.phone != null)
              Text(p.phone!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _dialogOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
    Color? color,
  }) {
    final c = color ?? AppTheme.primary;
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// Big animated tick — used after saving a personal/self expense
Widget _buildSuccessTick() {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 500),
    curve: Curves.elasticOut,
    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 96),
        SizedBox(height: 16),
        Text(
          'Transaction added to\nPersonal Expense',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
      ],
    ),
  );
}
