import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../systems/system_config.dart';
import '../constants/app_constants.dart';
import 'database_service.dart';
import 'db_filter.dart';

/// البيانات الأولية عند أول تشغيل (تُنفَّذ مرة واحدة لكل نظام).
///
/// كل النظام/فرع يملك شجرة معزولة داخل Firestore حسب `systemId` —
/// لهذا تُعاد التهيئة لكل نظام على حدة وبشكل آمن (تُفحص العدد قبل الإدراج).
class DatabaseSeed {
  DatabaseSeed._();

  static final DatabaseSeed instance = DatabaseSeed._();

  Future<void> ensureSeed() async {
    final svc = DatabaseService.instance;

    // نظام جديد (شجرة فارغة): تصفير العدّادات ليبدأ العد من صفر في هذا الإصدار.
    final fresh = await svc.count(AppConstants.tSettings) == 0;
    if (fresh) {
      await svc.resetCounters();
    }

    // ===== الإعدادات =====
    if (await svc.count(AppConstants.tSettings) == 0) {
      await svc.insert(AppConstants.tSettings, {
        'key': 'company_name',
        'value': SystemConfig.instance.systemLabel,
      });
      await svc.insert(AppConstants.tSettings, {
        'key': 'company_address',
        'value': '',
      });
      await svc.insert(AppConstants.tSettings, {
        'key': 'company_phone',
        'value': '',
      });
    }

    // ===== هوية النظام/الفرع (تُضاف إن لم تكن موجودة فقط) =====
    final identity = {
      AppConstants.settingBranchCode: SystemConfig.instance.branchCode,
      AppConstants.settingBranchName: SystemConfig.instance.branchName,
    };
    for (final entry in identity.entries) {
      final existing = await svc.find(
        AppConstants.tSettings,
        filter: DbFilter.equals('key', entry.key),
      );
      if (existing.isEmpty) {
        await svc.insert(AppConstants.tSettings, {
          'key': entry.key,
          'value': entry.value,
        });
      }
    }

    // ===== الأدوار =====
    if (await svc.count(AppConstants.tRoles) == 0) {
      for (final role in AppConstants.roles) {
        await svc.insert(AppConstants.tRoles, {
          'name': _roleName(role),
        });
      }
    }

    // ===== المستخدم الافتراضي =====
    if (await svc.count(AppConstants.tUsers) == 0) {
      final hash = sha256
          .convert(utf8.encode(AppConstants.defaultAdminPassword))
          .toString();
      await svc.insert(AppConstants.tUsers, {
        'username': AppConstants.defaultAdminUsername,
        'password_hash': hash,
        'full_name': AppConstants.adminFullName,
        'role': AppConstants.roleAdmin,
        'is_active': true,
      });
    } else {
      // تثبيت الاسم الكامل للمدير عند كل تشغيل
      final admins = await svc.find(
        AppConstants.tUsers,
        filter: DbFilter.equals(
          'username',
          AppConstants.defaultAdminUsername,
        ),
      );
      if (admins.isNotEmpty) {
        await svc.update(
          AppConstants.tUsers,
          admins.first['id'] as int,
          {'full_name': AppConstants.adminFullName},
        );
      }
    }

    // ===== الضرائب =====
    if (await svc.count(AppConstants.tTaxes) == 0) {
      await svc.insert(AppConstants.tTaxes, {
        'name': 'ضريبة القيمة المضافة',
        'rate': 15.0,
        'is_active': true,
      });
    }

    // ===== الوحدات =====
    if (await svc.count(AppConstants.tUnits) == 0) {
      await svc.insert(AppConstants.tUnits, {'name': 'قطعة'});
      await svc.insert(AppConstants.tUnits, {'name': 'علبة'});
    }

    // ===== الفروع (منعزل لكل نظام) =====
    if (await svc.count(AppConstants.tBranches) == 0) {
      if (SystemConfig.instance.isBranch) {
        // نظام فرع: فرع واحد فقط = هوية النظام نفسه
        await svc.insert(AppConstants.tBranches, {
          'code': SystemConfig.instance.branchCode,
          'name': SystemConfig.instance.branchName,
          'governorate':
              SystemConfig.instance.branchName.replaceFirst('فرع ', 'محافظة '),
          'phone': '',
          'address': '',
          'manager': 'مدير الفرع',
          'is_default': true,
        });
      } else {
        // النظام الرئيسي: الفروع الأربعة الثابتة (نفس الأنظمة الحقيقية)
        const branches = [
          (code: 'BR01', name: 'فرع صنعاء'),
          (code: 'BR02', name: 'فرع عدن'),
          (code: 'BR03', name: 'فرع تعز'),
          (code: 'BR04', name: 'فرع الحديدة'),
        ];
        for (var i = 0; i < branches.length; i++) {
          await svc.insert(AppConstants.tBranches, {
            'code': branches[i].code,
            'name': branches[i].name,
            'governorate': branches[i].name.replaceFirst('فرع ', 'محافظة '),
            'phone': '',
            'address': '',
            'manager': 'مدير الفرع',
            'is_default': i == 0,
          });
        }
      }
    }

    // ===== المستودع الرئيسي =====
    if (await svc.count(AppConstants.tWarehouses) == 0) {
      await svc.insert(AppConstants.tWarehouses, {
        'name': 'المستودع الرئيسي',
      });
    }

    // ===== الصندوق الرئيسي =====
    if (await svc.count(AppConstants.tCashAccounts) == 0) {
      await svc.insert(AppConstants.tCashAccounts, {
        'name': 'الصندوق الرئيسي',
        'account_id': null,
        'balance': 0.0,
        'is_default': true,
      });
    }
  }

  static String _roleName(String role) => switch (role) {
    AppConstants.roleAdmin => 'مدير',
    AppConstants.roleAccountant => 'محاسب',
    AppConstants.roleSales => 'موظف مبيعات',
    AppConstants.roleWarehouse => 'أمين مستودع',
    _ => role,
  };
}