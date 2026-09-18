/// نماذج بيانات الطباعة المشتركة بين كل المنصات (بدون أي اعتماديات).
class ReportTable {
  /// عنوان القسم الذي يظهر فوق الجدول (مثل: تقارير نهاية اليوم)
  final String? caption;

  /// عناوين الأعمدة
  final List<String> columns;

  /// صفوف البيانات (نصوص جاهزة للعرض)
  final List<List<String>> rows;

  /// صف الإجماليات (اختياري)
  final List<String>? totalsRow;

  const ReportTable({
    this.caption,
    required this.columns,
    required this.rows,
    this.totalsRow,
  });
}
