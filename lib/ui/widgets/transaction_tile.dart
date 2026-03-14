import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../theme/app_theme.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final String? personName;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.personName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = transaction.status == 'completed';
    final isLoan = transaction.type == 'loan' ||
        transaction.type == 'loan_giving' ||
        transaction.type == 'loan_taking';
    final statusColor = isCompleted ? AppTheme.success : AppTheme.warning;
    final typeColor = isLoan ? AppTheme.loanColor : AppTheme.splitColor;
    final typeLabel = switch (transaction.type) {
      'loan_giving' => 'LENT',
      'loan_taking' => 'BORROWED',
      String t => t.toUpperCase(),
    };
    final paid = transaction.totalAmount - transaction.remainingAmount;
    final progress = transaction.totalAmount == 0
        ? 0.0
        : paid / transaction.totalAmount;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _chip(typeLabel, typeColor),
                  const SizedBox(width: 8),
                  if (personName != null)
                    Expanded(
                      child: Text(
                        personName!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  _chip(isCompleted ? 'PAID' : 'PENDING', statusColor),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${_fmt(transaction.totalAmount)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Remaining: ₹${_fmt(transaction.remainingAmount)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFF5F5F5),
                  valueColor: AlwaysStoppedAnimation(statusColor),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _formatDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
