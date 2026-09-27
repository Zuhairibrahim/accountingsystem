import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/database/db_filter.dart';
import '../../core/utils/audit_log_service.dart';
import '../../core/utils/open_link.dart';
import '../../core/utils/system_sync.dart';
import '../../systems/branch_profile.dart';
import '../../systems/branch_registry.dart';
import '../../systems/system_config.dart';

/// شاشة إضافة فرع جديد — من النظام الأساسي فقط.
///
/// الأدمين يُدخل فقط: اسم الفرع + اسم المستخدم + كلمة السر.
/// كود الفرع يُعبأ تلقائياً من آخر كود محفوظ (مثال: BR10 ← BR11) ولا يُعدَّل يدوياً،
/// وكل المهام/الوحدات الموجودة في الفروع تُضاف تلقائياً للفرع الجديد،
/// بينما تبقى بيانات كل فرع مستقلة تماماً (قاعدة معزولة).
class BranchManagerPage extends StatefulWidget {
  const BranchManagerPage({super.key});

  @override
  State<BranchManagerPage> createState() => _BranchManagerPageState();
}

class _BranchManagerPageState extends State<BranchManagerPage> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  List<BranchProfile> _branches = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await BranchRegistry.instance.loadAll();
    if (!mounted) return;
    setState(() {
      _branches = BranchRegistry.instance.branches;
      _codeController.text = BranchRegistry.instance.nextCode;
    });
  }

  String _linkOf(BranchProfile p) => SystemConfig.cloudUrlFor(p.id);

  /// رابط نفس الأصل — يفتح نظام الفرع بأحدث نسخة من هذا التطبيق مباشرة.
  String _localLinkOf(BranchProfile p) => '/?sys=${p.id}';

  /// فتح نظام الفرع في نافذة مستقلة (نفس النسخة الحالية — بيانات Firebase).
  void _openBranchSystem(BranchProfile p) {
    openSystemWindow(_localLinkOf(p));
    AuditLogService.record(
      AuditAction.openBranchSystem,
      details: 'فتح نظام «${p.name}» (${p.code}) من النظام الأساسي',
      actor: 'مدير النظام',
    );
  }

  /// عرض رمز QR لرابط الفرع — للمسح بكاميرا التلفون من أي مكان بالعالم.
  Future<void> _showQr(BranchProfile p) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Color(0xFFB45309)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'رابط «${p.name}»',
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6EAF2)),
              ),
              child: _BranchQrView(
                data: _linkOf(p),
                size: 230,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'امسح الرمز بكاميرا التلفون أو أرسل الرابط — يعمل من أي مكان '
              'في العالم ويفتح هذا الفرع بالتحديد باسمه وبيانات دخوله.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              _linkOf(p),
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _linkOf(p)));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('تم نسخ الرابط')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('نسخ الرابط'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  /// تصدير تطبيق الفرع (exe) من بطاقة الفرع — للنسخ إلى جهاز الموظف.
  Future<void> _exportBranchApp(BranchProfile p) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await createDesktopApp(
      {
        'id': p.id,
        'name': p.name,
        'code': p.code,
        'url': _linkOf(p),
        'username': p.username,
        'password': p.password,
      },
      onStatus: (_) {},
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result['ok'] == true
              ? 'تم تصدير تطبيق «${p.name}» — داخل مجلد ZuhairSystem على سطح المكتب'
              : (result['message'] as String? ?? 'تعذّر التصدير'),
        ),
        backgroundColor: result['ok'] == true
            ? const Color(0xFF059669)
            : const Color(0xFFD97706),
      ),
    );
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final user = _userController.text.trim();
    final pass = _passController.text;
    if (name.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم الفرع واسم المستخدم وكلمة السر');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = await BranchRegistry.instance.createBranch(
        name: name,
        username: user,
        password: pass,
      );
      // حفظ الفرع في جدول الفروع (يظهر داخل قسم الفروع) تلقائياً
      try {
        await DatabaseService.instance.insert(
          AppConstants.tBranches,
          {
            'code': p.code,
            'name': p.name,
            'governorate': p.name.startsWith('فرع ')
                ? p.name.replaceFirst('فرع ', 'محافظة ')
                : 'محافظة',
            'phone': '',
            'address': '',
            'manager': 'مدير النظام',
            'system_id': p.id,
          },
        );
      } catch (_) {}
      _nameController.clear();
      _userController.clear();
      _passController.clear();
      if (!mounted) return;
      setState(() {
        _branches = BranchRegistry.instance.branches;
        _codeController.text = BranchRegistry.instance.nextCode;
      });
      // تسجيل عملية إنشاء الفرع في سجل العمليات (يظهر في لوحة الأدمن فوراً)
      AuditLogService.record(
        AuditAction.createBranch,
        details: 'إنشاء فرع «${p.name}» — الرمز ${p.code} (${p.id})',
        actor: 'مدير النظام',
      );
      // إنشاء التطبيق المستقل للفرع (محلياً) مع نافذة تقدم حية —
      // البيانات داخل التطبيق كلها عبر السحابة (Firebase).
      final appResult = await _buildAppWithProgress(p);
      await _showCreated(p, appResult: appResult);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is StateError
          ? e.message
          : 'تعذّر إنشاء الفرع. تأكد من الاتصال بالسحابة ثم أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// تصدير تطبيق الفرع (exe) مع نافذة تقدم حية
  /// (تحميل القالب ← تجهيز ← تنزيل الملف).
  Future<Map<String, Object?>> _buildAppWithProgress(BranchProfile p) async {
    if (!mounted) {
      return const {'done': true, 'ok': false, 'message': 'أُغلقت الشاشة'};
    }
    final step = ValueNotifier<String>('إرسال أمر التصدير...');
    final appFuture = createDesktopApp(
      {
        'id': p.id,
        'name': p.name,
        'code': p.code,
        'url': _linkOf(p),
        'username': p.username,
        'password': p.password,
      },
      onStatus: (st) {
        final s = st['step'];
        if (s is String && s.isNotEmpty && s != 'اكتمل') {
          step.value = s;
        }
      },
    );
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        appFuture.whenComplete(() => navigator.pop());
        return PopScope(
          canPop: false,
          child: ValueListenableBuilder<String>(
            valueListenable: step,
            builder: (ctx, s, _) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(width: 12),
                  Text('جارٍ تصدير تطبيق الفرع', style: TextStyle(fontSize: 17)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'يُصدَّر الآن تطبيقان مستقلان لفرع «${p.name}»: تطبيق الابتوب '
                    'EXE بأيقونة تحمل اسمه، وتطبيق التلفون APK — كلاهما داخل '
                    'مجلد ZuhairSystem على سطح المكتب، وكل البيانات عبر '
                    'السحابة (Firebase).',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_suggest_outlined,
                          size: 18,
                          color: Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
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
        );
      },
    );
    return appFuture;
  }

  Future<void> _showCreated(
    BranchProfile p, {
    required Map<String, Object?> appResult,
  }) async {
    final link = _linkOf(p);
    final appOk = appResult['ok'] == true;
    final appMsg = (appResult['message'] as String?) ?? '';
    final appPath = (appResult['path'] as String?) ?? '';
    final apkPath = (appResult['apk'] as String?) ?? '';
    final isExe = appOk && appPath.toLowerCase().endsWith('.exe');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('تم إنشاء الفرع بنجاح'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('اسم الفرع', p.name),
              _row('كود الفرع', p.code),
              _row('معرف النظام', p.id),
              _row('اسم المستخدم', p.username),
              _row('كلمة المرور', p.password),
              _row('قاعدة البيانات', p.dbName),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: appOk
                      ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                      : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: appOk
                        ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                        : const Color(0xFFD97706).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      appOk
                          ? (isExe
                              ? Icons.desktop_windows
                              : Icons.link_outlined)
                          : Icons.info_outline,
                      color: appOk
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        appOk
                            ? (isExe
                                ? 'تم تصدير التطبيق «${p.name}.exe» بأيقونته '
                                    'الخاصة — داخل مجلد ZuhairSystem على سطح '
                                    'المكتب. انسخه إلى لابتوب الموظف وافتحه '
                                    'مباشرة؛ يفتح نظام الفرع باسمه وبيانات '
                                    'دخوله وكل البيانات عبر السحابة (Firebase).'
                                : 'تم إنشاء اختصار «$p.name» — جرّب تصدير '
                                    'التطبيق مرة أخرى من بطاقة الفرع.')
                            : '$appMsg\nأعد تصدير التطبيق من بطاقة الفرع بعد '
                                'التأكد من الاتصال.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // بطاقة تطبيق التلفون (APK)
              if (appOk && apkPath.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.smartphone,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تطبيق التلفون «APK» — داخل مجلد ZuhairSystem على سطح '
                          'المكتب. انقله للتلفون وثبّته (اسمح بالتثبيت من '
                          'مصادر غير معروفة)؛ يفتح نظام هذا الفرع بالتحديد.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Text(
                'رابط الدخول (يعمل من أي مكان عبر السحابة):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      link,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                      color: Color(0xFFD98E04),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الرابط')),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'رمز QR للرابط',
                    icon: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 18,
                      color: Color(0xFFB45309),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showQr(p);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'الرابط دائماً: $link — يعمل من أي مكان حتى لو كان الجهاز مطفأً.',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BranchProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفرع في'),
        content: Text(
          'هل تريد حذف "${p.name}" (${p.code})؟\n'
          'يُحذف الفرع فوراً من السجل ويُغلق تطبيقه عند الموظف مباشرة، '
          'وتُمسح كل بياناته بالكامل في الخلفية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await BranchRegistry.instance.deleteBranch(p.id);
    // حذف صف الفرع من جدول الفروع داخل نظام الأدمن حتى لا يبقى يتيماً
    try {
      final rows = await DatabaseService.instance.find(
        AppConstants.tBranches,
        filter: DbFilter.equals('system_id', p.id),
      );
      for (final row in rows) {
        await DatabaseService.instance.delete(
          AppConstants.tBranches,
          (row['id'] as num).toInt(),
        );
      }
    } catch (_) {}
    // تسجيل عملية حذف الفرع في سجل العمليات
    AuditLogService.record(
      AuditAction.deleteBranch,
      details: 'حذف فرع «${p.name}» — الرمز ${p.code} (${p.id}) من السجل',
      actor: 'مدير النظام',
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إضافة فرع جديد',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'أدخل الاسم والمستخدم وكلمة المرور فقط — كود الفرع يتولّد تلقائياً '
            'من آخر كود محفوظ، وكل المهام تُضاف تلقائياً وبيانات كل فرع مستقلة.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بيانات الفرع الجديد',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          readOnly: true,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'كود الفرع (تلقائي)',
                            prefixIcon: Icon(Icons.tag),
                            helperStyle: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الفرع',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'اسم مستخدم الفرع الجديد',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
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
                        border: Border.all(color: Colors.red.shade200),
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
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _create,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_business_outlined),
                      label: Text(
                        _saving ? 'جارٍ الإنشاء...' : 'إنشاء الفرع',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF0369A1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بعد الإنشاء سيتم تضمين جميع المهام الموجودة في الفروع '
                          'الآن، وتكون بيانات الفرع الجديد مستقلة تماماً عن الفروع الأخرى.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'الفروع المُضافة من هنا',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Chip(
                avatar: const Icon(
                  Icons.storefront,
                  size: 14,
                  color: Color(0xFF0F172A),
                ),
                label: Text(
                  '${_branches.length} / ${SystemConfig.maxBranches}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_branches.isEmpty)
            Text(
              'لا توجد فروع مضافة بعد.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final b in _branches) _branchCard(b),
              ],
            ),
        ],
      ),
    );
  }

  Widget _branchCard(BranchProfile b) {
    final link = _linkOf(b);
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFF0D9488),
      const Color(0xFF16A34A),
      const Color(0xFFEA580C),
    ];
    final color = colors[b.themeIndex % colors.length];
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.storefront, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${b.code} — ${b.id}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'رمز QR — يفتح الفرع من التلفون',
                onPressed: () => _showQr(b),
                icon: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFFB45309),
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'حذف من السجل',
                onPressed: () => _delete(b),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ],
          ),
          const Divider(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'المستخدم: ${b.username}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.link, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  link,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ),
              IconButton(
                tooltip: 'نسخ الرابط',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الرابط')),
                  );
                },
                icon: const Icon(Icons.copy, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _openBranchSystem(b),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('فتح النظام', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _exportBranchApp(b),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text(
                    'تصدير exe',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// رسم رمز QR لرابط الفرع — يُمسح بكاميرا التلفون فيفتح الفرع الصحيح.
class _BranchQrView extends StatelessWidget {
  final String data;
  final double size;

  const _BranchQrView({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    final qr = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(qr);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _QrPainter(image),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrImage _image;

  const _QrPainter(this._image);

  @override
  void paint(Canvas canvas, Size size) {
    final count = _image.moduleCount;
    final cell = size.width / count;
    final paint = Paint()..color = const Color(0xFF0B1220);
    for (var y = 0; y < count; y++) {
      for (var x = 0; x < count; x++) {
        if (_image.isDark(y, x)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x * cell, y * cell, cell, cell),
              Radius.circular(cell * 0.18),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate._image != _image;
}
