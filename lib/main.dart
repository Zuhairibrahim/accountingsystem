import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'systems/branch_registry.dart';
import 'systems/system_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // تحديد النظام الحالي من الرابط (?sys=...)
  SystemConfig.instance.init();
  // تهيئة AdMob (لا تعطّل إقلاع التطبيق — تُنفّذ بالخلفية)
  unawaited(AdService.instance.init());
  runApp(const ProviderScope(child: AccountingApp()));
  // تحميل إعدادات الفرع الديناميكي (إن كانت الصفحة مفتوحة لفرع مُضاف)
  BranchRegistry.instance.ensureCurrentReady();
}