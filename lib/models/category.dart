import 'package:flutter/material.dart';

import 'dhikrs.dart';
class Category {
  int id;
  String category;
  String audio;
  String filename;
  List<Dhikr> dhikrs;
  bool isPinned; // إضافة خاصية التثبيت

  Category({
    required this.id,
    required this.category,
    required this.audio,
    required this.filename,
    required this.dhikrs,
    this.isPinned = false, // القيمة الافتراضية تكون false
  });

  IconData? get icon {
    switch (category) {
      case 'أذكار الصباح':
        return Icons.wb_sunny;
      case 'أذكار المساء':
        return Icons.nights_stay;
      case 'أذكار النوم':
        return Icons.bedtime;
      case 'أذكار الاستيقاظ':
        return Icons.alarm;
      case 'أذكار الصلاة':
        return Icons.mosque;
      case 'أذكار الطعام':
        return Icons.restaurant;
      case 'أذكار السفر':
        return Icons.flight;
      case 'أذكار المنزل':
        return Icons.home;
      case 'أذكار الوضوء':
        return Icons.water_drop;
      case 'أذكار الدعاء':
        return Icons.favorite;
      default:
        return Icons.book;
    }
  }
}