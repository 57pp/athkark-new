import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Smart notification service with customizable timing, snooze/dismiss, and enhanced features
class SmartNotificationService {
  static const String _notificationPreferencesKey = 'smart_notification_prefs';
  static const String _notificationTimingKey = 'notification_timing_';
  static const String _snoozeSettingsKey = 'snooze_settings';
  static const String _soundPreferencesKey = 'sound_preferences';
  static const String _vibrationPreferencesKey = 'vibration_preferences';
  static const String _visualPreferencesKey = 'visual_preferences';
  static const String _accessibilitySettingsKey = 'accessibility_settings';

  static final SmartNotificationService _instance = SmartNotificationService._();
  static SmartNotificationService get instance => _instance;

  SmartNotificationService._();

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  
  // Notification timing settings (default 15 minutes before prayer)
  final Map<String, int> _notificationTimings = {};
  
  // Snooze settings
  SnoozeSettings _snoozeSettings = SnoozeSettings();
  
  // Sound preferences
  SoundPreferences _soundPreferences = SoundPreferences();
  
  // Vibration preferences  
  VibrationPreferences _vibrationPreferences = VibrationPreferences();
  
  // Visual preferences
  VisualPreferences _visualPreferences = VisualPreferences();
  
  // Accessibility settings
  AccessibilitySettings _accessibilitySettings = AccessibilitySettings();
  
  // Active notification tracking
  final Map<String, SmartNotificationRecord> _activeNotifications = {};
  final StreamController<SmartNotificationEvent> _eventController = 
      StreamController<SmartNotificationEvent>.broadcast();

  /// Initialize the smart notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🧠 Initializing Smart Notification Service...');
    
    _prefs = await SharedPreferences.getInstance();
    
    // Load all preferences
    await _loadNotificationTimings();
    await _loadSnoozeSettings();
    await _loadSoundPreferences();
    await _loadVibrationPreferences();
    await _loadVisualPreferences();
    await _loadAccessibilitySettings();
    
    _isInitialized = true;
    print('✅ Smart Notification Service initialized');
    
    // Log current settings
    _logCurrentSettings();
  }

  /// Get the event stream for notification events
  Stream<SmartNotificationEvent> get eventStream => _eventController.stream;

  /// Get smart notification timing for a prayer
  Future<int> getNotificationTiming(String prayerId) async {
    return _notificationTimings[prayerId] ?? 15; // Default 15 minutes
  }

  /// Set smart notification timing for a prayer
  Future<void> setNotificationTiming(String prayerId, int minutesBefore) async {
    _notificationTimings[prayerId] = minutesBefore;
    await _prefs.setInt(_notificationTimingKey + prayerId, minutesBefore);
    
    _eventController.add(SmartNotificationEvent(
      type: NotificationEventType.timingChanged,
      prayerId: prayerId,
      data: {'minutesBefore': minutesBefore},
    ));
    
    print('📅 Set notification timing for $prayerId: $minutesBefore minutes');
  }

  /// Schedule smart notification with customizable timing
  Future<bool> scheduleSmartNotification({
    required String prayerId,
    required String prayerName,
    required DateTime prayerTime,
    String adhanFile = 'adhan.mp3',
    bool isCustom = false,
  }) async {
    try {
      // Get custom timing or use default
      final int minutesBefore = await getNotificationTiming(prayerId);
      final DateTime notificationTime = prayerTime.subtract(Duration(minutes: minutesBefore));
      
      // Check if notification time is in the past
      if (notificationTime.isBefore(DateTime.now())) {
        print('⚠️ Notification time for $prayerName is in the past, scheduling for next prayer');
        return await _scheduleForNextOccurrence(prayerId, prayerName, prayerTime, minutesBefore);
      }
      
      // Create notification record
      final notification = SmartNotificationRecord(
        id: prayerId,
        prayerName: prayerName,
        prayerTime: prayerTime,
        notificationTime: notificationTime,
        adhanFile: adhanFile,
        isCustom: isCustom,
        status: NotificationStatus.scheduled,
      );
      
      _activeNotifications[prayerId] = notification;
      
      // Schedule the notification with enhanced features
      print('🔍 DEBUG: About to call _scheduleEnhancedNotification with minutesBefore: $minutesBefore');
      final success = await _scheduleEnhancedNotification(notification);
      print('🔍 DEBUG: _scheduleEnhancedNotification returned: $success');
      
      if (success) {
        print('✅ Smart notification scheduled for $prayerName at $notificationTime');
      } else {
        print('❌ Failed to schedule smart notification for $prayerName');
      }
      
      return success;
      
    } catch (e) {
      print('❌ Error scheduling smart notification: $e');
      return false;
    }
  }

  /// Schedule notification for next occurrence
  Future<bool> _scheduleForNextOccurrence(String prayerId, String prayerName, 
      DateTime currentPrayerTime, int minutesBefore) async {
    // Schedule for tomorrow
    final tomorrow = DateTime(
      currentPrayerTime.year,
      currentPrayerTime.month, 
      currentPrayerTime.day + 1,
      currentPrayerTime.hour,
      currentPrayerTime.minute,
    );
    
    return await scheduleSmartNotification(
      prayerId: prayerId,
      prayerName: prayerName,
      prayerTime: tomorrow,
      isCustom: false,
    );
  }

  /// Schedule enhanced notification with all smart features
  Future<bool> _scheduleEnhancedNotification(SmartNotificationRecord notification) async {
    try {
      print('🔍 DEBUG: _scheduleEnhancedNotification called for: ${notification.prayerName}');
      
      // Calculate minutesBefore from notification time difference
      final minutesBefore = notification.prayerTime.difference(notification.notificationTime).inMinutes;
      print('🔍 DEBUG: Calculated minutesBefore: $minutesBefore');
      
      // This would integrate with the existing notification system
      // For now, we'll simulate the scheduling process
      
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Get notification details with smart features
      final androidDetails = _getAndroidNotificationDetails(notification);
      final iosDetails = _getIOSNotificationDetails(notification);
      
      // Schedule the notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notification.id.hashCode,
        'حان وقت صلاة ${notification.prayerName}',
        'أدخل $minutesBefore دقيقة لتقديم الأذان',
        _convertToTZDateTime(notification.notificationTime),
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: _createSmartNotificationPayload(notification),
      );
      
      notification.status = NotificationStatus.scheduled;
      return true;
      
    } catch (e) {
      print('❌ Error scheduling enhanced notification: $e');
      notification.status = NotificationStatus.failed;
      return false;
    }
  }

  /// Get Android notification details with smart features
  AndroidNotificationDetails _getAndroidNotificationDetails(SmartNotificationRecord notification) {
    final preferences = _visualPreferences;
    
    return AndroidNotificationDetails(
      'smart_prayer_notification_${notification.id}',
      'إشعارات الصلاة الذكية',
      channelDescription: 'إشعارات مخصصة للصلاة مع ميزات متقدمة',
      importance: Importance.max,
      priority: Priority.max,
      playSound: _soundPreferences.enabled,
      sound: _soundPreferences.useAdhan ? 
          RawResourceAndroidNotificationSound('adhan') : null,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: _vibrationPreferences.enabled,
      vibrationPattern: Int64List.fromList(_vibrationPreferences.customPattern),
      enableLights: preferences.enableLED,
      ledColor: Color(preferences.ledColor),
      ongoing: false,
      autoCancel: false,
      actions: _getAndroidActions(notification),
      timeoutAfter: _snoozeSettings.autoDismissDuration.inMilliseconds,
      color: preferences.themeColor,
      icon: '@drawable/ic_stat_athkark',
      subText: 'قبل ${_notificationTimings[notification.id] ?? 15} دقيقة',
    );
  }

  /// Get iOS notification details with smart features
  DarwinNotificationDetails _getIOSNotificationDetails(SmartNotificationRecord notification) {
    return DarwinNotificationDetails(
      presentAlert: _visualPreferences.showAlert,
      presentBadge: _visualPreferences.showBadge,
      presentSound: _soundPreferences.enabled,
      sound: _soundPreferences.useAdhan ? 'adhan_soft.caf' : null,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
  }

  /// Get Android notification actions (snooze, dismiss, etc.)
  List<AndroidNotificationAction> _getAndroidActions(SmartNotificationRecord notification) {
    final actions = <AndroidNotificationAction>[];
    
    if (_snoozeSettings.enabled) {
      actions.addAll([
        AndroidNotificationAction(
          'snooze_5',
          'تأجيل 5 دقائق',
        ),
        AndroidNotificationAction(
          'snooze_10', 
          'تأجيل 10 دقائق',
        ),
        AndroidNotificationAction(
          'snooze_15',
          'تأجيل 15 دقيقة', 
        ),
      ]);
    }
    
    actions.addAll([
      AndroidNotificationAction(
        'dismiss',
        'إلغاء',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        'open_app',
        'فتح التطبيق',
        showsUserInterface: true,
      ),
    ]);
    
    return actions;
  }

  /// Handle notification action (snooze, dismiss, etc.)
  Future<void> handleNotificationAction(String action, String payload) async {
    print('🔔 Handling notification action: $action');
    
    try {
      final notificationId = _extractNotificationId(payload);
      final notification = _activeNotifications[notificationId];
      
      if (notification == null) {
        print('⚠️ No active notification found for ID: $notificationId');
        return;
      }
      
      switch (action) {
        case 'snooze_5':
          await _snoozeNotification(notification, Duration(minutes: 5));
          break;
        case 'snooze_10':
          await _snoozeNotification(notification, Duration(minutes: 10));
          break;
        case 'snooze_15':
          await _snoozeNotification(notification, Duration(minutes: 15));
          break;
        case 'dismiss':
          await _dismissNotification(notification);
          break;
        case 'open_app':
          await _openAppFromNotification(notification);
          break;
        default:
          print('⚠️ Unknown notification action: $action');
      }
      
    } catch (e) {
      print('❌ Error handling notification action: $e');
    }
  }

  /// Snooze a notification
  Future<void> _snoozeNotification(SmartNotificationRecord notification, Duration snoozeDuration) async {
    try {
      notification.status = NotificationStatus.snoozed;
      notification.snoozeTime = DateTime.now().add(snoozeDuration);
      
      _eventController.add(SmartNotificationEvent(
        type: NotificationEventType.snoozed,
        prayerId: notification.id,
        prayerName: notification.prayerName,
        data: {
          'snoozeDuration': snoozeDuration.inMinutes,
          'newNotificationTime': notification.snoozeTime?.toIso8601String(),
        },
      ));
      
      // Schedule the snoozed notification
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.show(
        notification.id.hashCode + 1000000, // Different ID for snoozed notification
        'تأجيل إشعار صلاة ${notification.prayerName}',
        'سعيد تأخير ${snoozeDuration.inMinutes} دقيقة',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'snoozed_notification',
            'الإشعارات المؤجلة',
            channelDescription: 'إشعارات الصلاة المؤجلة',
          ),
        ),
      );
      
      print('✅ Notification snoozed for ${snoozeDuration.inMinutes} minutes');
      
    } catch (e) {
      print('❌ Error snoozing notification: $e');
    }
  }

  /// Dismiss a notification
  Future<void> _dismissNotification(SmartNotificationRecord notification) async {
    try {
      notification.status = NotificationStatus.dismissed;
      
      _eventController.add(SmartNotificationEvent(
        type: NotificationEventType.dismissed,
        prayerId: notification.id,
        prayerName: notification.prayerName,
      ));
      
      // Remove from active notifications
      _activeNotifications.remove(notification.id);
      
      // Cancel any existing notifications for this prayer
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(notification.id.hashCode);
      
      print('✅ Notification dismissed for ${notification.prayerName}');
      
    } catch (e) {
      print('❌ Error dismissing notification: $e');
    }
  }

  /// Open app from notification
  Future<void> _openAppFromNotification(SmartNotificationRecord notification) async {
    try {
      _eventController.add(SmartNotificationEvent(
        type: NotificationEventType.opened,
        prayerId: notification.id,
        prayerName: notification.prayerName,
      ));
      
      // This would typically trigger app navigation or deep linking
      print('📱 Opening app from notification for ${notification.prayerName}');
      
    } catch (e) {
      print('❌ Error opening app from notification: $e');
    }
  }

  /// Cancel smart notification
  Future<void> cancelSmartNotification(String prayerId) async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(prayerId.hashCode);
      
      _activeNotifications.remove(prayerId);
      
      _eventController.add(SmartNotificationEvent(
        type: NotificationEventType.cancelled,
        prayerId: prayerId,
      ));
      
      print('🗑️ Smart notification cancelled for $prayerId');
      
    } catch (e) {
      print('❌ Error cancelling smart notification: $e');
    }
  }

  /// Update snooze settings
  Future<void> updateSnoozeSettings(SnoozeSettings settings) async {
    _snoozeSettings = settings;
    await _prefs.setString(_snoozeSettingsKey, settings.toJsonString());
    
    _eventController.add(SmartNotificationEvent(
      type: NotificationEventType.settingsChanged,
      data: {'snoozeSettings': settings.toJsonString()},
    ));
  }

  /// Update sound preferences
  Future<void> updateSoundPreferences(SoundPreferences preferences) async {
    _soundPreferences = preferences;
    await _prefs.setString(_soundPreferencesKey, preferences.toJsonString());
    
    _eventController.add(SmartNotificationEvent(
      type: NotificationEventType.settingsChanged,
      data: {'soundPreferences': preferences.toJsonString()},
    ));
  }

  /// Update vibration preferences
  Future<void> updateVibrationPreferences(VibrationPreferences preferences) async {
    _vibrationPreferences = preferences;
    await _prefs.setString(_vibrationPreferencesKey, preferences.toJsonString());
    
    _eventController.add(SmartNotificationEvent(
      type: NotificationEventType.settingsChanged,
      data: {'vibrationPreferences': preferences.toJsonString()},
    ));
  }

  /// Update visual preferences
  Future<void> updateVisualPreferences(VisualPreferences preferences) async {
    _visualPreferences = preferences;
    await _prefs.setString(_visualPreferencesKey, preferences.toJsonString());
    
    _eventController.add(SmartNotificationEvent(
      type: NotificationEventType.settingsChanged,
      data: {'visualPreferences': preferences.toJsonString()},
    ));
  }

  /// Update accessibility settings
  Future<void> updateAccessibilitySettings(AccessibilitySettings settings) async {
    _accessibilitySettings = settings;
    await _prefs.setString(_accessibilitySettingsKey, settings.toJsonString());
    
    _eventController.add(SmartNotificationEvent(
      type: NotificationEventType.settingsChanged,
      data: {'accessibilitySettings': settings.toJsonString()},
    ));
  }

  /// Get all settings
  SmartNotificationSettings getAllSettings() {
    return SmartNotificationSettings(
      timings: Map.from(_notificationTimings),
      snooze: _snoozeSettings,
      sound: _soundPreferences,
      vibration: _vibrationPreferences,
      visual: _visualPreferences,
      accessibility: _accessibilitySettings,
    );
  }

  /// Convert DateTime to TZDateTime
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Create smart notification payload
  String _createSmartNotificationPayload(SmartNotificationRecord notification) {
    return '{"smart_notification": true, "prayer_id": "${notification.id}", "prayer_name": "${notification.prayerName}", "notification_time": "${notification.notificationTime.toIso8601String()}"}';
  }

  /// Extract notification ID from payload
  String _extractNotificationId(String payload) {
    try {
      final Map<String, dynamic> data = _parsePayload(payload);
      return data['prayer_id'] ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Parse notification payload
  Map<String, dynamic> _parsePayload(String payload) {
    // Simple JSON parsing - in production you'd use proper JSON
    final Map<String, dynamic> result = {};
    // Implementation would parse the payload JSON
    return result;
  }

  /// Load notification timings from preferences
  Future<void> _loadNotificationTimings() async {
    // Load all notification timings from SharedPreferences
    // This is a simplified implementation
  }

  /// Load snooze settings from preferences
  Future<void> _loadSnoozeSettings() async {
    final json = _prefs.getString(_snoozeSettingsKey);
    if (json != null) {
      // Parse JSON and create SnoozeSettings object
    }
  }

  /// Load sound preferences from preferences
  Future<void> _loadSoundPreferences() async {
    final json = _prefs.getString(_soundPreferencesKey);
    if (json != null) {
      // Parse JSON and create SoundPreferences object
    }
  }

  /// Load vibration preferences from preferences
  Future<void> _loadVibrationPreferences() async {
    final json = _prefs.getString(_vibrationPreferencesKey);
    if (json != null) {
      // Parse JSON and create VibrationPreferences object
    }
  }

  /// Load visual preferences from preferences
  Future<void> _loadVisualPreferences() async {
    final json = _prefs.getString(_visualPreferencesKey);
    if (json != null) {
      // Parse JSON and create VisualPreferences object
    }
  }

  /// Load accessibility settings from preferences
  Future<void> _loadAccessibilitySettings() async {
    final json = _prefs.getString(_accessibilitySettingsKey);
    if (json != null) {
      // Parse JSON and create AccessibilitySettings object
    }
  }

  /// Log current settings for debugging
  void _logCurrentSettings() {
    print('📊 Smart Notification Settings:');
    print('  - Timings: $_notificationTimings');
    print('  - Snooze: ${_snoozeSettings.enabled}');
    print('  - Sound: ${_soundPreferences.enabled}');
    print('  - Vibration: ${_vibrationPreferences.enabled}');
    print('  - Visual LED: ${_visualPreferences.enableLED}');
    print('  - Accessibility: ${_accessibilitySettings.highContrast}');
  }

  /// Get active notifications
  List<SmartNotificationRecord> getActiveNotifications() {
    return _activeNotifications.values.toList();
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}

// Data models and enums

enum NotificationEventType {
  timingChanged,
  snoozed,
  dismissed,
  opened,
  cancelled,
  settingsChanged,
}

enum NotificationStatus {
  scheduled,
  active,
  snoozed,
  dismissed,
  cancelled,
  failed,
}

class SmartNotificationEvent {
  final NotificationEventType type;
  final String? prayerId;
  final String? prayerName;
  final Map<String, dynamic>? data;

  const SmartNotificationEvent({
    required this.type,
    this.prayerId,
    this.prayerName,
    this.data,
  });
}

class SmartNotificationRecord {
  final String id;
  final String prayerName;
  final DateTime prayerTime;
  final DateTime notificationTime;
  final String adhanFile;
  final bool isCustom;
  NotificationStatus status;
  DateTime? snoozeTime;

  SmartNotificationRecord({
    required this.id,
    required this.prayerName,
    required this.prayerTime,
    required this.notificationTime,
    required this.adhanFile,
    required this.isCustom,
    required this.status,
    this.snoozeTime,
  });
}

class SnoozeSettings {
  final bool enabled;
  final List<int> availableDurations;
  final bool autoDismiss;
  final Duration autoDismissDuration;

  const SnoozeSettings({
    this.enabled = true,
    this.availableDurations = const [5, 10, 15, 30],
    this.autoDismiss = false,
    this.autoDismissDuration = const Duration(minutes: 10),
  });

  String toJsonString() {
    final data = {
      'enabled': enabled,
      'availableDurations': availableDurations,
      'autoDismiss': autoDismiss,
      'autoDismissDurationMinutes': autoDismissDuration.inMinutes,
    };
    return data.toString();
  }
}

class SoundPreferences {
  final bool enabled;
  final bool useAdhan;
  final double volume;
  final String? customSound;

  const SoundPreferences({
    this.enabled = true,
    this.useAdhan = true,
    this.volume = 0.8,
    this.customSound,
  });

  String toJsonString() {
    final data = {
      'enabled': enabled,
      'useAdhan': useAdhan,
      'volume': volume,
      'customSound': customSound,
    };
    return data.toString();
  }
}

class VibrationPreferences {
  final bool enabled;
  final List<int> customPattern;
  final int repeatCount;

  const VibrationPreferences({
    this.enabled = true,
    this.customPattern = const [0, 500, 200, 500],
    this.repeatCount = 2,
  });

  String toJsonString() {
    final data = {
      'enabled': enabled,
      'customPattern': customPattern,
      'repeatCount': repeatCount,
    };
    return data.toString();
  }
}

class VisualPreferences {
  final bool showBadge;
  final bool showAlert;
  final bool enableLED;
  final int ledColor;
  final Color themeColor;

  const VisualPreferences({
    this.showBadge = true,
    this.showAlert = true,
    this.enableLED = true,
    this.ledColor = 0xFF00FF00,
    this.themeColor = Colors.green,
  });

  String toJsonString() {
    final data = {
      'showBadge': showBadge,
      'showAlert': showAlert,
      'enableLED': enableLED,
      'ledColor': ledColor,
    };
    return data.toString();
  }
}

class AccessibilitySettings {
  final bool highContrast;
  final bool largeText;
  final bool hapticFeedback;
  final bool audioDescriptions;

  const AccessibilitySettings({
    this.highContrast = false,
    this.largeText = false,
    this.hapticFeedback = true,
    this.audioDescriptions = false,
  });

  String toJsonString() {
    final data = {
      'highContrast': highContrast,
      'largeText': largeText,
      'hapticFeedback': hapticFeedback,
      'audioDescriptions': audioDescriptions,
    };
    return data.toString();
  }
}

class SmartNotificationSettings {
  final Map<String, int> timings;
  final SnoozeSettings snooze;
  final SoundPreferences sound;
  final VibrationPreferences vibration;
  final VisualPreferences visual;
  final AccessibilitySettings accessibility;

  const SmartNotificationSettings({
    required this.timings,
    required this.snooze,
    required this.sound,
    required this.vibration,
    required this.visual,
    required this.accessibility,
  });
}