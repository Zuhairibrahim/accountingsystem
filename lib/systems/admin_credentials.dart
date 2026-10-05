import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase/firebase_bootstrap.dart';
import 'system_config.dart';

/// بيانات دخول الأدمن القابلة للتغيير من لوحة التحكم — محفوظة في السحابة
/// (Firestore) حتى تعمل على أي جهاز في العالم فور تغييرها.
///
/// التدفق الكامل:
/// 1) تغيير البيانات من قسم «حساب الأدمن» داخل النظام الأساسي.
/// 2) حفظ فوري في السحابة (accounting_admin_config/credentials).
/// 3) تسجيل الخروج.
/// 4) شاشة الدخول تقرأ أحدث بيانات من السحابة قبل التحقق.
/// 5) الدخول بالاسم/كلمة السر الجديدة ينجح مباشرة — على أي جهاز.
class AdminCredentials {
  AdminCredentials._();

  static final AdminCredentials instance = AdminCredentials._();

  static const String collection = 'accounting_admin_config';
  static const String docId = 'credentials';

  ({String username, String password}) _creds =
      SystemConfig.defaultAdminCredentials;

  bool _loaded = false;

  /// آخر بيانات محمّلة (كاش) — تبدأ من القيم الافتراضية المضمّنة.
  ({String username, String password}) get current => _creds;

  /// هل سبق تحميل بيانات مخصصة من السحابة؟
  bool get isLoaded => _loaded;

  /// قراءة أحدث بيانات من السحابة (الخادم أولاً ثم الكاش) — تُستدعى عند فتح
  /// شاشة الدخول وعند كل محاولة دخول (للأدمن) لضمان عمل البيانات الجديدة
  /// فوراً بعد تسجيل الخروج على أي جهاز في العالم.
  Future<void> load() async {
    try {
      await FirebaseBootstrap.instance.initialize();
      final doc = FirebaseFirestore.instance
          .collection(collection)
          .doc(docId);
      Map<String, dynamic>? data;
      try {
        data = (await doc.get(const GetOptions(source: Source.server))).data();
      } catch (_) {
        data = (await doc.get(const GetOptions(source: Source.cache))).data();
      }
      _apply(data);
      _loaded = true;
    } catch (_) {
      // بدون إنترنت: يبقى آخر كاش محمّل — الدخول لا يتعطل أبداً
    }
  }

  void _apply(Map<String, dynamic>? data) {
    if (data == null) return;
    final user = data['username']?.toString().trim() ?? '';
    final pass = data['password']?.toString() ?? '';
    if (user.isEmpty || pass.isEmpty) return;
    _creds = (username: user, password: pass);
    SystemConfig.customAdminCredentials = _creds;
  }

  /// حفظ بيانات جديدة في السحابة وتحديث الكاش فوراً — يعيد true عند النجاح.
  Future<bool> save({
    required String username,
    required String password,
  }) async {
    try {
      await FirebaseBootstrap.instance.initialize();
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .set({
        'username': username.trim(),
        'password': password,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      _creds = (username: username.trim(), password: password);
      SystemConfig.customAdminCredentials = _creds;
      _loaded = true;
      return true;
    } catch (_) {
      return false;
    }
  }
}
