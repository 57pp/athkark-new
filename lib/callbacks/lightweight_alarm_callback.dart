import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Lightweight alarm callback - without duplicate initialization
@pragma('vm:entry-point')
Future<void> prayerAlarmCallback(int id, Map<String, dynamic>? data) async {
  // Ensure Flutter binding is ready for UI operations
  WidgetsFlutterBinding.ensureInitialized();
  
  final fln = FlutterLocalNotificationsPlugin();
  await _ensureFlnInitIfNeeded(fln);
  await _showScheduledNotification(fln, data);
}

/// Ensure FlutterLocalNotificationsPlugin is initialized if needed
Future<void> _ensureFlnInitIfNeeded(FlutterLocalNotificationsPlugin fln) async {
  try {
    // Check if already initialized
    final initialized = await fln.getNotificationAppLaunchDetails();
    if (initialized != null) {
      // Already initialized, no need to initialize again
      return;
    }
    
    // Minimal initialization only if needed
    const androidSettings = AndroidInitializationSettings('ic_stat_athkark');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) => _handleNotification(response),
    );
    
    print('✅ FLN initialized in callback');
  } catch (e) {
    print('⚠️ FLN init failed in callback: $e');
    // Continue anyway - notifications might still work
  }
}

/// Show scheduled notification with minimal setup
Future<void> _showScheduledNotification(FlutterLocalNotificationsPlugin fln, Map<String, dynamic>? data) async {
  try {
    final prayer = data?['prayer'] as String? ?? 'صلاة';
    final isCustom = data?['isCustom'] as bool? ?? false;
    final customPrayerId = data?['customPrayerId'] as String?;
    
    const androidDetails = AndroidNotificationDetails(
      'prayer_alarm_channel',
      'Prayer Notifications',
      channelDescription: 'Prayer time notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      fullScreenIntent: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await fln.show(
      888888,
      'حان وقت صلاة $prayer',
      isCustom ? 'انقر لتشغيل الأذان' : 'انقر لفتح التطبيق',
      notificationDetails,
      payload: '{"prayer":"$prayer", "isCustom":$isCustom, "customPrayerId":"${customPrayerId ?? ""}"}',
    );
    
    print('📢 Prayer notification shown: $prayer');
  } catch (e) {
    print('⚠️ Failed to show prayer notification: $e');
  }
}

/// Handle notification tap
Future<void> _handleNotification(NotificationResponse response) async {
  try {
    // Parse notification data
    final payload = response.payload;
    if (payload == null) return;
    
    // Handle prayer notifications
    if (payload.contains('"prayer"')) {
      print('📱 Prayer notification tapped: ${response.payload}');
      // Could trigger additional actions like opening app or playing adhan
    }
  } catch (e) {
    print('⚠️ Error handling notification tap: $e');
  }
}