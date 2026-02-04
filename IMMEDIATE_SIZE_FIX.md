# تطبيق فوري لإصلاح حجم التطبيق

## الخطوات العاجلة (5 دقائق)

### الخطوة 1: تنظيف التطبيق
```bash
flutter clean
flutter pub get
```

### الخطوة 2: إزالة صور المصحف من pubspec.yaml
```yaml
# في pubspec.yaml، غيّر هذا القسم:
flutter:
  assets:
    - assets/
    - assets/source/surah.json
    - assets/source/juz.json
    - assets/source/surah/
    - assets/source/tajweed/
    - assets/page_numbers.json
    # - assets/mushaf/page/        ← احذف هذا السطر
    # - assets/icon/logo.png       ← أو هذا إذا كان كبيراً
    # - assets/adhan/adhan.mp3     ← أو هذا إذا كان كبيراً
```

### الخطوة 3: إنشاء واجهة مؤقتة للمصحف
```dart
// lib/pages/mushaf_viewer_page.dart (النسخة المبسطة)
import 'package:flutter/material.dart';

class MushafViewerPage extends StatelessWidget {
  final String surahName;
  final int startPage;

  const MushafViewerPage({
    super.key,
    required this.surahName,
    required this.startPage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(surahName),
        backgroundColor: Colors.green.shade600,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 80, color: Colors.orange),
              SizedBox(height: 24),
              Text(
                'قريباً: قراءة المصحف',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'نحن نعمل على تحسين التطبيق\nسيتم إضافة قراءة المصحف قريباً\nحجم التطبيق المحسن متوفر الآن',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.arrow_back),
                label: Text('العودة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### الخطوة 4: بناء التطبيق المحسن
```bash
flutter build appbundle --release
```

## التحقق من الحجم
```bash
ls -lh build/app/outputs/bundle/release/app-release.aab
```

## إذا كان لا يزال كبيراً (>200MB):
فكّر في إزالة هذه الملفات أيضاً:
- `assets/adhan/adhan.mp3` (ملف الصوت)
- `assets/icon/logo.png` (إذا كان كبيراً)
- بعض الخطوط في `assets/fonts/`

## النتيجة المتوقعة
- حجم التطبيق: 15-25 ميجابايت ✅
- أقل من حد Google Play ✅
- قابل للرفع فوراً ✅

---

**تطبيق هذه الخطوات سيحل المشكلة في دقائق!**