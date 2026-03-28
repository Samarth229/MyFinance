import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/financial_summary.dart';
import '../../core/services/dashboard_service.dart';
import '../theme/app_theme.dart';
import '../widgets/summary_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/payment_flow_popup.dart';
import 'add_transaction_screen.dart';
import 'repay_screen.dart';

const _channel = MethodChannel('com.example.myfinance/gpay');

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onGPayLaunched;
  final VoidCallback? onTotalTransactionsTap;
  const DashboardScreen({super.key, this.onGPayLaunched, this.onTotalTransactionsTap});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _analytics = AnalyticsService();
  final _dashboard = DashboardService();

  FinancialSummary? _summary;
  int _pendingPeople = 0;
  List<TopEntry> _topSplits = [];
  List<TopEntry> _topLents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _analytics.getFinancialSummary();
      final pendingPeople = await _dashboard.getPendingPeopleCount();
      final topSplits = await _analytics.getTopSplits();
      final topLents = await _analytics.getTopLents();
      setState(() {
        _summary = summary;
        _pendingPeople = pendingPeople;
        _topSplits = topSplits;
        _topLents = topLents;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openApp(String package) async {
    try {
      await _channel.invokeMethod('openApp', package);
      if (package == 'com.google.android.apps.nbu.paisa.user') {
        widget.onGPayLaunched?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App not installed')),
        );
      }
    }
  }

  Future<void> _onRecordPayment() async {
    final result = await showPaymentFlowPopup(context);
    if (!mounted) return;
    if (result == true) {
      _load();
    } else if (result == 'split' || result == 'loan') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(preselectedType: result as String),
        ),
      );
      if (mounted) _load();
    } else if (result == 'repay') {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const RepayScreen()));
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyFinance'),
        actions: [
          if (Platform.isIOS) ...[
            _PayButton(
              label: 'Record',
              color: const Color(0xFF00897B),
              onTap: _onRecordPayment,
            ),
            const SizedBox(width: 4),
          ],
          _PayButton(
            label: 'GPay',
            color: const Color(0xFF1A73E8),
            onTap: () => _openApp('com.google.android.apps.nbu.paisa.user'),
          ),
          const SizedBox(width: 4),
          _PayButton(
            label: 'PhonePe',
            color: const Color(0xFF5F259F),
            onTap: () => _openApp('com.phonepe.app'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load',
                  subtitle: _error,
                  actionLabel: 'Retry',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildBanner(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      const SizedBox(height: 12),
                      _buildCompletionCard(),
                      const SizedBox(height: 12),
                      _buildCountsCard(),
                      const SizedBox(height: 12),
                      _buildLeaderboard(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBanner() {
    final s = _summary!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3F51B5), Color(0xFF7986CB)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Outstanding',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '₹${_fmt(s.totalRemaining)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _bannerStat('Created', '₹${_fmt(s.totalCreated)}'),
              const SizedBox(width: 28),
              _bannerStat('Collected', '₹${_fmt(s.totalPaid)}'),
              const SizedBox(width: 28),
              _bannerStat('Owing', '$_pendingPeople people'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildStatsRow() {
    final s = _summary!;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onTotalTransactionsTap,
            child: SummaryCard(
              label: 'Total Transactions',
              value: '${s.totalTransactions}',
              icon: Icons.receipt_long,
              color: AppTheme.splitColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(
            label: 'Pending',
            value: '${s.pendingTransactions}',
            icon: Icons.pending_actions,
            color: AppTheme.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionCard() {
    final s = _summary!;
    final rate = s.completionRate;
    final color = rate >= 75 ? AppTheme.success : AppTheme.warning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Collection Progress',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${rate.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: rate / 100,
                backgroundColor: const Color(0xFFF5F5F5),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${_fmt(s.totalPaid)} collected of ₹${_fmt(s.totalCreated)}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountsCard() {
    final s = _summary!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _countTile('${s.completedTransactions}',
                  'Completed', Icons.check_circle_outline, AppTheme.success),
            ),
            Container(
                width: 1,
                height: 48,
                color: const Color(0xFFF5F5F5)),
            Expanded(
              child: _countTile('${s.pendingTransactions}', 'Pending',
                  Icons.hourglass_empty, AppTheme.warning),
            ),
            Container(
                width: 1,
                height: 48,
                color: const Color(0xFFF5F5F5)),
            Expanded(
              child: _countTile(
                  '${(s.debtRatio * 100).toStringAsFixed(0)}%',
                  'Debt Ratio',
                  Icons.pie_chart_outline,
                  AppTheme.danger),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countTile(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(0);
  }

  Widget _buildLeaderboard() {
    if (_topSplits.isEmpty && _topLents.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with divider
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Text('Top Splits',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.splitColor)),
                  ),
                  VerticalDivider(
                      width: 1, thickness: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Text('Top Lents',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.loanColor)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Rows for rank 1, 2, 3
            ...List.generate(3, (i) {
              final split = i < _topSplits.length ? _topSplits[i] : null;
              final lent = i < _topLents.length ? _topLents[i] : null;
              if (split == null && lent == null) return const SizedBox.shrink();

              // % lead of rank i over rank i+1
              String splitPct = '';
              if (split != null && i + 1 < _topSplits.length) {
                final next = _topSplits[i + 1].amount;
                if (split.amount > 0) {
                  final pct = ((split.amount - next) / split.amount * 100).round();
                  splitPct = '+$pct%';
                }
              }
              String lentPct = '';
              if (lent != null && i + 1 < _topLents.length) {
                final next = _topLents[i + 1].amount;
                if (lent.amount > 0) {
                  final pct = ((lent.amount - next) / lent.amount * 100).round();
                  lentPct = '+$pct%';
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Split entry
                      Expanded(
                        child: split == null
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  Text('${i + 1}.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade500)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(split.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        Text('₹${_fmt(split.amount)}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  if (splitPct.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.splitColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(splitPct,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.splitColor)),
                                    ),
                                ],
                              ),
                      ),
                      VerticalDivider(
                          width: 12,
                          thickness: 1,
                          color: Colors.grey.shade200),
                      // Lent entry
                      Expanded(
                        child: lent == null
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  Text('${i + 1}.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade500)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(lent.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        Text('₹${_fmt(lent.amount)}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  if (lentPct.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.loanColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(lentPct,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.loanColor)),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PayButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
