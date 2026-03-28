import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionScreen({super.key, required this.onDone});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.myfinance/gpay');

  bool _cameraGranted = false;
  bool _notifGranted = false;
  bool _accessibilityGranted = false;
  bool _waitingForAccessibility = false;
  bool _accessibilityDenied = false;
  Timer? _accessibilityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkExisting();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accessibilityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForAccessibility) {
      _checkAccessibility();
    }
  }

  Future<void> _checkExisting() async {
    final cam = await Permission.camera.isGranted;
    final notif = await Permission.notification.isGranted;
    final acc = await _isAccessibilityEnabled();
    setState(() {
      _cameraGranted = cam;
      _notifGranted = notif;
      _accessibilityGranted = acc;
    });
  }

  Future<bool> _isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    setState(() => _cameraGranted = status.isGranted);
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    setState(() => _notifGranted = status.isGranted);
  }

  Future<void> _requestAccessibility() async {
    setState(() {
      _waitingForAccessibility = true;
      _accessibilityDenied = false;
    });
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<void> _checkAccessibility() async {
    final enabled = await _isAccessibilityEnabled();
    setState(() {
      _accessibilityGranted = enabled;
      _waitingForAccessibility = false;
      if (!enabled) _accessibilityDenied = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.account_balance_wallet,
                  size: 56, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('Welcome to MyFinance',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Grant these permissions to unlock all features',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 36),

              _permissionTile(
                icon: Icons.camera_alt,
                title: 'Camera',
                subtitle: 'Scan QR codes and bill images',
                granted: _cameraGranted,
                onTap: _requestCamera,
              ),
              const SizedBox(height: 12),
              _permissionTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Alert you when GPay payment is detected',
                granted: _notifGranted,
                onTap: _requestNotification,
              ),
              const SizedBox(height: 12),
              if (!Platform.isIOS) ...[
                const SizedBox(height: 12),
                _permissionTile(
                  icon: Icons.accessibility_new,
                  title: 'Background Detection',
                  subtitle: 'Detect GPay even when app is closed',
                  granted: _accessibilityGranted,
                  onTap: _waitingForAccessibility ? null : _requestAccessibility,
                  loading: _waitingForAccessibility,
                ),
                if (_accessibilityDenied) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Without this permission, you\'ll need to open MyFinance manually after every GPay payment to track it.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDone,
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text('Skip for now',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: granted
                ? AppTheme.success.withValues(alpha: 0.12)
                : AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: granted ? AppTheme.success : AppTheme.primary, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12)),
        trailing: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : granted
                ? const Icon(Icons.check_circle,
                    color: AppTheme.success)
                : TextButton(
                    onPressed: onTap,
                    child: const Text('Allow'),
                  ),
      ),
    );
  }
}
