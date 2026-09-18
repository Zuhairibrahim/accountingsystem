import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// مجموعة تقارير الأقسام المشتركة (المنتجات/الموظفين):
/// كل نظام (فرع أو أدمن) يكتب تقريره الشامل هنا فتيصل للنظام الأساسي
/// فوراً عبر `onSnapshot` — نفس آلية تقارير نهاية اليوم تماماً.
const String kSectionReportsCollection = 'accounting_section_reports';

CollectionReference<Map<String, dynamic>> _ref() =>
    FirebaseFirestore.instance.collection(kSectionReportsCollection);

/// معرف وثيقة تقرير القسم: النوع ثم كود النظام ثم التاريخ والوقت.
String sectionDocId(String type, String branchCode) {
  final now = DateTime.now();
  final stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
      '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  return '${type}_${branchCode}_$stamp';
}

/// رفع تقرير قسم شامل (منتجات/موظفين) إلى المجموعة المشتركة.
///
/// [type] نوع القسم (products/employees) — [title] عنوان التقرير —
/// [stats] بطاقات إحصائية [{label, value}] — [columns] رؤوس الأعمدة —
/// [rows] صفوف الجدول — [totalsRow] صف الإجماليات.
Future<bool> sectionPushReport({
  required String type,
  required String typeLabel,
  required String title,
  required String subtitle,
  required String branchCode,
  required String branchName,
  required String systemId,
  required List<Map<String, Object?>> stats,
  required List<String> columns,
  required List<List<String>> rows,
  List<String>? totalsRow,
}) async {
  try {
    if (branchCode.isEmpty || rows.isEmpty) return false;
    final now = DateTime.now();
    final record = <String, Object?>{
      'type': type,
      'type_label': typeLabel,
      'title': title,
      'subtitle': subtitle,
      'branch_code': branchCode,
      'branch_name': branchName,
      'system_id': systemId,
      'report_date': now.toIso8601String().substring(0, 10),
      'generated_at': now.toIso8601String(),
      'received_at': now.toIso8601String(),
      'rows_count': rows.length,
      'stats': stats,
      'columns': columns,
      'rows': rows,
      'totals': totalsRow ?? const <String>[],
    };
    await _ref().doc(sectionDocId(type, branchCode)).set(record);
    return true;
  } catch (_) {
    return false;
  }
}

/// قراءة كل تقارير الأقسام (الأحدث أولاً).
Future<List<Map<String, Object?>>> sectionFetchReports() async {
  try {
    final snap = await _ref()
        .orderBy('received_at', descending: true)
        .limit(200)
        .get();
    return [
      for (final d in snap.docs)
        <String, Object?>{...Map<String, dynamic>.from(d.data()), 'id': d.id},
    ];
  } catch (_) {
    return [];
  }
}

/// بث مباشر لأي تقرير قسم جديد يصل من أي نظام.
Stream<List<Map<String, Object?>>> sectionWatchReports() {
  final controller = StreamController<List<Map<String, Object?>>>.broadcast();
  _ref()
      .orderBy('received_at', descending: true)
      .limit(200)
      .snapshots()
      .listen(
        (snap) {
          controller.add([
            for (final d in snap.docs)
              <String, Object?>{
                ...Map<String, dynamic>.from(d.data()),
                'id': d.id,
              },
          ]);
        },
        onError: (_) {},
      );
  return controller.stream;
}

/// حذف تقرير قسم من المجموعة المشتركة (من النظام الأساسي).
Future<void> sectionDeleteReport(String docId) async {
  if (docId.isEmpty) return;
  try {
    await _ref().doc(docId).delete();
  } catch (_) {
    // الغياب — إن لم يعد التقرير موجوداً
  }
}
