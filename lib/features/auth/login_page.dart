import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import '../../core/utils/audit_log_service.dart';
import '../../systems/admin_credentials.dart';
import '../../systems/branch_registry.dart';
import '../../systems/branch_theme.dart';
import '../../systems/system_config.dart';

/// ألوان الهوية الجديدة (كحلي + ذهبي)
const _kNavy1 = Color(0xFF0B1220);
const _kNavy2 = Color(0xFF15264B);
const _kGold = Color(0xFFF5B21A);

/// شاشة تسجيل الدخول — تصميم 2026 مقسوم (Split-Screen):
/// لوحة هوية داكنة فاخرة بلمسات ذهبية + جانب نموذج فاتح نظيف.
/// للأدمن: هوية النظام الأساسي — للفرع: اسم الفرع يظهر بشكل بارز
/// مع كوده ولونه الخاص. منطق التحقق كما هو تماماً.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscure = true;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _userFocus.addListener(_onFocusChanged);
    _passFocus.addListener(_onFocusChanged);
    // تحميل بيانات دخول الأدمن المخصصة من السحابة مبكراً (تسخين الكاش)
    if (SystemConfig.instance.isAdmin) {
      AdminCredentials.instance.load();
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (SystemConfig.branchDeleted.value) return;

    final user = _userController.text.trim();
    final pass = _passController.text;
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم المستخدم وكلمة السر');
      return;
    }
    // الأدمن: قراءة أحدث بيانات دخول من السحابة قبل التحقق — يضمن أن
    // البيانات الجديدة (بعد تغييرها من «حساب الأدمن») تعمل فوراً بعد
    // تسجيل الخروج على أي جهاز في العالم.
    if (SystemConfig.instance.isAdmin) {
      setState(() => _loading = true);
      await AdminCredentials.instance.load();
      if (!mounted) return;
      setState(() => _loading = false);
    }
    final expected = SystemConfig.instance.credentials;
    if (user == expected.username && pass == expected.password) {
      setState(() => _loading = true);
      // تسجيل عملية الدخول الناجحة في سجل العمليات (يصل للأدمن فوراً)
      AuditLogService.record(
        AuditAction.login,
        details:
            'دخول ناجح — ${SystemConfig.instance.systemLabel} (${SystemConfig.instance.branchCode})',
        actor: user,
      );
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
          return _buildPreparing();
        }
        if (SystemConfig.dynamicBranchFailed.value) {
          return _buildBranchLoadFailed();
        }
        if (SystemConfig.branchDeleted.value) {
          return _buildDeletedBranch();
        }
        return _buildForm();
      },
    );
  }

  // ==================== شاشة التجهيز ====================
  Widget _buildPreparing() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kNavy1,
        body: _DarkBackdrop(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(_kGold),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'جارٍ تجهيز إعدادات الفرع...',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== نموذج الدخول (Split-Screen) ====================
  Widget _buildForm() {
    final sys = SystemConfig.instance;
    final theme = sys.theme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        body: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(flex: 5, child: _brandPanel(theme, sys)),
                        Expanded(flex: 4, child: _formSide(theme, sys)),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          _brandPanel(theme, sys, compact: true),
                          _formSide(theme, sys, compact: true),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _forSaleBadge(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== شريط البيع ====================
  Widget _forSaleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kGold, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_offer_outlined, color: _kGold, size: 14),
          const SizedBox(width: 7),
          const Text(
            'FOR SALE — \$500',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          Container(
            width: 1,
            height: 12,
            color: Colors.white24,
            margin: const EdgeInsets.symmetric(horizontal: 9),
          ),
          const Icon(Icons.chat_outlined, color: _kGold, size: 13),
          const SizedBox(width: 5),
          const Text(
            'واتساب 778066436',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== لوحة الهوية الداكنة ====================
  Widget _brandPanel(BranchTheme theme, SystemConfig sys,
      {bool compact = false}) {
    final isAdmin = sys.isAdmin;
    return _DarkBackdrop(
      accent: isAdmin ? null : theme.accent,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 28 : 56,
          vertical: compact ? 40 : 48,
        ),
        child: compact
            ? Column(
                children: [
                  _brandLogo(theme, isAdmin),
                  const SizedBox(height: 18),
                  if (!isAdmin) ...[
                    Text(
                      'النظام المحاسبي المتكامل',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    isAdmin ? 'النظام المحاسبي المتكامل' : sys.branchName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 8),
                    _branchCodeChip(sys),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    sys.systemRole,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandLogo(theme, isAdmin),
                  const SizedBox(height: 30),
                  if (!isAdmin) ...[
                    Text(
                      'النظام المحاسبي المتكامل — نظام فرعي',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    isAdmin ? 'النظام المحاسبي المتكامل' : sys.branchName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isAdmin ? 32 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.25,
                    ),
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 14),
                    _branchCodeChip(sys),
                    const SizedBox(height: 14),
                  ] else
                    const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Text(
                      isAdmin
                          ? 'منصة محاسبية سحابية متكاملة — فروع منعزلة، تقارير فورية، وتحكم كامل من النظام الأساسي عبر Firebase.'
                          : 'نظام فرعي مستقل ببياناته الخاصة بالكامل — يرسل تقاريره للنظام الأساسي فوراً عبر سحابة Firebase.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14.5,
                        height: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  if (isAdmin) ...[
                    _featureRow(
                      Icons.cloud_done_outlined,
                      'سحابي 100%',
                      'كل البيانات عبر Firebase — تعمل من أي جهاز',
                    ),
                    const SizedBox(height: 20),
                    _featureRow(
                      Icons.admin_panel_settings_outlined,
                      'تحكم مركزي بالفروع',
                      'إنشاء وحذف الفروع واستقبال تقاريرها فوراً',
                    ),
                    const SizedBox(height: 20),
                    _featureRow(
                      Icons.print_outlined,
                      'تقارير قابلة للطباعة',
                      'تقارير شاملة لكل قسم مع الطباعة والإرسال',
                    ),
                  ] else ...[
                    _featureRow(
                      Icons.storefront_outlined,
                      'بيانات مستقلة تماماً',
                      'قاعدة معزولة خاصة بهذا الفرع داخل السحابة',
                    ),
                    const SizedBox(height: 20),
                    _featureRow(
                      Icons.send_outlined,
                      'تقارير تصل الإدارة فوراً',
                      'تقارير نهاية اليوم والأقسام تصلك مباشرة',
                    ),
                    const SizedBox(height: 20),
                    _featureRow(
                      Icons.print_outlined,
                      'تقارير قابلة للطباعة',
                      'تقارير شاملة لكل قسم مع الطباعة',
                    ),
                  ],
                  const SizedBox(height: 42),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: _kGold.withValues(alpha: 0.9),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الإصدار 2.0 — هوية 2026',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _branchCodeChip(SystemConfig sys) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag_rounded,
            color: _kGold.withValues(alpha: 0.9),
            size: 14,
          ),
          const SizedBox(width: 7),
          Text(
            'كود الفرع ${sys.branchCode}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandLogo(BranchTheme theme, bool isAdmin) {
    final c1 = isAdmin ? const Color(0xFFF5B21A) : theme.accent;
    final c2 = Color.lerp(c1, Colors.black, 0.30)!;
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: 0.35),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(
        isAdmin ? Icons.bar_chart_rounded : Icons.storefront_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String sub) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Icon(icon, color: _kGold, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== جانب النموذج الفاتح ====================
  Widget _formSide(BranchTheme theme, SystemConfig sys,
      {bool compact = false}) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 28 : 56,
          vertical: 40,
        ),
        child: SizedBox(
          width: 430,
          child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 24),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ====== العنوان ======
                  Text(
                    sys.isAdmin ? 'مرحباً بعودتك' : 'دخول ${sys.branchName}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sys.isAdmin
                        ? 'سجّل دخولك للمتابعة إلى النظام الأساسي'
                        : 'سجّل دخولك للمتابعة إلى ${sys.branchName} (${sys.branchCode})',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 34),
                  // ====== الحقول ======
                  _modernField(
                    controller: _userController,
                    focus: _userFocus,
                    label: 'اسم المستخدم',
                    hint: 'أدخل اسم المستخدم',
                    icon: Icons.person_outline_rounded,
                    accent: theme.accent,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 18),
                  _modernField(
                    controller: _passController,
                    focus: _passFocus,
                    label: 'كلمة السر',
                    hint: 'أدخل كلمة السر',
                    icon: Icons.lock_outline_rounded,
                    accent: theme.accent,
                    obscure: _obscure,
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      hoverColor: Colors.transparent,
                      splashRadius: 18,
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  // ====== الخطأ ======
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFECACA),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFB91C1C),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 26),
                  // ====== زر الدخول ======
                  _gradientButton(theme, sys),
                  const SizedBox(height: 30),
                  // ====== بطاقة هوية النظام ======
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6EAF2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            sys.isAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.storefront_outlined,
                            color: theme.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sys.isAdmin ? 'مدير النظام' : sys.branchName,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sys.isAdmin
                                    ? 'النظام الأساسي — بيانات الدخول خاصّة بهذا النظام فقط'
                                    : 'رمز النظام ${sys.branchCode} — بيانات الدخول خاصّة بهذا الفرع فقط',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified_user_rounded,
                          color: _kGold.withValues(alpha: 0.85),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  // ==================== حقل إدخال حديث ====================
  Widget _modernField({
    required TextEditingController controller,
    required FocusNode focus,
    required String label,
    required String hint,
    required IconData icon,
    required Color accent,
    bool obscure = false,
    Widget? suffix,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onSubmitted,
  }) {
    final focused = focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: focused ? Colors.white : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? accent.withValues(alpha: 0.65)
              : const Color(0xFFE6EAF2),
          width: focused ? 1.6 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focus,
        obscureText: obscure,
        obscuringCharacter: '●',
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14.5,
          letterSpacing: 0.2,
        ),
        cursorColor: accent,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        autofillHints: obscure
            ? [AutofillHints.password]
            : [AutofillHints.username],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
          ),
          labelText: label,
          floatingLabelStyle: TextStyle(
            color: accent,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color: focused ? accent : const Color(0xFF94A3B8),
            size: 21,
          ),
          suffixIcon: suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
        ),
      ),
    );
  }

  // ==================== زر الدخول (ذهبي للأدمن / لون الفرع للفروع) ====================
  Widget _gradientButton(BranchTheme theme, SystemConfig sys) {
    final c1 = sys.isAdmin ? const Color(0xFFF5B21A) : theme.accent;
    final c2 = sys.isAdmin ? const Color(0xFFB45309) : theme.button;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [c1, c2],
          ),
          boxShadow: [
            BoxShadow(
              color: c1.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _loading ? null : _submit,
            child: SizedBox(
              height: 54,
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
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

  // ==================== شاشة تعذر تحميل إعدادات الفرع ====================
  Widget _buildBranchLoadFailed() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kNavy1,
        body: _DarkBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 60,
                      offset: const Offset(0, 26),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: Color(0xFFD97706),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'تعذّر تحميل إعدادات الفرع',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لم يستطع النظام الوصول للسحابة (Firebase) لتجهيز هذا '
                      'الفرع. تحقق من اتصال الإنترنت ثم أعد المحاولة — '
                      'الفرع يعمل من أي مكان في العالم بمجرد توفر الاتصال.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.8,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB45309),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () =>
                            BranchRegistry.instance.retryDynamicBranch(),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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

  // ==================== شاشة الفرع المحذوف ====================
  Widget _buildDeletedBranch() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kNavy1,
        body: _DarkBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 60,
                      offset: const Offset(0, 26),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFDC2626),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'تم حذف الفرع',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تم حذف الفرع من قبل عمك زهير بن ابراهيم القحطاني '
                      'ولا يمكن الدخول إلى هذا النظام بعد الآن.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.8,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFD97706),
                            size: 19,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'للتواصل أو إعادة تفعيل الفرع: من النظام '
                              'الأساسي (لوحة تحكم الأدمن).',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
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

/// الخلفية الداكنة الفاخرة للوحات الهوية — تدرج كحلي + شبكة نقاط + هالات.
class _DarkBackdrop extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const _DarkBackdrop({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final glowColor = accent ?? const Color(0xFFF5B21A);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [_kNavy2, _kNavy1, Color(0xFF070D18)],
            ),
          ),
        ),
        CustomPaint(painter: _DotGridPainter(bright: true)),
        Positioned(
          top: -160,
          right: -140,
          child: _glow(glowColor.withValues(alpha: 0.13), 460),
        ),
        Positioned(
          bottom: -180,
          left: -120,
          child: _glow(const Color(0xFF2563EB).withValues(alpha: 0.12), 500),
        ),
        child,
      ],
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// شبكة نقاط خفيفة على الخلفية.
class _DotGridPainter extends CustomPainter {
  final bool bright;

  const _DotGridPainter({this.bright = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bright
          ? Colors.white.withValues(alpha: 0.045)
          : const Color(0xFF0F172A).withValues(alpha: 0.030)
      ..strokeWidth = 1;
    const step = 34.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
