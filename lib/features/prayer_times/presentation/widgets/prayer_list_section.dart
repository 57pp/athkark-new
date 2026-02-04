import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/prayer_prefs.dart';
import '../../domain/prayer_times_service_fixed.dart';
import 'prayer_ui_components.dart';

class PrayerListSection extends StatelessWidget {
  final PrayerTimesState state;
  final PrayerTimesService service;
  final DateFormat timeFormat;

  const PrayerListSection({
    super.key,
    required this.state,
    required this.service,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrayerUIComponents.buildSectionHeader(
          title: 'مواقيت اليوم',
          icon: Icons.schedule,
          iconColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        ...PrayerType.values.map((prayer) => 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildPrayerItem(context, prayer),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerItem(BuildContext context, PrayerType prayer) {
    final time = state.times[prayer]!;
    final isNext = state.nextPrayer == prayer;
    final enabled = state.enabled[prayer] ?? true;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getBorderColor(isNext, enabled, theme),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getBackgroundColors(isNext, enabled, theme),
          ),
          boxShadow: isNext ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getIconBackgroundColor(isNext, enabled, theme),
              shape: BoxShape.circle,
              boxShadow: isNext ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: PrayerUIComponents.buildPrayerIcon(
              prayer,
              color: _getIconColor(isNext, enabled, theme),
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  prayer.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                    color: _getTitleColor(isNext, enabled, theme),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isNext && enabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'القادمة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                PrayerUIComponents.buildTimeText(
                  timeFormat.format(time),
                  isNext: isNext,
                  color: _getTimeColor(isNext, enabled, theme),
                ),
              ],
            ),
          ),
          trailing: PrayerUIComponents.buildEnhancedSwitch(
            value: enabled,
            onChanged: (value) => service.togglePrayer(prayer, value),
            activeColor: theme.colorScheme.primary,
          ),
          onTap: () => _showPrayerDetails(context, prayer, time),
        ),
      ),
    );
  }

  Color _getBorderColor(bool isNext, bool enabled, ThemeData theme) {
    if (!enabled) return theme.colorScheme.outline.withOpacity(0.3);
    if (isNext) return theme.colorScheme.primary.withOpacity(0.8);
    return theme.colorScheme.primary.withOpacity(0.2);
  }

  List<Color> _getBackgroundColors(bool isNext, bool enabled, ThemeData theme) {
    if (!enabled) return [theme.colorScheme.surface, theme.colorScheme.surface];
    if (isNext) {
      return [
        theme.colorScheme.primary.withOpacity(0.08),
        theme.colorScheme.primary.withOpacity(0.04),
      ];
    }
    return [
      theme.colorScheme.primary.withOpacity(0.03),
      theme.colorScheme.primary.withOpacity(0.01),
    ];
  }

  Color _getIconBackgroundColor(bool isNext, bool enabled, ThemeData theme) {
    if (!enabled) return theme.colorScheme.outline.withOpacity(0.1);
    if (isNext) return theme.colorScheme.primary.withOpacity(0.15);
    return theme.colorScheme.primary.withOpacity(0.08);
  }

  Color _getIconColor(bool isNext, bool enabled, ThemeData theme) {
    if (!enabled) return theme.colorScheme.outline;
    if (isNext) return theme.colorScheme.primary;
    return theme.colorScheme.primary.withOpacity(0.8);
  }

  Color _getTitleColor(bool isNext, bool enabled, ThemeData theme) {
    if (!enabled) return theme.colorScheme.onSurface.withOpacity(0.5);
    if (isNext) return theme.colorScheme.primary;
    return theme.colorScheme.onSurface;
  }

  Color _getTimeColor(bool isNext, bool enabled, ThemeData theme) {
    if (!enabled) return theme.colorScheme.onSurface.withOpacity(0.5);
    if (isNext) return theme.colorScheme.primary;
    return theme.colorScheme.onSurface;
  }

  void _showPrayerDetails(BuildContext context, PrayerType prayer, DateTime time) {
    final theme = Theme.of(context);
    final nextPrayer = state.nextPrayer == prayer;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              PrayerUIComponents.buildPrayerIcon(
                prayer,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                prayer.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الوقت: ${timeFormat.format(time)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.toggle_on,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الحالة: ${state.enabled[prayer]! ? 'مفعل' : 'معطل'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (nextPrayer) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'هذه هي الصلاة القادمة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showTimeFormatOptions(context);
              },
              child: const Text('تنسيق الوقت'),
            ),
          ],
        );
      },
    );
  }

  void _showTimeFormatOptions(BuildContext context) {
    // يمكن إضافة خيارات تنسيق الوقت هنا
  }
}
