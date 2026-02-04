import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import '../../models/category.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const CategoryCard({
    required this.category,
    required this.onTap,
    required this.onTogglePin,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6.w,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: onTap,
        splashColor: Theme.of(context).colorScheme.surface.withOpacity(0.2),
        highlightColor: Theme.of(context).colorScheme.surface.withOpacity(0.1),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: 140.h,
            maxHeight: 160.h,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: Theme.of(context).brightness == Brightness.dark
                ? AppColors.primaryGradientDark
                : AppColors.primaryGradientLight,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                blurRadius: 6.w,
                offset: Offset(0, 3.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  iconSize: 20.w,
                  icon: Icon(
                    category.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  onPressed: onTogglePin,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.icon,
                      size: 25.sp,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      category.category,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  'عدد الأذكار: ${category.dhikrs.length}',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                    fontSize: 10.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}