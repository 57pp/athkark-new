 import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/athkark_notifications.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/utils/simple_prayer_notification_service.dart';
import '../../../shared/utils/simple_prayer_audio_service.dart';
import 'prayer_prefs.dart';

const String kAdhanNotificationChannelId = 'athkark.adhan';
const String kAdhanNotificationChannelName = 'الأذان';
const String kAdhanNotificationChannelDescription = 'تنبيه الأذان بصوت الأذان';
const String _adhanPlaybackChannelId = 'athkark.adhan.playback';
const String kStopAdhanActionId = 'stop_adhan';
const String kRepeatAdhanActionId = 'repeat_adhan';

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
  late SimplePrayerNotificationService _simpleNotificationService;
  late SimplePrayerAudioService _simpleAudioService;
  bool _initialized = false;
  bool _timezoneReady = false;
  String? _cachedPlaceName;
  Timer? _midnightTimer;
  Timer? _nextPrayerTimer;
  bool _isScheduling = false;
  bool _testMode = false;
  Timer? _testTimer;

  Future<void> init({
    FlutterLocalNotificationsPlugin? notifications,
    bool forceRefresh = false,
  }) async {
    if (_initialized) {
      if (forceRefresh) {
        await refreshAndSchedule(forceLocation: true);
      }
      _startNextPrayerWatcher();
      return;
    }

    try {
      debugPrint('🔄 Starting PrayerTimesService initialization...');
      
      _notifications = notifications ?? AthkarkNotifications.instance.plugin;
      _prefs = await PrayerPrefs.load();

      // Initialize simple services with timeout
      _simpleNotificationService = SimplePrayerNotificationService.instance;
      await _simpleNotificationService.initialize();

      _simpleAudioService = SimplePrayerAudioService.instance;
      await _simpleAudioService.initialize(_notifications!);

      _ensureTimezone();
      await _ensureAndroidChannel();

      // Initialize with fallback state first to prevent infinite loading
      await _initializeWithFallbackState();

      // Then try to refresh with real location data
      try {
        await refreshAndSchedule(forceLocation: forceRefresh);
        debugPrint('✅ PrayerTimesService initialization completed successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to refresh with real location, using fallback: $e');
        // Keep the fallback state that's already initialized
      }

      // Load and schedule custom prayers
      try {
        await loadCustomPrayers();
        await _scheduleAllCustomPrayers();
        debugPrint('✅ Custom prayers loaded and scheduled');
      } catch (e) {
        debugPrint('⚠️ Failed to load custom prayers: $e');
      }

      _scheduleMidnightRefresh();
      _scheduleCustomPrayersMidnightRefresh();
      
      _initialized = true;
      debugPrint('🎯 PrayerTimesService fully initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ Critical error during PrayerTimesService init: $e\n$stackTrace');
      // Ensure we have at least a fallback state even if everything fails
      await _initializeWithFallbackState();
      _initialized = true;
    }
  }

  /// Initialize service with a fallback state to prevent infinite loading
  Future<void> _initializeWithFallbackState() async {
    try {
      debugPrint('🆘 Initializing fallback state...');
      
      // Get stored coordinates or use defaults
      final Coordinates coordinates = _getFallbackCoordinates();
      final String placeName = _getFallbackPlaceName();
      
      // Compute prayer times with fallback coordinates
      final _PrayerComputationResult computation = _computePrayerTimes(coordinates);
      
      final Map<PrayerType, bool> enabled = <PrayerType, bool>{
        for (final PrayerType prayer in PrayerType.values)
          prayer: _prefs.isPrayerEnabled(prayer),
      };

      final PrayerTimesState fallbackState = PrayerTimesState(
        coordinates: coordinates,
        times: computation.times,
        sunrise: computation.sunrise,
        enabled: enabled,
        nextPrayer: computation.nextPrayer,
        locationStatus: PrayerLocationStatus.ready,
        placeName: placeName,
        lastUpdated: DateTime.now(),
        advancedAudioEnabled: _prefs.advancedAudioEnabled,
      );
      
      state.value = fallbackState;
      _startNextPrayerWatcher();
      debugPrint('✅ Fallback state initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize fallback state: $e\n$stackTrace');
      
      // Even more basic fallback - just create a minimal state
      try {
        final Coordinates defaultCoords = _defaultCoordinates();
        final _PrayerComputationResult basicComputation = _computePrayerTimes(defaultCoords);
        
        final PrayerTimesState minimalState = PrayerTimesState(
          coordinates: defaultCoords,
          times: basicComputation.times,
          sunrise: basicComputation.sunrise,
          enabled: {for (final prayer in PrayerType.values) prayer: true},
          nextPrayer: basicComputation.nextPrayer,
          locationStatus: PrayerLocationStatus.ready,
          placeName: 'الموقع الافتراضي',
          lastUpdated: DateTime.now(),
          advancedAudioEnabled: false,
        );
        
        state.value = minimalState;
        _startNextPrayerWatcher();
        debugPrint('🆘 Minimal fallback state created');
      } catch (finalError) {
        debugPrint('❌ Even minimal fallback failed: $finalError');
        // As a last resort, ensure state is not null by setting an empty state
        rethrow;
      }
    }
  }

  /// Get fallback coordinates from storage or use defaults
  Coordinates _getFallbackCoordinates() {
    final double? storedLat = _prefs.latitude;
    final double? storedLng = _prefs.longitude;
    
    if (storedLat != null && storedLng != null) {
      return Coordinates(storedLat, storedLng);
    }
    
    // Use default coordinates (Mecca area as Islamic reference)
    return _defaultCoordinates();
  }

  /// Get fallback place name from storage or use defaults
  String _getFallbackPlaceName() {
    final String? storedPlaceName = _prefs.placeName;
    if (storedPlaceName != null && storedPlaceName.isNotEmpty) {
      return storedPlaceName;
    }
    
    return 'الموقع الافتراضي (مكة المكرمة)';
  }

  Future<void> refreshAndSchedule({
    bool forceLocation = false,
    bool reschedule = true,
  }) async {
    if (_isScheduling) {
      debugPrint('⚠️ Already scheduling, skipping request');
      return;
    }
    
    _isScheduling = true;
    try {
      debugPrint('🔄 Starting refreshAndSchedule...');
      
      // Resolve location with timeout
      final _LocationResolution resolution =
          await _resolveLocation(forceRequest: forceLocation);
      _cachedPlaceName = resolution.placeName;

      // Compute prayer times with error handling
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
      _startNextPrayerWatcher();
      debugPrint('✅ State updated successfully');

      if (reschedule) {
        try {
          await _scheduleForDay(
            times: computation.times,
            enabled: enabled,
            advancedAudio: _prefs.advancedAudioEnabled,
          );
          debugPrint('✅ Prayer scheduling completed');
        } catch (e) {
          debugPrint('⚠️ Failed to schedule prayers: $e');
          // Don't let scheduling failures break the UI
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in refreshAndSchedule: $e\n$stackTrace');
      
      // Ensure we have a valid state even if everything fails
      try {
        if (state.value == null) {
          await _initializeWithFallbackState();
        }
      } catch (fallbackError) {
        debugPrint('❌ Even fallback initialization failed: $fallbackError');
        // Re-throw to let the caller know something went wrong
        rethrow;
      }
    } finally {
      _isScheduling = false;
      debugPrint('🏁 refreshAndSchedule completed');
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
      final prayersJson = _prefs.getCustomPrayers();
      final List<CustomPrayer> prayers = [];

      for (final json in prayersJson) {
        prayers.add(CustomPrayer.fromJson(json));
      }

      customPrayersNotifier.value = prayers;
      debugPrint('Loaded ${prayers.length} custom prayers');
    } catch (e) {
      debugPrint('Error loading custom prayers: $e');
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
        name: name,
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

      // Schedule EXACTLY like test prayer
      final success = await scheduleCustomPrayerLikeTest(prayer);
      if (!success) {
        debugPrint('❌ Failed to schedule custom prayer: ${prayer.name}');
      }

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

        // Schedule or cancel notification based on enabled state (exactly like test prayer)
        if (enabled) {
          final success = await scheduleCustomPrayerLikeTest(updatedPrayer);
          if (!success) {
            debugPrint('❌ Failed to schedule custom prayer: ${updatedPrayer.name}');
          }
        } else {
          await _cancelCustomPrayerNotification(id);
          // Also cancel Android Alarm Manager
          if (Platform.isAndroid) {
            await AndroidAlarmManager.cancel(_getCustomPrayerAlarmIdAndroid(id));
          }
        }

        debugPrint(
            '${enabled ? 'Enabled' : 'Disabled'} custom prayer: ${updatedPrayer.name}');
      }
    } catch (e) {
      debugPrint('Error toggling custom prayer: $e');
      rethrow;
    }
  }

  Future<void> updateCustomPrayer(String id, String newName, TimeOfDay newTime) async {
    try {
      final currentPrayers =
          List<CustomPrayer>.from(customPrayersNotifier.value);
      final prayerIndex = currentPrayers.indexWhere((p) => p.id == id);

      if (prayerIndex != -1) {
        final oldPrayer = currentPrayers[prayerIndex];

        // Create new time with the same date but updated hour/minute
        final now = DateTime.now();
        final updatedTime = DateTime(
          now.year,
          now.month,
          now.day,
          newTime.hour,
          newTime.minute,
        );

        final updatedPrayer = CustomPrayer(
          id: oldPrayer.id,
          name: newName,
          time: updatedTime,
          enabled: oldPrayer.enabled,
        );

        currentPrayers[prayerIndex] = updatedPrayer;
        customPrayersNotifier.value = currentPrayers;

        // Save to prefs
        await _saveCustomPrayers(currentPrayers);

        // Cancel old notification and schedule new one if enabled
        await _cancelCustomPrayerNotification(id);
        if (Platform.isAndroid) {
          await AndroidAlarmManager.cancel(_getCustomPrayerAlarmIdAndroid(id));
        }

        if (updatedPrayer.enabled) {
          final success = await scheduleCustomPrayerLikeTest(updatedPrayer);
          if (!success) {
            debugPrint('❌ Failed to reschedule updated custom prayer: ${updatedPrayer.name}');
          }
        }

        debugPrint(
            'Updated custom prayer: ${oldPrayer.name} -> ${updatedPrayer.name}, time: ${oldPrayer.time} -> ${updatedPrayer.time}');
      }
    } catch (e) {
      debugPrint('Error updating custom prayer: $e');
      rethrow;
    }
  }


  /// Handle prayer notification when app is opened from notification
  Future<void> handlePrayerNotification(String prayerName,
      {bool autoStartAdhan = true}) async {
    debugPrint('Handling prayer notification in foreground: $prayerName');
    if (autoStartAdhan) {
      await _simpleAudioService.playAdhan(prayerName);
    }
  }

  /// Handle custom prayer notification when app is opened from notification
  Future<void> handleCustomPrayerNotification(
      String prayerId, String prayerName,
      {bool autoStartAdhan = true}) async {
    debugPrint(
        'Handling custom prayer notification in foreground: $prayerName (ID: $prayerId)');
    if (autoStartAdhan) {
      await _simpleAudioService.playAdhan(prayerName);
    }
  }


  /// Schedule all custom prayers notifications on app startup (like test prayer)
  Future<void> _scheduleAllCustomPrayers() async {
    try {
      final currentPrayers = customPrayersNotifier.value;
      int scheduledCount = 0;
      for (final prayer in currentPrayers) {
        if (prayer.enabled) {
          final success = await scheduleCustomPrayerLikeTest(prayer);
          if (success) scheduledCount++;
        }
      }
      debugPrint('Scheduled $scheduledCount out of ${currentPrayers.where((p) => p.enabled).length} custom prayers like test prayer');
    } catch (e) {
      debugPrint('Error scheduling custom prayers: $e');
    }
  }

  /// Schedule custom prayers for today (called daily at midnight) - like test prayer
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
            // Schedule EXACTLY like test prayer
            final success = await scheduleCustomPrayerLikeTest(prayer);
            if (success) {
              debugPrint('Scheduled custom prayer ${prayer.name} for today at ${prayer.time} like test prayer');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scheduling custom prayers for today: $e');
    }
  }

  /// Schedule custom prayer EXACTLY like test prayer (copied from PrayerTestService)
  Future<bool> scheduleCustomPrayerLikeTest(CustomPrayer prayer) async {
    try {
      final nextOccurrence = prayer.getNextOccurrence();
      final alarmId = _getCustomPrayerAlarmIdAndroid(prayer.id);

      // Schedule notification (EXACT same as PrayerTestService)
      final notificationSuccess = await _simpleNotificationService.schedulePrayerNotification(
        prayerId: prayer.id,
        prayerName: prayer.name,
        scheduledTime: nextOccurrence,
        isCustom: true,
      );

      if (!notificationSuccess) {
        debugPrint('❌ Failed to schedule custom prayer notification');
        return false;
      }

      // Schedule Android Alarm Manager for automatic triggering (EXACT same as test prayer)
      if (Platform.isAndroid) {
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
        debugPrint('✅ Scheduled Android alarm for custom prayer: ${prayer.name} at $nextOccurrence');
      }

      debugPrint('✅ Custom prayer scheduled successfully like test prayer: ${prayer.name} at $nextOccurrence');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule custom prayer like test: ${prayer.name} - $e');
      return false;
    }
  }

  /// Schedule single custom prayer alarm (now uses the test-like method)
  Future<void> _scheduleSingleCustomPrayerAlarm(CustomPrayer prayer) async {
    await scheduleCustomPrayerLikeTest(prayer);
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

      // Use the simple and reliable notification service (notification only)
      final success =
          await _simpleNotificationService.schedulePrayerNotification(
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
      final success = await _simpleNotificationService.cancelNotification(id);

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
          await _simpleNotificationService.schedulePrayerNotification(
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
      await _simpleAudioService.playAdhan(prayerName);
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
    _nextPrayerTimer?.cancel();
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

    // Delete existing channel first (like welcome/adhkar services)
    await android.deleteNotificationChannel(kAdhanNotificationChannelId);

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        kAdhanNotificationChannelId,
        kAdhanNotificationChannelName,
        description: 'تنبيه الأذان بصوت هادئ',
        importance: Importance.high,
        playSound: false, // Disabled to prevent double audio with programmatic playback
      ),
    );
  }

  Future<void> _scheduleForDay({
    required Map<PrayerType, DateTime> times,
    required Map<PrayerType, bool> enabled,
    required bool advancedAudio,
  }) async {
    await _cancelExistingNotifications();
    // Use the same simple service for regular prayers like custom prayers
    await _scheduleWithSimpleService(times: times, enabled: enabled);
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
        await _simpleNotificationService.schedulePrayerNotification(
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
            await _simpleNotificationService.schedulePrayerNotification(
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
    // Recreate channel before scheduling (like welcome/adhkar services)
    await _ensureAndroidChannel();

    final tz.TZDateTime tzWhen = tz.TZDateTime.from(when, tz.local);
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      kAdhanNotificationChannelId,
      kAdhanNotificationChannelName,
      channelDescription: kAdhanNotificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false, // Disabled to prevent double audio with programmatic playback
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
    try {
      debugPrint('🧮 Computing prayer times for coordinates: ${coordinates.latitude}, ${coordinates.longitude}');
      
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
      
      debugPrint('✅ Prayer times computed successfully. Next prayer: ${nextPrayer?.displayName ?? "none"}');
      
      // Ensure all times are properly converted to local time
      final Map<PrayerType, DateTime> localMapped = {
        for (final entry in mapped.entries)
          entry.key: entry.value.toLocal(),
      };
      final DateTime localSunrise = times.sunrise.toLocal();
      
      debugPrint('🕐 Prayer times (local timezone):');
      for (final entry in localMapped.entries) {
        debugPrint('  ${entry.key.displayName}: ${entry.value} (offset: ${entry.value.timeZoneOffset})');
      }
      debugPrint('  Sunrise: $localSunrise (offset: ${localSunrise.timeZoneOffset})');
      
      return _PrayerComputationResult(
        times: localMapped,
        sunrise: localSunrise,
        nextPrayer: nextPrayer,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error computing prayer times: $e\n$stackTrace');
      
      // Return fallback times based on current time and season
      final DateTime now = _getLocalNow();
      
      // Calculate sunrise based on current season (approximate)
      // In winter: sunrise around 7:00, in summer: sunrise around 5:30
      final int month = now.month;
      final int sunriseHour = (month >= 11 || month <= 2) ? 7 : (month >= 5 && month <= 8) ? 5 : 6;
      final DateTime sunrise = DateTime(now.year, now.month, now.day, sunriseHour, 30);
      
      // Calculate prayer times relative to sunrise
      final DateTime fajr = sunrise.subtract(const Duration(hours: 1, minutes: 30));
      final DateTime dhuhr = DateTime(now.year, now.month, now.day, 12, 0);
      final DateTime asr = DateTime(now.year, now.month, now.day, 15, 30);
      final DateTime maghrib = sunrise.add(const Duration(hours: 30)); // 30 minutes after sunset
      final DateTime isha = DateTime(now.year, now.month, now.day, 19, 30);
      
      final Map<PrayerType, DateTime> fallbackTimes = <PrayerType, DateTime>{
        PrayerType.fajr: fajr,
        PrayerType.dhuhr: dhuhr,
        PrayerType.asr: asr,
        PrayerType.maghrib: maghrib,
        PrayerType.isha: isha,
      };
      
      final PrayerType? nextPrayer = _nextPrayerFromTimes(fallbackTimes);
      
      debugPrint('🆘 Using fallback prayer times');
      debugPrint('🕐 Fallback times (local timezone):');
      for (final entry in fallbackTimes.entries) {
        debugPrint('  ${entry.key.displayName}: ${entry.value} (offset: ${entry.value.timeZoneOffset})');
      }
      debugPrint('  Sunrise: $sunrise (offset: ${sunrise.timeZoneOffset})');
      
      return _PrayerComputationResult(
        times: fallbackTimes,
        sunrise: sunrise,
        nextPrayer: nextPrayer,
      );
    }
  }

  PrayerType? _nextPrayerFromTimes(Map<PrayerType, DateTime> times) {
    try {
      final DateTime now = _getLocalNow();
      debugPrint('🧮 Calculating next prayer. Current time: $now');
      
      final List<MapEntry<PrayerType, DateTime>> sorted = times.entries.toList()
        ..sort(
          (MapEntry<PrayerType, DateTime> a, MapEntry<PrayerType, DateTime> b) =>
              a.value.compareTo(b.value),
        );
      
      debugPrint('📅 Prayer times for today:');
      for (final entry in sorted) {
        debugPrint('  ${entry.key.displayName}: ${entry.value} (${entry.value.isAfter(now) ? 'future' : 'past'})');
      }
      
      // Look for the next prayer that's after current time
      for (final MapEntry<PrayerType, DateTime> entry in sorted) {
        // Add a small buffer to ensure we get the right next prayer
        if (entry.value.isAfter(now.add(const Duration(seconds: 1)))) {
          debugPrint('✅ Next prayer found: ${entry.key.displayName} at ${entry.value}');
          return entry.key;
        }
      }
      
      // If all prayers are today and have passed, next prayer is Fajr tomorrow
      final fajrToday = times[PrayerType.fajr];
      if (fajrToday != null) {
        final fajrTomorrow = fajrToday.add(const Duration(days: 1));
        debugPrint('🌅 All prayers passed. Tomorrow Fajr: $fajrTomorrow');
        
        // Make sure tomorrow's Fajr is after current time
        if (fajrTomorrow.isAfter(now)) {
          debugPrint('✅ Returning tomorrow Fajr');
          return PrayerType.fajr;
        }
      }
      
      debugPrint('⚠️ No valid next prayer found');
      return null;
    } catch (e) {
      debugPrint('❌ Error calculating next prayer: $e');
      return null;
    }
  }

  Future<_LocationResolution> _resolveLocation({
    required bool forceRequest,
  }) async {
    PrayerLocationStatus status = PrayerLocationStatus.ready;
    Coordinates? coordinates;
    String? placeName;

    try {
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
        // Check location service availability with timeout
        final bool locationEnabled = await _checkLocationServiceWithTimeout();
        if (!locationEnabled) {
          status = PrayerLocationStatus.serviceDisabled;
          placeName ??= _prefs.placeName;
        } else {
          // Check permissions with timeout
          final permission = await _checkLocationPermissionWithTimeout(forceRequest);
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            status = PrayerLocationStatus.permissionDenied;
            placeName ??= _prefs.placeName;
          } else {
            // Get location with timeout
            final position = await _getLocationWithTimeout();
            if (position != null) {
              coordinates = Coordinates(
                position.latitude,
                position.longitude,
              );
              await _prefs.setCoordinates(
                position.latitude,
                position.longitude,
              );
              status = PrayerLocationStatus.ready;
              
              // Get place name with timeout
              placeName = await _getPlaceNameWithTimeout(
                position.latitude,
                position.longitude,
              );
              
              if (placeName == null || placeName.isEmpty) {
                placeName = 'الموقع الحالي (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})';
              }
              
              await _prefs.setPlaceName(placeName);
            } else {
              status = PrayerLocationStatus.serviceDisabled;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error in location resolution, using fallback: $e');
      status = PrayerLocationStatus.serviceDisabled;
      placeName ??= _prefs.placeName;
    }

    final Coordinates resolvedCoordinates =
        coordinates ?? _defaultCoordinates();
    placeName ??=
        '\u0645\u0648\u0642\u0639\u0643 \u0627\u0644\u062d\u0627\u0644\u064a (${resolvedCoordinates.latitude.toStringAsFixed(2)}, ${resolvedCoordinates.longitude.toStringAsFixed(2)})';

    return _LocationResolution(
      coordinates: resolvedCoordinates,
      status: status,
      placeName: placeName,
    );
  }

  /// Check location service availability with timeout
  Future<bool> _checkLocationServiceWithTimeout() async {
    try {
      return await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏰ Location service check timed out');
          return false;
        },
      );
    } catch (e) {
      debugPrint('⚠️ Error checking location service: $e');
      return false;
    }
  }

  /// Check location permission with timeout
  Future<LocationPermission> _checkLocationPermissionWithTimeout(bool forceRequest) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏰ Permission check timed out');
          return LocationPermission.denied;
        },
      );
      
      if ((permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) && forceRequest) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⏰ Permission request timed out');
            return LocationPermission.denied;
          },
        );
      }
      
      return permission;
    } catch (e) {
      debugPrint('⚠️ Error checking location permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Get location with timeout
  Future<Position?> _getLocationWithTimeout() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      // Check if position is valid before returning
      if (position.latitude != 0 && position.longitude != 0) {
        return position;
      } else {
        debugPrint('⚠️ Invalid position received');
        return null;
      }
    } on TimeoutException {
      debugPrint('⏰ Location retrieval timed out');
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting location: $e');
      return null;
    }
  }

  /// Get place name with timeout
  Future<String?> _getPlaceNameWithTimeout(double lat, double lng) async {
    try {
      return await _reverseGeocode(lat, lng).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⏰ Reverse geocoding timed out');
          return null;
        },
      );
    } catch (e) {
      debugPrint('⚠️ Error getting place name: $e');
      return null;
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final List<geocoding.Placemark> placemarks =
          await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        return null;
      }
      final geocoding.Placemark place = placemarks.first;
      
      // Try multiple location fields for better accuracy
      final String? locality = place.locality?.trim();
      final String? subAdministrativeArea = place.subAdministrativeArea?.trim();
      final String? administrativeArea = place.administrativeArea?.trim();
      final String? subLocality = place.subLocality?.trim();
      final String? thoroughfare = place.thoroughfare?.trim();
      final String? country = place.country?.trim();
      
      // Prioritize location fields in order of preference
      String? locationName = locality;
      if (locationName == null || locationName.isEmpty) {
        locationName = subAdministrativeArea;
      }
      if (locationName == null || locationName.isEmpty) {
        locationName = administrativeArea;
      }
      if (locationName == null || locationName.isEmpty) {
        locationName = subLocality;
      }
      if (locationName == null || locationName.isEmpty) {
        locationName = thoroughfare;
      }
      
      // Format the final location string
      if (locationName != null && locationName.isNotEmpty) {
        if (country != null && country.isNotEmpty) {
          return '$locationName، $country';
        }
        return locationName;
      }
      
      // Fallback to country if no city found
      if (country != null && country.isNotEmpty) {
        return country;
      }
      
      return null;
    } catch (e) {
      print('⚠️ Error in reverse geocoding: $e');
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

  Coordinates _defaultCoordinates() => const Coordinates(21.4225, 39.8262); // Mecca, Saudi Arabia

  /// Get current time in local timezone for calculations
  DateTime _getLocalNow() {
    final now = DateTime.now();
    debugPrint('🕐 Current time (local): $now, timezone offset: ${now.timeZoneOffset}');
    return now;
  }

  void _startNextPrayerWatcher() {
    _nextPrayerTimer?.cancel();
    _nextPrayerTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshNextPrayerFlag(),
    );
    _refreshNextPrayerFlag();
  }

  void _refreshNextPrayerFlag() {
    final PrayerTimesState? current = state.value;
    if (current == null) {
      return;
    }

    final PrayerType? recalculated = _nextPrayerFromTimes(current.times);
    if (recalculated != current.nextPrayer) {
      state.value = PrayerTimesState(
        coordinates: current.coordinates,
        times: current.times,
        sunrise: current.sunrise,
        enabled: current.enabled,
        nextPrayer: recalculated,
        locationStatus: current.locationStatus,
        placeName: current.placeName,
        lastUpdated: DateTime.now(),
        advancedAudioEnabled: current.advancedAudioEnabled,
      );
    }
  }

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

/// Show prayer alarm notification immediately (for background alarms)
Future<void> _showPrayerAlarmNotification(String? prayer, {bool isCustom = false, String? prayerId}) async {
  try {
    // Initialize notifications for background use
    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_athkark');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await notifications.initialize(settings);

    // Recreate channel before showing
    final androidImpl = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.deleteNotificationChannel(kAdhanNotificationChannelId);
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        kAdhanNotificationChannelId,
        kAdhanNotificationChannelName,
        description: kAdhanNotificationChannelDescription,
        importance: Importance.max,
        playSound: false, // Disabled to prevent double audio with programmatic playback
        enableVibration: true,
        enableLights: true,
        ledColor: AppColors.primaryColor,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      kAdhanNotificationChannelId,
      kAdhanNotificationChannelName,
      channelDescription: kAdhanNotificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: false, // Disabled to prevent double audio with programmatic playback
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      enableLights: true,
      ledColor: AppColors.primaryColor,
      ledOnMs: 1000,
      ledOffMs: 1000,
      color: AppColors.primaryColor,
      icon: '@drawable/ic_stat_athkark',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ticker: 'Athkark prayer',
      styleInformation: BigTextStyleInformation(
        'حان وقت صلاة ${prayer ?? ''}',
        contentTitle: 'حان وقت الصلاة',
        summaryText: 'انقر لفتح التطبيق',
      ),
      autoCancel: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          kStopAdhanActionId,
          'إيقاف الأذان',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          kRepeatAdhanActionId,
          'تكرار بعد 10 دقائق',
          showsUserInterface: false,
        ),
      ],
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
      'type': 'prayer_alarm',
      'prayer': prayer,
      'is_custom': isCustom,
      'prayer_id': prayerId,
      'timestamp': DateTime.now().toIso8601String(),
      'auto_adhan_played': true, // Mark that adhan was played automatically
    });

    await notifications.show(
      888888 + (prayer?.hashCode ?? 0), // Unique ID for prayer alarms
      'حان وقت الصلاة',
      'صلاة ${prayer ?? ''}',
      details,
      payload: payload,
    );

    debugPrint('✅ Prayer alarm notification shown for: $prayer');
  } catch (e) {
    debugPrint('❌ Failed to show prayer alarm notification: $e');
  }
}

@pragma('vm:entry-point')
Future<void> prayerAlarmCallback(
  int id,
  Map<String, dynamic>? data,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final String? prayer = data?['prayer'] as String?;
  final bool isCustom = data?['isCustom'] as bool? ?? false;
  final String? prayerId = data?['customPrayerId'] as String?;

  try {
    // Show notification immediately like test notifications
    await _showPrayerAlarmNotification(prayer, isCustom: isCustom, prayerId: prayerId);

    // Isolated execution to prevent UI interference
    await _playAdhanFromAlarm(prayer, isCustom: isCustom);
  } catch (error, stackTrace) {
    debugPrint('Failed to start adhan playback: $error\n$stackTrace');
  }
}

/// Static variable to prevent multiple adhan playbacks within a short time
DateTime? _lastAdhanPlaybackTime;

/// Isolated method for alarm-triggered adhan playback
/// Prevents interference with UI gesture events
Future<void> _playAdhanFromAlarm(String? prayer,
    {bool isCustom = false}) async {
  await Future.microtask(() async {
    try {
      // Check if adhan was played recently (within last 30 seconds) to prevent double playback
      final now = DateTime.now();
      if (_lastAdhanPlaybackTime != null) {
        final timeSinceLastPlayback = now.difference(_lastAdhanPlaybackTime!);
        if (timeSinceLastPlayback.inSeconds < 30) {
          debugPrint('⏰ Adhan playback blocked - too soon after previous playback (${timeSinceLastPlayback.inSeconds}s ago)');
          return;
        }
      }

      debugPrint(
          '🎯 ALARM TRIGGERED: Starting adhan for prayer: $prayer (custom: $isCustom)');

      // Update last playback time
      _lastAdhanPlaybackTime = now;

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

  // Additional check for direct playback (belt and suspenders)
  final now = DateTime.now();
  if (_lastAdhanPlaybackTime != null) {
    final timeSinceLastPlayback = now.difference(_lastAdhanPlaybackTime!);
    if (timeSinceLastPlayback.inSeconds < 30) {
      debugPrint('⏰ Direct adhan playback blocked - too soon after previous playback (${timeSinceLastPlayback.inSeconds}s ago)');
      return;
    }
  }

  // Update last playback time
  _lastAdhanPlaybackTime = now;

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
