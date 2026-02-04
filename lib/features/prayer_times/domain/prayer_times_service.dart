import 'dart:async';
import 'dart:io';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:athkark/main.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/athkark_notifications.dart';
import '../../../shared/utils/unified_prayer_notification_service.dart';
import '../../../shared/utils/simple_prayer_audio_service.dart';
import '../../../shared/utils/boot_service.dart';
import 'prayer_prefs.dart';

const String kAdhanNotificationChannelId = 'athkark.adhan';
const String kAdhanNotificationChannelName = 'الأذان';
const String kAdhanNotificationChannelDescription = 'تنبيه الأذان بصوت الأذان';
const String _adhanPlaybackChannelId = 'athkark.adhan.playback';

enum PrayerLocationStatus {
  idle,
  loading,
  permissionDenied,
  serviceDisabled,
  ready,
}

class PrayerTimesState {
  const PrayerTimesState({
    required this.coordinates,
    required this.times,
    required this.sunrise,
    required this.enabled,
    required this.nextPrayer,
    required this.locationStatus,
    required this.placeName,
    required this.lastUpdated,
    required this.advancedAudioEnabled,
  });

  final Coordinates coordinates;
  final Map<PrayerType, DateTime> times;
  final DateTime sunrise;
  final Map<PrayerType, bool> enabled;
  final PrayerType? nextPrayer;
  final PrayerLocationStatus locationStatus;
  final String? placeName;
  final DateTime lastUpdated;
  final bool advancedAudioEnabled;
}

/// Model for custom user-defined prayers
class CustomPrayer {
  final String id;
  final String name;
  final DateTime time;
  final bool enabled;

  const CustomPrayer({
    required this.id,
    required this.name,
    required this.time,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'time': time.toIso8601String(),
      'enabled': enabled,
    };
  }

  factory CustomPrayer.fromJson(Map<String, dynamic> json) {
    return CustomPrayer(
      id: json['id'],
      name: json['name'],
      time: DateTime.parse(json['time']),
      enabled: json['enabled'] ?? true,
    );
  }

  /// Get time for next occurrence (today or tomorrow)
  DateTime getNextOccurrence() {
    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);

    if (today.isAfter(now)) {
      return today;
    } else {
      return today.add(const Duration(days: 1));
    }
  }

  /// Create a copy with updated properties
  CustomPrayer copyWith({
    String? id,
    String? name,
    DateTime? time,
    bool? enabled,
  }) {
    return CustomPrayer(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
    );
  }
}

class PrayerTimesService {
  PrayerTimesService._();

  static final PrayerTimesService instance = PrayerTimesService._();

  final ValueNotifier<PrayerTimesState?> state =
      ValueNotifier<PrayerTimesState?>(null);

  // Custom prayers management
  final ValueNotifier<List<CustomPrayer>> customPrayersNotifier =
      ValueNotifier<List<CustomPrayer>>([]);

  FlutterLocalNotificationsPlugin? _notifications;
  late PrayerPrefs _prefs;
  UnifiedPrayerNotificationService? _unifiedNotificationService;
  SimplePrayerAudioService? _simpleAudioService;
  bool _initialized = false;
  bool _timezoneReady = false;
  String? _cachedPlaceName;
  Timer? _midnightTimer;
  bool _isScheduling = false;
  bool _testMode = false;
  Timer? _testTimer;

  Future<void> init({
    FlutterLocalNotificationsPlugin? notifications,
    bool forceRefresh = false,
  }) async {
    if (_initialized && !forceRefresh) {
      return;
    }

    try {
      // تأكد من إكمال تهيئة النظام (AndroidAlarmManager + Unified service) قبل الجدولة
      await Boot.ensure();

      _notifications = notifications ?? AthkarkNotifications.instance.plugin;
      _prefs = await PrayerPrefs.load();

      // Initialize simple services - unified service is initialized in main boot
      _unifiedNotificationService = UnifiedPrayerNotificationService.instance;
  
      _simpleAudioService = SimplePrayerAudioService.instance;
      await _simpleAudioService!.initialize(_notifications!);

      _ensureTimezone();
      await _ensureAndroidChannel();
      await _ensureNotificationPermissions();

      await refreshAndSchedule(forceLocation: forceRefresh);

      // Load and schedule custom prayers
      await loadCustomPrayers();
      await _scheduleAllCustomPrayers();

      _scheduleMidnightRefresh();
      // Schedule custom prayers refresh at midnight
      _scheduleCustomPrayersMidnightRefresh();
      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint(
          'Error during prayer times service initialization, using fallback: $e\n$stackTrace');
      setFallbackState();
      _initialized = true; // Mark as initialized even with fallback
    }
  }

  void setFallbackState() {
    // Use default calculation parameters since _prefs might not be loaded
    final CalculationParameters params = CalculationMethodParameters.ummAlQura();
    params.madhab = Madhab.shafi;

    final _PrayerComputationResult computation =
        _computePrayerTimesWithParams(_defaultCoordinates(), params);

    final Map<PrayerType, bool> enabled = <PrayerType, bool>{
      for (final PrayerType prayer in PrayerType.values)
        prayer: true, // Default all enabled
    };

    state.value = PrayerTimesState(
      coordinates: _defaultCoordinates(),
      times: computation.times,
      sunrise: computation.sunrise,
      enabled: enabled,
      nextPrayer: computation.nextPrayer,
      locationStatus: PrayerLocationStatus.serviceDisabled,
      placeName: 'مكة',
      lastUpdated: DateTime.now(),
      advancedAudioEnabled: false, // Default
    );
  }

  Future<void> refreshAndSchedule({
    bool forceLocation = false,
    bool reschedule = true,
  }) async {
    if (_isScheduling) {
      return;
    }
    _isScheduling = true;
    try {
      final _LocationResolution resolution =
          await _resolveLocation(forceRequest: forceLocation);
      _cachedPlaceName = resolution.placeName;

      final _PrayerComputationResult computation =
          _computePrayerTimes(resolution.coordinates);

      final Map<PrayerType, bool> enabled = <PrayerType, bool>{
        for (final PrayerType prayer in PrayerType.values)
          prayer: _prefs.isPrayerEnabled(prayer),
      };

      final PrayerTimesState nextState = PrayerTimesState(
        coordinates: resolution.coordinates,
        times: computation.times,
        sunrise: computation.sunrise,
        enabled: enabled,
        nextPrayer: computation.nextPrayer,
        locationStatus: resolution.status,
        placeName: _cachedPlaceName,
        lastUpdated: DateTime.now(),
        advancedAudioEnabled: _prefs.advancedAudioEnabled,
      );
      state.value = nextState;

      if (reschedule) {
        await _scheduleForDay(
          times: computation.times,
          enabled: enabled,
          advancedAudio: _prefs.advancedAudioEnabled,
        );
      }
    } finally {
      _isScheduling = false;
    }
  }

  Future<void> refreshLocation() async {
    await refreshAndSchedule(forceLocation: true);
  }

  Future<void> rescheduleToday() async {
    await refreshAndSchedule(forceLocation: false);
    // Also schedule custom prayers for today
    await _scheduleCustomPrayersForToday();
  }

  Future<void> togglePrayer(PrayerType prayer, bool enabled) async {
    await _prefs.setPrayerEnabled(prayer, enabled);
    final PrayerTimesState? current = state.value;
    if (current == null) {
      return;
    }
    final Map<PrayerType, bool> updated =
        Map<PrayerType, bool>.from(current.enabled);
    updated[prayer] = enabled;
    state.value = PrayerTimesState(
      coordinates: current.coordinates,
      times: current.times,
      sunrise: current.sunrise,
      enabled: updated,
      nextPrayer: _nextPrayerFromTimes(current.times),
      locationStatus: current.locationStatus,
      placeName: current.placeName,
      lastUpdated: DateTime.now(),
      advancedAudioEnabled: current.advancedAudioEnabled,
    );
    await _scheduleForDay(
      times: current.times,
      enabled: updated,
      advancedAudio: current.advancedAudioEnabled,
    );
  }

  Future<void> setAdvancedAudio(bool enabled) async {
    await _prefs.setAdvancedAudioEnabled(enabled);
    final PrayerTimesState? current = state.value;
    if (current == null) {
      return;
    }
    state.value = PrayerTimesState(
      coordinates: current.coordinates,
      times: current.times,
      sunrise: current.sunrise,
      enabled: current.enabled,
      nextPrayer: current.nextPrayer,
      locationStatus: current.locationStatus,
      placeName: current.placeName,
      lastUpdated: DateTime.now(),
      advancedAudioEnabled: enabled,
    );
    await _scheduleForDay(
      times: current.times,
      enabled: current.enabled,
      advancedAudio: enabled,
    );
  }

  // Custom Prayers Management Methods
  Future<void> loadCustomPrayers() async {
    try {
      // Ensure _prefs is initialized
      if (!_initialized || _prefs == null) {
        debugPrint(
            '⚠️ PrayerTimesService not initialized, initializing now...');
        if (_prefs == null) {
          _prefs = await PrayerPrefs.load();
        }
      }

      final prayersJson = _prefs.getCustomPrayers();
      final List<CustomPrayer> prayers = [];

      for (final json in prayersJson) {
        prayers.add(CustomPrayer.fromJson(json));
      }

      customPrayersNotifier.value = prayers;
      debugPrint('✅ Loaded ${prayers.length} custom prayers');
    } catch (e) {
      debugPrint('❌ Error loading custom prayers: $e');
      // Set empty list on error to prevent further issues
      customPrayersNotifier.value = [];
    }
  }

  Future<void> addCustomPrayer(String name, TimeOfDay time) async {
    try {
      final now = DateTime.now();
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      final prayer = CustomPrayer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim().isEmpty ? 'صلاة مخصصة' : name.trim(),
        time: prayerTime,
        enabled: true,
      );

      // Get current prayers
      final currentPrayers =
          List<CustomPrayer>.from(customPrayersNotifier.value);
      currentPrayers.add(prayer);

      // Update notifier
      customPrayersNotifier.value = currentPrayers;

      // Save to prefs
      await _saveCustomPrayers(currentPrayers);

      // Schedule notification for this prayer
      await _scheduleCustomPrayerNotification(prayer);

      debugPrint(
          'Added custom prayer: $name at ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('Error adding custom prayer: $e');
      rethrow;
    }
  }

  Future<void> removeCustomPrayer(String id) async {
    try {
      final currentPrayers =
          List<CustomPrayer>.from(customPrayersNotifier.value);
      final prayerToRemove = currentPrayers.firstWhere((p) => p.id == id);

      currentPrayers.removeWhere((p) => p.id == id);
      customPrayersNotifier.value = currentPrayers;

      // Save to prefs
      await _saveCustomPrayers(currentPrayers);

      // Cancel notification
      await _cancelCustomPrayerNotification(id);

      debugPrint('Removed custom prayer: ${prayerToRemove.name}');
    } catch (e) {
      debugPrint('Error removing custom prayer: $e');
      rethrow;
    }
  }

  Future<void> toggleCustomPrayer(String id, bool enabled) async {
    try {
      final currentPrayers =
          List<CustomPrayer>.from(customPrayersNotifier.value);
      final prayerIndex = currentPrayers.indexWhere((p) => p.id == id);

      if (prayerIndex != -1) {
        final updatedPrayer =
            currentPrayers[prayerIndex].copyWith(enabled: enabled);
        currentPrayers[prayerIndex] = updatedPrayer;
        customPrayersNotifier.value = currentPrayers;

        // Save to prefs
        await _saveCustomPrayers(currentPrayers);

        // Schedule or cancel notification based on enabled state
        if (enabled) {
          await _scheduleCustomPrayerNotification(updatedPrayer);
        } else {
          await _cancelCustomPrayerNotification(id);
        }

        debugPrint(
            '${enabled ? 'Enabled' : 'Disabled'} custom prayer: ${updatedPrayer.name}');
      }
    } catch (e) {
      debugPrint('Error toggling custom prayer: $e');
      rethrow;
    }
  }

  /// Test adhan audio immediately
  Future<void> testAdhanAudio() async {
    debugPrint(
        '🧪 TESTING SIMPLE ADHAN AUDIO - You should hear the adhan now!');

    try {
      // Use the simple and reliable audio service
      final success = await _simpleAudioService!.testAudio();
      if (success) {
        debugPrint(
            '✅ Simple adhan test completed successfully - check if you heard the audio');
      } else {
        debugPrint('❌ Simple adhan test failed');
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Simple adhan test failed: $error\n$stackTrace');
    }
  }

  /// Handle prayer notification when app is opened from notification
  Future<void> handlePrayerNotification(String prayerName,
      {bool autoStartAdhan = true}) async {
    debugPrint('Handling prayer notification in foreground: $prayerName');
    if (autoStartAdhan) {
      await _simpleAudioService!.playAdhan(prayerName);
    }
  }

  /// Handle custom prayer notification when app is opened from notification
  Future<void> handleCustomPrayerNotification(
      String prayerId, String prayerName,
      {bool autoStartAdhan = true}) async {
    debugPrint(
        'Handling custom prayer notification in foreground: $prayerName (ID: $prayerId)');
    if (autoStartAdhan) {
      await _simpleAudioService!.playAdhan(prayerName);
    }
  }


  /// Schedule all custom prayers notifications on app startup
  Future<void> _scheduleAllCustomPrayers() async {
    try {
      final currentPrayers = customPrayersNotifier.value;
      for (final prayer in currentPrayers) {
        if (prayer.enabled) {
          await _scheduleCustomPrayerNotification(prayer);
        }
      }
      debugPrint(
          'Scheduled ${currentPrayers.where((p) => p.enabled).length} custom prayer notifications');
    } catch (e) {
      debugPrint('Error scheduling custom prayers: $e');
    }
  }

  /// Schedule custom prayers for today (called daily at midnight)
  Future<void> _scheduleCustomPrayersForToday() async {
    try {
      final currentPrayers = customPrayersNotifier.value;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final prayer in currentPrayers) {
        if (prayer.enabled) {
          // Calculate next occurrence for this prayer
          final nextOccurrence = prayer.getNextOccurrence();

          // Only schedule if it's today
          if (nextOccurrence.year == today.year &&
              nextOccurrence.month == today.month &&
              nextOccurrence.day == today.day) {
            // Schedule with Android Alarm Manager for exact timing
            await _scheduleCustomPrayerNotification(prayer);
            debugPrint(
                'Scheduled custom prayer ${prayer.name} for today at ${prayer.time}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error scheduling custom prayers for today: $e');
    }
  }

  /// Schedule single custom prayer alarm
  Future<void> _scheduleSingleCustomPrayerAlarm(CustomPrayer prayer) async {
    try {
      final nextOccurrence = prayer.getNextOccurrence();
      final alarmId = _getCustomPrayerAlarmIdAndroid(prayer.id);

      await AndroidAlarmManager.oneShotAt(
        nextOccurrence,
        alarmId,
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        alarmClock: true,
        params: <String, dynamic>{
          'prayer': prayer.name,
          'isCustom': true,
          'customPrayerId': prayer.id,
        },
      );
      debugPrint(
          '✅ Scheduled single Android alarm for custom prayer: ${prayer.name} at $nextOccurrence');

      // Also schedule with SimplePrayerNotificationService as backup
      await _scheduleCustomPrayerAlarmWithSimpleService(
          prayer.id, prayer.name, nextOccurrence);
    } catch (e) {
      debugPrint(
          '❌ Failed to schedule single Android alarm for custom prayer: ${prayer.name} - $e');
    }
  }

  Future<void> _saveCustomPrayers(List<CustomPrayer> prayers) async {
    try {
      final prayersJson = prayers.map((p) => p.toJson()).toList();
      await _prefs.setCustomPrayers(prayersJson);
    } catch (e) {
      debugPrint('Error saving custom prayers: $e');
      rethrow;
    }
  }

  Future<void> _scheduleCustomPrayerNotification(CustomPrayer prayer) async {
    try {
      if (!prayer.enabled) return;

      final nextOccurrence = prayer.getNextOccurrence();

      // Schedule notification with zonedSchedule for automatic adhan playback when app opens
      final success = await _unifiedNotificationService!.schedulePrayerNotification(
        prayerId: prayer.id,
        prayerName: prayer.name,
        scheduledTime: nextOccurrence,
        isCustom: true,
      );

      if (success) {
        debugPrint(
            '✅ Successfully scheduled custom prayer notification: ${prayer.name} at $nextOccurrence');
      } else {
        debugPrint(
            '❌ Failed to schedule custom prayer notification: ${prayer.name}');
      }
    } catch (e) {
      debugPrint('Error scheduling custom prayer notification: $e');
    }
  }

  Future<void> _cancelCustomPrayerNotification(String id) async {
    try {
      debugPrint('Cancelling custom prayer notification for ID: $id');

      // Use the simple notification service
      final success = await _unifiedNotificationService!.cancelNotification(id);

      if (success) {
        debugPrint(
            '✅ Successfully cancelled custom prayer notification for ID: $id');
      } else {
        debugPrint('❌ Failed to cancel custom prayer notification for ID: $id');
      }
    } catch (e) {
      debugPrint('Error cancelling custom prayer notification: $e');
    }
  }

  /// Test custom prayer notification immediately to verify it works
  Future<void> _testCustomPrayerNotification(CustomPrayer prayer) async {
    try {
      debugPrint('Testing custom prayer notification for: ${prayer.name}');

      // Use the same method as the test button - handle custom prayer notification
      await handleCustomPrayerNotification(prayer.id, prayer.name,
          autoStartAdhan: true);

      debugPrint(
          'Custom prayer notification test completed for: ${prayer.name}');
    } catch (e) {
      debugPrint('Error testing custom prayer notification: $e');
    }
  }

  int _getCustomPrayerId(String prayerId) {
    // Generate a unique ID for custom prayers (avoiding conflicts with regular prayer IDs)
    return 2000000 + int.parse(prayerId.substring(prayerId.length - 6));
  }

  int _getCustomPrayerAlarmId(String prayerId) {
    // Generate a unique alarm ID for custom prayers (avoiding conflicts with regular prayer alarm IDs)
    return 3000000 + int.parse(prayerId.substring(prayerId.length - 6));
  }

  /// Schedule custom prayer alarm using native Android CustomPrayerAlarmReceiver
  Future<bool> _scheduleNativeCustomPrayerAlarm(
      String prayerId, String prayerName, int scheduledTimeMillis) async {
    try {
      // Use MethodChannel to call native Android code
      const MethodChannel customPrayerChannel =
          MethodChannel('custom_prayer_alarm');

      debugPrint(
          'Attempting to schedule custom prayer alarm via MethodChannel: $prayerName at ${DateTime.fromMillisecondsSinceEpoch(scheduledTimeMillis)}');

      final result = await customPrayerChannel
          .invokeMethod<bool>('scheduleCustomPrayerAlarm', {
        'prayerId': prayerId,
        'prayerName': prayerName,
        'scheduledTime': scheduledTimeMillis,
        'payload':
            '{"custom_prayer":"$prayerName", "id":"$prayerId", "auto_play":true}',
      });

      final success = result ?? false;
      debugPrint('Custom prayer alarm scheduling result: $success');

      return success;
    } catch (e) {
      debugPrint('Error scheduling native custom prayer alarm: $e');
      // Fallback to direct Android Alarm Manager if MethodChannel fails
      return await _fallbackScheduleCustomPrayerAlarm(
          prayerId, prayerName, scheduledTimeMillis);
    }
  }

  /// Schedule custom prayer alarm using SimplePrayerNotificationService
  Future<bool> _scheduleCustomPrayerAlarmWithSimpleService(
      String prayerId, String prayerName, DateTime scheduledTime) async {
    try {
      debugPrint(
          'Scheduling custom prayer alarm with SimplePrayerNotificationService: $prayerName at $scheduledTime');

      // Use the simple and reliable notification service
      final success =
          await _unifiedNotificationService!.schedulePrayerNotification(
        prayerId: prayerId,
        prayerName: prayerName,
        scheduledTime: scheduledTime,
        isCustom: true,
      );

      if (success) {
        debugPrint(
            '✅ Successfully scheduled custom prayer alarm with SimplePrayerNotificationService: $prayerName');
      } else {
        debugPrint(
            '❌ Failed to schedule custom prayer alarm with SimplePrayerNotificationService: $prayerName');
      }

      return success;
    } catch (e) {
      debugPrint(
          'Error scheduling custom prayer alarm with SimplePrayerNotificationService: $e');
      return false;
    }
  }

  /// Fallback method to schedule custom prayer alarm directly
  Future<bool> _fallbackScheduleCustomPrayerAlarm(
      String prayerId, String prayerName, int scheduledTimeMillis) async {
    try {
      debugPrint('Using fallback scheduling for custom prayer: $prayerName');

      // For fallback, we'll use the standard prayer alarm callback
      // This ensures at least some functionality even if the new system fails
      await AndroidAlarmManager.oneShotAt(
        DateTime.fromMillisecondsSinceEpoch(scheduledTimeMillis),
        _getCustomPrayerAlarmId(prayerId),
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        alarmClock: true,
        params: <String, dynamic>{
          'prayer': prayerName,
          'isCustom': true,
          'customPrayerId': prayerId,
          'payload':
              '{"custom_prayer":"$prayerName", "id":"$prayerId", "auto_play":true}',
        },
      );

      debugPrint('Fallback custom prayer alarm scheduled successfully');
      return true;
    } catch (e) {
      debugPrint('Fallback scheduling also failed: $e');
      return false;
    }
  }

  /// Cancel custom prayer alarm using native Android CustomPrayerAlarmReceiver
  Future<bool> _cancelNativeCustomPrayerAlarm(String prayerId) async {
    try {
      const MethodChannel customPrayerChannel =
          MethodChannel('custom_prayer_alarm');

      debugPrint(
          'Attempting to cancel custom prayer alarm via MethodChannel: $prayerId');

      final result = await customPrayerChannel
          .invokeMethod<bool>('cancelCustomPrayerAlarm', {
        'prayerId': prayerId,
      });

      final success = result ?? false;
      debugPrint('Custom prayer alarm cancellation result: $success');

      return success;
    } catch (e) {
      debugPrint('Error cancelling native custom prayer alarm: $e');
      // Fallback to direct Android Alarm Manager cancellation
      return await _fallbackCancelCustomPrayerAlarm(prayerId);
    }
  }

  /// Fallback method to cancel custom prayer alarm directly
  Future<bool> _fallbackCancelCustomPrayerAlarm(String prayerId) async {
    try {
      debugPrint('Using fallback cancellation for custom prayer: $prayerId');

      await AndroidAlarmManager.cancel(_getCustomPrayerAlarmId(prayerId));

      debugPrint('Fallback custom prayer alarm cancelled successfully');
      return true;
    } catch (e) {
      debugPrint('Fallback cancellation also failed: $e');
      return false;
    }
  }

  /// Handle prayer notification - unified method for both background and foreground
  Future<void> _handlePrayerNotification(
    String? prayerName, {
    bool isBackground = false,
    bool autoStartAdhan = true,
    String? customPrayerId,
  }) async {
    try {
      debugPrint(
          'Handling prayer notification: $prayerName (background: $isBackground, customId: $customPrayerId)');

      // Show prayer notification
      await _showPrayerTimeNotification(prayerName);

      // Automatically start adhan playback if enabled
      if (autoStartAdhan) {
        await _playAdhanFromNotification(prayerName);
      }

      debugPrint('Prayer notification handled successfully: $prayerName');
    } catch (error, stackTrace) {
      debugPrint('Error in prayer notification handler: $error\n$stackTrace');
    }
  }

  /// Show prayer time notification
  Future<void> _showPrayerTimeNotification(String? prayerName) async {
    try {
      final notifications = AthkarkNotifications.instance;
      final plugin = notifications.plugin;

      await plugin.show(
        888888, // Prayer notification ID
        'حان وقت صلاة ${prayerName ?? ''}',
        'انقر لفتح التطبيق وبدء الأذان',
        NotificationDetails(
          android: AndroidNotificationDetails(
            kAdhanNotificationChannelId,
            kAdhanNotificationChannelName,
            channelDescription: kAdhanNotificationChannelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('adhan'),
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload:
            '{"action":"prayer_notification", "prayer":"${prayerName ?? ''}", "timestamp":"${DateTime.now().toIso8601String()}"}',
      );

      debugPrint('Prayer time notification sent for: $prayerName');
    } catch (error, stackTrace) {
      debugPrint(
          'Failed to show prayer time notification: $error\n$stackTrace');
    }
  }

  /// Play adhan specifically triggered by prayer notification
  Future<void> _playAdhanFromNotification(String? prayerName) async {
    if (prayerName != null) {
      await _simpleAudioService!.playAdhan(prayerName);
    }
  }

  /// Fallback method to play adhan when direct playback fails
  Future<void> _playAdhanFallback(String? prayerName) async {
    try {
      debugPrint('🔄 Trying fallback adhan playback for: $prayerName');

      // Use AudioService as fallback
      final AudioHandler handler = await AudioService.init(
        builder: () => _AdhanAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: _adhanPlaybackChannelId,
          androidNotificationChannelName: 'تشغيل الأذان',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          preloadArtwork: true,
          androidNotificationIcon: 'ic_stat_athkark',
        ),
      );

      if (prayerName != null) {
        await handler.customAction(
          'configure',
          <String, dynamic>{'prayer': prayerName, 'isCustom': false},
        );
      }

      // Short delay to ensure configuration is complete
      await Future.delayed(const Duration(milliseconds: 200));

      await handler.play();
      debugPrint(
          '✅ Fallback adhan playback started successfully for: $prayerName');
    } catch (fallbackError) {
      debugPrint('❌ Fallback adhan playback also failed: $fallbackError');
      // Last resort - show notification only
      await _showAdhanNotificationOnly(prayerName);
    }
  }

  /// Show notification when audio playback fails completely
  Future<void> _showAdhanNotificationOnly(String? prayerName) async {
    try {
      debugPrint(
          '📢 Showing adhan notification only (no audio) for: $prayerName');

      final notifications = AthkarkNotifications.instance;
      final plugin = notifications.plugin;

      await plugin.show(
        999999, // Special ID for audio-failed notifications
        'حان وقت صلاة ${prayerName ?? ''}',
        'انقر لفتح التطبيق - لم يتم تشغيل الصوت',
        NotificationDetails(
          android: AndroidNotificationDetails(
            kAdhanNotificationChannelId,
            kAdhanNotificationChannelName,
            channelDescription: kAdhanNotificationChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: false, // No sound since audio failed
            enableVibration: true,
            enableLights: true,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false, // No sound since audio failed
          ),
        ),
        payload:
            '{"action":"prayer_notification", "prayer":"${prayerName ?? ''}", "audio_failed":true}',
      );

      debugPrint('📢 Adhan notification shown (audio failed) for: $prayerName');
    } catch (notificationError) {
      debugPrint('❌ Even notification failed: $notificationError');
    }
  }

  void dispose() {
    _midnightTimer?.cancel();
    _testTimer?.cancel();
  }

  Future<void> playTestAdhan() async {
    await _playTestAdhan();
  }

  Future<void> startTestAdhan() async {
    if (_testMode) return;
    _testMode = true;
    _testTimer?.cancel();
    _testTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      await _playTestAdhan();
    });
  }

  Future<void> stopTestAdhan() async {
    _testMode = false;
    _testTimer?.cancel();
    _testTimer = null;
  }

  bool get isTestMode => _testMode;

  Future<void> _playTestAdhan() async {
    debugPrint('Starting test adhan playback');
    try {
      // Use async isolation to prevent gesture interference
      await _playTestAdhanAsync();
    } catch (error, stackTrace) {
      debugPrint('Failed to start test adhan playback: $error\n$stackTrace');
    }
  }

  /// Isolated async method for audio service initialization
  /// Prevents gesture event interference with Flutter
  Future<void> _playTestAdhanAsync() async {
    // Run in a separate microtask to isolate from UI events
    await Future.microtask(() async {
      try {
        // Simplified approach - try to initialize AudioService directly
        // The audio_service package handles concurrent initialization gracefully

        debugPrint('Initializing AudioService');

        final AudioHandler handler = await AudioService.init(
          builder: () => _AdhanAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: _adhanPlaybackChannelId,
            androidNotificationChannelName: 'تشغيل الأذان التجريبي',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            preloadArtwork: true,
            androidNotificationIcon: 'ic_stat_athkark',
          ),
        );

        debugPrint('AudioService initialized');

        // Configure after a brief delay to ensure initialization is complete
        await Future.delayed(const Duration(milliseconds: 100));

        await handler.customAction(
          'configure',
          <String, dynamic>{'prayer': 'تجريبي'},
        );

        debugPrint('Custom action configured');

        // Add additional delay before playing
        await Future.delayed(const Duration(milliseconds: 300));

        debugPrint('Calling play');
        await handler.play();
        debugPrint('Play called successfully');
      } catch (error, stackTrace) {
        debugPrint('Error in _playTestAdhanAsync: $error\n$stackTrace');
        rethrow;
      }
    });
  }

  Future<void> _ensureNotificationPermissions() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isLimited) {
        return;
      }

      final result = await Permission.notification.request();
      if (!result.isGranted && !result.isLimited) {
        debugPrint(
            'Notification permission not granted; adhan alerts may be blocked');
      }

      // Request exact alarm / notification permissions via plugin as well
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications?.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  void _ensureTimezone() {
    if (_timezoneReady) {
      return;
    }
    tz.initializeTimeZones();
    if (tz.local.name == 'UTC' && _prefs.latitude != null) {
      final double lat = _prefs.latitude!;
      final double lng = _prefs.longitude!;
      try {
        final tz.Location location = tz.getLocation(_guessTimezone(lat, lng));
        tz.setLocalLocation(location);
      } catch (_) {
        // Fallback to system default if guessing fails.
      }
    }
    _timezoneReady = true;
  }

  Future<void> _ensureAndroidChannel() async {
    if (!Platform.isAndroid) {
      return;
    }
    final AndroidFlutterLocalNotificationsPlugin? android =
        _notifications?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return;
    }
    await android.deleteNotificationChannel(kAdhanNotificationChannelId);
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        kAdhanNotificationChannelId,
        kAdhanNotificationChannelName,
        description: 'تنبيه الأذان بصوت هادئ',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('adhan_soft'),
        playSound: true,
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  Future<void> _scheduleForDay({
    required Map<PrayerType, DateTime> times,
    required Map<PrayerType, bool> enabled,
    required bool advancedAudio,
  }) async {
    await _cancelExistingNotifications();
    await _scheduleNotifications(times: times, enabled: enabled);
    await _scheduleAdvancedAlarms(
      times: times,
      enabled: enabled,
      advancedAudio: advancedAudio,
    );
    await _prefs.setLastScheduleDate(DateTime.now());

    // Schedule with Android Alarm Manager for automatic triggering
    await _scheduleAndroidAlarms(times: times, enabled: enabled);
  }

  /// Schedule Android alarms for automatic prayer triggering
  Future<void> _scheduleAndroidAlarms({
    required Map<PrayerType, DateTime> times,
    required Map<PrayerType, bool> enabled,
  }) async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now();
    for (final MapEntry<PrayerType, DateTime> entry in times.entries) {
      if (!(enabled[entry.key] ?? false)) {
        continue;
      }
      if (entry.value.isBefore(now)) {
        continue;
      }

      try {
        await AndroidAlarmManager.oneShotAt(
          entry.value,
          entry.key.alarmId,
          prayerAlarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          alarmClock: true,
          params: <String, dynamic>{
            'prayer': entry.key.displayName,
            'isCustom': false,
          },
        );
        debugPrint(
            '✅ Scheduled Android alarm for: ${entry.key.displayName} at ${entry.value}');
      } catch (e) {
        debugPrint(
            '❌ Failed to schedule Android alarm for: ${entry.key.displayName} - $e');
      }
    }

    // Also schedule custom prayers with Android Alarm Manager
    await _scheduleCustomPrayersAndroidAlarms();
  }

  /// Schedule custom prayers with Android Alarm Manager
  Future<void> _scheduleCustomPrayersAndroidAlarms() async {
    if (!Platform.isAndroid) return;

    final customPrayers = customPrayersNotifier.value;
    final now = DateTime.now();

    for (final prayer in customPrayers) {
      if (!prayer.enabled) continue;

      final nextOccurrence = prayer.getNextOccurrence();
      if (nextOccurrence.isBefore(now)) continue;

      try {
        final alarmId = _getCustomPrayerAlarmIdAndroid(prayer.id);
        await AndroidAlarmManager.oneShotAt(
          nextOccurrence,
          alarmId,
          prayerAlarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          alarmClock: true,
          params: <String, dynamic>{
            'prayer': prayer.name,
            'isCustom': true,
            'customPrayerId': prayer.id,
          },
        );
        debugPrint(
            '✅ Scheduled Android alarm for custom prayer: ${prayer.name} at $nextOccurrence');
      } catch (e) {
        debugPrint(
            '❌ Failed to schedule Android alarm for custom prayer: ${prayer.name} - $e');
      }
    }

    // Also schedule with flutter_local_notifications as backup
    await _scheduleCustomPrayersWithNotifications();
  }

  /// Schedule custom prayers with flutter_local_notifications as backup
  Future<void> _scheduleCustomPrayersWithNotifications() async {
    final customPrayers = customPrayersNotifier.value;
    final now = DateTime.now();

    for (final prayer in customPrayers) {
      if (!prayer.enabled) continue;

      final nextOccurrence = prayer.getNextOccurrence();
      if (nextOccurrence.isBefore(now)) continue;

      try {
        await _unifiedNotificationService!.schedulePrayerNotification(
          prayerId: prayer.id,
          prayerName: prayer.name,
          scheduledTime: nextOccurrence,
          isCustom: true,
        );
        debugPrint(
            '✅ Scheduled notification backup for custom prayer: ${prayer.name} at $nextOccurrence');
      } catch (e) {
        debugPrint(
            '❌ Failed to schedule notification backup for custom prayer: ${prayer.name} - $e');
      }
    }
  }

  /// Get unique alarm ID for custom prayers (Android Alarm Manager)
  int _getCustomPrayerAlarmIdAndroid(String prayerId) {
    return 4000000 + int.parse(prayerId.substring(prayerId.length - 6));
  }

  /// Schedule notifications using the simple and reliable service
  Future<void> _scheduleWithSimpleService({
    required Map<PrayerType, DateTime> times,
    required Map<PrayerType, bool> enabled,
  }) async {
    try {
      for (final MapEntry<PrayerType, DateTime> entry in times.entries) {
        if (!(enabled[entry.key] ?? false)) {
          continue;
        }
        if (entry.value.isBefore(DateTime.now())) {
          continue;
        }

        final success =
            await _unifiedNotificationService!.schedulePrayerNotification(
          prayerId: entry.key.name,
          prayerName: entry.key.displayName,
          scheduledTime: entry.value,
          isCustom: false,
        );

        if (success) {
          debugPrint(
              '✅ Scheduled simple notification for: ${entry.key.displayName}');
        } else {
          debugPrint(
              '❌ Failed to schedule simple notification for: ${entry.key.displayName}');
        }
      }
    } catch (e) {
      debugPrint('Error scheduling with simple service: $e');
    }
  }

  Future<void> _cancelExistingNotifications() async {
    if (_notifications == null) {
      return;
    }
    for (final PrayerType prayer in PrayerType.values) {
      await _notifications!.cancel(prayer.notificationId);
    }
  }

  Future<void> _scheduleNotifications({
    required Map<PrayerType, DateTime> times,
    required Map<PrayerType, bool> enabled,
  }) async {
    if (_notifications == null) {
      return;
    }
    final DateTime now = DateTime.now();
    for (final MapEntry<PrayerType, DateTime> entry in times.entries) {
      if (!(enabled[entry.key] ?? false)) {
        continue;
      }
      if (entry.value.isBefore(now)) {
        continue;
      }
      await _scheduleSingleNotification(
        id: entry.key.notificationId,
        title: 'حان وقت صلاة ${entry.key.displayName}',
        when: entry.value,
      );
    }
  }

  Future<void> _scheduleSingleNotification({
    required int id,
    required String title,
    required DateTime when,
  }) async {
    final tz.TZDateTime tzWhen = tz.TZDateTime.from(when, tz.local);
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      kAdhanNotificationChannelId,
      kAdhanNotificationChannelName,
      channelDescription: kAdhanNotificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: 'adhan_soft.caf',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _notifications!.zonedSchedule(
      id,
      title,
      'افتح لعرض الأذكار بعد الأذان',
      tzWhen,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '{"route":"/adhkar?type=post_prayer"}',
    );
  }

  Future<void> _scheduleAdvancedAlarms({
    required Map<PrayerType, DateTime> times,
    required Map<PrayerType, bool> enabled,
    required bool advancedAudio,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    // Cancel all existing alarms first
    for (final PrayerType prayer in PrayerType.values) {
      await AndroidAlarmManager.cancel(prayer.alarmId);
    }
    if (!advancedAudio) {
      return;
    }
    final DateTime now = DateTime.now();
    for (final MapEntry<PrayerType, DateTime> entry in times.entries) {
      if (!(enabled[entry.key] ?? false)) {
        continue;
      }
      if (entry.value.isBefore(now)) {
        continue;
      }
      await AndroidAlarmManager.oneShotAt(
        entry.value,
        entry.key.alarmId,
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        alarmClock: true,
        params: <String, dynamic>{
          'prayer': entry.key.displayName,
          'isCustom': false,
        },
      );
    }
  }

  _PrayerComputationResult _computePrayerTimes(Coordinates coordinates) {
    final DateTime now = DateTime.now();
    final DateTime date = DateTime(now.year, now.month, now.day);
    final CalculationParameters params =
        _parametersForMethod(_prefs.calculationMethod);
    params.madhab = _prefs.madhab;

    final PrayerTimes times = PrayerTimes(
      date: date,
      coordinates: coordinates,
      calculationParameters: params,
      precision: true,
    );

    final Map<PrayerType, DateTime> mapped = <PrayerType, DateTime>{
      PrayerType.fajr: times.fajr.toLocal(),
      PrayerType.dhuhr: times.dhuhr.toLocal(),
      PrayerType.asr: times.asr.toLocal(),
      PrayerType.maghrib: times.maghrib.toLocal(),
      PrayerType.isha: times.isha.toLocal(),
    };

    final PrayerType? nextPrayer = _nextPrayerFromTimes(mapped);
    return _PrayerComputationResult(
      times: mapped,
      sunrise: times.sunrise.toLocal(),
      nextPrayer: nextPrayer,
    );
  }

  _PrayerComputationResult _computePrayerTimesWithParams(
      Coordinates coordinates, CalculationParameters params) {
    final DateTime now = DateTime.now();
    final DateTime date = DateTime(now.year, now.month, now.day);

    final PrayerTimes times = PrayerTimes(
      date: date,
      coordinates: coordinates,
      calculationParameters: params,
      precision: true,
    );

    final Map<PrayerType, DateTime> mapped = <PrayerType, DateTime>{
      PrayerType.fajr: times.fajr.toLocal(),
      PrayerType.dhuhr: times.dhuhr.toLocal(),
      PrayerType.asr: times.asr.toLocal(),
      PrayerType.maghrib: times.maghrib.toLocal(),
      PrayerType.isha: times.isha.toLocal(),
    };

    final PrayerType? nextPrayer = _nextPrayerFromTimes(mapped);
    return _PrayerComputationResult(
      times: mapped,
      sunrise: times.sunrise.toLocal(),
      nextPrayer: nextPrayer,
    );
  }

  PrayerType? _nextPrayerFromTimes(Map<PrayerType, DateTime> times) {
    final DateTime now = DateTime.now();
    final List<MapEntry<PrayerType, DateTime>> sorted = times.entries.toList()
      ..sort(
        (MapEntry<PrayerType, DateTime> a, MapEntry<PrayerType, DateTime> b) =>
            a.value.compareTo(b.value),
      );
    for (final MapEntry<PrayerType, DateTime> entry in sorted) {
      if (entry.value.isAfter(now)) {
        return entry.key;
      }
    }
    return null;
  }

  Future<_LocationResolution> _resolveLocation({
    required bool forceRequest,
  }) async {
    PrayerLocationStatus status = PrayerLocationStatus.ready;
    Coordinates? coordinates;
    String? placeName;

    if (!forceRequest) {
      final double? storedLat = _prefs.latitude;
      final double? storedLng = _prefs.longitude;
      if (storedLat != null && storedLng != null) {
        coordinates = Coordinates(storedLat, storedLng);
        placeName = _prefs.placeName;
      }
    }

    bool needLookup = coordinates == null || forceRequest;
    if (needLookup) {
      final bool locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        status = PrayerLocationStatus.serviceDisabled;
        placeName ??= _prefs.placeName;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (forceRequest) {
            try {
              permission = await Geolocator.requestPermission().timeout(
                const Duration(seconds: 5),
                onTimeout: () => permission, // Keep current permission on timeout
              );
            } catch (e) {
              debugPrint('Permission request failed or timed out: $e');
              // Keep current permission
            }
          }
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          status = PrayerLocationStatus.permissionDenied;
          placeName ??= _prefs.placeName;
        } else {
          try {
            final Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            );
            coordinates = Coordinates(
              position.latitude,
              position.longitude,
            );
            await _prefs.setCoordinates(
              position.latitude,
              position.longitude,
            );
            status = PrayerLocationStatus.ready;
            placeName = await _reverseGeocode(
              position.latitude,
              position.longitude,
            );
            await _prefs.setPlaceName(placeName);
          } on TimeoutException {
            status = PrayerLocationStatus.serviceDisabled;
          } on Exception {
            status = PrayerLocationStatus.serviceDisabled;
          }
        }
      }
    }

    final Coordinates resolvedCoordinates =
        coordinates ?? _defaultCoordinates();
    return _LocationResolution(
      coordinates: resolvedCoordinates,
      status: status,
      placeName: placeName,
    );
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final List<geocoding.Placemark> placemarks =
          await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        return null;
      }
      final geocoding.Placemark place = placemarks.first;
      final String? localityRaw = place.locality?.trim();
      final String? adminRaw = place.administrativeArea?.trim();
      final String? locality = (localityRaw != null && localityRaw.isNotEmpty)
          ? localityRaw
          : (adminRaw != null && adminRaw.isNotEmpty ? adminRaw : null);
      final String? country = place.country?.trim();
      if (locality != null &&
          locality.isNotEmpty &&
          country != null &&
          country.isNotEmpty) {
        return '$locality، $country';
      }
      if (locality != null && locality.isNotEmpty) {
        return locality;
      }
      if (country != null && country.isNotEmpty) {
        return country;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  CalculationParameters _parametersForMethod(CalculationMethod method) {
    switch (method) {
      case CalculationMethod.dubai:
        return CalculationMethodParameters.dubai();
      case CalculationMethod.egyptian:
        return CalculationMethodParameters.egyptian();
      case CalculationMethod.karachi:
        return CalculationMethodParameters.karachi();
      case CalculationMethod.kuwait:
        return CalculationMethodParameters.kuwait();
      case CalculationMethod.moonsightingCommittee:
        return CalculationMethodParameters.moonsightingCommittee();
      case CalculationMethod.morocco:
        return CalculationMethodParameters.morocco();
      case CalculationMethod.muslimWorldLeague:
        return CalculationMethodParameters.muslimWorldLeague();
      case CalculationMethod.northAmerica:
        return CalculationMethodParameters.northAmerica();
      case CalculationMethod.other:
        return CalculationMethodParameters.other();
      case CalculationMethod.qatar:
        return CalculationMethodParameters.qatar();
      case CalculationMethod.singapore:
        return CalculationMethodParameters.singapore();
      case CalculationMethod.tehran:
        return CalculationMethodParameters.tehran();
      case CalculationMethod.turkiye:
        return CalculationMethodParameters.turkiye();
      case CalculationMethod.ummAlQura:
        return CalculationMethodParameters.ummAlQura();
    }
  }

  Coordinates _defaultCoordinates() => const Coordinates(15.3694, 44.191);

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final DateTime now = DateTime.now();
    final DateTime target = DateTime(now.year, now.month, now.day + 1, 0, 10);
    _midnightTimer = Timer(
      target.difference(now),
      () => refreshAndSchedule(forceLocation: false),
    );
  }

  void _scheduleCustomPrayersMidnightRefresh() {
    final DateTime now = DateTime.now();
    final DateTime target = DateTime(now.year, now.month, now.day + 1, 0,
        15); // 15 seconds after midnight refresh
    Timer(
      target.difference(now),
      () => _scheduleCustomPrayersForToday(),
    );
  }

  String _guessTimezone(double lat, double lng) {
    if (lat > 20 && lng > 50 && lng < 60) {
      return 'Asia/Riyadh';
    }
    if (lat < 25 && lng > 40 && lng < 50) {
      return 'Asia/Aden';
    }
    return tz.local.name;
  }
}

class _LocationResolution {
  const _LocationResolution({
    required this.coordinates,
    required this.status,
    required this.placeName,
  });

  final Coordinates coordinates;
  final PrayerLocationStatus status;
  final String? placeName;
}

class _PrayerComputationResult {
  const _PrayerComputationResult({
    required this.times,
    required this.sunrise,
    required this.nextPrayer,
  });

  final Map<PrayerType, DateTime> times;
  final DateTime sunrise;
  final PrayerType? nextPrayer;
}

@pragma('vm:entry-point')
Future<void> prayerAlarmCallback(
  int id,
  Map<String, dynamic>? data,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  final String? prayer = data?['prayer'] as String?;
  final bool isCustom = data?['isCustom'] as bool? ?? false;
  final String? customPrayerId = data?['customPrayerId'] as String?;

  try {
    // Simple duplicate prevention using SharedPreferences
    final canExecute = await _checkDuplicateExecution(id);
    if (!canExecute) {
      debugPrint('🛡️ Duplicate callback execution prevented for: $prayer');
      return;
    }

    // Show prayer notification first (lightweight)
    await _showPrayerNotification(prayer, isCustom, customPrayerId);

    // Play adhan in isolated execution
    await _playAdhanFromAlarm(prayer, isCustom: isCustom);
  } catch (error, stackTrace) {
    debugPrint('Failed in prayer callback: $error\n$stackTrace');
  }
}

/// Show prayer notification - lightweight, but fully initialized for reliability
Future<void> _showPrayerNotification(
    String? prayer, bool isCustom, String? customPrayerId) async {
  try {
    final plugin = await _prepareAlarmNotificationPlugin();

    const androidDetails = AndroidNotificationDetails(
      'prayer_alarm_channel',
      'Prayer Notifications',
      channelDescription: 'Prayer time notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'adhan.mp3',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
    await plugin.show(
      888888,
      'Prayer time: ${prayer ?? ''}',
      'Adhan is playing for your reminder',
      notificationDetails,
      payload: '{"prayer":"${prayer ?? ''}", "isCustom":$isCustom}',
    );
  } catch (e) {
    debugPrint('Failed to show prayer notification: $e');
  }
}

Future<FlutterLocalNotificationsPlugin>
    _prepareAlarmNotificationPlugin() async {
  final plugin = FlutterLocalNotificationsPlugin();

  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_athkark'),
    iOS: DarwinInitializationSettings(),
  );

  await plugin.initialize(initializationSettings);

  const channel = AndroidNotificationChannel(
    'prayer_alarm_channel',
    'Prayer Notifications',
    description: 'Prayer time notifications',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('adhan'),
  );

  final androidImplementation = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidImplementation?.createNotificationChannel(channel);

  return plugin;
}

/// Simple duplicate execution prevention using SharedPreferences
Future<bool> _checkDuplicateExecution(int alarmId) async {
  try {
    final key = 'alarm_execution_lock_$alarmId';
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if another execution is happening
    final lastExecution = prefs.getInt(key);
    if (lastExecution != null) {
      final timeDiff = now - lastExecution;
      if (timeDiff < 15000) {
        // 15 seconds
        return false; // Prevent execution
      }
    }

    // Record this execution
    await prefs.setInt(key, now);

    // Also cleanup old locks
    await _cleanupOldLocks();

    return true;
  } catch (e) {
    debugPrint('⚠️ Error checking duplicate execution: $e');
    return true; // Continue to be safe
  }
}

/// Cleanup old execution locks
Future<void> _cleanupOldLocks() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('alarm_execution_lock_'))
        .toList();

    if (keys.length > 50) {
      // Keep only recent 50 locks
      final oldKeys = keys.sublist(0, keys.length - 50);
      for (final key in oldKeys) {
        await prefs.remove(key);
      }
      debugPrint('🧹 Cleaned up ${oldKeys.length} old alarm locks');
    }
  } catch (e) {
    debugPrint('⚠️ Error cleaning old locks: $e');
  }
}

/// Isolated method for alarm-triggered adhan playback
/// Prevents interference with UI gesture events
Future<void> _playAdhanFromAlarm(String? prayer,
    {bool isCustom = false}) async {
  await Future.microtask(() async {
    try {
      debugPrint(
          '🎯 ALARM TRIGGERED: Starting adhan for prayer: $prayer (custom: $isCustom)');

      // Try direct audio playback first (more reliable for alarms)
      try {
        await _playAdhanDirectFromAlarm(prayer);
        debugPrint('✅ Direct adhan playback from alarm succeeded for: $prayer');
        return;
      } catch (directError) {
        debugPrint(
            '❌ Direct adhan playback failed, trying AudioService: $directError');
      }

      // Fallback to AudioService
      final AudioHandler handler = await AudioService.init(
        builder: () => _AdhanAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: _adhanPlaybackChannelId,
          androidNotificationChannelName: 'تشغيل الأذان',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          preloadArtwork: true,
          androidNotificationIcon: 'ic_stat_athkark',
        ),
      );

      if (prayer != null) {
        await handler.customAction(
          'configure',
          <String, dynamic>{'prayer': prayer, 'isCustom': isCustom},
        );
      }

      // Short delay to ensure configuration is complete
      await Future.delayed(const Duration(milliseconds: 200));

      await handler.play();

      debugPrint(
          '✅ AudioService adhan playback started successfully for: $prayer');
    } catch (error, stackTrace) {
      debugPrint('❌ Error in alarm callback: $error\n$stackTrace');
      rethrow;
    }
  });
}

/// Direct audio playback for alarm callbacks (most reliable)
Future<void> _playAdhanDirectFromAlarm(String? prayer) async {
  debugPrint('🔊 Playing adhan directly from alarm for: $prayer');

  final ja.AudioPlayer player = ja.AudioPlayer();

  try {
    // Set volume to maximum
    await player.setVolume(1.0);

    // Load audio source
    final audioSource = ja.AudioSource.asset('assets/adhan/adhan.mp3');
    await player.setAudioSource(audioSource);

    // Verify audio loaded
    final duration = player.duration;
    if (duration == null || duration.inMilliseconds == 0) {
      throw Exception('Invalid audio duration: $duration');
    }

    debugPrint('✅ Alarm audio loaded, duration: ${duration.inMilliseconds}ms');

    // Start playback
    await player.play();

    // Wait a bit to ensure playback started
    await Future.delayed(const Duration(milliseconds: 500));

    if (player.playing) {
      debugPrint('✅ Alarm adhan is playing successfully!');
    } else {
      throw Exception('Playback did not start');
    }

    // Keep player alive for the duration of the adhan (typically 30-60 seconds)
    await Future.delayed(const Duration(seconds: 35));
  } finally {
    await player.dispose();
    debugPrint('🗑️ Alarm audio player disposed');
  }
}

class _AdhanAudioHandler extends BaseAudioHandler with SeekHandler {
  _AdhanAudioHandler() {
    debugPrint('AdhanAudioHandler constructor called');
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.playerStateStream.listen(_handlePlayerState);
    mediaItem.add(_currentMediaItem());
    debugPrint('AdhanAudioHandler initialized');
  }

  final ja.AudioPlayer _player = ja.AudioPlayer();
  String _title = 'الأذان';
  bool _prepared = false;
  bool _playing = false;

  MediaItem _currentMediaItem() => MediaItem(
        id: 'adhan_asset',
        title: _title,
        artist: 'Athkark',
      );

  Future<void> _prepare() async {
    if (_prepared) {
      debugPrint('Already prepared');
      return;
    }
    debugPrint('Preparing audio source');
    try {
      // First check if the audio file exists by trying to load it
      final audioSource = ja.AudioSource.asset('assets/adhan/adhan.mp3');
      await _player.setAudioSource(audioSource);
      _prepared = true;
      debugPrint('Audio source prepared successfully');
    } on ja.PlayerException catch (error) {
      debugPrint('Failed to load adhan audio: ${error.message}');
      debugPrint(
          'Audio file might not exist or is corrupted. Using fallback tone.');

      // Try fallback - generate a simple test tone
      await _prepareFallbackTone();
    } on ja.PlayerInterruptedException catch (error) {
      debugPrint('Adhan playback interrupted: ${error.message}');
      _prepared = false;
    } catch (error) {
      debugPrint('Unexpected error during adhan preparation: $error');
      debugPrint('Using fallback tone instead.');
      await _prepareFallbackTone();
    }
  }

  /// Fallback method to create a simple test tone when audio file is missing
  Future<void> _prepareFallbackTone() async {
    try {
      debugPrint('Preparing fallback test tone');
      // Use a simple tone or silent audio as fallback
      // For now, just mark as prepared with no audio
      _prepared = true;
      debugPrint('Fallback preparation completed');
    } catch (error) {
      debugPrint('Even fallback preparation failed: $error');
      _prepared = true; // Mark as prepared to avoid retries
    }
  }

  @override
  Future<void> play() async {
    if (_playing) {
      debugPrint('Already playing, skipping');
      return;
    }
    _playing = true;
    debugPrint('Starting play');

    try {
      await _prepare();

      // Only attempt playback if we have a prepared source
      if (_prepared) {
        debugPrint('Prepared, setting media item');
        mediaItem.add(_currentMediaItem());
        debugPrint('Media item set, starting playback');

        // Try to play, but handle cases where audio might not be available
        try {
          await _player.play();
          debugPrint('Playback started');
          playbackState.add(playbackState.value.copyWith(playing: true));
        } catch (playError) {
          debugPrint('Audio playback failed: $playError');
          debugPrint(
              'This is normal if audio file is missing. Providing visual feedback instead.');
          _playing = false;
          // Don't throw - this is expected when audio file is missing
        }
      } else {
        debugPrint('Audio preparation failed, cannot play');
        _playing = false;
      }
    } catch (error) {
      debugPrint('Error during play preparation: $error');
      _playing = false;
      // Don't rethrow - graceful handling of missing audio
    }
  }

  @override
  Future<void> stop() async {
    debugPrint('Stopping playback');
    _playing = false;
    _prepared = false; // Reset prepared flag to allow re-preparation
    try {
      await _player.stop();
      debugPrint('Player stopped');
      await _player.dispose();
      debugPrint('Player disposed');
    } catch (error) {
      debugPrint('Error during stop: $error');
    }
    return super.stop();
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'configure') {
      final String? prayer = extras?['prayer'] as String?;
      final bool isCustom = extras?['isCustom'] as bool? ?? false;
      if (prayer != null && prayer.isNotEmpty) {
        debugPrint('Configuring for prayer: $prayer (custom: $isCustom)');
        _title = prayer == 'تجريبي' ? 'أذان تجريبي' : 'أذان $prayer';
        mediaItem.add(_currentMediaItem());
        debugPrint('Media item updated to: $_title');
      }
    }
    return null;
  }

  PlaybackState _transformEvent(ja.PlaybackEvent event) {
    return PlaybackState(
      controls: <MediaControl>[MediaControl.stop],
      systemActions: const <MediaAction>{},
      androidCompactActionIndices: const <int>[0],
      processingState: _mapProcessingState(event.processingState),
      playing: _player.playing,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      updateTime: event.updateTime,
    );
  }

  AudioProcessingState _mapProcessingState(ja.ProcessingState state) {
    switch (state) {
      case ja.ProcessingState.idle:
        return AudioProcessingState.idle;
      case ja.ProcessingState.loading:
        return AudioProcessingState.loading;
      case ja.ProcessingState.buffering:
        return AudioProcessingState.loading;
      case ja.ProcessingState.ready:
        return AudioProcessingState.ready;
      case ja.ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _handlePlayerState(ja.PlayerState state) {
    debugPrint('Player state changed: ${state.processingState}');

    // Only handle completion when we actually have audio playing
    if (_playing && (state.processingState == ja.ProcessingState.completed)) {
      debugPrint('Playback completed naturally, stopping');
      _playing = false;
      playbackState.add(playbackState.value.copyWith(playing: false));
      Future.delayed(const Duration(milliseconds: 100), () => stop());
    } else if (state.processingState == ja.ProcessingState.idle && _playing) {
      debugPrint(
          'Player went idle during playback - likely audio file missing');
      _playing = false;
      playbackState.add(playbackState.value.copyWith(playing: false));
      // Don't stop the service, just mark as not playing
    }
  }
}
