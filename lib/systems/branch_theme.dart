import 'package:flutter/material.dart';

/// هوية كل فرع في شاشة تسجيل الدخول والواجهة.
class BranchTheme {
  final Color accent;
  final Color button;
  final List<Color> panelGradient;
  final IconData icon;

  const BranchTheme({
    required this.accent,
    required this.button,
    required this.panelGradient,
    required this.icon,
  });

  /// تصميم النظام الأساسي (ذهبي داكن)
  static const BranchTheme admin = BranchTheme(
    accent: Color(0xFFD98E04),
    button: Color(0xFFB45309),
    panelGradient: [Color(0xFF1C1917), Color(0xFF44403C), Color(0xFF292524)],
    icon: Icons.admin_panel_settings,
  );

  /// فرع صنعاء — بنفسجي
  static const BranchTheme sanaa = BranchTheme(
    accent: Color(0xFF7C3AED),
    button: Color(0xFF6D28D9),
    panelGradient: [
      Color(0xFF1E1B4B),
      Color(0xFF6D28D9),
      Color(0xFF241A33),
    ],
    icon: Icons.storefront,
  );

  /// فرع عدن — فيروزي (بلحري)
  static const BranchTheme aden = BranchTheme(
    accent: Color(0xFF0D9488),
    button: Color(0xFF0F766E),
    panelGradient: [
      Color(0xFF042F2E),
      Color(0xFF0D9488),
      Color(0xFF0A2A29),
    ],
    icon: Icons.storefront,
  );

  /// فرع تعز — أخضر (جبل)
  static const BranchTheme taiz = BranchTheme(
    accent: Color(0xFF16A34A),
    button: Color(0xFF15803D),
    panelGradient: [
      Color(0xFF052E16),
      Color(0xFF16A34A),
      Color(0xFF102B1C),
    ],
    icon: Icons.storefront,
  );

  /// فرع الحديدة — برتقالي (ميناء)
  static const BranchTheme hudaydah = BranchTheme(
    accent: Color(0xFFEA580C),
    button: Color(0xFFC2410C),
    panelGradient: [
      Color(0xFF431407),
      Color(0xFFEA580C),
      Color(0xFF3E1A12),
    ],
    icon: Icons.storefront,
  );

  /// فرع ذمار — أزرق (المرتفعات)
  static const BranchTheme dhamar = BranchTheme(
    accent: Color(0xFF0369A1),
    button: Color(0xFF075985),
    panelGradient: [
      Color(0xFF082F49),
      Color(0xFF0369A1),
      Color(0xFF082940),
    ],
    icon: Icons.storefront,
  );
}