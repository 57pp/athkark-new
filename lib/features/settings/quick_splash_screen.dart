import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class QuickSplashScreen extends StatefulWidget {
  const QuickSplashScreen({super.key});

  @override
  State<QuickSplashScreen> createState() => _QuickSplashScreenState();
}

class _QuickSplashScreenState extends State<QuickSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _ringScaleAnimation;

  late Animation<double> _textSlideAnimation;
  late Animation<double> _textOpacityAnimation;

  late Animation<double> _loadingOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Logo
    _logoScaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
      ),
    );

    // Outer ring subtle pulse
    _ringScaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Text
    _textSlideAnimation = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Loading
    _loadingOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: Curves.easeOut,
      ),
    );

    _startAnimations();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 150));
    await _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();

    await Future.delayed(const Duration(milliseconds: 250));
    await _loadingController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark
                ? [
                    AppColors.dBackground,
                    AppColors.dPrimary.withOpacity(0.85),
                  ]
                : [
                    AppColors.primary.withOpacity(0.90),
                    AppColors.secondaryColor.withOpacity(0.95),
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Soft glow background circles
            Positioned(
              top: -120,
              right: -60,
              child: _BlurCircle(
                diameter: 220,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -40,
              child: _BlurCircle(
                diameter: 260,
                color: Colors.black.withOpacity(0.25),
              ),
            ),

            // Main content
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                    [_logoController, _textController, _loadingController],
                  ),
                  builder: (context, _) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // LOGO + RING
                        Opacity(
                          opacity: _logoOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer soft glow ring
                                  Transform.scale(
                                    scale: _ringScaleAnimation.value,
                                    child: Container(
                                      width: 150,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.32),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Inner circle (PURE WHITE BACKGROUND, NO COLOR OVER LOGO)
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white, // خلفية بيضاء صافية
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withOpacity(0.35),
                                          blurRadius: 24,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.85),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Image.asset(
                                          'assets/logo.png',
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Center(
                                              child: Icon(
                                                Icons.mosque_rounded,
                                                size: 52,
                                                color: AppColors.primaryColor,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // TITLE / SUBTITLE / FEATURES CARD
                        Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Opacity(
                            opacity: _textOpacityAnimation.value,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 28),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color:
                                            Colors.white.withOpacity(0.22),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'أذكاري',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.1,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'كل لحظة ذكر، أذان، وتسبيح في مكان واحد مصمَّم ليهدّي قلبك.',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14.5,
                                            height: 1.6,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white
                                                .withOpacity(0.94),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.center,
                                          children: const [
                                            _FeatureChip('مواقيت دقيقة'),
                                            _FeatureChip('تنبيهات الأذكار'),
                                            _FeatureChip('عداد تسبيح ذكي'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // LOADING LINE + TEXT
                        Opacity(
                          opacity: _loadingOpacityAnimation.value,
                          child: Column(
                            children: [
                              // Line loader
                              Container(
                                width: 160,
                                height: 4,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withOpacity(0.16),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedBuilder(
                                    animation: _loadingController,
                                    builder: (context, _) {
                                      final value =
                                          (_loadingController.value * 2.0) % 1.0;
                                      return FractionallySizedBox(
                                        widthFactor: 0.35,
                                        alignment: AlignmentDirectional(
                                          value * 2 - 1,
                                          0,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Colors.white
                                                    .withOpacity(0.95),
                                                Colors.white
                                                    .withOpacity(0.65),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'جارٍ تهيئة تجربتك الإيمانية...',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.96),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'لن يستغرق الأمر إلا لحظات.',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11.5,
                                  color: Colors.white.withOpacity(0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Bottom branding
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    'تم التطوير بحب للمسلمين حول العالم',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'أذكاري © ${DateTime.now().year}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.45),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double diameter;
  final Color color;

  const _BlurCircle({
    required this.diameter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        color: Colors.white.withOpacity(0.10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.95),
        ),
      ),
    );
  }
}
