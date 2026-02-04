import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// نظام إدارة إشعارات الأذكار الإسلامية الشامل
/// يدعم الأذكار الصباحية والمسائية وأذكار النوم وأذكار بعد الصلاة
class AdhkarNotifications {
  AdhkarNotifications._();
  static final AdhkarNotifications instance = AdhkarNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // معرفات القنوات
  static const String morningChannelId = 'athkark.adhkar.morning';
  static const String eveningChannelId = 'athkark.adhkar.evening';
  static const String postPrayerChannelId = 'athkark.adhkar.postPrayer';
  static const String sleepChannelId = 'athkark.adhkar.sleep';
  static const String generalChannelId = 'athkark.adhkar.general';

  // قائمة الأذكار الصحيحة
  static const Map<String, List<Map<String, String>>> _adhkarDatabase = {
    'morning': [
      {
        'text': 'أصبحنا وأصبح الملك لله، والحمد لله',
        'count': '1',
        'category': 'صباحية'
      },
      {
        'text': 'أعوذ بكلمات الله التامات من شر ما خلق',
        'count': '3',
        'category': 'صباحية'
      },
      {
        'text': 'بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم',
        'count': '3',
        'category': 'صباحية'
      },
      {
        'text': 'رضيت بالله رباً وبالإسلام ديناً وبمحمد صلى الله عليه وسلم نبياً',
        'count': '3',
        'category': 'صباحية'
      },
      {
        'text': 'يا حي يا قيوم برحمتك أستغيث أصلح لي كل أمري ولا تكلني إلى نفسي طرفة عين',
        'count': '1',
        'category': 'صباحية'
      },
      {
        'text': 'أصبحنا وأصبح الميزان بيد الله وحده لا شريك له إليه المآب',
        'count': '1',
        'category': 'صباحية'
      }
    ],
    'evening': [
      {
        'text': 'أمسينا وأمسى الملك لله، والحمد لله',
        'count': '1',
        'category': 'مسائية'
      },
      {
        'text': 'أعوذ بكلمات الله التامات من شر ما خلق',
        'count': '3',
        'category': 'مسائية'
      },
      {
        'text': 'يا حي يا قيوم برحمتك أستغيث أصلح لي كل أمري ولا تكلني إلى نفسي طرفة عين',
        'count': '1',
        'category': 'مسائية'
      },
      {
        'text': 'أعوذ بالله من الشيطان الرجيم',
        'count': '1',
        'category': 'مسائية'
      },
      {
        'text': 'رضيت بالله رباً وبالإسلام ديناً وبمحمد صلى الله عليه وسلم نبياً',
        'count': '3',
        'category': 'مسائية'
      }
    ],
    'post_prayer': [
      {
        'text': 'سبحان الله',
        'count': '33',
        'category': 'بعد الصلاة'
      },
      {
        'text': 'الحمد لله',
        'count': '33',
        'category': 'بعد الصلاة'
      },
      {
        'text': 'الله أكبر',
        'count': '34',
        'category': 'بعد الصلاة'
      },
      {
        'text': 'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير',
        'count': '1',
        'category': 'بعد الصلاة'
      },
      {
        'text': 'أستغفر الله',
        'count': '10',
        'category': 'بعد الصلاة'
      }
    ],
    'sleep': [
      {
        'text': 'باسمك أموت وأحيا',
        'count': '1',
        'category': 'نوم'
      },
      {
        'text': 'سبحان الله',
        'count': '33',
        'category': 'نوم'
      },
      {
        'text': 'الحمد لله',
        'count': '33',
        'category': 'نوم'
      },
      {
        'text': 'الله أكبر',
        'count': '34',
        'category': 'نوم'
      },
      {
        'text': 'أعوذ بالله من الشيطان الرجيم',
        'count': '3',
        'category': 'نوم'
      },
      {
        'text': 'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير',
        'count': '1',
        'category': 'نوم'
      }
    ]
  };

  /// تهيئة النظام
  Future<void> init() async {
    await _createNotificationChannels();
  }

  /// جدولة أذكار الصباح
  Future<void> scheduleMorningAdhkar({
    required int hour,
    required int minute,
  }) async {
    await _scheduleAdhkar(
      type: 'morning',
      hour: hour,
      minute: minute,
      title: '🌅 أذكار الصباح المباركة',
      body: 'حان وقت أذكار الصباح المباركة',
      channelId: morningChannelId,
    );
  }

  /// جدولة أذكار المساء
  Future<void> scheduleEveningAdhkar({
    required int hour,
    required int minute,
  }) async {
    await _scheduleAdhkar(
      type: 'evening',
      hour: hour,
      minute: minute,
      title: '🌆 أذكار المساء المباركة',
      body: 'حان وقت أذكار المساء المباركة',
      channelId: eveningChannelId,
    );
  }

  /// جدولة أذكار النوم
  Future<void> scheduleSleepAdhkar({
    required int hour,
    required int minute,
  }) async {
    await _scheduleAdhkar(
      type: 'sleep',
      hour: hour,
      minute: minute,
      title: '🌙 أذكار النوم المباركة',
      body: 'حان وقت أذكار النوم المباركة',
      channelId: sleepChannelId,
    );
  }

  /// جدولة أذكار بعد الصلاة
  Future<void> schedulePostPrayerAdhkar() async {
    // يتم جدولة هذا تلقائياً بناءً على أوقات الصلاة
    await _scheduleAdhkar(
      type: 'post_prayer',
      hour: -1, // سيتم حسابه بناءً على أوقات الصلاة
      minute: 0,
      title: '🤲 أذكار بعد الصلاة',
      body: 'حان وقت أذكار ما بعد الصلاة',
      channelId: postPrayerChannelId,
    );
  }

  /// إظهار إشعار آذكار فوري للاختبار
  Future<void> showImmediateAdhkar({required String type}) async {
    final adhkarList = _adhkarDatabase[type];
    if (adhkarList == null || adhkarList.isEmpty) return;

    final randomAdhkar = adhkarList[Random().nextInt(adhkarList.length)];
    final channelId = _getChannelIdForType(type);
    
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      channelId: channelId,
      title: _getTitleForType(type),
      body: randomAdhkar['text'] ?? '',
      payload: {'type': type},
    );
  }

  /// إلغاء جميع إشعارات الأذكار
  Future<void> cancelAllAdhkarNotifications() async {
    await _plugin.cancelAll();
  }

  /// جدولة إشعار الذكر
  Future<void> _scheduleAdhkar({
    required String type,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelId,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled;

    if (hour == -1) {
      // سيتم حسابه بناءً على أوقات الصلاة
      scheduled = now.add(const Duration(minutes: 10));
    } else {
      scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }

    final adhkarList = _adhkarDatabase[type];
    final randomAdhkar = adhkarList != null && adhkarList.isNotEmpty 
        ? adhkarList[Random().nextInt(adhkarList.length)]
        : {'text': body, 'count': '1'};

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _getChannelNameForType(type),
        channelDescription: 'إشعارات ${_getChannelNameForType(type)}',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          '${randomAdhkar['text']}\n\nالتكرار: ${randomAdhkar['count']} مرات',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      _getNotificationIdForType(type),
      title,
      body,
      scheduled,
      notificationDetails,
      payload: jsonEncode({'type': type, 'title': title, 'body': body}),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: hour == -1 ? null : DateTimeComponents.time,
    );
  }

  /// إظهار إشعار
  Future<void> _showNotification({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required Map<String, dynamic>? payload,
  }) async {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _getChannelNameForType(channelId),
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  /// إنشاء قنوات الإشعارات
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    const List<Map<String, String>> channels = [
      {
        'id': morningChannelId,
        'name': 'أذكار الصباح',
        'description': 'إشعارات أذكار الصباح المباركة'
      },
      {
        'id': eveningChannelId,
        'name': 'أذكار المساء',
        'description': 'إشعارات أذكار المساء المباركة'
      },
      {
        'id': postPrayerChannelId,
        'name': 'أذكار بعد الصلاة',
        'description': 'إشعارات أذكار ما بعد الصلاة'
      },
      {
        'id': sleepChannelId,
        'name': 'أذكار النوم',
        'description': 'إشعارات أذكار النوم المباركة'
      },
      {
        'id': generalChannelId,
        'name': 'أذكار عامة',
        'description': 'إشعارات الأذكار العامة'
      },
    ];

    for (final channel in channels) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        AndroidNotificationChannel(
          channel['id']!,
          channel['name']!,
          description: channel['description']!,
          importance: Importance.high,
        ),
      );
    }
  }

  /// الحصول على معرف الإشعار بناءً على النوع
  int _getNotificationIdForType(String type) {
    switch (type) {
      case 'morning':
        return 1001;
      case 'evening':
        return 1002;
      case 'post_prayer':
        return 1003;
      case 'sleep':
        return 1004;
      default:
        return 1005;
    }
  }

  /// الحصول على معرف القناة بناءً على النوع
  String _getChannelIdForType(String type) {
    switch (type) {
      case 'morning':
        return morningChannelId;
      case 'evening':
        return eveningChannelId;
      case 'post_prayer':
        return postPrayerChannelId;
      case 'sleep':
        return sleepChannelId;
      default:
        return generalChannelId;
    }
  }

  /// الحصول على اسم القناة بناءً على النوع
  String _getChannelNameForType(String type) {
    switch (type) {
      case 'morning':
        return 'أذكار الصباح';
      case 'evening':
        return 'أذكار المساء';
      case 'post_prayer':
        return 'أذكار بعد الصلاة';
      case 'sleep':
        return 'أذكار النوم';
      case morningChannelId:
        return 'أذكار الصباح';
      case eveningChannelId:
        return 'أذكار المساء';
      case postPrayerChannelId:
        return 'أذكار بعد الصلاة';
      case sleepChannelId:
        return 'أذكار النوم';
      default:
        return 'أذكار عامة';
    }
  }

  /// الحصول على العنوان بناءً على النوع
  String _getTitleForType(String type) {
    switch (type) {
      case 'morning':
        return '🌅 أذكار الصباح المباركة';
      case 'evening':
        return '🌆 أذكار المساء المباركة';
      case 'post_prayer':
        return '🤲 أذكار بعد الصلاة';
      case 'sleep':
        return '🌙 أذكار النوم المباركة';
      default:
        return 'أذكارك';
    }
  }
}