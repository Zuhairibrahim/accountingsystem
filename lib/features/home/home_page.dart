import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_service.dart';
import '../../systems/admin/admin_control_page.dart';
import '../../systems/admin/branch_manager_page.dart';
import '../../systems/admin/system_hub_page.dart';
import '../../systems/eod/eod_report_page.dart';
import '../../systems/system_config.dart';
import '../attendance/attendance_page.dart';
import '../module/data_module_page.dart';
import '../branches/branches_page.dart';
import '../products/products_page.dart';
import '../reports/reports_page.dart';
import '../sales/pos_page.dart';
import '../settings/settings_page.dart';

/// النظام المحاسبي المتكامل — قائمة جانبية + نقطة بيع + كل الوحدات
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

  /// فهرس الأقسام الخاصة
  static const int _posIndex = 1;
  static const int _branchesIndex = 2;
  static const int _productsIndex = 6;
  static const int _reportsIndex = 16;
  static const int _attendanceIndex = 13;
  static const int _settingsIndex = 17;
  static const int _adminControlIndex = 18;
  static const int _eodIndex = 19;
  static const int _addBranchIndex = 20;
  static const int _systemHubIndex = 21;

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
    // الأدمن يبدأ من مركز التحكم بالأنظمة داخل تطبيقه (يحتوي الأنظمة داخله)
    _selectedIndex = SystemConfig.instance.isAdmin ? _systemHubIndex : 0;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final metrics = await _dbService.getDashboardMetrics();
    final invoices = await _dbService.getAll(AppConstants.tSales);
    final products = await _dbService.getAll(AppConstants.tProducts);

    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _invoices = invoices;
      _products = products;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Row(
          children: [
            _buildSidebar(),
            // المحتوى الرئيسي
            Expanded(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _selectedIndex == 0
                        ? (_isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildDashboard())
                        : _buildSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== القائمة الجانبية ====================
  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.centerRight,
            child: const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Text(
                  'النظام المحاسبي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // هوية النظام الحالي
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SystemConfig.instance.isAdmin
                  ? const Color(0xFFB45309)
                  : const Color(0xFF1D4ED8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  SystemConfig.instance.isAdmin
                      ? Icons.admin_panel_settings
                      : Icons.storefront,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SystemConfig.instance.systemLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${SystemConfig.instance.branchCode} — ${SystemConfig.instance.systemId}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              children: [
                if (SystemConfig.instance.isAdmin)
                  _buildSidebarItem(
                    21,
                    Icons.account_tree,
                    'مركز الأنظمة (المتحكم)',
                  ),
                _buildSidebarItem(0, Icons.dashboard, 'لوحة التحكم'),
                _buildSidebarItem(
                  1,
                  Icons.point_of_sale,
                  'المبيعات (نقطة البيع)',
                ),
                if (SystemConfig.instance.isAdmin)
                  _buildSidebarItem(
                    2,
                    Icons.store_mall_directory,
                    'الفروع',
                  ),
                _buildSidebarItem(3, Icons.shopping_cart, 'المشتريات'),
                _buildSidebarItem(4, Icons.people, 'العملاء'),
                _buildSidebarItem(5, Icons.badge, 'الموردين'),
                _buildSidebarItem(6, Icons.inventory_2, 'المنتجات'),
                _buildSidebarItem(7, Icons.warehouse, 'المخزون'),
                _buildSidebarItem(8, Icons.move_to_inbox, 'الصندوق'),
                _buildSidebarItem(9, Icons.account_balance, 'البنوك'),
                _buildSidebarItem(10, Icons.money_off, 'المصروفات'),
                _buildSidebarItem(11, Icons.person, 'الموظفين'),
                _buildSidebarItem(12, Icons.payments_outlined, 'الرواتب'),
                _buildSidebarItem(13, Icons.event_available, 'الحضور والغياب'),
                _buildSidebarItem(16, Icons.analytics, 'التقارير'),
                _buildSidebarItem(17, Icons.settings, 'الإعدادات'),
                if (SystemConfig.instance.isAdmin)
                  _buildSidebarItem(
                    18,
                    Icons.account_tree,
                    'تقارير الأنظمة (الربط المركزي)',
                  ),
                _buildSidebarItem(
                  19,
                  Icons.send,
                  'ترحيل نهاية اليوم',
                ),
                if (SystemConfig.instance.isAdmin)
                  _buildSidebarItem(
                    20,
                    Icons.add_business_outlined,
                    'إضافة فرع جديد',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.amber : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== الشريط العلوي ====================
  Widget _buildHeader() {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.menu, color: Colors.grey),
              SizedBox(width: 20),
              SizedBox(
                width: 250,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث هنا...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.notifications_none, color: Colors.grey),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () => AuthSession.instance.logout(),
                icon: const Icon(Icons.logout, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x402563EB),
                          blurRadius: 8,
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
                          fontWeight: FontWeight.bold,
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
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'مدير النظام',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'admin',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
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
      case _systemHubIndex:
        // قسم الأدمن فقط — يحتوي الأنظمة الستة وداخله الانتقال بينها
        return SystemConfig.instance.isAdmin
            ? const SystemHubPage()
            : const EodReportPage();
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
      case _adminControlIndex:
        return SystemConfig.instance.isAdmin
            ? const AdminControlPage()
            : const EodReportPage();
      case _eodIndex:
        return const EodReportPage();
      case _addBranchIndex:
        // قسم ملك للأدمن فقط — محذوف نهائياً من أنظمة الفروع
        return SystemConfig.instance.isAdmin
            ? const BranchManagerPage()
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

  // ==================== لوحة التحكم ====================
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لوحة التحكم',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // البطاقات الإحصائية الست
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              _buildStatCard(
                'صافي الربح',
                '${_metrics['net_profit'] ?? 0} ريال',
                'أرباح حقيقية من القيود',
                Icons.trending_up,
                Colors.red,
                Colors.red.shade50,
              ),
              _buildStatCard(
                'رصيد البنوك',
                '${_metrics['bank_balance'] ?? 0} ريال',
                'حسابات رئيسية',
                Icons.account_balance,
                Colors.green,
                Colors.green.shade50,
              ),
              _buildStatCard(
                'رصيد الصندوق',
                '${_metrics['cash_balance'] ?? 0} ريال',
                'النقدية بالخزينة',
                Icons.wallet,
                Colors.orange,
                Colors.orange.shade50,
              ),
              _buildStatCard(
                'إجمالي المشتريات',
                '${_metrics['total_purchases'] ?? 0} ريال',
                'من فواتير المشتريات',
                Icons.shopping_bag,
                Colors.blue,
                Colors.blue.shade50,
              ),
              _buildStatCard(
                'إجمالي المبيعات',
                '${_metrics['total_sales'] ?? 0} ريال',
                'من فواتير المبيعات',
                Icons.point_of_sale,
                Colors.indigo,
                Colors.indigo.shade50,
              ),
              _buildStatCard(
                'الفواتير المستحقة',
                '${_metrics['outstanding_invoices'] ?? 0} فاتورة',
                'تحتاج متابعة',
                Icons.receipt,
                Colors.purple,
                Colors.purple.shade50,
              ),
            ],
          ),
          const SizedBox(height: 30),

          // مؤشرات سريعة
          Row(
            children: [
              _buildMiniIndicator(
                'العملاء',
                '${_metrics['customers_count'] ?? 0}',
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(width: 15),
              _buildMiniIndicator(
                'الموردين',
                '${_metrics['suppliers_count'] ?? 0}',
                Icons.badge,
                Colors.teal,
              ),
              const SizedBox(width: 15),
              _buildMiniIndicator(
                'المنتجات',
                '${_metrics['products_count'] ?? 0}',
                Icons.inventory_2,
                Colors.deepPurple,
              ),
              const SizedBox(width: 15),
              _buildMiniIndicator(
                'قيمة المخزون',
                '${_metrics['inventory_value'] ?? 0} ريال',
                Icons.warehouse,
                Colors.amber.shade800,
              ),
            ],
          ),
          const SizedBox(height: 30),

          // الجداول التنفيذية
          _buildTableSection(
            'فواتير المبيعات الحقيقية',
            _buildSalesTable(),
          ),
          const SizedBox(height: 20),
          _buildTableSection(
            'المنتجات المخزنة',
            _buildProductsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String amount,
    String sub,
    IconData icon,
    Color color,
    Color bg,
  ) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniIndicator(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildTableSection(String title, Widget tableWidget) {
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
          const SizedBox(height: 10),
          tableWidget,
        ],
      ),
    );
  }

  Widget _buildSalesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
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
                  DataCell(Text(inv['invoice_no']?.toString() ?? '-')),
                  DataCell(Text(inv['date']?.toString() ?? '-')),
                  DataCell(Text(inv['customer']?.toString() ?? '-')),
                  DataCell(Text(inv['amount'].toString())),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        inv['status']?.toString() ?? 'مدفوعة',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildProductsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
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
                    ),
                  ),
                  DataCell(Text(p['name']?.toString() ?? '-')),
                  DataCell(Text('${(p['sale_price'] as num?) ?? 0}')),
                  DataCell(Text('${(p['stock_qty'] as num?) ?? 0}')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
