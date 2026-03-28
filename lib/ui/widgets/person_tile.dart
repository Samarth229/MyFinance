import 'package:flutter/material.dart';
import '../../core/analytics/person_report.dart';
import '../theme/app_theme.dart';

class PersonTile extends StatelessWidget {
  final PersonReport report;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PersonTile({super.key, required this.report, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasBalance = report.totalRemaining > 0;
    final statusColor = hasBalance ? AppTheme.warning : AppTheme.success;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    AppTheme.primary.withValues(alpha: 0.12),
                radius: 24,
                child: Text(
                  report.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Text(
                      '${report.transactionCount} transaction${report.transactionCount == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${_fmt(report.totalRemaining)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    hasBalance ? 'pending' : 'cleared',
                    style: TextStyle(fontSize: 11, color: statusColor),
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
