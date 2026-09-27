import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/firebase/firebase_bootstrap.dart';
import 'branch_profile.dart';
import 'system_config.dart';

/// سجل الفروع الديناميكية التي يُنشئها النظام الأساسي في السحابة
/// (حتى 100 فرع — حسب SystemConfig.maxBranches).
///
/// المرجع الوحيد والأخير هو مجموعة `accounting_branches` في Firestore —
/// لا يوجد أي تخزين محلي أو كاش إطلاقاً: كل قراءة وكل كتابة عبر Firebase
/// مباشرة حتى لا تحدث أي خلط بين بيانات الفروع أبداً.
///
/// - الأدمين يُدخل فقط: اسم الفرع + اسم المستخدم + كلمة السر
/// - كود الفرع يُولَّد تلقائياً من آخر كود محفوظ (مثال: آخر BR10 ← الجديد BR11)
/// - المعرف (`branch1`, `branch2`... حتى `branch100`) وقاعدة البيانات والتصميم
///   تُولَّد تلقائياً من الترقيم التسلسلي
/// - كل فرع جديد يأخذ نفس المهام/الوحدات، بينما بياناته مستقلة تماماً
///   (قاعدة معزولة برمز `accounting_system_branchN`).
class BranchRegistry {
  BranchRegistry._();

  static final BranchRegistry instance = BranchRegistry._();

  static const String collection = 'accounting_branches';

  List<BranchProfile> _branches = [];
  bool _loaded = false;
  Future<void>? _currentLoading;

  List<BranchProfile> get branches => List.unmodifiable(_branches);

  bool get isLoaded => _loaded;

  BranchProfile? find(String id) {
    for (final b in _branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// أكبر رقم مشغول (من معرفات وأكواد الفروع المسجلة في السجل)
  int _maxNumber() {
    var max = 0;
    for (final b in _branches) {
      final idN = int.tryParse(b.id.replaceFirst('branch', ''));
      if (idN != null && idN > max) max = idN;
    }
    for (final b in _branches) {
      final m = RegExp(r'BR(\d+)').firstMatch(b.code);
      final c = m == null ? null : int.tryParse(m.group(1)!);
      if (c != null && c > max) max = c;
    }
    return max;
  }

  /// كود الفرع الجديد التلقائي (آخر كود محفوظ + 1، مثل BR10 ← BR11)
  String get nextCode {
    final n = _maxNumber() + 1;
    return 'BR${n.toString().padLeft(2, '0')}';
  }

  /// المعرف التلقائي للفرع الجديد (branch1, branch2, ... حتى branch100)
  String get nextId => 'branch${_maxNumber() + 1}';

  /// التأكد من جاهزية إعدادات الفرع الديناميكي الحالي قبل فتح قاعدته.
  ///
  /// يقرأ السجل كاملاً من Firestore (المرجع الموثوق) — بدون أي كاش محلي.
  Future<void> ensureCurrentReady() {
    final pending = _currentLoading;
    if (pending != null) return pending;
    final task = _ensureCurrentReady();
    _currentLoading = task;
    task.whenComplete(() => _currentLoading = null);
    return task;
  }

  Future<void> _ensureCurrentReady() async {
    final pendingId = SystemConfig.instance.pendingDynamicId;
    if (pendingId.isEmpty) {
      SystemConfig.dynamicBranchReady.value = true;
      return;
    }
    // ثلاث محاولات تلقائية قبل إعلان الفشل — يتجاوز ضعف الإنترنت اللحظي
    // حتى لا تظهر شاشة دخول فارغة أبداً عند فتح رابط فرع من أي مكان.
    for (var attempt = 1; attempt <= 3; attempt++) {
      final cloudOk = await loadAll();
      if (cloudOk) {
        // قراءة سحابية ناجحة: الفرع غير موجود فيها = محذوف فعلاً.
        if (find(pendingId) == null) {
          SystemConfig.branchDeleted.value = true;
        }
        SystemConfig.dynamicBranchFailed.value = false;
        SystemConfig.dynamicBranchReady.value = true;
        return;
      }
      if (attempt < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    SystemConfig.dynamicBranchFailed.value = true;
    SystemConfig.dynamicBranchReady.value = true;
  }

  /// إعادة محاولة تحميل إعدادات الفرع الحالي (زر «إعادة المحاولة»).
  Future<void> retryDynamicBranch() {
    SystemConfig.dynamicBranchReady.value = false;
    SystemConfig.dynamicBranchFailed.value = false;
    SystemConfig.branchDeleted.value = false;
    return ensureCurrentReady();
  }

  /// تحميل كل الفروع المسجلة من السحابة (Firestore فقط — لا كاش محلي).
  ///
  /// تعيد true عند نجاح القراءة السحابية وfalse عند تعذر الوصول.
  Future<bool> loadAll() async {
    try {
      await _ensureFirebase();
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt')
          .get();
      _branches = snap.docs
          .map((d) => BranchProfile.fromJson(d.data()))
          .where((p) => p.id.isNotEmpty)
          .toList();
      _loaded = true;
      SystemConfig.registerDynamicProfiles(_branches);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// إنشاء فرع جديد: تُولَّد تلقائياً المعرف والكود وقاعدة البيانات والتصميم.
  /// الحد الأقصى 100 فرع (SystemConfig.maxBranches).
  Future<BranchProfile> createBranch({
    required String name,
    required String username,
    required String password,
  }) async {
    // قراءة إلزامية من السحابة قبل توليد المعرف حتى لا يتكرر أبداً
    final cloudOk = await loadAll();
    if (!cloudOk) {
      throw StateError('تعذّر قراءة سجل الفروع من السحابة — تحقق من الإنترنت');
    }
    final n = _maxNumber() + 1;
    if (n > SystemConfig.maxBranches) {
      throw StateError(
        'تم الوصول للحد الأقصى لعدد الفروع (${SystemConfig.maxBranches} فرعاً) — '
        'لا يمكن إضافة فروع جديدة',
      );
    }
    final id = 'branch$n';
    final code = 'BR${n.toString().padLeft(2, '0')}';
    final profile = BranchProfile(
      id: id,
      name: name.trim(),
      code: code,
      username: username.trim(),
      password: password,
      dbName: 'accounting_system_$id',
      themeIndex: (n - 1) % 4,
    );
    await _ensureFirebase();
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .set(profile.toJson());
    _branches = [
      for (final b in _branches)
        if (b.id != id) b,
      profile,
    ];
    SystemConfig.registerDynamicProfiles(_branches);
    return profile;
  }

  /// حذف فرع فوري: يُشطب من السجل لحظياً (تطبيق الموظف يُغلق فوراً
  /// بشاشة «تم حذف الفرع») ثم تُمسح شجرة بياناته بالكامل في الخلفية
  /// دون إبطاء واجهة الأدمن إطلاقاً.
  Future<void> deleteBranch(String id) async {
    final profile = find(id);
    _branches = [for (final b in _branches) if (b.id != id) b];
    SystemConfig.registerDynamicProfiles(_branches);
    await _ensureFirebase();
    await FirebaseFirestore.instance.collection(collection).doc(id).delete();
    // مسح شجرة البيانات + التقارير بالخلفية — لا يُنتظر (الحذف فوري)
    if (profile != null) {
      unawaited(_wipeLegacySystem(id, profile.code));
    }
  }

  /// مسح شجرة نظام في السحابة بالكامل — يُستخدم عند حذف فرع من السجل.
  Future<void> _wipeLegacySystem(String id, String code) async {
    try {
      await _ensureFirebase();
      final fs = FirebaseFirestore.instance;
      final root = fs.collection('accounting_systems').doc(id);

      Future<void> clearCollection(
        CollectionReference<Map<String, dynamic>> col,
      ) async {
        while (true) {
          final snap = await col.limit(400).get();
          if (snap.docs.isEmpty) return;
          final batch = fs.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      }

      for (final name in AppConstants.allStores) {
        final storeRef = root.collection('stores').doc(name);
        await clearCollection(storeRef.collection('records'));
        await storeRef.delete();
        await root.collection('counters').doc(name).delete();
      }
      await root.delete();

      // مسح تقارير هذا الفرع (نهاية اليوم + الحضور + الأقسام)
      await _deleteReportsOf(code);
      await _deleteSectionReportsOf(code);
    } catch (_) {
      // الشجرة قد لا تكون موجودة أصلاً — لا شيء يُكسر
    }
  }

  /// حذف كل تقارير المجموعة المشتركة الخاصة بكود فرع معيّن.
  Future<void> _deleteReportsOf(String code) async {
    try {
      final fs = FirebaseFirestore.instance;
      final col = fs.collection('accounting_eod_reports');
      while (true) {
        final snap = await col
            .where('branch_code', isEqualTo: code)
            .limit(400)
            .get();
        if (snap.docs.isEmpty) return;
        final batch = fs.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  /// حذف تقارير الأقسام (منتجات/موظفين/رواتب/مخزون...) الخاصة بكود فرع معيّن.
  Future<void> _deleteSectionReportsOf(String code) async {
    try {
      final fs = FirebaseFirestore.instance;
      final col = fs.collection('accounting_section_reports');
      while (true) {
        final snap = await col
            .where('branch_code', isEqualTo: code)
            .limit(400)
            .get();
        if (snap.docs.isEmpty) return;
        final batch = fs.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  /// التأكد من تهيئة Firebase (البوابة الإلزامية لكل النظام/فرع)
  Future<void> _ensureFirebase() async {
    await FirebaseBootstrap.instance.initialize();
  }
}
