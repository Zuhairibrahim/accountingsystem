import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/ads/ad_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/database/db_filter.dart';
import '../../core/utils/audit_log_service.dart';
import '../../core/utils/cross_tab.dart';
import '../../core/utils/file_transfer.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/system_sync.dart';
import '../../systems/system_config.dart';

/// صف مُجمّع لمنتج مباع اليوم
class _SoldLine {
  final String name;
  final String? barcode;
  final double salePrice;
  double soldQty = 0;
  double soldTotal = 0;
  final double? remainingQty;

  _SoldLine({
    required this.name,
    required this.barcode,
    required this.salePrice,
    required this.remainingQty,
  });
}

/// ترحيل نهاية اليوم: تقرير كامل (الإجمالي + المنتجات + الكميات المتبقية)
/// يُصدَّر كملف JSON ويُرسل إلى النظام الرئيسي (التحكم).
class EodReportPage extends StatefulWidget {
  const EodReportPage({super.key});

  @override
  State<EodReportPage> createState() => _EodReportPageState();
}

class _EodReportPageState extends State<EodReportPage> {
  final DatabaseService _svc = DatabaseService.instance;
  bool _loading = true;
  bool _saving = false;

  String _today = '';
  String _branchCode = '';
  String _branchName = '';
  String _companyName = '';
  final String _currency = AppConstants.defaultCurrency;
  int _branchId = 0;

  List<Map<String, Object?>> _todaySales = [];
  List<Map<String, Object?>> _products = [];
  List<_SoldLine> _soldLines = [];

  static final NumberFormat _num = NumberFormat('#,##0.00');

  double get _totalAmount => Formatters.round(_todaySales.fold<double>(
    0,
    (s, x) => s + (x['amount'] as num? ?? 0).toDouble(),
  ));

  int get _soldProductCount => _soldLines.length;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now().toString().substring(0, 10);
    _load();
  }

  Future<void> _load() async {
    final settings = await _svc.getAll(AppConstants.tSettings);
    String setting(String key, String fallback) {
      for (final s in settings) {
        if (s['key'] == key) return s['value']?.toString() ?? fallback;
      }
      return fallback;
    }

    _branchCode = setting(AppConstants.settingBranchCode, SystemConfig.instance.branchCode);
    _branchName = setting(AppConstants.settingBranchName, SystemConfig.instance.branchName);
    _companyName = setting(AppConstants.settingCompanyName, 'شركتي');

    final branches = await _svc.getAll(AppConstants.tBranches);
    for (final b in branches) {
      if (b['is_default'] == true || b['code'] == _branchCode) {
        _branchId = (b['id'] as num?)?.toInt() ?? 0;
        if (b['name'] != null) _branchName = b['name'].toString();
        break;
      }
    }
    if (_branchId == 0 && branches.isNotEmpty) {
      _branchId = (branches.first['id'] as num?)?.toInt() ?? 0;
    }

    final sales = await _svc.getAll(AppConstants.tSales);
    final products = await _svc.getAll(AppConstants.tProducts);

    final today = <Map<String, Object?>>[];
    for (final s in sales) {
      if ((s['date']?.toString() ?? '') == _today) today.add(s);
    }

    // تجميع المنتجات المباعة اليوم
    final lines = <String, _SoldLine>{};
    for (final sale in today) {
      final raw = sale['items']?.toString();
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        for (final item in decoded) {
          final map = item as Map<String, dynamic>;
          final name = map['name']?.toString() ?? 'منتج';
          final qty = (map['qty'] as num? ?? 1).toDouble();
          final price = (map['price'] as num? ?? 0).toDouble();
          final total = (map['total'] as num? ?? (price * qty)).toDouble();

          double? remaining;
          String? barcode;
          double? saleP;
          for (final p in products) {
            if (p['name']?.toString() == name) {
              barcode = p['barcode']?.toString();
              saleP = (p['sale_price'] as num?)?.toDouble();
              remaining = (p['stock_qty'] as num?)?.toDouble();
              break;
            }
          }

          final line = lines.putIfAbsent(
            name,
            () => _SoldLine(
              name: name,
              barcode: barcode,
              salePrice: saleP ?? price,
              remainingQty: remaining,
            ),
          );
          line.soldQty = Formatters.round(line.soldQty + qty, 3);
          line.soldTotal = Formatters.round(line.soldTotal + total);
        }
      } catch (_) {
        // نتجاهل البنود غير الصالحة
      }
    }

    if (!mounted) return;
    setState(() {
      _todaySales = today;
      _products = products;
      _soldLines = lines.values.toList()
        ..sort((a, b) => b.soldTotal.compareTo(a.soldTotal));
      _loading = false;
    });
  }

  // ==================== بناء التقرير ====================
  Map<String, Object?> _buildReportJson() {
    return {
      'format': 'branch_end_of_day_report',
      'version': 1,
      'system_id': SystemConfig.instance.systemId,
      'branch_code': _branchCode,
      'branch_name': _branchName,
      'company_name': _companyName,
      'report_date': _today,
      'generated_at': DateTime.now().toIso8601String(),
      'currency': _currency,
      'summary': {
        'total_amount': _totalAmount,
        'invoice_count': _todaySales.length,
        'product_count': _soldProductCount,
      },
      'products': [
        for (final l in _soldLines)
          {
            'name': l.name,
            'barcode': l.barcode,
            'sold_qty': l.soldQty,
            'sale_price': l.salePrice,
            'sold_total': l.soldTotal,
            'remaining_qty': l.remainingQty,
          },
      ],
      'stock': [
        for (final p in _products)
          {
            'name': p['name']?.toString() ?? '-',
            'barcode': p['barcode']?.toString(),
            'sale_price': (p['sale_price'] as num?) ?? 0,
            'remaining_qty': (p['stock_qty'] as num?) ?? 0,
          },
      ],
      'invoices': [
        for (final s in _todaySales)
          {
            'invoice_no': s['invoice_no']?.toString() ?? '-',
            'customer': s['customer']?.toString() ?? '-',
            'amount': (s['amount'] as num?) ?? 0,
            'item_count': _itemCountOf(s),
          },
      ],
    };
  }

  int _itemCountOf(Map<String, Object?> sale) {
    final raw = sale['items']?.toString();
    if (raw == null || raw.isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return 0;
      return decoded.fold<int>(
        0,
        (sum, item) =>
            sum + ((item as Map<String, dynamic>)['qty'] as num? ?? 1).toInt(),
      );
    } catch (_) {
      return 0;
    }
  }

  // ==================== إرسال التقرير (وصول تلقائي للنظام الأساسي) ====================
  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_todaySales.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد أي بيانات اليوم لإرسالها — من الضروري إدخال '
            'التقارير والمعاملات أولاً ثم إعادة الإرسال',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final data = _buildReportJson();
    // 1) حفظ في قاعدة بيانات هذا النظام
    await _storeLocal();
    // 2) إشعار فوري للنظام الأساسي المفتوح (لتحديث فوري)
    notifyReportSent({
      'branch_code': _branchCode,
      'branch_name': _branchName,
      'report_date': _today,
      'system_id': SystemConfig.instance.systemId,
    });
    // 3) تسليم مباشر لصندوق البريد المحلي (يصل للنظام الأساسي فوراً حتى عبر المنافذ)
    final pushed = await pushReport(data);
    // 4) نسخة احتياطية قابلة للتنزيل أيضاً
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final filename = 'تقرير-($_branchCode)-$_today.json'.replaceAll('/', '-');
    downloadTextFile(filename, json);
    // تسجيل عملية إرسال التقرير في سجل العمليات (يصل للأدمن فوراً)
    AuditLogService.record(
      AuditAction.eodSent,
      details: 'إرسال تقرير نهاية اليوم $_branchName — $_today',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(pushed
            ? 'تم إرسال تقرير $_branchName ($_today) — وصل إلى النظام الأساسي تلقائياً'
            : 'تم إنشاء التقرير — أرسله يدوياً عبر «استيراد ملف احتياطي» إن لم يتلقَّ النظام الأساسي'),
        backgroundColor: pushed ? Colors.green.shade700 : Colors.orange.shade800,
      ),
    );
    // عرض إعلان بيني عند إتمام ترحيل التقرير
    AdService.instance.tryShowInterstitial(source: 'eod_export');
  }

  Future<void> _storeLocal() async {
    final data = _buildReportJson();
    final summary = data['summary'] as Map<String, Object?>;
    final existing = await _svc.find(
      AppConstants.tBranchReports,
      filter: DbFilter.and([
        DbFilter.equals('branch_code', data['branch_code']),
        DbFilter.equals('report_date', data['report_date']),
      ]),
    );
    final record = {
      'branch_code': data['branch_code'],
      'branch_name': data['branch_name'],
      'system_id': data['system_id'],
      'report_date': data['report_date'],
      'generated_at': data['generated_at'],
      'total_amount': summary['total_amount'],
      'invoice_count': summary['invoice_count'],
      'product_count': summary['product_count'],
      'currency': data['currency'],
      'products': jsonEncode(data['products']),
      'stock': jsonEncode(data['stock']),
      'invoices': jsonEncode(data['invoices']),
      'received_at': DateTime.now().toIso8601String(),
    };
    if (existing.isNotEmpty) {
      await _svc.update(
        AppConstants.tBranchReports,
        (existing.first['id'] as num).toInt(),
        record,
      );
    } else {
      await _svc.insert(AppConstants.tBranchReports, record);
    }
    await _load();
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
                        'ترحيل نهاية اليوم',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildExportButton(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildIdentityCard(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 20),
                  _buildSoldTable(),
                  const SizedBox(height: 16),
                  _buildStockTable(),
                  const SizedBox(height: 16),
                  _buildInvoicesTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildIdentityCard() {
    final cfg = SystemConfig.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(
            cfg.isAdmin ? Icons.admin_panel_settings : Icons.storefront,
            color: const Color(0xFF0F172A),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_branchName ($_branchCode)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_companyName — ${cfg.systemLabel}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  'التاريخ: $_today  |  العملة: $_currency',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Chip(
            avatar: const Icon(Icons.send, size: 16, color: Colors.white),
            label: const Text(
              'يُرسل إلى النظام الرئيسي',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
            backgroundColor: const Color(0xFF0F172A),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        _chip(
          'إجمالي مبيعات اليوم',
          '${_num.format(_totalAmount)} $_currency',
          Icons.point_of_sale,
          const Color(0xFF2563EB),
        ),
        _chip(
          'عدد الفواتير',
          '${_todaySales.length}',
          Icons.receipt,
          const Color(0xFF7C3AED),
        ),
        _chip(
          'أصناف مباعة',
          '$_soldProductCount',
          Icons.shopping_basket,
          const Color(0xFF059669),
        ),
        _chip(
          'عدد الأصناف في المخزون',
          '${_products.length}',
          Icons.warehouse,
          const Color(0xFFD97706),
        ),
      ],
    );
  }

  Widget _chip(String title, String value, IconData icon, Color color) {
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
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      onPressed: _saving ? null : _export,
      icon: const Icon(Icons.send, color: Colors.white),
      label: Text(
        _saving ? 'جارٍ الترحيل...' : 'إرسال التقرير الآن (يصل تلقائياً)',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildTableCard(String title, Widget child) {
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
          child,
        ],
      ),
    );
  }

  Widget _buildSoldTable() {
    return _buildTableCard(
      'المنتجات المباعة اليوم (مع الكميات المتبقية)',
      _soldLines.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'لا مبيعات اليوم بعد — التقرير سيكون بأرصدة المخزون فقط',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : _dataTable(
              headers: const [
                'المنتج',
                'الباركود',
                'الكمية المباعة',
                'سعر البيع',
                'إجمالي البيع',
                'الكمية المتبقية',
              ],
              rows: [
                for (final l in _soldLines)
                  [
                    l.name,
                    l.barcode ?? '-',
                    l.soldQty.toStringAsFixed(0),
                    _num.format(l.salePrice),
                    _num.format(l.soldTotal),
                    (l.remainingQty?.toStringAsFixed(0) ?? '-'),
                  ],
              ],
            ),
    );
  }

  Widget _buildStockTable() {
    return _buildTableCard(
      'أرصدة المخزون المتبقية في نهاية اليوم (كل المنتجات)',
      _products.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey)),
            )
          : _dataTable(
              headers: const ['المنتج', 'الباركود', 'سعر البيع', 'الكمية المتبقية'],
              rows: [
                for (final p in _products)
                  [
                    p['name']?.toString() ?? '-',
                    p['barcode']?.toString() ?? '-',
                    '${(p['sale_price'] as num?) ?? 0}',
                    '${(p['stock_qty'] as num?) ?? 0}',
                  ],
              ],
            ),
    );
  }

  Widget _buildInvoicesTable() {
    return _buildTableCard(
      'فواتير اليوم',
      _todaySales.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا فواتير اليوم', style: TextStyle(color: Colors.grey)),
            )
          : _dataTable(
              headers: const ['رقم الفاتورة', 'العميل', 'عدد القطع', 'المبلغ'],
              rows: [
                for (final s in _todaySales)
                  [
                    s['invoice_no']?.toString() ?? '-',
                    s['customer']?.toString() ?? '-',
                    '${_itemCountOf(s)}',
                    _num.format((s['amount'] as num?) ?? 0),
                  ],
              ],
            ),
    );
  }

  Widget _dataTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: [for (final h in headers) DataColumn(label: Text(h))],
        rows: [
          for (final row in rows)
            DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
        ],
      ),
    );
  }
}