import 'package:cloud_firestore/cloud_firestore.dart';

import '../../systems/system_config.dart';
import '../firebase/firebase_bootstrap.dart';

/// مجموعة سجل العمليات المشتركة: كل نظام (أدمن/فرع) يسجل عملياته هنا،
/// ويصل كل سجل للوحة تحكم الأدمن فوراً عبر `snapshots()` — بلا أي تخزين محلي.
///
/// السجل لا يُعطّل أبداً أي عملية أساسية: أي فشل في الكتابة يُتجاهل بصمت
/// حتى لا يتأثر إدخال البيانات أو الإرسال بسبب مشكلة في التوثيق.
const String kAuditLogsCollection = 'accounting_audit_logs';

/// أسماء العمليات الموحدة
class AuditAction {
  AuditAction._();

  static const String login = 'login';
  static const String createBranch = 'create_branch';
  static const String deleteBranch = 'delete_branch';
  static const String openBranchSystem = 'open_branch_system';
  static const String eodSent = 'eod_sent';
  static const String attendanceSent = 'attendance_sent';
  static const String importReport = 'import_report';
  static const String deleteReport = 'delete_report';
  static const String runtimeError = 'runtime_error';
  static const String changeCredentials = 'change_credentials';
}

/// تسجيل عمليات النظام في السحابة لفحصها من لوحة تحكم الأدمن.
class AuditLogService {
  AuditLogService._();

  static CollectionReference<Map<String, dynamic>> ref() =>
      FirebaseFirestore.instance.collection(kAuditLogsCollection);

  /// تسجيل عملية من النظام الحالي (معرف/الاسم/الكود تُملأ تلقائياً).
  static Future<void> record(
    String action, {
    String? details,
    String? actor,
  }) async {
    try {
      await FirebaseBootstrap.instance.initialize();
      final sys = SystemConfig.instance;
      await ref().add({
        'action': action,
        'action_label': _actionLabel(action),
        'system_id': sys.systemId,
        'system_name': sys.branchName,
        'branch_code': sys.branchCode,
        'details': details ?? '',
        'actor': actor ?? '',
        'time': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // تجاهل فشل التسجيل — لا يجب أن يمنع العملية الأصلية
    }
  }

  /// تسجيل عملية مع معرّف/اسم نظام محدد (مثل إجراءات الأدمن على نظام آخر).
  static Future<void> recordFor(
    String action, {
    String? systemId,
    String? systemName,
    String? branchCode,
    String? details,
    String? actor,
  }) async {
    try {
      await FirebaseBootstrap.instance.initialize();
      await ref().add({
        'action': action,
        'action_label': _actionLabel(action),
        'system_id': systemId ?? '',
        'system_name': systemName ?? '',
        'branch_code': branchCode ?? '',
        'details': details ?? '',
        'actor': actor ?? '',
        'time': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // تجاهل فشل التسجيل
    }
  }

  /// بث مباشر لآخر العمليات (أحدثها أولاً) — تستمع له لوحة تحكم الأدمن.
  static Stream<List<Map<String, Object?>>> watchAuditLogs({int limit = 300}) {
    return ref()
        .orderBy('time', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs)
                <String, Object?>{
                  ...Map<String, dynamic>.from(d.data()),
                  'id': d.id,
                },
            ]);
  }

  /// جلب لمرة واحدة لآخر العمليات (أحدثها أولاً).
  static Future<List<Map<String, Object?>>> fetchAuditLogs(
      {int limit = 300}) async {
    try {
      final snap = await ref()
          .orderBy('time', descending: true)
          .limit(limit)
          .get();
      return [
        for (final d in snap.docs)
          <String, Object?>{
            ...Map<String, dynamic>.from(d.data()),
            'id': d.id,
          },
      ];
    } catch (_) {
      return [];
    }
  }

  /// الاسم العربي الظاهر للعملية.
  static String _actionLabel(String action) => switch (action) {
        AuditAction.login => 'تسجيل دخول',
        AuditAction.createBranch => 'إنشاء فرع',
        AuditAction.deleteBranch => 'حذف فرع',
        AuditAction.openBranchSystem => 'فتح نظام فرع',
        AuditAction.eodSent => 'إرسال تقرير نهاية اليوم',
        AuditAction.attendanceSent => 'إرسال تقرير الحضور',
        AuditAction.importReport => 'استيراد تقرير',
        AuditAction.deleteReport => 'حذف تقرير',
        AuditAction.runtimeError => 'خطأ وقت التشغيل',
        AuditAction.changeCredentials => 'تغيير بيانات الدخول',
        _ => action,
      };
}