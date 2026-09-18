import 'print_models_helper.dart';
import 'print_report_web.dart';
import 'report_models.dart';

/// طباعة التقرير على الويب — نافذة طباعة HTML فاخرة RTL.
Future<void> printFullReport({
  required String title,
  required String companyLine,
  List<({String label, String value})> stats = const [],
  required List<ReportTable> tables,
}) async {
  printHtmlReport(
    title: title,
    companyLine: companyLine,
    bodyHtml: buildReportBodyHtml(stats: stats, tables: tables),
  );
}
