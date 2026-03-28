import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../core/models/personal_expense.dart';
import '../../core/repositories/personal_expense_repository.dart';

/// Shows the full payment recording flow (iOS widget or wherever needed).
/// Returns:
///   true        → Self expense saved (trigger refresh)
///   'split'     → caller should open AddTransactionScreen(split)
///   'loan'      → caller should open AddTransactionScreen(loan)
///   'repay'     → caller should open RepayScreen
///   null        → user cancelled / No Payment
Future<dynamic> showPaymentFlowPopup(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PaymentFlowDialog(),
  );
}

enum _Step { choice, amount, category, success }

class _PaymentFlowDialog extends StatefulWidget {
  const _PaymentFlowDialog();

  @override
  State<_PaymentFlowDialog> createState() => _PaymentFlowDialogState();
}

class _PaymentFlowDialogState extends State<_PaymentFlowDialog>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.choice;
  double _amount = 0;
  String _selectedCategory = '';
  final _amountCtrl = TextEditingController();
  final _repo = PersonalExpenseRepository();
  late AnimationController _tickAnim;
  late Animation<double> _tickScale;

  static const _categories = [
    ('\u{1F697}  Transport', 'Transport', Color(0xFF1565C0)),
    ('\u{1F354}  Food',      'Food',      Color(0xFFE65100)),
    ('\u{1F46A}  Family',    'Family',    Color(0xFF6A1B9A)),
    ('\u{1F45C}  Accessories','Accessories',Color(0xFF00695C)),
    ('\u2022\u2022\u2022  Others', 'Others', Color(0xFF546E7A)),
  ];

  @override
  void initState() {
    super.initState();
    _tickAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _tickScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tickAnim, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tickAnim.dispose();
    super.dispose();
  }

  Future<void> _saveAndShowSuccess() async {
    await _repo.insert(PersonalExpense(
      amount: _amount,
      source: 'gpay_self',
      category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
      createdAt: DateTime.now(),
    ));
    setState(() => _step = _Step.success);
    _tickAnim.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: switch (_step) {
          _Step.choice   => _buildChoice(),
          _Step.amount   => _buildAmount(),
          _Step.category => _buildCategory(),
          _Step.success  => _buildSuccess(),
        },
      ),
    );
  }

  // ── Step 1: choice ──────────────────────────────────────────────────────────

  Widget _buildChoice() {
    return SingleChildScrollView(
      key: const ValueKey('choice'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, color: AppTheme.primary, size: 40),
            const SizedBox(height: 8),
            const Text('Record this payment',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _choiceBtn(Icons.person, 'Self', 'Personal expense',
                AppTheme.success, () => setState(() => _step = _Step.amount)),
            const SizedBox(height: 8),
            _choiceBtn(Icons.group, 'Split', 'Share with others',
                AppTheme.splitColor, () => Navigator.pop(context, 'split')),
            const SizedBox(height: 8),
            _choiceBtn(Icons.handshake_outlined, 'Loan', 'Give or take a loan',
                AppTheme.loanColor, () => Navigator.pop(context, 'loan')),
            const SizedBox(height: 8),
            _choiceBtn(Icons.refresh, 'Repay', 'Repay a loan',
                const Color(0xFFFB8C00), () => Navigator.pop(context, 'repay')),
            const SizedBox(height: 8),
            _choiceBtn(Icons.cancel_outlined, 'No Payment',
                "I didn't actually pay",
                Colors.grey, () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _choiceBtn(IconData icon, String label, String sub, Color color,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: color, fontSize: 14)),
              Text(sub,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ),
          Icon(Icons.chevron_right, color: color, size: 18),
        ]),
      ),
    );
  }

  // ── Step 2: amount ──────────────────────────────────────────────────────────

  Widget _buildAmount() {
    return Padding(
      key: const ValueKey('amount'),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Self Expense',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('How much did you pay?',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              hintText: '0',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = _Step.choice),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final v = double.tryParse(_amountCtrl.text.trim());
                  if (v != null && v > 0) {
                    _amount = v;
                    setState(() => _step = _Step.category);
                  }
                },
                child: const Text('Update'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Step 3: category ────────────────────────────────────────────────────────

  Widget _buildCategory() {
    return Padding(
      key: const ValueKey('category'),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._categories.map((c) {
            final (label, value, color) = c;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _selectedCategory = value;
                    _saveAndShowSuccess();
                  },
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Step 4: success ─────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _tickScale,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Color(0xFF4CAF50), size: 60),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Transaction added to\nPersonal Expense',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
