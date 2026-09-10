// طباعة فاتورة — يعتمد التنفيذ على المنصة
// الويب: نافذة طباعة HTML (يدعم العربية بشكل كامل)
// غير الويب: لا عملية
export 'invoice_printer_stub.dart'
    if (dart.library.js_interop) 'invoice_printer_web.dart';
