import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/database/db_filter.dart';
import '../../systems/system_config.dart';

/// صفحة الإعدادات — بيانات الشركة + هوية النظام/الفرع
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _svc = DatabaseService.instance;
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();
  final _branchNameCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _branchCodeCtrl.dispose();
    _branchNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _svc.getAll(AppConstants.tSettings);
    String value(String key, [String fallback = '']) =>
        settings
            .firstWhere(
              (s) => s['key'] == key,
              orElse: () => {'value': fallback},
            )['value']
            ?.toString() ??
        fallback;
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = value(AppConstants.settingCompanyName);
      _addressCtrl.text = value(AppConstants.settingCompanyAddress);
      _phoneCtrl.text = value(AppConstants.settingCompanyPhone);
      _branchCodeCtrl.text = value(
        AppConstants.settingBranchCode,
        SystemConfig.instance.branchCode,
      );
      _branchNameCtrl.text = value(
        AppConstants.settingBranchName,
        SystemConfig.instance.branchName,
      );
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final values = {
      AppConstants.settingCompanyName: _nameCtrl.text.trim(),
      AppConstants.settingCompanyAddress: _addressCtrl.text.trim(),
      AppConstants.settingCompanyPhone: _phoneCtrl.text.trim(),
      AppConstants.settingBranchCode: _branchCodeCtrl.text.trim().isEmpty
          ? SystemConfig.instance.branchCode
          : _branchCodeCtrl.text.trim(),
      AppConstants.settingBranchName: _branchNameCtrl.text.trim().isEmpty
          ? SystemConfig.instance.branchName
          : _branchNameCtrl.text.trim(),
    };
    for (final entry in values.entries) {
      final existing = await _svc.find(
        AppConstants.tSettings,
        filter: DbFilter.equals('key', entry.key),
      );
      if (existing.isNotEmpty) {
        final key = (existing.first['id'] as num).toInt();
        await _svc.update(AppConstants.tSettings, key, {
          'value': entry.value,
        });
      } else {
        await _svc.insert(AppConstants.tSettings, {
          'key': entry.key,
          'value': entry.value,
        });
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
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
                    'الإعدادات',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 560,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بيانات الشركة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الشركة',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'العنوان',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'هوية هذا النظام (تظهر في تقارير نهاية اليوم)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'بهذا الاسم والكود يُستقبل التقرير في النظام الأساسي.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _branchCodeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'كود الفرع',
                                  helperText: 'مثال: BR01',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _branchNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'اسم الفرع/النظام',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                          ),
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            _saving ? 'جارٍ الحفظ...' : 'حفظ',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
