import 'package:flutter/foundation.dart';

import 'branch_profile.dart';
import 'branch_theme.dart';

/// تعريف الأنظمة داخل مشروع واحد.
///
/// كل نظام يُفتح عبر باراميتر `sys` في الرابط:
///   admin    → النظام الأساسي (التحكم الكامل بكل الفروع + استقبال التقارير تلقائياً)
///   branch1  → فرع صنعاء (افتراضي ثابت)
///   branch2  → فرع عدن (افتراضي ثابت)
///   branch3  → فرع تعز (افتراضي ثابت)
///   branch4  → فرع الحديدة (افتراضي ثابت)
///   branch5+ → فروع مُضافة ديناميكياً من تطبيق «إضافة فرع جديد» المربوط بالأدمن
///              (حتى 50 فرعاً — مثال: branch50)
///
/// الفروع الأربعة الثابتة تُنشأ مع نظام الأدمن مباشرة (النظام الخامس)،
/// ومن النظام السادس يبدأ إضافة الفروع عبر تطبيق إضافة الفرع الخاص بالأدمن.
/// كل نظام يقرأ ويكتب شجرة Firestore معزولة خاصة به داخل السحابة
/// (`accounting_systems/{systemId}`)، بينما تُرسل تقارير الفروع للنظام
/// الأساسي عبر المجموعة المشتركة `accounting_eod_reports` (وصول فوري).
class SystemConfig {
  SystemConfig._();

  static final SystemConfig instance = SystemConfig._();

  // ==================== معرّفات الأنظمة ====================
  static const String adminMode = 'admin';
  static const String branch1Mode = 'branch1';
  static const String branch2Mode = 'branch2';
  static const String branch3Mode = 'branch3';
  static const String branch4Mode = 'branch4';

  /// معرف فرع ذمار (سابقاً فرع خامس ثابت) — أصبح فرعاً مُضافاً ديناميكياً
  /// يحتفظ برمزه وبياناته السابقة، وهو أول فرع يُضاف عبر تطبيق إضافة الفرع.
  static const String branch5Mode = 'branch5';

  /// الحد الأقصى لعدد الفروع في المشروع كاملاً (50 فرعاً).
  static const int maxBranches = 50;

  /// الفروع الثابتة الافتراضية (أربعة فروع تُنشأ مع نظام الأدمن).
  static const List<String> fixedBranchModes = [
    branch1Mode,
    branch2Mode,
    branch3Mode,
    branch4Mode,
  ];

  /// الأنظمة المرسِلة + النظام الرئيسي المستلم (الأنظمة الثابتة فقط)
  static const List<String> modeIds = [
    adminMode,
    ...fixedBranchModes,
  ];

  /// الأنظمة المرسلة فقط (الفروع الثابتة)
  static const List<String> branchModes = fixedBranchModes;

  /// الفروع الديناميكية المُضافة من النظام الأساسي (سجل السحابة)
  static final Map<String, BranchProfile> _dynamicProfiles = {};

  /// إعلام جاهزية إعدادات الفرع الديناميكي (شاشة الدخول تنتظره قبل فتح النموذج)
  static final ValueNotifier<bool> dynamicBranchReady =
      ValueNotifier<bool>(false);

  /// إعلام حذف الفرع الديناميكي الحالي من السجل (شاشة الدخول تعرض رسالة منع)
  static final ValueNotifier<bool> branchDeleted = ValueNotifier<bool>(false);

  /// الفروع المرسلة: الثابتة الأربعة + الديناميكية المُضافة من الأدمن
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

  /// المتبقي من السعة قبل الوصول لـ 50 فرعاً
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

  /// تحديد النظام الحالي من الرابط.
  ///
  /// الأولوية للمعامل `sys` (مثل `?sys=branch1`) — ويدعم أيضاً الفروع
  /// الديناميكية المضافة من الأدمن مثل `?sys=branch6`, وإلا يُحدَّد النظام
  /// من رقم المنفذ (8080 → الأدمن، و8080+N → فرع branchN).
  void init([Uri? base]) {
    final uri = base ?? Uri.base;
    final arg = uri.queryParameters['sys']?.trim().toLowerCase();
    if (arg != null && arg.isNotEmpty) {
      _mode = arg;
      _pendingDynamicId = modeIds.contains(arg) ? '' : arg;
    } else {
      _mode = modeForPort(uri.hasPort ? uri.port : adminPort);
      _pendingDynamicId = '';
    }
    // إعادة ضبط إعلام الحذف عند فتح أي نظام
    branchDeleted.value = false;
  }

  /// الاسم الظاهر للنظام
  String get systemLabel {
    final p = _dynamicProfiles[_mode];
    if (p != null) return p.name;
    return switch (_mode) {
      adminMode => 'النظام الأساسي (التحكم)',
      branch1Mode => 'فرع صنعاء',
      branch2Mode => 'فرع عدن',
      branch3Mode => 'فرع تعز',
      branch4Mode => 'فرع الحديدة',
      branch5Mode => 'فرع ذمار',
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
  static ({String username, String password}) credentialsOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return (username: p.username, password: p.password);
    return switch (mode) {
      adminMode => (username: 'admin zuhair', password: '!Yemen.com0510'),
      branch1Mode => (username: 'ad1', password: '1254'),
      branch2Mode => (username: 'ad2', password: '1254'),
      branch3Mode => (username: 'ad3', password: '1254'),
      branch4Mode => (username: 'ad4', password: '1254'),
      branch5Mode => (username: 'ad5', password: '1254'),
      _ => (username: 'admin zuhair', password: '!Yemen.com0510'),
    };
  }

  // ==================== أدوات مساعدة ثابتة ====================
  static BranchTheme themeOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.theme;
    return switch (mode) {
      branch1Mode => BranchTheme.sanaa,
      branch2Mode => BranchTheme.aden,
      branch3Mode => BranchTheme.taiz,
      branch4Mode => BranchTheme.hudaydah,
      branch5Mode => BranchTheme.dhamar,
      _ => BranchTheme.admin,
    };
  }

  static String branchCodeOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.code;
    return switch (mode) {
      branch1Mode => 'BR01',
      branch2Mode => 'BR02',
      branch3Mode => 'BR03',
      branch4Mode => 'BR04',
      branch5Mode => 'BR05',
      _ => 'BR00',
    };
  }

  static String branchNameOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.name;
    return switch (mode) {
      branch1Mode => 'فرع صنعاء',
      branch2Mode => 'فرع عدن',
      branch3Mode => 'فرع تعز',
      branch4Mode => 'فرع الحديدة',
      branch5Mode => 'فرع ذمار',
      _ => 'المركز الرئيسي',
    };
  }

  static String databaseNameOf(String mode) {
    final p = _dynamicProfiles[mode];
    if (p != null) return p.dbName;
    return switch (mode) {
      branch1Mode => 'accounting_system_branch1',
      branch2Mode => 'accounting_system_branch2',
      branch3Mode => 'accounting_system_branch3',
      branch4Mode => 'accounting_system_branch4',
      branch5Mode => 'accounting_system_branch5',
      _ => 'accounting_system',
    };
  }

  // ==================== الفروع الديناميكية (حتى 50) ====================

  /// هل المعرّف معرف فرع صالح (branch1 .. branch50)؟
  static bool isBranchId(String mode) =>
      branchNumber(mode) != null && branchNumber(mode)! <= maxBranches;

  /// رقم الفرع من المعرّف (branch6 → 6) أو null إن لم يكن فرعاً
  static int? branchNumber(String mode) {
    if (!mode.startsWith('branch')) return null;
    return int.tryParse(mode.substring('branch'.length));
  }

  /// رابط السحابة الرسمي (يعمل من أي جهاز في أي مكان)
  static const String cloudBaseUrl = 'https://accountingsystem-fc3f0.web.app';

  /// الرابط السحابي لنظام/فرع معيّن
  static String cloudUrlFor(String mode) => '$cloudBaseUrl/?sys=$mode';

  /// عنوان صندوق البريد المحلي الذي يستقبل تقارير الفروع ويسلّمها للنظام الأساسي.
  ///
  /// يُحسب ديناميكياً من مضيف النافذة الحالية مع منفذ النظام الأساسي (8080)
  /// حتى يعمل تلقائياً من الجهاز نفسه (localhost) ومن الهاتف عبر الشبكة
  /// المحلية (192.168.x.x). يمكن تجاوزه عبر RELAY_BASE عند الحاجة.
  static String get localRelayBase {
    const override = String.fromEnvironment('RELAY_BASE');
    if (override.isNotEmpty) return override;
    final uri = Uri.base;
    final scheme = uri.hasScheme ? uri.scheme : 'http';
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    return '$scheme://$host:$adminPort';
  }

  // ==================== المنافذ ====================
  /// القاعدة: منفذ النظام الأساسي (الأدمن)
  static const int adminPort = 8080;

  /// منافذ الفروع الثابتة الأربعة
  static const int branch1Port = 8081;
  static const int branch2Port = 8082;
  static const int branch3Port = 8083;
  static const int branch4Port = 8084;

  /// رمز الفرع الديناميكي بالترقيم التسلسلي (branch5 → 5 ... branch50 → 50)
  static int? _branchNumberOrNull(String mode) => branchNumber(mode);

  /// تحديد النظام من رقم المنفذ.
  ///
  /// 8080 → الأدمن، 8080+N → فرع branchN (يغطي حتى 50 فرعاً = منفذ 8130).
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