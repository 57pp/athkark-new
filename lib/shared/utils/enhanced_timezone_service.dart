import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced timezone service with daylight saving time detection and qibla direction
class EnhancedTimezoneService {
  static const String _currentTimezoneKey = 'enhanced_timezone_current';
  static const String _lastDSTCheckKey = 'enhanced_timezone_dst_check';
  static const String _qiblaDirectionKey = 'enhanced_qibla_direction';
  static const String _lastQiblaUpdateKey = 'enhanced_qibla_last_update';

  static final EnhancedTimezoneService _instance = EnhancedTimezoneService._();
  static EnhancedTimezoneService get instance => _instance;

  EnhancedTimezoneService._();

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  
  // Current timezone information
  String? _currentTimezone;
  bool _isDaylightSavingTime = false;
  Duration _timezoneOffset = Duration.zero;
  DateTime? _lastDSTCheck;
  DateTime? _dstTransitionDate;
  String _transitionType = 'none'; // 'spring_forward', 'fall_back', 'none'

  // Qibla direction information
  double? _qiblaDirection;
  DateTime? _lastQiblaUpdate;

  /// Initialize the enhanced timezone service
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🌍 Initializing Enhanced Timezone Service...');
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // Load saved timezone information
    await _loadTimezoneInformation();
    
    // Detect current timezone and DST status
    await _detectTimezoneAndDST();
    
    // Load or calculate qibla direction
    await _loadOrCalculateQiblaDirection();

    _isInitialized = true;
    print('✅ Enhanced Timezone Service initialized');
  }

  /// Load saved timezone information from preferences
  Future<void> _loadTimezoneInformation() async {
    _currentTimezone = _prefs.getString(_currentTimezoneKey);
    _lastDSTCheck = DateTime.tryParse(_prefs.getString(_lastDSTCheckKey) ?? '');
    
    print('📁 Loaded timezone info: $_currentTimezone, last DST check: $_lastDSTCheck');
  }

  /// Detect current timezone and check for daylight saving time
  Future<void> _detectTimezoneAndDST() async {
    try {
      final now = DateTime.now();
      final currentTimezone = tz.local.name;
      
      print('🔍 Detecting timezone: $currentTimezone');
      
      // Check if timezone has changed
      if (_currentTimezone != currentTimezone) {
        print('🔄 Timezone changed from $_currentTimezone to $currentTimezone');
        _currentTimezone = currentTimezone;
        await _prefs.setString(_currentTimezoneKey, currentTimezone);
      }

      // Determine current offset
      _timezoneOffset = now.timeZoneOffset;
      
      // Check for daylight saving time
      await _checkDaylightSavingTime(now);
      
      _lastDSTCheck = now;
      await _prefs.setString(_lastDSTCheckKey, now.toIso8601String());
      
      print('⏰ Timezone detection complete:');
      print('  - Timezone: $_currentTimezone');
      print('  - Offset: $_timezoneOffset');
      print('  - DST Active: $_isDaylightSavingTime');
      print('  - Transition: $_transitionType');
      
    } catch (e) {
      print('❌ Error detecting timezone and DST: $e');
    }
  }

  /// Check for daylight saving time status
  Future<void> _checkDaylightSavingTime(DateTime now) async {
    try {
      // Calculate timezone offset for January (winter) and July (summer) of current year
      final winter = DateTime(now.year, 1, 15);
      final summer = DateTime(now.year, 7, 15);
      
      final winterOffset = winter.timeZoneOffset;
      final summerOffset = summer.timeZoneOffset;
      final currentOffset = now.timeZoneOffset;
      
      print('🕐 Checking DST:');
      print('  - Winter offset: $winterOffset');
      print('  - Summer offset: $summerOffset');
      print('  - Current offset: $currentOffset');
      
      // Determine DST status
      if (summerOffset != winterOffset) {
        // This timezone observes DST
        if (currentOffset == summerOffset) {
          _isDaylightSavingTime = true;
          _transitionType = 'summer_active';
          print('  - DST is currently ACTIVE');
        } else if (currentOffset == winterOffset) {
          _isDaylightSavingTime = false;
          _transitionType = 'winter_active';
          print('  - DST is currently INACTIVE');
        } else {
          // Transition period
          _isDaylightSavingTime = (currentOffset == summerOffset);
          _transitionType = 'transition';
          print('  - DST is in TRANSITION');
        }
        
        // Estimate transition dates (simplified)
        await _estimateDSTTransitions(now);
        
      } else {
        // This timezone does not observe DST
        _isDaylightSavingTime = false;
        _transitionType = 'none';
        _dstTransitionDate = null;
        print('  - DST is NOT OBSERVED in this timezone');
      }
      
    } catch (e) {
      print('❌ Error checking DST: $e');
      _isDaylightSavingTime = false;
      _transitionType = 'none';
    }
  }

  /// Estimate DST transition dates
  Future<void> _estimateDSTTransitions(DateTime now) async {
    try {
      // Simplified DST transition estimation based on common patterns
      // Note: This is a basic implementation - real-world DST rules are more complex
      
      final int currentYear = now.year;
      
      // Common DST transition patterns (simplified)
      // Spring forward: Second Sunday in March (US) or last Sunday in March (EU)
      // Fall back: First Sunday in November (US) or last Sunday in October (EU)
      
      final springTransition = _getSecondSundayInMarch(currentYear);
      final fallTransition = _getFirstSundayInNovember(currentYear);
      
      // Determine if we're in transition period
      final currentDate = DateTime(now.year, now.month, now.day);
      
      if (currentDate.isAfter(springTransition) && currentDate.isBefore(fallTransition)) {
        _dstTransitionDate = springTransition;
        _transitionType = 'spring_forward';
      } else if (currentDate.isAfter(fallTransition) || currentDate.isBefore(springTransition)) {
        _dstTransitionDate = fallTransition;
        _transitionType = 'fall_back';
      } else {
        _dstTransitionDate = springTransition; // Default to next transition
        _transitionType = 'transition';
      }
      
      print('📅 Estimated DST transitions:');
      print('  - Spring transition: ${springTransition.toIso8601String().split('T')[0]}');
      print('  - Fall transition: ${fallTransition.toIso8601String().split('T')[0]}');
      print('  - Next transition: ${_dstTransitionDate?.toIso8601String().split('T')[0]}');
      
    } catch (e) {
      print('❌ Error estimating DST transitions: $e');
    }
  }

  /// Get the second Sunday in March for DST spring transition
  DateTime _getSecondSundayInMarch(int year) {
    // Find the first day of March
    final march1 = DateTime(year, 3, 1);
    // Find the first Sunday of March
    final firstSunday = march1.add(Duration(days: (7 - march1.weekday + DateTime.sunday) % 7));
    // Add one week to get the second Sunday
    return firstSunday.add(const Duration(days: 7));
  }

  /// Get the first Sunday in November for DST fall transition
  DateTime _getFirstSundayInNovember(int year) {
    // Find the first day of November
    final nov1 = DateTime(year, 11, 1);
    // Find the first Sunday of November
    return nov1.add(Duration(days: (7 - nov1.weekday + DateTime.sunday) % 7));
  }

  /// Load or calculate qibla direction
  Future<void> _loadOrCalculateQiblaDirection() async {
    try {
      _qiblaDirection = _prefs.getDouble(_qiblaDirectionKey);
      _lastQiblaUpdate = DateTime.tryParse(_prefs.getString(_lastQiblaUpdateKey) ?? '');

      print('🧭 Loading qibla direction: $_qiblaDirection, last update: $_lastQiblaUpdate');
      
      // If we don't have qibla direction or it's more than 1 day old, recalculate
      final now = DateTime.now();
      if (_qiblaDirection == null || 
          _lastQiblaUpdate == null || 
          now.difference(_lastQiblaUpdate!).inDays > 1) {
        
        print('🔄 Recalculating qibla direction...');
        await _calculateQiblaDirection();
      } else {
        print('✅ Using cached qibla direction: $_qiblaDirection°');
      }
      
    } catch (e) {
      print('❌ Error loading qibla direction: $e');
      await _calculateQiblaDirection();
    }
  }

  /// Calculate qibla direction based on user's location
  Future<void> _calculateQiblaDirection() async {
    try {
      // Kaaba coordinates (21.422N, 39.826E)
      const double kaabaLat = 21.422487;
      const double kaabaLon = 39.826206;
      
      // Get user's coordinates from prayer prefs
      final userLat = _prefs.getDouble('user_latitude');
      final userLng = _prefs.getDouble('user_longitude');
      
      if (userLat == null || userLng == null) {
        print('⚠️ No user coordinates found for qibla calculation');
        return;
      }
      
      print('🧭 Calculating qibla direction for user coordinates: $userLat, $userLng');
      
      // Convert coordinates to radians
      final lat1 = _degreesToRadians(userLat);
      final lat2 = _degreesToRadians(kaabaLat);
      final deltaLng = _degreesToRadians(kaabaLon - userLng);
      
      // Calculate bearing using spherical trigonometry
      final y = math.sin(deltaLng) * math.cos(lat2);
      final x = (math.cos(lat1) * math.sin(lat2)) - 
                (math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng));
      
      final bearing = math.atan2(y, x);
      final bearingDegrees = (bearing * 180 / math.pi + 360) % 360;
      
      _qiblaDirection = bearingDegrees;
      _lastQiblaUpdate = DateTime.now();
      
      // Save to preferences
      await _prefs.setDouble(_qiblaDirectionKey, _qiblaDirection!);
      await _prefs.setString(_lastQiblaUpdateKey, _lastQiblaUpdate!.toIso8601String());
      
      print('✅ Qibla direction calculated: ${_qiblaDirection!.toStringAsFixed(1)}° from North');
      
    } catch (e) {
      print('❌ Error calculating qibla direction: $e');
    }
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Update user location and recalculate qibla
  Future<void> updateUserLocation(double latitude, double longitude) async {
    try {
      print('📍 Updating user location: $latitude, $longitude');
      
      // Save to prayer preferences
      await _prefs.setDouble('user_latitude', latitude);
      await _prefs.setDouble('user_longitude', longitude);
      
      // Recalculate qibla direction
      await _calculateQiblaDirection();
      
      print('✅ User location updated and qibla recalculated');
      
    } catch (e) {
      print('❌ Error updating user location: $e');
    }
  }

  /// Force timezone and DST re-detection
  Future<void> refreshTimezoneAndDST() async {
    print('🔄 Refreshing timezone and DST detection...');
    await _detectTimezoneAndDST();
  }

  /// Get current timezone information
  Map<String, dynamic> getTimezoneInformation() {
    return {
      'timezone': _currentTimezone,
      'isDaylightSavingTime': _isDaylightSavingTime,
      'timezoneOffset': _timezoneOffset.inHours,
      'timezoneOffsetMinutes': _timezoneOffset.inMinutes,
      'transitionType': _transitionType,
      'transitionDate': _dstTransitionDate?.toIso8601String(),
      'lastDSTCheck': _lastDSTCheck?.toIso8601String(),
      'currentTime': DateTime.now().toIso8601String(),
    };
  }

  /// Get qibla direction information
  Map<String, dynamic> getQiblaInformation() {
    return {
      'direction': _qiblaDirection,
      'directionFormatted': _qiblaDirection != null 
          ? '${_qiblaDirection!.toStringAsFixed(1)}°' 
          : null,
      'lastUpdated': _lastQiblaUpdate?.toIso8601String(),
      'isValid': _qiblaDirection != null && _qiblaDirection! >= 0 && _qiblaDirection! <= 360,
    };
  }

  /// Get qibla direction as a compass bearing
  String getQiblaDirectionString() {
    if (_qiblaDirection == null) return 'غير محدد';
    
    const List<String> directions = [
      'شمال', 'شمال شرق', 'شرق', 'جنوب شرق',
      'جنوب', 'جنوب غرب', 'غرب', 'شمال غرب'
    ];
    
    final bearing = _qiblaDirection!;
    final index = ((bearing + 22.5) / 45).floor() % 8;
    
    return directions[index];
  }

  /// Check if timezone has daylight saving time
  bool hasDaylightSavingTime() {
    return _transitionType != 'none';
  }

  /// Get time until next DST transition
  Duration? getTimeUntilNextDSTTransition() {
    if (_dstTransitionDate == null) return null;
    return _dstTransitionDate!.difference(DateTime.now());
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get current timezone
  String? get currentTimezone => _currentTimezone;

  /// Get current DST status
  bool get isDaylightSavingTime => _isDaylightSavingTime;

  /// Get current timezone offset
  Duration get timezoneOffset => _timezoneOffset;

  /// Get qibla direction
  double? get qiblaDirection => _qiblaDirection;

  /// Get formatted qibla direction
  String get qiblaDirectionFormatted {
    if (_qiblaDirection == null) return 'غير محدد';
    return '${_qiblaDirection!.toStringAsFixed(1)}° ${getQiblaDirectionString()}';
  }

  /// Get DST transition type
  String get transitionType => _transitionType;

  /// Get DST transition date
  DateTime? get dstTransitionDate => _dstTransitionDate;
}