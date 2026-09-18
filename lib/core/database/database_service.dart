import 'package:cloud_firestore/cloud_firestore.dart';

import '../../systems/system_config.dart';
import '../constants/app_constants.dart';
import 'db_filter.dart';

/// طبقة الوصول المركزية للبيانات — كلها داخل Firestore (سحابة Firebase).
///
/// لا توجد أي قاعدة بيانات محلية: كل نظام (أدمن / فرع) يقرأ ويكتب
/// شجرة معزولة خاصة به داخل السحابة عبر `accounting_systems/{systemId}`.
///
/// المفاتيح: عدّاد متسلسل لكل Store يبدأ من 1 (تُصفَّر العدّادات في هذا
/// الإصدار)، وخرّى كل سجل يحمل `id` (المفتاح) مع بياناته.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  /// وثيقة جذر النظام الحالي (حسب `?sys=`)
  static DocumentReference<Map<String, dynamic>> systemDoc() =>
      FirebaseFirestore.instance
          .collection('accounting_systems')
          .doc(SystemConfig.instance.systemId);

  /// مرجع مجموعة سجلات Store معيّن (سجلات store داخل النظام الحالي)
  static CollectionReference<Map<String, dynamic>> store(String storeName) =>
      systemDoc().collection('stores').doc(storeName).collection('records');

  /// مرجع عدّاد المفاتيح المتسلسل لـ Store معيّن
  static DocumentReference<Map<String, dynamic>> counterRef(String storeName) =>
      systemDoc().collection('counters').doc(storeName);

  // ==================== إضافة ====================
  /// إضافة سجل ويعيد المفتاح المتسلسل الجديد
  Future<int> insert(String storeName, Map<String, Object?> data) async {
    final key = await _nextKey(storeName);
    await _write(storeName, key, data, replace: true);
    return key;
  }

  /// إضافة بسرعة: بيانات بلا مفتاح (يُحجز مفتاح متسلسل)
  Future<int> nextKey(String storeName) => insert(storeName, const {});

  // ==================== تحديث ====================
  /// دمج الحقول الممررة مع السجل الموجود
  Future<void> update(
    String storeName,
    int key,
    Map<String, Object?> data,
  ) async {
    await _write(storeName, key, data, replace: false);
  }

  /// استبدال قيمة السجل كاملة (إنشاؤه إن لم يوجد)
  Future<void> upsert(
    String storeName,
    int key,
    Map<String, Object?> data,
  ) async {
    await _write(storeName, key, data, replace: true);
  }

  // ==================== قراءة ====================
  Future<Map<String, Object?>?> get(String storeName, int key) async {
    final doc = await store(storeName).doc('$key').get();
    if (!doc.exists) return null;
    return _fromFirestore(doc.data()!, doc.id);
  }

  /// كل السجلات مع إمكانية الفرز بواحد أو أكثر من الحقول وأخذ عدد محدود
  Future<List<Map<String, Object?>>> getAll(
    String storeName, {
    List<String>? sortAsc,
    List<String>? sortDesc,
    int? limit,
  }) async {
    final rows = await _fetchAll(storeName);
    return _sortRows(rows, sortAsc, sortDesc, limit);
  }

  /// بحث بشرط `DbFilter` مع الفرز والتقسيم
  Future<List<Map<String, Object?>>> find(
    String storeName, {
    DbFilter? filter,
    List<String>? sortAsc,
    List<String>? sortDesc,
    int? limit,
    int? offset,
  }) async {
    var rows = await _fetchAll(storeName);
    if (filter != null) {
      rows = rows.where(filter.accepts).toList();
    }
    rows = _sortRows(rows, sortAsc, sortDesc, null);
    if (offset != null && offset > 0) {
      rows = offset >= rows.length ? const [] : rows.sublist(offset);
    }
    if (limit != null && rows.length > limit) rows = rows.sublist(0, limit);
    return rows;
  }

  /// عدد السجلات في Store (مع مرشّح اختياري)
  Future<int> count(String storeName, {DbFilter? filter}) async {
    var rows = await _fetchAll(storeName);
    if (filter != null) {
      rows = rows.where(filter.accepts).toList();
    }
    return rows.length;
  }

  // ==================== حذف ====================
  Future<void> delete(String storeName, int key) async {
    await store(storeName).doc('$key').delete();
  }

  /// مسح كل السجلات في Store (عبر دفعات كتابة)
  Future<void> clear(String storeName) async {
    final snap = await store(storeName).get();
    final fs = FirebaseFirestore.instance;
    WriteBatch? batch;
    var size = 0;
    for (final d in snap.docs) {
      if (batch == null || size >= 450) {
        batch = fs.batch();
        size = 0;
        await batch.commit();
        batch = fs.batch();
      }
      batch.delete(d.reference);
      size++;
    }
    if (batch != null && size > 0) {
      await batch.commit();
    }
  }

  // ==================== معاملات ====================
  /// تنفيذ عدة عمليات داخل معاملة واحدة (نفس بنية الـ API القديم بدون قاعدة محلية)
  Future<T> transaction<T>(Future<T> Function() action) => action();

  // ==================== لوحة التحكم ====================
  /// حساب الإحصائيات والأرقام الحية للوحة التحكم من قاعدة البيانات الحقيقية
  /// (كل القراءات بالتوازي — أسرع تنفيذ بدون أي انتظار متسلسل)
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final res = await Future.wait<dynamic>([
      getAll(AppConstants.tSales),
      getAll(AppConstants.tPurchases),
      count(AppConstants.tCustomers),
      count(AppConstants.tSuppliers),
      getAll(AppConstants.tProducts),
      getAll(AppConstants.tBankAccounts),
      getAll(AppConstants.tCashAccounts),
    ]);
    final sales = res[0] as List<Map<String, Object?>>;
    final purchases = res[1] as List<Map<String, Object?>>;
    final customers = res[2] as int;
    final suppliers = res[3] as int;
    final products = res[4] as List<Map<String, Object?>>;
    final bankRows = res[5] as List<Map<String, Object?>>;
    final cashRows = res[6] as List<Map<String, Object?>>;

    var totalSales = 0.0;
    var totalPurchases = 0.0;
    var inventoryVal = 0.0;
    var bankBalance = 0.0;
    var cashBalance = 0.0;
    var outstandingCount = 0;

    for (final val in sales) {
      if (val['type'] == 'sale' || val['type'] == null) {
        totalSales += (val['amount'] as num? ?? 0).toDouble();
      }
      final status = val['status']?.toString() ?? '';
      if (status == 'جزئية' || status == 'غير مدفوعة') {
        outstandingCount += 1;
      }
    }

    for (final val in purchases) {
      if (val['type'] == 'purchase' || val['type'] == null) {
        totalPurchases += (val['amount'] as num? ?? 0).toDouble();
      }
    }

    for (final val in products) {
      final cost = (val['price'] as num? ?? 0).toDouble();
      final qty = (val['stock_qty'] as num? ?? 0).toDouble();
      inventoryVal += cost * qty;
    }

    for (final val in bankRows) {
      bankBalance += (val['balance'] as num? ?? 0).toDouble();
    }
    for (final val in cashRows) {
      cashBalance += (val['balance'] as num? ?? 0).toDouble();
    }

    return {
      'net_profit': totalSales - totalPurchases,
      'bank_balance': bankBalance,
      'cash_balance': cashBalance,
      'total_purchases': totalPurchases,
      'total_sales': totalSales,
      'customers_count': customers,
      'suppliers_count': suppliers,
      'products_count': products.length,
      'inventory_value': inventoryVal,
      'outstanding_invoices': outstandingCount,
    };
  }

  // ==================== أرقام تسلسلية ====================
  /// يُنتج رقماً تسلسلياً بصيغة PREFIX-000001 بإحصاء السجلات
  Future<String> nextSerial(
    String storeName,
    String prefix, {
    String field = 'no',
  }) async {
    final rows = await find(
      storeName,
      filter: DbFilter.matches(field, '^$prefix-'),
    );
    return '$prefix-${(rows.length + 1).toString().padLeft(6, '0')}';
  }

  // ==================== داخلي ====================
  Future<int> _nextKey(String storeName) async {
    final ref = counterRef(storeName);
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final next = (snap.data()?['next'] as int? ?? 0) + 1;
      tx.set(ref, {'next': next}, SetOptions(merge: true));
      return next;
    });
  }

  /// تصفير كل العدّادات في هذا النظام — يُستدعى فقط عند أول تشغيل لنظام جديد
  /// (شجرة فارغة) حتى يبدأ العد من صفر في هذا الإصدار بلا أي تعارض مع بيانات قائمة.
  Future<void> resetCounters() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final name in AppConstants.allStores) {
      batch.set(counterRef(name), {'next': 0}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _write(
    String storeName,
    int key,
    Map<String, Object?> data, {
    required bool replace,
  }) async {
    final doc = store(storeName).doc('$key');
    final payload = _sanitize(<String, Object?>{...data, 'id': key});
    await doc.set(payload, SetOptions(merge: !replace));
  }

  Future<List<Map<String, Object?>>> _fetchAll(String storeName) async {
    final snap = await store(storeName).get();
    return [
      for (final d in snap.docs) _fromFirestore(d.data(), d.id),
    ];
  }

  List<Map<String, Object?>> _sortRows(
    List<Map<String, Object?>> rows,
    List<String>? sortAsc,
    List<String>? sortDesc,
    int? limit,
  ) {
    var list = rows;
    if (sortAsc != null || sortDesc != null) {
      list = [...rows]..sort((a, b) {
          for (final f in sortDesc ?? const <String>[]) {
            final c = _compareValues(a[f], b[f]);
            if (c != 0) return -c;
          }
          for (final f in sortAsc ?? const <String>[]) {
            final c = _compareValues(a[f], b[f]);
            if (c != 0) return c;
          }
          return 0;
        });
    }
    if (limit != null && list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  int _compareValues(Object? a, Object? b) {
    if (a is num && b is num) return a.compareTo(b);
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    return '${a ?? ''}'.compareTo('${b ?? ''}');
  }

  /// تنظيف القيم قبل الرفع (Firestore يرفض المفاتيح الفارغة وبعض الأنواع)
  static Map<String, Object?> _sanitize(Map<String, Object?> map) {
    final out = <String, Object?>{};
    for (final e in map.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is DateTime) {
        out[e.key] = Timestamp.fromDate(v);
      } else if (v is Map) {
        final clean = _sanitize(Map<String, Object?>.from(v));
        if (clean.isNotEmpty) out[e.key] = clean;
      } else if (v is List) {
        out[e.key] = v.map((x) {
          if (x is Map) return _sanitize(Map<String, Object?>.from(x));
          return x;
        }).where((x) => x != null).toList();
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }

  /// استرجاع قيم Firestore (Timestamp → DateTime) مع إلحاق المفتاح `id`
  static Map<String, Object?> _fromFirestore(
    Map<String, dynamic> raw,
    String docKey,
  ) {
    final data = <String, Object?>{...raw};
    final key = int.tryParse(docKey) ?? raw['id'];
    return <String, Object?>{
      for (final e in data.entries) e.key: _restore(e.value),
      'id': key,
    };
  }

  static Object? _restore(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is Map) {
      return {
        for (final e in v.entries) e.key: _restore(e.value),
      };
    }
    if (v is List) return v.map(_restore).toList();
    return v;
  }
}