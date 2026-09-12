import 'package:web/web.dart' as web;

/// فتح رابط في نفس التبويب (الويب فقط).
void openLink(String url) {
  web.window.location.href = url;
}