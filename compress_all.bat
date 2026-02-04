@echo off
echo بدء ضغط صور المصحف...

REM إنشاء مجلد الصور المضغوطة
if not exist "assets\quran_compressed" mkdir "assets\quran_compressed"

REM ضغط جميع الصور
echo ضغط الصور...
for %%f in (assets\mushaf\page\*.webp) do (
    echo ضغط %%f
    magick "%%f" -quality 70 -resize 50% "assets\quran_compressed\%%~nf.webp"
)

echo تم ضغط جميع الصور بنجاح!
echo المجلد الجديد: assets\quran_compressed
pause