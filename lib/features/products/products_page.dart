import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/widgets/barcode_scan_dialog.dart';
import '../../systems/system_config.dart';
import '../reports/full_report_dialog.dart';

/// صفحة المنتجات: إضافة/تعديل/حذف/بحث + التقاط الباركود بالكاميرا
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final DatabaseService _svc = DatabaseService.instance;
  List<Map<String, Object?>> _products = [];
  bool _loading = true;
  String _query = '';

  static final NumberFormat _num = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _svc.getAll(AppConstants.tProducts);
    if (!mounted) return;
    setState(() {
      _products = list;
      _loading = false;
    });
  }

  List<Map<String, Object?>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) {
      return p.values.any(
        (v) => v != null && v.toString().toLowerCase().contains(q),
      );
    }).toList();
  }

  Future<void> _openForm([Map<String, Object?>? product]) async {
    final isEdit = product != null;
    final messenger = ScaffoldMessenger.of(context);
    final barcodeCtrl = TextEditingController(
      text: product?['barcode']?.toString() ?? '',
    );
    final nameCtrl = TextEditingController(
      text: product?['name']?.toString() ?? '',
    );
    final categoryCtrl = TextEditingController(
      text: product?['category']?.toString() ?? '',
    );
    final priceCtrl = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );
    final saleCtrl = TextEditingController(
      text: product?['sale_price']?.toString() ?? '',
    );
    final stockCtrl = TextEditingController(
      text: product?['stock_qty']?.toString() ?? '0',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isEdit ? 'تعديل منتج' : 'إضافة منتج جديد',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: barcodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الباركود (الرقم التسلسلي)',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final code = await scanBarcode(dialogContext);
                          if (code != null) barcodeCtrl.text = code;
                        },
                        tooltip: 'تصوير الباركود',
                        icon: const Icon(
                          Icons.photo_camera,
                          color: Colors.blueGrey,
                        ),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المنتج'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف (مثال: عصير رواب كبير)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر الشراء'),
                    validator: _numValidator,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: saleCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر البيع'),
                    validator: _numValidator,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'كمية المخزون الحالية',
                    ),
                    validator: _numValidator,
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
              final data = <String, Object?>{
                'barcode': barcodeCtrl.text.trim(),
                'name': nameCtrl.text.trim(),
                'category': categoryCtrl.text.trim(),
                'price': num.tryParse(priceCtrl.text) ?? 0,
                'sale_price': num.tryParse(saleCtrl.text) ?? 0,
                'stock_qty': num.tryParse(stockCtrl.text) ?? 0,
              };
              if (isEdit) {
                await _svc.update(
                  AppConstants.tProducts,
                  (product['id'] as num).toInt(),
                  data,
                );
              } else {
                await _svc.insert(AppConstants.tProducts, data);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _load();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    isEdit ? 'تم تعديل المنتج' : 'تم حفظ المنتج في السحابة',
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

  String? _numValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'مطلوب';
    if (num.tryParse(v) == null) return 'أدخل رقماً';
    return null;
  }

  // ==================== التقرير الشامل (عرض + طباعة) ====================
  Future<void> _openFullReport() async {
    final sys = SystemConfig.instance;
    final now = DateTime.now();
    final dateLabel =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    var totalQty = 0.0;
    var costValue = 0.0;
    var saleValue = 0.0;
    var outOfStock = 0;
    var lowStock = 0;
    final categories = <String>{};
    final rows = <List<String>>[];

    final sorted = [..._products]..sort(
        (a, b) => (b['stock_qty'] as num? ?? 0)
            .compareTo(a['stock_qty'] as num? ?? 0),
      );

    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final qty = (p['stock_qty'] as num?) ?? 0;
      final price = (p['price'] as num?) ?? 0;
      final sale = (p['sale_price'] as num?) ?? 0;
      final qtyD = qty.toDouble();
      totalQty += qtyD;
      costValue += qtyD * price.toDouble();
      saleValue += qtyD * sale.toDouble();
      if (qtyD <= 0) outOfStock++;
      if (qtyD > 0 && qtyD <= 5) lowStock++;
      final cat = p['category']?.toString() ?? '';
      if (cat.isNotEmpty) categories.add(cat);
      rows.add([
        '${i + 1}',
        p['barcode']?.toString() ?? '-',
        p['name']?.toString() ?? '-',
        cat.isEmpty ? '—' : cat,
        _num.format(price),
        _num.format(sale),
        qtyD % 1 == 0 ? qtyD.toStringAsFixed(0) : _num.format(qtyD),
        _num.format(qtyD * price.toDouble()),
        _num.format(qtyD * sale.toDouble()),
      ]);
    }

    await showFullReportDialog(
      context: context,
      title: 'التقرير الشامل للمنتجات والمخزون',
      subtitle:
          '${sys.systemLabel} (${sys.branchCode}) — عدد المنتجات: '
          '${_products.length} — بتاريخ $dateLabel',
      reportType: 'products',
      reportTypeLabel: 'تقرير المنتجات والمخزون',
      stats: [
        ReportStat('عدد المنتجات', '${_products.length}', const Color(0xFF2563EB)),
        ReportStat('إجمالي الكميات المتبقية', _num.format(totalQty), const Color(0xFF7C3AED)),
        ReportStat('قيمة المخزون (تكلفة)', _num.format(costValue), const Color(0xFFD97706)),
        ReportStat('قيمة المخزون (بيع)', _num.format(saleValue), const Color(0xFF16A34A)),
        ReportStat('الربح المتوقع', _num.format(saleValue - costValue), const Color(0xFF059669)),
        ReportStat('نفد من المخزون', '$outOfStock', const Color(0xFFDC2626)),
        ReportStat('كمية منخفضة (≤5)', '$lowStock', const Color(0xFFEA580C)),
        ReportStat('عدد التصنيفات', '${categories.length}', const Color(0xFF0F172A)),
      ],
      columns: const [
        ReportColumn('#'),
        ReportColumn('الباركود'),
        ReportColumn('اسم المنتج'),
        ReportColumn('التصنيف'),
        ReportColumn('سعر الشراء'),
        ReportColumn('سعر البيع'),
        ReportColumn('المتبقي'),
        ReportColumn('قيمة التكلفة'),
        ReportColumn('قيمة البيع'),
      ],
      rows: rows,
      totalsRow: [
        'الإجمالي',
        '',
        '${_products.length} منتج',
        '${categories.length} تصنيف',
        '',
        '',
        _num.format(totalQty),
        _num.format(costValue),
        _num.format(saleValue),
      ],
    );
  }

  Future<void> _confirmDelete(Map<String, Object?> product) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا المنتج نهائياً؟'),
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
      AppConstants.tProducts,
      (product['id'] as num).toInt(),
    );
    _load();
    messenger.showSnackBar(const SnackBar(content: Text('تم الحذف')));
  }

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
                      'المنتجات',
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
                          onPressed:
                              _products.isEmpty ? null : _openFullReport,
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
                          label: const Text(
                            'إضافة منتج',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
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
                        ? const Center(child: Text('لا توجد منتجات بعد'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(8),
                            child: DataTable(
                              showCheckboxColumn: false,
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('الباركود')),
                                DataColumn(label: Text('اسم المنتج')),
                                DataColumn(label: Text('التصنيف')),
                                DataColumn(label: Text('سعر الشراء')),
                                DataColumn(label: Text('سعر البيع')),
                                DataColumn(label: Text('المخزون المتبقي')),
                                DataColumn(label: Text('إجراءات')),
                              ],
                              rows: [
                                for (var i = 0; i < _filtered.length; i++)
                                  DataRow(
                                    cells: [
                                      DataCell(Text('${i + 1}')),
                                      DataCell(
                                        Text(
                                          _filtered[i]['barcode']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _filtered[i]['name']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _filtered[i]['category']
                                                  ?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _num.format(
                                            (_filtered[i]['price'] as num?) ??
                                                0,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _num.format(
                                            (_filtered[i]['sale_price']
                                                    as num?) ??
                                                0,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${(_filtered[i]['stock_qty'] as num?) ?? 0}',
                                          style: TextStyle(
                                            color:
                                                ((_filtered[i]['stock_qty']
                                                            as num?) ??
                                                        0) <=
                                                    0
                                                ? Colors.red
                                                : Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: () =>
                                                  _openForm(_filtered[i]),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: Colors.blueGrey,
                                              ),
                                              tooltip: 'تعديل',
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _confirmDelete(_filtered[i]),
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
              ],
            ),
    );
  }
}
