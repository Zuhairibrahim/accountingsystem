import 'dart:math' as math;

import 'package:intl/intl.dart';

/// أدوات تنسيق الأرقام والتواريخ
class Formatters {
  Formatters._();

  static final NumberFormat _number = NumberFormat('#,##0.00');

  static String currency(num value) => _number.format(value);

  static String dateOnly(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String displayDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  static double round(num v, [int digits = 2]) {
    final f = math.pow(10, digits).toDouble();
    return (v * f).roundToDouble() / f;
  }
}
