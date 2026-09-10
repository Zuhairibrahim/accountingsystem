import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:web/web.dart' as web;

import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../core/utils/cross_tab.dart';
import '../../core/utils/system_sync.dart';
import '../../systems/branch_registry.dart';
import '../../systems/system_config.dart';

/// مركز التحكم بالأنظمة (تطبيق الأدمن الخاص):
///
/// يحتوي جولة الأنظمة الستة (الأساسي + الفروع الخمسة)، ويمكن الدخول لأي
/// نظام من داخل هذا التطبيق مباشرة، وتُعرض بيانات كل نظام (بيانات موحّدة،
/// يختلف فقط الرابط واسم الفرع وكلمة المرور)، مع استلام أحدث التقارير وعددها
/// مباشرة عبر السحابة.
class SystemHubPage extends StatefulWidget {
  const SystemHubPage({super.key});

  @override
  State<SystemHubPage> createState() => _SystemHubPageState();
}

class _SystemHubPageState extends State<SystemHubPage> {
  final DatabaseService _svc = DatabaseService.instance;
  List<Map<String, Object?>> _reports = [];
  List<Map<String, Object?>> _attendance = [];
  String _companyName = '';
  bool _loading = true;
  StreamSubscription<Map<String, Object?>>? _sub;

  static final NumberFormat _num = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    // استقبال تلقائي فوري: أي تقرير جديد من أي فرع يحدّث المركز مباشرة
    _sub = onReportSent().listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await BranchRegistry.instance.loadAll();
    final settings = await _svc.getAll(AppConstants.tSettings);
    String setting(String key, String fallback) {
      for (final s in settings) {
        if (s['key'] == key) return s['value']?.toString() ?? fallback;
      }
      return fallback;
    }

    final all = await fetchReports();
    final reports = [
      for (final r in all)
        if (r['type'] == 'eod') r,
    ];
    final attendance = [
      for (final r in all)
        if (r['type'] == 'attendance') r,
    ];

    if (!mounted) return;
    setState(() {
      _companyName = setting(AppConstants.settingCompanyName, 'شركتي');
      _reports = reports;
      _attendance = attendance;
      _loading = false;
    });
  }

  String _sameOriginLink(String mode) {
    final uri = Uri.base;
    final scheme = uri.hasScheme ? uri.scheme : 'http';
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    return '$scheme://$host/?sys=$mode';
  }

  String _appLink(String mode) {
    final uri = Uri.base;
    final scheme = uri.hasScheme ? '${uri.scheme}://' : '';
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    return '$scheme$host:${SystemConfig.portOf(mode)}/?sys=$mode';
  }

  List<Map<String, Object?>> _reportsOf(String code) => [
    for (final r in _reports) if ((r['branch_code']?.toString() ?? '') == code) r,
  ];

  List<Map<String, Object?>> _attendanceOf(String code) => [
    for (final a in _attendance) if ((a['branch_code']?.toString() ?? '') == code) a,
  ];

  Future<void> _copy(String text, BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('تم نسخ الرابط')));
  }

  @override
  Widget build(BuildContext context) {
    final modes = SystemConfig.allSystemModes;
    return Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildOverview(modes),
                    const SizedBox(height: 24),
                    Text(
                      'الأنظمة داخل تطبيق الأدمن (${modes.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'كل نظام يحتوي نفس البيانات (المنتجات/الموظفين/المبيعات) '
                      'ويختلف فقط: الرابط واسم الفرع وكلمة المرور. اضغط «دخول» ليُفتح داخل هذا التطبيق.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final mode in modes) _systemCard(mode),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مركز التحكم بالأنظمة — الأدمن',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_companyName — يتحكم بجميع الأنظمة ويستقبل تقارير نهاية اليوم والحضور تلقائياً',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Chip(
            avatar: const Icon(Icons.sync, color: Colors.white, size: 16),
            label: const Text(
              'استقبال تلقائي للتقارير',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(List<String> modes) {
    int reportsCount = _reports.length;
    int attendanceCount = _attendance.length;
    int branched = modes.length - 1;
    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        _overviewCard('الأنظمة', '${modes.length}', Icons.account_tree, const Color(0xFF0F172A)),
        _overviewCard('الفروع المرتبطة', '$branched', Icons.storefront, const Color(0xFFCA8A04)),
        _overviewCard('تقارير نهاية اليوم', '$reportsCount', Icons.receipt_long, const Color(0xFF7C3AED)),
        _overviewCard('تقارير الحضور والغياب', '$attendanceCount', Icons.event_available, const Color(0xFF059669)),
      ],
    );
  }

  Widget _overviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
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

  Widget _systemCard(String mode) {
    final isAdmin = mode == SystemConfig.adminMode;
    final name = SystemConfig.branchNameOf(mode);
    final code = SystemConfig.branchCodeOf(mode);
    final creds = SystemConfig.credentialsOf(mode);
    final link = _sameOriginLink(mode);
    final appLink = _appLink(mode);
    final reports = _reportsOf(code);
    final attendance = _attendanceOf(code);

    final color = isAdmin ? const Color(0xFF0F172A) : const Color(0xFFCA8A04);
    double latestTotal = 0;
    if (reports.isNotEmpty) {
      latestTotal = (reports.first['total_amount'] as num?)?.toDouble() ?? 0;
    }
    int latestPresent = attendance.isNotEmpty
        ? (attendance.first['present'] as num?)?.toInt() ?? 0
        : 0;
    int latestAbsent = attendance.isNotEmpty
        ? (attendance.first['absent'] as num?)?.toInt() ?? 0
        : 0;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAdmin ? Icons.admin_panel_settings : Icons.storefront,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdmin ? '$name (المتحكم)' : name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$code — $mode',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (!isAdmin)
                Chip(
                  avatar: const Icon(Icons.badge, size: 14),
                  label: Text('v$code', style: const TextStyle(fontSize: 10)),
                  backgroundColor: color.withValues(alpha: 0.1),
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                ),
            ],
          ),
          const Divider(height: 20),
          _infoRow('اسم المستخدم', creds.username),
          _infoRow('كلمة المرور', creds.password),
          _infoRow('معرف النظام', mode),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.assessment_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تقرير نهاية اليوم: ${reports.isEmpty ? 'بانتظار أول تقرير' : _num.format(latestTotal)} (${reports.length})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'آخر حضور: حاضر $latestPresent / غائب $latestAbsent (${attendance.length})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => web.window.location.href = link,
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(
                    isAdmin ? 'فتح التطبيق' : 'دخول داخل التطبيق',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'نسخ رابط الدخول',
                onPressed: () => _copy(appLink, context),
                icon: const Icon(
                  Icons.copy,
                  size: 18,
                  color: Color(0xFFCA8A04),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}