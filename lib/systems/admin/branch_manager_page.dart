import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/utils/audit_log_service.dart';
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
      // إنشاء التطبيق المستقل للفرع تلقائياً داخل مجلد المسؤول (عبر الخادم المحلي)
      final appCreated = await createDesktopApp({
        'id': p.id,
        'name': p.name,
        'code': p.code,
        'url': _linkOf(p),
        'username': p.username,
        'password': p.password,
      });
      // تسجيل عملية إنشاء الفرع في سجل العمليات (يظهر في لوحة الأدمن فوراً)
      AuditLogService.record(
        AuditAction.createBranch,
        details: 'إنشاء فرع «${p.name}» — الرمز ${p.code} (${p.id})',
        actor: 'مدير النظام',
      );
      await _showCreated(p, appCreated: appCreated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر إنشاء الفرع. تأكد من الاتصال بالسحابة ثم أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCreated(BranchProfile p, {bool appCreated = false}) async {
    final link = _linkOf(p);
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
                  color: appCreated
                      ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                      : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: appCreated
                        ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                        : const Color(0xFFD97706).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      appCreated
                          ? Icons.desktop_windows
                          : Icons.info_outline,
                      color: appCreated
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        appCreated
                            ? 'تم إنشاء التطبيق «${p.name}» تلقائياً داخل مجلد المسؤول '
                                '(admin) — بجانبه ملف «بيانات الدخول» باسم المستخدم '
                                'وكلمة السر، ويمكن نسخه ولصقه على جهاز الموظف مباشرة.'
                            : 'الخادم المحلي غير شغال الآن (لا يمكن إنشاء التطبيق تلقائياً). '
                                'شغّل serve_all.py على هذا الجهاز ثم اضغط «إنشاء الفرع» مرة أخرى، '
                                'وسيُنشأ التطبيق تلقائياً داخل مجلد المسؤول بجانب ملف بيانات الدخول.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'الرابط دائماً: https://accountingsystem-fc3f0.web.app/?sys=${p.id} '
                'يعمل من أي مكان حتى لو كان الجهاز مطفأً.',
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
          'هل تريد حذف "${p.name}" (${p.code}) من السجل؟\n'
          'لن يُحذف أي بيانات سابقة، لكن لن يُعتدّ بالفرع كنظام جديد.',
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
          const Text(
            'الفروع المُضافة من هنا',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }
}