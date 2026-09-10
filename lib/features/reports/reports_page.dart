import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';

/// صفحة التقارير — ملخصات مباشرة من قاعدة البيانات
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseService _svc = DatabaseService.instance;
  Map<String, dynamic> _metrics = {};
  List<Map<String, Object?>> _sales = [];
  List<Map<String, Object?>> _purchases = [];
  bool _loading = true;

  static final NumberFormat _num = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final metrics = await _svc.getDashboardMetrics();
    final sales = await _svc.getAll(AppConstants.tSales);
    final purchases = await _svc.getAll(AppConstants.tPurchases);
    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _sales = sales;
      _purchases = purchases;
      _loading = false;
    });
  }

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
                  const Text(
                    'التقارير',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    children: [
                      _card(
                        'إجمالي المبيعات',
                        '${_num.format(_metrics['total_sales'] ?? 0)} ريال',
                        Icons.point_of_sale,
                        Colors.indigo,
                      ),
                      _card(
                        'إجمالي المشتريات',
                        '${_num.format(_metrics['total_purchases'] ?? 0)} ريال',
                        Icons.shopping_bag,
                        Colors.blue,
                      ),
                      _card(
                        'صافي الربح',
                        '${_num.format(_metrics['net_profit'] ?? 0)} ريال',
                        Icons.trending_up,
                        Colors.red,
                      ),
                      _card(
                        'عدد فواتير المبيعات',
                        '${_sales.length}',
                        Icons.receipt,
                        Colors.green,
                      ),
                      _card(
                        'عدد فواتير المشتريات',
                        '${_purchases.length}',
                        Icons.receipt_long,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _tableSection('أحدث فواتير المبيعات', _salesTable()),
                  const SizedBox(height: 16),
                  _tableSection('أحدث فواتير المشتريات', _purchasesTable()),
                ],
              ),
            ),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _tableSection(String title, Widget table) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 8),
          table,
        ],
      ),
    );
  }

  Widget _salesTable() {
    return _simpleTable(
      headers: const ['رقم الفاتورة', 'التاريخ', 'العميل', 'المبلغ', 'الحالة'],
      rows: _sales
          .map(
            (s) => [
              s['invoice_no']?.toString() ?? '-',
              s['date']?.toString() ?? '-',
              s['customer']?.toString() ?? '-',
              _fmtNum(s['amount']),
              s['status']?.toString() ?? '-',
            ],
          )
          .toList(),
    );
  }

  Widget _purchasesTable() {
    return _simpleTable(
      headers: const ['رقم الفاتورة', 'التاريخ', 'المورد', 'المبلغ', 'الحالة'],
      rows: _purchases
          .map(
            (p) => [
              p['invoice_no']?.toString() ?? '-',
              p['date']?.toString() ?? '-',
              p['supplier']?.toString() ?? '-',
              _fmtNum(p['amount']),
              p['status']?.toString() ?? '-',
            ],
          )
          .toList(),
    );
  }

  String _fmtNum(Object? v) {
    final n = v is num ? v : num.tryParse(v?.toString() ?? '');
    return n == null ? '-' : _num.format(n);
  }

  Widget _simpleTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('لا توجد بيانات بعد', style: TextStyle(color: Colors.grey)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [for (final h in headers) DataColumn(label: Text(h))],
        rows: [
          for (final row in rows)
            DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
        ],
      ),
    );
  }
}
