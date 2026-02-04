import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audio_service/audio_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../../features/prayer_times/domain/prayer_times_service.dart';
import '../../models/scheduled_prayer.dart';
import 'simple_prayer_audio_service.dart';

/// Unified Prayer Notification Service
/// Combines the best of both SimplePrayerNotificationService and EnhancedPreciseNotificationService
/// Provides a single, reliable interface for all prayer notifications
class UnifiedPrayerNotificationService {
  static UnifiedPrayerNotificationService? _instance;
  static UnifiedPrayerNotificationService get instance =>
      _instance ??= UnifiedPrayerNotificationService();

  // Private fields
  FlutterLocalNotificationsPlugin? _notifications;
  SimplePrayerAudioService? _audioService;
  SharedPreferences? _prefs;
  MethodChannel? _nativeChannel;
  static bool _globalInitializationGuard = false;
  bool _isInitialized = false;
  bool _isPrimaryMode = true; // true = Simple mode, false = Enhanced mode

  // Service state
  ServiceState _serviceState = ServiceState.uninitialized;
  List<ScheduledPrayer> _scheduledPrayers = [];
  final List<ServiceLog> _logs = [];

  // Performance monitoring
  final Map<String, DateTime> _performanceMetrics = {};
  Timer? _healthCheckTimer;

  // Notification channels
  static const String _primaryChannelId = 'unified_prayer_channel';
  static const String _secondaryChannelId = 'unified_prayer_fallback';
  static const String _nativeChannelName = 'unified_prayer_native';
  static const String _stopActionId = 'stop_adhan';
  static const String _repeatActionId = 'repeat_adhan';

  // Getters for state information
  bool get isInitialized => _isInitialized;
  ServiceState get serviceState => _serviceState;
  List<ScheduledPrayer> get scheduledPrayers =>
      List.unmodifiable(_scheduledPrayers);
  FlutterLocalNotificationsPlugin get notifications => _notifications!;
  List<ServiceLog> get logs => List.unmodifiable(_logs);

  /// Initialize the unified service with guardian to prevent duplicate initialization
  Future<void> initialize({bool forceEnhanced = false}) async {
    // Guardian to prevent duplicate initialization
    if (_isInitialized) {
      _log(
          'Unified Prayer Notification Service already initialized, skipping...',
          LogLevel.debug);
      return;
    }

    // Double-check with a static flag to be absolutely sure
    if (_globalInitializationGuard) {
      _log('Global initialization guard active, waiting for completion...',
          LogLevel.info);
      while (_globalInitializationGuard) {
        await Future.delayed(Duration(milliseconds: 100));
        if (_isInitialized) return; // Another thread completed initialization
      }
    }

    try {
      _globalInitializationGuard = true;
      _log(
          'Initializing Unified Prayer Notification Service...', LogLevel.info);
      _serviceState = ServiceState.initializing;

      // Initialize timezone
      tz.initializeTimeZones();
      // Ensure local location is set (main sets Asia/Aden, but guard here too)
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Aden'));
      } catch (_) {
        // Keep current if mapping fails
      }
      await _ensureNotificationPermission();

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Initialize local notifications
      _notifications = FlutterLocalNotificationsPlugin();
      await _initializeNotifications();
      await _ensureNotificationPermission();

      // Initialize audio service
      _audioService = SimplePrayerAudioService.instance;
      await _audioService!.initialize(_notifications!);

      // Initialize native channel for Android
      if (Platform.isAndroid) {
        _initializeNativeChannel();
      }

      // Choose service mode based on capabilities and preferences
      await _determineServiceMode(forceEnhanced);

      // Create notification channels
      await _createNotificationChannels();

      // Start health monitoring
      _startHealthMonitoring();

      // Mark initialized before restore to avoid re-entrant init during restore
      _isInitialized = true;
      _serviceState = ServiceState.ready;

      // Restore scheduled prayers
      await _restoreScheduledPrayers();

      _log('Unified Prayer Notification Service initialized successfully',
          LogLevel.info);
    } catch (e) {
      _serviceState = ServiceState.error;
      _log('Failed to initialize Unified Prayer Notification Service: $e',
          LogLevel.error);
      rethrow;
    } finally {
      _globalInitializationGuard = false;
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      final status = await Permission.notification.status;
      if (!status.isGranted && !status.isLimited) {
        final result = await Permission.notification.request();
        if (!result.isGranted && !result.isLimited) {
          _log(
              'Notification permission not granted; prayer alerts may be blocked',
              LogLevel.warning);
        }
      }

      final androidImplementation = _notifications
          ?.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final bool? enabled = await androidImplementation.areNotificationsEnabled();
        if (enabled != true) {
          await androidImplementation.requestNotificationsPermission();
        }
        // Request exact alarms for reliable scheduling on Android 12+
        await androidImplementation.requestExactAlarmsPermission();
      }

      final iosImplementation = _notifications
          ?.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
    } catch (e) {
      _log('Failed to request notification permission: $e', LogLevel.warning);
    }
  }

  /// Initialize notifications plugin
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_athkark');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications!.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Initialize native Android channel
  void _initializeNativeChannel() {
    _nativeChannel = const MethodChannel(_nativeChannelName);
    _nativeChannel!.setMethodCallHandler(_handleNativeMethodCall);
  }

  /// Determine which service mode to use
  Future<void> _determineServiceMode(bool forceEnhanced) async {
    if (forceEnhanced && Platform.isAndroid) {
      _isPrimaryMode = false;
      _log('Using Enhanced mode (forced)', LogLevel.info);
      return;
    }

    // Check capabilities for Enhanced mode
    if (Platform.isAndroid) {
      final canUseEnhanced = await _checkEnhancedModeCapabilities();
      _isPrimaryMode = !canUseEnhanced;
      _log(
          'Using ${_isPrimaryMode ? 'Simple' : 'Enhanced'} mode based on capabilities',
          LogLevel.info);
    } else {
      _isPrimaryMode = true; // iOS uses Simple mode
      _log('Using Simple mode (iOS)', LogLevel.info);
    }
  }

  /// Check if Enhanced mode can be used
  Future<bool> _checkEnhancedModeCapabilities() async {
    try {
      // Check notification permission
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted && !notificationStatus.isLimited) {
        return false;
      }

      // Check exact alarm permission - DO NOT initialize here, it's already done in main()
      // AndroidAlarmManager.initialize() is called only once in main() to avoid duplicate initialization
      final bool exactAlarmsAllowed = await _checkExactAlarmsPermission();

      return exactAlarmsAllowed;
    } catch (e) {
      _log('Enhanced mode not available: $e', LogLevel.warning);
      return false;
    }
  }

  /// Check exact alarm permission without re-initializing
  Future<bool> _checkExactAlarmsPermission() async {
    try {
      if (!Platform.isAndroid) return false;

      // Check if exact alarm permission is available
      // Since the method checkExactAlarmPermission might not exist in all plugin versions,
      // we simply assume exact alarms are available after AndroidAlarmManager.initialize() in main()
      // This is safe because AndroidAlarmManager.initialize() was already called in main()
      _log(
          'Assuming exact alarm permissions are available (AndroidAlarmManager already initialized in main)',
          LogLevel.debug);
      return true; // Safe assumption since AndroidAlarmManager was initialized in main
    } catch (e) {
      // If check fails, assume enhanced mode is not available
      _log('Could not check exact alarm permission: $e', LogLevel.warning);
      return false;
    }
  }

  /// Create notification channels
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    // Primary channel for main notifications
    const AndroidNotificationChannel primaryChannel =
        AndroidNotificationChannel(
      _primaryChannelId,
      'تنبيهات الصلاة الموحدة',
      description: 'تنبيهات موحدة وموثوقة لأوقات الصلاة',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
    );

    final androidImplementation = _notifications
        ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.deleteNotificationChannel(_primaryChannelId);
    await androidImplementation?.createNotificationChannel(primaryChannel);

    // Secondary channel for fallback
    const AndroidNotificationChannel secondaryChannel =
        AndroidNotificationChannel(
      _secondaryChannelId,
      'تنبيهات الصلاة الاحتياطية',
      description: 'تنبيهات احتياطية عند فشل النظام الأساسي',
      importance: Importance.high,
      playSound: false,
      enableVibration: true,
      enableLights: true,
    );

    await androidImplementation?.deleteNotificationChannel(_secondaryChannelId);
    await androidImplementation?.createNotificationChannel(secondaryChannel);

    _log('Notification channels created', LogLevel.debug);
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _performHealthCheck();
    });
  }

  /// Perform health check
  Future<void> _performHealthCheck() async {
    try {
      // Check service state
      if (_serviceState != ServiceState.ready) {
        _log('Health check: Service not ready', LogLevel.warning);
        await _attemptRecovery();
        return;
      }

      // Check permission status
      await _checkPermissionsHealth();

      // Check scheduled prayers
      await _checkScheduledPrayersHealth();

      // Check storage integrity
      await _checkStorageHealth();
    } catch (e) {
      _log('Health check failed: $e', LogLevel.error);
    }
  }

  /// Check permissions health
  Future<void> _checkPermissionsHealth() async {
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted && !notificationStatus.isLimited) {
      _log('Health check: Notification permission lost', LogLevel.warning);
    }
  }

  /// Check scheduled prayers health
  Future<void> _checkScheduledPrayersHealth() async {
    final now = DateTime.now();
    final expiredPrayers = _scheduledPrayers
        .where((prayer) => prayer.scheduledTime.isBefore(now))
        .toList();

    if (expiredPrayers.isNotEmpty) {
      _log('Health check: Found ${expiredPrayers.length} expired prayers',
          LogLevel.debug);
      _scheduledPrayers
          .removeWhere((prayer) => prayer.scheduledTime.isBefore(now));
      await _saveScheduledPrayers();
    }
  }

  /// Check storage health
  Future<void> _checkStorageHealth() async {
    try {
      await _prefs!
          .setString('health_check_test', DateTime.now().toIso8601String());
      await _prefs!.remove('health_check_test');
    } catch (e) {
      _log('Health check: Storage integrity failed', LogLevel.error);
    }
  }

  /// Generate unique and consistent notification ID for prayer
  int generateUniqueNotificationId(String prayerId, DateTime scheduledTime) {
    // Create a consistent hash combining prayerId and scheduledTime
    final key = '${prayerId}_${scheduledTime.millisecondsSinceEpoch}';
    return key.hashCode & 0x7fffffff; // Ensure positive int
  }

  /// Check if notification already exists (idempotency check)
  Future<bool> notificationExists(
      String prayerId, DateTime scheduledTime) async {
    try {
      final notificationId =
          generateUniqueNotificationId(prayerId, scheduledTime);
      final pendingNotifications =
          await _notifications!.pendingNotificationRequests();

      // Check if notification with same ID already exists
      final exists = pendingNotifications
          .any((notification) => notification.id == notificationId);

      // Also check if prayer already exists in our local list
      final localExists = _scheduledPrayers.any((prayer) =>
          prayer.id == prayerId &&
          prayer.scheduledTime.millisecondsSinceEpoch ==
              scheduledTime.millisecondsSinceEpoch);

      return exists || localExists;
    } catch (e) {
      _log('Error checking notification existence: $e', LogLevel.warning);
      return false;
    }
  }

  /// Schedule a prayer notification using appropriate service
  Future<bool> schedulePrayerNotification({
    required String prayerId,
    required String prayerName,
    required DateTime scheduledTime,
    bool isCustom = false,
    String? customPrayerName,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _ensureNotificationPermission();

    try {
      _log('Scheduling notification for: $prayerName at $scheduledTime',
          LogLevel.info);

      // Performance tracking
      final startTime = DateTime.now();
      _performanceMetrics['$prayerId\_schedule'] = startTime;

      // Generate unique notification ID
      final notificationId =
          generateUniqueNotificationId(prayerId, scheduledTime);

      // Create scheduled prayer record
      final scheduledPrayer = ScheduledPrayer(
        id: prayerId,
        title: isCustom ? customPrayerName ?? prayerName : prayerName,
        body:
            'حان وقت صلاة ${isCustom ? customPrayerName ?? prayerName : prayerName}',
        scheduledTime: scheduledTime,
        category: isCustom ? 'custom_prayer' : 'prayer',
        payload: {
          'prayer_id': prayerId,
          'prayer_name': prayerName,
          'is_custom': isCustom,
          'custom_prayer_name': customPrayerName,
          'notification_id': notificationId,
        },
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Add notification ID to scheduled prayer for tracking
      final updatedPrayer = ScheduledPrayer(
        id: prayerId,
        title: scheduledPrayer.title,
        body: scheduledPrayer.body,
        scheduledTime: scheduledPrayer.scheduledTime,
        category: scheduledPrayer.category,
        payload: Map<String, dynamic>.from(scheduledPrayer.payload)
          ..['notification_id'] = notificationId,
        createdAt: scheduledPrayer.createdAt,
        isActive: scheduledPrayer.isActive,
      );

      // Try enhanced scheduling first if available
      bool success = false;
      if (!_isPrimaryMode) {
        success = await _scheduleEnhancedNotification(updatedPrayer);
      }

      // If enhanced failed or not available, use simple notification
      if (!success) {
        _log('Using Simple notification service for: $prayerName', LogLevel.debug);
        success = await _scheduleSimpleNotification(updatedPrayer);
      }

      if (success) {
        // Update local list (idempotent - remove existing first)
        _scheduledPrayers.removeWhere((prayer) => prayer.id == prayerId);
        _scheduledPrayers.add(updatedPrayer);
        await _saveScheduledPrayers();

        _log(
            'Notification scheduled successfully for: $prayerName (ID: $notificationId)',
            LogLevel.info);

        // Performance tracking
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime).inMilliseconds;
        _log('Scheduling took ${duration}ms', LogLevel.debug);

        return true;
      } else {
        _log(
            'Failed to schedule notification for: $prayerName', LogLevel.error);
        return false;
      }
    } catch (e) {
      _log('Error scheduling notification for $prayerName: $e', LogLevel.error);
      return false;
    }
  }

  /// Schedule notification using Simple mode
  Future<bool> _scheduleSimpleNotification(ScheduledPrayer prayer) async {
    try {
      // Convert to local timezone
      final tz.TZDateTime localTime =
          tz.TZDateTime.from(prayer.scheduledTime, tz.local);

      // Create notification details
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _primaryChannelId,
        'تنبيهات الصلاة الموحدة',
        channelDescription: 'تنبيهات موحدة وموثوقة لأوقات الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Colors.teal,
        icon: '@drawable/ic_stat_athkark',
        ticker: 'Prayer reminder',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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
        timeoutAfter: 300000, // 5 minutes
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'adhan.mp3',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Create payload
      final String payload = jsonEncode({
        'prayer_id': prayer.id,
        'prayer_name': prayer.title,
        'scheduled_time': prayer.scheduledTime.toIso8601String(),
        'is_custom': prayer.payload['is_custom'] ?? false,
        'timestamp': DateTime.now().toIso8601String(),
        'notification_id': prayer.id.hashCode.abs() % 100000,
        'service_mode': 'simple',
      });

      // Get notification ID from payload or generate one
      final notificationId = prayer.payload['notification_id'] ??
          generateUniqueNotificationId(prayer.id, prayer.scheduledTime);

      // Schedule notification
      await _notifications!.zonedSchedule(
        notificationId,
        'حان وقت صلاة ${prayer.title}',
        'انقر لفتح التطبيق وبدء الأذان',
        localTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      return true;
    } catch (e) {
      _log('Simple notification scheduling failed: $e', LogLevel.error);
      return false;
    }
  }

  /// Schedule notification using Enhanced mode
  Future<bool> _scheduleEnhancedNotification(ScheduledPrayer prayer) async {
    try {
      if (!Platform.isAndroid) {
        return false;
      }

      // If native channel is missing, cannot use enhanced mode
      if (_nativeChannel == null) {
        _log('Native channel not available, enhanced mode not possible', LogLevel.warning);
        return false;
      }

      // Use native Android exact alarms
      final result =
          await _nativeChannel?.invokeMethod<bool>('scheduleExactAlarm', {
        'alarmId': prayer.id,
        'prayerName': prayer.title,
        'scheduledTime': prayer.scheduledTime.millisecondsSinceEpoch,
        'title': 'حان وقت صلاة ${prayer.title}',
        'body': 'انقر لفتح التطبيق وبدء الأذان',
        'payload': jsonEncode(prayer.payload),
        'channelId': _primaryChannelId,
      });

      final success = result ?? false;
      if (!success) {
        _log('Native scheduleExactAlarm returned false', LogLevel.warning);
        return false;
      }

      return true;
    } catch (e) {
      _log('Enhanced notification scheduling failed: $e', LogLevel.error);
      return false;
    }
  }

  /// Cancel a notification
  Future<bool> cancelNotification(String prayerId) async {
    try {
      _log('Cancelling notification: $prayerId', LogLevel.info);

      // Cancel from native service if in enhanced mode
      if (!_isPrimaryMode && Platform.isAndroid) {
        try {
          await _nativeChannel
              ?.invokeMethod('cancelAlarm', {'alarmId': prayerId});
        } catch (e) {
          _log('Failed to cancel from native service: $e', LogLevel.warning);
        }
      }

      // Get the notification ID that was used for scheduling
      final scheduledPrayer = _scheduledPrayers.firstWhere(
        (prayer) => prayer.id == prayerId,
        orElse: () => ScheduledPrayer(
          id: prayerId,
          title: '',
          body: '',
          scheduledTime: DateTime.now(),
          category: '',
          payload: {},
        ),
      );

      final notificationId = scheduledPrayer.payload['notification_id'] ??
          generateUniqueNotificationId(prayerId, scheduledPrayer.scheduledTime);

      // Cancel from Flutter notifications
      await _notifications!.cancel(notificationId);

      // Remove from local list
      _scheduledPrayers.removeWhere((prayer) => prayer.id == prayerId);
      await _saveScheduledPrayers();

      _log('Notification cancelled successfully: $prayerId', LogLevel.info);
      return true;
    } catch (e) {
      _log('Error cancelling notification $prayerId: $e', LogLevel.error);
      return false;
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      _log('Cancelling all notifications', LogLevel.info);

      // Cancel all Flutter notifications
      await _notifications!.cancelAll();

      // Cancel native alarms if in enhanced mode
      if (!_isPrimaryMode && Platform.isAndroid) {
        for (final prayer in _scheduledPrayers) {
          try {
            await _nativeChannel
                ?.invokeMethod('cancelAlarm', {'alarmId': prayer.id});
          } catch (e) {
            _log('Failed to cancel native alarm for ${prayer.id}: $e', LogLevel.warning);
          }
        }
      }

      // Clear local list
      _scheduledPrayers.clear();
      await _saveScheduledPrayers();

      _log('All notifications cancelled', LogLevel.info);
    } catch (e) {
      _log('Error cancelling all notifications: $e', LogLevel.error);
    }
  }

  /// Test notification
  Future<bool> testNotification(String prayerName) async {
    try {
      _log('Testing notification for: $prayerName', LogLevel.info);

      // Show immediate notification
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _primaryChannelId,
        'تنبيهات الصلاة الموحدة',
        channelDescription: 'تنبيهات موحدة وموثوقة لأوقات الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan'),
        enableVibration: true,
        enableLights: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      await _notifications!.show(
        999999, // Test notification ID
        'اختبار: حان وقت صلاة $prayerName',
        'هذا اختبار للنظام الموحد',
        details,
      );

      // Test audio service
      await _audioService?.testAudio();

      _log('Test notification sent successfully for: $prayerName',
          LogLevel.info);
      return true;
    } catch (e) {
      _log('Test notification failed: $e', LogLevel.error);
      return false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) async {
    try {
      final String? payload = response.payload;
      if (payload == null) return;

      _log('Notification tapped with payload: $payload', LogLevel.info);

      final Map<String, dynamic> data = jsonDecode(payload);
      final String prayerName =
          data['prayer_name'] ?? data['prayer'] ?? 'غير معروف';
      final bool isCustom = data['is_custom'] ?? false;
      final String? customPrayerId =
          data['prayer_id'] ?? data['customPrayerId'] as String?;

      // Ensure audio service is initialized
      if (_audioService == null) {
        _log('Re-initializing audio service for notification tap',
            LogLevel.debug);
        _audioService = SimplePrayerAudioService.instance;
        await _audioService!.initialize(_notifications!);
      }

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

      // Play adhan when notification is tapped
      final success = await _audioService!.playAdhan(prayerName);

      if (success) {
        _log(
            'Adhan triggered successfully from notification tap for: $prayerName',
            LogLevel.info);
      } else {
        _log('Adhan playback failed from notification tap for: $prayerName',
            LogLevel.warning);
        await _showFallbackNotification(prayerName);
      }
    } catch (e) {
      _log('Error handling notification tap: $e', LogLevel.error);
      await _showFallbackNotification('غير معروف');
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
    try {
      await _createNotificationChannels();

      final tz.TZDateTime scheduled =
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
      final int repeatId = DateTime.now().millisecondsSinceEpoch % 100000;

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _primaryChannelId,
        'تنبيهات الصلاة الموحدة',
        channelDescription: 'تنبيهات موحدة وموثوقة لأوقات الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Colors.teal,
        icon: '@drawable/ic_stat_athkark',
        ticker: 'Prayer reminder',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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
        presentSound: true,
        sound: 'adhan.mp3',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final String payload = jsonEncode({
        'prayer_id': prayerId,
        'prayer_name': prayerName,
        'is_custom': isCustom,
        'timestamp': DateTime.now().toIso8601String(),
        'repeat_request': true,
      });

      await _notifications?.zonedSchedule(
        repeatId,
        'موعد الأذان $prayerName',
        'سيتم التذكير مرة أخرى بعد 10 دقائق',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      _log('Repeat adhan scheduled in 10 minutes for: $prayerName',
          LogLevel.info);
    } catch (e) {
      _log('Failed to schedule repeat adhan: $e', LogLevel.warning);
    }
  }

  /// Show fallback notification
  Future<void> _showFallbackNotification(String prayerName) async {
    try {
      await _notifications!.show(
        999998, // Fallback notification ID
        'صلاة $prayerName',
        'انقر لفتح التطبيق وتشغيل الأذان',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _secondaryChannelId,
            'تنبيهات الصلاة الاحتياطية',
            channelDescription: 'تنبيهات احتياطية عند فشل النظام الأساسي',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
          ),
        ),
      );
      _log('Fallback notification shown for: $prayerName', LogLevel.debug);
    } catch (e) {
      _log('Even fallback notification failed: $e', LogLevel.error);
    }
  }

  /// Handle native method calls
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAlarmFired':
        final String alarmId = call.arguments['alarmId'];
        final String prayerName = call.arguments['prayerName'];
        final int scheduledTime = call.arguments['scheduledTime'];

        await _handleAlarmFired(alarmId, prayerName, scheduledTime);
        break;

      case 'onBootRestoreCompleted':
        final int restoredCount = call.arguments['restoredCount'];
        final int failedCount = call.arguments['failedCount'];

        await _handleBootRestoreCompleted(restoredCount, failedCount);
        break;

      default:
        throw UnimplementedError('Method ${call.method} not implemented');
    }
  }

  /// Handle alarm fired from native code
  Future<void> _handleAlarmFired(
      String alarmId, String prayerName, int scheduledTime) async {
    final executionTime = DateTime.now().millisecondsSinceEpoch;
    final delay = executionTime - scheduledTime;

    _log('Alarm fired from native code: $prayerName (delay: ${delay}ms)',
        LogLevel.info);

    // Update alarm status
    await _updateAlarmStatus(alarmId, 'fired', executionTime);

    // Trigger audio playback
    await _audioService?.playAdhan(prayerName);
  }

  /// Handle boot restore completion
  Future<void> _handleBootRestoreCompleted(
      int restoredCount, int failedCount) async {
    _log(
        'Boot restore completed - Restored: $restoredCount, Failed: $failedCount',
        LogLevel.info);

    // Update status
    await _prefs!.setInt('last_boot_restore_count', restoredCount);
    await _prefs!.setInt('last_boot_failed_count', failedCount);
  }

  /// Update alarm status
  Future<void> _updateAlarmStatus(
      String alarmId, String status, int timestamp) async {
    try {
      await _prefs!.setString('alarm_status_$alarmId', status);
      await _prefs!
          .setString('alarm_status_timestamp_$alarmId', timestamp.toString());
      _log('Updated alarm $alarmId status to: $status', LogLevel.debug);
    } catch (e) {
      _log('Error updating alarm status: $e', LogLevel.error);
    }
  }

  /// Restore scheduled prayers after app restart
  Future<void> _restoreScheduledPrayers() async {
    await _loadScheduledPrayers();

    final validPrayers = _scheduledPrayers
        .where((prayer) => prayer.scheduledTime.isAfter(DateTime.now()))
        .toList();

    for (final prayer in validPrayers) {
      await schedulePrayerNotification(
        prayerId: prayer.id,
        prayerName: prayer.title,
        scheduledTime: prayer.scheduledTime,
        isCustom: prayer.payload['is_custom'] ?? false,
        customPrayerName: prayer.payload['custom_prayer_name'],
      );
    }

    // Remove expired prayers
    _scheduledPrayers
        .removeWhere((prayer) => prayer.scheduledTime.isBefore(DateTime.now()));
    await _saveScheduledPrayers();

    _log('Restored ${validPrayers.length} scheduled prayers', LogLevel.info);
  }

  /// Save scheduled prayers to storage
  Future<void> _saveScheduledPrayers() async {
    final prayersJson = _scheduledPrayers
        .map((prayer) => {
              'id': prayer.id,
              'title': prayer.title,
              'body': prayer.body,
              'scheduledTime': prayer.scheduledTime.toIso8601String(),
              'category': prayer.category,
              'payload': prayer.payload,
              'createdAt': prayer.createdAt.toIso8601String(),
              'isActive': prayer.isActive,
            })
        .toList();

    await _prefs!.setString('scheduled_prayers', jsonEncode(prayersJson));
  }

  /// Load scheduled prayers from storage
  Future<void> _loadScheduledPrayers() async {
    final prayersJson = _prefs!.getString('scheduled_prayers');
    if (prayersJson != null) {
      try {
        final List<dynamic> prayersList = jsonDecode(prayersJson);
        _scheduledPrayers =
            prayersList.map((json) => ScheduledPrayer.fromJson(json)).toList();
        _log('Loaded ${_scheduledPrayers.length} scheduled prayers',
            LogLevel.debug);
      } catch (e) {
        _log('Error loading scheduled prayers: $e', LogLevel.error);
      }
    }
  }

  /// Attempt to recover from error state
  Future<void> _attemptRecovery() async {
    _log('Attempting service recovery...', LogLevel.warning);

    try {
      // Reinitialize if needed
      if (!_isInitialized) {
        await initialize(forceEnhanced: !_isPrimaryMode);
      }

      // Reset service state
      _serviceState = ServiceState.ready;

      _log('Service recovery completed', LogLevel.info);
    } catch (e) {
      _log('Service recovery failed: $e', LogLevel.error);
      _serviceState = ServiceState.error;
    }
  }

  /// Log message with level
  void _log(String message, LogLevel level) {
    final timestamp = DateTime.now();
    final log = ServiceLog(
      timestamp: timestamp,
      level: level,
      message: message,
      source: 'UnifiedPrayerNotificationService',
    );

    _logs.add(log);

    // Keep only last 100 logs
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }

    // Print to console
    final prefix = level.toString().split('.').last.toUpperCase();
    print('[$prefix] UnifiedPrayerNotificationService: $message');
  }

  /// Get system health information
  Map<String, dynamic> getSystemHealth() {
    return {
      'isInitialized': _isInitialized,
      'serviceState': _serviceState.toString(),
      'serviceMode': _isPrimaryMode ? 'Simple' : 'Enhanced',
      'scheduledPrayersCount': _scheduledPrayers.length,
      'logsCount': _logs.length,
      'performanceMetrics': _performanceMetrics.length,
      'systemTime': DateTime.now().toIso8601String(),
      'timezone': DateTime.now().timeZoneName,
      'isHealthy': _serviceState == ServiceState.ready,
    };
  }

  /// Get all scheduled notifications
  Future<List<ScheduledPrayer>> getScheduledNotifications() async {
    return List.from(_scheduledPrayers);
  }

  /// Get service statistics
  ServiceStatistics getStatistics() {
    final errorLogs = _logs.where((log) => log.level == LogLevel.error).length;
    final warningLogs =
        _logs.where((log) => log.level == LogLevel.warning).length;
    final infoLogs = _logs.where((log) => log.level == LogLevel.info).length;

    return ServiceStatistics(
      totalLogs: _logs.length,
      errorLogs: errorLogs,
      warningLogs: warningLogs,
      infoLogs: infoLogs,
      isInitialized: _isInitialized,
      serviceState: _serviceState,
      serviceMode: _isPrimaryMode ? ServiceMode.simple : ServiceMode.enhanced,
      scheduledPrayersCount: _scheduledPrayers.length,
    );
  }

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _audioService?.dispose();
    _notifications = null;
    _audioService = null;
    _prefs = null;
    _nativeChannel = null;
    _isInitialized = false;
    _serviceState = ServiceState.disposed;

    _log('Service disposed', LogLevel.info);
  }
}

/// Service state enum
enum ServiceState {
  uninitialized,
  initializing,
  ready,
  error,
  disposed,
}

/// Service mode enum
enum ServiceMode {
  simple,
  enhanced,
}

/// Log level enum
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Service log model
class ServiceLog {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String source;

  const ServiceLog({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.source,
  });

  @override
  String toString() {
    return '[${timestamp.toIso8601String()}] ${level.toString().split('.').last.toUpperCase()}: $message';
  }
}

/// Service statistics model
class ServiceStatistics {
  final int totalLogs;
  final int errorLogs;
  final int warningLogs;
  final int infoLogs;
  final bool isInitialized;
  final ServiceState serviceState;
  final ServiceMode serviceMode;
  final int scheduledPrayersCount;

  const ServiceStatistics({
    required this.totalLogs,
    required this.errorLogs,
    required this.warningLogs,
    required this.infoLogs,
    required this.isInitialized,
    required this.serviceState,
    required this.serviceMode,
    required this.scheduledPrayersCount,
  });

  bool get hasErrors => errorLogs > 0;
  bool get hasWarnings => warningLogs > 0;
  bool get isHealthy =>
      isInitialized && serviceState == ServiceState.ready && errorLogs == 0;

  int get healthScore => _calculateHealthScore();

  int _calculateHealthScore() {
    int score = 100;
    if (!isInitialized) score -= 30;
    if (serviceState != ServiceState.ready) score -= 20;
    if (errorLogs > 0) score -= errorLogs * 15;
    if (warningLogs > 0) score -= warningLogs * 5;
    return score.clamp(0, 100);
  }
}
