import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/database/db_filter.dart';
import '../../core/utils/audit_log_service.dart';
import '../../core/utils/cross_tab.dart';
import '../../core/utils/file_transfer.dart';
import '../../core/utils/system_sync.dart';
import '../../systems/system_config.dart';

/// حالات الحضور والغياب (تُخزَّن بالرمز الإنجليزي وتُعرض بالعربية)
const List<({String key, String label})> kAttendanceStatuses = [
  (key: 'present', label: 'حاضر'),
  (key: 'absent', label: 'غائب'),
  (key: 'leave', label: 'إجازة'),
  (key: 'late', label: 'متأخر'),
];

String kAttendanceLabel(String? key) {
  for (final s in kAttendanceStatuses) {
    if (s.key == key) return s.label;
  }
  return '—';
}

/// نظام الحضور والغياب:
/// - كل يوم تُسجَّل حالة كل موظف (قائمة منسدلة) مع زر حفظ مرتبط بالتاريخ.
/// - من اليوم الثاني تظهر حالة كل شخص (حاضر/غائب/إجازة/متأخر) تلقائياً.
/// - تقرير نهاية اليوم يُرفع للنظام الرئيسي (المدير) تلقائياً.
/// - تقرير شهري: الحاضرون طوال الشهر والغائبون بأيام محددة مع ملاحظة الغياب.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final DatabaseService _svc = DatabaseService.instance;

  DateTime _date = DateTime.now();
  DateTime _month = DateTime.now();

  bool _loading = true;
  bool _saving = false;
  bool _sending = false;

  String _branchCode = '';
  String _branchName = '';
  String _companyName = '';

  List<Map<String, Object?>> _employees = [];
  List<Map<String, Object?>> _allRecords = [];

  /// حالة الموظف المختارة لليوم المحدد: employeeId -> (statusKey, note)
  final Map<int, String> _statusDraft = {};
  final Map<int, TextEditingController> _noteDrafts = {};

  String get _dateKey {
    final m = _date.month.toString().padLeft(2, '0');
    final d = _date.day.toString().padLeft(2, '0');
    return '${_date.year}-$m-$d';
  }

  String get _monthKey {
    final m = _month.month.toString().padLeft(2, '0');
    return '${_month.year}-$m';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _noteDrafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final settings = await _svc.getAll(AppConstants.tSettings);
    String setting(String key, String fallback) {
      for (final s in settings) {
        if (s['key'] == key) return s['value']?.toString() ?? fallback;
      }
      return fallback;
    }

    _branchCode = setting(
      AppConstants.settingBranchCode,
      SystemConfig.instance.branchCode,
    );
    _branchName = setting(
      AppConstants.settingBranchName,
      SystemConfig.instance.branchName,
    );
    _companyName = setting(
      AppConstants.settingCompanyName,
      'شركتي',
    );

    final employees = await _svc.getAll(
      AppConstants.tEmployees,
      sortAsc: ['name'],
    );
    final records = await _svc.getAll(AppConstants.tAttendance);

    if (!mounted) return;
    setState(() {
      _employees = employees;
      _allRecords = records;
      _loading = false;
    });
    _seedDrafts();
  }

  /// تحميل الحالة المحفوظة لليوم المختار إلى القوائم المنسدلة
  void _seedDrafts() {
    for (final c in _noteDrafts.values) {
      c.dispose();
    }
    _noteDrafts.clear();
    _statusDraft.clear();
    final forDate = _allRecords.where((r) => r['date']?.toString() == _dateKey);
    final byEmployee = <int, String>{
      for (final r in forDate)
        if (r['employee_id'] is num && r['status'] != null)
          (r['employee_id'] as num).toInt(): r['status']!.toString(),
    };
    for (final e in _employees) {
      final id = (e['id'] as num).toInt();
      _statusDraft[id] = byEmployee[id] ?? 'present';
    }
  }

  String _noteOf(int employeeId) {
    final controller = _noteDrafts[employeeId];
    if (controller != null && controller.text.trim().isNotEmpty) {
      return controller.text.trim();
    }
    final forDate = _allRecords.where((r) {
      final eid = r['employee_id'];
      return eid is num &&
          eid.toInt() == employeeId &&
          r['date']?.toString() == _dateKey;
    });
    if (forDate.isEmpty) return '';
    return forDate.first['note']?.toString() ?? '';
  }

  bool _hasSaved(int employeeId) {
    return _allRecords.any((r) {
      final eid = r['employee_id'];
      return eid is num &&
          eid.toInt() == employeeId &&
          r['date']?.toString() == _dateKey;
    });
  }

  // ==================== حفظ الحضور والغياب لليوم ====================
  Future<void> _saveDate() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    // حذف أي سجلات قديمة لنفس اليوم ثم إعادة التسجيل نظيفاً
    final existing = await _svc.find(
      AppConstants.tAttendance,
      filter: DbFilter.equals('date', _dateKey),
    );
    for (final rec in existing) {
      await _svc.delete(
        AppConstants.tAttendance,
        (rec['id'] as num).toInt(),
      );
    }

    for (final e in _employees) {
      final id = (e['id'] as num).toInt();
      final status = _statusDraft[id] ?? 'present';
      final note = status == 'absent' ? _noteOf(id) : '';
      await _svc.insert(
        AppConstants.tAttendance,
        {
          'employee_id': id,
          'employee': e['name']?.toString() ?? '',
          'date': _dateKey,
          'status': status,
          'note': note,
          'saved_at': DateTime.now().toIso8601String(),
        },
      );
    }

    final records = await _svc.getAll(AppConstants.tAttendance);
    if (!mounted) return;
    setState(() {
      _allRecords = records;
      _saving = false;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text('تم حفظ الحضور والغياب ليوم $_dateKey (${_employees.length} موظف)'),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  // ==================== إرسال تقرير اليوم للمدير ====================
  Map<String, Object?> _buildReportJson() {
    final present = _employees.where(
      (e) => _statusDraft[(e['id'] as num).toInt()] == 'present',
    ).length;
    final absent = _employees.where(
      (e) => _statusDraft[(e['id'] as num).toInt()] == 'absent',
    ).length;
    final leave = _employees.where(
      (e) => _statusDraft[(e['id'] as num).toInt()] == 'leave',
    ).length;
    final late = _employees.where(
      (e) => _statusDraft[(e['id'] as num).toInt()] == 'late',
    ).length;

    return {
      'format': 'branch_attendance_report',
      'version': 1,
      'system_id': SystemConfig.instance.systemId,
      'branch_code': _branchCode,
      'branch_name': _branchName,
      'company_name': _companyName,
      'report_date': _dateKey,
      'generated_at': DateTime.now().toIso8601String(),
      'summary': {
        'total_employees': _employees.length,
        'present': present,
        'absent': absent,
        'leave': leave,
        'late': late,
      },
      'employees': [
        for (final e in _employees)
          {
            'name': e['name']?.toString() ?? '-',
            'status': _statusDraft[(e['id'] as num).toInt()] ?? 'present',
            'status_label': kAttendanceLabel(
              _statusDraft[(e['id'] as num).toInt()],
            ),
            'note': _noteOf((e['id'] as num).toInt()),
            'has_saved': _hasSaved((e['id'] as num).toInt()),
          },
      ],
    };
  }

  Future<void> _storeReportLocal() async {
    final data = _buildReportJson();
    final summary = data['summary'] as Map<String, Object?>;
    final existing = await _svc.find(
      AppConstants.tAttendanceReports,
      filter: DbFilter.and([
        DbFilter.equals('branch_code', data['branch_code']),
        DbFilter.equals('report_date', data['report_date']),
      ]),
    );
    final record = <String, Object?>{
      'branch_code': data['branch_code'],
      'branch_name': data['branch_name'],
      'system_id': data['system_id'],
      'report_date': data['report_date'],
      'generated_at': data['generated_at'],
      'total_employees': summary['total_employees'],
      'present': summary['present'],
      'absent': summary['absent'],
      'leave': summary['leave'],
      'late': summary['late'],
      'employees': jsonEncode(data['employees']),
      'received_at': DateTime.now().toIso8601String(),
    };
    if (existing.isNotEmpty) {
      await _svc.update(
        AppConstants.tAttendanceReports,
        (existing.first['id'] as num).toInt(),
        record,
      );
    } else {
      await _svc.insert(AppConstants.tAttendanceReports, record);
    }
  }

  Future<void> _sendToday() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_employees.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'لا يوجد موظفون في هذا الفرع بعد — أضف الموظفين أولاً ثم أرسل التقرير',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final data = _buildReportJson();
    await _storeReportLocal();
    notifyReportSent({
      'branch_code': _branchCode,
      'branch_name': _branchName,
      'report_date': _dateKey,
      'system_id': SystemConfig.instance.systemId,
      'type': 'attendance',
    });
    final pushed = await pushReport(data);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final filename = 'حضور($_branchCode)-$_dateKey.json'.replaceAll('/', '-');
    downloadTextFile(filename, json);
    // تسجيل عملية إرسال تقرير الحضور في سجل العمليات
    AuditLogService.record(
      AuditAction.attendanceSent,
      details: 'إرسال تقرير الحضور $_branchName — $_dateKey',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          pushed
              ? 'تم رفع تقرير الحضور $_branchName ($_dateKey) — وصل للنظام الرئيسي تلقائياً'
              : 'تم إنشاء التقرير — أرسله يدوياً إن لم يستقبله النظام الرئيسي',
        ),
        backgroundColor: pushed ? Colors.green.shade700 : Colors.orange.shade800,
      ),
    );
  }

  // ==================== الإحصاءات ====================
  Map<String, int> _dailyStats() {
    var present = 0, absent = 0, leave = 0, late = 0;
    for (final e in _employees) {
      switch (_statusDraft[(e['id'] as num).toInt()] ?? 'present') {
        case 'present':
          present++;
        case 'absent':
          absent++;
        case 'leave':
          leave++;
        case 'late':
          late++;
      }
    }
    return {
      'present': present,
      'absent': absent,
      'leave': leave,
      'late': late,
    };
  }

  // ==================== التقرير الشهري ====================
  List<Map<String, Object?>> _monthlyRows() {
    final monthRecords = _allRecords
        .where((r) => (r['date']?.toString() ?? '').startsWith(_monthKey))
        .toList();

    final rows = <Map<String, Object?>>[];
    for (final e in _employees) {
      final id = (e['id'] as num).toInt();
      final name = e['name']?.toString() ?? '-';
      final mine = monthRecords
          .where((r) => (r['employee_id'] as num?)?.toInt() == id)
          .toList();
      final presentDays = mine
          .where((r) => r['status']?.toString() == 'present')
          .length;
      final lateDays = mine
          .where((r) => r['status']?.toString() == 'late')
          .length;
      final leaveDays = mine
          .where((r) => r['status']?.toString() == 'leave')
          .length;
      final absentList = mine
          .where((r) => r['status']?.toString() == 'absent')
          .toList();
      final noData = mine.isEmpty;
      final fullMonth =
          !noData && absentList.isEmpty && leaveDays == 0 && lateDays == 0;
      rows.add({
        'name': name,
        'no_data': noData,
        'full_month': fullMonth,
        'present_days': presentDays,
        'absent_days': absentList.length,
        'leave_days': leaveDays,
        'late_days': lateDays,
        'absent_list': absentList,
        'recorded_days': mine.length,
      });
    }
    return rows;
  }

  // ==================== الواجهة ====================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _employees.isEmpty
                ? _buildEmpty()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildDailySummary(),
                        const SizedBox(height: 16),
                        _buildDailyTable(),
                        const SizedBox(height: 16),
                        _buildSendRow(),
                        const SizedBox(height: 24),
                        _buildMonthlyHeader(),
                        const SizedBox(height: 10),
                        _buildMonthlyTable(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          const Text('لا يوجد موظفون بعد'),
          const SizedBox(height: 6),
          const Text(
            'أضف الموظفين من قسم «الموظفين» أولاً ثم سجّل الحضور والغياب هنا.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                const Text(
                  'الحضور والغياب اليومي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_branchName ($_branchCode) — $_companyName',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  'سجّل حالة كل موظف ثم اضغط «حفظ». من اليوم الثاني يظهر سجل الحالة لكل موظف تلقائياً.',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          // إختيار التاريخ
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(_dateKey),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCA8A04), width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ الحضور',
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _seedDrafts();
  }

  // ==================== ملخص اليوم ====================
  Widget _buildDailySummary() {
    final s = _dailyStats();
    Color color(String key) => switch (key) {
      'present' => const Color(0xFF16A34A),
      'absent' => const Color(0xFFDC2626),
      'leave' => const Color(0xFFD97706),
      _ => const Color(0xFF2563EB),
    };
    final items = [
      (key: 'present', label: 'حاضر', value: s['present']!.toDouble()),
      (key: 'absent', label: 'غائب', value: s['absent']!.toDouble()),
      (key: 'leave', label: 'إجازة', value: s['leave']!.toDouble()),
      (key: 'late', label: 'متأخر', value: s['late']!.toDouble()),
    ];
    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        for (final it in items)
          Container(
            width: 200,
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
                    Icon(Icons.people, color: color(it.key), size: 18),
                    const SizedBox(width: 8),
                    Text(it.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  it.value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color(it.key),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==================== جدول تسجيل اليوم ====================
  Widget _buildDailyTable() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تسجيل الحضور والغياب — $_dateKey',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                ),
                onPressed: _saving ? null : _saveDate,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _saving ? 'جارٍ الحفظ...' : 'حفظ الحضور والغياب (مع التاريخ)',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('الموظف')),
                DataColumn(label: Text('الحالة')),
                DataColumn(label: Text('ملاحظة الغياب')),
                DataColumn(label: Text('مسجّل')),
              ],
              rows: [
                for (var i = 0; i < _employees.length; i++)
                  DataRow(
                    cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(
                        Text(
                          _employees[i]['name']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(_buildStatusDropdown(_employees[i])),
                      DataCell(_buildNoteField(_employees[i])),
                      DataCell(
                        _hasSaved((_employees[i]['id'] as num).toInt())
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF16A34A),
                                size: 18,
                              )
                            : const Text(
                                '—',
                                style: TextStyle(color: Colors.grey),
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

  Widget _buildStatusDropdown(Map<String, Object?> employee) {
    final id = (employee['id'] as num).toInt();
    final value = _statusDraft[id] ?? 'present';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: [
            for (final s in kAttendanceStatuses)
              DropdownMenuItem(value: s.key, child: Text(s.label)),
          ],
          onChanged: (v) => setState(() => _statusDraft[id] = v ?? 'present'),
        ),
      ),
    );
  }

  Widget _buildNoteField(Map<String, Object?> employee) {
    final id = (employee['id'] as num).toInt();
    final controller = _noteDrafts.putIfAbsent(
      id,
      () => TextEditingController(text: _noteOf(id)),
    );
    final isAbsent = _statusDraft[id] == 'absent';
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        enabled: isAbsent,
        onChanged: (v) {},
        decoration: InputDecoration(
          isDense: true,
          hintText: isAbsent ? 'سبب الغياب...' : '—',
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFCA8A04)),
          ),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  // ==================== زر رفع تقرير اليوم للمدير ====================
  Widget _buildSendRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: const Color(0xFF16A34A), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'يُرفع تقرير الحضور اليومي إلى النظام الرئيسي (المدير) تلقائياً '
              'بضغطة واحدة، مع نسخة احتياطية قابلة للتنزيل.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            onPressed: _sending ? null : _sendToday,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
            label: Text(
              _sending ? 'جارٍ الرفع...' : 'رفع تقرير اليوم للمدير',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== التقرير الشهري ====================
  Widget _buildMonthlyHeader() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'التقرير الشهري (الحاضرون طوال الشهر / الغائبون بأيام محددة)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(_monthLabel()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCA8A04), width: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'الموظفون الذين لم يُسجَّل لهم أي غياب/إجازة/تأخير في هذا الشهر يُعتبرون حاضرين طوال الشهر، '
            'والغائبون تظهر أيام غيابهم مع ملاحظة الغياب.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _monthLabel() {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'اختر الشهر',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    setState(() => _month = picked);
  }

  String _noteOfRec(Map<String, Object?> r) => (r['note']?.toString() ?? '').trim();

  Widget _buildMonthlyTable() {
    final rows = _monthlyRows();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'لا توجد بيانات حضور لهذا الشهر بعد — سجّل الحضور من الأعلى.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('الموظف')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('أيام حضور')),
                  DataColumn(label: Text('أيام غياب')),
                  DataColumn(label: Text('أيام إجازة')),
                  DataColumn(label: Text('أيام تأخير')),
                  DataColumn(label: Text('تفاصيل الغياب')),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(
                          Text(
                            rows[i]['name']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          _monthStatusChip(rows[i]),
                        ),
                        DataCell(
                          Text('${rows[i]['present_days'] ?? 0}'),
                        ),
                        DataCell(
                          Text(
                            '${rows[i]['absent_days'] ?? 0}',
                            style: const TextStyle(color: Color(0xFFDC2626)),
                          ),
                        ),
                        DataCell(Text('${rows[i]['leave_days'] ?? 0}')),
                        DataCell(Text('${rows[i]['late_days'] ?? 0}')),
                        DataCell(
                          SizedBox(
                            width: 280,
                            child: _absentDetails(rows[i]),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _monthStatusChip(Map<String, Object?> row) {
    final Widget content;
    final Color color;
    if (row['no_data'] == true) {
      content = const Text('لا بيانات', style: TextStyle(fontSize: 12, color: Colors.grey));
      color = Colors.grey;
    } else if (row['full_month'] == true) {
      content = const Text(
        'حاضر طوال الشهر',
        style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
      );
      color = const Color(0xFF16A34A);
    } else {
      content = Text(
        row['absent_days'] == 0 ? 'إجازة/تأخير' : 'لديه غياب',
        style: const TextStyle(fontSize: 12, color: Color(0xFFD97706)),
      );
      color = const Color(0xFFD97706);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }

  Widget _absentDetails(Map<String, Object?> row) {
    final absentList = (row['absent_list'] as List<Map<String, Object?>>? ?? []);
    if (absentList.isEmpty) {
      return Text(
        row['no_data'] == true ? '—' : 'لا يوجد غياب',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final a in absentList)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              '${a['date']}${_noteOfRec(a).isEmpty ? '' : ' — ${_noteOfRec(a)}'}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
            ),
          ),
      ],
    );
  }
}