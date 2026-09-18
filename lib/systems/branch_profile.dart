import 'branch_theme.dart';

/// ملف تعريف فرع مُضاف ديناميكياً من خلال النظام الأساسي.
///
/// الأدمين يُدخل فقط: اسم الفرع + اسم المستخدم + كلمة السر.
/// باقي القيم (المعرف، الكود، قاعدة البيانات، التصميم) تُولَّد تلقائياً.
class BranchProfile {
  final String id; // مثال: branch5
  final String name; // مثال: فرع إب
  final String code; // مثال: BR11
  final String username;
  final String password;
  final String dbName; // مثال: accounting_system_branch5
  final int themeIndex; // لتدوير التصاميم المتاحة

  const BranchProfile({
    required this.id,
    required this.name,
    required this.code,
    required this.username,
    required this.password,
    required this.dbName,
    required this.themeIndex,
  });

  /// التصميم الخاص بالفرع (تصاميم محايدة، تُتداول تلقائياً).
  BranchTheme get theme {
    const themes = [
      BranchTheme.design1,
      BranchTheme.design2,
      BranchTheme.design3,
      BranchTheme.design4,
    ];
    return themes[themeIndex % themes.length];
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'username': username,
    'password': password,
    'dbName': dbName,
    'themeIndex': themeIndex,
    'createdAt': DateTime.now().toIso8601String(),
  };

  factory BranchProfile.fromJson(Map<String, Object?> json) {
    final index = (json['themeIndex'] as num?)?.toInt() ?? 0;
    return BranchProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      dbName: json['dbName']?.toString() ?? '',
      themeIndex: index,
    );
  }
}