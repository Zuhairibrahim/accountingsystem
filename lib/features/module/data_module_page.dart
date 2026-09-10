import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/database_service.dart';

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
