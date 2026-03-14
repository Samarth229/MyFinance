import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/personal_expense.dart';
import '../../core/repositories/personal_expense_repository.dart';
import 'dashboard_screen.dart';
import 'people_screen.dart';
import 'transactions_screen.dart';
import 'personal_screen.dart';
import 'add_person_screen.dart';
import 'add_transaction_screen.dart';
import 'repay_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _gpayChannel = MethodChannel('com.example.myfinance/gpay');
  final _personalRepo = PersonalExpenseRepository();
  late final PageController _pageController;

  int _tab = 0;
  int _refreshKey = 0;
  int _cachedRefreshKey = -1;
  final _navVisible = ValueNotifier<bool>(false);
  late List<Widget> _cachedPages;
  bool _showSwipeHint = false;

  // Returns cached pages, rebuilding only when _refreshKey changes
  List<Widget> get _pages {
    if (_cachedRefreshKey != _refreshKey) {
      _cachedRefreshKey = _refreshKey;
      _cachedPages = _buildPages();
    }
    return _cachedPages;
  }

  List<Widget> _buildPages() => [
        _KeepAlivePage(
          child: DashboardScreen(
            key: ValueKey('dash_$_refreshKey'),
            onGPayLaunched: _onGPayLaunched,
            onTotalTransactionsTap: () => _goToTab(2),
          ),
        ),
        _KeepAlivePage(child: PeopleScreen(key: ValueKey('people_$_refreshKey'))),
        _KeepAlivePage(child: TransactionsScreen(key: ValueKey('txn_$_refreshKey'))),
        _KeepAlivePage(child: PersonalScreen(key: ValueKey('personal_$_refreshKey'))),
      ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tab);
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPending();
      _checkSwipeHint();
    });
  }

  Future<void> _checkSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('swipe_hint_seen') ?? false;
    if (!seen && mounted) setState(() => _showSwipeHint = true);
  }

  Future<void> _dismissSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('swipe_hint_seen', true);
    if (mounted) setState(() => _showSwipeHint = false);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _navVisible.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPageScroll() {
    if (!mounted) return;
    final page = _pageController.page ?? _tab.toDouble();
    final settled = (page - page.round()).abs() < 0.005;
    _navVisible.value = !settled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPending();
  }

  Future<void> _checkPending() async {
    await _commitPendingPersonalExpenses();
    await _handlePendingAction();
  }

  Future<void> _commitPendingPersonalExpenses() async {
    try {
      final raw = await _gpayChannel.invokeMethod<String>('getPendingPersonalExpenses') ?? '';
      if (raw.isNotEmpty) {
        for (final part in raw.split(',')) {
          final amount = double.tryParse(part.trim());
          if (amount != null && amount > 0) {
            await _personalRepo.insert(PersonalExpense(
              amount: amount,
              source: 'gpay_self',
              createdAt: DateTime.now(),
            ));
          }
        }
        setState(() => _refreshKey++);
      }
    } catch (_) {}
  }

  Future<void> _handlePendingAction() async {
    try {
      final action = await _gpayChannel.invokeMethod<String?>('getPendingAction');
      if (action != null && mounted) {
        if (action == 'repay') {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const RepayScreen()));
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(
                preselectedType: action == 'loan' ? 'loan' : 'split',
              ),
            ),
          );
        }
        setState(() => _refreshKey++);
      }
    } catch (_) {}
  }

  void _goToTab(int index) {
    setState(() => _tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onGPayLaunched() {}

  void _onAdd() async {
    if (_tab == 1) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPersonScreen()));
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
    }
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _tab = i),
            children: _pages,
          ),
          // Nav bar overlaid at bottom, slides in during swipe
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _navVisible,
              builder: (_, visible, child) => AnimatedSlide(
                offset: visible ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                child: Container(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  decoration: BoxDecoration(
                    color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
                        Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _tab,
                    onTap: _goToTab,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard_outlined),
                        activeIcon: Icon(Icons.dashboard),
                        label: 'Dashboard',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.people_outline),
                        activeIcon: Icon(Icons.people),
                        label: 'People',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.receipt_long_outlined),
                        activeIcon: Icon(Icons.receipt_long),
                        label: 'Transactions',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline),
                        activeIcon: Icon(Icons.person),
                        label: 'Personal',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
          // Swipe hint overlay — shown only on first launch
          if (_showSwipeHint)
            GestureDetector(
              onTap: _dismissSwipeHint,
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          SizedBox(width: 16),
                          Text('Swipe',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          SizedBox(width: 16),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 28),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Swipe to switch between screens',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAdd,
        tooltip: _tab == 1 ? 'Add Person' : 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
