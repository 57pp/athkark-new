import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/navigation/deep_link.dart';
import '../utils/simple_prayer_audio_service.dart';

/// Full-screen popup dialog for prayer notifications
/// This appears when the app is closed and a prayer notification is tapped
class PrayerPopupDialog extends StatefulWidget {
  final NotificationResponse response;
  
  const PrayerPopupDialog({
    super.key,
    required this.response,
  });

  @override
  State<PrayerPopupDialog> createState() => _PrayerPopupDialogState();
}

class _PrayerPopupDialogState extends State<PrayerPopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String _prayerName = '';
  
  @override
  void initState() {
    super.initState();
    _parsePayload();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }
  
  void _parsePayload() {
    try {
      final payload = widget.response.payload;
      if (payload != null) {
        final data = Uri.parse(payload).queryParameters;
        _prayerName = data['prayer'] ?? 'الصلاة';
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
      _prayerName = 'الصلاة';
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildDialogContent(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDialogContent() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.indigo[900]!,
            Colors.deepPurple[800]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 30),
          _buildPrayerContent(),
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.amber.withValues(alpha: 0.2),
          ),
          child: Icon(
            Icons.mosque,
            size: 40,
            color: Colors.amber,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'حان وقت صلاة $_prayerName',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Cairo',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'حان الأوان لتأدية الصلاة والانتقال للأذكار',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
            fontFamily: 'Cairo',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildPrayerContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            'السلام عليكم ورحمة الله وبركاته',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'هذا هو الوقت المناسب لأداء صلاة $_prayerName\n\n'
            'قم بتأدية الصلاة وأذكارها،\n'
            'وسوف يتم توجيهك لصفحة الأذكار.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: 'Cairo',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _navigateToAdhkar(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'فتح الأذكار',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton(
            onPressed: () => _dismissPopup(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'تأجيل لاحقاً',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _stopNotification(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: const Text(
            'إيقاف الإشعار',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }
  
  void _navigateToAdhkar() {
    // Close the dialog and navigate to adhkar screen
    Navigator.of(context).pop();
    
    // Parse the notification payload to get the route
    try {
      final payload = widget.response.payload;
      if (payload != null) {
        // Navigate toadhkar screen
        final route = '/adhkar';
        // In a real app, you would use your navigation system here
        debugPrint('Navigating to: $route');
      }
    } catch (e) {
      debugPrint('Error navigating to adhkar: $e');
    }
  }
  
  void _dismissPopup() {
    Navigator.of(context).pop();
  }
  
  void _stopNotification() {
    // Stop the notification and close popup
    // In a real implementation, you would cancel the notification here
    debugPrint('Stopping prayer notification');

    // Stop the adhan audio if it's playing
    try {
      SimplePrayerAudioService.instance.stop();
      debugPrint('Adhan audio playback stopped');
    } catch (e) {
      debugPrint('Error stopping adhan audio: $e');
    }

    Navigator.of(context).pop();
  }
}

/// Helper class to show prayer popup dialog
class PrayerPopupHelper {
  static Future<void> showPrayerPopup(NotificationResponse response) async {
    // This would be called when notification is tapped
    // In a real app, you would use your navigation system here
    debugPrint('Showing prayer popup for payload: ${response.payload}');
  }
}