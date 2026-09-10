// مزامنة التقارير عبر صندوق البريد المحلي (يعمل حتى بين منافذ مختلفة)
// الويب: fetch على /api/* لتسليم التقارير للنظام الأساسي
// غير الويب: لا عملية
export 'system_sync_stub.dart'
    if (dart.library.js_interop) 'system_sync_web.dart';