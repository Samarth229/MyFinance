import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/database_helper.dart';
import '../../main.dart' show themeNotifier;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _upiController = TextEditingController();
  String? _imagePath;
  bool _loading = true;
  bool _editMode = false;

  // Permission state
  bool _cameraGranted = false;
  bool _notifGranted = false;
  bool _accessibilityGranted = false;
  bool _waitingForAccessibility = false;
  static const _channel = MethodChannel('com.example.myfinance/gpay');

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkPermissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('profile_name') ?? '';
      _phoneController.text = prefs.getString('profile_phone') ?? '';
      _upiController.text = prefs.getString('profile_upi') ?? '';
      _imagePath = prefs.getString('profile_image');
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', _nameController.text.trim());
    await prefs.setString('profile_phone', _phoneController.text.trim());
    await prefs.setString('profile_upi', _upiController.text.trim());
    if (_imagePath != null) {
      await prefs.setString('profile_image', _imagePath!);
    }
    setState(() => _editMode = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', picked.path);
      setState(() => _imagePath = picked.path);
    }
  }

  Future<void> _showResetDialog() async {
    final resetController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '⚠',
                          style: TextStyle(fontSize: 60, color: Colors.red.shade700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Danger Zone',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'If Reset, all transactions will be reset to Zero.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Type 'reset' and then press Enter to reset",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: resetController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'reset',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setSt(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: resetController.text.trim().toLowerCase() == 'reset'
                              ? () async {
                                  Navigator.pop(ctx);
                                  await _doReset();
                                }
                              : null,
                          child: const Text('Enter'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _doReset() async {
    final db = await DatabaseHelper().database;
    await db.delete('payments');
    await db.delete('transactions');
    await db.delete('persons');
    await db.delete('personal_expenses');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_personal_expenses');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data has been reset'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkPermissions() async {
    final cam = await Permission.camera.isGranted;
    final notif = await Permission.notification.isGranted;
    final acc = await _isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        _cameraGranted = cam;
        _notifGranted = notif;
        _accessibilityGranted = acc;
      });
    }
  }

  Future<bool> _isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  void _showAppTutorial() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TutorialDialog(),
    );
  }

  Future<void> _showPermissionsSheet() async {
    await _checkPermissions();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('App Permissions',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Manage what MyFinance can access',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
              _permTile(
                ctx: ctx, setS: setS,
                icon: Icons.camera_alt, title: 'Camera',
                subtitle: 'Scan QR codes and bill images',
                granted: _cameraGranted, loading: false,
                onAllow: () async {
                  final s = await Permission.camera.request();
                  setState(() => _cameraGranted = s.isGranted);
                  setS(() {});
                },
              ),
              const SizedBox(height: 10),
              _permTile(
                ctx: ctx, setS: setS,
                icon: Icons.notifications, title: 'Notifications',
                subtitle: 'Alert you when GPay payment is detected',
                granted: _notifGranted, loading: false,
                onAllow: () async {
                  final s = await Permission.notification.request();
                  setState(() => _notifGranted = s.isGranted);
                  setS(() {});
                },
              ),
              const SizedBox(height: 10),
              if (!Platform.isIOS)
                _permTile(
                  ctx: ctx, setS: setS,
                  icon: Icons.accessibility_new, title: 'Background Detection',
                  subtitle: 'Detect GPay even when app is closed',
                  granted: _accessibilityGranted, loading: _waitingForAccessibility,
                  onAllow: () async {
                    setState(() => _waitingForAccessibility = true);
                    setS(() {});
                    try { await _channel.invokeMethod('openAccessibilitySettings'); } catch (_) {}
                    await Future.delayed(const Duration(seconds: 1));
                    final acc = await _isAccessibilityEnabled();
                    setState(() {
                      _accessibilityGranted = acc;
                      _waitingForAccessibility = false;
                    });
                    setS(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permTile({
    required BuildContext ctx,
    required StateSetter setS,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required bool loading,
    required VoidCallback onAllow,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(ctx).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(ctx).dividerColor),
      ),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: granted
                ? const Color(0xFF43A047).withValues(alpha: 0.12)
                : const Color(0xFF3F51B5).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: granted ? const Color(0xFF43A047) : const Color(0xFF3F51B5),
              size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: loading
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : granted
                ? const Icon(Icons.check_circle, color: Color(0xFF43A047))
                : TextButton(
                    onPressed: onAllow,
                    child: const Text('Allow'),
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final hasImage = _imagePath != null && File(_imagePath!).existsSync();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final primaryColor = const Color(0xFF3F51B5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.close : Icons.edit_outlined),
            tooltip: _editMode ? 'Cancel' : 'Edit Profile',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Avatar + Info Header ──────────────────────────────
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _editMode ? _pickImage : null,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          backgroundImage: hasImage ? FileImage(File(_imagePath!)) : null,
                          child: !hasImage
                              ? Icon(Icons.person, size: 60, color: primaryColor.withValues(alpha: 0.5))
                              : null,
                        ),
                      ),
                      if (_editMode)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!_editMode) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _infoRow(Icons.person_outline, 'Name',
                              _nameController.text.isNotEmpty ? _nameController.text : '—', isDark),
                          Divider(height: 1, color: borderColor),
                          _infoRow(Icons.phone_outlined, 'Contact',
                              _phoneController.text.isNotEmpty ? _phoneController.text : '—', isDark),
                          Divider(height: 1, color: borderColor),
                          _infoRow(Icons.account_balance_wallet_outlined, 'UPI',
                              _upiController.text.isNotEmpty ? _upiController.text : '—', isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Edit Fields ───────────────────────────────────────
          if (_editMode) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildField(label: 'Name', controller: _nameController, icon: Icons.person_outline, isDark: isDark),
                    Divider(height: 1, color: borderColor),
                    _buildField(label: 'Contact', controller: _phoneController, icon: Icons.phone_outlined, keyboard: TextInputType.phone, isDark: isDark),
                    Divider(height: 1, color: borderColor),
                    _buildField(label: 'UPI ID', controller: _upiController, icon: Icons.account_balance_wallet_outlined, isDark: isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Update', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  onPressed: _saveProfile,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── How to Use (Info) ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline, color: Color(0xFF1E88E5), size: 20),
                ),
                title: const Text('How to Use', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Quick app tour & tips', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAppTutorial,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Permissions ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.security_outlined, color: primaryColor, size: 20),
                ),
                title: const Text('Permissions', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  Platform.isIOS ? 'Camera, Notifications' : 'Camera, Notifications, Accessibility',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showPermissionsSheet,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Dark Mode Toggle ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: SwitchListTile(
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(isDark ? 'On' : 'Off'),
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: isDark ? Colors.amber : Colors.orange,
                ),
                value: isDark,
                onChanged: (val) async {
                  themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('dark_mode', val);
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Reset Button ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Reset All Data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: _showResetDialog,
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Text(
            '$label : ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A237E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tutorial Dialog
// ─────────────────────────────────────────────────────────────

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog();

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog>
    with TickerProviderStateMixin {
  int _page = 0;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  static const _pages = [
    _TutorialPage(
      emoji: '👋',
      title: "Welcome, Money Boss!",
      body:
          "This is your personal finance sidekick.\nLet's get you up to speed in 60 seconds — no boring manuals!",
      color: Color(0xFF3F51B5),
      bgEmoji: '💰',
    ),
    _TutorialPage(
      emoji: '📊',
      title: "Your HQ — Dashboard",
      body:
          "The Dashboard shows your total balance at a glance.\nSee who owes you, who you owe, and your personal spend — all in one place!",
      color: Color(0xFF1E88E5),
      bgEmoji: '🏦',
    ),
    _TutorialPage(
      emoji: '➕',
      title: "The Magic Button",
      body:
          "Tap the blue ＋ button anytime to log a new transaction.\nLoaned a friend cash? Split a dinner bill? Done in 5 seconds!",
      color: Color(0xFF43A047),
      bgEmoji: '🚀',
    ),
    _TutorialPage(
      emoji: '👥',
      title: "Your Squad — People",
      body:
          "Add the people you transact with.\nSwipe to the People tab and tap ＋ to add a friend. Their balance updates automatically every time!",
      color: Color(0xFF8E24AA),
      bgEmoji: '🤝',
    ),
    _TutorialPage(
      emoji: '🔁',
      title: "Settling Up",
      body:
          "When someone pays you back, record a Repayment.\nGo to Transactions → select the person → hit Repay. Balance goes to zero — satisfying!",
      color: Color(0xFFFB8C00),
      bgEmoji: '✅',
    ),
    _TutorialPage(
      emoji: '💸',
      title: "Track Your Own Spending",
      body:
          "The Personal tab tracks your own expenses, separate from loans and splits.\nGreat for keeping an eye on daily spending!",
      color: Color(0xFFE53935),
      bgEmoji: '📱',
    ),
    _TutorialPage(
      emoji: '🎉',
      title: "You're All Set!",
      body:
          "You now know everything you need.\nGo out there, track your money, and never forget who owes you again!",
      color: Color(0xFF3F51B5),
      bgEmoji: '🏆',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _slideCtrl.reset();
      setState(() => _page++);
      _slideCtrl.forward();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pages[_page];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────
            Container(
              width: double.infinity,
              // top padding accounts for -12px bounce room
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              decoration: BoxDecoration(color: p.color),
              child: Center(
                child: AnimatedBuilder(
                  animation: _bounceAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _bounceAnim.value),
                    child: child,
                  ),
                  child: Text(p.emoji,
                      style: const TextStyle(fontSize: 64, height: 1)),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────
            Container(
              color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        Text(
                          p.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1A237E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Page dots ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? p.color : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // ── Button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        animationDuration: Duration.zero,
                        textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            inherit: false),
                      ),
                      onPressed: _next,
                      child: Text(
                        _page < _pages.length - 1 ? 'Next  →' : '🎉  Got it!',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPage {
  final String emoji;
  final String title;
  final String body;
  final Color color;
  final String bgEmoji;

  const _TutorialPage({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
    required this.bgEmoji,
  });
}
