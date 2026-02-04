import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/navigation/deep_link.dart';
import 'core/notifications/athkark_notifications.dart'
    show AthkarkNotifications, decodeNotificationPayload;
import 'core/theme/theme.dart';
import 'core/ads/ad_network.dart';
import 'features/settings/splash_screen.dart';
import 'features/settings/splash_page.dart';

final ValueNotifier<DeepLink?> notificationDeepLink =
    ValueNotifier<DeepLink?>(null);
final AthkarkNotifications notifications = AthkarkNotifications.instance;

Future<void> initTimezone() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Aden'));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Minimal initialization to test
  try {
    await initTimezone();
    debugPrint('✅ Timezone initialized');
  } catch (e) {
    debugPrint('❌ Timezone init failed: $e');
  }

  try {
    await ScreenUtil.ensureScreenSize();
    debugPrint('✅ ScreenUtil initialized');
  } catch (e) {
    debugPrint('❌ ScreenUtil init failed: $e');
  }

  // Test AdNetwork
  try {
    await AdNetwork.I.init();
    debugPrint('✅ AdNetwork initialized');
  } catch (e) {
    debugPrint('❌ AdNetwork init failed: $e');
  }

  // Test MobileAds
  try {
    await MobileAds.instance.initialize();
    debugPrint('✅ MobileAds initialized');
  } catch (e) {
    debugPrint('❌ MobileAds init failed: $e');
  }

  // Test AndroidAlarmManager
  if (Platform.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
      debugPrint('✅ AndroidAlarmManager initialized');
    } catch (e) {
      debugPrint('❌ AndroidAlarmManager init failed: $e');
    }
  }

  final FlutterLocalNotificationsPlugin plugin = notifications.plugin;

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('ic_stat_athkark');

  final DarwinInitializationSettings darwinSettings =
      DarwinInitializationSettings(
    notificationCategories: <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        AthkarkNotifications.darwinCategoryId,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain('mark_read', 'Mark read'),
          DarwinNotificationAction.plain('snooze_10', 'Snooze 10m'),
          DarwinNotificationAction.plain('open', 'Open'),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          DarwinNotificationCategoryOption.hiddenPreviewShowSubtitle,
        },
      ),
    ],
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
    macOS: darwinSettings,
  );

  try {
    await plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) =>
          _handleNotificationResponse(response, fromBackground: false),
      onDidReceiveBackgroundNotificationResponse:
          athkarkNotificationTapBackground,
    );
    debugPrint('✅ Notifications initialized');
  } catch (e) {
    debugPrint('❌ Notifications init failed: $e');
  }

  try {
    await notifications.init();
    debugPrint('✅ AthkarkNotifications initialized');
  } catch (e) {
    debugPrint('❌ AthkarkNotifications init failed: $e');
  }

  // Skip PrayerTimesService for now
  // try {
  //   await PrayerTimesService.instance.init(
  //     notifications: plugin,
  //     forceRefresh: true,
  //   );
  //   debugPrint('✅ PrayerTimesService initialized');
  // } catch (e) {
  //   debugPrint('❌ PrayerTimesService init failed: $e');
  // }

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final DeepLink? pendingDeepLink = _consumePendingDeepLink(prefs);

  DeepLink? initialDeepLink = pendingDeepLink;
  if (initialDeepLink == null) {
    final NotificationAppLaunchDetails? launchDetails =
        await plugin.getNotificationAppLaunchDetails();
    final Map<String, dynamic> launchPayload = decodeNotificationPayload(
      launchDetails?.notificationResponse?.payload,
    );
    initialDeepLink = _deepLinkFromPayload(launchPayload);
  }

  // Skip _scheduleDefaultNotifications for now
  // await _scheduleDefaultNotifications(
  //   notifications,
  //   prefs,
  //   forcePrayerRefresh: true,
  // );

  runApp(
    MyApp(
      key: const ValueKey('minimal_app'),
      notifications: notifications,
      deepLinkNotifier: notificationDeepLink,
      initialDeepLink: initialDeepLink,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.notifications,
    required this.deepLinkNotifier,
    this.initialDeepLink,
  });

  final AthkarkNotifications notifications;
  final ValueNotifier<DeepLink?> deepLinkNotifier;
  final DeepLink? initialDeepLink;

  @override
  State<MyApp> createState() => _MyAppState();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
    if (widget.initialDeepLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.deepLinkNotifier.value = widget.initialDeepLink;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed');
    }
  }

  Future<void> _loadThemePreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? themePreference = prefs.getString('theme_mode');
    if (themePreference != null) {
      setState(() {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == themePreference,
          orElse: () => ThemeMode.system,
        );
      });
    }
  }

  Future<void> toggleTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    await prefs.setString('theme_mode', _themeMode.name);
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
          '/home': (_) => const MainScreen(),
        },
        builder: (BuildContext context, Widget? materialChild) =>
            Directionality(
          textDirection: TextDirection.rtl,
          child: materialChild!,
        ),
      ),
      child: const SplashPage(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimal Athkark'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Minimal app loaded successfully!'),
            SizedBox(height: 20),
            Text('If you see this, the basic setup works.'),
            SizedBox(height: 20),
            Text('Now we can add services back one by one.'),
          ],
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> athkarkNotificationTapBackground(
  NotificationResponse response,
) async {
  await _handleNotificationResponse(response, fromBackground: true);
}

Future<void> _handleNotificationResponse(
  NotificationResponse response, {
  required bool fromBackground,
}) async {
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
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'pending_notification_payload',
    jsonEncode(payload),
  );
}

DeepLink? _consumePendingDeepLink(SharedPreferences prefs) {
  final String? raw = prefs.getString('pending_notification_payload');
  if (raw == null || raw.isEmpty) {
    return null;
  }
  prefs.remove('pending_notification_payload');
  final Map<String, dynamic> payload = decodeNotificationPayload(raw);
  return _deepLinkFromPayload(payload);
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