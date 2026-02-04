import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_network.dart';

class AdaptiveBanner extends StatefulWidget {
  final String adUnitId;
  const AdaptiveBanner({super.key, required this.adUnitId});

  @override
  State<AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<AdaptiveBanner> with WidgetsBindingObserver {
  BannerAd? _ad;
  bool _loaded = false;
  bool _isResumed = true;

  Future<void> _load() async {
    if (!mounted) return;
    if (!AdNetwork.I.isOnline) return;
    if (_ad != null) return;

    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return;

    final ad = BannerAd(
      size: size,
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          _loaded = false;
          if (mounted) setState(() {});
        },
      ),
    );

    await ad.load();
    if (!mounted) { ad.dispose(); return; }
    setState(() => _ad = ad);
  }

  void _onOnlineChange(bool online) {
    if (!mounted) return;
    if (!online) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      setState(() {});
    } else if (_isResumed) {
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdNetwork.I.online$.listen(_onOnlineChange);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isResumed = state == AppLifecycleState.resumed;
    if (_isResumed && AdNetwork.I.isOnline && _ad == null) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isResumed || !_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}