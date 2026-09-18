import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/ads/app_ad_banner.dart';
import '../../core/auth/auth_session.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../systems/admin/branch_manager_page.dart';
import '../../systems/admin/section_reports_page.dart';
import '../../systems/eod/eod_report_page.dart';
import '../../systems/system_config.dart';
import '../attendance/attendance_page.dart';
import '../module/data_module_page.dart';
import '../branches/branches_page.dart';
import '../products/products_page.dart';
import '../reports/reports_page.dart';
import '../sales/pos_page.dart';
import '../settings/settings_page.dart';

/// النظام المحاسبي المتكامل — واجهة 2026: قائمة جانبية مصنّفة + لوحة تحكم حديثة
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final DatabaseService _dbService = DatabaseService.instance;
  Map<String, dynamic> _metrics = {};
  List<Map<String, Object?>> _invoices = [];
  List<Map<String, Object?>> _products = [];
  bool _isLoading = true;

  static final intl.NumberFormat _money = intl.NumberFormat('#,##0');

  /// فهرس الأقسام الخاصة
  static const int _posIndex = 1;
  static const int _branchesIndex = 2;
  static const int _productsIndex = 6;
  static const int _reportsIndex = 16;
  static const int _attendanceIndex = 13;
  static const int _settingsIndex = 17;
  static const int _eodIndex = 19;
  static const int _addBranchIndex = 20;
  static const int _sectionReportsIndex = 22;

  /// تعريفات وحدات الجداول — الفهرس في القائمة = الفهرس في المصفوفة
  static const List<({String title, String store, List<ColumnField> columns})>
  _moduleSpecs = [
    (title: '', store: '', columns: []), // 0 لوحة التحكم
    (title: '', store: '', columns: []), // 1 نقطة البيع
    (title: '', store: '', columns: []), // 2 الفروع (صفحة خاصة)
    (
      // 3 المشتريات
      title: 'المشتريات',
      store: AppConstants.tPurchases,
      columns: [
        ColumnField('invoice_no', 'رقم الفاتورة'),
        ColumnField('date', 'التاريخ'),
        ColumnField('supplier', 'المورد'),
        ColumnField('amount', 'المبلغ', type: FieldType.number),
        ColumnField('status', 'الحالة'),
      ],
    ),
    (
      // 4 العملاء
      title: 'العملاء',
      store: AppConstants.tCustomers,
      columns: [
        ColumnField('code', 'الرمز'),
        ColumnField('name', 'الاسم'),
        ColumnField('phone', 'الهاتف'),
        ColumnField('address', 'العنوان'),
        ColumnField('balance', 'الرصيد', type: FieldType.number),
      ],
    ),
    (
      // 5 الموردين
      title: 'الموردين',
      store: AppConstants.tSuppliers,
      columns: [
        ColumnField('code', 'الرمز'),
        ColumnField('name', 'الاسم'),
        ColumnField('phone', 'الهاتف'),
        ColumnField('address', 'العنوان'),
      ],
    ),
    (title: '', store: '', columns: []), // 6 المنتجات (صفحة خاصة)
    (
      // 7 المخزون
      title: 'المخزون',
      store: AppConstants.tStockMovements,
      columns: [
        ColumnField('product', 'المنتج'),
        ColumnField('warehouse', 'المستودع'),
        ColumnField('type', 'النوع'),
        ColumnField('qty', 'الكمية', type: FieldType.number),
        ColumnField('date', 'التاريخ'),
      ],
    ),
    (
      // 8 الصندوق
      title: 'الصندوق',
      store: AppConstants.tCashAccounts,
      columns: [
        ColumnField('name', 'اسم الصندوق'),
        ColumnField('balance', 'الرصيد', type: FieldType.number),
      ],
    ),
    (
      // 9 البنوك
      title: 'البنوك',
      store: AppConstants.tBankAccounts,
      columns: [
        ColumnField('name', 'اسم الحساب'),
        ColumnField('bank_name', 'البنك'),
        ColumnField('iban', 'رقم الآيبان'),
        ColumnField('balance', 'الرصيد', type: FieldType.number),
      ],
    ),
    (
      // 10 المصروفات
      title: 'المصروفات',
      store: AppConstants.tExpenses,
      columns: [
        ColumnField('expense_no', 'رقم السند'),
        ColumnField('date', 'التاريخ'),
        ColumnField('description', 'البيان'),
        ColumnField('amount', 'المبلغ', type: FieldType.number),
      ],
    ),
    (
      // 11 الموظفين
      title: 'الموظفين',
      store: AppConstants.tEmployees,
      columns: [
        ColumnField('name', 'الاسم'),
        ColumnField('phone', 'الهاتف'),
        ColumnField('base_salary', 'الراتب الأساسي', type: FieldType.number),
        ColumnField('net_salary', 'صافي الراتب', type: FieldType.number),
      ],
    ),
    (
      // 12 الرواتب
      title: 'الرواتب',
      store: AppConstants.tSalaryRecords,
      columns: [
        ColumnField('employee', 'الموظف'),
        ColumnField('month', 'الشهر'),
        ColumnField('year', 'السنة'),
        ColumnField('base_salary', 'الأساسي', type: FieldType.number),
        ColumnField('allowances', 'البدلات', type: FieldType.number),
        ColumnField('deductions', 'الخصومات', type: FieldType.number),
        ColumnField('net', 'الصافي', type: FieldType.number),
      ],
    ),
    (
      // 13 الحضور والغياب
      title: 'الحضور والغياب',
      store: AppConstants.tAttendance,
      columns: [
        ColumnField('employee', 'الموظف'),
        ColumnField('date', 'التاريخ'),
        ColumnField('status', 'الحالة (حاضر/غائب)'),
      ],
    ),
    (title: '', store: '', columns: []), // 14 التقارير
    (title: '', store: '', columns: []), // 15 الإعدادات
    (title: '', store: '', columns: []), // 16 تقارير الأنظمة (النظام الأساسي)
    (title: '', store: '', columns: []), // 17 ترحيل نهاية اليوم
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // قراءة متوازية — لوحة التحكم تظهر بأقصى سرعة بدون انتظار متسلسل
    final results = await Future.wait([
      _dbService.getDashboardMetrics(),
      _dbService.getAll(AppConstants.tSales),
      _dbService.getAll(AppConstants.tProducts),
    ]);

    if (!mounted) return;
    setState(() {
      _metrics = results[0] as Map<String, dynamic>;
      _invoices = results[1] as List<Map<String, Object?>>;
      _products = results[2] as List<Map<String, Object?>>;
      _isLoading = false;
    });
  }

  String get _pageTitle => switch (_selectedIndex) {
        0 => 'لوحة التحكم',
        1 => 'المبيعات (نقطة البيع)',
        2 => 'الفروع',
        16 => 'التقارير',
        17 => 'الإعدادات',
        19 => 'ترحيل نهاية اليوم',
        20 => 'إضافة فرع جديد',
        22 => 'استقبال تقارير الفروع',
        _ =>
          _moduleSpecs[_selectedIndex].title.isNotEmpty
              ? _moduleSpecs[_selectedIndex].title
              : 'النظام المحاسبي',
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _selectedIndex == 0
                        ? (_isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFB45309),
                                  ),
                                )
                              : _buildDashboard())
                        : _buildSection(),
                  ),
                  const AppAdBanner(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== القائمة الجانبية الحديثة ====================
  static const _sidebarBg = Color(0xFF0B1220);
  static const _gold = Color(0xFFF5B21A);

  Widget _buildSidebar() {
    final isAdmin = SystemConfig.instance.isAdmin;
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        border: Border(
          left: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        children: [
          // ====== الشعار ======
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF5B21A), Color(0xFFB45309)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF5B21A).withValues(
                          alpha: 0.30,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النظام المحاسبي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'الإصدار 2.0 — سحابي',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ====== هوية الفرع (أنظمة الفروع فقط — حُذفت من النظام الأساسي) ======
          if (!SystemConfig.instance.isAdmin)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SystemConfig.instance.systemLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${SystemConfig.instance.branchCode} — ${SystemConfig.instance.systemId}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // ====== العناصر المصنّفة ======
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              children: [
                _group('الرئيسية'),
                _item(0, Icons.dashboard_rounded, 'لوحة التحكم'),
                _item(1, Icons.point_of_sale, 'المبيعات (نقطة البيع)'),
                if (isAdmin) _item(2, Icons.store_mall_directory, 'الفروع'),
                _group('العمليات'),
                _item(3, Icons.shopping_cart, 'المشتريات'),
                _item(4, Icons.people, 'العملاء'),
                _item(5, Icons.badge, 'الموردين'),
                _item(6, Icons.inventory_2, 'المنتجات'),
                _item(7, Icons.warehouse, 'المخزون'),
                _group('المالية'),
                _item(8, Icons.move_to_inbox, 'الصندوق'),
                _item(9, Icons.account_balance, 'البنوك'),
                _item(10, Icons.money_off, 'المصروفات'),
                _group('الموارد البشرية'),
                _item(11, Icons.person, 'الموظفين'),
                _item(12, Icons.payments_outlined, 'الرواتب'),
                _item(13, Icons.event_available, 'الحضور والغياب'),
                _group('التقارير والإدارة'),
                _item(16, Icons.analytics, 'التقارير'),
                if (isAdmin)
                  _item(22, Icons.mark_email_read, 'استقبال تقارير الفروع'),
                _item(19, Icons.send, 'ترحيل نهاية اليوم'),
                if (isAdmin)
                  _item(20, Icons.add_business_outlined, 'إضافة فرع جديد'),
                _item(17, Icons.settings, 'الإعدادات'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _gold : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isSelected ? _gold : Colors.transparent,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? _sidebarBg : const Color(0xFF7C8BA1),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? _sidebarBg : const Color(0xFF9AA8BC),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 3.5,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _sidebarBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== الشريط العلوي الحديث ====================
  Widget _buildHeader() {
    return Container(
      height: 72,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8EDF4), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dashboard_outlined,
              color: Color(0xFFB45309),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pageTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'كل البيانات عبر Firebase — حفظ فوري بالسحابة',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _loadData,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF64748B),
              size: 22,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_outlined, size: 14, color: Color(0xFF16A34A)),
                SizedBox(width: 6),
                Text(
                  'متصل بالسحابة',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => AuthSession.instance.logout(),
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5B21A), Color(0xFFB45309)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40F5B21A),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.transparent,
                  child: Text(
                    'ز',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.adminFullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'مدير النظام',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'admin',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== توجيه الأقسام ====================
  Widget _buildSection() {
    switch (_selectedIndex) {
      case _posIndex:
        return const PosPage();
      case _branchesIndex:
        return SystemConfig.instance.isAdmin
            ? const BranchesPage()
            : _buildDashboard();
      case _productsIndex:
        return const ProductsPage();
      case _attendanceIndex:
        return const AttendancePage();
      case _reportsIndex:
        return const ReportsPage();
      case _settingsIndex:
        return const SettingsPage();
      case _eodIndex:
        return const EodReportPage();
      case _addBranchIndex:
        // قسم ملك للأدمن فقط — محذوف نهائياً من أنظمة الفروع
        return SystemConfig.instance.isAdmin
            ? const BranchManagerPage()
            : const EodReportPage();
      case _sectionReportsIndex:
        // استقبال تقارير المنتجات/الموظفين من الفروع — للأدمن فقط
        return SystemConfig.instance.isAdmin
            ? const SectionReportsPage()
            : const EodReportPage();
      default:
        final spec = _moduleSpecs[_selectedIndex];
        return DataModulePage(
          key: ValueKey(_selectedIndex),
          title: spec.title,
          storeName: spec.store,
          columns: spec.columns,
        );
    }
  }

  // ==================== لوحة التحكم الحديثة ====================
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====== الترحيب ======
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة التحكم',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'نظرة شاملة على أداء النظام والأرقام الحية',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1220),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'تحديث',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ====== البطاقات الإحصائية ======
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _kpiCard(
                'صافي الربح',
                '${_money.format(_metrics['net_profit'] ?? 0)} ريال',
                'أرباح حقيقية من القيود',
                Icons.trending_up_rounded,
                const Color(0xFF059669),
                const Color(0xFFECFDF5),
              ),
              _kpiCard(
                'رصيد البنوك',
                '${_money.format(_metrics['bank_balance'] ?? 0)} ريال',
                'حسابات رئيسية',
                Icons.account_balance_rounded,
                const Color(0xFF2563EB),
                const Color(0xFFEFF6FF),
              ),
              _kpiCard(
                'رصيد الصندوق',
                '${_money.format(_metrics['cash_balance'] ?? 0)} ريال',
                'النقدية بالخزينة',
                Icons.wallet_rounded,
                const Color(0xFFD97706),
                const Color(0xFFFFFBEB),
              ),
              _kpiCard(
                'إجمالي المشتريات',
                '${_money.format(_metrics['total_purchases'] ?? 0)} ريال',
                'من فواتير المشتريات',
                Icons.shopping_bag_rounded,
                const Color(0xFF7C3AED),
                const Color(0xFFF5F3FF),
              ),
              _kpiCard(
                'إجمالي المبيعات',
                '${_money.format(_metrics['total_sales'] ?? 0)} ريال',
                'من فواتير المبيعات',
                Icons.point_of_sale_rounded,
                const Color(0xFF0EA5E9),
                const Color(0xFFF0F9FF),
              ),
              _kpiCard(
                'الفواتير المستحقة',
                '${_metrics['outstanding_invoices'] ?? 0} فاتورة',
                'تحتاج متابعة',
                Icons.receipt_long_rounded,
                const Color(0xFFDC2626),
                const Color(0xFFFEF2F2),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ====== مؤشرات سريعة ======
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _quickStat(
                  'العملاء',
                  '${_metrics['customers_count'] ?? 0}',
                  Icons.people_alt_outlined,
                  const Color(0xFF60A5FA),
                ),
                _dividerV(),
                _quickStat(
                  'الموردين',
                  '${_metrics['suppliers_count'] ?? 0}',
                  Icons.badge_outlined,
                  const Color(0xFF34D399),
                ),
                _dividerV(),
                _quickStat(
                  'المنتجات',
                  '${_metrics['products_count'] ?? 0}',
                  Icons.inventory_2_outlined,
                  const Color(0xFFC084FC),
                ),
                _dividerV(),
                _quickStat(
                  'قيمة المخزون',
                  _money.format(_metrics['inventory_value'] ?? 0),
                  Icons.warehouse_outlined,
                  const Color(0xFFF5B21A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ====== الجداول ======
          _modernTableCard(
            'فواتير المبيعات الحقيقية',
            '${_invoices.length} فاتورة',
            _buildSalesTable(),
          ),
          const SizedBox(height: 18),
          _modernTableCard(
            'المنتجات المخزنة',
            '${_products.length} منتج',
            _buildProductsTable(),
          ),
        ],
      ),
    );
  }

  Widget _dividerV() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: const Color(0xFF1E293B),
    );
  }

  Widget _quickStat(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String amount,
    String sub,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Container(
      width: 236,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.5,
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernTableCard(String title, String badge, Widget tableWidget) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          tableWidget,
        ],
      ),
    );
  }

  TextStyle get _tableHeadStyle => const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      );

  TextStyle get _tableCellStyle => const TextStyle(
        color: Color(0xFF334155),
        fontSize: 12.5,
      );

  Widget _buildSalesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: _tableHeadStyle,
        dataTextStyle: _tableCellStyle,
        columns: const [
          DataColumn(label: Text('رقم الفاتورة')),
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('العميل')),
          DataColumn(label: Text('المبلغ')),
          DataColumn(label: Text('الحالة')),
        ],
        rows: _invoices
            .map(
              (inv) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      inv['invoice_no']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  DataCell(Text(inv['date']?.toString() ?? '-')),
                  DataCell(Text(inv['customer']?.toString() ?? '-')),
                  DataCell(
                    Text(
                      _money.format((inv['amount'] as num?) ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(_statusChip(inv['status']?.toString())),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _statusChip(String? status) {
    final s = status ?? 'مدفوعة';
    final (bg, fg) = switch (s) {
      'غير مدفوعة' => (const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
      'جزئية' => (const Color(0xFFFFFBEB), const Color(0xFFB45309)),
      _ => (const Color(0xFFF0FDF4), const Color(0xFF15803D)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProductsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: _tableHeadStyle,
        dataTextStyle: _tableCellStyle,
        columns: const [
          DataColumn(label: Text('الكود')),
          DataColumn(label: Text('اسم المنتج')),
          DataColumn(label: Text('سعر البيع')),
          DataColumn(label: Text('المخزون')),
        ],
        rows: _products
            .take(8)
            .map(
              (p) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      p['code']?.toString() ?? p['barcode']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  DataCell(Text(p['name']?.toString() ?? '-')),
                  DataCell(
                    Text('${(p['sale_price'] as num?) ?? 0}'),
                  ),
                  DataCell(Text('${(p['stock_qty'] as num?) ?? 0}')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
