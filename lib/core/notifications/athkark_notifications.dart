import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AthkarkNotifications {
  AthkarkNotifications._();

  static final AthkarkNotifications instance = AthkarkNotifications._();

  static const String morningChannelId = 'athkark.morning';
  static const String eveningChannelId = 'athkark.evening';
  static const String postPrayerChannelId = 'athkark.postPrayer';
  static const String quranChannelId = 'athkark.quran';
  static const String nudgesChannelId = 'athkark.nudges';
  static const String darwinCategoryId = 'athkark.actions';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Random _random = Random();

  SharedPreferences? _prefs;
  bool _timezoneInitialized = false;
  tz.Location? _locationCache;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> init() async {
    await _ensureReady();
    await _ensureDefaults();
    await _requestPermissions();
    await _createAndroidChannels();
  }

  Future<void> scheduleDaily({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required TimeOfDay time,
    Map<String, dynamic>? payload,
  }) async {
    await _ensureReady();
    final tz.TZDateTime now = tz.TZDateTime.now(_location);
    tz.TZDateTime scheduled = _nextInstanceOfTime(time, now);

    final bool inQuietHours = _isWithinQuietHours(scheduled);
    if (inQuietHours && channelId != postPrayerChannelId) {
      return;
    }
    if (!_passesCooldownCheck(scheduled)) {
      return;
    }

    final Map<String, dynamic> mergedPayload = <String, dynamic>{
      'channelId': channelId,
      'title': title,
      'body': body,
      if (payload != null) ...payload,
    };

    final NotificationDetails details = _buildNotificationDetails(
      channelId: channelId,
      title: title,
      body: body,
      silent: channelId == postPrayerChannelId && inQuietHours,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      payload: _encodePayload(mergedPayload),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleNudgesRandom({
    required int baseId,
    int count = 2,
    TimeOfDay windowStart = const TimeOfDay(hour: 9, minute: 0),
    TimeOfDay windowEnd = const TimeOfDay(hour: 21, minute: 0),
    Map<String, dynamic>? payload,
    String? title,
    String? body,
  }) async {
    await _ensureReady();
    final int minPerDay = _prefs?.getInt('nudges_per_day') ?? count;
    final int targetCount = minPerDay.clamp(1, 5);

    final int startMinutes = windowStart.hour * 60 + windowStart.minute;
    final int endMinutes = windowEnd.hour * 60 + windowEnd.minute;
    if (endMinutes <= startMinutes) {
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(_location);
    final Set<int> offsets = <int>{};
    final int available = endMinutes - startMinutes;

    while (offsets.length < targetCount && offsets.length < available) {
      offsets.add(_random.nextInt(available) + startMinutes);
    }

    int index = 0;
    for (final int minutes in offsets) {
      final int hour = minutes ~/ 60;
      final int minute = minutes % 60;
      tz.TZDateTime scheduled = tz.TZDateTime(
        _location,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduled.isBefore(now.add(const Duration(minutes: 1)))) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      if (_isWithinQuietHours(scheduled)) {
        continue;
      }
      if (!_passesCooldownCheck(scheduled)) {
        continue;
      }

      final String nudgesTitle = title ?? 'Gentle Tasbih Nudge';
      final String nudgesBody =
          body ?? 'Take a moment for tasbih and remembrance.';

      final Map<String, dynamic> mergedPayload = <String, dynamic>{
        'channelId': nudgesChannelId,
        'title': nudgesTitle,
        'body': nudgesBody,
        ...?payload,
      };
      mergedPayload.putIfAbsent('route', () => '/tasbih');

      final NotificationDetails details = _buildNotificationDetails(
        channelId: nudgesChannelId,
        title: nudgesTitle,
        body: nudgesBody,
        silent: false,
      );

      await _plugin.zonedSchedule(
        baseId + index,
        nudgesTitle,
        nudgesBody,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: _encodePayload(mergedPayload),
      );
      index += 1;
    }
  }

  Future<void> schedulePrayerReminders({
    required int baseId,
    required Coordinates coordinates,
    CalculationMethod calculationMethod = CalculationMethod.muslimWorldLeague,
    Madhab madhab = Madhab.shafi,
  }) async {
    await _ensureReady();
    final tz.TZDateTime now = tz.TZDateTime.now(_location);
    final DateTime baseDate = DateTime(now.year, now.month, now.day);
    final CalculationParameters params =
        _parametersForMethod(calculationMethod);
    params.madhab = madhab;

    final PrayerTimes times = PrayerTimes(
      date: baseDate,
      coordinates: coordinates,
      calculationParameters: params,
      precision: true,
    );
    final List<_PrayerSchedule> reminders = <_PrayerSchedule>[
      _PrayerSchedule('Fajr', times.fajr),
      _PrayerSchedule('Dhuhr', times.dhuhr),
      _PrayerSchedule('Asr', times.asr),
      _PrayerSchedule('Maghrib', times.maghrib),
      _PrayerSchedule('Isha', times.isha),
    ];

    int offset = 0;
    for (final _PrayerSchedule entry in reminders) {
      final tz.TZDateTime baseTime =
          tz.TZDateTime.from(entry.time.toUtc(), _location);
      final tz.TZDateTime scheduled = baseTime.add(const Duration(minutes: 7));

      if (scheduled.isBefore(now.add(const Duration(minutes: 1)))) {
        continue;
      }

      final bool inQuiet = _isWithinQuietHours(scheduled);
      if (!_passesCooldownCheck(scheduled)) {
        continue;
      }

      final String title = 'Post prayer adhkar';
      final String body = 'It is time for adhkar after ${entry.label}.';

      final Map<String, dynamic> mergedPayload = <String, dynamic>{
        'channelId': postPrayerChannelId,
        'title': title,
        'body': body,
        'route': '/adhkar',
        'type': 'post_prayer',
      };

      final NotificationDetails details = _buildNotificationDetails(
        channelId: postPrayerChannelId,
        title: title,
        body: body,
        silent: inQuiet,
      );

      await _plugin.zonedSchedule(
        baseId + offset,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: _encodePayload(mergedPayload),
      );
      offset += 1;
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancelById(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> recordInteraction({DateTime? timestamp}) async {
    await _ensureReady();
    final DateTime moment = (timestamp ?? DateTime.now()).toUtc();
    await _prefs?.setString('last_interaction_at', moment.toIso8601String());
  }

  Future<void> snooze({
    required int id,
    required Map<String, dynamic> payload,
    Duration duration = const Duration(minutes: 10),
  }) async {
    await _ensureReady();
    final String? channelId = payload['channelId'] as String?;
    if (channelId == null) {
      return;
    }

    final String title = payload['title'] as String? ?? 'Athkark reminder';
    final String body = payload['body'] as String? ?? '';
    final tz.TZDateTime scheduled = tz.TZDateTime.now(_location).add(duration);
    final bool silent =
        channelId == postPrayerChannelId && _isWithinQuietHours(scheduled);

    final NotificationDetails details = _buildNotificationDetails(
      channelId: channelId,
      title: title,
      body: body,
      silent: silent,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: _encodePayload(payload),
    );
  }

  Future<void> _ensureReady() async {
    if (!_timezoneInitialized) {
      tz.initializeTimeZones();
      _locationCache = tz.getLocation('Asia/Aden');
      tz.setLocalLocation(_locationCache!);
      _timezoneInitialized = true;
    }
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _ensureDefaults() async {
    final SharedPreferences prefs = _prefs!;
    prefs.setBool(
        'quiet_hours_enabled', prefs.getBool('quiet_hours_enabled') ?? true);
    prefs.setString(
        'quiet_hours_start', prefs.getString('quiet_hours_start') ?? '23:30');
    prefs.setString(
        'quiet_hours_end', prefs.getString('quiet_hours_end') ?? '05:00');
    prefs.setInt('nudges_per_day', prefs.getInt('nudges_per_day') ?? 2);
    prefs.setString('quran_time', prefs.getString('quran_time') ?? '19:00');
    prefs.setString('morning_time', prefs.getString('morning_time') ?? '05:15');
    prefs.setString('evening_time', prefs.getString('evening_time') ?? '17:45');
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
      critical: false,
    );

    final MacOSFlutterLocalNotificationsPlugin? macImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    await macImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? implementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (implementation == null) {
      return;
    }

    for (final _AndroidChannelConfig channel in _channelConfigs) {
      await implementation.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: channel.importance,
          playSound: channel.importance != Importance.low,
          enableVibration: channel.importance != Importance.low,
        ),
      );
    }
  }

  bool _isWithinQuietHours(tz.TZDateTime dateTime) {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null || !(prefs.getBool('quiet_hours_enabled') ?? true)) {
      return false;
    }

    final TimeOfDay start =
        _parseTimeOfDay(prefs.getString('quiet_hours_start') ?? '23:30');
    final TimeOfDay end =
        _parseTimeOfDay(prefs.getString('quiet_hours_end') ?? '05:00');

    final int startMinutes = start.hour * 60 + start.minute;
    final int endMinutes = end.hour * 60 + end.minute;
    final int currentMinutes = dateTime.hour * 60 + dateTime.minute;

    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }

  bool _passesCooldownCheck(tz.TZDateTime scheduled) {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return true;
    }

    final String? lastInteractionRaw = prefs.getString('last_interaction_at');
    if (lastInteractionRaw == null) {
      return true;
    }

    final DateTime? parsed = DateTime.tryParse(lastInteractionRaw);
    if (parsed == null) {
      return true;
    }

    final tz.TZDateTime lastInteraction = tz.TZDateTime.from(parsed, _location);
    if (!scheduled.isAfter(lastInteraction)) {
      return true;
    }

    return scheduled.difference(lastInteraction) >= const Duration(minutes: 60);
  }

  NotificationDetails _buildNotificationDetails({
    required String channelId,
    required String title,
    required String body,
    required bool silent,
  }) {
    final _AndroidChannelConfig channel = _channelConfigs.firstWhere(
      (config) => config.id == channelId,
      orElse: () => _AndroidChannelConfig(
        id: channelId,
        name: channelId,
        description: '',
        importance: Importance.defaultImportance,
      ),
    );

    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: _priorityForImportance(channel.importance),
      icon: 'ic_stat_athkark',
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(body),
      playSound: !silent,
      enableVibration: !silent,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'mark_read',
          'Mark read',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze_10',
          'Snooze 10m',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'open',
          'Open',
          showsUserInterface: true,
        ),
      ],
    );

    final DarwinNotificationDetails darwin = DarwinNotificationDetails(
      categoryIdentifier: darwinCategoryId,
      presentAlert: !silent,
      presentBadge: !silent,
      presentSound: !silent,
      threadIdentifier: channelId,
      interruptionLevel:
          silent ? InterruptionLevel.passive : InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(
    TimeOfDay time,
    tz.TZDateTime reference,
  ) {
    tz.TZDateTime scheduled = tz.TZDateTime(
      _location,
      reference.year,
      reference.month,
      reference.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(reference)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final List<String> parts = value.split(':');
    final int hour = int.tryParse(parts.elementAt(0)) ?? 0;
    final int minute = int.tryParse(parts.elementAt(1)) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _encodePayload(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    return jsonEncode(payload);
  }

  tz.Location get _location {
    _locationCache ??= tz.getLocation('Asia/Aden');
    return _locationCache!;
  }

  CalculationParameters _parametersForMethod(CalculationMethod method) {
    switch (method) {
      case CalculationMethod.dubai:
        return CalculationMethodParameters.dubai();
      case CalculationMethod.egyptian:
        return CalculationMethodParameters.egyptian();
      case CalculationMethod.karachi:
        return CalculationMethodParameters.karachi();
      case CalculationMethod.kuwait:
        return CalculationMethodParameters.kuwait();
      case CalculationMethod.moonsightingCommittee:
        return CalculationMethodParameters.moonsightingCommittee();
      case CalculationMethod.morocco:
        return CalculationMethodParameters.morocco();
      case CalculationMethod.muslimWorldLeague:
        return CalculationMethodParameters.muslimWorldLeague();
      case CalculationMethod.northAmerica:
        return CalculationMethodParameters.northAmerica();
      case CalculationMethod.other:
        return CalculationMethodParameters.other();
      case CalculationMethod.qatar:
        return CalculationMethodParameters.qatar();
      case CalculationMethod.singapore:
        return CalculationMethodParameters.singapore();
      case CalculationMethod.tehran:
        return CalculationMethodParameters.tehran();
      case CalculationMethod.turkiye:
        return CalculationMethodParameters.turkiye();
      case CalculationMethod.ummAlQura:
        return CalculationMethodParameters.ummAlQura();
    }
  }
}

Map<String, dynamic> decodeNotificationPayload(String? raw) {
  if (raw == null || raw.isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

class _AndroidChannelConfig {
  const _AndroidChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
  });

  final String id;
  final String name;
  final String description;
  final Importance importance;
}

class _PrayerSchedule {
  const _PrayerSchedule(this.label, this.time);

  final String label;
  final DateTime time;
}

const List<_AndroidChannelConfig> _channelConfigs = <_AndroidChannelConfig>[
  _AndroidChannelConfig(
    id: AthkarkNotifications.morningChannelId,
    name: 'Morning Adhkar',
    description: 'Daily reminders for morning adhkar.',
    importance: Importance.high,
  ),
  _AndroidChannelConfig(
    id: AthkarkNotifications.eveningChannelId,
    name: 'Evening Adhkar',
    description: 'Daily reminders for evening adhkar.',
    importance: Importance.high,
  ),
  _AndroidChannelConfig(
    id: AthkarkNotifications.postPrayerChannelId,
    name: 'Post prayer adhkar',
    description: 'Reminders to recite adhkar after the daily prayers.',
    importance: Importance.defaultImportance,
  ),
  _AndroidChannelConfig(
    id: AthkarkNotifications.quranChannelId,
    name: 'Daily Quran',
    description: 'Reminders for your daily Quran reading.',
    importance: Importance.defaultImportance,
  ),
  _AndroidChannelConfig(
    id: AthkarkNotifications.nudgesChannelId,
    name: 'Tasbih nudges',
    description: 'Light tasbih nudges throughout the day.',
    importance: Importance.low,
  ),
];

Priority _priorityForImportance(Importance importance) {
  switch (importance) {
    case Importance.max:
      return Priority.max;
    case Importance.high:
      return Priority.high;
    case Importance.low:
      return Priority.low;
    case Importance.min:
    case Importance.none:
      return Priority.min;
    case Importance.defaultImportance:
    default:
      return Priority.defaultPriority;
  }
}
