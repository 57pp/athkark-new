import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_network.dart';

class InterstitialManager {
  InterstitialAd? _ad;
  bool _loading = false;
  int _failCount = 0;

  Future<void> preload(String unitId) async {
    if (_loading) return;
    if (_ad != null) return;
    if (!AdNetwork.I.isOnline) return;

    _loading = true;
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          _failCount = 0;
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          _ad = null;
          _failCount++;
        },
      ),
    );
  }

  Future<bool> showIfReady() async {
    final ad = _ad;
    if (ad == null) return false;
    bool shown = false;
    await ad.show().whenComplete(() {
      ad.dispose();
      _ad = null;
      shown = true;
    });
    return shown;
  }

  Duration nextBackoff() => Duration(seconds: min(60, 2 << _failCount)); // 2,4,8..60
}