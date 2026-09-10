import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/widgets/barcode_scan_dialog.dart';

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
