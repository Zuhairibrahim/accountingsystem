import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// تنزيل نص كملف في المتصفح (يُستخدم لإرسال تقرير نهاية اليوم)
void downloadTextFile(String filename, String content) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

/// فتح نافذة اختيار ملف وإرجاع محتواه كنص (يُستخدم لاستقبال تقرير في النظام الأساسي)
Future<String?> pickFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'application/json,.json';
  web.document.body?.append(input);

  final completer = Completer<String?>();
  var handled = false;
  void onChanged(web.Event _) async {
    if (handled) return;
    handled = true;
    final file = input.files?.item(0);
    input.remove();
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    try {
      final text = (await file.text().toDart).toDart;
      if (!completer.isCompleted) completer.complete(text);
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
  }

  input.addEventListener('change', onChanged.toJS);
  input.click();
  return completer.future;
}