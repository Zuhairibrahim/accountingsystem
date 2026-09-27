import 'dart:io';

import 'package:flutter/services.dart';

/// معرّف النظام المضمّن في ذيل ملف الـ APK (علامة @@ZSYS=...@@).
///
/// تطبيق التلفون يقرأ ملفه نفسه عند الإقلاع ليعرف فرعه — هكذا يُصدَّر
/// تطبيق مستقل لكل فرع من قالب واحد موقّع دون إعادة بناء أو توقيع:
/// مخطط توقيع APK v2/v3 لا يشمل تعليق الأرشيف، فبقاء التوقيع صالحاً
/// مضمون بعد إلحاق العلامة.
Future<String?> embeddedMode() async {
  try {
    if (!Platform.isAndroid) return null;
    final path = await const MethodChannel('app/embedded')
        .invokeMethod<String>('apkPath');
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    final length = await file.length();
    if (length == 0) return null;
    final start = length > 1024 ? length - 1024 : 0;
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      final data = await raf.read(length - start);
      final text = String.fromCharCodes(data);
      final m = RegExp(r'@@ZSYS=([^@]+)@@').firstMatch(text);
      if (m != null) {
        final mode = m.group(1)!.trim().toLowerCase();
        if (mode.isNotEmpty) return mode;
      }
    } finally {
      await raf.close();
    }
  } catch (_) {
    // لا يمنع إقلاع التطبيق أبداً
  }
  return null;
}
