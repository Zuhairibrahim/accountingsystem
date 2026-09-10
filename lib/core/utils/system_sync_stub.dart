import 'eod_sync_firestore.dart';

/// رفع تقرير نهاية اليوم إلى المجموعة المشتركة في السحابة.
Future<bool> pushReport(Map<String, Object?> payload) =>
    eodPushReport(payload);

/// إنشاء تطبيق مستقل لفرع جديد — يعمل فقط مع الخادم المحلي (Web).
Future<bool> createDesktopApp(Map<String, Object?> payload) async => false;

/// قراءة كل تقارير الفروع في المجموعة المشتركة.
Future<List<Map<String, Object?>>> fetchReports() => eodFetchReports();