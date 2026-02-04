# سكريبت ضغط صور المصحف - ImageMagick

## الخطوات:

### 1. تثبيت ImageMagick
```bash
# تحميل من: https://imagemagick.org/script/download.php#windows
# تثبيت على Windows
```

### 2. تشغيل السكريبت
```batch
@echo off
echo بدء ضغط صور المصحف...

REM إنشاء مجلد الصور المضغوطة
if not exist "assets\quran_compressed" mkdir "assets\quran_compressed"

REM ضغط جميع الصور
echo ضغط الصور...
for %%f in (assets\mushaf\page\*.webp) do (
    echo ضغط %%f
    magick "%%f" -quality 70 -resize 50% "assets\quran_compressed\%%~nxf"
)

echo تم ضغط جميع الصور بنجاح!
echo المجلد الجديد: assets\quran_compressed
pause
```

### 3. تشغيل الأمر
```bash
# في terminal VS Code
compress_quran_images.bat
```

### 4. التحقق من النتائج
```bash
# فحص أحجام الملفات
dir assets\quran_compressed /s
dir assets\mushaf\page /s
```

---

## النتائج المتوقعة:

| القياس | قبل الضغط | بعد الضغط | التحسن |
|---------|-----------|-----------|--------|
| حجم كل صورة | ~600 KB | ~150 KB | 75% تقليل |
| إجمالي الصفحات | 300+ | 300+ | جميع الصفحات |
| الحجم الإجمالي | ~200 MB | ~50-60 MB | 70% تقليل |

---

## البديل بدون ImageMagick:

إذا لم تتمكن من تثبيت ImageMagick، يمكنك استخدام أدوات أخرى:

### 1. TinyPNG (أونلاين)
- زر: https://tinypng.com/
- رفع المجلد كاملاً
- تحميل الصور المضغوطة

### 2. Paint.NET مع إضافة WebP
- تحميل إضافة WebP
- تحويل الصور يدوياً

### 3. IrfanView
- تحميل وتثبيت
- ضغط جماعي للصور

---

**ملاحظة**: السكريبت أعلاه هو الأسرع والأكثر فعالية للمشروع.