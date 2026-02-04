import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppColors {
  // Light Theme Colors
  static const Color primary = Color(0xFF0F3D3E);
  static const Color onPrimary = Color(0xFFE6EFF2);
  static const Color secondary = Color(0xFF748CAB);
  static const Color onSecondary = Color(0xFF0B1A1C);
  static const Color tertiary = Color(0xFF3A8891);
  static const Color onTertiary = Color(0xFF0B1A1C);
  static const Color background = Color(0xFFF4F8F9);
  static const Color onBackground = Color(0xFF0B1A1C);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF0B1A1C);
  static const Color surfaceVariant = Color(0xFFE6EFF2);
  static const Color outline = Color(0xFFCFE1E5);

  // Dark Theme Colors
  static const Color dPrimary = Color(0xFF0F3D3E);
  static const Color dOnPrimary = Color(0xFFE6EFF2);
  static const Color dSecondary = Color(0xFF748CAB);
  static const Color dOnSecondary = Color(0xFF0B1A1C);
  static const Color dTertiary = Color(0xFF3A8891);
  static const Color dOnTertiary = Color(0xFF0B1A1C);
  static const Color dBackground = Color(0xFF0B1A1C);
  static const Color dOnBackground = Color(0xFFE6EFF2);
  static const Color dSurface = Color(0xFF102326);
  static const Color dOnSurface = Color(0xFFE6EFF2);
  static const Color dSurfaceVariant = Color(0xFF1A2E31);
  static const Color dOutline = Color(0xFF274348);

  // Error Colors (Material 3 defaults)
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color dError = Color(0xFFF2B8B5);
  static const Color dOnError = Color(0xFF601410);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F3D3E), Color(0xFF3A8891)],
  );

  static const LinearGradient primaryGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F3D3E), Color(0xFF3A8891)],
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F3D3E), Color(0xFF3A8891)],
  );

  static const LinearGradient backgroundGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4F8F9), Color(0xFFFFFFFF)],
  );

  static const LinearGradient backgroundGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1A1C), Color(0xFF102326)],
  );

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Splash Screen Colors (close to palette)
  static const Color splashDarkStart = Color(0xFF0B1220);
  static const Color splashDarkEnd = Color(0xFF141B2D);
  static const Color splashLightStart = Color(0xFFF7FAFF);
  static const Color splashLightEnd = Color(0xFFEAF1FF);

  // Backward compatibility properties
  static const Color primaryColor = primary;
  static const Color secondaryColor = secondary;
  static const Color primaryColorDark = dPrimary;
  static const Color accentColor = tertiary;
}

// Text Styles for backward compatibility
class AppTextStyles {
  static TextStyle headline = TextStyle(
    fontSize: 24.sp,
    fontWeight: FontWeight.w700,
    fontFamily: 'Cairo',
  );

  static TextStyle title = TextStyle(
    fontSize: 20.sp,
    fontWeight: FontWeight.w700,
    fontFamily: 'Cairo',
  );

  static TextStyle body = TextStyle(
    fontSize: 18.sp,
    height: 1.5 * ScreenUtil().scaleHeight,
    fontFamily: 'Cairo',
  );

  static TextStyle caption = TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    fontFamily: 'Cairo',
  );
}