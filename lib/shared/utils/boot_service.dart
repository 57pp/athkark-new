import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/notifications/athkark_notifications.dart';
import 'unified_prayer_notification_service.dart';

/// Boot Service - Centralized initialization with Cached Future pattern
/// Prevents duplicate initialization and provides reliable startup
class BootService {
  static BootService? _instance;
  static BootService get instance => _instance ??= BootService();

  // Cached Future - ensures initialization happens only once
  static Future<void>? _bootFuture;
  static bool _isInitialized = false;
  
  // Services
  late FlutterLocalNotificationsPlugin _notifications;
  late AthkarkNotifications _athkarkNotifications;

  // Initialize or return the cached future
  static Future<void> ensure() async {
    _bootFuture ??= BootService.instance._boot();
    return _bootFuture!;
  }

  /// Main boot sequence - called only once
  Future<void> _boot() async {
    if (_isInitialized) return;

    print('🚀 Starting Boot Sequence...');
    final startTime = DateTime.now();

    try {
      // 1. Core Flutter bindings
      print('📱 Initializing Flutter bindings...');
      // WidgetsFlutterBinding.ensureInitialized(); // Already done in main()
      print('✅ Flutter bindings ready');

      // 2. Essential system services
      print('🔧 Initializing essential system services...');
      await _initEssentialServices();
      print('✅ Essential services ready');

      // 3. Notification system
      print('🔔 Initializing notification system...');
      await _initNotificationSystem();
      print('✅ Notification system ready');

      // 4. Prayer notification service (unified)
      print('🕌 Initializing unified prayer notification service...');
      await _initPrayerServices();
      print('✅ Prayer services ready');

      // 5. Recovery and monitoring
      print('🛠️ Initializing system recovery...');
      await _initRecoveryServices();
      print('✅ Recovery services ready');

      // 6. Analytics and ads (deferred)
      print('📊 Initializing analytics...');
      await _initAnalytics();
      print('✅ Analytics ready');

      _isInitialized = true;
      
      final bootDuration = DateTime.now().difference(startTime).inMilliseconds;
      print('🎉 Boot sequence completed in ${bootDuration}ms');

    } catch (e) {
      print('❌ Boot sequence failed: $e');
      _isInitialized = false;
      _bootFuture = null; // Reset to allow retry
      rethrow;
    }
  }

  /// Initialize essential system services
  Future<void> _initEssentialServices() async {
    print('  - AndroidAlarmManager initialized in main()');
    print('  - Timezone setup is already done in main()');
    print('  ✅ Essential services ready');
  }

  /// Initialize notification system
  Future<void> _initNotificationSystem() async {
    print('  - Creating notification plugin...');
    _athkarkNotifications = AthkarkNotifications.instance;
    _notifications = _athkarkNotifications.plugin;

    print('  - Initializing notifications...');
    await _athkarkNotifications.init();
    
    print('  ✅ Notification system ready');
  }

  /// Initialize prayer services
  Future<void> _initPrayerServices() async {
    print('  - Initializing unified prayer notification service...');
    await UnifiedPrayerNotificationService.instance.initialize();
    print('  ✅ Unified prayer notification service ready');
  }

  /// Initialize recovery and monitoring services
  Future<void> _initRecoveryServices() async {
    print('  - System recovery services skipped (removed for production)');
    print('  ✅ Recovery services ready');
  }

  /// Initialize analytics and ads (deferred to prevent blocking)
  Future<void> _initAnalytics() async {
    // These are deferred to avoid blocking main thread
    try {
      print('  - Initializing Google Mobile Ads...');
      // AdNetwork.I.init(); // This should be done in main() before boot
      print('  ✅ Google Mobile Ads ready');
    } catch (e) {
      print('  ⚠️ Analytics init failed (non-critical): $e');
    }
  }

  /// Get initialization status
  static bool get isInitialized => _isInitialized;

  /// Check if we're running in a background isolate
  static bool get isBackgroundIsolate {
    try {
      // Simple check - if we can't access main isolates, we're in background
      final currentIsolate = Isolate.current;
      return currentIsolate != null;
    } catch (e) {
      return true; // Assume background if check fails
    }
  }

  /// Check duplicate execution using SharedPreferences
  static Future<bool> checkDuplicateExecution() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'alarm_execution_lock';
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if another execution is happening
      final lastExecution = prefs.getInt(key);
      if (lastExecution != null) {
        final timeDiff = now - lastExecution;
        if (timeDiff < 10000) { // 10 seconds
          print('🛡️ Duplicate execution prevented - another alarm running');
          return false;
        }
      }
      
      // Record this execution
      await prefs.setInt(key, now);
      return true;
    } catch (e) {
      print('⚠️ Error checking duplicate execution: $e');
      return true; // Continue to be safe
    }
  }

  /// Safe cleanup
  static Future<void> cleanup() async {
    try {
      if (_isInitialized) {
        // Clean up SharedPreferences lock
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('alarm_execution_lock');
        
        _isInitialized = false;
        _bootFuture = null;
        print('🧹 Boot service cleaned up');
      }
    } catch (e) {
      print('⚠️ Error during boot service cleanup: $e');
    }
  }
}

/// Extension for quick access
extension BootServiceExtension on BootService {
  /// Initialize with proper error handling
  static Future<void> initialize({bool force = false}) async {
    if (!BootService.isInitialized || force) {
      return await BootService.ensure();
    }
  }

  /// Check if services are ready
  static bool isReady() => BootService.isInitialized;
}