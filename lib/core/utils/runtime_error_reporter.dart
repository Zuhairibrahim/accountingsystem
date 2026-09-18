import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'audit_log_service.dart';

/// مراقبة أخطاء وقت التشغيل — تلتقط كل خطأ يحدث أثناء عمل التطبيق
/// (أخطاء الواجهة + أخطاء التنفيذ غير الملتقطة) وترسله فوراً إلى
/// سجل العمليات في السحابة `accounting_audit_logs` ليظهر مباشرة
/// في لوحة تحكم الأدمن — بدون أي تخزين محلي وبلا أي تعطيل للتطبيق.
///
/// مزايا:
/// - لا يُغرق السجل: نفس الخطأ لا يُرسل مرة أخرى قبل 30 ثانية.
/// - لا يكسر أبداً العمل الأصلي: كل فشل في الإرسال يُتجاهل بصمت.
/// - يعمل في الأدمن وكل الفروع (كل نظام يظهر أخطاؤه باسمه وكوده).
class RuntimeErrorReporter {
  RuntimeErrorReporter._();

  static final Set<String> _sent = <String>{};
  static final Map<String, DateTime> _lastSent = <String, DateTime>{};

  /// تركيب المراقب — تُستدعى مرة واحدة عند إقلاع التطبيق.
  static void install() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      _report('خطأ واجهة', details.exception, details.stack);
      original?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _report('خطأ تنفيذ', error, stack);
      return true;
    };
  }

  static void _report(String kind, Object error, StackTrace? stack) {
    try {
      final key = '$kind:$error';
      final now = DateTime.now();
      final last = _lastSent[key];
      if (last != null && now.difference(last).inSeconds < 30) {
        return; // نفس الخطأ يتكرر بسرعة — تجاهل
      }
      _lastSent[key] = now;
      _sent.add(key);
      if (_sent.length > 200) {
        _sent.clear();
        _lastSent.clear();
      }

      var text = error.toString();
      if (text.length > 400) text = text.substring(0, 400);
      var frames = stack?.toString().split('\n') ?? const <String>[];
      frames = frames.take(4).toList();
      final stackText = frames.join(' | ').trim();

      unawaited(
        AuditLogService.record(
          AuditAction.runtimeError,
          details: stackText.isEmpty
              ? '$kind: $text'
              : '$kind: $text\n$stackText',
          actor: 'مراقب النظام',
        ),
      );
    } catch (_) {
      // لا يكسر أبداً التشغيل
    }
  }
}
