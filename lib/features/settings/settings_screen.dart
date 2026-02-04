import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import '../../shared/widgets/custom_app_bar.dart';
import '../../shared/utils/adhkar_notification_service.dart';
import '../../shared/utils/welcome_notification_service.dart';
import '../../features/prayer_times/domain/prayer_times_service_fixed.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback toggleTheme;

  const SettingsScreen({required this.toggleTheme, super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      title: 'الإعدادات',
      showBackButton: false,
      useBottomNavBarStyle: true,
      leading: const SizedBox.shrink(), // Remove back button completely
    );
  }

  Widget _buildBody(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundGradientDark
            : AppColors.backgroundGradientLight,
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General Settings Section
          _buildSectionHeader(context, 'الإعدادات العامة'),
          _buildSettingsTile(
            context,
            title: 'الوضع الليلي',
            subtitle: 'تفعيل أو تعطيل الوضع الليلي',
            icon: Icons.brightness_6,
            trailing: Switch(
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (value) => toggleTheme(),
              activeColor: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 8),

          // Adhkar Notifications Section
          _buildSectionHeader(context, 'تذكيرات الأذكار'),
          _buildAdhkarNotificationSettings(context),
          const SizedBox(height: 8),


          // Welcome Notifications Section
          _buildSectionHeader(context, 'إشعارات الترحيب'),
          _buildWelcomeNotificationSettings(context),
          const SizedBox(height: 8),

          // App Information Section
          _buildSectionHeader(context, 'معلومات التطبيق'),
          _buildSettingsTile(
            context,
            title: 'المميزات',
            subtitle: 'اكتشف مميزات التطبيق',
            icon: Icons.star,
            onTap: () => _showFeaturesDialog(context),
          ),
          _buildSettingsTile(
            context,
            title: 'قيمنا',
            subtitle: 'تعرف على قيمنا ورسالتنا',
            icon: Icons.emoji_events,
            onTap: () => _showOurValuesDialog(context),
          ),
          _buildSettingsTile(
            context,
            title: 'عن التطبيق',
            subtitle: 'إصدار التطبيق والمزيد',
            icon: Icons.info,
            onTap: () => _showAppInfoDialog(context),
          ),

          // Developer Section
          _buildSectionHeader(context, 'المطورون'),
          _buildSettingsTile(
            context,
            title: 'فريق التطوير',
            subtitle: 'تعرف على فريق التطوير',
            icon: Icons.code,
            onTap: () => _showDevelopersDialog(context),
          ),
          _buildSettingsTile(
            context,
            title: 'تواصل مع المطور',
            subtitle: 'رقم الهاتف: +967779509319',
            icon: Icons.contact_phone,
            onTap: () => _showContactDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        title,
        style: AppTextStyles.headline.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        title: Text(
          title,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          textAlign: TextAlign.right,
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.right,
        ),
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAdhkarNotificationSettings(BuildContext context) {
    final adhkarService = AdhkarNotificationService.instance;

    return Column(
      children: [
        // Morning Adhkar
        _buildSettingsTile(
          context,
          title: 'أذكار الصباح ☀️',
          subtitle: 'تذكير يومي بأذكار الصباح',
          icon: Icons.wb_sunny,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${adhkarService.morningTime.hour.toString().padLeft(2, '0')}:${adhkarService.morningTime.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: adhkarService.morningEnabled,
                onChanged: (value) async {
                  await adhkarService.setMorningAdhkar(enabled: value);
                  // Force rebuild
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                },
                activeColor: AppColors.secondaryColor,
              ),
            ],
          ),
          onTap: () => _showTimePicker(context, 'morning'),
        ),

        // Evening Adhkar
        _buildSettingsTile(
          context,
          title: 'أذكار المساء 🌙',
          subtitle: 'تذكير يومي بأذكار المساء',
          icon: Icons.nights_stay,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${adhkarService.eveningTime.hour.toString().padLeft(2, '0')}:${adhkarService.eveningTime.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: adhkarService.eveningEnabled,
                onChanged: (value) async {
                  await adhkarService.setEveningAdhkar(enabled: value);
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                },
                activeColor: AppColors.secondaryColor,
              ),
            ],
          ),
          onTap: () => _showTimePicker(context, 'evening'),
        ),

        // Daily Adhkar Reminder
        _buildSettingsTile(
          context,
          title: 'تذكير يومي 📿',
          subtitle: 'تذكير عام بالأذكار والتسبيح',
          icon: Icons.notifications,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${adhkarService.dailyTime.hour.toString().padLeft(2, '0')}:${adhkarService.dailyTime.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: adhkarService.dailyEnabled,
                onChanged: (value) async {
                  await adhkarService.setDailyAdhkar(enabled: value);
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                },
                activeColor: AppColors.secondaryColor,
              ),
            ],
          ),
          onTap: () => _showTimePicker(context, 'daily'),
        ),

      ],
    );
  }

  Future<void> _showTimePicker(BuildContext context, String type) async {
    final adhkarService = AdhkarNotificationService.instance;
    TimeOfDay initialTime;

    switch (type) {
      case 'morning':
        initialTime = adhkarService.morningTime;
        break;
      case 'evening':
        initialTime = adhkarService.eveningTime;
        break;
      case 'daily':
        initialTime = adhkarService.dailyTime;
        break;
      default:
        return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (pickedTime != null && context.mounted) {
      switch (type) {
        case 'morning':
          await adhkarService.setMorningAdhkar(enabled: adhkarService.morningEnabled, time: pickedTime);
          break;
        case 'evening':
          await adhkarService.setEveningAdhkar(enabled: adhkarService.eveningEnabled, time: pickedTime);
          break;
        case 'daily':
          await adhkarService.setDailyAdhkar(enabled: adhkarService.dailyEnabled, time: pickedTime);
          break;
      }

      // Force rebuild
      (context as Element).markNeedsBuild();
    }
  }


  Widget _buildPrayerNotificationSettings(BuildContext context) {
    return const SizedBox.shrink(); // Remove all test buttons for production
  }

  Widget _buildWelcomeNotificationSettings(BuildContext context) {
    final welcomeService = WelcomeNotificationService.instance;

    return Column(
      children: [
        // Welcome Notifications Toggle
        _buildSettingsTile(
          context,
          title: 'إشعارات الترحيب الذكية',
          subtitle: 'إشعارات شخصية عند فتح التطبيق',
          icon: Icons.waving_hand,
          trailing: Switch(
            value: welcomeService.welcomeNotificationsEnabled,
            onChanged: (value) async {
              await welcomeService.setWelcomeNotificationsEnabled(value);
              if (context.mounted) {
                (context as Element).markNeedsBuild();
              }
            },
            activeColor: AppColors.secondaryColor,
          ),
        ),

        // User Statistics
        _buildSettingsTile(
          context,
          title: 'إحصائيات الاستخدام',
          subtitle: 'عرض إحصائيات استخدام التطبيق',
          icon: Icons.analytics,
          onTap: () => _showUserStatisticsDialog(context),
        ),

      ],
    );
  }

  void _showUserStatisticsDialog(BuildContext context) {
    final stats = WelcomeNotificationService.instance.getUserStatistics();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إحصائيات الاستخدام'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('عدد مرات فتح التطبيق:', '${stats['app_open_count']}'),
                _buildStatRow('آخر فتح:', _formatDateTime(stats['last_app_open'])),
                _buildStatRow('أول فتح:', _formatDateTime(stats['first_app_open'])),
                _buildStatRow('أيام منذ آخر فتح:', '${stats['days_since_last_open']}'),
                _buildStatRow('أيام منذ أول فتح:', '${stats['days_since_first_open']}'),
                _buildStatRow('الإشعارات مفعلة:', stats['welcome_notifications_enabled'] ? 'نعم' : 'لا'),
                _buildStatRow('الخدمة مهيأة:', stats['is_initialized'] ? 'نعم' : 'لا'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return 'غير محدد';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'غير محدد';
    }
  }






  void _showFeaturesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CustomDialog(
        title: 'المميزات',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFeatureItem('حساب أوقات الصلاة بدقة حسب موقعك مع تحديث يومي'),
              _buildFeatureItem('تنبيهات الأذان مع خيارات الإيقاف والتكرار من الإشعار'),
              _buildFeatureItem('تذكير أذكار الصباح والمساء والتنبيه اليومي المرن'),
              _buildFeatureItem('مكتبة أذكار مصنفة مع بحث سريع عن الدعاء'),
              _buildFeatureItem('عرض الذكر بتصميم مريح مع مشاركة كنص أو صورة عالية الجودة'),
              _buildFeatureItem('عداد تسبيح مدمج يحفظ تقدمك لكل ذكر'),
              _buildFeatureItem('تنبيهات بعد الصلاة وترحيب بالمستخدم الجديد'),
              _buildFeatureItem('دعم كامل للوضع الليلي واللغة العربية واتجاه RTL'),
              _buildFeatureItem('عمل بدون إنترنت للأذكار المخزّنة محلياً'),
              _buildFeatureItem('إدارة جميع التنبيهات من الإعدادات بضغطة واحدة'),
            ],
          ),
        ),
      ),
    );
  }

  void _showOurValuesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CustomDialog(
        title: 'قيمنا',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              color: AppColors.secondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'نسعى لتقديم أفضل تجربة مستخدم مع الحفاظ على الهوية الإسلامية',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: _CustomDialog(
          title: 'عن تطبيق أذكارك',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoRow('اسم التطبيق :', 'أذكارك'),
              Divider(
                  height: 24.h,
                  color: AppColors.outline.withOpacity(0.2)),
              _buildInfoRow('الإصدار الحالي :', 'الإصدار  2.0.0'),
              SizedBox(height: 16.h),
              Text(
                'تطبيق اذكارك يساعدك على المداومة على الأذكار اليومية\nبإصدارات متطورة وواجهة مستخدم مريحة',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14.sp,
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.color
                      ?.withOpacity(0.8),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showDevelopersDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => _CustomDialog(
      title: 'فريق التطوير',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDeveloperCard('م. شهاب  محمد'),
          _buildDeveloperCard('م. عبدالرحمن طلال'),
          _buildDeveloperCard('م. أحمد محمد'),
        ],
      ),
    ),
  );
}

void _showContactDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => _CustomDialog(
      title: 'تواصل مع المطور',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.contact_phone,
            color: AppColors.secondaryColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'رقم الهاتف: +967779509319',
            style: AppTextStyles.body.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك الاتصال أو إرسال رسالة للاستفسارات أو الدعم.',
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse('tel:+967779509319');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.phone),
                label: const Text('اتصال'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse('sms:+967779509319');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.message),
                label: const Text('رسالة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildFeatureItem(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
            child: Text(
          text,
          style: AppTextStyles.body,
          textAlign: TextAlign.right,
        )),
        const SizedBox(width: 12),
        const Icon(Icons.check_circle, color: AppColors.secondaryColor),
      ],
    ),
  );
}

Widget _buildInfoRow(String title, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 8.h),
    child: Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: AppTextStyles.body),
        Text(
          value,
          style: AppTextStyles.body,
        ),
      ],
    ),
  );
}

Widget _buildDeveloperCard(String name) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      //leading: Icon(Icons.person, color: AppColors.primaryColor),
      title: Text(
        name,
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _CustomDialog extends StatelessWidget {
  final String title;
  final Widget content;

  const _CustomDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        style: AppTextStyles.title,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(child: content),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.secondaryColor),
            ),
          ),
        ),
      ],
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      insetPadding: const EdgeInsets.all(20),
    );
  }
}

