import 'package:web/web.dart' as web;

/// فتح رابط نظام (فرع/أدمن) في نافذة تطبيق مستقلة من نفس الأصل —
/// تفتح دائماً أحدث نسخة من هذا التطبيق مع المعامل ?sys= الصحيح.
void openSystemWindow(String url) {
  web.window.open(url, '_blank');
}
