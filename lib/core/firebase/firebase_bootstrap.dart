import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// تهيئة الاتصال بخدمة Firebase (البوابة الإلزامية لبدء التطبيق).
///
/// التطبيق لا يعمل إلا مع الإنترنت: هذه التهيئة تفشل عند غياب الاتصال،
/// وتُظهر شاشة Bootstrap رسالة واضحة حتى يُعاد الاتصال.
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
    _ready = true;
  }
}