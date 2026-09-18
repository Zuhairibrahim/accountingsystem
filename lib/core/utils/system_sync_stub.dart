import 'eod_sync_firestore.dart';

/// رفع تقرير نهاية اليوم إلى المجموعة المشتركة في السحابة.
Future<bool> pushReport(Map<String, Object?> payload) =>
    eodPushReport(payload);

/// تصدير تطبيق سطح مكتب مستقل للفرع — يعمل من نسخة الويب/سطح المكتب.
Future<Map<String, Object?>> createDesktopApp(
  Map<String, Object?> payload, {
  void Function(Map<String, Object?> status)? onStatus,
}) async => const {
      'done': true,
      'ok': false,
      'message': 'تصدير التطبيق يعمل فقط من النسخة السحابية/الويب',
    };

/// قراءة كل تقارير الفروع في المجموعة المشتركة.
Future<List<Map<String, Object?>>> fetchReports() => eodFetchReports();
