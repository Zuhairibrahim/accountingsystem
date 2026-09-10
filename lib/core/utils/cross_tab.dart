// إشعارات فورية بين تبويبات الأنظمة — يعتمد التنفيذ على المنصة
// الويب: BroadcastChannel (نفس الأصل)
// غير الويب: لا عملية
export 'cross_tab_stub.dart'
    if (dart.library.js_interop) 'cross_tab_web.dart';