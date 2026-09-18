// طباعة التقارير — يعتمد التنفيذ على المنصة
// الويب: نافذة طباعة بتقرير HTML فاخر (RTL) يعمل من أي متصفح على أي جهاز
// غير الويب: لا عملية
export 'print_report_stub.dart'
    if (dart.library.js_interop) 'print_report_web.dart';
