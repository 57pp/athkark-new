import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced Prayer Audio Service
/// Provides reliable, optimized audio playback with advanced features
/// Integrated with the unified notification system
class EnhancedPrayerAudioService {
  static EnhancedPrayerAudioService? _instance;
  static EnhancedPrayerAudioService get instance => 
      _instance ??= EnhancedPrayerAudioService();

  ja.AudioPlayer? _player;
  FlutterLocalNotificationsPlugin? _notifications;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Audio configuration
  static const List<String> _audioFiles = [
    'assets/adhan/adhan.mp3',
    'assets/adhan/adhan_soft.mp3',
    'assets/adhan/adhan_saudia.mp3',
    'assets/adhan/adhan_mecca.mp3',
  ];

  // Playback state
  AudioPlaybackState _playbackState = AudioPlaybackState.stopped;
  String _currentAudioFile = _audioFiles.first;
  Timer? _autoStopTimer;
  StreamSubscription<ja.PlayerState>? _playerStateSubscription;

  // Performance metrics
  int _totalPlaybacks = 0;
  int _successfulPlaybacks = 0;
  int _failedPlaybacks = 0;
  List<double> _playbackDurations = [];

  // Getters
  bool get isInitialized => _isInitialized;
  AudioPlaybackState get playbackState => _playbackState;
  String get currentAudioFile => _currentAudioFile;
  int get totalPlaybacks => _totalPlaybacks;
  int get successfulPlaybacks => _successfulPlaybacks;
  int get failedPlaybacks => _failedPlaybacks;
  double get successRate => _totalPlaybacks > 0 ? 
      (_successfulPlaybacks / _totalPlaybacks) * 100 : 0.0;

  /// Initialize the enhanced service
  Future<void> initialize(
    FlutterLocalNotificationsPlugin notifications,
    SharedPreferences prefs
  ) async {
    if (_isInitialized) return;

    try {
      print('🎵 Initializing Enhanced Prayer Audio Service...');

      _notifications = notifications;
      _prefs = prefs;

      // Initialize audio player
      _player = ja.AudioPlayer();
      
      // Setup player state monitoring
      _setupPlayerStateMonitoring();
      
      // Load user preferences
      await _loadPreferences();

      _isInitialized = true;
      _playbackState = AudioPlaybackState.ready;
      
      print('✅ Enhanced Prayer Audio Service initialized successfully');

    } catch (e) {
      _playbackState = AudioPlaybackState.error;
      print('❌ Failed to initialize Enhanced Prayer Audio Service: $e');
      rethrow;
    }
  }

  /// Setup player state monitoring
  void _setupPlayerStateMonitoring() {
    _playerStateSubscription = _player!.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) {
        _onPlaybackCompleted();
      } else if (state.processingState == ja.ProcessingState.idle) {
        _onPlaybackError(state);
      }
    });
  }

  /// Load user preferences
  Future<void> _loadPreferences() async {
    _currentAudioFile = _prefs?.getString('preferred_adhan_file') ?? _audioFiles.first;
    
    // Load playback statistics
    _totalPlaybacks = _prefs?.getInt('total_adhan_playbacks') ?? 0;
    _successfulPlaybacks = _prefs?.getInt('successful_adhan_playbacks') ?? 0;
    _failedPlaybacks = _prefs?.getInt('failed_adhan_playbacks') ?? 0;
    
    print('📊 Loaded preferences - Audio: $_currentAudioFile, Success Rate: ${successRate.toStringAsFixed(1)}%');
  }

  /// Save user preferences
  Future<void> _savePreferences() async {
    await _prefs?.setString('preferred_adhan_file', _currentAudioFile);
    await _prefs?.setInt('total_adhan_playbacks', _totalPlaybacks);
    await _prefs?.setInt('successful_adhan_playbacks', _successfulPlaybacks);
    await _prefs?.setInt('failed_adhan_playbacks', _failedPlaybacks);
  }

  /// Play adhan with enhanced reliability
  Future<bool> playAdhan(
    String prayerName, {
    String? customAudioFile,
    int timeoutSeconds = 45,
    bool showNotification = true,
  }) async {
    if (!_isInitialized || _player == null) {
      print('❌ Service not initialized');
      return false;
    }

    _totalPlaybacks++;
    
    try {
      print('🔊 Enhanced adhan playback for: $prayerName');
      _playbackState = AudioPlaybackState.preparing;

      // Stop any current playback
      await _stopCurrentPlayback();

      // Determine audio file to use
      final audioFile = customAudioFile ?? _currentAudioFile;
      
      // Preload and verify audio file
      if (!await _verifyAudioFile(audioFile)) {
        throw Exception('Audio file not accessible: $audioFile');
      }

      // Setup audio source with error handling
      ja.AudioSource audioSource = ja.AudioSource.asset(audioFile);
      await _player!.setAudioSource(audioSource);

      // Set optimal playback parameters
      await _player!.setVolume(1.0);
      await _player!.setSpeed(1.0);

      // Verify audio loaded properly
      final duration = _player!.duration;
      if (duration == null || duration.inMilliseconds < 1000) {
        throw Exception('Invalid audio duration: ${duration?.inMilliseconds}ms');
      }

      print('✅ Audio loaded - Duration: ${duration.inMilliseconds}ms, File: $audioFile');

      // Start playback with timeout
      _playbackState = AudioPlaybackState.playing;
      
      final playbackStartTime = DateTime.now();
      await _player!.play();

      // Monitor playback progress
      final playbackTimeout = Timer(Duration(seconds: timeoutSeconds), () async {
        print('⚠️ Playback timeout, stopping...');
        await _stopCurrentPlayback();
      });

      // Wait for playback to complete or timeout
      await _waitForPlaybackCompletion();

      playbackTimeout.cancel();
      final playbackDuration = DateTime.now().difference(playbackStartTime);
      _recordPlaybackMetrics(true, playbackDuration);

      _playbackState = AudioPlaybackState.completed;
      _successfulPlaybacks++;

      print('✅ Enhanced adhan playback completed successfully for: $prayerName');

      // Auto-stop timer for safety
      _setupAutoStop();

      if (showNotification) {
        await _showPlaybackNotification(prayerName, audioFile);
      }

      await _savePreferences();
      return true;

    } catch (e) {
      _playbackState = AudioPlaybackState.error;
      _failedPlaybacks++;
      
      final playbackDuration = Duration.zero;
      _recordPlaybackMetrics(false, playbackDuration);
      
      print('❌ Enhanced adhan playback failed for $prayerName: $e');

      // Enhanced fallback
      await _enhancedFallback(prayerName, e.toString());
      
      await _savePreferences();
      return false;
    }
  }

  /// Verify audio file accessibility
  Future<bool> _verifyAudioFile(String audioFile) async {
    try {
      // Try to set the audio source to verify it's accessible
      final testSource = ja.AudioSource.asset(audioFile);
      await _player!.setAudioSource(testSource);
      
      // Check if duration can be obtained
      final duration = _player!.duration;
      return duration != null && duration.inMilliseconds > 0;
    } catch (e) {
      print('⚠️ Audio file verification failed: $e');
      return false;
    }
  }

  /// Stop current playback
  Future<void> _stopCurrentPlayback() async {
    try {
      await _player?.stop();
      _autoStopTimer?.cancel();
      _playbackState = AudioPlaybackState.stopped;
    } catch (e) {
      print('⚠️ Error stopping playback: $e');
    }
  }

  /// Wait for playback completion
  Future<void> _waitForPlaybackCompletion() async {
    return await _player!.playerStateStream.firstWhere((state) {
      return state.processingState == ja.ProcessingState.completed ||
             state.processingState == ja.ProcessingState.idle ||
             state.processingState == ja.ProcessingState.idle;
    }).then((_) => Future.value());
  }

  /// Record playback metrics
  void _recordPlaybackMetrics(bool success, Duration duration) {
    _playbackDurations.add(duration.inMilliseconds.toDouble());
    
    // Keep only last 50 recordings
    if (_playbackDurations.length > 50) {
      _playbackDurations.removeAt(0);
    }
  }

  /// Setup auto-stop timer
  void _setupAutoStop() {
    _autoStopTimer = Timer(const Duration(seconds: 30), () async {
      try {
        await _stopCurrentPlayback();
        print('🛑 Auto-stop triggered after 30 seconds');
      } catch (e) {
        print('⚠️ Error in auto-stop: $e');
      }
    });
  }

  /// Show playback notification
  Future<void> _showPlaybackNotification(String prayerName, String audioFile) async {
    try {
      final fileName = audioFile.split('/').last.replaceAll('.mp3', '').replaceAll('_', ' ');
      
      await _notifications!.show(
        888888,
        'تشغيل الأذان: $prayerName',
        'جاري تشغيل $fileName',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'adhan_playback',
            'تشغيل الأذان',
            channelDescription: 'إشعارات تشغيل الأذان',
            importance: Importance.low,
            playSound: false,
            ongoing: true,
          ),
        ),
      );

      // Auto-cancel after 5 seconds
      Timer(const Duration(seconds: 5), () {
        _notifications?.cancel(888888);
      });

    } catch (e) {
      print('⚠️ Error showing playback notification: $e');
    }
  }

  /// Enhanced fallback when playback fails
  Future<void> _enhancedFallback(String prayerName, String error) async {
    try {
      // Try alternative audio file
      final alternativeFiles = _audioFiles.where((file) => file != _currentAudioFile).toList();
      
      for (final altFile in alternativeFiles) {
        if (await _verifyAudioFile(altFile)) {
          print('🔄 Trying alternative audio file: $altFile');
          
          try {
            _currentAudioFile = altFile;
            await _prefs?.setString('preferred_adhan_file', altFile);
            
            final success = await playAdhan(
              prayerName,
              customAudioFile: altFile,
              showNotification: false,
              timeoutSeconds: 30,
            );
            
            if (success) {
              print('✅ Alternative audio file worked: $altFile');
              return;
            }
          } catch (e) {
            print('⚠️ Alternative audio file failed: $e');
          }
        }
      }

      // Last resort: show high-priority notification
      await _notifications?.show(
        999999,
        'حان وقت صلاة $prayerName',
        'فشل تشغيل الأذان - انقر لفتح التطبيق',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'adhan_fallback_enhanced',
            'أذان احتياطي محسن',
            channelDescription: 'تنبيهات الأذان عند فشل الصوت المحسن',
            importance: Importance.max,
            priority: Priority.max,
            playSound: false,
            enableVibration: true,
            enableLights: true,
          ),
        ),
      );

    } catch (e) {
      print('❌ Even enhanced fallback failed: $e');
    }
  }

  /// Handle playback completion
  void _onPlaybackCompleted() {
    _playbackState = AudioPlaybackState.completed;
    _autoStopTimer?.cancel();
    print('🎵 Playback completed');
  }

  /// Handle playback error
  void _onPlaybackError(ja.PlayerState state) {
    _playbackState = AudioPlaybackState.error;
    _failedPlaybacks++;
    _autoStopTimer?.cancel();
    print('❌ Playback error: ${state.processingState}');
  }

  /// Set preferred audio file
  Future<bool> setPreferredAudioFile(String audioFile) async {
    if (!_audioFiles.contains(audioFile)) {
      print('❌ Invalid audio file: $audioFile');
      return false;
    }

    try {
      // Test the audio file
      if (!await _verifyAudioFile(audioFile)) {
        print('❌ Audio file not accessible: $audioFile');
        return false;
      }

      _currentAudioFile = audioFile;
      await _prefs?.setString('preferred_adhan_file', audioFile);
      
      print('✅ Set preferred audio file: $audioFile');
      return true;
    } catch (e) {
      print('❌ Error setting preferred audio file: $e');
      return false;
    }
  }

  /// Get available audio files
  List<String> getAvailableAudioFiles() {
    return List.unmodifiable(_audioFiles);
  }

  /// Test audio system
  Future<bool> testAudioSystem() async {
    print('🧪 Testing enhanced audio system...');
    
    final startTime = DateTime.now();
    final success = await playAdhan(
      'تجريبي',
      timeoutSeconds: 15,
      showNotification: true,
    );
    final duration = DateTime.now().difference(startTime);
    
    print('📊 Audio test completed in ${duration.inMilliseconds}ms - Success: $success');
    return success;
  }

  /// Get performance statistics
  AudioPerformanceStatistics getStatistics() {
    final avgDuration = _playbackDurations.isNotEmpty
        ? _playbackDurations.reduce((a, b) => a + b) / _playbackDurations.length
        : 0.0;

    return AudioPerformanceStatistics(
      totalPlaybacks: _totalPlaybacks,
      successfulPlaybacks: _successfulPlaybacks,
      failedPlaybacks: _failedPlaybacks,
      successRate: successRate,
      averageDurationMs: avgDuration,
      currentAudioFile: _currentAudioFile,
      playbackState: _playbackState,
      isInitialized: _isInitialized,
    );
  }

  /// Reset statistics
  Future<void> resetStatistics() async {
    _totalPlaybacks = 0;
    _successfulPlaybacks = 0;
    _failedPlaybacks = 0;
    _playbackDurations.clear();
    
    await _savePreferences();
    
    print('📊 Audio statistics reset');
  }

  /// Stop current playback
  Future<void> stop() async {
    await _stopCurrentPlayback();
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _player?.pause();
      _playbackState = AudioPlaybackState.paused;
    } catch (e) {
      print('⚠️ Error pausing playback: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _player?.play();
      _playbackState = AudioPlaybackState.playing;
    } catch (e) {
      print('⚠️ Error resuming playback: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _autoStopTimer?.cancel();
    _playerStateSubscription?.cancel();
    _player?.dispose();
    _player = null;
    _notifications = null;
    _prefs = null;
    _isInitialized = false;
    _playbackState = AudioPlaybackState.disposed;
    
    print('🗑️ Enhanced Prayer Audio Service disposed');
  }
}

/// Audio playback state enum
enum AudioPlaybackState {
  uninitialized,
  ready,
  preparing,
  playing,
  paused,
  completed,
  stopped,
  error,
  disposed,
}

/// Audio performance statistics
class AudioPerformanceStatistics {
  final int totalPlaybacks;
  final int successfulPlaybacks;
  final int failedPlaybacks;
  final double successRate;
  final double averageDurationMs;
  final String currentAudioFile;
  final AudioPlaybackState playbackState;
  final bool isInitialized;

  const AudioPerformanceStatistics({
    required this.totalPlaybacks,
    required this.successfulPlaybacks,
    required this.failedPlaybacks,
    required this.successRate,
    required this.averageDurationMs,
    required this.currentAudioFile,
    required this.playbackState,
    required this.isInitialized,
  });

  bool get isHealthy => isInitialized && 
      playbackState != AudioPlaybackState.error && 
      successRate > 80.0;

  String get healthStatus => isHealthy ? 'Excellent' : 
      (playbackState == AudioPlaybackState.error ? 'Error' : 'Degraded');
}

/// Enhanced Adhan Audio Handler for background playback
class EnhancedAdhanAudioHandler extends BaseAudioHandler {
  final ja.AudioPlayer _player = ja.AudioPlayer();
  String _currentPrayer = 'الأذان';
  String _currentAudioFile = 'assets/adhan/adhan.mp3';

  EnhancedAdhanAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  @override
  Future<void> play() async {
    try {
      ja.AudioSource audioSource = ja.AudioSource.asset(_currentAudioFile);
      await _player.setAudioSource(audioSource);
      await _player.setVolume(1.0);
      await _player.setSpeed(1.0);
      await _player.play();

      // Update media item
      mediaItem.add(MediaItem(
        id: 'adhan_enhanced',
        title: _currentPrayer,
        artist: 'Athkark Enhanced',
        duration: const Duration(seconds: 30),
      ));

      playbackState.add(playbackState.value.copyWith(
        playing: true,
        controls: [MediaControl.stop],
        processingState: AudioProcessingState.ready,
      ));

    } catch (e) {
      print('Error in EnhancedAdhanAudioHandler.play(): $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [],
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'configure' && extras != null) {
      _currentPrayer = extras['prayer'] ?? 'الأذان';
      _currentAudioFile = extras['audio_file'] ?? 'assets/adhan/adhan.mp3';
      
      mediaItem.add(MediaItem(
        id: 'adhan_enhanced',
        title: _currentPrayer,
        artist: 'Athkark Enhanced',
        duration: const Duration(seconds: 30),
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
      speed: 1.0,
    );
  }
}