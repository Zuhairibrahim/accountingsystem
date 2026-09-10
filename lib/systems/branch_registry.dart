import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/database/database_service.dart';
import '../core/firebase/firebase_bootstrap.dart';
import 'branch_profile.dart';
import 'system_config.dart';

/// سجل الفروع الديناميكية التي يُنشئها النظام الأساسي.
///
/// - الأدمين يُدخل فقط: اسم الفرع + اسم المستخدم + كلمة السر
/// - كود الفرع يُولَّد تلقائياً من آخر كود محفوظ (مثال: آخر BR10 ← الجديد BR11)
/// - المعرف (`branch5`, `branch6`...) وقاعدة البيانات والتصميم تُولَّد تلقائياً
/// - كل الفرع الجديد يأخذ نفس المهام/الوحدات الموجودة في الفروع الأخرى،
///   بينما بياناته مستقلة تماماً (قاعدة معزولة برمز `accounting_system_branchN`).
class BranchRegistry {
  BranchRegistry._();

  static final BranchRegistry instance = BranchRegistry._();

  static const String collection = 'accounting_branches';
  static const String _cacheStore = AppConstants.tSettings;
  static const int _cacheKey = 9101;

  /// الفروع الأربعة الثابتة (تُستثنى من التوليد التلقائي)
  static const List<({String id, String code})> _fixed = [
    (id: 'branch1', code: 'BR01'),
    (id: 'branch2', code: 'BR02'),
    (id: 'branch3', code: 'BR03'),
    (id: 'branch4', code: 'BR04'),
  ];

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

  /// أكبر رقم مشغول (الفروع الثابتة 1-4 + أرقام المعرفات والرموز المسجلة)
  int _maxNumber() {
    var max = 0;
    for (final f in _fixed) {
      final idN = int.tryParse(f.id.replaceFirst('branch', ''));
      if (idN != null && idN > max) max = idN;
      final cN = int.tryParse(
        f.code.startsWith('BR') ? f.code.substring(2) : '',
      );
      if (cN != null && cN > max) max = cN;
    }
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

  /// المعرف التلقائي للفرع الجديد (branch5, branch6, ...)
  String get nextId => 'branch${_maxNumber() + 1}';

  /// التأكد من جاهزية إعدادات الفرع الديناميكي الحالي قبل فتح قاعدته.
  ///
  /// يُستدعى من مورد قاعدة البيانات ومن بدء التشغيل حتى يُعرف اسم قاعدة
  /// الفرع (accounting_system_branchN) بشكل صحيح قبل فتحها.
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
    if (!_loaded) {
      _branches = await _fromLocalCache();
      _loaded = true;
      SystemConfig.registerDynamicProfiles(_branches);
    }
    if (find(pendingId) == null) {
      // الأول فتح لهذا الفرع الديناميكي → نجلب ملفه من سجل السحابة
      try {
        await _ensureFirebase();
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(pendingId)
            .get();
        if (doc.exists) {
          final p = BranchProfile.fromJson(doc.data()!);
          if (p.id.isNotEmpty) {
            _branches = [
              for (final b in _branches)
                if (b.id != p.id) b,
              p,
            ];
            SystemConfig.registerDynamicProfiles(_branches);
            await _cacheLocally();
          }
        }
      } catch (_) {
        // بدون سحابة → يكفي الكاش المحلي
      }
    }
    SystemConfig.dynamicBranchReady.value = true;
  }

  /// تحميل كل الفروع المسجلة من السحابة (مع الكاش المحلي كاحتياط) وتحديث النظام.
  Future<void> loadAll() async {
    if (!_loaded) {
      _branches = await _fromLocalCache();
      _loaded = true;
    }
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
      registerAndCache();
    } catch (_) {
      registerAndCache();
    }
  }

  /// تسجيل الفروع في SystemConfig + تحديث الكاش المحلي.
  void registerAndCache() {
    SystemConfig.registerDynamicProfiles(_branches);
    _cacheLocally();
  }

  /// إنشاء فرع جديد: تُولَّد تلقائياً المعرف والكود وقاعدة البيانات والتصميم.
  Future<BranchProfile> createBranch({
    required String name,
    required String username,
    required String password,
  }) async {
    await loadAll();
    final n = _maxNumber() + 1;
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
    registerAndCache();
    return profile;
  }

  /// حذف فرع ديناميكي من السجل (السحابة + الكاش المحلي)
  Future<void> deleteBranch(String id) async {
    _branches = [for (final b in _branches) if (b.id != id) b];
    registerAndCache();
    try {
      await _ensureFirebase();
      await FirebaseFirestore.instance.collection(collection).doc(id).delete();
    } catch (_) {
      // الحذف المحلي تم حتى لو فشل الحذف السحابي
    }
  }

  /// التأكد من تهيئة Firebase (البوابة الإلزامية لكل النظام/فرع)
  Future<void> _ensureFirebase() async {
    await FirebaseBootstrap.instance.initialize();
  }

  // ==================== الكاش المحلي (يعمل بدون إنترنت) ====================
  Future<void> _cacheLocally() async {
    try {
      final json = jsonEncode([for (final b in _branches) b.toJson()]);
      await DatabaseService.instance.upsert(
        _cacheStore,
        _cacheKey,
        {'value': json},
      );
    } catch (_) {
      // تجاهل فشل التخزين المؤقت
    }
  }

  Future<List<BranchProfile>> _fromLocalCache() async {
    try {
      final rec = await DatabaseService.instance.get(_cacheStore, _cacheKey);
      final raw = rec?['value']?.toString();
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list)
          BranchProfile.fromJson(Map<String, Object?>.from(e as Map)),
      ];
    } catch (_) {
      return [];
    }
  }
}