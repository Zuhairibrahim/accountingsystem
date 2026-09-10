/// مرشّح استعلام مطابق لمنطق `Filter` السابق لكن بلا أي اعتماد على sembast.
///
/// يُستخدم مع `DatabaseService.find` و`DatabaseService.count` لتصفية السجلات
/// على Firestore — تُقيَّم الشروط في الذاكرة بعد جلب السجلات (نفس سلوك
/// القراءة السابقة داخل المتصفح)، وتدعم التجميع بـ `and`/`or` والتطابق
/// المنتظم `matches`.
class DbFilter {
  final DbFilterType type;
  final String? field;
  final Object? value;
  final List<DbFilter> children;

  const DbFilter._(
    this.type, {
    this.field,
    this.value,
    this.children = const [],
  });

  /// يساوي حقل قيمة محددة
  const DbFilter.equals(String field, Object? value)
      : this._(DbFilterType.equals, field: field, value: value);

  /// القيمة المخزنة أكبر من القيمة المعطاة
  const DbFilter.greaterThan(String field, Object value)
      : this._(DbFilterType.greaterThan, field: field, value: value);

  /// القيمة المخزنة أصغر من القيمة المعطاة
  const DbFilter.lessThan(String field, Object value)
      : this._(DbFilterType.lessThan, field: field, value: value);

  /// الحقل قائمة تحتوي على القيمة المعطاة
  const DbFilter.arrayContains(String field, Object value)
      : this._(DbFilterType.arrayContains, field: field, value: value);

  /// تطابق النمط المنتظم على التمثيل النصي للحقل
  const DbFilter.matches(String field, String pattern)
      : this._(DbFilterType.matches, field: field, value: pattern);

  /// كل الشروط يجب أن تنطبق
  const DbFilter.and(List<DbFilter> children)
      : this._(DbFilterType.and, children: children);

  /// أحد الشروط على الأقل يجب أن ينطبق
  const DbFilter.or(List<DbFilter> children)
      : this._(DbFilterType.or, children: children);

  /// هل يقبل السجل هذا المرشّح؟
  bool accepts(Map<String, Object?> record) {
    switch (type) {
      case DbFilterType.equals:
        return _equals(record[field], value);
      case DbFilterType.greaterThan:
        return _compare(record[field], value) > 0;
      case DbFilterType.lessThan:
        return _compare(record[field], value) < 0;
      case DbFilterType.arrayContains:
        final list = record[field];
        if (list is! List) return false;
        return list.any((e) => _equals(e, value));
      case DbFilterType.matches:
        final text = record[field]?.toString() ?? '';
        return RegExp(value.toString()).hasMatch(text);
      case DbFilterType.and:
        return children.every((f) => f.accepts(record));
      case DbFilterType.or:
        return children.any((f) => f.accepts(record));
    }
  }

  static Object? _normalize(Object? v) {
    if (v is DateTime) {
      return v.toIso8601String();
    }
    return v;
  }

  static bool _equals(Object? a, Object? b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na is num && nb is num) return na == nb;
    return na == nb;
  }

  static int _compare(Object? a, Object? b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na is num && nb is num) return na.compareTo(nb);
    if (na is String && nb is String) return na.compareTo(nb);
    return '${na ?? ''}'.compareTo('${nb ?? ''}');
  }
}

enum DbFilterType {
  equals,
  greaterThan,
  lessThan,
  arrayContains,
  matches,
  and,
  or,
}