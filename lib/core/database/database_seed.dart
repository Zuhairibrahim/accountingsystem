import '../../systems/system_config.dart';
import '../constants/app_constants.dart';
import 'database_service.dart';

/// تهيئة أولية لنظام جديد — بدون أي بيانات افتراضية.
///
/// النظام يبدأ فارغاً تماماً: المستخدم يُدخل كل شيء يدوياً
/// (الأدوار، المستخدمين، الضرائب، الوحدات، المستودعات، الصناديق، الفروع).
/// التهيئة تكتفي بتصفير العدّادات وكتابة هوية النظام غير المرئية
/// (اسم الفرع وكوده) التي يقرأها التقرير فقط.
class DatabaseSeed {
  DatabaseSeed._();

  static final DatabaseSeed instance = DatabaseSeed._();

  Future<void> ensureSeed() async {
    final svc = DatabaseService.instance;
    final sys = SystemConfig.instance;

    final settings = await svc.getAll(AppConstants.tSettings);

    // نظام جديد (شجرة فارغة): تصفير العدّادات ليبدأ العد من صفر — لا شيء غير ذلك
    if (settings.isEmpty) {
      await svc.resetCounters();
    }

    Map<String, Object?>? rowOf(String key) {
      for (final s in settings) {
        if (s['key'] == key) return s;
      }
      return null;
    }

    // ===== هوية النظام (إعدادات غير مرئية — يقرأها التقرير والتقارير المرسلة) =====
    // تُضاف إن لم تكن موجودة (بيانات الفرع الديناميكي المحمّلة من السجل).
    final identity = <String, String>{
      AppConstants.settingCompanyName: sys.systemLabel,
      AppConstants.settingBranchCode: sys.branchCode,
      AppConstants.settingBranchName: sys.branchName,
    };
    for (final entry in identity.entries) {
      final row = rowOf(entry.key);
      if (row == null) {
        await svc.insert(AppConstants.tSettings, {
          'key': entry.key,
          'value': entry.value,
        });
      }
    }
  }
}
