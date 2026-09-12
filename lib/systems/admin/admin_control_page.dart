import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/audit_log_service.dart';
import '../../core/utils/cross_tab.dart';
import '../../core/utils/eod_sync_firestore.dart';
import '../../core/utils/file_transfer.dart';
import '../../core/utils/system_sync.dart';
import '../system_config.dart';

/// قسم الربط المركزي في النظام الأساسي:
/// يستقبل تقارير نهاية اليوم من كل نظام تلقائياً ومباشرة عبر السحابة
/// (المجموعة المشتركة `accounting_eod_reports` مع `onSnapshot`) ويعرضها
/// كل نظام في قسم خاص.
class AdminControlPage extends StatefulWidget {
  const AdminControlPage({super.key});

  @override
  State<AdminControlPage> createState() => _AdminControlPageState();
}

class _AdminControlPageState extends State<AdminControlPage> {
  List<Map<String, Object?>> _reports = [];
  List<Map<String, Object?>> _attendanceReports = [];
  List<Map<String, Object?>> _audits = [];
  bool _loading = true;
  bool _importing = false;
  bool _syncing = false;
  StreamSubscription<Map<String, Object?>>? _sub;
  StreamSubscription<List<Map<String, Object?>>>? _auditSub;
  final _filterController = TextEditingController();
  String _auditFilter = '';

  static final NumberFormat _num = NumberFormat('#,##0.00');
  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    // الاستقبال التلقائي الفوري: أي تقرير يكتبه فرع في السحابة يصل هنا مباشرة
    _sub = onReportSent().listen((_) => _syncAll());
    // سجل العمليات الحي: أي عملية في أي نظام تصل هنا فوراً
    _auditSub = AuditLogService.watchAuditLogs().listen((list) {
      if (mounted) setState(() => _audits = list);
    });
    _syncAll();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _auditSub?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  // ==================== الاستقبال التلقائي ====================
  /// كل التقارير تُقرأ مباشرة من المجموعة المشتركة في السحابة — أي تقرير
  /// يكتبه فرع يصل هنا فوراً (بلا أي صندوق بريد محلي أو استطلاع دوري).
  Future<void> _load() async {
    final all = await fetchReports();
    if (!mounted) return;
    setState(() {
      _reports = [
        for (final r in all)
          if (r['type'] == 'eod') r,
      ];
      _attendanceReports = [
        for (final r in all)
          if (r['type'] == 'attendance') r,
      ];
      _loading = false;
    });
  }

  Future<void> _syncAll() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await _load();
    if (!mounted) return;
    setState(() => _syncing = false);
  }

  // ==================== استقبال تقرير من ملف JSON ====================
  Future<void> _importReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await pickFile();
    if (text == null) return;

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(text);
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('not a map');
      }
      decoded = raw;
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('الملف غير صالح — يجب اختيار ملف تقرير JSON'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (decoded['format'] != 'branch_end_of_day_report') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('هذا الملف ليس تقرير نهاية يوم صالحاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final branchCode = decoded['branch_code']?.toString() ?? '';
    if (branchCode.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('التقرير لا يحتوي على كود فرع صالح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _importing = true);
    // رفع التقرير إلى المجموعة المشتركة في السحابة — يصل للنظام كما لو أرسله فرع.
    final pushed = await pushReport(Map<String, Object?>.from(decoded));
    await _syncAll();
    if (!mounted) return;
    setState(() => _importing = false);
    if (pushed) {
      AuditLogService.record(
        AuditAction.importReport,
        details:
            'استيراد تقرير ${decoded['branch_name']} ليوم ${decoded['report_date']}',
        actor: 'مدير النظام',
      );
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          pushed
              ? 'تم استقبال تقرير ${decoded['branch_name']} ليوم ${decoded['report_date']}'
              : 'تعذّر رفع التقرير إلى السحابة — تحقق من الاتصال',
        ),
        backgroundColor: pushed ? Colors.green.shade700 : Colors.red,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, Object?> report) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'حذف تقرير ${report['branch_name']} ليوم ${report['report_date']}؟',
        ),
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
    try {
      await eodDeleteReport(report['id']?.toString() ?? '');
    } catch (_) {
      // الغياب — إن حُذف التقرير من مصدر آخر
    }
    await _syncAll();
    AuditLogService.record(
      AuditAction.deleteReport,
      details:
          'حذف تقرير ${report['branch_name']} ليوم ${report['report_date']}',
      actor: 'مدير النظام',
    );
    messenger.showSnackBar(const SnackBar(content: Text('تم حذف التقرير')));
  }

  void _showDetail(Map<String, Object?> report) {
    List<Map<String, dynamic>> decode(Object? raw) {
      try {
        final d = jsonDecode(raw?.toString() ?? '[]');
        if (d is! List) return [];
        return [for (final e in d) e as Map<String, dynamic>];
      } catch (_) {
        return [];
      }
    }

    final products = decode(report['products']);
    final stock = decode(report['stock']);
    final invoices = decode(report['invoices']);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
          insetPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: 860,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${report['branch_name']} — تقرير ${report['report_date']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _detailChip(
                        'الإجمالي',
                        '${_num.format((report['total_amount'] as num?) ?? 0)} '
                            '${report['currency'] ?? ''}',
                        Icons.point_of_sale,
                        const Color(0xFFCA8A04),
                      ),
                      _detailChip(
                        'عدد الفواتير',
                        '${report['invoice_count'] ?? 0}',
                        Icons.receipt,
                        const Color(0xFF7C3AED),
                      ),
                      _detailChip(
                        'أصناف مباعة',
                        '${report['product_count'] ?? 0}',
                        Icons.shopping_basket,
                        const Color(0xFF059669),
                      ),
                      _detailChip(
                        'وقت الاستقبال',
                        report['received_at']?.toString() ?? '-',
                        Icons.schedule,
                        const Color(0xFFD97706),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailSection('المنتجات المباعة', [
                    for (final p in products)
                      '${p['name'] ?? '-'} — مباع ${_qty(p['sold_qty'])} '
                          'بسعر ${_fmt(p['sale_price'])} | الإجمالي ${_fmt(p['sold_total'])} '
                          '| المتبقي ${_qty(p['remaining_qty'])}',
                  ]),
                  const SizedBox(height: 12),
                  _detailSection('أرصدة المخزون المتبقية', [
                    for (final s in stock)
                      '${s['name'] ?? '-'} — المتبقي ${_qty(s['remaining_qty'])} '
                          '(سعر البيع ${_fmt(s['sale_price'])})',
                  ]),
                  const SizedBox(height: 12),
                  _detailSection('فواتير اليوم', [
                    for (final i in invoices)
                      '${i['invoice_no'] ?? '-'} — ${i['customer'] ?? '-'} '
                          '| ${_fmt(i['amount'])}',
                  ]),
                ],
              ),
            ),
          ),
        ),
    );
  }

  String _fmt(Object? v) {
    final n = v is num ? v : num.tryParse(v?.toString() ?? '');
    return n == null ? '-' : _num.format(n);
  }

  String _qty(Object? v) {
    final n = v is num ? v : num.tryParse(v?.toString() ?? '');
    return n == null ? '-' : n.toStringAsFixed(0);
  }

  String _short(String s) => s.length >= 16 ? s.substring(0, 16) : s;

  Widget _detailChip(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: lines.isEmpty
              ? const Text('لا بيانات', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    for (final l in lines)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(l, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // ==================== الواجهة ====================
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'تقارير الأنظمة (الربط المركزي)',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                            ),
                            onPressed: _syncing ? null : _syncAll,
                            icon: const Icon(
                              Icons.sync,
                              color: Colors.white,
                            ),
                            label: Text(
                              _syncing ? 'جارٍ الاستقبال...' : 'مزامنة الآن (استقبال تلقائي)',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _importing ? null : _importReport,
                            icon: const Icon(Icons.file_download_outlined),
                            label: Text(
                              _importing ? 'جارٍ الاستيراد...' : 'استيراد ملف احتياطي',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 16,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'استقبال تلقائي مباشر: عند إرسال أي نظام يصل تقريره هنا فوراً. '
                          'التقارير تُقرأ مباشرة من قاعدة البيانات المنعزلة لكل نظام.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSystemSummary(),
                  const SizedBox(height: 20),
                  for (final mode in SystemConfig.allSystemModes)
                    _buildSystemSection(mode),
                  const SizedBox(height: 20),
                  _buildAuditSection(),
                ],
              ),
            ),
    );
  }

  // ==================== بطاقات ملخص الأنظمة الأربعة ====================
  Widget _buildSystemSummary() {
    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        for (final mode in SystemConfig.allSystemModes)
          _systemCard(mode),
      ],
    );
  }

  Widget _systemCard(String mode) {
    final code = SystemConfig.branchCodeOf(mode);
    final name = SystemConfig.branchNameOf(mode);
    final isAdmin = mode == SystemConfig.adminMode;
    final reports = _reportsOf(code);
    double latestTotal = 0;
    if (reports.isNotEmpty) {
      latestTotal = (reports.first['total_amount'] as num?)?.toDouble() ?? 0;
    }
    final color = isAdmin
        ? const Color(0xFF0F172A)
        : const Color(0xFFCA8A04);
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(
          color: reports.isEmpty ? const Color(0xFFCBD5E1) : color,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.storefront,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Text(
            reports.isEmpty
                ? 'بانتظار التقرير...'
                : 'آخر تقرير: ${_num.format(latestTotal)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: reports.isEmpty ? Colors.orange.shade800 : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${reports.length} تقرير مستلم',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  List<Map<String, Object?>> _reportsOf(String code) => [
    for (final r in _reports)
      if ((r['branch_code']?.toString() ?? '') == code) r,
  ];

  List<Map<String, Object?>> _attendanceOf(String code) => [
    for (final a in _attendanceReports)
      if ((a['branch_code']?.toString() ?? '') == code) a,
  ];

  // ==================== قسم خاص لكل نظام ====================
  Widget _buildSystemSection(String mode) {
    final code = SystemConfig.branchCodeOf(mode);
    final name = SystemConfig.branchNameOf(mode);
    final isAdmin = mode == SystemConfig.adminMode;
    final reports = _reportsOf(code);
    final attendance = _attendanceOf(code);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAdmin ? const Color(0xFF0F172A) : const Color(0xFF2563EB))
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isAdmin ? Icons.admin_panel_settings : Icons.storefront,
                  color: isAdmin ? const Color(0xFF0F172A) : const Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdmin ? '$name (النظام الرئيسي)' : name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'الكود: $code — تقارير نهاية اليوم: ${reports.length} | تقارير الحضور: ${attendance.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا تقارير مستلمة من هذا النظام بعد',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            _reportsTable(reports, isAdmin),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          Text(
            'تقارير الحضور والغياب (من نظام $name)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (attendance.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لا تقارير حضور مستلمة بعد',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else
            _attendanceTable(attendance),
        ],
      ),
    );
  }

  Widget _reportsTable(List<Map<String, Object?>> reports, bool isAdmin) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('الإجمالي')),
          DataColumn(label: Text('الفواتير')),
          DataColumn(label: Text('الأصناف')),
          DataColumn(label: Text('وقت الاستقبال')),
          DataColumn(label: Text('إجراءات')),
        ],
        rows: [
          for (final r in reports)
            DataRow(
              cells: [
                DataCell(Text(r['report_date']?.toString() ?? '-')),
                DataCell(
                  Text(
                    '${_num.format((r['total_amount'] as num?) ?? 0)} '
                    '${r['currency'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text('${r['invoice_count'] ?? 0}')),
                DataCell(Text('${r['product_count'] ?? 0}')),
                DataCell(
                  Text(
                    _short(r['received_at']?.toString() ?? ''),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showDetail(r),
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: Colors.blueGrey,
                        ),
                        tooltip: 'عرض التقرير',
                      ),
                      if (isAdmin) ...[
                        IconButton(
                          onPressed: () => _confirmDelete(r),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          tooltip: 'حذف',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _attendanceTable(List<Map<String, Object?>> attendance) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('حاضر')),
          DataColumn(label: Text('غائب')),
          DataColumn(label: Text('إجازة')),
          DataColumn(label: Text('تأخير')),
          DataColumn(label: Text('وقت الاستقبال')),
          DataColumn(label: Text('إجراءات')),
        ],
        rows: [
          for (final a in attendance)
            DataRow(
              cells: [
                DataCell(Text(a['report_date']?.toString() ?? '-')),
                DataCell(
                  Text(
                    '${a['present'] ?? 0}',
                    style: const TextStyle(color: Color(0xFF16A34A)),
                  ),
                ),
                DataCell(
                  Text(
                    '${a['absent'] ?? 0}',
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
                DataCell(Text('${a['leave'] ?? 0}')),
                DataCell(Text('${a['late'] ?? 0}')),
                DataCell(
                  Text(
                    _short(a['received_at']?.toString() ?? ''),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                DataCell(
                  IconButton(
                    onPressed: () => _showAttendanceDetail(a),
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.blueGrey,
                    ),
                    tooltip: 'عرض تفاصيل الحضور',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showAttendanceDetail(Map<String, Object?> report) {
    List<Map<String, dynamic>> decode(Object? raw) {
      try {
        final d = jsonDecode(raw?.toString() ?? '[]');
        if (d is! List) return [];
        return [for (final e in d) e as Map<String, dynamic>];
      } catch (_) {
        return [];
      }
    }

    final employees = decode(report['employees']);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${report['branch_name']} — حضور ${report['report_date']}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                const Divider(),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _detailChip(
                      'حاضر',
                      '${report['present'] ?? 0}',
                      Icons.check_circle,
                      const Color(0xFF16A34A),
                    ),
                    _detailChip(
                      'غائب',
                      '${report['absent'] ?? 0}',
                      Icons.cancel,
                      const Color(0xFFDC2626),
                    ),
                    _detailChip(
                      'إجازة',
                      '${report['leave'] ?? 0}',
                      Icons.beach_access,
                      const Color(0xFFD97706),
                    ),
                    _detailChip(
                      'متأخر',
                      '${report['late'] ?? 0}',
                      Icons.schedule,
                      const Color(0xFF2563EB),
                    ),
                    _detailChip(
                      'إجمالي الموظفين',
                      '${report['total_employees'] ?? 0}',
                      Icons.people,
                      const Color(0xFF0F172A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'تفاصيل الموظفين',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: employees.isEmpty
                      ? const Text('لا بيانات', style: TextStyle(color: Colors.grey))
                      : Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            for (final e in employees)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
child: Text(
                                  '${e['name'] ?? '-'} — ${e['status_label'] ?? e['status'] ?? '-'}'
                                  '${(e['note']?.toString() ?? '').isEmpty ? '' : ' (${e['note']})'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== سجل العمليات (Audit) ====================
  Widget _buildAuditSection() {
    final needle = _auditFilter.toLowerCase();
    final filtered = [
      for (final a in _audits)
        if (needle.isEmpty ||
            ('${a['system_name']} ${a['action_label']} '
                    '${a['details']} ${a['actor']}')
                .toLowerCase()
                .contains(needle))
          a,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سجل العمليات (Audit Log)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'كل عملية تُنفَّذ في أي نظام تصل هنا فوراً — دخول، إنشاء/حذف فرع، تقارير.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _filterController,
                  onChanged: (v) => setState(() => _auditFilter = v),
                  decoration: InputDecoration(
                    hintText: 'بحث في السجل...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  _audits.isEmpty
                      ? 'لا توجد عمليات مسجلة بعد — ستظهر هنا كل عملية تلقائياً'
                      : 'لا نتائج مطابقة للبحث',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('الوقت')),
                  DataColumn(label: Text('النظام')),
                  DataColumn(label: Text('العملية')),
                  DataColumn(label: Text('التفاصيل')),
                  DataColumn(label: Text('بواسطة')),
                ],
                rows: [
                  for (final a in filtered)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _fmtTime(a['time']),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${a['system_name'] ?? '-'}'
                            '${(a['branch_code']?.toString() ?? '').isEmpty ? '' : ' (${a['branch_code']})'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _auditIcon(a['action']?.toString()),
                                size: 16,
                                color: _auditColor(a['action']?.toString()),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                a['action_label']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 340,
                            child: Text(
                              a['details']?.toString() ?? '-',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${a['actor'] ?? '-'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmtTime(Object? t) {
    final raw = t?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return _timeFmt.format(dt.toLocal());
  }

  IconData _auditIcon(String? action) => switch (action) {
        AuditAction.login => Icons.login,
        AuditAction.createBranch => Icons.add_business_outlined,
        AuditAction.deleteBranch => Icons.storefront,
        AuditAction.eodSent => Icons.post_add,
        AuditAction.attendanceSent => Icons.fact_check_outlined,
        AuditAction.importReport => Icons.file_download_outlined,
        AuditAction.deleteReport => Icons.delete_outline,
        _ => Icons.info_outline,
      };

  Color _auditColor(String? action) => switch (action) {
        AuditAction.login => const Color(0xFF2563EB),
        AuditAction.createBranch => const Color(0xFF16A34A),
        AuditAction.deleteBranch => const Color(0xFFDC2626),
        AuditAction.eodSent => const Color(0xFFCA8A04),
        AuditAction.attendanceSent => const Color(0xFF0D9488),
        AuditAction.importReport => const Color(0xFF7C3AED),
        AuditAction.deleteReport => const Color(0xFFDC2626),
        _ => const Color(0xFF64748B),
      };
}