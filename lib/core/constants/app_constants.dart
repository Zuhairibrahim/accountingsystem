/// الثوابت العامة للتطبيق
class AppConstants {
  AppConstants._();

  /// اسم قاعدة البيانات (IndexedDB داخل المتصفح)
  static const String dbName = 'accounting_system';

  // ==================== StoreNames (الجداول) ====================
  static const String tCompany = 'company';
  static const String tUsers = 'users';
  static const String tRoles = 'roles';
  static const String tPermissions = 'permissions';
  static const String tCustomers = 'customers';
  static const String tSuppliers = 'suppliers';
  static const String tProducts = 'products';
  static const String tProductCategories = 'product_categories';
  static const String tUnits = 'units';
  static const String tBranches = 'branches';
  static const String tWarehouses = 'warehouses';
  static const String tStock = 'stock';
  static const String tStockMovements = 'stock_movements';
  static const String tSales = 'sales';
  static const String tSaleItems = 'sale_items';
  static const String tPurchases = 'purchases';
  static const String tPurchaseItems = 'purchase_items';
  static const String tCashAccounts = 'cash_accounts';
  static const String tCashTransactions = 'cash_transactions';
  static const String tBankAccounts = 'bank_accounts';
  static const String tBankTransactions = 'bank_transactions';
  static const String tExpenses = 'expenses';
  static const String tReceipts = 'receipts';
  static const String tPayments = 'payments';
  static const String tEmployees = 'employees';
  static const String tSalaryRecords = 'salary_records';
  static const String tAttendance = 'attendance';
  static const String tTaxes = 'taxes';
  static const String tFiscalYears = 'fiscal_years';
  static const String tAccountingPeriods = 'accounting_periods';
  static const String tAuditLogs = 'audit_logs';
  static const String tSettings = 'settings';
  static const String tBackupMetadata = 'backup_metadata';
  static const String tBranchReports = 'branch_reports';
  static const String tAttendanceReports = 'attendance_reports';

  /// كل الـ Stores (لأغراض التصدير/الاستيراد)
  static const List<String> allStores = [
    tCompany,
    tUsers,
    tRoles,
    tPermissions,
    tCustomers,
    tSuppliers,
    tProducts,
    tProductCategories,
    tUnits,
    tWarehouses,
    tStock,
    tStockMovements,
    tBranches,
    tSales,
    tSaleItems,
    tPurchases,
    tPurchaseItems,
    tCashAccounts,
    tCashTransactions,
    tBankAccounts,
    tBankTransactions,
    tExpenses,
    tReceipts,
    tPayments,
    tEmployees,
    tSalaryRecords,
    tAttendance,
    tTaxes,
    tFiscalYears,
    tAccountingPeriods,
    tAuditLogs,
    tSettings,
    tBackupMetadata,
    tBranchReports,
    tAttendanceReports,
  ];

  // ==================== مفاتيح الإعدادات ====================
  static const String settingCompanyName = 'company_name';
  static const String settingCompanyAddress = 'company_address';
  static const String settingCompanyPhone = 'company_phone';

  /// هوية النظام/الفرع — ما يرسله التقرير للنظام الرئيسي
  static const String settingBranchCode = 'branch_code';
  static const String settingBranchName = 'branch_name';

  /// العملة الافتراضية للنظام
  static const String defaultCurrency = 'ريال';

  // ==================== الأدوار ====================
  static const String roleAdmin = 'admin';
  static const String roleAccountant = 'accountant';
  static const String roleSales = 'sales';
  static const String roleWarehouse = 'warehouse';

  static const List<String> roles = [
    roleAdmin,
    roleAccountant,
    roleSales,
    roleWarehouse,
  ];

  // ==================== أنواع الحسابات ====================
  static const String accAsset = 'asset';
  static const String accLiability = 'liability';
  static const String accEquity = 'equity';
  static const String accRevenue = 'revenue';
  static const String accExpense = 'expense';

  static const List<String> accountTypes = [
    accAsset,
    accLiability,
    accEquity,
    accRevenue,
    accExpense,
  ];

  // ==================== الجانب الطبيعي ====================
  static const String sideDebit = 'debit';
  static const String sideCredit = 'credit';

  // ==================== حالات الوثائق ====================
  static const String statusDraft = 'draft';
  static const String statusPosted = 'posted';
  static const String statusVoid = 'void';

  // ==================== أنواع حركات المخزون ====================
  static const String invPurchase = 'purchase';
  static const String invPurchaseReturn = 'purchase_return';
  static const String invSale = 'sale';
  static const String invSaleReturn = 'sale_return';
  static const String invDamaged = 'damaged';
  static const String invAdjustment = 'adjustment';

  // ==================== معاملات نقدية ====================
  static const String txIn = 'in';
  static const String txOut = 'out';

  // ==================== الافتراضي ====================
  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'admin123';
  static const String adminFullName = 'مدير النظام zuhair bn ibrahim alqahtani';
}
