import 'package:flutter/material.dart';

enum AdhanButtonSize {
  large, // For featured buttons like Fajr
  medium, // For regular prayer buttons
  small, // For compact buttons
}

class AdhanButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onPressed;
  final AdhanButtonSize size;
  final bool isEnabled;
  final Widget? trailing;
  final String? statusText;
  final bool showNextPrayerIndicator;

  const AdhanButton({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.gradientColors,
    this.onPressed,
    this.size = AdhanButtonSize.medium,
    this.isEnabled = true,
    this.trailing,
    this.statusText,
    this.showNextPrayerIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Size configurations
    final double height = size == AdhanButtonSize.large ? 130.0 :
                          size == AdhanButtonSize.medium ? 100.0 : 80.0;
    final double iconSize = size == AdhanButtonSize.large ? 32.0 :
                           size == AdhanButtonSize.medium ? 24.0 : 20.0;
    final double titleFontSize = size == AdhanButtonSize.large ? 24.0 :
                                size == AdhanButtonSize.medium ? 18.0 : 16.0;
    final double subtitleFontSize = size == AdhanButtonSize.large ? 18.0 :
                                   size == AdhanButtonSize.medium ? 14.0 : 12.0;
    final EdgeInsets padding = size == AdhanButtonSize.large ?
        const EdgeInsets.all(20) : const EdgeInsets.all(16);
    final double borderRadius = size == AdhanButtonSize.large ? 20.0 : 16.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: isEnabled ? onPressed : null,
          child: Container(
            padding: padding,
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 16),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: titleFontSize,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: subtitleFontSize,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status indicator or trailing widget
                if (statusText != null || trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEnabled ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: trailing ?? Text(
                      statusText ?? (isEnabled ? 'مفعل' : 'معطل'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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

// Specialized widget for next prayer indicator
class NextPrayerIndicator extends StatelessWidget {
  final String remainingTime;

  const NextPrayerIndicator({
    super.key,
    required this.remainingTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.access_time,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'الصلاة القادمة - متبقي: $remainingTime',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}