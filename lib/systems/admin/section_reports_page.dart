import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/audit_log_service.dart';
import '../../core/utils/section_report_sync.dart';
import '../../features/reports/full_report_dialog.dart';

/// قسم استقبال تقارير الموظفين والمنتجات من الفروع + سجل العمليات الحي
/// (بما فيه أخطاء وقت التشغيل) — النظام الأساسي فقط.
///
/// أي نظام (فرع أو أدمن) يضغط «إرسال التقرير للأدمن» يصل تقريره هنا
/// فوراً عبر السحابة (`accounting_section_reports` + onSnapshot بث مباشر)
/// مع عرض كامل التفاصيل وإعادة الطباعة والحذف.
class SectionReportsPage extends StatefulWidget {
  const SectionReportsPage({super.key});

  @override
  State<SectionReportsPage> createState() => _SectionReportsPageState();
}

class _SectionReportsPageState extends State<SectionReportsPage> {
  List<Map<String, Object?>> _reports = [];
  List<Map<String, Object?>> _audits = [];
  bool _loading = true;
  String _filter = 'all';
  StreamSubscription<List<Map<String, Object?>>>? _sub;
  StreamSubscription<List<Map<String, Object?>>>? _auditSub;
  final _auditFilterController = TextEditingController();
  String _auditFilter = '';

  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    // استقبال حي فوري: أي تقرير يُرسل من أي فرع يصل هنا مباشرة
    _sub = sectionWatchReports().listen((list) {
      if (mounted) {
        setState(() {
          _reports = list;
          _loading = false;
        });
      }
    });
    // سجل العمليات الحي: كل عملية في أي نظام (+ أخطاء التشغيل) تصل فوراً
    _auditSub = AuditLogService.watchAuditLogs().listen((list) {
      if (mounted) setState(() => _audits = list);
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _auditSub?.cancel();
    _auditFilterController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await sectionFetchReports();
    if (!mounted) return;
    setState(() {
      _reports = list;
      _loading = false;
    });
  }

  List<Map<String, Object?>> get _filtered => switch (_filter) {
        'products' => [
            for (final r in _reports) if (r['type'] == 'products') r,
          ],
        'employees' => [
            for (final r in _reports) if (r['type'] == 'employees') r,
          ],
        'salaries' => [
            for (final r in _reports) if (r['type'] == 'salaries') r,
          ],
        'stock' => [
            for (final r in _reports) if (r['type'] == 'stock') r,
          ],
        'purchases' => [
            for (final r in _reports) if (r['type'] == 'purchases') r,
          ],
        'expenses' => [
            for (final r in _reports) if (r['type'] == 'expenses') r,
          ],
        'cash_accounts' => [
            for (final r in _reports) if (r['type'] == 'cash_accounts') r,
          ],
        'bank_accounts' => [
            for (final r in _reports) if (r['type'] == 'bank_accounts') r,
          ],
        'attendance' => [
            for (final r in _reports) if (r['type'] == 'attendance') r,
          ],
        'summary' => [
            for (final r in _reports) if (r['type'] == 'summary') r,
          ],
        _ => _reports,
      };

  int _countOf(String type) => [
        for (final r in _reports)
          if (type == 'all' || r['type'] == type) r,
      ].length;

  Future<void> _view(Map<String, Object?> r) async {
    List<Map<String, Object?>> stats;
    List<ReportColumn> columns;
    List<List<String>> rows;
    List<String>? totals;
    try {
      stats = [
        for (final s in (r['stats'] as List? ?? []))
          {
            'label': (s as Map)['label']?.toString() ?? '',
            'value': s['value']?.toString() ?? '',
          },
      ];
      columns = [
        for (final c in (r['columns'] as List? ?? []))
          ReportColumn(c.toString()),
      ];
      rows = [
        for (final row in (r['rows'] as List? ?? []))
          [for (final cell in (row as List)) cell.toString()],
      ];
      final rawTotals = r['totals'] as List?;
      totals = rawTotals == null || rawTotals.isEmpty
          ? null
          : [for (final t in rawTotals) t.toString()];
    } catch (_) {
      return;
    }
    if (!mounted) return;
    await showFullReportDialog(
      context: context,
      title: r['title']?.toString() ?? 'تقرير',
      subtitle:
          '${r['branch_name'] ?? '-'} (${r['branch_code'] ?? '-'}) — '
          'وصل: ${_fmtTime(r['received_at'])}',
      stats: [
        for (final s in stats)
          ReportStat(
            s['label']!.toString(),
            s['value']!.toString(),
            const Color(0xFF2563EB),
          ),
      ],
      columns: columns,
      rows: rows,
      totalsRow: totals,
      showSendButton: false,
    );
  }

  Future<void> _confirmDelete(Map<String, Object?> r) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'حذف تقرير «${r['title']}» من ${r['branch_name']}؟',
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
    await sectionDeleteReport(r['id']?.toString() ?? '');
    await _load();
    AuditLogService.record(
      AuditAction.deleteReport,
      details: 'حذف ${r['type_label']} «${r['title']}» من ${r['branch_name']}',
      actor: 'مدير النظام',
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('تم حذف التقرير')),
    );
  }

  String _fmtTime(Object? t) {
    final raw = t?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    return dt == null ? raw : _timeFmt.format(dt.toLocal());
  }

  IconData _typeIcon(String? type) => switch (type) {
        'products' => Icons.inventory_2_outlined,
        'employees' => Icons.people_outline,
        'salaries' => Icons.payments_outlined,
        'stock' => Icons.warehouse_outlined,
        'purchases' => Icons.shopping_cart_outlined,
        'expenses' => Icons.money_off_outlined,
        'cash_accounts' => Icons.account_balance_wallet_outlined,
        'bank_accounts' => Icons.account_balance_outlined,
        'attendance' => Icons.event_available_outlined,
        'summary' => Icons.assessment_outlined,
        _ => Icons.summarize_outlined,
      };

  Color _typeColor(String? type) => switch (type) {
        'products' => const Color(0xFF2563EB),
        'employees' => const Color(0xFF7C3AED),
        'salaries' => const Color(0xFFD97706),
        'stock' => const Color(0xFF059669),
        'purchases' => const Color(0xFF0EA5E9),
        'expenses' => const Color(0xFFDC2626),
        'cash_accounts' => const Color(0xFF16A34A),
        'bank_accounts' => const Color(0xFF6366F1),
        'attendance' => const Color(0xFFCA8A04),
        'summary' => const Color(0xFF0F172A),
        _ => const Color(0xFF0F172A),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'استقبال تقارير الفروع',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _filterChip('all', 'الكل', _countOf('all')),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('products', 'المنتجات', _countOf('products')),
                    _filterChip('employees', 'الموظفين', _countOf('employees')),
                    _filterChip('salaries', 'الرواتب', _countOf('salaries')),
                    _filterChip('stock', 'المخزون', _countOf('stock')),
                    _filterChip(
                      'purchases',
                      'المشتريات',
                      _countOf('purchases'),
                    ),
                    _filterChip(
                      'expenses',
                      'المصروفات',
                      _countOf('expenses'),
                    ),
                    _filterChip(
                      'cash_accounts',
                      'الصناديق',
                      _countOf('cash_accounts'),
                    ),
                    _filterChip(
                      'bank_accounts',
                      'البنوك',
                      _countOf('bank_accounts'),
                    ),
                    _filterChip(
                      'attendance',
                      'الحضور',
                      _countOf('attendance'),
                    ),
                    _filterChip(
                      'summary',
                      'المالي الشامل',
                      _countOf('summary'),
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
                        'استقبال حي فوري: عند ضغط أي فرع «إرسال التقرير للأدمن» '
                        'يصل التقرير هنا مباشرة عبر السحابة — اضغط «عرض» للاطلاع '
                        'على التفاصيل كاملة أو طباعتها.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 44,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 10),
                                const Text('لا توجد تقارير مستلمة بعد'),
                                const SizedBox(height: 6),
                                Text(
                                  'أرسل تقريراً من أي فرع (منتجات/موظفين) وسيظهر هنا فوراً',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(8),
                              child: DataTable(
                                headingRowHeight: 46,
                                showCheckboxColumn: false,
                                columns: const [
                                  DataColumn(label: Text('النوع')),
                                  DataColumn(label: Text('الفرع')),
                                  DataColumn(label: Text('كود الفرع')),
                                  DataColumn(label: Text('التاريخ')),
                                  DataColumn(label: Text('عدد السجلات')),
                                  DataColumn(label: Text('وقت الاستقبال')),
                                  DataColumn(label: Text('إجراءات')),
                                ],
                                rows: [
                                  for (final r in _filtered)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _typeIcon(
                                                  r['type']?.toString(),
                                                ),
                                                size: 16,
                                                color: _typeColor(
                                                  r['type']?.toString(),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                r['type_label']?.toString() ??
                                                    '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            r['branch_name']?.toString() ??
                                                '-',
                                          ),
                                        ),
                                        DataCell(
                                          Text(r['branch_code']?.toString() ?? '-'),
                                        ),
                                        DataCell(
                                          Text(
                                            r['report_date']?.toString() ?? '-',
                                          ),
                                        ),
                                        DataCell(
                                          Text('${r['rows_count'] ?? 0}'),
                                        ),
                                        DataCell(
                                          Text(
                                            _fmtTime(r['received_at']),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: () => _view(r),
                                                icon: const Icon(
                                                  Icons
                                                      .visibility_outlined,
                                                  size: 18,
                                                  color: Colors.blueGrey,
                                                ),
                                                tooltip: 'عرض التقرير كاملاً',
                                              ),
                                              IconButton(
                                                onPressed: () =>
                                                    _confirmDelete(r),
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
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildAuditSection(),
              ],
            ),
    );
  }

  // ==================== سجل العمليات الحي (Audit + أخطاء التشغيل) ====================
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
                      'سجل العمليات وأخطاء التشغيل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'كل عملية في أي نظام + أي خطأ وقت تشغيل تصل هنا فوراً عبر السحابة.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _auditFilterController,
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
            SizedBox(
              height: 320,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
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
              ),
            ),
        ],
      ),
    );
  }

  IconData _auditIcon(String? action) => switch (action) {
        AuditAction.login => Icons.login,
        AuditAction.createBranch => Icons.add_business_outlined,
        AuditAction.deleteBranch => Icons.storefront,
        AuditAction.eodSent => Icons.post_add,
        AuditAction.attendanceSent => Icons.fact_check_outlined,
        AuditAction.importReport => Icons.file_download_outlined,
        AuditAction.deleteReport => Icons.delete_outline,
        AuditAction.runtimeError => Icons.bug_report_outlined,
        AuditAction.changeCredentials => Icons.key,
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
        AuditAction.runtimeError => const Color(0xFFDC2626),
        AuditAction.changeCredentials => const Color(0xFFB45309),
        _ => const Color(0xFF64748B),
      };

  Widget _filterChip(String key, String label, int count) {
    final selected = _filter == key;
    return ChoiceChip(
      selected: selected,
      label: Text('$label ($count)'),
      onSelected: (_) => setState(() => _filter = key),
      selectedColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0F172A),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
