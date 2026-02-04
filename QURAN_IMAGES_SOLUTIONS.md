# حلول لإضافة صور القرآن مع التحكم في الحجم

## الخيارات المتاحة:

### 🥇 الخيار الأول: صفحات مختارة فقط (30 صفحة)

#### الصفحات المقترحة:
1. **سورة الفاتحة** (الصفحة 1)
2. **سورة البقرة** (الصفحات 2-14)
3. **سورة آل عمران** (الصفحات 18-25)
4. **سورة يس** (الصفحة 22)
5. **سورة الملك** (الصفحة 28)
6. **سورة الفلق** (الصفحة 30)

#### الميزات:
- حجم صغير (15-20 ميجابايت)
- يغطي أكثر السور قراءة
- سرعة تحميل عالية
- مثالي للبداية

---

### 🥈 الخيار الثاني: تحميل عند الطلب (الأفضل طويل المدى)

#### كيف يعمل:
1. **بداية خفيفة**: التطبيق بدون صور
2. **تحميل تدريجي**: المستخدم يختار ما يريد تحميله
3. **حفظ محلي**: الصور تبقى في الجهاز بعد التحميل
4. **إدارة المساحة**: إمكانية حذف الصور غير المستخدمة

#### الخطوات:

##### 1. إنشاء خدمة التحميل
```dart
// lib/services/quran_download_service.dart
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class QuranDownloadService {
  static const Map<int, String> surahPages = {
    1: [1], // الفاتحة
    2: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], // البقرة
    3: [18, 19, 20, 21, 22, 23, 24, 25], // آل عمران
    36: [22], // يس
    67: [28], // الملك
    113: [30], // الفلق
  };
  
  static Future<String> downloadPage(int pageNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/quran_pages/page_${pageNumber}.webp';
    final file = File(filePath);
    
    if (await file.exists()) {
      return filePath;
    }
    
    // رابط التحميل (تحتاج لاستضافة الصور)
    final url = 'https://your-domain.com/quran/page_${pageNumber}.webp';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    }
    
    throw Exception('فشل تحميل الصفحة $pageNumber');
  }
  
  static Future<bool> downloadSurah(int surahNumber) async {
    final pages = surahPages[surahNumber] ?? [];
    bool success = true;
    
    for (int page in pages) {
      try {
        await downloadPage(page);
      } catch (e) {
        success = false;
        print('خطأ تحميل الصفحة $page: $e');
      }
    }
    
    return success;
  }
}
```

##### 2. شاشة اختيار التحميل
```dart
// lib/screens/quran_download_screen.dart
class QuranDownloadScreen extends StatelessWidget {
  final Map<int, String> availableSurahs = {
    1: 'سورة الفاتحة',
    2: 'سورة البقرة',
    3: 'سورة آل عمران',
    36: 'سورة يس',
    67: 'سورة الملك',
    113: 'سورة الفلق',
  };
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تحميل المصحف')),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'اختر السور التي تريد تحميل صورها:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...availableSurahs.entries.map((entry) {
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(entry.value),
                subtitle: Text('${QuranDownloadService.surahPages[entry.key]?.length ?? 0} صفحة'),
                trailing: ElevatedButton(
                  onPressed: () => _downloadSurah(context, entry.key),
                  child: Text('تحميل'),
                ),
              ),
            );
          }).toList(),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'المساحة المطلوبة: حوالي 15-20 ميجابايت',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  void _downloadSurah(BuildContext context, int surahNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('جاري التحميل...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('يتم تحميل الصور، يرجى الانتظار...'),
          ],
        ),
      ),
    );
    
    bool success = await QuranDownloadService.downloadSurah(surahNumber);
    
    Navigator.pop(context);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحميل السورة بنجاح!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحميل بعض الصفحات')),
      );
    }
  }
}
```

##### 3. تحديث صفحة المصحف
```dart
// lib/pages/mushaf_viewer_page.dart (محدث)
import '../services/quran_download_service.dart';

Widget buildImageWidget(int pageNum) {
  return FutureBuilder<String>(
    future: QuranDownloadService.downloadPage(pageNum),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.file(
          File(snapshot.data!),
          width: boxWidth,
          height: boxHeight,
          fit: BoxFit.contain,
        );
      } else if (snapshot.hasError) {
        return _buildDownloadPrompt(context, pageNum);
      }
      return Center(child: CircularProgressIndicator());
    },
  );
}

Widget _buildDownloadPrompt(BuildContext context, int pageNum) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.download, size: 64, color: Colors.blue),
        SizedBox(height: 16),
        Text(
          'هذه الصفحة غير محملة بعد',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text('انقر لتحميل الصفحة'),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            try {
              await QuranDownloadService.downloadPage(pageNum);
              setState(() {}); // إعادة تحميل الواجهة
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('فشل في التحميل: $e')),
              );
            }
          },
          child: Text('تحميل الآن'),
        ),
      ],
    ),
  );
}
```

---

### 🥉 الخيار الثالث: ضغط الصور

#### تحسين الصور الموجودة:
```bash
# استخدام ImageMagick لضغط الصور
# تثبيت: https://imagemagick.org/script/download.php#windows

# إنشاء مجلد للصور المضغوطة
mkdir assets\quran_compressed

# ضغط جميع الصور إلى 70% جودة و 50% حجم
for %f in (assets\mushaf\page\*.webp) do (
    convert "%f" -quality 70 -resize 50% "assets\quran_compressed\%~nf.webp"
)

# تحديث pubspec.yaml
# - assets/quran_compressed/    (بدلاً من assets/mushaf/page/)
```

#### النتائج المتوقعة:
- حجم الصور: من 200MB إلى 60-70MB
- جودة مقبولة للقراءة
- تحميل سريع

---

### 🎯 التوصية النهائية:

#### للمبتدئين:
**استخدم الخيار الأول** - صفحات مختارة فقط
- سهل التطبيق
- حجم صغير
- تجربة ممتازة للمستخدمين

#### للمطورين المتقدمين:
**استخدم الخيار الثاني** - تحميل عند الطلب
- مرونة أكبر
- تجربة مستخدم محترفة
- قابل للتوسع

#### للحل السريع:
**استخدم الخيار الثالث** - صور مضغوطة
- أقل تعقيد
- كل الصور متاحة
- حجم معقول

---

### 🔧 أي خيار تختار؟

أخبرني بـ:
1. **أي خيار تفضل؟**
2. **هل تريد مني تطبيق الحل الآن؟**
3. **هل لديك خادم لاستضافة الصور؟**

سأقوم بتطبيق الحل الذي تختاره فوراً! 🚀