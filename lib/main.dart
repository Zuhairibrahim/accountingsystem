// ============================================================================
//  © 2026 Zuhair Ibrahim — ALL RIGHTS RESERVED | جميع الحقوق محفوظة © زهير إبراهيم
//  Project: Accounting System — نظام المحاسبة المتكامل
//  This code contains a proprietary embedded copyright fingerprint.
//  Selling, redistributing, or removing this notice is strictly forbidden.
//  ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/utils/embedded_marker.dart';
import 'core/utils/runtime_error_reporter.dart';
import 'systems/branch_registry.dart';
import 'systems/system_config.dart';
import 'core/ownership/ownership_guard.dart';

/// بصمة الملكية الفكرية — يُمنع حذفها أو تعديلها (انظر ملف LICENSE)
/// Proprietary ownership fingerprint — must NOT be removed or altered (see LICENSE).
const String kAppOwnershipFingerprint =
    'OWNER:Zuhair-Ibrahim|PROJECT:accountingsystem|YEAR:2026|'
    'LICENSE:ALL-RIGHTS-RESERVED|SIG:ZI-2026-ACC-PROPRIETARY';

Future<void> main() async {
  assert(ownershipSealsIntact(), 'Ownership seals must remain intact — see LICENSE');
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