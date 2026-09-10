import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/auth/auth_session.dart';
import 'core/database/database_seed.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'systems/branch_registry.dart';
import 'systems/system_config.dart';

/// جذر التطبيق — RTL عربي كامل.
///
/// بوابة إجبارية: لا يمكن فتح التطبيق إلا مع الاتصال بخدمة Firebase.
/// عند غياب الإنترنت تظهر رسالة واضحة وزر إعادة محاولة حتى ينجح الاتصال.
class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '${SystemConfig.instance.systemLabel} — النظام المحاسبي',
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _BootstrapGate(
        child: ValueListenableBuilder<bool>(
          valueListenable: AuthSession.instance.isAuthenticated,
          builder: (context, authed, _) =>
              authed ? const HomePage() : const LoginPage(),
        ),
      ),
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate({required this.child});

  final Widget child;

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

enum _BootstrapPhase { booting, failed, ready }

class _BootstrapGateState extends State<_BootstrapGate> {
  _BootstrapPhase _phase = _BootstrapPhase.booting;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _BootstrapPhase.booting;
      _error = '';
    });
    try {
      // الاتصال بـ Firebase إلزامي — لا يعمل التطبيق بدونه
      await FirebaseBootstrap.instance.initialize();
      // تهيئة البيانات الأولية للنظام الحالي (آمنة: تُفحص العدد أولاً)
      await DatabaseSeed.instance.ensureSeed();
      // جاهزية إعدادات الفروع (الثابتة والديناميكية)
      await BranchRegistry.instance.ensureCurrentReady();
      if (!mounted) return;
      setState(() => _phase = _BootstrapPhase.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _BootstrapPhase.failed;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _BootstrapPhase.ready => widget.child,
      _BootstrapPhase.booting => const _BootMessage(
          icon: Icons.cloud_sync,
          color: Color(0xFFCA8A04),
          title: 'جارٍ الاتصال بالسحابة...',
          message: 'يتم الآن الاتصال بخدمة البيانات السحابية',
          showProgress: true,
        ),
      _BootstrapPhase.failed => _BootMessage(
          icon: Icons.cloud_off,
          color: Colors.red.shade600,
          title: 'تعذر الاتصال بالإنترنت',
          message:
              'التطبيق لا يعمل إلا مع الإنترنت.\nتأكد من الاتصال ثم أعد المحاولة.',
          error: _error,
          onRetry: _run,
        ),
    };
  }
}

class _BootMessage extends StatelessWidget {
  const _BootMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.error,
    this.onRetry,
    this.showProgress = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? error;
  final VoidCallback? onRetry;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: color),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (error != null && error!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                  if (showProgress) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}