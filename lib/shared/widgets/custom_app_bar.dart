import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double elevation;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final bool useBottomNavBarStyle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
    this.elevation = 0,
    this.backgroundColor,
    this.backgroundGradient,
    this.useBottomNavBarStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (useBottomNavBarStyle) {
      return Container(
        decoration: BoxDecoration(
          gradient: backgroundGradient ??
              (theme.brightness == Brightness.dark
                  ? AppColors.primaryGradientDark
                  : AppColors.primaryGradientLight),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Row(
              children: [
                if (showBackButton)
                  leading ??
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 28.sp,
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                        tooltip: 'رجوع',
                      ),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.headline.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (actions != null) ...actions!,
                if (actions == null && showBackButton)
                  SizedBox(width: 48.w), // Balance the leading button
              ],
            ),
          ),
        ),
      );
    }

    return AppBar(
      title: Text(
        title,
        style: AppTextStyles.headline.copyWith(
          color: theme.colorScheme.onPrimary,
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor ?? Colors.transparent,
      flexibleSpace: backgroundGradient != null
          ? Container(
              decoration: BoxDecoration(
                gradient: backgroundGradient ??
                    (theme.brightness == Brightness.dark
                        ? AppColors.primaryGradientDark
                        : AppColors.primaryGradientLight),
              ),
            )
          : null,
      elevation: elevation,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
      iconTheme: IconThemeData(
        color: theme.colorScheme.onPrimary,
        size: 28.sp,
      ),
      leading: showBackButton
          ? (leading ??
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 28.sp,
                  color: theme.colorScheme.onPrimary,
                ),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                tooltip: 'رجوع',
              ))
          : null,
      actions: actions,
      centerTitle: true,
      toolbarHeight: 60.h,
    );
  }

  @override
  Size get preferredSize => useBottomNavBarStyle ? Size.fromHeight(80.h) : Size.fromHeight(60.h);
}