import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/prayer_times_service_fixed.dart';
import 'prayer_ui_components.dart';

class CustomPrayersSection extends StatefulWidget {
  final PrayerTimesService service;
  final DateFormat timeFormat;
  final VoidCallback onAddCustomPrayer;
  final Function(CustomPrayer) onDeleteCustomPrayer;
  final Function(CustomPrayer) onEditCustomPrayer;

  const CustomPrayersSection({
    super.key,
    required this.service,
    required this.timeFormat,
    required this.onAddCustomPrayer,
    required this.onDeleteCustomPrayer,
    required this.onEditCustomPrayer,
  });

  @override
  State<CustomPrayersSection> createState() => _CustomPrayersSectionState();
}

class _CustomPrayersSectionState extends State<CustomPrayersSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrayerUIComponents.buildSectionHeader(
          title: 'الصلوات المخصصة',
          icon: Icons.access_time,
          iconColor: Theme.of(context).colorScheme.primary,
        ),
        ValueListenableBuilder<List<CustomPrayer>>(
          valueListenable: widget.service.customPrayersNotifier,
          builder: (context, customPrayers, _) {
            if (customPrayers.isEmpty) {
              return PrayerUIComponents.buildEmptyState(
                context: context,
                icon: Icons.add_alarm,
                title: 'لا توجد صلوات مخصصة',
                subtitle: 'يمكنك إضافة صلوات مخصصة مثل صلاة الوتر أو صلاة الضحى',
                onAction: widget.onAddCustomPrayer,
                actionText: 'إضافة صلاة مخصصة',
              );
            }

            return Column(
              children: [
                ExpansionTile(
                  initiallyExpanded: _isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isExpanded = expanded;
                    });
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mosque,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'الصلوات المخصصة (${customPrayers.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    Column(
                      children: [
                        ...customPrayers.map((prayer) => 
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: _buildCustomPrayerItem(context, prayer),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAddButton(context),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomPrayerItem(BuildContext context, CustomPrayer prayer) {
    final theme = Theme.of(context);
    final isEnabled = prayer.enabled;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEnabled 
              ? theme.colorScheme.primary.withOpacity(0.2)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isEnabled ? [
              theme.colorScheme.primary.withOpacity(0.05),
              theme.colorScheme.primary.withOpacity(0.02),
            ] : [
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isEnabled 
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : theme.colorScheme.outline.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mosque,
              color: isEnabled 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 24,
            ),
          ),
          title: Text(
            prayer.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isEnabled 
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.timeFormat.format(prayer.time),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر الحالة
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEnabled 
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 12),
              // زر التبديل
              PrayerUIComponents.buildEnhancedSwitch(
                value: isEnabled,
                onChanged: (value) async {
                  await widget.service.toggleCustomPrayer(prayer.id, value);
                },
                activeColor: theme.colorScheme.primary,
              ),
              // قائمة الإجراءات
              PrayerUIComponents.buildEnhancedPopupMenu(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      widget.onEditCustomPrayer(prayer);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(prayer);
                      break;
                  }
                },
                menuItems: {
                  'edit': Icons.edit,
                  'delete': Icons.delete_outline,
                },
              ),
            ],
          ),
          onTap: () => widget.onEditCustomPrayer(prayer),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ElevatedButton.icon(
          onPressed: widget.onAddCustomPrayer,
          icon: const Icon(Icons.add, size: 20),
          label: const Text(
            'إضافة صلاة مخصصة جديدة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(CustomPrayer prayer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('حذف الصلاة المخصصة'),
          content: Text('هل أنت متأكد من حذف صلاة "${prayer.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDeleteCustomPrayer(prayer);
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }
}