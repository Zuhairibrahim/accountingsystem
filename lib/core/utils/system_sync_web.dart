import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../systems/system_config.dart';
import 'eod_sync_firestore.dart';

const Duration _timeout = Duration(seconds: 120);

/// رفع تقرير نهاية اليوم إلى المجموعة المشتركة في السحابة.
Future<bool> pushReport(Map<String, Object?> payload) =>
    eodPushReport(payload);

/// طلب من الخادم المحلي على جهاز المستخدم إنشاء تطبيق مستقل لفرع جديد.
/// يُستدعى تلقائياً من النظام الأساسي عند إنشاء فرع جديد؛ العنوان `localhost`
/// لأن المتصفح يعمل على نفس الجهاز الذي يُنشأ عليه التطبيق (مجلد المسؤول).
/// المهلة طويلة (120 ثانية) حتى تُغطي توليد الأيقونة المخصصة للفرع (حتى 90 ث).
Future<bool> createDesktopApp(Map<String, Object?> payload) async {
  try {
    final headers = web.Headers();
    headers.set('Content-Type', 'text/plain;charset=UTF-8');
    final res = await web.window
        .fetch(
          'http://localhost:${SystemConfig.adminPort}/api/create_app'.toJS,
          web.RequestInit(
            method: 'POST',
            body: jsonEncode(payload).toJS,
            headers: headers,
          ),
        )
        .toDart
        .timeout(_timeout);
    if (res.status != 200) return false;
    final text = (await res.text().toDart).toDart;
    try {
      final body = jsonDecode(text);
      if (body is Map && body['ok'] == true) return true;
    } catch (_) {}
    return false;
  } catch (_) {
    return false;
  }
}

/// قراءة كل تقارير الفروع في المجموعة المشتركة.
Future<List<Map<String, Object?>>> fetchReports() => eodFetchReports();