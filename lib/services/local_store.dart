import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static Future<SharedPreferences>? _prefsF;
  static Future<SharedPreferences> _prefs() =>
      _prefsF ??= SharedPreferences.getInstance();

  // Custom prayers
  static Future<void> saveCustomPrayers(List<Map<String, dynamic>> list) async {
    final p = await _prefs();
    await p.setString('custom_prayers', jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> loadCustomPrayers() async {
    final p = await _prefs();
    final raw = p.getString('custom_prayers');
    if (raw == null) return <Map<String, dynamic>>[];
    final data = jsonDecode(raw) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // Theme preference
  static Future<String?> getThemeMode() async {
    final p = await _prefs();
    return p.getString('theme_mode');
  }

  static Future<void> setThemeMode(String themeMode) async {
    final p = await _prefs();
    await p.setString('theme_mode', themeMode);
  }

  // Morning/evening times
  static Future<String> getMorningTime() async {
    final p = await _prefs();
    return p.getString('morning_time') ?? '05:15';
  }

  static Future<void> setMorningTime(String time) async {
    final p = await _prefs();
    await p.setString('morning_time', time);
  }

  static Future<String> getEveningTime() async {
    final p = await _prefs();
    return p.getString('evening_time') ?? '17:45';
  }

  static Future<void> setEveningTime(String time) async {
    final p = await _prefs();
    await p.setString('evening_time', time);
  }

  static Future<String> getQuranTime() async {
    final p = await _prefs();
    return p.getString('quran_time') ?? '19:00';
  }

  static Future<void> setQuranTime(String time) async {
    final p = await _prefs();
    await p.setString('quran_time', time);
  }

  // Coordinates
  static Future<double> getLatitude() async {
    final p = await _prefs();
    return p.getDouble('user_latitude') ?? 15.3694;
  }

  static Future<void> setLatitude(double latitude) async {
    final p = await _prefs();
    await p.setDouble('user_latitude', latitude);
  }

  static Future<double> getLongitude() async {
    final p = await _prefs();
    return p.getDouble('user_longitude') ?? 44.1910;
  }

  static Future<void> setLongitude(double longitude) async {
    final p = await _prefs();
    await p.setDouble('user_longitude', longitude);
  }

  static Future<String> getPlaceName() async {
    final p = await _prefs();
    return p.getString('place_name') ?? 'Sana\'a, Yemen';
  }

  static Future<void> setPlaceName(String placeName) async {
    final p = await _prefs();
    await p.setString('place_name', placeName);
  }

  // General utility methods
  static Future<Map<String, dynamic>?> getStringMap(String key) async {
    final p = await _prefs();
    final raw = p.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> setStringMap(String key, Map<String, dynamic> value) async {
    final p = await _prefs();
    await p.setString(key, jsonEncode(value));
  }

  static Future<int?> getInt(String key) async {
    final p = await _prefs();
    return p.getInt(key);
  }

  static Future<void> setInt(String key, int value) async {
    final p = await _prefs();
    await p.setInt(key, value);
  }

  static Future<bool?> getBool(String key) async {
    final p = await _prefs();
    return p.getBool(key);
  }

  static Future<void> setBool(String key, bool value) async {
    final p = await _prefs();
    await p.setBool(key, value);
  }
}