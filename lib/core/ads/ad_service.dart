import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_constants.dart';

/// إدارة إعلانات AdMob داخل التطبيق.
///
/// - يعمل فقط على Android و iOS (AdMob لا يدعم الويب/سطح المكتب).
/// - يهيّئ SDK ويجمع موافقة المستخدم (GDPR/UMP) قبل أول طلب إعلان.
/// - يدير الإعلان البيني مع فاصل زمني ([AdConstants.interstitialMinIntervalSeconds])
///   لتكرار مناسب وسياسي لأعلى المطاف ضمن شروط Google AdMob و Google Play.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  Completer<void>? _initCompleter;

  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;
  bool _showingInterstitial = false;
  DateTime? _lastShownAt;

  /// هل المنصة الحالية تدعم إعلانات AdMob؟
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// اكتمال التهيئة (SDK + موافقة المستخدم) — تنتظرها أجزاء الواجهة قبل الطلب.
  Future<void> get ready async {
    final complete = _initCompleter?.future;
    if (complete != null) await complete;
  }

  /// تهيئة AdMob: SDK ثم موافقة المستخدم ثم تحميل أول إعلان بيني.
  ///
  /// تُستدعى مرة واحدة عند إقلاع التطبيق ولا تعطّل واجهة المستخدم.
  Future<void> init() {
    if (!isSupported) {
      return Future.value();
    }
    return (_initCompleter ??= Completer<void>()..complete(
      _initInternal(),
    )).future;
  }

  Future<void> _initInternal() async {
    try {
      await MobileAds.instance.initialize();
      await _gatherConsent();
      await _loadInterstitial();
    } catch (e) {
      debugPrint('AdService.init error: $e');
    }
  }

  /// جمع موافقة المستخدم (UMP/GDPR) — تُنفّذ قبل طلب الإعلانات.
  Future<void> _gatherConsent() async {
    try {
      final params = ConsentRequestParameters(tagForUnderAgeOfConsent: false);
      final infoUpdate = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () => infoUpdate.complete(),
        (FormError error) => infoUpdate.completeError(error),
      );
      await infoUpdate.future;

      if (await ConsentInformation.instance.canRequestAds()) {
        return;
      }
      await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
        // يتم تجاهل أخطاء النموذج — يمكن طلب الإعلانات عبر حالة canRequestAds
      });
    } catch (e) {
      debugPrint('AdService consent error: $e');
    }
  }

  Future<void> _loadInterstitial() async {
    if (!isSupported) return;
    if (_interstitialAd != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: AdConstants.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (shownAd) {
                _showingInterstitial = false;
                shownAd.dispose();
                _interstitialAd = null;
                _loadInterstitial();
              },
              onAdFailedToShowFullScreenContent: (failedAd, error) {
                debugPrint('AdService show error: $error');
                _showingInterstitial = false;
                failedAd.dispose();
                _interstitialAd = null;
                _loadInterstitial();
              },
            );
            _loadingInterstitial = false;
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdService interstitial load error: $error');
            _interstitialAd = null;
            _loadingInterstitial = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('AdService interstitial load threw: $e');
      _loadingInterstitial = false;
    }
  }

  /// محاولة عرض الإعلان البيني عند نقطة طبيعية (إتمام بيع، تقرير، ...).
  ///
  /// - لا يعرضه قبل الحصول على إعلان محمّل.
  /// - يطبّق الفاصل الزمني الأدنى بين الظهور.
  /// - لا يعرضه أثناء ظهور إعلان آخر.
  /// - يعود [true] فقط إذا عُرض فعلياً.
  Future<bool> tryShowInterstitial({String source = 'auto'}) async {
    if (!isSupported) return false;
    final ad = _interstitialAd;
    if (ad == null || _showingInterstitial) return false;

    final now = DateTime.now();
    final last = _lastShownAt;
    if (last != null &&
        now.difference(last).inSeconds <
            AdConstants.interstitialMinIntervalSeconds) {
      return false;
    }

    _lastShownAt = now;
    _showingInterstitial = true;
    _interstitialAd = null;
    try {
      await ad.show();
      debugPrint('AdService interstitial shown @$source');
      return true;
    } catch (e) {
      debugPrint('AdService interstitial show threw: $e');
      _showingInterstitial = false;
      ad.dispose();
      _loadInterstitial();
      return false;
    }
  }
}