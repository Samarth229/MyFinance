import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/screens/app_shell.dart';
import 'ui/screens/permission_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const MyFinanceApp());
}

class MyFinanceApp extends StatelessWidget {
  const MyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      child: const _Launcher(),
      builder: (_, mode, child) => MaterialApp(
        title: 'DebtTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        themeAnimationDuration: Duration.zero,
        home: child,
      ),
    );
  }
}

class _Launcher extends StatefulWidget {
  const _Launcher();

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  bool _splashDone = false;
  bool _ready = false;
  bool _permissionsDone = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('permissions_done') ?? false;
    setState(() {
      _permissionsDone = done;
      _ready = true;
    });
  }

  Future<void> _onPermissionsDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_done', true);
    if (mounted) {
      setState(() => _permissionsDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onDone: () => setState(() => _splashDone = true));
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_permissionsDone) {
      return PermissionScreen(onDone: _onPermissionsDone);
    }
    return const AppShell();
  }
}
