import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import '../../systems/system_config.dart';

/// شاشة تسجيل الدخول — تحقق من اسم المستخدم وكلمة السر المخصصة لكل نظام.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);

    final expected = SystemConfig.instance.credentials;
    final user = _userController.text.trim();
    final pass = _passController.text;
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم المستخدم وكلمة السر');
      return;
    }
    if (user == expected.username && pass == expected.password) {
      setState(() => _loading = true);
      // دخول سريع بدون أي تأخير
      AuthSession.instance.login();
      return;
    }
    setState(() => _error = 'اسم المستخدم أو كلمة السر غير صحيحة لهذا النظام');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SystemConfig.dynamicBranchReady,
      builder: (context, ready, _) {
        final sys = SystemConfig.instance;
        if (sys.pendingDynamicId.isNotEmpty && !ready) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جارٍ تجهيز إعدادات الفرع...'),
                ],
              ),
            ),
          );
        }
        return _buildForm();
      },
    );
  }

  Widget _buildForm() {
    final sys = SystemConfig.instance;
    final theme = sys.theme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF3F5F9),
                sys.isAdmin
                    ? Color(0xFFFBF1DC)
                    : theme.accent.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: 900,
                constraints: const BoxConstraints(maxHeight: 620),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // ======== اللوحة الجانبية (الشعار والهوية) ========
                    Expanded(
                      flex: 5,
                      child: _BrandPanel(
                        systemLabel: sys.systemLabel,
                        systemRole: sys.systemRole,
                        accent: theme.accent,
                        gradient: theme.panelGradient,
                        icon: theme.icon,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // ======== نموذج الدخول ========
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'دخول النظام المحاسبي — ${sys.systemLabel}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 28),
                            TextField(
                              controller: _userController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'اسم المستخدم',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passController,
                              obscureText: _obscure,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'كلمة السر',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.button,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'دخول',
                                        style: TextStyle(fontSize: 15),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'بيانات الدخول خاصّة بهذا النظام فقط\n'
                              '${sys.isAdmin ? 'مدير الأنظمة' : sys.branchName} — ${sys.branchCode}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// اللوحة الجانبية الزخرفية التي تحمل هوية النظام
class _BrandPanel extends StatelessWidget {
  final String systemLabel;
  final String systemRole;
  final Color accent;
  final List<Color> gradient;
  final IconData icon;

  const _BrandPanel({
    required this.systemLabel,
    required this.systemRole,
    required this.accent,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(28),
          right: Radius.circular(0),
        ),
      ),
      child: Stack(
        children: [
          // زخارف خلفية
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  systemLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  systemRole,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'نظام محاسبي متكامل وآمن',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}