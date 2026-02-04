import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/category.dart';
import '../../models/dhikrs.dart';

class DataProvider {
  // جلب الفئات من ملف JSON
  Future<List<Category>> getCategories() async {
    // تحميل البيانات من ملف JSON
    String jsonData = await rootBundle.loadString('assets/adhkar.json');
    List<dynamic> data = jsonDecode(jsonData);

    // تحميل حالة التثبيت من SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // تحويل البيانات إلى قائمة من الفئات
    List<Category> categories = data.map((categoryJson) {
      List<Dhikr> dhikrs = (categoryJson['array'] as List)
          .map((dhikrJson) => Dhikr(
                id: dhikrJson['id'],
                text: dhikrJson['text'],
                count: dhikrJson['count'],
                audio: dhikrJson['audio'],
                filename: dhikrJson['filename'],
              ))
          .toList();

      // إنشاء كائن Category مع تحميل حالة التثبيت
      return Category(
        id: categoryJson['id'],
        category: categoryJson['category'],
        audio: categoryJson['audio'],
        filename: categoryJson['filename'],
        dhikrs: dhikrs,
        isPinned: prefs.getBool('pinned_${categoryJson['id']}') ?? false, // تحميل حالة التثبيت
      );
    }).toList();

    return categories;
  }

  // تغيير حالة التثبيت وحفظها
  Future<void> togglePinCategory(int categoryId, bool isPinned) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pinned_$categoryId', isPinned); // حفظ حالة التثبيت
  }
}