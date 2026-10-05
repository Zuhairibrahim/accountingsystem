import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import '../../core/utils/audit_log_service.dart';
import '../../systems/admin_credentials.dart';
import '../../systems/system_config.dart';

/// قسم «حساب الأدمن» داخل لوحة التحكم — تغيير اسم المستخدم وكلمة السر.
///
/// البيانات تُحفظ في السحابة (Firestore) فوراً: بعد الحفظ سجّل الخروج
/// وادخل بالبيانات الجديدة — تعمل مباشرة على أي جهاز في العالم.
class AdminAccountPage extends StatefulWidget {
  const AdminAccountPage({super.key});

  @override
  State<AdminAccountPage> createState() => _AdminAccountPageState();
}

class _AdminAccountPageState extends State<AdminAccountPage> {
  final _currentPassController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userController.text = SystemConfig.instance.credentials.username;
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _userController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentPass = _currentPassController.text;
    final newUser = _userController.text.trim();
    final newPass = _passController.text;
    final confirm = _confirmController.text;

    // 1) التحقق من كلمة السر الحالية
    final current = SystemConfig.instance.credentials;
    if (currentPass != current.password) {
      setState(() => _error = 'كلمة السر الحالية غير صحيحة');
      return;
    }
    // 2) التحقق من البيانات الجديدة
    if (newUser.isEmpty || newPass.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم المستخدم وكلمة السر الجديدين');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'كلمة السر الجديدة وتأكيدها غير متطابقتين');
      return;
    }
    if (newUser == current.username && newPass == current.password) {
      setState(() => _error = 'البيانات الجديدة مطابقة للحالية — لا يوجد تغيير');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // 3) الحفظ في السحابة
    final ok = await AdminCredentials.instance.save(
      username: newUser,
      password: newPass,
    );
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _saving = false;
        _error = 'تعذّر الحفظ في السحابة — تحقق من الإنترنت وأعد المحاولة';
      });
      return;
    }

    // 4) توثيق العملية في سجل العمليات
    AuditLogService.record(
      AuditAction.changeCredentials,
      details: 'تغيير بيانات دخول الأدمن — اسم المستخدم الجديد: $newUser',
      actor: 'مدير النظام',
    );

    setState(() => _saving = false);
    _showSuccess(newUser);
  }

  Future<void> _showSuccess(String newUser) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('تم تغيير بيانات الدخول بنجاح'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اسم المستخدم الجديد: $newUser',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'البيانات محفوظة في السحابة وتعمل فوراً على كل الأجهزة.\n'
                'سجّل الخروج الآن ثم ادخل بالبيانات الجديدة.',
                style: TextStyle(fontSize: 12.5, height: 1.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('بقاء في النظام'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthSession.instance.logout();
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('تسجيل الخروج الآن'),
          ),
        ],
      ),
    );
    if (mounted) {
      _currentPassController.clear();
      _passController.clear();
      _confirmController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = SystemConfig.instance.credentials;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حساب الأدمن — بيانات الدخول',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'غيّر اسم المستخدم وكلمة السر من هنا — تُحفظ في السحابة فوراً '
            'وتعمل على أي جهاز في العالم بعد تسجيل الخروج.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // بطاقة البيانات الحالية
          Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFFB45309),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اسم المستخدم الحالي',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SelectableText(
                          current.username,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_done_outlined,
                          size: 13,
                          color: Color(0xFF16A34A),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'محفوظة بالسحابة',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // نموذج التغيير
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'البيانات الجديدة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _currentPassController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة السر الحالية (للتأكيد)',
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم الجديد',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passController,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'كلمة السر الجديدة',
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscure,
                    onSubmitted: (_) => _saving ? null : _save(),
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة السر الجديدة',
                      prefixIcon: Icon(Icons.check_circle_outline),
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
                      onPressed: _saving ? null : _save,
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
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving ? 'جارٍ الحفظ في السحابة...' : 'حفظ البيانات الجديدة',
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
                          'بعد الحفظ: سجّل الخروج من أيقونة الخروج بالأعلى ثم '
                          'ادخل بالبيانات الجديدة — تعمل فوراً على كل الأجهزة.',
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
        ],
      ),
    );
  }
}
