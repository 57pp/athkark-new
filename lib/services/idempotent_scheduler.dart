import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/local_store.dart';

/// Idempotent Scheduler - prevents duplicate scheduling
class IdempotentScheduler {
  static const String _pendingKey = 'pending_notifications';
  static const int _maxCacheSize = 100;

  /// Generate consistent notification ID for deduplication
  static int notificationIdFor(String key, DateTime timeUtc) {
    final k = '${key}_${timeUtc.millisecondsSinceEpoch}';
    return k.hashCode & 0x7fffffff; // موجب وثابت
  }

  /// Schedule notification once - prevent duplicates
  static Future<bool> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required Map<String, dynamic> payload,
    required FlutterLocalNotificationsPlugin plugin,
  }) async {
    try {
      // Check if notification already exists
      final pending = await plugin.pendingNotificationRequests();
      
      if (pending.any((p) => p.id == id)) {
        print('🛡️ Notification already scheduled: $title');
        return true; // Already scheduled, don't reschedule
      }

      // Convert to timezone-aware
      final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      // Schedule the notification
      await plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_channel',
            'Prayer Notifications',
            channelDescription: 'Prayer time notifications',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
          ),
        ),
        payload: _encodePayload(payload),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      // Cache the scheduled notification for duplicate prevention
      await _cacheScheduledNotification(id, scheduledTime);
      print('✅ Notification scheduled: $title at $scheduledTime');
      return true;

    } catch (e) {
      print('❌ Failed to schedule notification: $e');
      return false;
    }
  }

  /// Cancel notification if it exists
  static Future<bool> cancelOnce({
    required int id,
    required FlutterLocalNotificationsPlugin plugin,
  }) async {
    try {
      final pending = await plugin.pendingNotificationRequests();
      
      if (pending.any((p) => p.id == id)) {
        await plugin.cancel(id);
        await _removeCachedNotification(id);
        print('✅ Notification cancelled: $id');
        return true;
      } else {
        print('🛡️ Notification already cancelled: $id');
        return true;
      }
    } catch (e) {
      print('❌ Failed to cancel notification: $e');
      return false;
    }
  }

  /// Cache scheduled notification for duplicate prevention
  static Future<void> _cacheScheduledNotification(int id, DateTime time) async {
    try {
      final cache = await LocalStore.getStringMap(_pendingKey) ?? {};
      cache[id.toString()] = time.toIso8601String();
      
      // Limit cache size
      if (cache.length > _maxCacheSize) {
        final oldestKeys = cache.keys.toList()
          ..sort();
        for (final oldKey in oldestKeys.sublist(0, cache.length - _maxCacheSize)) {
          cache.remove(oldKey);
        }
        print('🧹 Cleaned up old notification cache entries');
      }
      
      await LocalStore.setStringMap(_pendingKey, cache);
    } catch (e) {
      print('⚠️ Failed to cache notification: $e');
    }
  }

  /// Remove notification from cache
  static Future<void> _removeCachedNotification(int id) async {
    try {
      final cache = await LocalStore.getStringMap(_pendingKey) ?? {};
      cache.remove(id.toString());
      await LocalStore.setStringMap(_pendingKey, cache);
    } catch (e) {
      print('⚠️ Failed to remove cached notification: $e');
    }
  }

  /// Get pending notification count
  static Future<int> getPendingCount() async {
    try {
      final cache = await LocalStore.getStringMap(_pendingKey) ?? {};
      return cache.length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all cached notifications (useful for cleanup)
  static Future<void> clearCache() async {
    try {
      await LocalStore.setStringMap(_pendingKey, {});
      print('🧹 Notification cache cleared');
    } catch (e) {
      print('⚠️ Failed to clear notification cache: $e');
    }
  }

  /// Encode payload to JSON string
  static String _encodePayload(Map<String, dynamic> payload) {
    try {
      return payload.toString(); // Simple string encoding
    } catch (e) {
      return '{}';
    }
  }
}