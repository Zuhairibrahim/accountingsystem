import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

/// مجموعة التقارير المشتركة: كل فرع يكتب تقرير نهاية اليوم/الحضور هنا
/// فيصل للنظام الأساسي فوراً عبر `onSnapshot` — بلا أي صندوق بريد محلي.
const String kEodReportsCollection = 'accounting_eod_reports';

CollectionReference<Map<String, dynamic>> _reportsRef() =>
    FirebaseFirestore.instance.collection(kEodReportsCollection);

/// معرف وثيقة التقرير: النوع ثم كود الفرع ثم التاريخ.
String eodDocId(String format, String branchCode, String reportDate) {
  final type = format == 'branch_attendance_report' ? 'attendance' : 'eod';
  return '${type}_${branchCode}_${reportDate.replaceAll('/', '-')}';
}

/// تسطيح JSON التقرير الكامل (مع `summary` والسلاسل) إلى سجل Flat
/// يُخزَّن في المجموعة المشتركة ويُسهَّل عرضه في النظام الأساسي.
Map<String, Object?> flattenEodReport(Map<String, Object?> payload) {
  final format = payload['format']?.toString() ?? 'branch_end_of_day_report';
  final rawSummary = payload['summary'];
  final summary = rawSummary is Map
      ? Map<String, Object?>.from(rawSummary)
      : <String, Object?>{};
  final code = payload['branch_code']?.toString() ?? '';
  final date = payload['report_date']?.toString() ?? '';
  final base = <String, Object?>{
    'type': format == 'branch_attendance_report' ? 'attendance' : 'eod',
    'format': format,
    'branch_code': code,
    'branch_name': payload['branch_name']?.toString() ?? code,
    'system_id': payload['system_id']?.toString() ?? '',
    'report_date': date,
    'generated_at': payload['generated_at']?.toString() ?? '',
    'received_at': DateTime.now().toIso8601String(),
  };
  if (format == 'branch_attendance_report') {
    base.addAll({
      'total_employees': summary['total_employees'] ?? 0,
      'present': summary['present'] ?? 0,
      'absent': summary['absent'] ?? 0,
      'leave': summary['leave'] ?? 0,
      'late': summary['late'] ?? 0,
      'employees': jsonEncode(payload['employees'] ?? const <Object?>[]),
    });
  } else {
    base.addAll({
      'total_amount': summary['total_amount'] ?? 0,
      'invoice_count': summary['invoice_count'] ?? 0,
      'product_count': summary['product_count'] ?? 0,
      'currency':
          payload['currency']?.toString() ?? AppConstants.defaultCurrency,
      'products': jsonEncode(payload['products'] ?? const <Object?>[]),
      'stock': jsonEncode(payload['stock'] ?? const <Object?>[]),
      'invoices': jsonEncode(payload['invoices'] ?? const <Object?>[]),
    });
  }
  return base;
}

/// رفع تقرير إلى المجموعة المشتركة (يصل للنظام الأساسي فوراً).
Future<bool> eodPushReport(Map<String, Object?> payload) async {
  try {
    final record = flattenEodReport(payload);
    final code = record['branch_code']?.toString() ?? '';
    final date = record['report_date']?.toString() ?? '';
    if (code.isEmpty || date.isEmpty) return false;
    final format = payload['format']?.toString() ?? '';
    await _reportsRef().doc(eodDocId(format, code, date)).set(record);
    return true;
  } catch (_) {
    return false;
  }
}

/// قراءة كل التقارير في المجموعة المشتركة (محدثة أولاً).
Future<List<Map<String, Object?>>> eodFetchReports() async {
  try {
    final snap = await _reportsRef()
        .orderBy('received_at', descending: true)
        .get();
    return [
      for (final d in snap.docs)
        <String, Object?>{...Map<String, dynamic>.from(d.data()), 'id': d.id},
    ];
  } catch (_) {
    return [];
  }
}

/// بث مباشر لأي تقرير جديد/محدّث في المجموعة المشتركة.
Stream<Map<String, Object?>> eodWatchReports() {
  final controller = StreamController<Map<String, Object?>>.broadcast();
  _reportsRef().snapshots().listen(
    (snap) {
      for (final d in snap.docs) {
        controller.add(
          <String, Object?>{...Map<String, dynamic>.from(d.data()), 'id': d.id},
        );
      }
    },
    onError: (_) {},
  );
  return controller.stream;
}

/// حذف تقرير من المجموعة المشتركة.
Future<void> eodDeleteReport(String docId) async {
  if (docId.isEmpty) return;
  try {
    await _reportsRef().doc(docId).delete();
  } catch (_) {
    // الغياب — إن لم يعد التقرير موجوداً
  }
}