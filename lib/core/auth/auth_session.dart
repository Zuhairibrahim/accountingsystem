import 'package:flutter/foundation.dart';

/// جلسة المصادقة — تُبقي حالة الدخول للجلسة الحالية في المتصفح.
class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  /// يعكس حالة الدخول (يستمع له الواجهة للتبديل بين شاشة الدخول والنظام)
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  bool get isLoggedIn => isAuthenticated.value;

  void login() => isAuthenticated.value = true;

  void logout() => isAuthenticated.value = false;
}