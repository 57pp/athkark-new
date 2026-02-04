import 'package:flutter/material.dart';
import 'colors.dart';

final ColorScheme lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: AppColors.onPrimary,
  secondary: AppColors.secondary,
  onSecondary: AppColors.onSecondary,
  tertiary: AppColors.tertiary,
  onTertiary: AppColors.onTertiary,
  background: AppColors.background,
  onBackground: AppColors.onBackground,
  surface: AppColors.surface,
  onSurface: AppColors.onSurface,
  surfaceVariant: AppColors.surfaceVariant,
  onSurfaceVariant: AppColors.onSurface,
  outline: AppColors.outline,
  error: AppColors.error,
  onError: AppColors.onError,
);

final ColorScheme darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.dPrimary,
  onPrimary: AppColors.dOnPrimary,
  secondary: AppColors.dSecondary,
  onSecondary: AppColors.dOnSecondary,
  tertiary: AppColors.dTertiary,
  onTertiary: AppColors.dOnTertiary,
  background: AppColors.dBackground,
  onBackground: AppColors.dOnBackground,
  surface: AppColors.dSurface,
  onSurface: AppColors.dOnSurface,
  surfaceVariant: AppColors.dSurfaceVariant,
  onSurfaceVariant: AppColors.dOnSurface,
  outline: AppColors.dOutline,
  error: AppColors.dError,
  onError: AppColors.dOnError,
);

ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: lightScheme,
  scaffoldBackgroundColor: lightScheme.background,
  fontFamily: 'Cairo',
  appBarTheme: AppBarTheme(
    backgroundColor: lightScheme.surface,
    foregroundColor: lightScheme.onSurface,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: lightScheme.onSurface,
      fontFamily: 'Cairo',
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: lightScheme.primary,
      foregroundColor: lightScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: lightScheme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lightScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lightScheme.primary, width: 1.6),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lightScheme.outline),
    ),
    labelStyle: TextStyle(color: lightScheme.onSurface),
    hintStyle: TextStyle(color: lightScheme.onSurface.withOpacity(0.7)),
  ),
  cardTheme: CardThemeData(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    color: lightScheme.surface,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: lightScheme.primary,
    foregroundColor: lightScheme.onPrimary,
  ),
);

ThemeData buildDarkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: darkScheme,
  scaffoldBackgroundColor: darkScheme.background,
  fontFamily: 'Cairo',
  appBarTheme: AppBarTheme(
    backgroundColor: darkScheme.surface,
    foregroundColor: darkScheme.onSurface,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: darkScheme.onSurface,
      fontFamily: 'Cairo',
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: darkScheme.primary,
      foregroundColor: darkScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: darkScheme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: darkScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: darkScheme.tertiary, width: 1.6),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: darkScheme.outline),
    ),
    labelStyle: TextStyle(color: darkScheme.onSurface),
    hintStyle: TextStyle(color: darkScheme.onSurface.withOpacity(0.7)),
  ),
  cardTheme: CardThemeData(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    color: darkScheme.surface,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: darkScheme.primary,
    foregroundColor: darkScheme.onPrimary,
  ),
);