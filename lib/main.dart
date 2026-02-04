import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui; // PlatformDispatcher

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/navigation/deep_link.dart';
import 'core/notifications/athkark_notifications.dart'
    show AthkarkNotifications, decodeNotificationPayload;
import 'core/theme/theme.dart';
import 'core/ads/ad_network.dart';
import 'ads/ad_manager_improved.dart';
import 'shared/widgets/prayer_popup_dialog.dart';
import 'shared/utils/unified_prayer_notification_service.dart';
import 'shared/utils/simple_prayer_notification_service.dart';
import 'shared/utils/adhkar_notification_service.dart';
import 'shared/utils/welcome_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/local_store.dart';
import 'screens/main_screen.dart';
import 'features/settings/quick_splash_screen.dart';
import 'features/prayer_times/domain/prayer_times_service.dart';

final ValueNotifier<DeepLink?> notificationDeepLink =
    ValueNotifier<DeepLink?>(null);
final AthkarkNotifications notifications = AthkarkNotifications.instance;

Future<void> initTimezone() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Aden'));
}

class Boot {
  static Future<void>? _f;
  static Future<void>? _prayerServiceInit;
  static Future<void> ensure() => _f ??= _boot();

  static Future<void> _boot() async {
    debugPrint('[BOOT] starting...');
    try {
      await AndroidAlarmManager.initialize();
      debugPrint('[BOOT] AndroidAlarmManager initialized');

      // Initialize core notifications (channels + permissions)
      await notifications.init();
      debugPrint('[BOOT] AthkarkNotifications initialized');

      await _requestNotificationPermission();
      debugPrint('[BOOT] Notification permission handled');

      await _requestBatteryOptimizationExemption();
      debugPrint('[BOOT] Battery optimization exemption requested');

      await UnifiedPrayerNotificationService.instance.initialize();
      debugPrint('[BOOT] UnifiedPrayerNotificationService initialized');

      await AdhkarNotificationService.instance.initialize();
      debugPrint('[BOOT] AdhkarNotificationService initialized');

      // Initialize SimplePrayerNotificationService with navigator key
      final simplePrayerService = SimplePrayerNotificationService.instance;
      await simplePrayerService.initialize(navigatorKey);
      debugPrint('[BOOT] SimplePrayerNotificationService initialized');

      await WelcomeNotificationService.instance.initialize();
      debugPrint('[BOOT] WelcomeNotificationService initialized');

      debugPrint('[BOOT] completed');
    } catch (e) {
      debugPrint('[BOOT] failed: $e');
    }
  }

  static Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isLimited) {
        return;
      }

      final result = await Permission.notification.request();
      if (!result.isGranted && !result.isLimited) {
        debugPrint(
            '[BOOT] Notification permission not granted; adhan alerts may be blocked');
      }
    } catch (e) {
      debugPrint('[BOOT] Failed to request notification permission: $e');
    }
  }

  static Future<void> _requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;

    try {
      debugPrint('[BOOT] Requesting battery optimization exemption...');

      // Use MethodChannel to request battery optimization exemption
      final MethodChannel batteryChannel = MethodChannel('battery_optimization');
      final bool? result = await batteryChannel.invokeMethod<bool>('requestBatteryOptimizationExemption');

      if (result == true) {
        debugPrint('[BOOT] Battery optimization exemption granted');
      } else {
        debugPrint('[BOOT] Battery optimization exemption denied or not supported');
      }
    } catch (e) {
      debugPrint('[BOOT] Failed to request battery optimization exemption: $e');
    }
  }

  static Future<void> ensurePrayerService() =>
      _prayerServiceInit ??= _initPrayerService();

  static Future<void> _initPrayerService() async {
    try {
      debugPrint('[BOOT] Initializing PrayerTimesService...');
      await PrayerTimesService.instance.init();
      debugPrint('[BOOT] PrayerTimesService initialized');
    } catch (e) {
      debugPrint('[BOOT] PrayerTimesService initialization failed: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob SDK and connectivity-aware ad network
  try {
    await AdNetwork.I.init();
    debugPrint('[ADS] AdMob initialized');
  } catch (e) {
    debugPrint('[ADS] Failed to initialize AdMob: $e');
  }

  await initTimezone();
  await ScreenUtil.ensureScreenSize();

  // Preload an interstitial ad for early availability
  EnhancedAdManager.loadInterstitialAd(
    onAdLoaded: () => debugPrint('[ADS] Startup interstitial loaded'),
    onAdFailed: () => debugPrint('[ADS] Startup interstitial failed'),
  );

  runApp(const MyApp());

  // Start boot sequence after the UI is up to avoid white screen blocking
  if (ui.PlatformDispatcher.instance.implicitView != null) {
    unawaited(Boot.ensure());
    unawaited(Boot.ensurePrayerService());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Global navigator key for showing dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
    // Check for pending prayer alerts when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingPrayerAlert();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle lifecycle changes
    if (state == AppLifecycleState.resumed) {
      _checkPendingPrayerAlert();
    }
  }

  Future<void> _loadThemePreference() async {
    final themeMode = await LocalStore.getThemeMode();
    if (themeMode != null) {
      setState(() {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == themeMode,
          orElse: () => ThemeMode.system,
        );
      });
    }
  }

  Future<void> _checkPendingPrayerAlert() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingAlertJson = prefs.getString('pending_prayer_alert');

      if (pendingAlertJson != null) {
        // Clear the pending alert flag
        await prefs.remove('pending_prayer_alert');

        // Parse the alert data
        final alertData = jsonDecode(pendingAlertJson);
        final String prayerName = alertData['prayer'] ?? 'غير معروف';
        final bool isCustom = alertData['is_custom'] ?? false;
        final String? prayerId = alertData['prayer_id'];

        // Check if the alert is recent (within last 5 minutes)
        final alertTime = DateTime.parse(alertData['timestamp']);
        final now = DateTime.now();
        final timeDiff = now.difference(alertTime).inMinutes;

        if (timeDiff <= 5) {
          debugPrint(
              'Pending prayer alert detected for $prayerName but dialog display is disabled.');
        }
      }
    } catch (e) {
      debugPrint('Error checking pending prayer alert: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (BuildContext context, Widget? child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: _themeMode,
        navigatorKey: navigatorKey,
        home: child,
        routes: <String, WidgetBuilder>{
          '/home': (_) => MainScreen(
                toggleTheme: toggleTheme,
                deepLinkNotifier: notificationDeepLink,
              ),
        },
        builder: (BuildContext context, Widget? materialChild) =>
            Directionality(
          textDirection: TextDirection.rtl,
          child: materialChild!,
        ),
      ),
      child: const QuickSplashScreen(),
    );
  }
}

/// Static method to toggle theme from anywhere in the app
Future<void> toggleTheme() async {
  final state = navigatorKey.currentContext;
  if (state != null) {
    final appState = state.findAncestorStateOfType<_MyAppState>();
    if (appState != null) {
      await appState._toggleTheme();
    }
  }
}

extension _MyAppStateExtension on _MyAppState {
  Future<void> _toggleTheme() async {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    await LocalStore.setThemeMode(_themeMode.name);
  }
}

Future<void> _handleNotificationResponse(
  NotificationResponse response, {
  required bool fromBackground,
}) async {
  // Handle prayer popup notifications (full screen intent)
  if (response.id == 999999) {
    debugPrint('Prayer popup notification tapped');

    // Show the prayer popup dialog
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => PrayerPopupDialog(response: response),
      );
    }
    return;
  }

  // Handle adhkar notifications
  final adhkarPayload = decodeNotificationPayload(response.payload);
  if (adhkarPayload['type'] == 'adhkar_reminder') {
    debugPrint('Adhkar notification tapped: ${adhkarPayload['adhkar_id']}');

    // Navigate to adhkar screen
    if (navigatorKey.currentContext != null) {
      final categoryId = adhkarPayload['category_id'] as int?;
      if (categoryId != null && categoryId > 0) {
        // Navigate to specific adhkar category
        Navigator.of(navigatorKey.currentContext!).pushNamed(
          '/adhkar',
          arguments: {'categoryId': categoryId},
        );
      } else {
        // Navigate to adhkar screen
        Navigator.of(navigatorKey.currentContext!).pushNamed('/adhkar');
      }
    }
    return;
  }

  final Map<String, dynamic> payload =
      decodeNotificationPayload(response.payload);

  switch (response.actionId) {
    case 'mark_read':
      await notifications.recordInteraction();
      if (response.id != null) {
        await notifications.cancelById(response.id!);
      }
      return;
    case 'snooze_10':
      await notifications.recordInteraction();
      if (response.id != null) {
        await notifications.snooze(
          id: response.id!,
          payload: payload,
          duration: const Duration(minutes: 10),
        );
      }
      return;
    case 'open':
    default:
      await notifications.recordInteraction();
      if (response.id != null) {
        await notifications.cancelById(response.id!);
      }
      final DeepLink? deepLink = _deepLinkFromPayload(payload);
      if (deepLink == null) {
        return;
      }
      if (fromBackground) {
        await _storePendingDeepLink(payload);
      } else {
        notificationDeepLink.value = deepLink;
      }
  }
}

Future<void> _storePendingDeepLink(Map<String, dynamic> payload) async {
  await LocalStore.setStringMap('pending_notification_payload', payload);
}

DeepLink? _deepLinkFromPayload(Map<String, dynamic> payload) {
  final String? route = payload['route'] as String?;
  if (route == null || route.isEmpty) {
    return null;
  }

  final Map<String, String> query = <String, String>{};
  payload.forEach((String key, dynamic value) {
    if (key == 'route' ||
        key == 'title' ||
        key == 'body' ||
        key == 'channelId') {
      return;
    }
    if (value == null) {
      return;
    }
    query[key] = value.toString();
  });

  return DeepLink(route: route, query: query);
}
