import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// تهيئة الاتصال بخدمة Firebase (البوابة الإلزامية لبدء التطبيق).
///
/// التطبيق لا يعمل إلا مع الإنترنت: هذه التهيئة تفشل عند غياب الاتصال،
/// وتُظهر شاشة Bootstrap رسالة واضحة حتى يُعاد الاتصال.
///
/// كاش Firestore معطّل عمداً على الويب: كل قراءة من السحابة مباشرة حتى
/// لا تظهر بيانات فروع قديمة مخزنة في متصفح المستخدم (IndexedDB) أبداً —
/// النظام سحابي 100% والمرجع الوحيد هو الخادم.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static final FirebaseBootstrap instance = FirebaseBootstrap._();

  FirebaseApp? _app;
  bool _ready = false;

  bool get isReady => _ready;

  FirebaseApp get app {
    final a = _app;
    if (a == null) {
      throw StateError('Firebase is not initialized. Call initialize() first.');
    }
    return a;
  }

  /// تهيئة Firebase مرة واحدة — تُستدعى عند إقلاع التطبيق قبل أي وصول للبيانات.
  Future<void> initialize() async {
    if (_ready) return;
    _app = await Firebase.initializeApp(options: FirebaseOptionsHolder.options);
    // بيانات حية دائماً — بلا أي كاش محلي قديم (تُضبط قبل أول استخدام).
    // محمي: أي فشل في الضبط لا يوقف التطبيق أبداً.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    } catch (_) {}
    _ready = true;
  }
}