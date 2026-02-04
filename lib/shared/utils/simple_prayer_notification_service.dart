import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audio_service/audio_service.dart';
import 'simple_prayer_audio_service.dart';

/// Simple and reliable prayer notification service
/// This replaces the complex notification systems with a straightforward approach
class SimplePrayerNotificationService {
  static SimplePrayerNotificationService? _instance;
  static SimplePrayerNotificationService get instance => _instance ??= SimplePrayerNotificationService();

  FlutterLocalNotificationsPlugin? _notifications;
  SimplePrayerAudioService? _audioService;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Notification channel details
  static const String _channelId = 'simple_prayer_channel';
  static const String _channelName = 'تنبيهات الصلاة البسيطة';
  static const String _channelDescription = 'تنبيهات بسيطة وموثوقة لأوقات الصلاة';
  static const String _stopActionId = 'stop_adhan';
  static const String _repeatActionId = 'repeat_adhan';

  /// Initialize the service
  Future<void> initialize([GlobalKey<NavigatorState>? _navigatorKey]) async {
    if (_isInitialized) return;

    try {
      print('🔧 Initializing Simple Prayer Notification Service...');

      // Initialize timezone
      tz.initializeTimeZones();

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Initialize local notifications
      _notifications = FlutterLocalNotificationsPlugin();

      // Initialize audio service
      _audioService = SimplePrayerAudioService.instance;
      await _audioService!.initialize(_notifications!);

      // Setup notification channels
      await _createNotificationChannel();

      // Initialize notification settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_stat_athkark');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications!.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      print('✅ Simple Prayer Notification Service initialized successfully');

    } catch (e) {
      print('❌ Failed to initialize Simple Prayer Notification Service: $e');
      rethrow;
    }
  }

  /// Create notification channel
  Future<void> _createNotificationChannel() async {
    final androidImpl = _notifications?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    // Delete existing channel first (like welcome/adhkar services)
    await androidImpl.deleteNotificationChannel(_channelId);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: false, // Disabled to prevent double audio with programmatic playback
      enableVibration: true,
      enableLights: true,
    );

    await androidImpl.createNotificationChannel(channel);

    // Also create fallback channel
    await androidImpl.deleteNotificationChannel('prayer_fallback');

    const AndroidNotificationChannel fallbackChannel = AndroidNotificationChannel(
      'prayer_fallback',
      'تنبيهات الصلاة الاحتياطية',
      description: 'تنبيهات عند فشل الصوت',
      importance: Importance.high,
      playSound: false,
      enableVibration: true,
      enableLights: true,
    );

    await androidImpl.createNotificationChannel(fallbackChannel);
  }

  /// Schedule a prayer notification
  Future<bool> schedulePrayerNotification({
    required String prayerId,
    required String prayerName,
    required DateTime scheduledTime,
    bool isCustom = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('📅 Scheduling notification for: $prayerName at $scheduledTime (Custom: $isCustom)');

      // Recreate channel before scheduling (like welcome/adhkar services)
      await _createNotificationChannel();

      // Convert to local timezone
      final tz.TZDateTime localTime = tz.TZDateTime.from(scheduledTime, tz.local);

      // Create unique notification ID
      final int notificationId = _generateNotificationId(prayerId);

      // Create notification details with high priority and alarm category
      // Removed sound from notification to prevent double audio playback
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: false, // Disabled to prevent double audio with programmatic playback
        enableVibration: true,
        enableLights: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        autoCancel: false,
        ongoing: false,
        visibility: NotificationVisibility.public,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            _stopActionId,
            'إيقاف الأذان',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _repeatActionId,
            'تكرار بعد 10 دقائق',
            showsUserInterface: false,
          ),
        ],
        timeoutAfter: 300000, // Auto-dismiss after 5 minutes (in milliseconds)
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false, // Disabled to prevent double audio with programmatic playback
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Create payload with more detailed information
      final String payload = jsonEncode({
        'prayer_id': prayerId,
        'prayer_name': prayerName,
        'scheduled_time': scheduledTime.toIso8601String(),
        'is_custom': isCustom,
        'timestamp': DateTime.now().toIso8601String(),
        'notification_id': notificationId,
        'auto_adhan_played': false, // Will be set to true when alarm triggers
      });

      // Schedule the notification with exact timing
      await _notifications!.zonedSchedule(
        notificationId,
        'حان وقت صلاة $prayerName',
        'انقر لفتح التطبيق',
        localTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      // Store notification info for management
      await _storeNotificationInfo(notificationId, prayerId, prayerName, scheduledTime, isCustom);

      print('✅ Notification scheduled successfully for: $prayerName (ID: $notificationId)');
      return true;

    } catch (e) {
      print('❌ Failed to schedule notification for $prayerName: $e');
      return false;
    }
  }

  /// Cancel a specific notification
  Future<bool> cancelNotification(String prayerId) async {
    try {
      final int notificationId = _generateNotificationId(prayerId);
      await _notifications!.cancel(notificationId);
      await _removeNotificationInfo(notificationId);
      print('🗑️ Notification cancelled for: $prayerId');
      return true;
    } catch (e) {
      print('❌ Failed to cancel notification: $e');
      return false;
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications!.cancelAll();
      await _clearAllNotificationInfo();
      print('🗑️ All notifications cancelled');
    } catch (e) {
      print('❌ Failed to cancel all notifications: $e');
    }
  }

  /// Test notification immediately
  Future<bool> testNotification(String prayerName) async {
    try {
      print('🧪 Testing notification for: $prayerName');

      // Show immediate notification without audio for testing
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'test_notification',
        'اختبار الإشعارات',
        channelDescription: 'اختبار بدون صوت',
        importance: Importance.high,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
        enableLights: false,
        category: AndroidNotificationCategory.message,
      );

      const NotificationDetails details = NotificationDetails(android: androidDetails);

      await _notifications!.show(
        999999, // Test notification ID
        'اختبار الإشعار',
        'هذا اختبار لصحة عمل الإشعارات بدون صوت',
        details,
      );

      print('✅ Test notification sent for: $prayerName');
      return true;

    } catch (e) {
      print('❌ Test notification failed: $e');
      return false;
    }
  }

  /// Handle notification tap/action directly from the notification shade
  void _onNotificationTapped(NotificationResponse response) async {
    try {
      final String? payload = response.payload;
      if (payload == null) return;

      print('🔔 Notification tapped with payload: $payload');

      final Map<String, dynamic> data = jsonDecode(payload);
      final String prayerName =
          data['prayer_name'] ?? data['prayer'] ?? 'غير معروف';
      final bool isCustom = data['is_custom'] ?? false;
      final String? customPrayerId =
          data['prayer_id'] ?? data['customPrayerId'] as String?;

      print('📋 Notification details - Name: $prayerName, Custom: $isCustom, ID: $customPrayerId');

      if (response.actionId == _stopActionId) {
        if (response.id != null) {
          await _notifications?.cancel(response.id!);
        }
        await _stopAllAdhanPlayback();
        return;
      }

      if (response.actionId == _repeatActionId) {
        if (response.id != null) {
          await _notifications?.cancel(response.id!);
        }
        await _stopAllAdhanPlayback();
        await _scheduleRepeatReminder(
          prayerName: prayerName,
          prayerId: customPrayerId ?? prayerName,
          isCustom: isCustom,
        );
        return;
      }

      await _audioService?.playAdhan(prayerName);
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  Future<void> _stopAllAdhanPlayback() async {
    try {
      await _audioService?.stop();
    } catch (_) {}
    try {
      await AudioService.stop();
    } catch (_) {}
    try {
      await SimplePrayerAudioService.instance.stop();
    } catch (_) {}
  }

  Future<void> _scheduleRepeatReminder({
    required String prayerName,
    required String prayerId,
    required bool isCustom,
  }) async {
    if (_notifications == null) {
      return;
    }

    await _createNotificationChannel();

    final tz.TZDateTime scheduled =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    final int repeatId = DateTime.now().millisecondsSinceEpoch % 100000;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: true,
      enableLights: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
      autoCancel: false,
      ongoing: false,
      visibility: NotificationVisibility.public,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          _stopActionId,
          'إيقاف الأذان',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _repeatActionId,
          'تكرار بعد 10 دقائق',
          showsUserInterface: false,
        ),
      ],
      timeoutAfter: 300000,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String repeatPayload = jsonEncode({
      'prayer_id': prayerId,
      'prayer_name': prayerName,
      'is_custom': isCustom,
      'timestamp': DateTime.now().toIso8601String(),
      'repeat_request': true,
    });

    await _notifications!.zonedSchedule(
      repeatId,
      'موعد الأذان $prayerName',
      'سيتم التذكير مرة أخرى بعد 10 دقائق',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: repeatPayload,
    );

    print('🔁 Repeat adhan scheduled in 10 minutes for: $prayerName');
  }

  /// Show fallback notification when audio fails
  Future<void> _showFallbackNotification(String prayerName) async {
    try {
      await _notifications!.show(
        999998, // Unique ID for fallback notifications
        'صلاة $prayerName',
        'انقر لفتح التطبيق',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_fallback',
            'تنبيهات الصلاة الاحتياطية',
            channelDescription: 'تنبيهات عند فشل الصوت',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
          ),
        ),
      );
      print('📢 Fallback notification shown for: $prayerName');
    } catch (e) {
      print('❌ Even fallback notification failed: $e');
    }
  }

  /// Generate unique notification ID
  int _generateNotificationId(String prayerId) {
    return prayerId.hashCode.abs() % 100000; // Keep IDs reasonable
  }

  /// Store notification info for management
  Future<void> _storeNotificationInfo(
    int notificationId,
    String prayerId,
    String prayerName,
    DateTime scheduledTime,
    bool isCustom,
  ) async {
    final String key = 'notification_$notificationId';
    final Map<String, dynamic> info = {
      'notification_id': notificationId,
      'prayer_id': prayerId,
      'prayer_name': prayerName,
      'scheduled_time': scheduledTime.toIso8601String(),
      'is_custom': isCustom,
      'created_at': DateTime.now().toIso8601String(),
      'channel_id': _channelId,
    };

    await _prefs!.setString(key, jsonEncode(info));
    print('💾 Stored notification info for ID $notificationId: $info');
  }

  /// Remove notification info
  Future<void> _removeNotificationInfo(int notificationId) async {
    final String key = 'notification_$notificationId';
    await _prefs!.remove(key);
  }

  /// Clear all notification info
  Future<void> _clearAllNotificationInfo() async {
    final keys = _prefs!.getKeys().where((key) => key.startsWith('notification_'));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  /// Get all scheduled notifications
  Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
    final List<Map<String, dynamic>> notifications = [];
    final keys = _prefs!.getKeys().where((key) => key.startsWith('notification_'));

    for (final key in keys) {
      final String? infoJson = _prefs!.getString(key);
      if (infoJson != null) {
        try {
          final Map<String, dynamic> info = jsonDecode(infoJson);
          notifications.add(info);
        } catch (e) {
          print('Error parsing notification info: $e');
        }
      }
    }

    return notifications;
  }

  /// Dispose resources
  void dispose() {
    _audioService?.dispose();
    _audioService = null;
    _notifications = null;
    _prefs = null;
    _isInitialized = false;
    print('🗑️ Simple Prayer Notification Service disposed');
  }
}
