import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../systems/system_config.dart';
import '../reports/full_report_dialog.dart';

/// نوع الحقل في نموذج الجدول
enum FieldType { text, number, date }

/// تعريف عمود/حقل يظهر في الجدول وفي نموذج الإضافة والتعديل
class ColumnField {
  final String field;
  final String label;
  final FieldType type;

  const ColumnField(this.field, this.label, {this.type = FieldType.text});
}

/// صفحة وحدة عامة: عرض السجلات + إضافة + تعديل + حذف + بحث
/// تعمل مباشرة على Firestore عبر DatabaseService
class DataModulePage extends StatefulWidget {
  final String title;
  final String storeName;
  final List<ColumnField> columns;

  const DataModulePage({
    super.key,
    required this.title,
    required this.storeName,
    required this.columns,
  });

  @override
  State<DataModulePage> createState() => _DataModulePageState();
}

class _DataModulePageState extends State<DataModulePage> {
  final DatabaseService _svc = DatabaseService.instance;
  List<Map<String, Object?>> _records = [];
  bool _loading = true;
  String _query = '';

  static final NumberFormat _num = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _svc.getAll(widget.storeName);
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  List<Map<String, Object?>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _records;
    return _records.where((r) {
      return r.values.any(
        (v) => v != null && v.toString().toLowerCase().contains(q),
      );
    }).toList();
  }

  /// معالج زر «عرض التقارير» — تقرير شامل لكل قسم (عرض + طباعة + إرسال)
  VoidCallback get _reportHandler => switch (widget.storeName) {
        AppConstants.tEmployees => _openEmployeesReport,
        AppConstants.tSalaryRecords => _openSalariesReport,
        AppConstants.tStockMovements => _openStockReport,
        _ => _openModuleReport,
      };

  // ==================== نموذج الإضافة / التعديل ====================
  Future<void> _openForm([Map<String, Object?>? record]) async {
    final isEdit = record != null;
    final messenger = ScaffoldMessenger.of(context);
    final controllers = <String, TextEditingController>{
      for (final c in widget.columns)
        c.field: TextEditingController(
          text: record?[c.field]?.toString() ?? '',
        ),
    };
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isEdit ? 'تعديل: ${widget.title}' : 'إضافة جديدة: ${widget.title}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in widget.columns)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        controller: controllers[c.field],
                        keyboardType: c.type == FieldType.number
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(labelText: c.label),
                        validator: c.type == FieldType.number
                            ? (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'مطلوب';
                                }
                                if (num.tryParse(v) == null) {
                                  return 'أدخل رقماً';
                                }
                                return null;
                              }
                            : (v) => (v == null || v.trim().isEmpty)
                                  ? 'مطلوب'
                                  : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
            ),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final data = <String, Object?>{};
              for (final c in widget.columns) {
                final text = controllers[c.field]!.text.trim();
                if (text.isEmpty) continue;
                data[c.field] = switch (c.type) {
                  FieldType.number =>
                    num.tryParse(text) ?? double.tryParse(text) ?? text,
                  FieldType.date => text,
                  FieldType.text => text,
                };
              }
              if (isEdit) {
                await _svc.update(
                  widget.storeName,
                  (record['id'] as num).toInt(),
                  data,
                );
              } else {
                await _svc.insert(widget.storeName, data);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _load();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    isEdit ? 'تم التعديل بنجاح' : 'تم الحفظ في السحابة',
                  ),
                ),
              );
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== حذف ====================
  Future<void> _confirmDelete(Map<String, Object?> record) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا السجل نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.delete(
      widget.storeName,
      (record['id'] as num).toInt(),
    );
    _load();
    messenger.showSnackBar(const SnackBar(content: Text('تم الحذف')));
  }

  // ==================== التقرير الشامل للموظفين (عرض + طباعة) ====================
  Future<void> _openEmployeesReport() async {
    final sys = SystemConfig.instance;
    final now = DateTime.now();
    final dateLabel =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final employees = await _svc.getAll(
      AppConstants.tEmployees,
      sortAsc: ['name'],
    );
    final salaries = await _svc.getAll(AppConstants.tSalaryRecords);
    final attendance = await _svc.getAll(AppConstants.tAttendance);
    final monthAttendance = attendance
        .where((r) => (r['date']?.toString() ?? '').startsWith(monthKey))
        .toList();

    var totalBase = 0.0;
    var totalNet = 0.0;
    var monthPresent = 0;
    var monthAbsent = 0;
    final rows = <List<String>>[];

    for (var i = 0; i < employees.length; i++) {
      final e = employees[i];
      final id = (e['id'] as num?)?.toInt();
      final name = e['name']?.toString() ?? '-';
      final base = ((e['base_salary'] as num?) ?? 0).toDouble();
      final net = ((e['net_salary'] as num?) ?? 0).toDouble();
      totalBase += base;
      totalNet += net;

      var present = 0;
      var absent = 0;
      for (final r in monthAttendance) {
        if ((r['employee_id'] as num?)?.toInt() != id) continue;
        switch (r['status']?.toString()) {
          case 'present':
          case 'late':
            present++;
          case 'absent':
            absent++;
        }
      }
      monthPresent += present;
      monthAbsent += absent;

      var lastSalary = '—';
      int? lastYear;
      int? lastMonth;
      for (final s in salaries) {
        if ((s['employee_id'] as num?)?.toInt() != id &&
            s['employee']?.toString() != name) {
          continue;
        }
        final y = int.tryParse(s['year']?.toString() ?? '') ?? 0;
        final m = int.tryParse(s['month']?.toString() ?? '') ?? 0;
        if (y > (lastYear ?? 0) || (y == lastYear && m >= (lastMonth ?? 0))) {
          lastYear = y;
          lastMonth = m;
          final netVal = ((s['net'] as num?) ?? (s['net_salary'] as num?) ?? 0);
          lastSalary = '${_num.format(netVal)} ($m/$y)';
        }
      }

      rows.add([
        '${i + 1}',
        name,
        e['phone']?.toString().isEmpty == false
            ? e['phone'].toString()
            : '—',
        _num.format(base),
        _num.format(net),
        '$present',
        '$absent',
        lastSalary,
      ]);
    }

    if (!mounted) return;
    await showFullReportDialog(
      context: context,
      title: 'التقرير الشامل لقسم الموظفين',
      subtitle:
          '${sys.systemLabel} (${sys.branchCode}) — عدد الموظفين: '
          '${employees.length} — بتاريخ $dateLabel',
      reportType: 'employees',
      reportTypeLabel: 'تقرير الموظفين',
      stats: [
        ReportStat('عدد الموظفين', '${employees.length}', const Color(0xFF2563EB)),
        ReportStat('إجمالي الرواتب الأساسية', _num.format(totalBase), const Color(0xFF7C3AED)),
        ReportStat('إجمالي الرواتب الصافية', _num.format(totalNet), const Color(0xFFD97706)),
        ReportStat('حضور هذا الشهر', '$monthPresent يوم', const Color(0xFF16A34A)),
        ReportStat('غياب هذا الشهر', '$monthAbsent يوم', const Color(0xFFDC2626)),
      ],
      columns: const [
        ReportColumn('#'),
        ReportColumn('اسم الموظف'),
        ReportColumn('الهاتف'),
        ReportColumn('الراتب الأساسي'),
        ReportColumn('صافي الراتب'),
        ReportColumn('حضور (الشهر)'),
        ReportColumn('غياب (الشهر)'),
        ReportColumn('آخر راتب مستلم'),
      ],
      rows: rows,
      totalsRow: [
        'الإجمالي',
        '${employees.length} موظف',
        '',
        _num.format(totalBase),
        _num.format(totalNet),
        '$monthPresent',
        '$monthAbsent',
        '',
      ],
    );
  }

  // ==================== التقرير الشامل للرواتب (عرض + طباعة) ====================
  Future<void> _openSalariesReport() async {
    final sys = SystemConfig.instance;
    final now = DateTime.now();
    final dateLabel =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    final records = await _svc.getAll(
      AppConstants.tSalaryRecords,
      sortDesc: ['year', 'month'],
    );

    var totalBase = 0.0;
    var totalAllow = 0.0;
    var totalDeduct = 0.0;
    var totalNet = 0.0;
    final employees = <String>{};
    final rows = <List<String>>[];

    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final base = ((r['base_salary'] as num?) ?? 0).toDouble();
      final allow = ((r['allowances'] as num?) ?? 0).toDouble();
      final deduct = ((r['deductions'] as num?) ?? 0).toDouble();
      final net = ((r['net'] as num?) ?? (r['net_salary'] as num?) ?? 0)
          .toDouble();
      totalBase += base;
      totalAllow += allow;
      totalDeduct += deduct;
      totalNet += net;
      final emp = r['employee']?.toString().isNotEmpty == true
          ? r['employee'].toString()
          : (r['employee_id']?.toString() ?? '—');
      employees.add(emp);
      rows.add([
        '${i + 1}',
        emp,
        '${r['month'] ?? '-'}',
        '${r['year'] ?? '-'}',
        _num.format(base),
        _num.format(allow),
        _num.format(deduct),
        _num.format(net),
      ]);
    }

    if (!mounted) return;
    await showFullReportDialog(
      context: context,
      title: 'التقرير الشامل للرواتب',
      subtitle:
          '${sys.systemLabel} (${sys.branchCode}) — عدد السجلات: '
          '${records.length} — بتاريخ $dateLabel',
      reportType: 'salaries',
      reportTypeLabel: 'تقرير الرواتب',
      stats: [
        ReportStat('عدد سجلات الرواتب', '${records.length}', const Color(0xFF2563EB)),
        ReportStat('عدد الموظفين المرصدة', '${employees.length}', const Color(0xFF7C3AED)),
        ReportStat('إجمالي الرواتب الأساسية', _num.format(totalBase), const Color(0xFFD97706)),
        ReportStat('إجمالي البدلات', _num.format(totalAllow), const Color(0xFF16A34A)),
        ReportStat('إجمالي الخصومات', _num.format(totalDeduct), const Color(0xFFDC2626)),
        ReportStat('إجمالي الصافي المدفوع', _num.format(totalNet), const Color(0xFF059669)),
      ],
      columns: const [
        ReportColumn('#'),
        ReportColumn('الموظف'),
        ReportColumn('الشهر'),
        ReportColumn('السنة'),
        ReportColumn('الأساسي'),
        ReportColumn('البدلات'),
        ReportColumn('الخصومات'),
        ReportColumn('الصافي'),
      ],
      rows: rows,
      totalsRow: [
        'الإجمالي',
        '${employees.length} موظف',
        '',
        dateLabel,
        _num.format(totalBase),
        _num.format(totalAllow),
        _num.format(totalDeduct),
        _num.format(totalNet),
      ],
    );
  }

  // ==================== التقرير الشامل للمخزون (عرض + طباعة) ====================
  Future<void> _openStockReport() async {
    final sys = SystemConfig.instance;
    final now = DateTime.now();
    final dateLabel =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    final records = await _svc.getAll(
      AppConstants.tStockMovements,
      sortDesc: ['date'],
    );

    var totalQty = 0.0;
    var maxQty = 0.0;
    final products = <String>{};
    final warehouses = <String>{};
    final rows = <List<String>>[];

    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final qty = ((r['qty'] as num?) ?? 0).toDouble();
      totalQty += qty;
      if (qty > maxQty) maxQty = qty;
      final product = r['product']?.toString().isNotEmpty == true
          ? r['product'].toString()
          : '—';
      final warehouse = r['warehouse']?.toString().isNotEmpty == true
          ? r['warehouse'].toString()
          : '—';
      products.add(product);
      warehouses.add(warehouse);
      rows.add([
        '${i + 1}',
        product,
        warehouse,
        r['type']?.toString().isNotEmpty == true ? r['type'].toString() : '—',
        _num.format(qty),
        r['date']?.toString().isNotEmpty == true ? r['date'].toString() : '—',
      ]);
    }

    if (!mounted) return;
    await showFullReportDialog(
      context: context,
      title: 'التقرير الشامل للمخزون وحركاته',
      subtitle:
          '${sys.systemLabel} (${sys.branchCode}) — عدد الحركات: '
          '${records.length} — بتاريخ $dateLabel',
      reportType: 'stock',
      reportTypeLabel: 'تقرير المخزون',
      stats: [
        ReportStat('عدد حركات المخزون', '${records.length}', const Color(0xFF2563EB)),
        ReportStat('إجمالي الكميات المتحركة', _num.format(totalQty), const Color(0xFF7C3AED)),
        ReportStat('أكبر حركة كمية', _num.format(maxQty), const Color(0xFFD97706)),
        ReportStat('عدد المنتجات المختلفة', '${products.length}', const Color(0xFF16A34A)),
        ReportStat('عدد المستودعات', '${warehouses.length}', const Color(0xFF0F172A)),
      ],
      columns: const [
        ReportColumn('#'),
        ReportColumn('المنتج'),
        ReportColumn('المستودع'),
        ReportColumn('نوع الحركة'),
        ReportColumn('الكمية'),
        ReportColumn('التاريخ'),
      ],
      rows: rows,
      totalsRow: [
        'الإجمالي',
        '${products.length} منتج',
        '${warehouses.length} مستودع',
        '',
        _num.format(totalQty),
        '',
      ],
    );
  }

  // ==================== تقرير شامل عام لأي قسم (عرض + طباعة) ====================
  Future<void> _openModuleReport() async {
    final sys = SystemConfig.instance;
    final now = DateTime.now();
    final dateLabel =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    final records = await _svc.getAll(widget.storeName);

    final numericFields = <String>{
      for (final c in widget.columns)
        if (c.type == FieldType.number) c.field,
    };
    final totals = <String, double>{};
    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final row = <String>['${i + 1}'];
      for (final c in widget.columns) {
        final v = r[c.field];
        if (v is num) {
          if (numericFields.contains(c.field)) {
            totals[c.field] = (totals[c.field] ?? 0) + v.toDouble();
            row.add(_num.format(v));
          } else {
            row.add(v.toString());
          }
        } else {
          row.add(v == null || v.toString().isEmpty ? '—' : v.toString());
        }
      }
      rows.add(row);
    }

    final stats = <ReportStat>[
      ReportStat('عدد السجلات', '${records.length}', const Color(0xFF2563EB)),
      for (final c in widget.columns)
        if (numericFields.contains(c.field))
          ReportStat(
            'إجمالي ${c.label}',
            _num.format(totals[c.field] ?? 0),
            const Color(0xFFD97706),
          ),
    ];

    if (!mounted) return;
    await showFullReportDialog(
      context: context,
      title: 'التقرير الشامل — ${widget.title}',
      subtitle:
          '${sys.systemLabel} (${sys.branchCode}) — عدد السجلات: '
          '${records.length} — بتاريخ $dateLabel',
      reportType: widget.storeName,
      reportTypeLabel: 'تقرير ${widget.title}',
      stats: stats,
      columns: [
        const ReportColumn('#'),
        for (final c in widget.columns) ReportColumn(c.label),
      ],
      rows: rows,
      totalsRow: [
        'الإجمالي',
        for (final c in widget.columns)
          numericFields.contains(c.field)
              ? _num.format(totals[c.field] ?? 0)
              : '',
      ],
    );
  }

  // ==================== البناء ====================
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'بحث...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(
                        color: Color(0xFFCA8A04),
                        width: 1.5,
                      ),
                    ),
                    onPressed: _records.isEmpty ? null : _reportHandler,
                    icon: const Icon(Icons.summarize_outlined, size: 18),
                    label: const Text('عرض التقارير'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                    ),
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      'إضافة ${widget.title}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: _filtered.isEmpty ? _buildEmpty() : _buildTable(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          const Text('لا توجد سجلات بعد'),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('أضف السجل الأول'),
          ),
        ],
      ),
    );
  }

  Widget _cellValue(Object? value) {
    if (value == null) return const Text('—');
    if (value is num) {
      if (value is int) return Text('$value');
      return Text(_num.format(value));
    }
    return Text(value.toString());
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: DataTable(
          headingRowHeight: 44,
          showCheckboxColumn: false,
          columns: [
            const DataColumn(
              label: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final c in widget.columns) DataColumn(label: Text(c.label)),
            const DataColumn(label: Text('إجراءات')),
          ],
          rows: [
            for (var i = 0; i < _filtered.length; i++)
              DataRow(
                cells: [
                  DataCell(Text('${i + 1}')),
                  for (final c in widget.columns)
                    DataCell(_cellValue(_filtered[i][c.field])),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _openForm(_filtered[i]),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.blueGrey,
                          ),
                          tooltip: 'تعديل',
                        ),
                        IconButton(
                          onPressed: () => _confirmDelete(_filtered[i]),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          tooltip: 'حذف',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
