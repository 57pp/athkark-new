import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Import the new AdNetwork
import '../core/ads/ad_network.dart';

/// Enhanced Ad Manager with pointer event isolation and proper lifecycle management
/// Resolves UI freezing issues and touch interference with ads
class EnhancedAdManager {
  // Ad unit IDs
  static const String interstitialAdUnitId =
      'ca-app-pub-4643935541592588/5481094834';
  static const String bannerAdUnitId =
      'ca-app-pub-4643935541592588/2895858748';

  // State management
  static InterstitialAd? _currentInterstitialAd;
  static bool _isInterstitialLoading = false;
  static DateTime? _lastInterstitialAdShown;
  static final Map<String, BannerAd> _bannerAds = {};
  static final Map<String, bool> _bannerAdLoading = {};
  static final Map<String, bool> _bannerAdAttempted = {}; // Track if we've tried loading for this screen

  static void _preloadSilently() {
    loadInterstitialAd(
      onAdLoaded: () => debugPrint('Interstitial preloaded'),
      onAdFailed: () => debugPrint('Interstitial preload failed'),
    );
  }

  /// Load interstitial ad with proper error handling and lifecycle management
  static Future<void> loadInterstitialAd({
    required VoidCallback onAdLoaded,
    required VoidCallback onAdFailed,
    int retryDelay = 30,
    String? placementId,
  }) async {
    // Check if online before loading ad
    if (!AdNetwork.I.isOnline) {
      debugPrint('Skipping interstitial ad load - device is offline');
      onAdFailed();
      return;
    }
    
    if (_isInterstitialLoading) return;

    _isInterstitialLoading = true;

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(
          keywords: ['quran', 'islam', 'muslim', 'prayer', 'dhikr'],
          contentUrl: 'https://athkark.com',
          nonPersonalizedAds: false,
        ),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _currentInterstitialAd = ad;
            _setupInterstitialCallbacks(onAdLoaded, onAdFailed);
            _isInterstitialLoading = false;
            onAdLoaded();
          },
          onAdFailedToLoad: (error) {
            _isInterstitialLoading = false;
            debugPrint('Failed to load interstitial ad: ${error.message}');
            _scheduleRetry(onAdLoaded, onAdFailed, retryDelay);
          },
        ),
      );
    } catch (e) {
      _isInterstitialLoading = false;
      debugPrint('Exception loading interstitial ad: $e');
      onAdFailed();
    }
  }

  /// Show interstitial ad with proper lifecycle management
  static void showInterstitialAd({
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailed,
    int cooldownSeconds = 30,
    String? placementId,
  }) {
    final now = DateTime.now();

    // Check cooldown period
    if (_lastInterstitialAdShown != null &&
        now.difference(_lastInterstitialAdShown!) <
            Duration(seconds: cooldownSeconds)) {
      debugPrint('Interstitial ad on cooldown, proceeding without ad');
      onAdDismissed();
      return;
    }

    if (_currentInterstitialAd == null) {
      debugPrint('No interstitial ad available, proceeding without ad');
      onAdFailed();
      return;
    }

    _lastInterstitialAdShown = now;

    // Show with error handling
    try {
      _currentInterstitialAd?.fullScreenContentCallback =
          FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _currentInterstitialAd = null;
          onAdDismissed();
          _preloadSilently();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _currentInterstitialAd = null;
          onAdFailed();
          _preloadSilently();
        },
      );
      _currentInterstitialAd!.show();
    } catch (e) {
      debugPrint('Error showing interstitial ad: $e');
      _currentInterstitialAd = null;
      onAdFailed();
      _preloadSilently();
    }
  }

  /// Load banner ad for specific screen with pointer event isolation
  static Future<BannerAd?> loadBannerAd({
    required String screenId,
    AdSize size = AdSize.banner,
    VoidCallback? onAdLoaded,
    Function(BannerAd, LoadAdError)? onAdFailed,
  }) async {
    // Check if online before loading ad
    if (!AdNetwork.I.isOnline) {
      return null;
    }

    // If we've already attempted to load for this screen and it's not loaded, don't try again
    if (_bannerAdAttempted[screenId] == true && _bannerAds[screenId] == null) {
      return null;
    }

    // Check if ad is already loaded and not disposed
    if (_bannerAds[screenId] != null && !_bannerAdLoading[screenId]!) {
      return _bannerAds[screenId];
    }

    if (_bannerAdLoading[screenId] == true) {
      return null;
    }

    _bannerAdLoading[screenId] = true;
    _bannerAdAttempted[screenId] = true;

    try {
      final bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: size,
        request: const AdRequest(
          keywords: ['quran', 'islam', 'muslim', 'prayer', 'dhikr'],
          contentUrl: 'https://athkark.com',
          nonPersonalizedAds: false,
        ),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _bannerAds[screenId] = ad as BannerAd;
            _bannerAdLoading[screenId] = false;
            onAdLoaded?.call();
          },
          onAdFailedToLoad: (ad, error) {
            _bannerAdLoading[screenId] = false;
            // Completely silent for all ad failures to prevent spam
            ad.dispose();
          },
          // Silent callbacks
          onAdOpened: (ad) {},
          onAdClosed: (ad) {},
        ),
      );

      await bannerAd.load();
      return bannerAd;
    } catch (e) {
      _bannerAdLoading[screenId] = false;
      return null;
    }
  }

  /// Get banner widget with proper pointer event isolation
  static Widget getBannerWidget({
    required String screenId,
    AdSize size = AdSize.banner,
    VoidCallback? onAdLoaded,
    Function(BannerAd, LoadAdError)? onAdFailed,
    Widget? fallbackWidget,
  }) {
    // Check if ad is already loaded to avoid repeated loading
    if (_bannerAds[screenId] != null && !_bannerAdLoading[screenId]!) {
      return PointerEventIsolatedAdWidget(
        ad: _bannerAds[screenId]!,
        screenId: screenId,
      );
    }

    // Only load once per screen session
    if (_bannerAdLoading[screenId] == true) {
      return fallbackWidget ?? const SizedBox.shrink();
    }

    return FutureBuilder<BannerAd?>(
      future: loadBannerAd(
        screenId: screenId,
        size: size,
        onAdLoaded: onAdLoaded,
        onAdFailed: onAdFailed, // Will be filtered in loadBannerAd
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return PointerEventIsolatedAdWidget(
            ad: snapshot.data!,
            screenId: screenId,
          );
        }

        return fallbackWidget ?? const SizedBox.shrink();
      },
    );
  }

  /// Clean up resources for specific screen
  static void cleanupScreenAds(String screenId) {
    if (_bannerAds[screenId] != null) {
      _bannerAds[screenId]!.dispose();
      _bannerAds.remove(screenId);
    }
    _bannerAdLoading.remove(screenId);
    _bannerAdAttempted.remove(screenId);
  }

  /// Clean up all ads
  static void dispose() {
    _currentInterstitialAd?.dispose();
    _currentInterstitialAd = null;
    _bannerAds.values.forEach((ad) => ad.dispose());
    _bannerAds.clear();
    _bannerAdLoading.clear();
    _bannerAdAttempted.clear();
    _isInterstitialLoading = false;
  }

  /// Setup interstitial ad callbacks
  static void _setupInterstitialCallbacks(
    VoidCallback onAdLoaded,
    VoidCallback onAdFailed,
  ) {
    _currentInterstitialAd?.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Interstitial ad dismissed');
        ad.dispose();
        _currentInterstitialAd = null;
        // Preload next ad
        loadInterstitialAd(
          onAdLoaded: () => debugPrint('Next interstitial ad preloaded'),
          onAdFailed: () => debugPrint('Failed to preload next interstitial ad'),
        );
        onAdLoaded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Failed to show interstitial ad: ${error.message}');
        ad.dispose();
        _currentInterstitialAd = null;
        onAdFailed();
      },
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Interstitial ad shown');
      },
    );
  }

  /// Schedule retry for failed ad load
  static void _scheduleRetry(
    VoidCallback onAdLoaded,
    VoidCallback onAdFailed,
    int retryDelay,
  ) {
    Future.delayed(Duration(seconds: retryDelay), () {
      loadInterstitialAd(
        onAdLoaded: onAdLoaded,
        onAdFailed: onAdFailed,
        retryDelay: retryDelay,
      );
    });
  }
}

/// Widget that isolates pointer events for ad views to prevent UI freezing
class PointerEventIsolatedAdWidget extends StatefulWidget {
  final BannerAd ad;
  final String screenId;

  const PointerEventIsolatedAdWidget({
    super.key,
    required this.ad,
    required this.screenId,
  });

  @override
  State<PointerEventIsolatedAdWidget> createState() =>
      _PointerEventIsolatedAdWidgetState();
}

class _PointerEventIsolatedAdWidgetState extends State<PointerEventIsolatedAdWidget> {
  @override
  void dispose() {
    super.dispose();
    // Clean up when widget is disposed
    EnhancedAdManager.cleanupScreenAds(widget.screenId);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.ad.size.width.toDouble(),
      height: widget.ad.size.height.toDouble(),
      child: Stack(
        children: [
          // Main ad widget
          AdWidget(ad: widget.ad),
          // Invisible overlay to isolate pointer events if needed
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: false, // Let ad handle its own touch events
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Utility class for managing ad screen lifecycle
class AdScreenManager {
  static final Set<String> _activeScreens = {};

  static void registerScreen(String screenId) {
    _activeScreens.add(screenId);
    debugPrint('Screen registered for ad management: $screenId');
  }

  static void unregisterScreen(String screenId) {
    _activeScreens.remove(screenId);
    EnhancedAdManager.cleanupScreenAds(screenId);
    debugPrint('Screen unregistered for ad management: $screenId');
  }

  static bool isScreenActive(String screenId) {
    return _activeScreens.contains(screenId);
  }

  static void disposeAll() {
    _activeScreens.clear();
    EnhancedAdManager.dispose();
  }
}
