import 'dart:async';

import 'eod_sync_firestore.dart';

/// إشعار فوري عند ترحيل تقرير — أصبح لاغياً لأن النظام الأساسي يستقبل
/// مباشرة عبر `onSnapshot` على المجموعة المشتركة في السحابة.
void notifyReportSent(Map<String, Object?> info) {}

bool _watchStarted = false;

/// بث مباشر لأي تقرير وصل حديثاً من الفروع (يقود `onSnapshot` على Firestore).
Stream<Map<String, Object?>> onReportSent() {
  final controller = StreamController<Map<String, Object?>>.broadcast();
  if (!_watchStarted) {
    _watchStarted = true;
    eodWatchReports().listen(
      controller.add,
      onError: (_) {},
    );
  }
  return controller.stream;
}