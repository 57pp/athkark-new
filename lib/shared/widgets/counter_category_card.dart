import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/colors.dart' show AppColors;

class CategoryCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isDeletable;
  final bool isPinned;

  const CategoryCard({
    required this.title,
    required this.onTap,
    this.onDelete,
    this.isDeletable = false,
    this.isPinned = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160.w,
      height: 130.h,
      child: Stack(
        children: [
          // Card Background
          Positioned.fill(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(15.r),
              child: Container(
                margin: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.r),
                  gradient: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.primaryGradientDark
                      : AppColors.primaryGradientLight,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow,
                      blurRadius: 6.r,
                      offset: Offset(0, 3.h),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),

          // Top-right Icons
          Positioned(
            top: 4.h,
            right: 4.w,
            child: Row(
              children: [
                if (isPinned)
                  Icon(
                    Icons.push_pin,
                    color: Theme.of(context).colorScheme.tertiary,
                    size: 18.sp,
                  ),
                if (isDeletable)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                      size: 20.sp,
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}