import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// Payment apps we support
class _PayApp {
  final String name;
  final String emoji;
  final Color color;
  final String checkScheme; // used with canLaunchUrl to detect installation
  final String Function(String upiString) buildUrl;

  const _PayApp({
    required this.name,
    required this.emoji,
    required this.color,
    required this.checkScheme,
    required this.buildUrl,
  });
}

final _kPaymentApps = [
  _PayApp(
    name: 'GPay',
    emoji: '🟢',
    color: const Color(0xFF1A73E8),
    checkScheme: 'gpay://',
    buildUrl: (upi) => upi.replaceFirst('upi://', 'gpay://upi/'),
  ),
  _PayApp(
    name: 'PhonePe',
    emoji: '🟣',
    color: const Color(0xFF5F259F),
    checkScheme: 'phonepe://',
    buildUrl: (upi) {
      final uri = Uri.tryParse(upi);
      final query = uri?.query ?? '';
      return 'intent://pay?$query#Intent;scheme=upi;package=com.phonepe.app;end';
    },
  ),
  _PayApp(
    name: 'Paytm',
    emoji: '🔵',
    color: const Color(0xFF00B9F1),
    checkScheme: 'paytmmp://',
    buildUrl: (upi) {
      final uri = Uri.tryParse(upi);
      final query = uri?.query ?? '';
      return 'intent://pay?$query#Intent;scheme=upi;package=net.one97.paytm;end';
    },
  ),
];

class QrScannerScreen extends StatefulWidget {
  final VoidCallback? onGPayLaunched;
  const QrScannerScreen({super.key, this.onGPayLaunched});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';
    if (raw.isEmpty) return;
    if (!raw.toLowerCase().startsWith('upi://')) return;

    setState(() => _detected = true);
    _controller.stop();
    _showUpiBottomSheet(raw);
  }

  Future<List<_PayApp>> _detectInstalledApps() async {
    final result = <_PayApp>[];
    for (final app in _kPaymentApps) {
      if (await canLaunchUrl(Uri.parse(app.checkScheme))) {
        result.add(app);
      }
    }
    return result;
  }

  void _showUpiBottomSheet(String upiString) {
    final uri = Uri.tryParse(upiString);
    final pa = uri?.queryParameters['pa'] ?? '';
    final pn = uri?.queryParameters['pn'] ?? 'Merchant';
    final am = uri?.queryParameters['am'] ?? '';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UpiPaySheet(
        pa: pa,
        pn: pn,
        am: am,
        upiString: upiString,
        detectApps: _detectInstalledApps,
        onGPayLaunched: widget.onGPayLaunched,
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onDone: () {
          if (mounted) Navigator.pop(context);
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _detected = false);
      _controller.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan QR Code',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point camera at a UPI / GPay QR code',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet with payment app picker ──────────────────────

class _UpiPaySheet extends StatefulWidget {
  final String pa, pn, am, upiString;
  final Future<List<_PayApp>> Function() detectApps;
  final VoidCallback? onGPayLaunched;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const _UpiPaySheet({
    required this.pa,
    required this.pn,
    required this.am,
    required this.upiString,
    required this.detectApps,
    required this.onCancel,
    required this.onDone,
    this.onGPayLaunched,
  });

  @override
  State<_UpiPaySheet> createState() => _UpiPaySheetState();
}

class _UpiPaySheetState extends State<_UpiPaySheet> {
  List<_PayApp>? _apps;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.detectApps().then((apps) {
      if (mounted) setState(() { _apps = apps; _loading = false; });
    });
  }

  Future<void> _launch(_PayApp app) async {
    if (app.name == 'GPay') widget.onGPayLaunched?.call();
    final url = app.buildUrl(widget.upiString);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      widget.onDone();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ${app.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UPI QR Detected',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(widget.pa,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('Payee', widget.pn),
          if (widget.am.isNotEmpty) _row('Amount', '₹${widget.am}'),
          const SizedBox(height: 20),

          // ── App Picker ───────────────────────────────────────
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_apps == null || _apps!.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No payment app found.\nPlease install GPay, PhonePe, or Paytm.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              _apps!.length == 1
                  ? 'Pay with'
                  : 'Choose payment app',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _apps!.map((app) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: app == _apps!.last ? 0 : 10),
                  child: _AppButton(app: app, onTap: () => _launch(app)),
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text('$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _AppButton extends StatelessWidget {
  final _PayApp app;
  final VoidCallback onTap;
  const _AppButton({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: app.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: app.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(app.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              app.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: app.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
