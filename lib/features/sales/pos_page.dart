import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/ads/ad_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/database/db_filter.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_printer.dart';
import '../../core/widgets/barcode_scan_dialog.dart';

/// بند داخل سلة فاتورة البيع
class _CartLine {
  final Map<String, Object?> product;
  double qty = 1;

  _CartLine({required this.product});

  double get price => (product['sale_price'] as num? ?? 0).toDouble();
  double get total => Formatters.round(price * qty);
}

/// نقطة البيع: مسح الباركود + سلة + كمية يدوية + إجمالي + طباعة + ملخص اليوم
class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final DatabaseService _svc = DatabaseService.instance;
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _customerCtrl = TextEditingController();
  final List<_CartLine> _cart = [];
  List<Map<String, Object?>> _todaySales = [];
  List<Map<String, Object?>> _branches = [];
  int? _branchId;

  bool _loading = true;
  String _today = '';
  double _todayTotal = 0;

  static final NumberFormat _num = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _today = DateTime.now().toString().substring(0, 10);
    _loadToday();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    final sales = await _svc.getAll(AppConstants.tSales);
    final branches = await _svc.getAll(AppConstants.tBranches);
    final today = <Map<String, Object?>>[];
    double total = 0;
    for (final s in sales) {
      final date = s['date']?.toString() ?? '';
      if (date == _today) {
        today.add(s);
        total += (s['amount'] as num? ?? 0).toDouble();
      }
    }
    if (!mounted) return;
    setState(() {
      _branches = branches;
      if (_branchId == null && branches.isNotEmpty) {
        _branchId = (branches.first['id'] as num?)?.toInt();
      }
      _todaySales = today;
      _todayTotal = Formatters.round(total);
      _loading = false;
    });
  }

  double get _cartTotal =>
      Formatters.round(_cart.fold<double>(0, (sum, l) => sum + l.total));

  String get _branchName {
    for (final b in _branches) {
      if ((b['id'] as num?)?.toInt() == _branchId) {
        return b['name']?.toString() ?? 'بدون فرع';
      }
    }
    return 'بدون فرع';
  }

  // ==================== إضافة منتج بالباركود ====================
  Future<void> _addByBarcode(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final found = await _svc.find(
      AppConstants.tProducts,
      filter: DbFilter.equals('barcode', code.trim()),
    );
    if (!context.mounted) return;
    if (found.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('المنتج غير موجود (باركود: $code)'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }
    final product = found.first;
    final stock = (product['stock_qty'] as num? ?? 0).toDouble();

    setState(() {
      final existing = _cart.where(
        (l) => l.product['barcode'] == product['barcode'],
      );
      if (existing.isNotEmpty) {
        final line = existing.first;
        if (stock <= 0 || line.qty >= stock) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('الكمية المطلوبة أكبر من المتوفر في المخزون'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        line.qty += 1;
      } else {
        if (stock <= 0) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('المنتج غير متوفر في المخزون'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _cart.add(_CartLine(product: product));
      }
    });
    _barcodeCtrl.clear();
    _barcodeCtrl.text = '';
  }

  Future<void> _openScanner() async {
    final code = await scanBarcode(context);
    if (code != null && code.isNotEmpty) {
      await _addByBarcode(code);
    }
  }

  // ==================== تعديل الكمية ====================
  void _changeQty(_CartLine line, double delta) {
    final stock = (line.product['stock_qty'] as num? ?? 0).toDouble();
    setState(() {
      final next = line.qty + delta;
      if (next < 1) return;
      if (next > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن تجاوز الكمية المتوفرة في المخزون'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      line.qty = next;
    });
  }

  void _removeLine(_CartLine line) {
    setState(() => _cart.remove(line));
  }

  // ==================== إتمام البيع والطباعة ====================
  Future<void> _checkout() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_cart.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('السلة فارغة')));
      return;
    }

    // خصم الكميات من المخزون + حساب الأرصدة المتبقية
    final remaining = <String, double>{};
    for (final line in _cart) {
      final id = (line.product['id'] as num).toInt();
      final before = (line.product['stock_qty'] as num? ?? 0).toDouble();
      final after = Formatters.round(before - line.qty, 3);
      final safeAfter = after < 0 ? 0.0 : after;
      remaining[line.product['name']?.toString() ?? 'منتج'] = safeAfter;
      await _svc.update(AppConstants.tProducts, id, {
        'stock_qty': safeAfter,
      });
    }

    // حفظ الفاتورة
    final invoiceNo = await _svc.nextSerial(
      AppConstants.tSales,
      'INV',
    );
    final items = [
      for (final l in _cart)
        {
          'name': l.product['name'],
          'price': l.price,
          'qty': l.qty,
          'total': l.total,
        },
    ];
    await _svc.insert(AppConstants.tSales, {
      'invoice_no': invoiceNo,
      'date': _today,
      'customer': _customerCtrl.text.trim().isEmpty
          ? 'عميل نقدي'
          : _customerCtrl.text.trim(),
      'amount': _cartTotal,
      'status': 'مدفوعة',
      'type': 'sale',
      'branch_id': _branchId,
      'branch_name': _branchName,
      'items': jsonEncode(items),
    });

    // بطاقة الفاتورة
    printInvoice(
      invoiceNo: invoiceNo,
      date: _today,
      customer: _customerCtrl.text.trim().isEmpty
          ? 'عميل نقدي'
          : _customerCtrl.text.trim(),
      lines: [
        for (final l in _cart)
          PrintLine(
            name: l.product['name']?.toString() ?? 'منتج',
            price: l.price,
            qty: l.qty,
            total: l.total,
          ),
      ],
      total: _cartTotal,
    );

    final reminder = remaining.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(0)}')
        .join(' | ');

    setState(() {
      _cart.clear();
      _customerCtrl.clear();
    });
    await _loadToday();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'تم بيع الفاتورة $invoiceNo — المخزون المتبقي: $reminder',
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
    // عرض إعلان بيني عند إتمام البيع (بعد تراجع يراعي سياسة AdMob)
    AdService.instance.tryShowInterstitial(source: 'pos_checkout');
  }

  // ==================== الواجهة ====================
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
                      'نقطة البيع',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: _barcodeCtrl,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: 'أدخل رقم الباركود...',
                              prefixIcon: Icon(Icons.barcode_reader, size: 18),
                              isDense: true,
                            ),
                            onSubmitted: _addByBarcode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                          ),
                          onPressed: _openScanner,
                          icon: const Icon(
                            Icons.photo_camera,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'تصوير الباركود',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // السلة
                      Expanded(
                        child: Container(
                          decoration: _card(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'سلة الفاتورة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _cart.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'المسح الباركود لتضيف منتجاً',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          showCheckboxColumn: false,
                                          columns: const [
                                            DataColumn(label: Text('المنتج')),
                                            DataColumn(label: Text('السعر')),
                                            DataColumn(label: Text('الكمية')),
                                            DataColumn(label: Text('الإجمالي')),
                                            DataColumn(label: Text('حذف')),
                                          ],
                                          rows: [
                                            for (final line in _cart)
                                              DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      line.product['name']
                                                              ?.toString() ??
                                                          '-',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      _num.format(line.price),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          onPressed: () =>
                                                              _changeQty(
                                                                line,
                                                                -1,
                                                              ),
                                                          icon: const Icon(
                                                            Icons
                                                                .remove_circle_outline,
                                                            size: 18,
                                                          ),
                                                        ),
                                                        Text(
                                                          line.qty
                                                              .toStringAsFixed(
                                                                0,
                                                              ),
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        IconButton(
                                                          onPressed: () =>
                                                              _changeQty(
                                                                line,
                                                                1,
                                                              ),
                                                          icon: const Icon(
                                                            Icons
                                                                .add_circle_outline,
                                                            size: 18,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      _num.format(line.total),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    IconButton(
                                                      onPressed: () =>
                                                          _removeLine(line),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'إجمالي الفاتورة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_num.format(_cartTotal)} ريال',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // عمود جانبي: الإعداد + ملخص اليوم
                      SizedBox(
                        width: 340,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: _card(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'بيانات العملية',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int?>(
                                    initialValue: _branchId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'الفرع',
                                      isDense: true,
                                    ),
                                    items: [
                                      for (final b in _branches)
                                        DropdownMenuItem<int?>(
                                          value: (b['id'] as num?)?.toInt(),
                                          child: Text(
                                            b['name']?.toString() ?? '-',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _branchId = v),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _customerCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'اسم الزبون',
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF059669,
                                        ),
                                      ),
                                      onPressed: _checkout,
                                      icon: const Icon(
                                        Icons.print,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'طباعة الفاتورة وإتمام البيع',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ملخص اليوم: كم تم بيعه اليوم
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: _card(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'ملخص اليوم',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(
                                          Icons.today,
                                          size: 18,
                                          color: Colors.blueGrey,
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Text(
                                      'التاريخ: $_today',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'إجمالي مبيعات اليوم: ${_num.format(_todayTotal)} ريال',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                    Text(
                                      'عدد الفواتير: ${_todaySales.length}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: _todaySales.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'لا مبيعات اليوم بعد',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : ListView(
                                              children: [
                                                for (final s in _todaySales)
                                                  ListTile(
                                                    dense: true,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      s['invoice_no']
                                                              ?.toString() ??
                                                          '-',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      s['items']?.toString() ??
                                                          s['customer']
                                                              ?.toString() ??
                                                          '',
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    trailing: Text(
                                                      s['amount'].toString(),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
    );
  }
}
