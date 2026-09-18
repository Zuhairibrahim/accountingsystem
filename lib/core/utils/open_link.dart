// فتح روابط الأنظمة — يعتمد التنفيذ على المنصة
// الويب: نافذة مستقلة جديدة من نفس الأصل (تفتح أحدث نسخة من التطبيق)
// غير الويب: لا عملية
export 'open_link_stub.dart'
    if (dart.library.js_interop) 'open_link_web.dart';
