import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/utils/embedded_marker.dart';
import 'core/utils/runtime_error_reporter.dart';
import 'systems/branch_registry.dart';
import 'systems/system_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // مراقبة أخطاء وقت التشغيل — كل خطأ يصل للوحة الأدمن فوراً
  RuntimeErrorReporter.install();
  // تحديد النظام الحالي: من الرابط (?sys=) أو من العلامة المضمّنة
  // داخل تطبيق التلفون (APK) — ثم تهيئة الإعلانات بالخلفية
  final embedded = await embeddedMode();
  SystemConfig.instance.init(null, embedded);
  unawaited(AdService.instance.init());
  runApp(const ProviderScope(child: AccountingApp()));
  // تحميل إعدادات الفرع الديناميكي (إن كانت الصفحة مفتوحة لفرع مُضاف)
  BranchRegistry.instance.ensureCurrentReady();
}