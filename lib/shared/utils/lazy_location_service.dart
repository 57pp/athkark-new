import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Lazy Location Service - موقع عند الطلب فقط
class LazyLocationService {
  static Position? _lastPosition;
  static bool _isServiceEnabled = false;
  static LocationPermission? _permission;

  /// Check if location service is enabled
  static Future<bool> isServiceEnabled() async {
    if (_isServiceEnabled) return true;
    
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      _isServiceEnabled = enabled;
      return enabled;
    } catch (e) {
      print('⚠️ Location service check failed: $e');
      return false;
    }
  }

  /// Get location permission status
  static Future<LocationPermission> checkPermission() async {
    if (_permission != null) return _permission!;
    
    try {
      final permission = await Geolocator.checkPermission();
      _permission = permission;
      return permission;
    } catch (e) {
      print('⚠️ Location permission check failed: $e');
      return LocationPermission.denied;
    }
  }

  /// Get current position with timeout - called only when needed
  static Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 5),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      // Check service availability
      final serviceEnabled = await isServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location service is disabled');
      }

      // Check permission
      final permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        _permission = requestedPermission;
        if (requestedPermission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied forever');
      }

      // Get position with timeout
      final position = await Geolocator.getCurrentPosition(
        timeLimit: timeout,
        desiredAccuracy: accuracy,
      );

      _lastPosition = position;
      print('✅ Location obtained: ${position.latitude}, ${position.longitude}');
      return position;

    } catch (e) {
      print('❌ Location retrieval failed: $e');
      // Return last known position if available, otherwise rethrow
      if (_lastPosition != null) {
        print('📍 Using last known position as fallback');
        return _lastPosition!;
      }
      rethrow;
    }
  }

  /// Get last known position (if available)
  static Position? getLastKnownPosition() {
    return _lastPosition;
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print('⚠️ Failed to open location settings: $e');
      return false;
    }
  }

  /// Open app settings
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      print('⚠️ Failed to open app settings: $e');
      return false;
    }
  }

  /// Calculate distance between two positions
  static double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Clear cached position
  static void clearCache() {
    _lastPosition = null;
    _permission = null;
    _isServiceEnabled = false;
    print('🧹 Location service cache cleared');
  }
}

/// Extension for convenience
extension LazyLocationServiceExtension on LazyLocationService {
  /// Get current position with default settings
  static Future<Position> getOnce() async {
    return await LazyLocationService.getCurrentPosition();
  }

  /// Get high accuracy position for prayer times
  static Future<Position> getHighAccuracyPosition() async {
    return await LazyLocationService.getCurrentPosition(
      accuracy: LocationAccuracy.high,
      timeout: Duration(seconds: 10),
    );
  }
}