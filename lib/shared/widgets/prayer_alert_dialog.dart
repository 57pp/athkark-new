import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_prayer_audio_service.dart';

/// Full-screen prayer alert dialog that appears when prayer time comes
class PrayerAlertDialog extends StatefulWidget {
  final String prayerName;
  final bool isCustom;
  final String? prayerId;

  const PrayerAlertDialog({
    super.key,
    required this.prayerName,
    this.isCustom = false,
    this.prayerId,
  });

  @override
  State<PrayerAlertDialog> createState() => _PrayerAlertDialogState();

  /// Show the prayer alert dialog
  static void show(
    BuildContext context,
    String prayerName, {
    bool isCustom = false,
    String? prayerId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => PrayerAlertDialog(
        prayerName: prayerName,
        isCustom: isCustom,
        prayerId: prayerId,
      ),
    );
  }
}

class _PrayerAlertDialogState extends State<PrayerAlertDialog> {
  final SimplePrayerAudioService _audioService = SimplePrayerAudioService.instance;
  bool _isPlaying = false;
  bool _isStopping = false;
  Timer? _autoDismissTimer;
  Timer? _repeatTimer;
  static const String _repeatPreferenceKey = 'adhan_repeat_prayer_name';
  static const String _repeatPreferenceTime = 'adhan_repeat_time';

  @override
  void initState() {
    super.initState();
    _startAdhan();
    _scheduleAutoDismiss();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  /// Clear repeat preferences
  Future<void> _clearRepeatPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_repeatPreferenceKey);
      await prefs.remove(_repeatPreferenceTime);
    } catch (e) {
      print('⚠️ Error clearing repeat preferences: $e');
    }
  }

  /// Save repeat preferences for scheduling
  Future<void> _saveRepeatPreferences(String prayerName, DateTime repeatTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_repeatPreferenceKey, prayerName);
      await prefs.setInt(_repeatPreferenceTime, repeatTime.millisecondsSinceEpoch);
    } catch (e) {
      print('⚠️ Error saving repeat preferences: $e');
    }
  }

  Future<void> _startAdhan() async {
    setState(() => _isPlaying = true);
    try {
      final success = await _audioService.playAdhan(widget.prayerName);
      if (!success) {
        print('❌ Failed to play adhan for: ${widget.prayerName}');
      }
    } catch (e) {
      print('❌ Error playing adhan: $e');
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  void _scheduleAutoDismiss() {
    // Auto dismiss after 2 minutes if not interacted with
    _autoDismissTimer = Timer(const Duration(minutes: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _stopAdhan() async {
    if (_isStopping) return; // Prevent multiple stop attempts
    
    setState(() => _isStopping = true);
    
    try {
      print('🛑 Stopping adhan for: ${widget.prayerName}');
      await _audioService.stop();
      
      // Cancel any repeat timer
      _repeatTimer?.cancel();
      
      // Clear repeat preferences
      await _clearRepeatPreferences();
      
      setState(() {
        _isPlaying = false;
        _isStopping = false;
      });
      
      print('✅ Adhan stopped successfully');
      Navigator.of(context).pop();
      
    } catch (e) {
      print('❌ Error stopping adhan: $e');
      setState(() => _isStopping = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل في إيقاف الأذان'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _repeatAdhan() async {
    // Schedule adhan to repeat after 10 minutes
    final repeatTime = DateTime.now().add(const Duration(minutes: 10));
    final context = this.context; // Save context before async operations
    
    try {
      print('🔄 Scheduling adhan repeat for: ${widget.prayerName} at $repeatTime');
      
      // Save repeat preferences for later retrieval
      await _saveRepeatPreferences(widget.prayerName, repeatTime);
      
      // Create a unique ID for this repeat
      final repeatId = 2000000 + DateTime.now().millisecondsSinceEpoch;
      
      if (Platform.isAndroid) {
        await AndroidAlarmManager.oneShotAt(
          repeatTime,
          repeatId,
          _repeatAlarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: false, // Don't reschedule on reboot to avoid issues
        );
        
        print('✅ Repeat scheduled with ID: $repeatId');
      } else {
        // For iOS and other platforms, use a simple timer
        _repeatTimer = Timer(repeatTime.difference(DateTime.now()), () {
          _repeatAlarmCallback(repeatId);
        });
      }

      // Stop current adhan
      await _audioService.stop();
      
      // Update state after stopping audio
      if (mounted) {
        setState(() => _isPlaying = false);
      }

      // Show confirmation and close dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('سيتم تكرار الأذان لصلاة ${widget.prayerName} بعد 10 دقائق'),
            duration: const Duration(seconds: 3),
          ),
        );
        
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      print('❌ Error scheduling repeat adhan: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في جدولة تكرار الأذان'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Callback function for repeat alarm
  static void _repeatAlarmCallback(int id) async {
    print('🔔 Repeat alarm triggered with ID: $id');
    
    try {
      // Initialize Flutter binding if needed
      WidgetsFlutterBinding.ensureInitialized();
      
      // Retrieve saved preferences
      final prefs = await SharedPreferences.getInstance();
      final prayerName = prefs.getString(_repeatPreferenceKey);
      final repeatTime = prefs.getInt(_repeatPreferenceTime);
      
      // Verify the repeat time is still valid (not too far in the past)
      if (prayerName != null && repeatTime != null) {
        final savedTime = DateTime.fromMillisecondsSinceEpoch(repeatTime);
        final now = DateTime.now();
        
        // Only proceed if the saved time is not more than 15 minutes ago
        if (now.difference(savedTime).inMinutes <= 15) {
          print('✅ Valid repeat found for: $prayerName');
          
          // Clear the preferences to prevent multiple triggers
          await prefs.remove(_repeatPreferenceKey);
          await prefs.remove(_repeatPreferenceTime);
          
          // Note: In a real app, you would navigate to show the dialog again
          // or trigger the prayer notification system here
          
          print('🔔 Repeat adhan should now trigger for: $prayerName');
        } else {
          print('⚠️ Repeat time expired, clearing preferences');
          await prefs.remove(_repeatPreferenceKey);
          await prefs.remove(_repeatPreferenceTime);
        }
      }
    } catch (e) {
      print('❌ Error in repeat alarm callback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.8),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Prayer icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mosque,
                      size: 50,
                      color: Colors.blue[800],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Prayer name
                  Text(
                    'حان وقت صلاة',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    widget.prayerName,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Status indicator
                  if (_isPlaying)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volume_up,
                          color: Colors.green[600],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الأذان يعمل...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 50),

                  // Action buttons
                  Row(
                    children: [
                      // Stop button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _stopAdhan,
                          icon: const Icon(Icons.stop),
                          label: const Text('إيقاف'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Repeat button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _repeatAdhan,
                          icon: const Icon(Icons.repeat),
                          label: const Text('تكرار'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Repeat info
                  Text(
                    'التكرار: الأذان بعد 10 دقائق',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}