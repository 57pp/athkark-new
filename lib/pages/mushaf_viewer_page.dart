import 'package:flutter/material.dart';
import 'package:athkark/core/theme/colors.dart' show AppColors, AppTextStyles;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../shared/widgets/custom_app_bar.dart';

class MushafViewerPage extends StatefulWidget {
  final String surahName;
  final int startPage;

  static const int _maxAvailablePage = 640;

  const MushafViewerPage({
    super.key,
    required this.surahName,
    required this.startPage,
  });

  @override
  State<MushafViewerPage> createState() => _MushafViewerPageState();
}

class _MushafViewerPageState extends State<MushafViewerPage> {
  late PageController _pageController;
  late int _startPage;
  late FlutterTts _flutterTts;
  Map<String, dynamic>? _surahData;
  List<Map<String, dynamic>> _allSurahs = [];
  String _currentSurahName = '';
  static const int _assetPageOffset = 3;

  @override
  void initState() {
    super.initState();
    _startPage = widget.startPage;
    if (_startPage < 1) {
      _startPage = 1;
    } else if (_startPage > MushafViewerPage._maxAvailablePage) {
      _startPage = MushafViewerPage._maxAvailablePage;
    }
    _pageController = PageController(initialPage: 0);
    _flutterTts = FlutterTts();
    _loadSurahData();
    _loadAllSurahs();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadSurahData() async {
    try {
      // Extract surah index from the name or find it from the list
      // For simplicity, assume the surah name contains the index or we need to map it
      // Since the surah_list_page passes the name, we need to find the corresponding index
      final surahList = jsonDecode(await rootBundle.loadString('assets/source/surah.json')) as List;
      final surah = surahList.firstWhere(
        (s) => s['titleAr'] == widget.surahName,
        orElse: () => null,
      );
      if (surah != null) {
        final index = int.parse(surah['index'].toString());
        final surahData = jsonDecode(await rootBundle.loadString('assets/source/surah/surah_$index.json'));
        setState(() {
          _surahData = surahData;
        });
      }
    } catch (e) {
      debugPrint('Error loading surah data: $e');
    }
  }

  Future<void> _speakSurahName() async {
    if (_surahData != null) {
      final name = _surahData!['name'] ?? _currentSurahName;
      await _flutterTts.setLanguage("ar-SA"); // Set to Arabic
      await _flutterTts.speak(name);
    }
  }

  Future<void> _loadAllSurahs() async {
    final surahList = jsonDecode(await rootBundle.loadString('assets/source/surah.json')) as List;
    final mappedSurahs = surahList.map((surah) {
      final pageNumber = int.tryParse(surah['pages']?.toString() ?? '1') ?? 1;
      final int assetPage = pageNumber + _assetPageOffset;
      return {
        'name_ar': surah['titleAr'] ?? '',
        'asset_start': assetPage,
      };
    }).toList();
    mappedSurahs.sort((a, b) => (a['asset_start'] as int).compareTo(b['asset_start'] as int));
    setState(() {
      _allSurahs = mappedSurahs;
      _currentSurahName = widget.surahName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _currentSurahName,
        showBackButton: true,
        useBottomNavBarStyle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradientDark
              : AppColors.backgroundGradientLight,
        ),
        child: PageView.builder(
          controller: _pageController,
          reverse: false, // Normal direction
          itemCount: MushafViewerPage._maxAvailablePage - _startPage + 1,
          onPageChanged: (index) {
            final pageNum = _startPage + index;
            // Find the current Surah for this page
            String currentSurah = _currentSurahName;
            for (var surah in _allSurahs) {
              if (pageNum >= surah['asset_start']) {
                currentSurah = surah['name_ar'];
              } else {
                break;
              }
            }
            setState(() {
              _currentSurahName = currentSurah;
            });
            _speakSurahName();
          },
          itemBuilder: (context, index) {
            final pageNum = _startPage + index;
            return LayoutBuilder(
              builder: (context, constraints) {
                final boxWidth = constraints.maxWidth;
                final boxHeight = constraints.maxHeight;
                final isDark = Theme.of(context).brightness == Brightness.dark;

                // Keep the page inside a framed container so it never overflows the viewport.
                return Container(
                  width: boxWidth,
                  height: boxHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Transform.scale(
                      scaleX: 1,
                      child: Image.asset(
                        'assets/quran_compressed/MushafMadinaHafsGreen1441-$pageNum.webp',
                        width: boxWidth,
                        height: boxHeight,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.construction,
                                  size: 64,
                                  color: Colors.orange,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'صفحة $pageNum غير متوفرة',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'قم بتشغيل سكريبت ضغط الصور أولاً',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('العودة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
