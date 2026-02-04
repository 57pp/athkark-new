import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AdNetwork {
  AdNetwork._();
  static final AdNetwork I = AdNetwork._();

  final _connCtrl = StreamController<bool>.broadcast();
  Stream<bool> get online$ => _connCtrl.stream;
  StreamSubscription? _connSub;
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    // Check initial connectivity status
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = connectivityResult.isNotEmpty && connectivityResult.first != ConnectivityResult.none;
    _connCtrl.add(_isOnline);

    // Listen for connectivity changes
    _connSub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
      if (isOnline != _isOnline) {
        _isOnline = isOnline;
        _connCtrl.add(isOnline);
      }
    });
  }

  void dispose() {
    _connSub?.cancel();
    _connCtrl.close();
  }
}