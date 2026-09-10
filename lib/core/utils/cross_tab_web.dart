import 'dart:async';

import 'eod_sync_firestore.dart';

/// إشعار فوري عند ترحيل تقرير — أصبح لاغياً لأن النظام الأساسي يستقبل
/// مباشرة عبر `onSnapshot` على المجموعة المشتركة في السحابة.
void notifyReportSent(Map<String, Object?> info) {}

StreamSubscription<Map<String, Object?>>? _watchSub;

/// بث مباشر لأي تقرير وصل حديثاً من الفروع (يقود `onSnapshot` على Firestore).
Stream<Map<String, Object?>> onReportSent() {
  final controller = StreamController<Map<String, Object?>>.broadcast();
  _watchSub ??= eodWatchReports().listen(
    controller.add,
    onError: (_) {},
  );
  return controller.stream;
}