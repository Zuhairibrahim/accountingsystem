import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';

/// قسم الفروع: ربط الفروع + تصفية إجمالي مبيعات وأرباح اليوم لجميع الفروع
/// + إدارة الفروع (إضافة/تعديل/حذف/بحث)
class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});

  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  final DatabaseService _svc = DatabaseService.instance;
  List<Map<String, Object?>> _branches = [];
  List<Map<String, Object?>> _sales = [];
  List<Map<String, Object?>> _products = [];
  bool _loading = true;
  String _query = '';
  String _today = '';

  static final NumberFormat _num = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _today = DateTime.now().toString().substring(0, 10);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final branches = await _svc.getAll(AppConstants.tBranches);
    final sales = await _svc.getAll(AppConstants.tSales);
    final products = await _svc.getAll(AppConstants.tProducts);
    if (!mounted) return;
    setState(() {
      _branches = branches;
      _sales = sales;
      _products = products;
      _loading = false;
    });
  }

  List<Map<String, Object?>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _branches;
    return _branches.where((r) {
      return r.values.any(
        (v) => v != null && v.toString().toLowerCase().contains(q),
      );
    }).toList();
  }

  // ==================== تصفية اليوم ====================
  List<Map<String, Object?>> get _todaySales =>
      _sales.where((s) => (s['date']?.toString() ?? '') == _today).toList();

  double? _defaultBranchId() {
    for (final b in _branches) {
      if (b['is_default'] == true) return (b['id'] as num?)?.toDouble();
    }
    return null;
  }

  double _salesOf(int? branchId) {
    var sum = 0.0;
    for (final s in _todaySales) {
      if ((s['branch_id'] as num?)?.toInt() == branchId) {
        sum += (s['amount'] as num? ?? 0).toDouble();
      }
    }
    return sum;
  }

  int _countOf(int? branchId) {
    var n = 0;
    for (final s in _todaySales) {
      if ((s['branch_id'] as num?)?.toInt() == branchId) n++;
    }
    return n;
  }

  double _profitOf(int? branchId) {
    var profit = 0.0;
    for (final s in _todaySales) {
      if ((s['branch_id'] as num?)?.toInt() != branchId) continue;
      profit += _profitOfSale(s);
    }
    return profit;
  }

  /// الربح التقديري لسلة فاتورة = (سعر البيع - تكلفة) × الكمية
  double _profitOfSale(Map<String, Object?> sale) {
    final raw = sale['items']?.toString();
    if (raw == null || raw.isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return 0;
      var profit = 0.0;
      for (final item in decoded) {
        final map = item as Map<String, dynamic>;
        final name = map['name']?.toString() ?? '';
        final qty = (map['qty'] as num? ?? 1).toDouble();
        final price = (map['price'] as num? ?? 0).toDouble();
        num? cost;
        for (final p in _products) {
          if (p['name']?.toString() == name) {
            cost = p['price'] as num?;
            break;
          }
        }
        profit += (price - (cost ?? 0)) * qty;
      }
      return profit;
    } catch (_) {
      return 0;
    }
  }

  double get _grandTotal => _todaySales.fold<double>(
    0,
    (s, x) => s + (x['amount'] as num? ?? 0).toDouble(),
  );

  double get _grandProfit => _todaySales.fold<double>(
    0,
    (s, x) => s + _profitOfSale(x),
  );

  // ==================== نموذج الفرع ====================
  Future<void> _openForm([Map<String, Object?>? record]) async {
    final isEdit = record != null;
    final messenger = ScaffoldMessenger.of(context);
    final fields = [
      ('code', 'كود الفرع', () => (record?['code']?.toString() ?? '')),
      (
        'name',
        'اسم الفرع',
        () => (record?['name']?.toString() ?? ''),
      ),
      (
        'governorate',
        'المحافظة',
        () => (record?['governorate']?.toString() ?? ''),
      ),
      ('phone', 'الهاتف', () => (record?['phone']?.toString() ?? '')),
      ('address', 'العنوان', () => (record?['address']?.toString() ?? '')),
      ('manager', 'مدير الفرع', () => (record?['manager']?.toString() ?? '')),
    ];
    final controllers = <String, TextEditingController>{
      for (final (f, _, getter) in fields)
        f: TextEditingController(text: getter()),
    };
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isEdit ? 'تعديل فرع' : 'إضافة فرع جديد',
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
                  for (final (f, label, _) in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        controller: controllers[f],
                        decoration: InputDecoration(labelText: label),
                        validator: f == 'governorate' || f == 'address'
                            ? null
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
              final defaultBranch = _defaultBranchId();
              if (!isEdit && defaultBranch == null) data['is_default'] = true;
              for (final (f, _, _) in fields) {
                final text = controllers[f]!.text.trim();
                if (text.isEmpty) continue;
                data[f] = text;
              }
              if (isEdit) {
                await _svc.update(
                  AppConstants.tBranches,
                  (record['id'] as num).toInt(),
                  data,
                );
              } else {
                await _svc.insert(AppConstants.tBranches, data);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _load();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(isEdit ? 'تم تعديل الفرع' : 'تمت إضافة الفرع'),
                ),
              );
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, Object?> record) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف ${record['name']}؟'),
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
      AppConstants.tBranches,
      (record['id'] as num).toInt(),
    );
    _load();
    messenger.showSnackBar(const SnackBar(content: Text('تم حذف الفرع')));
  }

  // ==================== الواجهة ====================
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
              const Text(
                'الفروع',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'بحث عن فرع...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodaySummary(),
                    const SizedBox(height: 20),
                    _buildBranchesTable(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== تصفية اليوم ====================
  Widget _buildTodaySummary() {
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
              const Icon(Icons.pie_chart, color: Color(0xFF0F172A), size: 20),
              const SizedBox(width: 8),
              Text(
                'تصفية اليوم ($_today) — إجمالي جميع الفروع',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _summaryChip(
                'عدد الفروع',
                '${_branches.length}',
                Icons.store_mall_directory,
                const Color(0xFF0F172A),
              ),
              _summaryChip(
                'مبيعات اليوم (كل الفروع)',
                '${_num.format(_grandTotal)} ريال',
                Icons.point_of_sale,
                const Color(0xFFCA8A04),
              ),
              _summaryChip(
                'صافي أرباح اليوم (تقديري)',
                '${_num.format(_grandProfit)} ريال',
                Icons.savings,
                const Color(0xFF059669),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('الفرع')),
                DataColumn(label: Text('المحافظة')),
                DataColumn(label: Text('مبيعات اليوم')),
                DataColumn(label: Text('الفواتير')),
                DataColumn(label: Text('الأرباح')),
              ],
              rows: [
                for (final b in _branches)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          b['name']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text(b['governorate']?.toString() ?? '-')),
                      DataCell(
                        Text(
                          '${_num.format(_salesOf((b['id'] as num?)?.toInt()))} ريال',
                          style: const TextStyle(
                            color: Color(0xFFCA8A04),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(Text('${_countOf((b['id'] as num?)?.toInt())}')),
                      DataCell(
                        Text(
                          '${_num.format(_profitOf((b['id'] as num?)?.toInt()))} ريال',
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                DataRow(
                  cells: [
                    const DataCell(
                      Text(
                        'الإجمالي العام',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataCell(Text('')),
                    DataCell(
                      Text(
                        '${_num.format(_grandTotal)} ريال',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(Text('${_todaySales.length}')),
                    DataCell(
                      Text(
                        '${_num.format(_grandProfit)} ريال',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _summaryChip(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== جدول الفروع ====================
  Widget _buildBranchesTable() {
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
          const Text(
            'قائمة الفروع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          _filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد فروع بعد')),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 44,
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(
                        label: Text(
                          '#',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(label: Text('الكود')),
                      DataColumn(label: Text('اسم الفرع')),
                      DataColumn(label: Text('المحافظة')),
                      DataColumn(label: Text('الهاتف')),
                      DataColumn(label: Text('المدير')),
                      DataColumn(label: Text('إجراءات')),
                    ],
                    rows: [
                      for (var i = 0; i < _filtered.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(_filtered[i]['code']?.toString() ?? '-')),
                            DataCell(
                              Text(
                                _filtered[i]['name']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _filtered[i]['governorate']?.toString() ?? '-',
                              ),
                            ),
                            DataCell(
                              Text(_filtered[i]['phone']?.toString() ?? '-'),
                            ),
                            DataCell(
                              Text(_filtered[i]['manager']?.toString() ?? '-'),
                            ),
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
        ],
      ),
    );
  }
}