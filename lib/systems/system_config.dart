import 'package:flutter/foundation.dart';

import 'branch_profile.dart';
import 'branch_theme.dart';

/// تعريف الأنظمة داخل مشروع واحد.
///
/// كل نظام يُفتح عبر باراميتر `sys` في الرابط:
///   admin    → النظام الأساسي (التحكم الكامل بكل الفروع + استقبال التقارير تلقائياً)
///   branch1+ → فروع مُضافة ديناميكياً من تطبيق «إضافة فرع جديد» المربوط بالأدمن
///              (حتى 100 فرع — مثال: branch100)
///
/// لا توجد فروع ثابتة افتراضية — كل الفروع تُضاف من النظام الأساسي فقط
/// عبر تطبيق إضافة الفرع (الترقيم يبدأ من branch1/BR01).
/// كل نظام يقرأ ويكتب شجرة Firestore معزولة خاصة به داخل السحابة
/// (`accounting_systems/{systemId}`)، بينما تُرسل تقارير الفروع للنظام
/// الأساسي عبر المجموعة المشتركة `accounting_eod_reports` (وصول فوري).
class SystemConfig {
  SystemConfig._();

  static final SystemConfig instance = SystemConfig._();

  // ==================== معرّفات الأنظمة ====================
  static const String adminMode = 'admin';

  /// الحد الأقصى لعدد الفروع في المشروع كاملاً (100 فرع).
  static const int maxBranches = 100;

  /// لا توجد فروع ثابتة افتراضية — كل الفروع (حتى 100 فرع) تُضاف ديناميكياً
  /// من النظام الأساسي عبر «إضافة فرع جديد» (الترقيم يبدأ من branch1/BR01).
  static const List<String> fixedBranchModes = [];

  /// النظام الرئيسي فقط (الفروع تُدار ديناميكياً عبر سجل السحابة)
  static const List<String> modeIds = [
    adminMode,
    ...fixedBranchModes,
  ];

  /// فارغة افتراضياً — الفروع تُضاف ديناميكياً وتُدار عبر BranchRegistry
  static const List<String> branchModes = fixedBranchModes;

  /// الفروع الديناميكية المُضافة من النظام الأساسي (سجل السحابة)
  static final Map<String, BranchProfile> _dynamicProfiles = {};

  /// إعلام جاهزية إعدادات الفرع الديناميكي (شاشة الدخول تنتظره قبل فتح النموذج)
  static final ValueNotifier<bool> dynamicBranchReady =
      ValueNotifier<bool>(false);

  /// إعلام حذف الفرع الديناميكي الحالي من السجل (شاشة الدخول تعرض رسالة منع)
  static final ValueNotifier<bool> branchDeleted = ValueNotifier<bool>(false);

  /// إعلام تعذّر تحميل إعدادات الفرع (ضعف إنترنت لحظي) — شاشة الدخول
  /// تعرض إعادة المحاولة بدل شاشة دخول فارغة لا تعمل.
  static final ValueNotifier<bool> dynamicBranchFailed =
      ValueNotifier<bool>(false);

  /// الفروع المُضافة ديناميكياً من الأدمن
  static List<String> get allBranchModes =>
      [...branchModes, ..._dynamicProfiles.keys];

  /// كل الأنظمة: الأدمن + كل الفروع (الثابتة والديناميكية)
  static List<String> get allSystemModes =>
      [adminMode, ...branchModes, ..._dynamicProfiles.keys];

  /// تسجيل الفروع الديناميكية المحمّلة من السحابة/الكاش المحلي
  static void registerDynamicProfiles(List<BranchProfile> profiles) {
    _dynamicProfiles
      ..clear()
      ..addEntries(profiles.map((p) => MapEntry(p.id, p)));
  }

  /// عدد الفروع المسجلة حالياً (ثابتة + ديناميكية)
  static int get currentBranchCount =>
      branchModes.length + _dynamicProfiles.length;

  /// المتبقي من السعة قبل الوصول لـ 100 فرع
  static int get remainingBranchSlots => maxBranches - currentBranchCount;

  /// ملف تعريف فرع ديناميكي حسب معرفه (أو null إن لم يكن موجوداً)
  static BranchProfile? profileOf(String mode) => _dynamicProfiles[mode];

  String _mode = adminMode;

  /// معرف فرع ديناميكي قيد التحميل (مثل `branch6`) — فارغ للأنظمة الثابتة
  String _pendingDynamicId = '';

  String get pendingDynamicId => _pendingDynamicId;

  String get systemId => _mode;

  bool get isAdmin => _mode == adminMode;

  bool get isBranch => !isAdmin;

  /// تحديد النظام الحالي من الرابط (أو من العلامة المضمّنة داخل APK).
  ///
  /// الأولوية للمعامل `sys` — يدعم الصيغة الرمزية القصيرة للفروع
  /// (`?sys=v1` تعادل `?sys=branch1` وحتى `v100`) والصيغة الكاملة معاً،
  /// وإن غاب (تطبيق التلفون المثبّت) يُستخدم معرّف الفرع المضمّن في ذيل
  /// الـ APK، وإلا يُحدَّد النظام من رقم المنفذ (8080 → الأدمن).
  void init([Uri? base, String? embeddedMode]) {
    final uri = base ?? Uri.base;
    var arg = uri.queryParameters['sys']?.trim().toLowerCase();
    // تطبيق التلفون (APK): المعرف مضمّن في ذيل ملف التطبيق نفسه
    if ((arg == null || arg.isEmpty) &&
        embeddedMode != null &&
        embeddedMode.trim().isNotEmpty) {
      arg = embeddedMode.trim().toLowerCase();
    }
    if (arg != null && arg.isNotEmpty) {
      // الصيغة الرمزية: v1..v100 ← branch1..branch100 (روابط قصيرة للفروع)
      final vMatch = RegExp(r'^v(\d+)$').firstMatch(arg);
      if (vMatch != null) arg = 'branch${vMatch.group(1)}';
      _mode = arg;
      _pendingDynamicId = modeIds.contains(arg) ? '' : arg;
    } else {
      _mode = modeForPort(uri.hasPort ? uri.port : adminPort);
      _pendingDynamicId = '';
    }
    // إعادة ضبط إعلامات الحذف/الفشل عند فتح أي نظام
    branchDeleted.value = false;
    dynamicBranchFailed.value = false;
  }

  /// الاسم الظاهر للنظام
  String get systemLabel {
    final p = _dynamicProfiles[_mode];
    if (p != null) return p.name;
    return switch (_mode) {
      adminMode => 'النظام الأساسي (التحكم)',
      _ => 'فرع جديد',
    };
  }

  /// الوصف المختصر لعرضه في الواجهة
  String get systemRole => isAdmin
      ? 'يتحكم بجميع الأنظمة ويستقبل تقارير نهاية اليوم تلقائياً'
      : 'نظام منعزل — يرسل تقرير نهاية اليوم للنظام الأساسي';

  /// رمز الفرع الذي تُرسل به التقارير للنظام الأساسي
  String get branchCode => branchCodeOf(_mode);

  /// اسم الفرع الذي تُرسل به التقارير
  String get branchName => branchNameOf(_mode);

  /// بيانات تسجيل الدخول المعتمدة لكل نظام
  ({String username, String password}) get credentials => credentialsOf(_mode);

  /// الهوية اللونية والتصميمية للنظام (تختلف لكل فرع)
  BranchTheme get theme => themeOf(_mode);

  // ==================== بيانات الدخول لكل نظام ====================
  /// بيانات الدخول: الأدمن ثابتة، وكل فرع من ملف تعريفه الديناميكي فقط
  /// (الاسم/اليوزر/كلمة السر المُدخلة من الأدمن عند إنشاء الفرع) —
  /// لا توجد أي بيانات دخول فروع مضمّنة في الكود إطلاقاً.
  static ({String username, String password}) credentialsOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return (username: p.username, password: p.password);
    return switch (mode) {
      adminMode => (username: 'admin zuhair', password: '!Yemen.com0510'),
      _ => (username: '', password: ''),
    };
  }

  // ==================== أدوات مساعدة ثابتة ====================
  static BranchTheme themeOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.theme;
    return switch (mode) {
      adminMode => BranchTheme.admin,
      _ => BranchTheme.admin,
    };
  }

  static String branchCodeOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.code;
    return switch (mode) {
      adminMode => 'BR00',
      _ => 'BR--',
    };
  }

  static String branchNameOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.name;
    return switch (mode) {
      adminMode => 'المركز الرئيسي',
      _ => 'فرع جديد',
    };
  }

  static String databaseNameOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.dbName;
    return switch (mode) {
      adminMode => 'accounting_system',
      _ => 'accounting_system',
    };
  }

  // ==================== الفروع الديناميكية (حتى 100) ====================

  /// هل المعرّف معرف فرع صالح (branch1 .. branch100)؟
  static bool isBranchId(String mode) =>
      branchNumber(mode) != null && branchNumber(mode)! <= maxBranches;

  /// رقم الفرع من المعرّف (branch6 → 6) أو null إن لم يكن فرعاً
  static int? branchNumber(String mode) {
    if (!mode.startsWith('branch')) return null;
    return int.tryParse(mode.substring('branch'.length));
  }

  /// رابط السحابة الرسمي (يعمل من أي جهاز في أي مكان)
  static const String cloudBaseUrl = 'https://accountingsystem-fc3f0.web.app';

  /// الرابط السحابي لنظام/فرع معيّن — بصيغة رمزية قصيرة للفروع
  /// (`?sys=v1` للفرع الأول، `?sys=v2` للثاني...) بينما الأدمن `?sys=admin`.
  /// الصيغة الكاملة `?sys=branch1` تعمل أيضاً (توافق دائم مع الروابط القديمة).
  static String cloudUrlFor(String mode) {
    final n = branchNumber(mode);
    final key = (n != null && n >= 1 && n <= maxBranches) ? 'v$n' : mode;
    return '$cloudBaseUrl/?sys=$key';
  }

  // ==================== المنافذ ====================
  /// القاعدة: منفذ النظام الأساسي (الأدمن)
  static const int adminPort = 8080;

  /// رمز الفرع الديناميكي بالترقيم التسلسلي (branch5 → 5 ... branch100 → 100)
  static int? _branchNumberOrNull(String mode) => branchNumber(mode);

  /// تحديد النظام من رقم المنفذ.
  ///
  /// 8080 → الأدمن، 8080+N → فرع branchN (يغطي حتى 100 فرع = منفذ 8180).
  static String modeForPort(int port) {
    if (port == adminPort) return adminMode;
    final n = port - adminPort;
    if (n >= 1 && n <= maxBranches) return 'branch$n';
    return adminMode;
  }

  /// المنفذ المخصص لتشغيل نظام معيّن (فرع branchN ← منفذ 8080+N).
  static int portOf(String mode) {
    final n = _branchNumberOrNull(mode);
    if (n != null && n >= 1 && n <= maxBranches) return adminPort + n;
    return adminPort;
  }

  /// روابط الأنظمة (كل نظام بمنفذ مستقل للفتح في Chrome محلياً)
  static String urlFor(String mode, [Uri? base]) {
    final uri = base ?? Uri.base;
    final scheme = uri.hasScheme ? '${uri.scheme}://' : '';
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    return '$scheme$host:${portOf(mode)}/';
  }
}