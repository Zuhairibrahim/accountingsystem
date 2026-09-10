import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../systems/system_config.dart';
import 'eod_sync_firestore.dart';

const Duration _timeout = Duration(milliseconds: 8000);

/// رفع تقرير نهاية اليوم إلى المجموعة المشتركة في السحابة.
Future<bool> pushReport(Map<String, Object?> payload) =>
    eodPushReport(payload);

/// طلب من الخادم المحلي إنشاء تطبيق مستقل (اختصار سطح المكتب) لفرع جديد.
/// يُستدعى تلقائياً من النظام الأساسي عند إنشاء فرع جديد — يعمل فقط محلياً.
Future<bool> createDesktopApp(Map<String, Object?> payload) async {
  try {
    final headers = web.Headers();
    headers.set('Content-Type', 'text/plain;charset=UTF-8');
    final res = await web.window
        .fetch(
          '${SystemConfig.localRelayBase}/api/create_app'.toJS,
          web.RequestInit(
            method: 'POST',
            body: jsonEncode(payload).toJS,
            headers: headers,
          ),
        )
        .toDart
        .timeout(_timeout);
    return res.status == 200;
  } catch (_) {
    return false;
  }
}

/// قراءة كل تقارير الفروع في المجموعة المشتركة.
Future<List<Map<String, Object?>>> fetchReports() => eodFetchReports();