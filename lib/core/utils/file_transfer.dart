// نقل الملفات — يعتمد التنفيذ على المنصة
// الويب: تنزيل الملفات واستقبالها عبر المتصفح
// غير الويب: لا عملية
export 'file_transfer_stub.dart'
    if (dart.library.js_interop) 'file_transfer_web.dart';