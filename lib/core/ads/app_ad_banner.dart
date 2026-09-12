import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_constants.dart';
import 'ad_service.dart';

/// بانر AdMob التكيفي (Adaptive Banner) — يُعرض أسفل شاشات التطبيق.
///
/// - يعرض أسفل شاشات التطبيق كله (Main Shell) ليكون ظاهراً بشكل متكرر.
/// - على الويب وسطح المكتب يعود [SizedBox.shrink] لأن AdMob لا يدعمها.
/// - ينتظر اكتمال تهيئة SDK وموافقة المستخدم قبل الطلب.
/// - يزيح التخطيط (يرفع العناصر للأسفل) بدل تغطيتها، توافقاً مع سياسة الإعلانات.
class AppAdBanner extends StatefulWidget {
  const AppAdBanner({super.key});

  @override
  State<AppAdBanner> createState() => _AppAdBannerState();
}

class _AppAdBannerState extends State<AppAdBanner> {
  BannerAd? _banner;
  bool _failed = false;
  bool _loading = false;
  int _lastWidth = 0;

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    await AdService.instance.ready;
    if (!mounted || _banner != null || _failed) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) return;
    if (_lastWidth == width) return;
    _lastWidth = width;

    _loading = true;
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;
    if (size == null) {
      setState(() => _failed = true);
      return;
    }

    final banner = BannerAd(
      size: size,
      adUnitId: AdConstants.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _banner = ad as BannerAd;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AppAdBanner load error: $error');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _failed = true;
            _loading = false;
          });
        },
      ),
    );
    await banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.instance.isSupported) {
      return const SizedBox.shrink();
    }

    if (_banner == null && !_failed && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }

    final banner = _banner;
    if (banner == null) {
      return const SizedBox.shrink();
    }

    final height = banner.size.height.toDouble();
    return Container(
      width: double.infinity,
      height: height,
      color: Colors.white,
      alignment: Alignment.center,
      child: SafeArea(
        top: false,
        child: AdWidget(ad: banner),
      ),
    );
  }
}