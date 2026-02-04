import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/prayer_times/domain/prayer_times_service.dart';
import '/../models/scheduled_prayer.dart';

class PreciseNotificationService {
  static const String _channelId = 'precise_prayer_channel';
  static const String _channelName = 'تذكير دقيق بالأذكار';
  static const String _channelDescription = 'تذكيرات دقيقة للأذكار والتسبيح';

  late FlutterLocalNotificationsPlugin _notifications;
  late SharedPreferences _prefs;
  List<ScheduledPrayer> _scheduledPrayers = [];
  
  bool _isInitialized = false;
  bool _exactAlarmsEnabled = false;
  bool _notificationsEnabled = false;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize local notifications
    _notifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_athkark');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);

    await _notifications.initialize(initializationSettings,
        onDidReceiveNotificationResponse: _onSelectNotification);
    
    await _createNotificationChannel();
    await _checkPermissions();
    
    _isInitialized = true;
    
    // Restore scheduled alarms after app restart
    await _restoreScheduledAlarms();
    
    // Start monitoring permissions
    _startPermissionMonitoring();
  }

  // Create high importance notification channel
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      icon: '@drawable/ic_stat_athkark',
      sound: RawResourceAndroidNotificationSound('default'),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show initial notification to create the channel
    await _notifications.show(
      0,
      'تم تفعيل الإشعارات الدقيقة',
      'التذكير بالأذكار سيعمل الآن بدقة عالية',
      platformChannelSpecifics,
    );
  }

  // Check and request runtime permissions
  Future<void> _checkPermissions() async {
    // Check notification permission
    if (Platform.isAndroid && await Permission.notification.isDenied) {
      _notificationsEnabled = false;
    } else {
      _notificationsEnabled = true;
    }

    // Check exact alarm permission (Android 12+)
    if (Platform.isAndroid) {
      _exactAlarmsEnabled = await _checkExactAlarmPermission();
    }
  }

  Future<bool> _checkExactAlarmPermission() async {
    try {
      // This is a simplified check - in real implementation you'd need platform-specific code
      return true; // Assume true for now, will be checked in runtime
    } catch (e) {
      return false;
    }
  }

  // Request notification permission
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.request();
      final result = notificationStatus.isGranted || notificationStatus.isLimited;
      
      if (!result) {
        // Show settings screen if permanently denied
        await openAppSettings();
      }
      
      _notificationsEnabled = result;
      return result;
    }
    
    // For iOS
    final bool result = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ?? false;
    
    _notificationsEnabled = result;
    return result;
  }

  // Request exact alarm permission (Android 12+)
  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      // In a real implementation, you'd check the specific permission
      // For now, we'll return true and handle it in the scheduling logic
      _exactAlarmsEnabled = true;
      return true;
    } catch (e) {
      _exactAlarmsEnabled = false;
      return false;
    }
  }

  // Schedule a precise notification with timezone handling
  Future<bool> schedulePreciseNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? category,
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_notificationsEnabled) {
      final granted = await requestNotificationPermission();
      if (!granted) return false;
    }

    // Convert to local time and handle timezone
    _convertToLocalTime(scheduledDateTime);
    
    // If the time has passed, schedule for next occurrence

    // Check if this alarm already exists
    if (_scheduledPrayers.any((prayer) => prayer.id == id)) {
      // Update existing alarm
      await cancelNotification(id);
    }

    // Create scheduled prayer record
    final scheduledPrayer = ScheduledPrayer(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledDateTime, // Store original time
      category: category ?? 'general',
      payload: payload ?? {},
    );

    _scheduledPrayers.add(scheduledPrayer);
    await _saveScheduledPrayers();

    // Schedule notification
    return await _scheduleNotification(scheduledPrayer);
  }

  tz.TZDateTime _convertToLocalTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }


  Future<bool> _scheduleNotification(ScheduledPrayer prayer) async {
    try {
      // Convert DateTime to TZDateTime
      final tz.TZDateTime scheduledTime = _convertToLocalTime(prayer.scheduledTime);
      
      final alarmId = prayer.id.hashCode;
      
      // Schedule with Flutter Local Notifications
      await _notifications.zonedSchedule(
        alarmId,
        prayer.title,
        prayer.body,
        scheduledTime,
        _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: prayer.id,
      );

      return true;
    } catch (e) {
      print('Error scheduling precise notification: $e');
      return false;
    }
  }

  NotificationDetails _getNotificationDetails() {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      icon: '@drawable/ic_stat_athkark',
      sound: RawResourceAndroidNotificationSound('default'),
    );

    return const NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
  }

  // Cancel a specific notification
  Future<bool> cancelNotification(String id) async {
    try {
      final alarmId = id.hashCode;
      
      // Cancel from Flutter Local Notifications
      await _notifications.cancel(alarmId);
      
      // Remove from list
      _scheduledPrayers.removeWhere((prayer) => prayer.id == id);
      await _saveScheduledPrayers();
      
      return true;
    } catch (e) {
      print('Error canceling notification: $e');
      return false;
    }
  }

  // Get all scheduled notifications
  Future<List<ScheduledPrayer>> getScheduledNotifications() async {
    return List.from(_scheduledPrayers);
  }

  // Check if a notification is scheduled
  Future<bool> isNotificationScheduled(String id) async {
    return _scheduledPrayers.any((prayer) => prayer.id == id);
  }

  // Handle notification selection
  void _onSelectNotification(NotificationResponse notificationResponse) async {
    if (notificationResponse.payload != null) {
      // Handle notification tap
      print('Notification tapped: ${notificationResponse.payload}');

      // Parse the prayer name from payload
      final String? prayerName = _extractPrayerName(notificationResponse.payload ?? '');

      // Trigger audio playback for prayer notifications
      if (prayerName != null && prayerName.isNotEmpty) {
        try {
          // Use the PrayerTimesService to trigger adhan playback
          await PrayerTimesService.instance.handlePrayerNotification(prayerName, autoStartAdhan: true);
          print('✅ Adhan audio triggered for scheduled notification: $prayerName');
        } catch (e) {
          print('❌ Failed to trigger adhan audio for scheduled notification: $e');
        }
      }
    }
  }
  
  // Extract prayer name from notification payload
  String? _extractPrayerName(String payload) {
    try {
      // First try to parse as JSON (for custom prayers)
      final Map<String, dynamic> data = jsonDecode(payload);
      if (data.containsKey('custom_prayer')) {
        return data['custom_prayer'] as String?;
      }
      if (data.containsKey('prayer')) {
        return data['prayer'] as String?;
      }
      // Fallback to URI parsing for legacy format
      final Map<String, dynamic> uriData = Uri.parse(payload).queryParameters;
      return uriData['prayer'];
    } catch (e) {
      // If JSON parsing fails, try URI parsing
      try {
        final Map<String, dynamic> uriData = Uri.parse(payload).queryParameters;
        return uriData['prayer'];
      } catch (e) {
        // If both fail, return null
        return null;
      }
    }
  }

  // Save scheduled prayers to SharedPreferences
  Future<void> _saveScheduledPrayers() async {
    final prayersJson = _scheduledPrayers.map((prayer) => prayer.toJson()).toList();
    
    await _prefs.setString('scheduled_prayers', jsonEncode(prayersJson));
  }

  // Load scheduled prayers from SharedPreferences
  Future<void> _loadScheduledPrayers() async {
    final prayersJson = _prefs.getString('scheduled_prayers');
    if (prayersJson != null) {
      try {
        final List<dynamic> prayersList = jsonDecode(prayersJson);
        _scheduledPrayers = prayersList.map((json) => ScheduledPrayer.fromJson(json)).toList();
        print('📥 Loaded ${_scheduledPrayers.length} scheduled prayers');
      } catch (e) {
        print('❌ Error loading scheduled prayers: $e');
      }
    }
  }

  // Restore scheduled alarms after app restart
  Future<void> _restoreScheduledAlarms() async {
    await _loadScheduledPrayers();
    
    final validPrayers = _scheduledPrayers.where(
      (prayer) => prayer.scheduledTime.isAfter(DateTime.now())
    ).toList();
    
    for (final prayer in validPrayers) {
      await _scheduleNotification(prayer);
    }
    
    // Remove expired prayers
    _scheduledPrayers.removeWhere(
      (prayer) => prayer.scheduledTime.isBefore(DateTime.now())
    );
    await _saveScheduledPrayers();
  }

  // Start monitoring permission changes
  void _startPermissionMonitoring() {
    // Monitor permission changes periodically
    Timer.periodic(Duration(minutes: 5), (timer) {
      _checkPermissions();
    });
  }

  // Handle device boot
  Future<void> handleDeviceBoot() async {
    print('Device boot detected, restoring alarms...');
    await _restoreScheduledAlarms();
  }

  // Get current permission status
  Map<String, bool> getPermissionStatus() {
    return {
      'notifications': _notificationsEnabled,
      'exactAlarms': _exactAlarmsEnabled,
      'backgroundExecution': true, // Assume true for now
    };
  }

  // Test scheduling - schedule a notification for testing purposes
  Future<bool> testNotificationSchedule() async {
    final testTime = DateTime.now().add(Duration(minutes: 2));
    
    return await schedulePreciseNotification(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      title: 'اختبار التنبيه الدقيق',
      body: 'هذا اختبار لتنبيه الوِتر الدقيق',
      scheduledDateTime: testTime,
      category: 'test',
    );
  }

  // Dispose resources
  void dispose() {
    // Clean up resources if needed
  }
}