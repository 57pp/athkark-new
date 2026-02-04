import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../shared/utils/data_provider.dart';
import '../../models/category.dart';
import '../../screens/adhkar/category_screen.dart';
import '../../shared/widgets/adhkar_category_card.dart';
import '../../shared/widgets/adhkar_search_delegate.dart';
import '../../shared/widgets/adhan_button.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import '../../ads/ad_manager_improved.dart';
import '../../screens/adhkar/athkar_detail_screen.dart';
import '../../shared/widgets/custom_app_bar.dart';

class AdhkarScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const AdhkarScreen({super.key, required this.toggleTheme});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late Future<List<Category>> _categoriesFuture;
  final DataProvider _dataProvider = DataProvider();
  List<Category> categories = [];
  List<Category> filteredCategories = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadInterstitialAd();
  }

  // تهيئة البيانات مع استخدام setState لضمان تحديث الواجهة
  void _initializeData() async {
    setState(() {
      _categoriesFuture = _dataProvider.getCategories();
    });

    final loadedCategories = await _categoriesFuture;
    setState(() {
      categories = loadedCategories;
      filteredCategories = loadedCategories;
    });
  }

  // تحميل إعلان الانتروستيشال
  void _loadInterstitialAd() {
    EnhancedAdManager.loadInterstitialAd(
      onAdLoaded: () => debugPrint('Interstitial ad loaded'),
      onAdFailed: () => debugPrint('Failed to load interstitial ad'),
    );
  }

  Future<void> _togglePinCategory(Category category) async {
    setState(() => category.isPinned = !category.isPinned);
    await _dataProvider.togglePinCategory(category.id, category.isPinned);
    _filterCategories(searchController.text);
  }

  void _filterCategories(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    setState(() {
      if (normalizedQuery.isEmpty) {
        filteredCategories = categories;
      } else {
        filteredCategories = categories.where((category) {
          final categoryName = category.category.toLowerCase();
          return categoryName.contains(normalizedQuery);
        }).toList();
      }
    });
  }

  List<Category> _sortCategories(List<Category> categories) {
    final sortedList = List<Category>.from(categories);
    sortedList.sort((a, b) {
      final aPinned = a.isPinned ? 1 : 0;
      final bPinned = b.isPinned ? 1 : 0;
      return bPinned.compareTo(aPinned);
    });
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildAdIntegratedBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      title: 'الأذكار',
      showBackButton: false,
      useBottomNavBarStyle: true,
    );
  }


  // دمج المحتوى الرئيسي مع إعلان البانر في عمود عمودي
  Widget _buildAdIntegratedBody() {
    return Column(
      children: [
        // حقل البحث في الأعلى
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Container(
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
                hintText: 'البحث في الأذكار...',
                hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.primaryColor),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
              ),
              onChanged: _filterCategories,
            ),
          ),
        ),
        Expanded(child: _buildMainContent()),
        // إعلان البانر مع خلفية شفافة
        EnhancedAdManager.getBannerWidget(
          screenId: 'adhkar_screen',
          onAdLoaded: () => debugPrint('Banner ad loaded on adhkar screen'),
          fallbackWidget: const SizedBox(height: 50, child: Center(child: Text(''))),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundGradientDark
            : AppColors.backgroundGradientLight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: RefreshIndicator(
          onRefresh: () async => _initializeData(),
          color: AppColors.secondaryColor,
          child: categories.isEmpty
              ? _buildLoadingIndicator()
              : _buildAdhkarContent(_sortCategories(filteredCategories)),
        ),
      ),
    );
  }

  Widget _buildAdhkarContent(List<Category> categories) {
    // Find featured categories (morning and evening)
    final morningCategory = categories.firstWhere(
      (cat) => cat.id == 1,
      orElse: () => categories.isNotEmpty
          ? categories[0]
          : Category(id: 0, category: '', audio: '', filename: '', dhikrs: []),
    );
    final eveningCategory = categories.firstWhere(
      (cat) => cat.id == 2,
      orElse: () => categories.length > 1
          ? categories[1]
          : Category(id: 0, category: '', audio: '', filename: '', dhikrs: []),
    );

    final otherCategories =
        categories.where((cat) => cat.id != 1 && cat.id != 2).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Featured Adhkar section like location section in prayer times
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الأذكار اليومية',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (morningCategory.id != 0)
                  AdhanButton(
                    title: 'أذكار الصباح',
                    subtitle: 'ابدأ يومك بالأذكار',
                    icon: Icons.wb_sunny,
                    gradientColors: [AppColors.primary, AppColors.tertiary],
                    size: AdhanButtonSize.medium,
                    onPressed: () =>
                        _handleCategoryTap(context, morningCategory),
                  ),
                if (eveningCategory.id != 0) ...[
                  const SizedBox(height: 16),
                  AdhanButton(
                    title: 'أذكار المساء',
                    subtitle: 'أنهِ يومك بالأذكار',
                    icon: Icons.nights_stay,
                    gradientColors: [AppColors.primary, AppColors.tertiary],
                    size: AdhanButtonSize.medium,
                    onPressed: () =>
                        _handleCategoryTap(context, eveningCategory),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Other categories in list like prayer times page
        if (otherCategories.isNotEmpty) ...[
          Text(
            'الأذكار الأخرى',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherCategories.length,
            itemBuilder: (context, index) {
              final category = otherCategories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  title: Text(
                    category.category,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: Text(
                    '${category.dhikrs.length} ذكر',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          category.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: category.isPinned
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                        ),
                        onPressed: () => _togglePinCategory(category),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    ],
                  ),
                  onTap: () => _handleCategoryTap(context, category),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _handleCategoryTap(BuildContext context, Category category) {
    EnhancedAdManager.showInterstitialAd(
      onAdDismissed: () => _navigateToCategory(context, category),
      onAdFailed: () => _navigateToCategory(context, category),
    );
  }

  void _navigateToCategory(BuildContext context, Category category) {
    // If category has only one dhikr, navigate directly to detail screen
    if (category.dhikrs.length == 1) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => DhikrDetailScreen(
            dhikrs: category.dhikrs,
            initialIndex: 0,
            categoryName: category.category,
          ),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      ).then((_) => _loadInterstitialAd());
    } else {
      // Navigate to category screen for multiple dhikrs
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => CategoryScreen(category: category),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      ).then((_) => _loadInterstitialAd());
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.secondaryColor,
            strokeWidth: 3.w,
          ),
          SizedBox(height: 16.h),
          Text(
            'جاري تحميل الأذكار...',
            style: AppTextStyles.body.copyWith(fontSize: 16.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline,
                size: 60.sp, color: Theme.of(context).colorScheme.error),
          ),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ أثناء تحميل البيانات',
            style:
                AppTextStyles.body.copyWith(fontSize: 18.sp, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _initializeData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.inbox, size: 60.sp, color: AppColors.secondaryColor),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد أذكار متاحة حالياً',
            style: AppTextStyles.body.copyWith(fontSize: 18.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'تحقق من الاتصال بالإنترنت أو انتظر التحديثات',
            style: AppTextStyles.body
                .copyWith(fontSize: 14.sp, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
