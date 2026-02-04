import 'dart:async';
import 'package:flutter/material.dart';

import '../../domain/prayer_prefs.dart';

/// مكونات مشتركة لواجهة مواقيت الصلاة
class PrayerUIComponents {
  // ألوان الثيم
  static const double _borderRadius = 12.0;
  static const double _largeBorderRadius = 20.0;
  static const double _smallBorderRadius = 8.0;
  static const double _cardElevation = 1.5;
  static const double _smallSpacing = 6.0;
  static const double _mediumSpacing = 12.0;
  static const double _largeSpacing = 16.0;
  static const double _xlSpacing = 24.0;
  
  // ألوان مكررة
  static const Color _whiteWithOpacity02 = Color(0x33FFFFFF);
  static const Color _whiteWithOpacity05 = Color(0x0DFFFFFF);
  static const Color _whiteWithOpacity08 = Color(0x14FFFFFF);
  static const Color _whiteWithOpacity09 = Color(0xE6FFFFFF);
  static const Color _whiteWithOpacity1 = Color(0x1AFFFFFF);
  static const Color _whiteWithOpacity12 = Color(0x1FFFFFFF);
  static const Color _whiteWithOpacity15 = Color(0x26FFFFFF);
  static const Color _whiteWithOpacity18 = Color(0x2DFFFFFF);
  static const Color _whiteWithOpacity2 = Color(0x33FFFFFF);
  static const Color _whiteWithOpacity25 = Color(0x40FFFFFF);

  /// إنشاء بطاقة عامة محسنة بصرياً
  static Widget buildEnhancedCard({
    required Widget child,
    required BuildContext context,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Color? backgroundColor,
    BorderRadius? borderRadius,
    double? elevation,
  }) {
    return Card(
      elevation: elevation ?? _cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(_borderRadius),
      ),
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(_borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundColor != null 
                ? [backgroundColor.withOpacity(0.95), backgroundColor.withOpacity(0.9)]
                : [
                    Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(0.98),
                    Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(0.95),
                  ],
          ),
        ),
        padding: padding ?? const EdgeInsets.all(_mediumSpacing),
        child: child,
      ),
    );
  }

  /// إنشاء عنصر قائمة محسن
  static Widget buildEnhancedListTile({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsets? contentPadding,
    BorderRadius? borderRadius,
    Color? backgroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: _mediumSpacing, vertical: _smallSpacing),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: leading,
        ),
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(_borderRadius),
        ),
        tileColor: backgroundColor,
      ),
    );
  }

  /// إنشاء تدرج متدرج هيرويك للبطاقة الرئيسية
  static LinearGradient buildHeroGradient(BuildContext context) {
    final theme = Theme.of(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.colorScheme.primary.withOpacity(0.95),
        theme.colorScheme.primary.withOpacity(0.85),
        theme.colorScheme.secondary.withOpacity(0.8),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
  }

  /// إنشاء تدرج داخلي خفيف
  static LinearGradient buildLightInnerGradient() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _whiteWithOpacity1,
        _whiteWithOpacity05,
      ],
    );
  }

  /// إنشاء ظلال محسنة للبطاقات
  static List<BoxShadow> buildEnhancedShadows(BuildContext context, {double opacity = 0.4}) {
    final theme = Theme.of(context);
    return [
      BoxShadow(
        color: theme.colorScheme.primary.withOpacity(opacity),
        blurRadius: 30,
        offset: const Offset(0, 15),
        spreadRadius: 2,
      ),
    ];
  }

  /// إنشاء ظلال خفيفة للعناصر
  static List<BoxShadow> buildLightShadows() {
    return [
      BoxShadow(
        color: Colors.white.withOpacity(0.3),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// إنشاء حاوية أيقونة محسنة (متصغرة)
  static Widget buildIconContainer({
    required Widget child,
    double size = 32,
    Color? backgroundColor,
    List<BoxShadow>? shadows,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? _whiteWithOpacity08,
        shape: BoxShape.circle,
        boxShadow: shadows ?? buildLightShadows(),
      ),
      child: child,
    );
  }

  /// إنشاء بطاقة إحصائية للشروق والوقت (متصغرة)
  static Widget buildStatCard({
    required BuildContext context,
    required Widget icon,
    required String label,
    required String value,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? _whiteWithOpacity18,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _whiteWithOpacity25,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// إنشاء عنصر عرض الوقت (متصغر)
  static Widget buildTimeDisplay({
    required BuildContext context,
    required String time,
    bool isHighlighted = false,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          textColor ?? Colors.white,
          textColor != null ? textColor : Colors.white.withOpacity(0.9),
        ],
      ).createShader(bounds),
      child: Text(
        time,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: 0.8,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  /// إنشاء زر مخصص للوضع المظلم/المضيء (متصغر)
  static Widget buildThemeToggleButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _whiteWithOpacity15,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: Colors.white,
          size: 20,
        ),
        tooltip: isDarkMode ? 'الوضع المضيء' : 'الوضع المظلم',
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  /// إنشاء خط فاصل متدرج
  static Widget buildGradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _whiteWithOpacity08,
            _whiteWithOpacity2,
            _whiteWithOpacity08,
          ],
        ),
      ),
    );
  }

  /// إنشاء بطاقة عرض معلومات
  static Widget buildInfoCard({
    required BuildContext context,
    required String title,
    Widget? content,
    EdgeInsets? padding,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _whiteWithOpacity12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: content ?? Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// إنشاء بطاقة عرض الوقت المحدد (متصغرة)
  static Widget buildTimeInfoCard({
    required BuildContext context,
    required String timeText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _whiteWithOpacity12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 12,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// إنشاء بطاقة تمييز للصلاة (متصغرة)
  static Widget buildPrayerHighlightCard({
    required BuildContext context,
    required String prayerName,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? _whiteWithOpacity15,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _whiteWithOpacity2,
          width: 0.8,
        ),
      ),
      child: Text(
        prayerName,
        style: theme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// إنشاء أيقونة مخصصة للصلاة
  static Widget buildPrayerIcon(PrayerType prayer, {Color? color, double size = 24}) {
    IconData icon;
    switch (prayer) {
      case PrayerType.fajr:
        icon = Icons.wb_twilight;
        break;
      case PrayerType.dhuhr:
        icon = Icons.wb_sunny;
        break;
      case PrayerType.asr:
        icon = Icons.wb_cloudy;
        break;
      case PrayerType.maghrib:
        icon = Icons.wb_sunny_outlined;
        break;
      case PrayerType.isha:
        icon = Icons.nightlight_round;
        break;
    }
    return Icon(
      icon,
      color: color,
      size: size,
    );
  }

  /// إنشاء نص زمن محسن
  static Widget buildTimeText(String time, {bool isNext = false, Color? color}) {
    return Text(
      time,
      style: TextStyle(
        fontSize: 16,
        fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  /// إنشاء عنوان قسم محسن
  static Widget buildSectionHeader({
    required String title,
    required IconData icon,
    Color? iconColor,
    VoidCallback? onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _mediumSpacing, vertical: _smallSpacing),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor ?? Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: _smallSpacing),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onRefresh,
              tooltip: 'تحديث',
            ),
        ],
      ),
    );
  }

  /// إنشاء رسالة حالة فارغة محسنة
  static Widget buildEmptyState({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onAction,
    required String actionText,
  }) {
    return buildEnhancedCard(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(_mediumSpacing),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.blue.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: _mediumSpacing),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _smallSpacing),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _mediumSpacing),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: Text(actionText),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// إنشاء زر تبديل محسن
  static Widget buildEnhancedSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: Colors.grey.withOpacity(0.3),
    );
  }

  /// إنشاء زر إجراءات منسدل محسن
  static Widget buildEnhancedPopupMenu({
    required Function(String) onSelected,
    Map<String, IconData>? menuItems,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      icon: const Icon(Icons.more_vert, size: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => menuItems?.entries.map((entry) {
        return PopupMenuItem<String>(
          value: entry.key,
          child: Row(
            children: [
              Icon(entry.value, size: 18),
              const SizedBox(width: 12),
              Text(_getMenuItemText(entry.key)),
            ],
          ),
        );
      }).toList() ?? [],
    );
  }

  /// ترجمة عناصر القائمة
  static String _getMenuItemText(String key) {
    switch (key) {
      case 'edit':
        return 'تعديل';
      case 'delete':
        return 'حذف';
      case 'enable':
        return 'تفعيل';
      case 'disable':
        return 'إلغاء التفعيل';
      default:
        return key;
    }
  }

  /// إنشاء رسالة شريط علوي محسنة
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showEnhancedSnackBar(
    BuildContext context, {
    required String message,
    String? actionText,
    VoidCallback? onAction,
    int duration = 3,
    Color? backgroundColor,
  }) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        action: actionText != null && onAction != null
            ? SnackBarAction(
                label: actionText,
                onPressed: onAction,
              )
            : null,
        duration: Duration(seconds: duration),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
