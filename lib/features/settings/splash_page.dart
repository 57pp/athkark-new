import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../shared/utils/unified_prayer_notification_service.dart';

import '../../core/theme/colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    // Wait for services to initialize, then navigate
    await _waitForServicesInitialization();
  }

  Future<void> _waitForServicesInitialization() async {
    try {
      // Wait for services to be ready with timeout
      bool servicesReady = false;
      int attempts = 0;
      const maxAttempts = 15; // 15 seconds max (faster timeout)

      print('🔄 Waiting for services to initialize...');
      
      while (!servicesReady && attempts < maxAttempts) {
        final unifiedService = UnifiedPrayerNotificationService.instance;

        // Check if main services are ready
        final unifiedReady = unifiedService.isInitialized;

        if (unifiedReady) {
          servicesReady = true;
          print('✅ Services ready after ${attempts}s');
          break;
        }
        
        await Future.delayed(const Duration(milliseconds: 500)); // Faster checking
        attempts++;
        
        // Print progress every 2 seconds
        if (attempts % 4 == 0) {
          print('⏳ Services still initializing... (${attempts}s elapsed)');
        }
      }

      // Navigate based on results
      if (servicesReady) {
        print('✅ Services ready, navigating to home');
        _navigateToHome();
      } else {
        // Try to navigate anyway, but with a delay to ensure basic initialization
        print('⚠️ Timeout waiting for services, navigating after short delay');
        await Future.delayed(const Duration(seconds: 1));
        _navigateToHome();
      }
      
    } catch (e) {
      print('❌ Error waiting for services: $e');
      // Navigate anyway after delay
      await Future.delayed(const Duration(seconds: 1));
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.splashDarkStart, AppColors.splashDarkEnd]
        : [AppColors.splashLightStart, AppColors.splashLightEnd];
    final baseTextStyle = Theme.of(context).textTheme.headlineSmall ??
        Theme.of(context).textTheme.titleLarge ??
        const TextStyle(fontSize: 24);
    final headline = baseTextStyle.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 128,
                          height: 128,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'أذكارك',
                          style: headline,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تطبيق الأذكار والقرآن الكريم',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.light
                                ? AppColors.onSurface
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // Loading indicator
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).brightness == Brightness.light
                                  ? AppColors.primaryColor
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'جاري تحميل النظام...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.light
                                ? AppColors.onSurface.withOpacity(0.7)
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
