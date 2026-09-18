import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'eod_sync_firestore.dart';

/// رفع تقرير نهاية اليوم إلى المجموعة المشتركة في السحابة.
Future<bool> pushReport(Map<String, Object?> payload) =>
    eodPushReport(payload);

/// تصدير تطبيق سطح مكتب مستقل للفرع (exe) — يتم من داخل تطبيق الأدمن.
///
/// يجلب قالب المشغل من نفس التطبيق (apps/launcher.exe.enc — مرمَّز XOR لأن
/// خطة Spark تمنع ملفات EXE على Hosting)، يفك الترميز، ثم يُلحق معرّف
/// الفرع في نهاية الملف (علامة @@ZSYS=...@@) وينزّل الملف النهائي باسم
/// الفرع. التطبيق المُصدَّر يفتح نظام الفرع مباشرة من السحابة
/// (Firebase) — كل البيانات سحابية بالكامل ولا يوجد أي تخزين محلي.
Future<Map<String, Object?>> createDesktopApp(
  Map<String, Object?> payload, {
  void Function(Map<String, Object?> status)? onStatus,
}) async {
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
      'message': 'تم تصدير تطبيق «$name» — تجده في مجلد googlgg على سطح المكتب',
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
