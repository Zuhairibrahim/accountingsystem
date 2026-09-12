/// إعدادات الإعلانات — أرقام وحدات Google AdMob الحقيقية.
class AdConstants {
  AdConstants._();

  /// معرف تطبيق AdMob (App ID).
  static const String appId = 'ca-app-pub-1396394529471927~8735159738';

  /// وحدة البانر (Banner) — تظهر أسفل التطبيق بشكل دائم.
  static const String bannerAdUnitId = 'ca-app-pub-1396394529471927/3333780274';

  /// وحدة الإعلان البيني (Interstitial) — تظهر عند إتمام المهام (بيع/تقرير).
  static const String interstitialAdUnitId =
      'ca-app-pub-1396394529471927/7756241011';

  /// الفاصل الزمني الأدنى بين ظهور الإعلان البيني بالثواني.
  ///
  /// هذا الحد يضمن التكرار الجيد للإعلانات مع البقاء ضمن سياسة Google
  /// (لا إعلانات متراكمة مباشرة، ولا إعلان مع إطلاق التطبيق).
  static const int interstitialMinIntervalSeconds = 60;
}