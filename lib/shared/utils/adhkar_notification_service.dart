import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/theme/colors.dart';
import 'unified_prayer_notification_service.dart';

/// Adhkar Notification Service
/// Manages notifications for morning and evening adhkar to engage users
class AdhkarNotificationService {
  static AdhkarNotificationService? _instance;
  static AdhkarNotificationService get instance =>
      _instance ??= AdhkarNotificationService();

  static const String _morningAdhkarId = 'morning_adhkar';
  static const String _eveningAdhkarId = 'evening_adhkar';
  static const String _dailyAdhkarId = 'daily_adhkar';
  static const String _adhkarChannelId = 'adhkar_reminders';
  static const String _adhkarChannelName = 'Adhkar Reminders';
  static const String _adhkarChannelDescription =
      'Daily adhkar reminders with morning, evening, and extra prompts.';

  FlutterLocalNotificationsPlugin? _notifications;
  SharedPreferences? _prefs;
  Timer? _dailyScheduler;
  bool _isInitialized = false;

  // Settings
  bool _morningEnabled = true;
  bool _eveningEnabled = true;
  bool _dailyEnabled = false;
  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _dailyTime = const TimeOfDay(hour: 12, minute: 0);

  // Getters
  bool get morningEnabled => _morningEnabled;
  bool get eveningEnabled => _eveningEnabled;
  bool get dailyEnabled => _dailyEnabled;
  TimeOfDay get morningTime => _morningTime;
  TimeOfDay get eveningTime => _eveningTime;
  TimeOfDay get dailyTime => _dailyTime;
  bool get isInitialized => _isInitialized;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _notifications = FlutterLocalNotificationsPlugin();

      await _initializeNotifications();

      // Load settings
      await _loadSettings();

      // Initialize timezone
      tz.initializeTimeZones();

      await _ensureNotificationPermission();
      await _createNotificationChannel();

      // Start daily scheduling
      _startDailyScheduler();

      _isInitialized = true;
      debugPrint('✅ AdhkarNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize AdhkarNotificationService: $e');
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

  Future<void> _ensureNotificationPermission() async {
    try {
      final android = _notifications
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        if (enabled != true) {
          await android.requestNotificationsPermission();
        }
        await android.requestExactAlarmsPermission();
      }

      final ios = _notifications
          ?.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        await ios.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to ensure adhkar notification permission: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    if (_notifications == null) return;

    final androidImpl = _notifications
        ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _adhkarChannelId,
      _adhkarChannelName,
      description: _adhkarChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: AppColors.primaryColor,
      showBadge: true,
    );

    await androidImpl.deleteNotificationChannel(_adhkarChannelId);
    await androidImpl.createNotificationChannel(channel);
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    _morningEnabled = _prefs?.getBool('adhkar_morning_enabled') ?? true;
    _eveningEnabled = _prefs?.getBool('adhkar_evening_enabled') ?? true;
    _dailyEnabled = _prefs?.getBool('adhkar_daily_enabled') ?? false;

    final morningHour = _prefs?.getInt('adhkar_morning_hour') ?? 6;
    final morningMinute = _prefs?.getInt('adhkar_morning_minute') ?? 0;
    _morningTime = TimeOfDay(hour: morningHour, minute: morningMinute);

    final eveningHour = _prefs?.getInt('adhkar_evening_hour') ?? 18;
    final eveningMinute = _prefs?.getInt('adhkar_evening_minute') ?? 0;
    _eveningTime = TimeOfDay(hour: eveningHour, minute: eveningMinute);

    final dailyHour = _prefs?.getInt('adhkar_daily_hour') ?? 12;
    final dailyMinute = _prefs?.getInt('adhkar_daily_minute') ?? 0;
    _dailyTime = TimeOfDay(hour: dailyHour, minute: dailyMinute);
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    await _prefs?.setBool('adhkar_morning_enabled', _morningEnabled);
    await _prefs?.setBool('adhkar_evening_enabled', _eveningEnabled);
    await _prefs?.setBool('adhkar_daily_enabled', _dailyEnabled);

    await _prefs?.setInt('adhkar_morning_hour', _morningTime.hour);
    await _prefs?.setInt('adhkar_morning_minute', _morningTime.minute);
    await _prefs?.setInt('adhkar_evening_hour', _eveningTime.hour);
    await _prefs?.setInt('adhkar_evening_minute', _eveningTime.minute);
    await _prefs?.setInt('adhkar_daily_hour', _dailyTime.hour);
    await _prefs?.setInt('adhkar_daily_minute', _dailyTime.minute);
  }

  /// Start daily scheduler
  void _startDailyScheduler() {
    _dailyScheduler?.cancel();
    _dailyScheduler = Timer.periodic(const Duration(hours: 1), (_) {
      _scheduleTodaysAdhkar();
    });

    // Schedule immediately
    _scheduleTodaysAdhkar();
  }

  /// Schedule today's adhkar notifications
  Future<void> _scheduleTodaysAdhkar() async {
    final now = DateTime.now();

    // Cancel existing adhkar notifications
    await _cancelAllAdhkarNotifications();

    // Schedule morning adhkar
    if (_morningEnabled) {
      final morningDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _morningTime.hour,
        _morningTime.minute,
      );

      // If morning time has passed today, schedule for tomorrow
      final scheduledTime = morningDateTime.isAfter(now)
          ? morningDateTime
          : morningDateTime.add(const Duration(days: 1));

      await _scheduleAdhkarNotification(
        id: _morningAdhkarId,
        title: 'أذكار الصباح ☀️',
        body: 'ابدأ يومك بالأذكار والأدعية',
        subtitle: 'اللهم إنا نسألك من فضلك',
        scheduledTime: scheduledTime,
        categoryId: 1, // Morning adhkar category
      );
    }

    // Schedule evening adhkar
    if (_eveningEnabled) {
      final eveningDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _eveningTime.hour,
        _eveningTime.minute,
      );

      // If evening time has passed today, schedule for tomorrow
      final scheduledTime = eveningDateTime.isAfter(now)
          ? eveningDateTime
          : eveningDateTime.add(const Duration(days: 1));

      await _scheduleAdhkarNotification(
        id: _eveningAdhkarId,
        title: 'أذكار المساء 🌙',
        body: 'أنهِ يومك بالأذكار والتسبيح',
        subtitle: 'سبحان الله وبحمده',
        scheduledTime: scheduledTime,
        categoryId: 2, // Evening adhkar category
      );
    }

    // Schedule daily adhkar reminder
    if (_dailyEnabled) {
      final dailyDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _dailyTime.hour,
        _dailyTime.minute,
      );

      // If daily time has passed today, schedule for tomorrow
      final scheduledTime = dailyDateTime.isAfter(now)
          ? dailyDateTime
          : dailyDateTime.add(const Duration(days: 1));

      await _scheduleAdhkarNotification(
        id: _dailyAdhkarId,
        title: 'تذكير بالأذكار 📿',
        body: 'خذ دقيقة للأذكار والتسبيح',
        subtitle: 'الذكر يرفع الدرجات',
        scheduledTime: scheduledTime,
        categoryId: 0, // General reminder
      );
    }
  }

  /// Schedule a single adhkar notification
  Future<bool> _scheduleAdhkarNotification({
    required String id,
    required String title,
    required String body,
    required String subtitle,
    required DateTime scheduledTime,
    required int categoryId,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      await _ensureNotificationPermission();

      // Recreate channel before scheduling (like welcome service)
      await _createNotificationChannel();

      final tz.TZDateTime localTime = tz.TZDateTime.from(scheduledTime, tz.local);

      // Create engaging notification content
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _adhkarChannelId,
        _adhkarChannelName,
        channelDescription: _adhkarChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: AppColors.primaryColor,
        ledColor: AppColors.primaryColor,
        ledOnMs: 1000,
        ledOffMs: 500,
        icon: '@drawable/ic_stat_athkark',
        ticker: 'Athkark adhkar',
        category: AndroidNotificationCategory.reminder,
        fullScreenIntent: false,
        autoCancel: true,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          body,
          summaryText: subtitle,
          contentTitle: title,
          htmlFormatContent: false,
          htmlFormatTitle: false,
        ),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'adhkar_reminder.caf',
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Create payload for navigation
      final payload = jsonEncode({
        'type': 'adhkar_reminder',
        'adhkar_id': id,
        'category_id': categoryId,
        'title': title,
        'scheduled_time': scheduledTime.toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Generate unique notification ID
      final notificationId = id.hashCode + scheduledTime.millisecondsSinceEpoch.hashCode;

      await _notifications!.zonedSchedule(
        notificationId,
        title,
        body,
        localTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('✅ Scheduled adhkar notification: $title at $scheduledTime');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule adhkar notification: $e');
      return false;
    }
  }

  /// Show adhkar notification immediately (for testing)
  Future<void> _showAdhkarNotification({
    required String title,
    required String body,
    required String subtitle,
    required int categoryId,
    String? adhkarId,
  }) async {
    try {
      await _ensureNotificationPermission();

      // Recreate channel before showing (like welcome service)
      await _createNotificationChannel();

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _adhkarChannelId,
        _adhkarChannelName,
        channelDescription: _adhkarChannelDescription,
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
        ticker: 'Athkark adhkar',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: subtitle,
        ),
        autoCancel: true,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        fullScreenIntent: false,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({
        'type': 'adhkar_reminder',
        'adhkar_id': adhkarId ?? 'test',
        'category_id': categoryId,
        'title': title,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _notifications!.show(
        999999 + Random().nextInt(1000), // Unique notification ID
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Adhkar notification shown: $title');
    } catch (e) {
      debugPrint('❌ Failed to show adhkar notification: $e');
    }
  }

  /// Cancel all adhkar notifications
  Future<void> _cancelAllAdhkarNotifications() async {
    try {
      // Cancel specific adhkar notifications
      final ids = [
        _morningAdhkarId.hashCode,
        _eveningAdhkarId.hashCode,
        _dailyAdhkarId.hashCode,
      ];

      for (final id in ids) {
        await _notifications?.cancel(id);
      }

      debugPrint('🗑️ Cancelled all adhkar notifications');
    } catch (e) {
      debugPrint('❌ Error cancelling adhkar notifications: $e');
    }
  }

  /// Update morning adhkar settings
  Future<void> setMorningAdhkar({required bool enabled, TimeOfDay? time}) async {
    _morningEnabled = enabled;
    if (time != null) _morningTime = time;
    await _saveSettings();
    await _scheduleTodaysAdhkar();
  }

  /// Update evening adhkar settings
  Future<void> setEveningAdhkar({required bool enabled, TimeOfDay? time}) async {
    _eveningEnabled = enabled;
    if (time != null) _eveningTime = time;
    await _saveSettings();
    await _scheduleTodaysAdhkar();
  }

  /// Update daily adhkar settings
  Future<void> setDailyAdhkar({required bool enabled, TimeOfDay? time}) async {
    _dailyEnabled = enabled;
    if (time != null) _dailyTime = time;
    await _saveSettings();
    await _scheduleTodaysAdhkar();
  }

  /// Test adhkar notification immediately
  Future<bool> testAdhkarNotification(String type) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      String title, body, subtitle, id;
      int categoryId;

      switch (type) {
        case 'morning':
          title = '🧪 اختبار: أذكار الصباح';
          body = 'هذا اختبار لتذكير أذكار الصباح';
          subtitle = 'اللهم إنا نسألك من فضلك';
          id = 'test_morning';
          categoryId = 1;
          break;
        case 'evening':
          title = '🧪 اختبار: أذكار المساء';
          body = 'هذا اختبار لتذكير أذكار المساء';
          subtitle = 'سبحان الله وبحمده';
          id = 'test_evening';
          categoryId = 2;
          break;
        default:
          title = '🧪 اختبار: تذكير الأذكار';
          body = 'هذا اختبار لتذكير الأذكار';
          subtitle = 'الذكر يرفع الدرجات';
          id = 'test_daily';
          categoryId = 0;
      }

      await _showAdhkarNotification(
        title: title,
        body: body,
        subtitle: subtitle,
        categoryId: categoryId,
        adhkarId: id,
      );

      debugPrint('✅ Test adhkar notification shown for $type');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to show test adhkar notification: $e');
      return false;
    }
  }

  /// Get next adhkar notification time
  DateTime? getNextAdhkarTime() {
    final now = DateTime.now();
    final List<DateTime> times = [];

    if (_morningEnabled) {
      final morning = DateTime(now.year, now.month, now.day, _morningTime.hour, _morningTime.minute);
      times.add(morning.isAfter(now) ? morning : morning.add(const Duration(days: 1)));
    }

    if (_eveningEnabled) {
      final evening = DateTime(now.year, now.month, now.day, _eveningTime.hour, _eveningTime.minute);
      times.add(evening.isAfter(now) ? evening : evening.add(const Duration(days: 1)));
    }

    if (_dailyEnabled) {
      final daily = DateTime(now.year, now.month, now.day, _dailyTime.hour, _dailyTime.minute);
      times.add(daily.isAfter(now) ? daily : daily.add(const Duration(days: 1)));
    }

    if (times.isEmpty) return null;

    times.sort();
    return times.first;
  }

  /// Get adhkar statistics
  Map<String, dynamic> getStatistics() {
    return {
      'morning_enabled': _morningEnabled,
      'evening_enabled': _eveningEnabled,
      'daily_enabled': _dailyEnabled,
      'morning_time': '${_morningTime.hour}:${_morningTime.minute.toString().padLeft(2, '0')}',
      'evening_time': '${_eveningTime.hour}:${_eveningTime.minute.toString().padLeft(2, '0')}',
      'daily_time': '${_dailyTime.hour}:${_dailyTime.minute.toString().padLeft(2, '0')}',
      'next_notification': getNextAdhkarTime()?.toIso8601String(),
      'is_initialized': _isInitialized,
    };
  }

  /// Dispose resources
  void dispose() {
    _dailyScheduler?.cancel();
    _notifications = null;
    _prefs = null;
    _isInitialized = false;
    debugPrint('🗑️ AdhkarNotificationService disposed');
  }
}
