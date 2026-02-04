import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/dhikrs.dart';
import 'athkar_detail_screen.dart';
import '../../models/category.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import '../../ads/ad_manager.dart';
import '../../shared/widgets/custom_app_bar.dart';

class CategoryScreen extends StatelessWidget {
  final Category category;
  const CategoryScreen({super.key, required this.category});

  String _getTruncatedDhikr(Dhikr dhikr) {
    final words = dhikr.text.split(' ');
    if (words.length <= 2) return dhikr.text;
    return '${words.take(2).join(' ')}...';
  }

  String _getTruncatedCategory() {
    final words = category.category.split(' ');
    if (words.length <= 2) return category.category;
    return '${words.take(2).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: CustomAppBar(
          title: _getTruncatedCategory(),
          useBottomNavBarStyle: true,
          actions: [
            Padding(
              padding: EdgeInsets.only(left: 16.w),
              child: Icon(
                category.icon,
                size: 28.sp,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? AppColors.backgroundGradientDark
                : AppColors.backgroundGradientLight,
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: category.dhikrs.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) =>
                        _buildPrayerTile(context, category.dhikrs[index], index),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: const BannerAdWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTile(BuildContext context, Dhikr dhikr, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () => _navigateToDetail(context, index),
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                Container(
                  width: 60.r,
                  height: 60.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.primary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
                        blurRadius: 6.r,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp,
                    ),
                  ),
                ),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTruncatedDhikr(dhikr),
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.sp,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 16.sp,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'انقر للقراءة',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, int index) {
    AdManager.showInterstitialAd(
      onAdDismissed: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              DhikrDetailScreen(dhikrs: category.dhikrs, initialIndex: index, categoryName: category.category),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
      ),
      onAdFailed: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              DhikrDetailScreen(dhikrs: category.dhikrs, initialIndex: index, categoryName: category.category),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
      ),
    );
  }
}
