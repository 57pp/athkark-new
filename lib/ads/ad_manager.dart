import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Import the new AdNetwork
import '../core/ads/ad_network.dart';

class AdManager {
  // معرّف وحدة الإعلان المنبثق (Interstitial Ad Unit ID)
  static const String interstitialAdUnitId =
      'ca-app-pub-4643935541592588/5481094834';

  // إدارة حالة الإعلانات
  static DateTime? _lastInterstitialAdShown;
  static InterstitialAd? _currentInterstitialAd;
  static bool _isInterstitialLoading = false;

  // تحميل الإعلان المنبثق مع إدارة التوقيت
  static Future<void> loadInterstitialAd({
    required VoidCallback onAdLoaded,
    required VoidCallback onAdFailed,
    int retryDelay = 45, // زيادة تأخير إعادة المحاولة
  }) async {
    // Check if online before loading ad
    if (!AdNetwork.I.isOnline) {
      debugPrint('Skipping interstitial ad load - device is offline');
      onAdFailed();
      return;
    }

    if (_isInterstitialLoading) return;

    _isInterstitialLoading = true;

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _currentInterstitialAd = ad;
          _currentInterstitialAd?.setImmersiveMode(true);
          _isInterstitialLoading = false;
          onAdLoaded();
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _currentInterstitialAd = null;
          onAdFailed();
          // إعادة محاولة تحميل الإعلان بعد تأخير محدد
          Future.delayed(
            Duration(seconds: retryDelay),
            () => loadInterstitialAd(
              onAdLoaded: onAdLoaded,
              onAdFailed: onAdFailed,
            ),
          );
        },
      ),
    );
  }

  // عرض الإعلان المنبثق مع التحقق من فترة التهدئة (cooldown)
  static void showInterstitialAd({
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailed,
    int cooldownSeconds = 60, // زيادة فترة التهدئة لتجربة أفضل
  }) {
    final now = DateTime.now();

    if (_lastInterstitialAdShown != null &&
        now.difference(_lastInterstitialAdShown!) <
            Duration(seconds: cooldownSeconds)) {
      onAdDismissed();
      return;
    }

    if (_currentInterstitialAd == null) {
      onAdFailed();
      return;
    }

    _lastInterstitialAdShown = now;

    _currentInterstitialAd?.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _currentInterstitialAd = null;
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _currentInterstitialAd = null;
        onAdFailed();
      },
    );

    _currentInterstitialAd?.show();
  }

  // تنظيف الموارد
  static void dispose() {
    _currentInterstitialAd?.dispose();
    _currentInterstitialAd = null;
    _isInterstitialLoading = false;
  }
}

// تعريف ويدجت حالة (StatefulWidget) لعرض إعلان البانر
class BannerAdWidget extends StatefulWidget {
  // الباني مع مفتاح اختياري
  const BannerAdWidget({super.key});

  @override
  BannerAdWidgetState createState() =>
      BannerAdWidgetState(); // إنشاء الحالة الخاصة بالويدجت
}

// تعريف الحالة الخاصة بـ BannerAdWidget
class BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd; // متغير لتخزين كائن إعلان البانر (يمكن أن يكون null)
  bool _isAdLoaded = false;
  bool _isAdLoading =
      false; // متغير لتتبع حالة تحميل الإعلان، يبدأ بقيمة false (أي لم يتم التحميل بعد)

  @override
  void initState() {
    super.initState(); // استدعاء initState للفئة الأساسية لضمان التهيئة الصحيحة
    _loadBannerAd(); // بدء تحميل إعلان البانر عند إنشاء الحالة
  }

  // دالة لتحميل إعلان البانر
  void _loadBannerAd() {
    // Check if online before loading ad
    if (!AdNetwork.I.isOnline) {
      debugPrint('Skipping banner ad load - device is offline');
      if (mounted) {
        setState(() {
          _isAdLoading = false;
        });
      }
      return;
    }
    
    if (_isAdLoading) {
      return;
    }
    setState(() {
      _isAdLoading = true;
    });
    _bannerAd = BannerAd(
      // استخدام معرف الاختبار أثناء التطوير
      adUnitId:
          'ca-app-pub-4643935541592588/2895858748', // معرف وحدة الإعلان (يُستبدل بمعرف الإنتاج لاحقًا)
      size: AdSize.banner, // تحديد حجم الإعلان كبانر قياسي
      request: const AdRequest(
        // إضافة معلمات لتحسين تحميل الإعلانات
        keywords: ['quran', 'islam', 'muslim', 'prayer', 'dhikr'],
        contentUrl: 'https://athkark.com',
        nonPersonalizedAds: false,
      ), // إرسال طلب الإعلان (يمكن تخصيص الطلب إذا لزم الأمر)
      listener: BannerAdListener(
        // مستمع الأحداث الخاص بالإعلان
        onAdLoaded: (ad) {
          // دالة تُستدعى عند تحميل الإعلان بنجاح
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadBannerAd();

              setState(() {
                _isAdLoaded =
                    true; // تحديث الحالة للإشارة إلى أن الإعلان تم تحميله
                _isAdLoading = false;
              });
            }
          });
        },

        onAdFailedToLoad: (ad, error) {
          // دالة تُستدعى في حالة فشل تحميل الإعلان
          ad.dispose(); // التخلص من كائن الإعلان لتفادي تسرب الذاكرة
          debugPrint('فشل تحميل إعلان البانر: ${error.message}');
          debugPrint('Error code: ${error.code}, domain: ${error.domain}');
          if (mounted) {
            setState(() {
              _isAdLoading = false;
            });
          }
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadBannerAd();
            }
          }); // طباعة رسالة الخطأ للمطور
        },
      ),
    );

    _bannerAd!
        .load(); // بدء عملية تحميل الإعلان (يستخدم العامل ! للتأكيد أن _bannerAd ليس null)
  }

  @override
  void dispose() {
    _bannerAd
        ?.dispose(); // التأكد من التخلص من كائن الإعلان إذا كان موجودًا عند إزالة الويدجت
    super.dispose(); // استدعاء dispose للفئة الأساسية
  }

  @override
  Widget build(BuildContext context) {
    // بناء الواجهة الخاصة بالويدجت بناءً على حالة تحميل الإعلان
    if (!_isAdLoaded) {
      // إذا لم يتم تحميل الإعلان بعد، لا نعرض أي شيء
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: SizedBox(
          // عرض الإعلان المحمل
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}