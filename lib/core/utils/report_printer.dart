// طباعة التقارير الموحدة — يعمل على الويب وسطح المكتب (ويندوز):
//   الويب  → نافذة طباعة HTML فاخرة (RTL) عبر المتصفح
//   ويندوز → ملف PDF عربي احترافي + نافذة الطباعة الأصلية للنظام
export 'report_models.dart';
export 'report_printer_html.dart' if (dart.library.io) 'report_printer_pdf.dart';
