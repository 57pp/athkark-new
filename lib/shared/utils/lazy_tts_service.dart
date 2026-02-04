import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

/// Lazy TTS Service - تهيئة كسولة لتجنب تأخير الإقلاع
class LazyTtsService {
  static FlutterTts? _tts;
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// Initialize TTS lazily - called only when needed
  static Future<void> _initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      // Wait for ongoing initialization
      while (_isInitializing) {
        await Future.delayed(Duration(milliseconds: 50));
        if (_isInitialized) return;
      }
      return;
    }

    _isInitializing = true;
    try {
      _tts = FlutterTts();
      
      // Minimal initialization
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      
      _isInitialized = true;
      print('✅ LazyTTSService initialized');
    } catch (e) {
      print('⚠️ LazyTTSService initialization failed: $e');
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Speak text - initialize if needed, then speak
  static Future<void> speak(String text) async {
    await _initialize();
    
    if (_tts != null && _isInitialized) {
      try {
        await _tts!.speak(text);
      } catch (e) {
        print('⚠️ TTS speak failed: $e');
      }
    }
  }

  /// Stop speaking
  static Future<void> stop() async {
    if (_tts != null && _isInitialized) {
      try {
        await _tts!.stop();
      } catch (e) {
        print('⚠️ TTS stop failed: $e');
      }
    }
  }

  /// Check if TTS is ready
  static bool get isReady => _isInitialized;

  /// Cleanup resources
  static Future<void> dispose() async {
    if (_tts != null) {
      await _tts!.stop();
    }
    _tts = null;
    _isInitialized = false;
    _isInitializing = false;
  }
}