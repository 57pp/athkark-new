import 'dart:convert';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

enum PrayerType {
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha,
}

extension PrayerTypeStorage on PrayerType {
  String get storageKey {
    switch (this) {
      case PrayerType.fajr:
        return 'pt.enabled_fajr';
      case PrayerType.dhuhr:
        return 'pt.enabled_dhuhr';
      case PrayerType.asr:
        return 'pt.enabled_asr';
      case PrayerType.maghrib:
        return 'pt.enabled_maghrib';
      case PrayerType.isha:
        return 'pt.enabled_isha';
    }
  }

  String get displayName {
    switch (this) {
      case PrayerType.fajr:
        return 'الفجر';
      case PrayerType.dhuhr:
        return 'الظهر';
      case PrayerType.asr:
        return 'العصر';
      case PrayerType.maghrib:
        return 'المغرب';
      case PrayerType.isha:
        return 'العشاء';
    }
  }

  int get notificationId {
    switch (this) {
      case PrayerType.fajr:
        return 501;
      case PrayerType.dhuhr:
        return 502;
      case PrayerType.asr:
        return 503;
      case PrayerType.maghrib:
        return 504;
      case PrayerType.isha:
        return 505;
    }
  }

  int get alarmId {
    switch (this) {
      case PrayerType.fajr:
        return 801;
      case PrayerType.dhuhr:
        return 802;
      case PrayerType.asr:
        return 803;
      case PrayerType.maghrib:
        return 804;
      case PrayerType.isha:
        return 805;
    }
  }
}

class PrayerPrefs {
  PrayerPrefs._(this._prefs);

  static const String _methodKey = 'pt.method';
  static const String _madhabKey = 'pt.madhab';
  static const String _lastScheduleDateKey = 'pt.last_schedule_date';
  static const String _latKey = 'pt.latitude';
  static const String _lngKey = 'pt.longitude';
  static const String _placeNameKey = 'pt.place_name';
  static const String _advancedAudioKey = 'pt.advanced_audio';
  static const String _customPrayersKey = 'pt.custom_prayers';

  final SharedPreferences _prefs;

  static Future<PrayerPrefs> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return PrayerPrefs._(prefs);
  }

  bool isPrayerEnabled(PrayerType prayer) =>
      _prefs.getBool(prayer.storageKey) ?? true;

  Future<void> setPrayerEnabled(PrayerType prayer, bool enabled) =>
      _prefs.setBool(prayer.storageKey, enabled);

  CalculationMethod get calculationMethod {
    final String? stored = _prefs.getString(_methodKey);
    if (stored == null) {
      return CalculationMethod.ummAlQura;
    }
    return CalculationMethod.values.firstWhere(
      (CalculationMethod method) => method.name == stored,
      orElse: () => CalculationMethod.ummAlQura,
    );
  }

  Future<void> setCalculationMethod(CalculationMethod method) =>
      _prefs.setString(_methodKey, method.name);

  Madhab get madhab {
    final String? stored = _prefs.getString(_madhabKey);
    if (stored == null) {
      return Madhab.shafi;
    }
    return Madhab.values.firstWhere(
      (Madhab value) => value.name == stored,
      orElse: () => Madhab.shafi,
    );
  }

  Future<void> setMadhab(Madhab value) =>
      _prefs.setString(_madhabKey, value.name);

  DateTime? get lastScheduleDate {
    final String? stored = _prefs.getString(_lastScheduleDateKey);
    if (stored == null || stored.isEmpty) {
      return null;
    }
    return DateTime.tryParse(stored);
  }

  Future<void> setLastScheduleDate(DateTime date) =>
      _prefs.setString(_lastScheduleDateKey, date.toIso8601String());

  Future<void> clearLastScheduleDate() => _prefs.remove(_lastScheduleDateKey);

  double? get latitude => _prefs.getDouble(_latKey);
  double? get longitude => _prefs.getDouble(_lngKey);

  Future<void> setCoordinates(double lat, double lng) async {
    await _prefs.setDouble(_latKey, lat);
    await _prefs.setDouble(_lngKey, lng);
  }

  Future<void> clearCoordinates() async {
    await _prefs.remove(_latKey);
    await _prefs.remove(_lngKey);
  }

  String? get placeName => _prefs.getString(_placeNameKey);

  Future<void> setPlaceName(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_placeNameKey);
      return;
    }
    await _prefs.setString(_placeNameKey, value);
  }

  bool get advancedAudioEnabled => _prefs.getBool(_advancedAudioKey) ?? false;

  Future<void> setAdvancedAudioEnabled(bool enabled) =>
      _prefs.setBool(_advancedAudioKey, enabled);

  // Custom prayers methods
  List<Map<String, dynamic>> getCustomPrayers() {
    final String? stored = _prefs.getString(_customPrayersKey);
    if (stored == null || stored.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = json.decode(stored);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error parsing custom prayers: $e');
      return [];
    }
  }

  Future<void> setCustomPrayers(List<Map<String, dynamic>> prayers) async {
    try {
      final String jsonString = json.encode(prayers);
      await _prefs.setString(_customPrayersKey, jsonString);
      print('Saved ${prayers.length} custom prayers to storage');
    } catch (e) {
      print('Error saving custom prayers: $e');
    }
  }
}
