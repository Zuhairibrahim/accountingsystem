import 'package:flutter/material.dart';

import '../../core/utils/report_printer.dart';
import '../../core/utils/section_report_sync.dart';
import '../../systems/system_config.dart';

/// إحصائية تظهر كبطاقة أعلى التقرير
class ReportStat {
  final String label;
  final String value;
  final Color color;

  const ReportStat(this.label, this.value, this.color);
}

/// عمود في جدول التقرير
class ReportColumn {
  final String label;

  const ReportColumn(this.label);
}

/// نافذة تقرير شامل موحدة: بطاقات إحصائية + جدول كامل + صف إجماليات
/// + زر طباعة احترافي + زر إرسال التقرير إلى مدير النظام (الأدمن)
/// عبر السحابة فوراً — يعمل من أي نظام (فرع أو أدمن).
Future<void> showFullReportDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<ReportStat> stats,
  required List<ReportColumn> columns,
  required List<List<String>> rows,
  List<String>? totalsRow,
  String? reportType,
  String? reportTypeLabel,
  bool showSendButton = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _FullReportDialog(
      title: title,
      subtitle: subtitle,
      stats: stats,
      columns: columns,
      rows: rows,
      totalsRow: totalsRow,
      reportType: reportType,
      reportTypeLabel: reportTypeLabel,
      showSendButton: showSendButton,
    ),
  );
}

class _FullReportDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<ReportStat> stats;
  final List<ReportColumn> columns;
  final List<List<String>> rows;
  final List<String>? totalsRow;
  final String? reportType;
  final String? reportTypeLabel;
  final bool showSendButton;

  const _FullReportDialog({
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.columns,
    required this.rows,
    this.totalsRow,
    this.reportType,
    this.reportTypeLabel,
    this.showSendButton = true,
  });

  @override
  State<_FullReportDialog> createState() => _FullReportDialogState();
}

class _FullReportDialogState extends State<_FullReportDialog> {
  bool _sending = false;
  bool _sent = false;

  /// إرسال التقرير إلى النظام الأساسي (الأدمن) عبر السحابة فوراً —
  /// عملية واحدة سريعة غير محجوبة.
  Future<void> _sendToAdmin() async {
    if (_sending || _sent) return;
    if (widget.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات في هذا التقرير لإرساله'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final sys = SystemConfig.instance;
    final pushed = await sectionPushReport(
      type: widget.reportType ?? 'section',
      typeLabel: widget.reportTypeLabel ?? 'تقرير شامل',
      title: widget.title,
      subtitle: widget.subtitle,
      branchCode: sys.branchCode,
      branchName: sys.branchName,
      systemId: sys.systemId,
      stats: [
        for (final s in widget.stats) {'label': s.label, 'value': s.value},
      ],
      columns: [for (final c in widget.columns) c.label],
      rows: widget.rows,
      totalsRow: widget.totalsRow,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = pushed;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pushed
              ? 'تم إرسال التقرير إلى مدير النظام (admin) فوراً عبر السحابة'
              : 'تعذّر الإرسال — تحقق من الاتصال بالسحابة ثم أعد المحاولة',
        ),
        backgroundColor:
            pushed ? const Color(0xFF059669) : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 1150, maxHeight: 900),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== الرأس =====
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.summarize_outlined,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.showSendButton) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _sent
                          ? const Color(0xFF059669)
                          : const Color(0xFFB45309),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onPressed: (_sending || _sent) ? null : _sendToAdmin,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _sent ? Icons.check_circle : Icons.send_outlined,
                            size: 18,
                          ),
                    label: Text(
                      _sending
                          ? 'جارٍ الإرسال...'
                          : _sent
                              ? 'تم الإرسال لمدير النظام'
                              : 'إرسال تقرير إلى مدير النظام (admin)',
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () => printFullReport(
                    title: widget.title,
                    companyLine: widget.subtitle,
                    stats: [
                      for (final s in widget.stats)
                        (label: s.label, value: s.value),
                    ],
                    tables: [
                      ReportTable(
                        columns: [
                          for (final c in widget.columns) c.label,
                        ],
                        rows: widget.rows,
                        totalsRow: widget.totalsRow,
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('طباعة التقرير'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
            const Divider(height: 28),
            // ===== البطاقات الإحصائية =====
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in widget.stats)
                  Container(
                    width: 210,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: s.color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: s.color,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ===== الجدول =====
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: widget.rows.isEmpty
                    ? const Center(child: Text('لا توجد بيانات بعد'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(10),
                          child: DataTable(
                            headingRowHeight: 46,
                            dataRowMinHeight: 42,
                            showCheckboxColumn: false,
                            columns: [
                              for (final c in widget.columns)
                                DataColumn(
                                  label: Text(
                                    c.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (var i = 0; i < widget.rows.length; i++)
                                DataRow(
                                  color: i.isEven
                                      ? WidgetStateProperty.all(
                                          const Color(0xFFF8FAFC),
                                        )
                                      : null,
                                  cells: [
                                    for (final cell in widget.rows[i])
                                      DataCell(
                                        Text(
                                          cell,
                                          style:
                                              const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              if (widget.totalsRow != null)
                                DataRow(
                                  color: const WidgetStatePropertyAll(
                                    Color(0xFFFEF3C7),
                                  ),
                                  cells: [
                                    for (final cell in widget.totalsRow!)
                                      DataCell(
                                        Text(
                                          cell,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                          ),
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
          ],
        ),
      ),
    );
  }
}
