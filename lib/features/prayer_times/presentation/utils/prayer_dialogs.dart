import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/prayer_times_service_fixed.dart';

class PrayerDialogs {
  static Future<void> showAddCustomPrayerDialog(
    BuildContext context,
    PrayerTimesService service,
    DateFormat timeFormat,
  ) async {
    final TextEditingController nameController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إضافة صلاة مخصصة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الصلاة',
                  hintText: 'مثل: الوتر، الرواتب، التراويح',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.access_time, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الوقت المحدد',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                          ),
                          Text(
                            '${selectedTime.format(context)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final TimeOfDay? time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          selectedTime = time;
                          Navigator.of(context).pop({
                            'name': nameController.text.trim(),
                            'time': time,
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule, size: 16),
                      label:
                          const Text('تغيير', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        minimumSize: const Size(80, 40),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final String name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': name,
                    'time': selectedTime,
                  });
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await service.addCustomPrayer(
          result['name'] as String,
          result['time'] as TimeOfDay,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إضافة صلاة ${result['name']} بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إضافة الصلاة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  static Future<void> showEditCustomPrayerDialog(
    BuildContext context,
    CustomPrayer prayer,
    PrayerTimesService service,
    DateFormat timeFormat,
  ) async {
    final TextEditingController nameController =
        TextEditingController(text: prayer.name);
    TimeOfDay selectedTime =
        TimeOfDay(hour: prayer.time.hour, minute: prayer.time.minute);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل الصلاة المخصصة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الصلاة',
                  hintText: 'مثل: الوتر، الرواتب، التراويح',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.access_time, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الوقت المحدد',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                          ),
                          Text(
                            selectedTime.format(context),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final TimeOfDay? time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          selectedTime = time;
                          Navigator.of(context).pop({
                            'name': nameController.text.trim(),
                            'time': time,
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule, size: 16),
                      label:
                          const Text('تغيير', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        minimumSize: const Size(80, 40),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final String name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': name,
                    'time': selectedTime,
                  });
                }
              },
              child: const Text('حفظ التغييرات'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await service.updateCustomPrayer(
          prayer.id,
          result['name'] as String,
          result['time'] as TimeOfDay,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث صلاة ${result['name']} بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تحديث الصلاة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  static Future<void> showDeleteCustomPrayerDialog(
    BuildContext context,
    CustomPrayer prayer,
    PrayerTimesService service,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف الصلاة'),
          content: Text('هل أنت متأكد من حذف صلاة "${prayer.name}"؟'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await service.removeCustomPrayer(prayer.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الصلاة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف الصلاة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
