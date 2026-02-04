import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Simple and reliable prayer audio service
/// This replaces the complex AudioService with a straightforward approach
class SimplePrayerAudioService {
  static SimplePrayerAudioService? _instance;
  static SimplePrayerAudioService get instance => _instance ??= SimplePrayerAudioService();

  // Static variable to prevent multiple adhan playbacks within a short time
  static DateTime? _lastAdhanPlaybackTime;

  ja.AudioPlayer? _player;
  FlutterLocalNotificationsPlugin? _notifications;
  bool _isInitialized = false;
  bool _isManuallyStopped = false; // Track if playback was stopped manually
  Timer? _autoStopTimer;

  /// Initialize the service
  Future<void> initialize(FlutterLocalNotificationsPlugin notifications) async {
    if (_isInitialized) return;

    _notifications = notifications;
    _player = ja.AudioPlayer();
    _isInitialized = true;

    print('✅ Simple Prayer Audio Service initialized');
  }

  /// Play adhan audio - the most reliable method
  Future<bool> playAdhan(String prayerName) async {
    if (!_isInitialized || _player == null) {
      print('❌ Service not initialized');
      return false;
    }

    // Check if adhan was played recently (within last 30 seconds) to prevent double playback
    // But allow if it was manually stopped (to allow quick restart)
    final now = DateTime.now();
    if (_lastAdhanPlaybackTime != null && !_isManuallyStopped) {
      final timeSinceLastPlayback = now.difference(_lastAdhanPlaybackTime!);
      if (timeSinceLastPlayback.inSeconds < 30) {
        print('⏰ Adhan playback blocked - too soon after previous playback (${timeSinceLastPlayback.inSeconds}s ago)');
        return false;
      }
    }

    try {
      print('🔊 Playing adhan for: $prayerName');

      // Update last playback time and reset manual stop flag
      _lastAdhanPlaybackTime = now;
      _isManuallyStopped = false;

      // Stop any current playback and cancel any existing auto-stop timer
      await _player!.stop();
      _autoStopTimer?.cancel();

      // Set volume to maximum
      await _player!.setVolume(1.0);

      // Always use bundled audio file from assets
      print('📦 Using bundled audio file');
      ja.AudioSource audioSource = ja.AudioSource.asset('assets/adhan/adhan.mp3');

      await _player!.setAudioSource(audioSource);

      // Verify audio loaded
      final duration = _player!.duration;
      if (duration == null || duration.inMilliseconds == 0) {
        throw Exception('Audio file not loaded properly');
      }

      print('✅ Audio loaded, duration: ${duration.inMilliseconds}ms');

      // Start playback
      await _player!.play();

      // Wait a moment to verify playback started
      await Future.delayed(const Duration(milliseconds: 500));

      if (_player!.playing) {
        print('✅ Adhan is playing successfully!');

        // Setup auto-stop timer for safety (longer duration to avoid interruption)
        _autoStopTimer = Timer(const Duration(seconds: 45), () async {
          if (!_isManuallyStopped && _player?.playing == true) {
            try {
              await _player!.stop();
              print('🛑 Adhan playback auto-stopped after 45 seconds');
            } catch (e) {
              print('Error in auto-stop: $e');
            }
          }
        });

        return true;
      } else {
        print('❌ Playback did not start');
        return false;
      }

    } catch (e) {
      print('❌ Error playing adhan: $e');

      // Fallback: show notification only
      await _showNotificationOnly(prayerName);
      return false;
    }
  }

  /// Show notification when audio fails
  Future<void> _showNotificationOnly(String prayerName) async {
    try {
      await _notifications!.show(
        999999,
        'حان وقت صلاة $prayerName',
        'انقر لفتح التطبيق - لم يتم تشغيل الصوت',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'adhan_fallback',
            'أذان احتياطي',
            channelDescription: 'إشعارات الأذان عند فشل الصوت',
            importance: Importance.high,
            priority: Priority.high,
            playSound: false, // No sound since audio failed
            enableVibration: true,
          ),
        ),
      );
      print('📢 Fallback notification shown for: $prayerName');
    } catch (e) {
      print('❌ Even notification failed: $e');
    }
  }

  /// Test the audio system
  Future<bool> testAudio() async {
    return await playAdhan('تجريبي');
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      print('🛑 Stopping audio playback...');
      
      // Cancel auto-stop timer
      _autoStopTimer?.cancel();
      
      // Set manual stop flag
      _isManuallyStopped = true;
      
      // Stop the player
      await _player?.stop();
      
      // Clear the last playback time to allow immediate restart
      _lastAdhanPlaybackTime = null;
      
      print('✅ Audio playback stopped successfully');
    } catch (e) {
      print('❌ Error stopping audio: $e');
    }
  }

  /// Check if currently playing
  bool get isPlaying {
    return _player?.playing == true && !_isManuallyStopped;
  }

  /// Check if was manually stopped
  bool get wasManuallyStopped => _isManuallyStopped;

  /// Dispose resources
  void dispose() {
    _autoStopTimer?.cancel();
    _player?.dispose();
    _player = null;
    _isInitialized = false;
    _isManuallyStopped = false;
    print('🗑️ Simple Prayer Audio Service disposed');
  }
}

/// Simplified Audio Handler for background playback
class SimpleAdhanAudioHandler extends BaseAudioHandler {
  final ja.AudioPlayer _player = ja.AudioPlayer();
  String _currentPrayer = 'الأذان';

  SimpleAdhanAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  @override
  Future<void> play() async {
    try {
      // Always use bundled audio file from assets
      ja.AudioSource audioSource = ja.AudioSource.asset('assets/adhan/adhan.mp3');

      await _player.setAudioSource(audioSource);
      await _player.setVolume(1.0);
      await _player.play();

      // Update media item
      mediaItem.add(MediaItem(
        id: 'adhan',
        title: _currentPrayer,
        artist: 'Athkark',
      ));

      playbackState.add(playbackState.value.copyWith(
        playing: true,
        controls: [MediaControl.stop],
      ));

    } catch (e) {
      print('Error in SimpleAdhanAudioHandler.play(): $e');
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [],
    ));
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'configure' && extras != null) {
      _currentPrayer = extras['prayer'] ?? 'الأذان';
      mediaItem.add(MediaItem(
        id: 'adhan',
        title: _currentPrayer,
        artist: 'Athkark',
      ));
    }
    return null;
  }

  PlaybackState _transformEvent(ja.PlaybackEvent event) {
    return PlaybackState(
      controls: [MediaControl.stop],
      processingState: const {
        ja.ProcessingState.idle: AudioProcessingState.idle,
        ja.ProcessingState.loading: AudioProcessingState.loading,
        ja.ProcessingState.buffering: AudioProcessingState.loading,
        ja.ProcessingState.ready: AudioProcessingState.ready,
        ja.ProcessingState.completed: AudioProcessingState.completed,
      }[event.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
      speed: _player.speed,
    );
  }
}