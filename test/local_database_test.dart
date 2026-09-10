import 'package:flutter_test/flutter_test.dart';

import 'package:accountingsystem/core/database/db_filter.dart';
import 'package:accountingsystem/core/utils/eod_sync_firestore.dart';

void main() {
  group('DbFilter', () {
    test('equals وأسس المقارنة (أرقام/نص/تاريخ)', () {
      final r = <String, Object?>{
        'name': 'أحمد',
        'qty': 5,
        'date': DateTime(2026, 9, 11),
      };
      expect(DbFilter.equals('name', 'أحمد').accepts(r), isTrue);
      expect(DbFilter.equals('name', 'خالد').accepts(r), isFalse);
      expect(DbFilter.equals('qty', 5).accepts(r), isTrue);
      expect(DbFilter.equals('qty', 5.0).accepts(r), isTrue);
      expect(
        DbFilter.equals('date', DateTime(2026, 9, 11)).accepts(r),
        isTrue,
      );
    });

    test('greaterThan وlessThan', () {
      final r = <String, Object?>{'qty': 10};
      expect(DbFilter.greaterThan('qty', 5).accepts(r), isTrue);
      expect(DbFilter.greaterThan('qty', 20).accepts(r), isFalse);
      expect(DbFilter.lessThan('qty', 20).accepts(r), isTrue);
    });

    test('and وor', () {
      final r = <String, Object?>{'a': 1, 'b': 2};
      const eqA = DbFilter.equals('a', 1);
      const eqB = DbFilter.equals('b', 2);
      const neqB = DbFilter.equals('b', 99);
      expect(DbFilter.and([eqA, eqB]).accepts(r), isTrue);
      expect(DbFilter.and([eqA, neqB]).accepts(r), isFalse);
      expect(DbFilter.or([eqA, neqB]).accepts(r), isTrue);
      expect(DbFilter.or([neqB]).accepts(r), isFalse);
    });

    test('matches مع نمط منتظم', () {
      final r = <String, Object?>{'no': 'INV-000002'};
      expect(DbFilter.matches('no', '^INV-').accepts(r), isTrue);
      expect(DbFilter.matches('no', '^SAL-').accepts(r), isFalse);
    });

    test('arrayContains', () {
      final r = <String, Object?>{'roles': ['admin', 'sales']};
      expect(DbFilter.arrayContains('roles', 'admin').accepts(r), isTrue);
      expect(DbFilter.arrayContains('roles', 'x').accepts(r), isFalse);
    });
  });

  group('eod_sync_firestore', () {
    test('eodDocId يستخدم النوع واسم الفرع والتاريخ', () {
      expect(eodDocId('branch_end_of_day_report', 'BR01', '2026-09-11'),
          'eod_BR01_2026-09-11');
      expect(eodDocId('branch_attendance_report', 'BR02', '2026-09-11'),
          'attendance_BR02_2026-09-11');
    });

    test('flattenEodReport يحوّل تقرير نهاية اليوم إلى سجل مسطّح', () {
      final flat = flattenEodReport({
        'format': 'branch_end_of_day_report',
        'branch_code': 'BR01',
        'branch_name': 'فرع صنعاء',
        'system_id': 'branch1',
        'report_date': '2026-09-11',
        'generated_at': '2026-09-11T08:00:00',
        'currency': 'ر.ي',
        'summary': {'total_amount': 1500, 'invoice_count': 3, 'product_count': 2},
        'products': [
          {'name': 'منتج', 'sold_qty': 1},
        ],
      });
      expect(flat['type'], 'eod');
      expect(flat['branch_code'], 'BR01');
      expect(flat['total_amount'], 1500);
      expect(flat['invoice_count'], 3);
      expect(flat['received_at'], isNotEmpty);
      expect(flat['products'], isA<String>());
    });

    test('flattenEodReport يحوّل تقرير الحضور إلى سجل مسطّح', () {
      final flat = flattenEodReport({
        'format': 'branch_attendance_report',
        'branch_code': 'BR02',
        'branch_name': 'فرع عدن',
        'system_id': 'branch2',
        'report_date': '2026-09-11',
        'generated_at': '2026-09-11T08:00:00',
        'summary': {'total_employees': 10, 'present': 8, 'absent': 1,
                    'leave': 1, 'late': 0},
        'employees': [
          {'name': 'موظف', 'status': 'present'},
        ],
      });
      expect(flat['type'], 'attendance');
      expect(flat['total_employees'], 10);
      expect(flat['present'], 8);
      expect(flat['employees'], isA<String>());
    });
  });
}