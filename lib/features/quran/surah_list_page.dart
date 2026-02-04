import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../pages/mushaf_viewer_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../ads/ad_manager.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import '../../shared/widgets/custom_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';

class SurahListPage extends StatefulWidget {
  const SurahListPage({super.key});

  @override
  State<SurahListPage> createState() => _SurahListPageState();
}

class _SurahListPageState extends State<SurahListPage> with TickerProviderStateMixin {
  static const int _assetPageOffset = 3;

  List<Map<String, dynamic>> surahs = [];
  List<Map<String, dynamic>> filteredSurahs = [];
  TextEditingController searchController = TextEditingController();
  String selectedType = 'الكل'; // الكل, مكية, مدنية
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    loadSurahs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadSurahs() async {
    try {
      setState(() => isLoading = true);

      final List<dynamic> rawSurahData = jsonDecode(
        await rootBundle.loadString('assets/source/surah.json'),
      );

      final List<Map<String, dynamic>> mappedSurahs = rawSurahData.map((surah) {
        final pageNumber = int.tryParse(surah['pages']?.toString() ?? '1') ?? 1;
        final int assetPage = pageNumber + _assetPageOffset;
        return {
          'name_ar': surah['titleAr'] ?? '',
          'name_en': surah['title'] ?? '',
          'place': surah['place'] ?? '',
          'type': surah['type'] ?? '',
          'count': surah['count'] ?? 0,
          'printed_page': pageNumber,
          'asset_page': assetPage,
          'index': surah['index'] ?? '',
        };
      }).toList();

      mappedSurahs.sort(
        (a, b) => (a['printed_page'] as int).compareTo(b['printed_page'] as int),
      );

      setState(() {
        surahs = mappedSurahs;
        filteredSurahs = mappedSurahs;
        isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات السور: $e')),
        );
      }
    }
  }

  void filterSurahs(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    setState(() {
      filteredSurahs = surahs.where((surah) {
        // Filter by search query
        final nameAr = surah['name_ar']?.toString().toLowerCase() ?? '';
        final nameEn = surah['name_en']?.toString().toLowerCase() ?? '';
        final matchesQuery = normalizedQuery.isEmpty ||
            nameAr.contains(normalizedQuery) ||
            nameEn.contains(normalizedQuery);

        // Filter by type
        final type = surah['type'] ?? '';
        final matchesType = selectedType == 'الكل' ||
            (selectedType == 'مكية' && type == 'Makkiyah') ||
            (selectedType == 'مدنية' && type == 'Madaniyah');

        return matchesQuery && matchesType;
      }).toList();
    });
  }

  void changeTypeFilter(String type) {
    setState(() => selectedType = type);
    filterSurahs(searchController.text);
  }

  Color getTypeColor(String type) {
    return type == 'Makkiyah' ? Colors.green : Colors.blue;
  }

  String getTypeText(String type) {
    return type == 'Makkiyah' ? 'مكية' : 'مدنية';
  }

  Map<String, int> getStatistics() {
    final makkiyah = surahs.where((s) => s['type'] == 'Makkiyah').length;
    final madaniyah = surahs.where((s) => s['type'] == 'Madaniyah').length;
    final totalVerses = surahs.fold<int>(0, (sum, s) => sum + (s['count'] as int? ?? 0));
    return {
      'makkiyah': makkiyah,
      'madaniyah': madaniyah,
      'totalVerses': totalVerses,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'القرآن الكريم',
          showBackButton: false,
          useBottomNavBarStyle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? AppColors.backgroundGradientDark
                : AppColors.backgroundGradientLight,
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Statistics Card
                      _buildStatisticsCard(),

                      // Search and Filter Section
                      _buildSearchAndFilterSection(),

                      // Surah List
                      Expanded(
                        child: filteredSurahs.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                itemCount: filteredSurahs.length + (filteredSurahs.length ~/ 10),
                                itemBuilder: (context, index) {
                                  if (index % 11 == 10) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.h),
                                      child: const BannerAdWidget(),
                                    );
                                  }

                                  final surahIndex = index - (index ~/ 11);
                                  if (surahIndex >= filteredSurahs.length) return const SizedBox.shrink();

                                  return _buildSurahCard(filteredSurahs[surahIndex], surahIndex);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = getStatistics();
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.8),
            AppColors.secondaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${stats['makkiyah']}', 'مكية', Colors.green),
          _buildStatItem('${stats['madaniyah']}', 'مدنية', Colors.blue),
          _buildStatItem('${stats['totalVerses']}', 'آية', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.amiri(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(15.r),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'البحث في السور...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16.sp,
                ),
                prefixIcon: Icon(Icons.search, color: AppColors.primaryColor, size: 24.sp),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
              ),
              onChanged: filterSurahs,
            ),
          ),

          SizedBox(height: 12.h),

          // Filter Buttons
          Row(
            children: [
              _buildFilterButton('الكل', selectedType == 'الكل'),
              SizedBox(width: 8.w),
              _buildFilterButton('مكية', selectedType == 'مكية'),
              SizedBox(width: 8.w),
              _buildFilterButton('مدنية', selectedType == 'مدنية'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => changeTypeFilter(label),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryColor : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected ? AppColors.primaryColor : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurahCard(Map<String, dynamic> surah, int index) {
    final nameAr = surah['name_ar'] ?? 'غير محدد';
    final nameEn = surah['name_en'] ?? '';
    final type = surah['type'] ?? '';
    final count = surah['count'] ?? 0;
    final printedPage = surah['printed_page'] ?? 1;
    final assetPage = surah['asset_page'] ?? printedPage;
    final typeColor = getTypeColor(type);
    final typeText = getTypeText(type);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: typeColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MushafViewerPage(
                  surahName: nameAr,
                  startPage: assetPage,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Surah Number
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [typeColor, typeColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 16.w),

                // Surah Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Arabic Name
                      Text(
                        nameAr,
                        style: GoogleFonts.amiri(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                          height: 1.2,
                        ),
                      ),

                      SizedBox(height: 4.h),

                      // English Name
                      Text(
                        nameEn,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 8.h),

                      // Details Row
                      Row(
                        children: [
                          // Type Badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: typeColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              typeText,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: typeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          SizedBox(width: 12.w),

                          // Verse Count
                          Row(
                            children: [
                              Icon(
                                Icons.format_list_numbered,
                                size: 16.sp,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '$count آية',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(width: 12.w),

                          // Page Number
                          Row(
                            children: [
                              Icon(
                                Icons.book,
                                size: 16.sp,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'ص $printedPage',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.primaryColor.withOpacity(0.7),
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد سور تطابق البحث',
            style: TextStyle(
              fontSize: 18.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'جرب تغيير كلمات البحث أو الفلتر',
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
