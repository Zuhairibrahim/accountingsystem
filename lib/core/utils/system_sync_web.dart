import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'eod_sync_firestore.dart';

/// رفع تقرير نهاية اليوم إلى المجموعة المشتركة في السحابة.
Future<bool> pushReport(Map<String, Object?> payload) =>
    eodPushReport(payload);

/// الخادم المحلي لبناء تطبيقات الفروع — يشغّله تطبيق الأدمن تلقائياً
/// عند فتحه (launcher.py ← serve_all.py على المنفذ 8080).
const _localServer = 'http://localhost:8080';

/// مهلة انتظار بدء أمر البناء على الخادم المحلي (الاتصال الأولي).
const _startTimeoutMs = 8000;

/// المهلة الكلية لبناء التطبيق على الخادم المحلي (PyInstaller قد يستغرق
/// دقائق في أول بناء، ثم يتسارع كثيراً بفضل الكاش).
const _buildDeadlineMs = 360000;

/// تصدير تطبيق سطح مكتب مستقل للفرع (exe) — يتم من داخل تطبيق الأدمن.
///
/// المسار الأساسي: خادم التصدير المحلي (يعمل تلقائياً مع تطبيق الأدمن)
/// يبني تطبيقاً مستقلاً **بأيقونة تحمل اسم الفرع** ويضع التطبيق وملف
/// بيانات الدخول مباشرة في مجلد adszuhair على سطح المكتب — البيانات
/// داخل التطبيق كلها عبر السحابة (Firebase).
///
/// الاحتياط (إن تعذّر الخادم المحلي): تنزيل قالب المشغّل من نفس التطبيق
/// (apps/launcher.exe.enc — مرمَّز XOR لأن خطة Spark تمنع ملفات EXE على
/// Hosting)، يُفك الترميز ثم يُلحق معرّف الفرع بذيل الملف (علامة
/// @@ZSYS=...@@) ويُنزَّل باسم الفرع.
Future<Map<String, Object?>> createDesktopApp(
  Map<String, Object?> payload, {
  void Function(Map<String, Object?> status)? onStatus,
}) async {
  final local = await _createViaLocalServer(payload, onStatus);
  if (local != null && local['ok'] == true) return local;
  return _downloadTemplateApp(payload, onStatus);
}

// ==================== البناء المحلي (أيقونة باسم الفرع) ====================

Map<String, Object?> _jsonToMap(JSAny? js) {
  final dart = js.dartify();
  if (dart is! Map) return {};
  return {
    for (final e in dart.entries) e.key.toString(): e.value,
  };
}

Future<Map<String, Object?>?> _createViaLocalServer(
  Map<String, Object?> payload,
  void Function(Map<String, Object?> status)? onStatus,
) async {
  try {
    onStatus?.call({'step': 'الاتصال بخادم التصدير المحلي...'});
    final controller = web.AbortController();
    web.window.setTimeout(
      (() => controller.abort()).toJS,
      _startTimeoutMs.toJS,
    );
    final headers = web.Headers();
    headers.set('Content-Type', 'application/json');
    final init = web.RequestInit(
      method: 'POST',
      headers: headers,
      body: jsonEncode(payload).toJS,
      signal: controller.signal,
    );
    final res = await web.window
        .fetch('$_localServer/api/create_app'.toJS, init)
        .toDart;
    if (res.status != 200) return null;
    final data = _jsonToMap(await res.json().toDart);
    final buildId = data['build_id']?.toString() ?? '';
    if (data['ok'] != true || buildId.isEmpty) return null;

    // متابعة حالة البناء حية حتى الاكتمال (توليد الأيقونة ← بناء ← نسخ)
    final deadline = DateTime.now().add(
      const Duration(milliseconds: _buildDeadlineMs),
    );
    var lastStep = '';
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final stRes = await web.window
          .fetch('$_localServer/api/build_status?id=$buildId'.toJS)
          .toDart;
      if (stRes.status != 200) continue;
      final st = _jsonToMap(await stRes.json().toDart);
      final step = st['step']?.toString() ?? '';
      if (step.isNotEmpty && step != lastStep && step != 'اكتمل') {
        lastStep = step;
        onStatus?.call({'step': step});
      }
      if (st['done'] == true) {
        return {
          'done': true,
          'ok': st['ok'] == true,
          'message': st['message']?.toString() ?? '',
          'path': st['path']?.toString() ?? '',
          'apk': st['apk_path']?.toString() ?? '',
        };
      }
    }
    return null;
  } catch (_) {
    return null; // الخادم المحلي غير متاح ← الاحتياط عبر المتصفح
  }
}

// ==================== احتياط: تنزيل قالب المشغّل ====================

Future<Map<String, Object?>> _downloadTemplateApp(
  Map<String, Object?> payload,
  void Function(Map<String, Object?> status)? onStatus,
) async {
  try {
    final id = payload['id']?.toString() ?? '';
    final name = payload['name']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty) {
      return _fail('بيانات الفرع ناقصة');
    }

    onStatus?.call({'step': 'تحميل قالب التطبيق...'});
    final res = await web.window.fetch('apps/launcher.exe.enc'.toJS).toDart;
    if (res.status != 200) {
      return _fail('قالب التطبيق غير متوفر داخل هذا التطبيق');
    }
    final buffer = (await res.arrayBuffer().toDart).toDart;
    final encoded = Uint8List.view(
      buffer,
      0,
      buffer.lengthInBytes,
    );

    // فك ترميز XOR (نفس مفتاح tool/patch_web_build.py)
    const key = [0xA3, 0x5F, 0x2B, 0x7E];
    final template = Uint8List.fromList([
      for (var i = 0; i < encoded.length; i++) encoded[i] ^ key[i % key.length],
    ]);

    onStatus?.call({'step': 'تجهيز تطبيق الفرع...'});
    final marker = utf8.encode('@@ZSYS=$id@@');
    final out = Uint8List(template.length + marker.length);
    out.setAll(0, template);
    out.setAll(template.length, marker);

    onStatus?.call({'step': 'تنزيل التطبيق...'});
    final blob = web.Blob(
      [out.toJS].toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = '$name.exe';
    anchor.click();
    web.window.setTimeout(
      (() => web.URL.revokeObjectURL(url)).toJS,
      10000.toJS,
    );

    return {
      'done': true,
      'ok': true,
      'path': '$name.exe',
      'message': 'تم تصدير تطبيق «$name» — داخل مجلد ZuhairSystem على سطح '
          'المكتب (بدون أيقونة مخصصة — شغّل التطبيق من تطبيق الأدمن '
          'للحصول على الأيقونة باسم الفرع)',
    };
  } catch (e) {
    return _fail('تعذّر تصدير التطبيق: $e');
  }
}

Map<String, Object?> _fail(String message) => {
      'done': true,
      'ok': false,
      'message': message,
    };

/// قراءة كل تقارير الفروع في المجموعة المشتركة.
Future<List<Map<String, Object?>>> fetchReports() => eodFetchReports();
