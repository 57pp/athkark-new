import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../../core/theme/colors.dart';

/// Smart Welcome Notification Service
/// Shows personalized welcome notifications based on user behavior
class WelcomeNotificationService {
  static WelcomeNotificationService? _instance;
  static WelcomeNotificationService get instance =>
      _instance ??= WelcomeNotificationService();

  // Getters
  bool get welcomeNotificationsEnabled => _welcomeNotificationsEnabled;
  bool get isInitialized => _isInitialized;

  static const String _welcomeChannelId = 'welcome_notifications';
  static const String _welcomeChannelName = 'Welcome Notifications';
  static const String _welcomeChannelDescription =
      'Delightful welcome and re-engagement reminders.';

  FlutterLocalNotificationsPlugin? _notifications;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // User tracking data
  int _appOpenCount = 0;
  DateTime? _lastAppOpen;
  DateTime? _firstAppOpen;
  bool _welcomeNotificationsEnabled = true;

  // Welcome messages
  final List<String> _dailyDuas = [
    'اللهم إني أسألك العفو والعافية في الدنيا والآخرة',
    'ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار',
    'اللهم إني أعوذ بك من الهم والحزن والعجز والكسل',
    'اللهم ارزقني حبك وحب من يحبك وحب عمل يقربني إلى حبك',
    'اللهم اجعل خير عمري آخره وخير عملي خواتمه',
    'اللهم إني أسألك الجنة وما قرب إليها من قول أو عمل',
    'اللهم ارزقني توبة نصوحاً قبل الموت',
    'اللهم يا مقلب القلوب ثبت قلبي على دينك',
  ];

  final List<String> _motivationalMessages = [
    'الذكر يرفع الدرجات ويحسن الأخلاق',
    'ابدأ يومك بالأذكار والأدعية',
    'المداومة على الذكر تفتح أبواب الرحمة',
    'كل ذكر يثمر حسنة، وكل حسنة ترفع درجة',
    'الأذكار درع من الشيطان ووسيلة للطمأنينة',
  ];

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      _prefs = await SharedPreferences.getInstance();
      _notifications = FlutterLocalNotificationsPlugin();

      await _initializeNotifications();
      // Load user data
      await _loadUserData();

      // Create notification channel
      await _createNotificationChannel();

      _isInitialized = true;
      debugPrint('✅ WelcomeNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize WelcomeNotificationService: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_athkark');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications?.initialize(settings);
  }

  /// Load user tracking data
  Future<void> _loadUserData() async {
    _appOpenCount = _prefs?.getInt('app_open_count') ?? 0;
    _welcomeNotificationsEnabled = _prefs?.getBool('welcome_notifications_enabled') ?? true;

    final lastOpenStr = _prefs?.getString('last_app_open');
    if (lastOpenStr != null) {
      _lastAppOpen = DateTime.parse(lastOpenStr);
    }

    final firstOpenStr = _prefs?.getString('first_app_open');
    if (firstOpenStr != null) {
      _firstAppOpen = DateTime.parse(firstOpenStr);
    }
  }

  /// Save user tracking data
  Future<void> _saveUserData() async {
    await _prefs?.setInt('app_open_count', _appOpenCount);
    await _prefs?.setBool('welcome_notifications_enabled', _welcomeNotificationsEnabled);
    _lastAppOpen = DateTime.now();
    await _prefs?.setString('last_app_open', _lastAppOpen!.toIso8601String());
    if (_firstAppOpen == null) {
      _firstAppOpen = _lastAppOpen;
      await _prefs?.setString('first_app_open', _firstAppOpen!.toIso8601String());
    }
  }

  /// Create notification channel
  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _welcomeChannelId,
      _welcomeChannelName,
      description: _welcomeChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: AppColors.primaryColor,
      showBadge: true,
    );

    final androidImplementation = _notifications
        ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Recreate the channel with high importance in case it already existed with lower importance
    await androidImplementation?.deleteNotificationChannel(_welcomeChannelId);
    await androidImplementation?.createNotificationChannel(channel);
  }

  /// Ensure notification permission is granted
  Future<void> _ensureNotificationPermission() async {
    try {
      // Check if notifications are enabled in our service
      if (!_welcomeNotificationsEnabled) return;

      // The permission should already be requested in Boot.ensure()
      // But let's double-check here
      final androidImplementation = _notifications?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final bool? areEnabled = await androidImplementation.areNotificationsEnabled();
        if (areEnabled != true) {
          await androidImplementation.requestNotificationsPermission();
        }
      }

      final iosImplementation = _notifications?.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error checking notification permission: $e');
    }
  }

  /// Show welcome notification when app is opened
  Future<void> showWelcomeNotification() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized || !_welcomeNotificationsEnabled) return;

    try {
      // Update user data
      _appOpenCount++;
      await _saveUserData();

      // Determine notification type
      final notificationData = _getNotificationContent();

      // Show notification after a longer delay to ensure app is fully loaded
      await Future.delayed(const Duration(seconds: 3));

      await _showNotification(notificationData);
    } catch (e) {
      debugPrint('❌ Failed to show welcome notification: $e');
    }
  }

  /// Get appropriate notification content based on user behavior
  Map<String, String> _getNotificationContent() {
    final now = DateTime.now();
    final daysSinceLastOpen = _lastAppOpen != null
        ? now.difference(_lastAppOpen!).inDays
        : 0;

    // First time user
    if (_appOpenCount == 1 || _firstAppOpen == null) {
      return {
        'title': 'أهلاً وسهلاً بك! 🌟',
        'body': 'مرحباً بك في تطبيق أذكارك. ابدأ رحلتك مع الأذكار والقرآن الكريم',
        'type': 'welcome',
      };
    }

    // User hasn't opened app for more than a day
    if (daysSinceLastOpen > 1) {
      final messages = [
        'مرحباً بعودتك! لقد اشتقت إليك 📖',
        'أهلاً بعودتك! كنا نفتقد ذكراك الجميل 🤲',
        'مرحباً! طبت وطابت أيامك 🌹',
        'أهلاً! فرحنا بعودتك إلينا 💫',
      ];
      final randomMessage = messages[Random().nextInt(messages.length)];

      return {
        'title': 'مرحباً بعودتك! 💝',
        'body': randomMessage,
        'type': 'return',
      };
    }

    // Regular user - show daily dua
    final randomDua = _dailyDuas[Random().nextInt(_dailyDuas.length)];
    final randomMotivation = _motivationalMessages[Random().nextInt(_motivationalMessages.length)];

    return {
      'title': 'دعاء اليوم 🤲',
      'body': '$randomDua\n\n$randomMotivation',
      'type': 'dua',
    };
  }

  /// Show the notification
  Future<void> _showNotification(Map<String, String> data) async {
    try {
      await _ensureNotificationPermission();

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _welcomeChannelId,
        _welcomeChannelName,
        channelDescription: _welcomeChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        enableLights: true,
        ledColor: AppColors.primaryColor,
        ledOnMs: 1000,
        ledOffMs: 1000,
        color: AppColors.primaryColor,
        icon: '@drawable/ic_stat_athkark',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ticker: 'Athkark welcome',
        styleInformation: BigTextStyleInformation(
          data['body']!,
          contentTitle: data['title'],
          summaryText: 'Welcome reminder',
        ),
        autoCancel: true,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: false,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({
        'type': 'welcome',
        'welcome_type': data['type'],
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _notifications!.show(
        999999 + Random().nextInt(1000), // Unique notification ID
        data['title'],
        data['body'],
        details,
        payload: payload,
      );

      debugPrint('✅ Welcome notification shown: ${data['type']}');
    } catch (e) {
      debugPrint('❌ Failed to show welcome notification: $e');
    }
  }

  /// Enable/disable welcome notifications
  Future<void> setWelcomeNotificationsEnabled(bool enabled) async {
    _welcomeNotificationsEnabled = enabled;
    await _saveUserData();
  }

  /// Test welcome notification
  Future<bool> testWelcomeNotification(String type) async {
    try {
      Map<String, String> testData;

      switch (type) {
        case 'welcome':
          testData = {
            'title': '🧪 اختبار: أهلاً وسهلاً',
            'body': 'هذا اختبار لإشعار الترحيب الأول',
            'type': 'welcome',
          };
          break;
        case 'return':
          testData = {
            'title': '🧪 اختبار: مرحباً بعودتك',
            'body': 'هذا اختبار لإشعار العودة',
            'type': 'return',
          };
          break;
        case 'dua':
        default:
          final randomDua = _dailyDuas[Random().nextInt(_dailyDuas.length)];
          testData = {
            'title': '🧪 اختبار: دعاء اليوم',
            'body': randomDua,
            'type': 'dua',
          };
      }

      await _showNotification(testData);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to test welcome notification: $e');
      return false;
    }
  }

  /// Get user statistics
  Map<String, dynamic> getUserStatistics() {
    final now = DateTime.now();
    final daysSinceLastOpen = _lastAppOpen != null
        ? now.difference(_lastAppOpen!).inDays
        : 0;
    final daysSinceFirstOpen = _firstAppOpen != null
        ? now.difference(_firstAppOpen!).inDays
        : 0;

    return {
      'app_open_count': _appOpenCount,
      'last_app_open': _lastAppOpen?.toIso8601String(),
      'first_app_open': _firstAppOpen?.toIso8601String(),
      'days_since_last_open': daysSinceLastOpen,
      'days_since_first_open': daysSinceFirstOpen,
      'welcome_notifications_enabled': _welcomeNotificationsEnabled,
      'is_initialized': _isInitialized,
    };
  }

  /// Reset user data (for testing)
  Future<void> resetUserData() async {
    _appOpenCount = 0;
    _lastAppOpen = null;
    _firstAppOpen = null;
    await _prefs?.remove('app_open_count');
    await _prefs?.remove('last_app_open');
    await _prefs?.remove('first_app_open');
    debugPrint('🔄 User data reset');
  }

  /// Dispose resources
  void dispose() {
    _notifications = null;
    _prefs = null;
    _isInitialized = false;
    debugPrint('🗑️ WelcomeNotificationService disposed');
  }
}
