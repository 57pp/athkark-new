import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class CustomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double iconSize;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool showShadow;
  final bool reverseOrder;
  final double fontSize;

  const CustomButton({
    super.key,
    required this.icon,
    required this.label,
    required this.fontSize,
    this.color,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.iconSize = 28,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
    this.showShadow = true,
    this.reverseOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.primaryColor;
    final disabledColor = buttonColor.withValues(alpha: 0.5);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled && !isLoading ? 1.0 : 0.6,
      child: ElevatedButton(
        onPressed: (isEnabled && !isLoading) ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: theme.colorScheme.onPrimary,
          disabledBackgroundColor: disabledColor,
          padding: EdgeInsets.symmetric(
            horizontal: padding.horizontal.w,
            vertical: padding.vertical.h,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius.r),
          ),
          elevation: showShadow ? 4.r : 0,
          shadowColor: showShadow ? Theme.of(context).colorScheme.shadow : Colors.transparent,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.pressed)
                ? theme.colorScheme.onPrimary.withValues(alpha: 0.1)
                : null,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildButtonContent(theme),
        ),
      ),
    );
  }

  List<Widget> _buildButtonContent(ThemeData theme) {
    final content = [
      _buildIconOrLoader(theme),
      SizedBox(width: 8.w),
      _buildLabelText(theme),
    ];

    return reverseOrder ? content.reversed.toList() : content;
  }

  Widget _buildIconOrLoader(ThemeData theme) {
    return isLoading
        ? SizedBox(
            width: iconSize.w,
            height: iconSize.w,
            child: CircularProgressIndicator(
              color: theme.colorScheme.onPrimary,
              strokeWidth: 2.w,
            ),
          )
        : Icon(
            icon,
            size: iconSize.w,
            color: theme.colorScheme.onPrimary,
          );
  }

  Widget _buildLabelText(ThemeData theme) {
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
        fontSize: fontSize.sp,
      ),
    );
  }
}