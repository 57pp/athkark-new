import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

/// Manages adhan repeat scheduling and tracking
class AdhanRepeatManager {
  static AdhanRepeatManager? _instance;
  static AdhanRepeatManager get instance => _instance ??= AdhanRepeatManager();

  // Preferences keys
  static const String _repeatKey = 'adhan_repeat_prayer_name';
  static const String _repeatTimeKey = 'adhan_repeat_timestamp';
  static const String _repeatIdKey = 'adhan_repeat_id';

  // Repeat configuration
  static const int _defaultRepeatMinutes = 10;
  static const int _maxRepeatId = 3000000;

  /// Schedule adhan to repeat after specified minutes
  Future<bool> scheduleRepeat(
    String prayerName, {
    int minutes = _defaultRepeatMinutes,
    bool exact = true,
    bool wakeup = true,
  }) async {
    try {
      final repeatTime = DateTime.now().add(Duration(minutes: minutes));
      final repeatId = _generateUniqueId();

      print(
          '🔄 Scheduling repeat for $prayerName at $repeatTime (ID: $repeatId)');

      // Save repeat information
      await _saveRepeatInfo(prayerName, repeatTime, repeatId);

      // Schedule the alarm
      if (await AndroidAlarmManager.oneShotAt(
        repeatTime,
        repeatId,
        _repeatAlarmCallback,
        exact: exact,
        wakeup: wakeup,
        rescheduleOnReboot: false,
      )) {
        print('✅ Repeat scheduled successfully with ID: $repeatId');
        return true;
      } else {
        print('❌ Failed to schedule repeat alarm');
        await _clearRepeatInfo();
        return false;
      }
    } catch (e) {
      print('❌ Error scheduling repeat: $e');
      await _clearRepeatInfo();
      return false;
    }
  }

  /// Cancel any scheduled repeat
  Future<bool> cancelRepeat() async {
    try {
      final repeatId = await _getRepeatId();
      if (repeatId != null) {
        final cancelled = await AndroidAlarmManager.cancel(repeatId);
        print('🛑 Repeat cancelled: $cancelled (ID: $repeatId)');
      }

      await _clearRepeatInfo();
      return true;
    } catch (e) {
      print('❌ Error cancelling repeat: $e');
      return false;
    }
  }

  /// Check if there's a scheduled repeat
  Future<bool> hasScheduledRepeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final repeatTime = prefs.getInt(_repeatTimeKey);

      if (repeatTime == null) return false;

      final savedTime = DateTime.fromMillisecondsSinceEpoch(repeatTime);
      final now = DateTime.now();

      // Check if the repeat time is still in the future or very recent (within 1 hour)
      return savedTime.isAfter(now.subtract(const Duration(hours: 1)));
    } catch (e) {
      print('⚠️ Error checking repeat status: $e');
      return false;
    }
  }

  /// Get remaining time until repeat (in minutes)
  Future<int> getRemainingMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final repeatTime = prefs.getInt(_repeatTimeKey);

      if (repeatTime == null) return 0;

      final savedTime = DateTime.fromMillisecondsSinceEpoch(repeatTime);
      final now = DateTime.now();

      if (savedTime.isAfter(now)) {
        return savedTime.difference(now).inMinutes;
      } else {
        // Repeat time has passed, clear it
        await _clearRepeatInfo();
        return 0;
      }
    } catch (e) {
      print('⚠️ Error getting remaining time: $e');
      return 0;
    }
  }

  /// Get the prayer name for scheduled repeat
  Future<String?> getScheduledPrayerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_repeatKey);
    } catch (e) {
      print('⚠️ Error getting prayer name: $e');
      return null;
    }
  }

  /// Generate unique repeat ID
  int _generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _maxRepeatId + (timestamp % 100000);
  }

  /// Save repeat information to preferences
  Future<void> _saveRepeatInfo(
      String prayerName, DateTime repeatTime, int repeatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_repeatKey, prayerName);
      await prefs.setInt(_repeatTimeKey, repeatTime.millisecondsSinceEpoch);
      await prefs.setInt(_repeatIdKey, repeatId);
    } catch (e) {
      print('⚠️ Error saving repeat info: $e');
    }
  }

  /// Clear repeat information
  Future<void> _clearRepeatInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_repeatKey);
      await prefs.remove(_repeatTimeKey);
      await prefs.remove(_repeatIdKey);
    } catch (e) {
      print('⚠️ Error clearing repeat info: $e');
    }
  }

  /// Get repeat ID from preferences
  Future<int?> _getRepeatId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_repeatIdKey);
    } catch (e) {
      print('⚠️ Error getting repeat ID: $e');
      return null;
    }
  }

  /// Callback function for repeat alarms
  static void _repeatAlarmCallback(int id) async {
    print('🔔 Repeat alarm triggered with ID: $id');

    try {
      // Initialize Flutter binding if needed
      WidgetsFlutterBinding.ensureInitialized();

      final prefs = await SharedPreferences.getInstance();
      final prayerName = prefs.getString(_repeatKey);
      final repeatTime = prefs.getInt(_repeatTimeKey);
      final savedId = prefs.getInt(_repeatIdKey);

      // Verify the alarm matches our saved data
      if (prayerName != null && repeatTime != null && savedId == id) {
        final savedTime = DateTime.fromMillisecondsSinceEpoch(repeatTime);
        final now = DateTime.now();

        // Only proceed if the time is reasonable (within 15 minutes of scheduled time)
        final timeDiff = now.difference(savedTime).inMinutes.abs();
        if (timeDiff <= 15) {
          print('✅ Valid repeat triggered for: $prayerName');

          // Clear the repeat info to prevent multiple triggers
          await prefs.remove(_repeatKey);
          await prefs.remove(_repeatTimeKey);
          await prefs.remove(_repeatIdKey);

          // In a real app, you would trigger the prayer notification system here
          // For now, we'll just log that it should trigger
          print('🎵 Repeat adhan should now play for: $prayerName');
        } else {
          print(
              '⚠️ Repeat time too far from scheduled time (diff: ${timeDiff}min), clearing');
          await prefs.remove(_repeatKey);
          await prefs.remove(_repeatTimeKey);
          await prefs.remove(_repeatIdKey);
        }
      } else {
        print('⚠️ Repeat data mismatch or missing, clearing');
        await prefs.remove(_repeatKey);
        await prefs.remove(_repeatTimeKey);
        await prefs.remove(_repeatIdKey);
      }
    } catch (e) {
      print('❌ Error in repeat callback: $e');
    }
  }

  /// Clean up expired repeat records
  Future<void> cleanupExpiredRepeats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final repeatTime = prefs.getInt(_repeatTimeKey);

      if (repeatTime != null) {
        final savedTime = DateTime.fromMillisecondsSinceEpoch(repeatTime);
        final now = DateTime.now();

        // Clear if repeat time is more than 2 hours old
        if (now.difference(savedTime).inHours > 2) {
          print('🧹 Cleaning up expired repeat record');
          await _clearRepeatInfo();
        }
      }
    } catch (e) {
      print('⚠️ Error cleaning up expired repeats: $e');
    }
  }
}
