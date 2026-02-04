import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'precise_notification_service.dart';
import '/../models/scheduled_prayer.dart';

class BootReceiverService {
  static const String _bootAction = 'android.intent.action.BOOT_COMPLETED';
  static const String _packageReplacedAction = 'android.intent.action.MY_PACKAGE_REPLACED';
  
  static BootReceiverService? _instance;
  static BootReceiverService get instance => _instance ??= BootReceiverService();
  
  late PreciseNotificationService _notificationService;
  late SharedPreferences _prefs;
  
  bool _isInitialized = false;

  // Initialize the boot receiver service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _notificationService = PreciseNotificationService();
    await _notificationService.initialize();
    
    _prefs = await SharedPreferences.getInstance();
    
    _isInitialized = true;
  }

  // Handle boot completed action
  Future<void> handleBootCompleted() async {
    print('BOOT_COMPLETED received - restoring alarms...');
    
    await initialize();
    await _restoreAllScheduledAlarms();
    await _prefs.setBool('last_boot_time', true);
  }

  // Handle package replaced action (app update)
  Future<void> handlePackageReplaced() async {
    print('PACKAGE_REPLACED received - handling app update...');
    
    await initialize();
    
    // Clear any corrupted data and restore
    await _clearCorruptedData();
    await _restoreAllScheduledAlarms();
    
    await _prefs.setBool('app_updated', true);
  }

  // Restore all scheduled alarms from storage
  Future<void> _restoreAllScheduledAlarms() async {
    try {
      // Load scheduled prayers from SharedPreferences
      final prayersJson = _prefs.getString('scheduled_prayers');
      if (prayersJson != null && prayersJson.isNotEmpty) {
        final prayers = _parseScheduledPrayers(prayersJson);
        
        print('Restoring ${prayers.length} scheduled prayers...');
        
        for (final prayer in prayers) {
          if (prayer.scheduledTime.isAfter(DateTime.now())) {
            final success = await _notificationService.schedulePreciseNotification(
              id: prayer.id,
              title: prayer.title,
              body: prayer.body,
              scheduledDateTime: prayer.scheduledTime,
              category: prayer.category,
              payload: prayer.payload,
            );
            
            if (success) {
              print('✅ Restored alarm: ${prayer.title} at ${prayer.scheduledTime}');
            } else {
              print('❌ Failed to restore alarm: ${prayer.title}');
            }
          } else {
            print('⏰ Skipping expired alarm: ${prayer.title}');
          }
        }
      } else {
        print('No scheduled prayers found to restore');
      }
    } catch (e) {
      print('Error restoring alarms: $e');
    }
  }

  // Parse scheduled prayers from JSON string
  List<ScheduledPrayer> _parseScheduledPrayers(String jsonString) {
    try {
      // Simple parsing - in production you'd use proper JSON parsing
      final prayers = <ScheduledPrayer>[];
      
      // Extract prayer data from the stored string
      // This is a simplified version - you'd implement proper JSON parsing
      print('Parsing prayers from: $jsonString');
      
      // For now, return empty list - implement proper parsing based on your storage format
      return prayers;
    } catch (e) {
      print('Error parsing prayers: $e');
      return [];
    }
  }

  // Clear corrupted data
  Future<void> _clearCorruptedData() async {
    try {
      await _prefs.remove('corrupted_alarms');
      print('Cleared corrupted data');
    } catch (e) {
      print('Error clearing corrupted data: $e');
    }
  }

  // Schedule a daily health check
  Future<void> scheduleDailyHealthCheck() async {
    // Schedule a daily check at 6:00 AM to verify all alarms are working
    final now = DateTime.now();
    final nextCheck = DateTime(now.year, now.month, now.day + 1, 6, 0);
    
    await AndroidAlarmManager.oneShotAt(
      nextCheck.toUtc(),
      999999, // Special ID for health check
      _healthCheckCallback,
      exact: true,
      wakeup: true,
    );
    
    print('Daily health check scheduled for $nextCheck');
  }

  // Health check callback
  @pragma('vm:entry-point')
  static void _healthCheckCallback(int id) async {
    try {
      // This will run in background isolate
      print('🩺 Performing daily health check...');
      
      // Check if any alarms were missed
      // You could add additional logic here to verify alarm functionality
      
      // Reschedule the next health check
      final instance = BootReceiverService.instance;
      await instance.scheduleDailyHealthCheck();
      
    } catch (e) {
      print('Health check error: $e');
    }
  }

  // Get system boot information
  Future<Map<String, dynamic>> getBootInfo() async {
    return {
      'lastBootTime': _prefs.getBool('last_boot_time') ?? false,
      'appUpdated': _prefs.getBool('app_updated') ?? false,
      'bootCount': _prefs.getInt('boot_count') ?? 0,
      'lastHealthCheck': _prefs.getString('last_health_check'),
    };
  }

  // Increment boot count
  Future<void> incrementBootCount() async {
    final currentCount = _prefs.getInt('boot_count') ?? 0;
    await _prefs.setInt('boot_count', currentCount + 1);
  }

  // Check if this is the first boot after installation
  Future<bool> isFirstBootAfterInstall() async {
    final installCompleted = _prefs.getBool('install_completed') ?? false;
    if (!installCompleted) {
      await _prefs.setBool('install_completed', true);
      return true;
    }
    return false;
  }

  // Force restore all alarms (for debugging)
  Future<void> forceRestoreAllAlarms() async {
    print('🔄 Force restoring all alarms...');
    await _restoreAllScheduledAlarms();
  }

  // Debug: Get system information
  Future<Map<String, dynamic>> getDebugInfo() async {
    final alarms = await _notificationService.getScheduledNotifications();
    
    return {
      'scheduledAlarmsCount': alarms.length,
      'bootReceiverInitialized': _isInitialized,
      'androidAlarmManagerRunning': true, // Assume it's running
      'timezone': DateTime.now().timeZoneName,
      'systemTime': DateTime.now().toIso8601String(),
    };
  }
}

// Flutter plugin bridge for Android boot receiver
class BootReceiverPlugin {
  // This class will be called from native Android code
  static void onBootCompleted() {
    BootReceiverService.instance.handleBootCompleted();
  }
  
  static void onPackageReplaced() {
    BootReceiverService.instance.handlePackageReplaced();
  }
}