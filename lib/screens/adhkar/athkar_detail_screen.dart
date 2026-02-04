import 'package:athkark/ads/ad_manager.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart' as theme_colors;
import '../../models/dhikrs.dart';

// Full screen dhikr view page
class FullDhikrViewPage extends StatelessWidget {
  final Dhikr dhikr;
  final String categoryName;

  const FullDhikrViewPage({
    super.key,
    required this.dhikr,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            categoryName,
            style: theme_colors.AppTextStyles.headline.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? theme_colors.AppColors.primaryGradientDark
                  : theme_colors.AppColors.primaryGradientLight,
            ),
          ),
        ),
        body: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? theme_colors.AppColors.backgroundGradientDark
                : theme_colors.AppColors.backgroundGradientLight,
          ),
          child: Column(
            children: [
              // Logo section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60.r,
                    height: 60.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 48.r,
                      height: 48.r,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.mosque,
                        size: 36.sp,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'تطبيق أذكارك',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              // Category name
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  categoryName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // Full prayer text
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.r),
                    color: theme.cardColor,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      dhikr.text,
                      textAlign: TextAlign.justify,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 20.sp,
                        height: 2.0,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DhikrDetailScreen extends StatefulWidget {
  final List<Dhikr> dhikrs;
  final int initialIndex;
  final String categoryName;

  const DhikrDetailScreen({
    super.key,
    required this.dhikrs,
    required this.initialIndex,
    required this.categoryName,
  });

  @override
  State<DhikrDetailScreen> createState() => _DhikrDetailScreenState();
}

class _DhikrDetailScreenState extends State<DhikrDetailScreen>
    with WidgetsBindingObserver {
  late int _currentIndex;
  final ScreenshotController _screenshotController = ScreenshotController();
  int _counter = 0;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _loadCounter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _goToNextDhikr() async {
    if (_currentIndex < widget.dhikrs.length - 1) {
      await _changeDhikr(_currentIndex + 1);
    } else {
      _showInfoSnackbar('هذا آخر دعاء في القائمة');
    }
  }

  void _goToPreviousDhikr() async {
    if (_currentIndex > 0) {
      await _changeDhikr(_currentIndex - 1);
    } else {
      _showInfoSnackbar('هذا أول دعاء في القائمة');
    }
  }

  Future<void> _changeDhikr(int newIndex) async {
    if (mounted) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  Future<void> _shareDhikr() async {
    try {
      // Show loading message for high quality capture
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري تحضير صورة عالية الجودة للمشاركة...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Wait a bit more for any animations to complete
      await Future.delayed(const Duration(milliseconds: 300));

      final theme = Theme.of(context);
      final width = MediaQuery.of(context).size.width;
      final image = await _screenshotController.captureFromWidget(
        _buildShareCaptureWidget(theme, widget.dhikrs[_currentIndex], width),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 4.0,
      );
      
      if (image != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/dhikr_${widget.dhikrs[_currentIndex].id}_hd.png');
        await file.writeAsBytes(image);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحضير الصورة بجودة عالية - جاهز للمشاركة'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        await Share.shareXFiles([XFile(file.path)]);
      } else {
        // Fallback to text share if image capture fails
        Share.share(
          widget.dhikrs[_currentIndex].text,
          subject: _truncatedCategory,
        );
      }
    } catch (e) {
      // Fallback to text share
      Share.share(
        widget.dhikrs[_currentIndex].text,
        subject: _truncatedCategory,
      );
    }
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final currentDhikr = widget.dhikrs[_currentIndex];
    setState(() => _counter = prefs.getInt('counter_${currentDhikr.id}') ?? 0);
  }

  Future<void> _saveCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final currentDhikr = widget.dhikrs[_currentIndex];
    await prefs.setInt('counter_${currentDhikr.id}', _counter);
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
      _scale = 1.2;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _scale = 1.0);
    });
    _saveCounter();
  }

  void _resetCounter() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor,
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تأكيد الإعادة',
                style: TextStyle(
                  fontSize: 22.sp,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'هل تريد إعادة العداد إلى الصفر؟',
                style: TextStyle(
                  fontSize: 18.sp,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 32.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DialogButton(
                    text: 'إلغاء',
                    color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                    onPressed: () => Navigator.pop(context),
                  ),
                  _DialogButton(
                    text: 'تأكيد',
                    color: theme_colors.AppColors.secondaryColor,
                    onPressed: () {
                      setState(() => _counter = 0);
                      _saveCounter();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _truncatedCategory {
    final words = widget.categoryName.split(' ');
    if (words.length <= 2) return widget.categoryName;
    return '${words.take(2).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    final currentDhikr = widget.dhikrs[_currentIndex];
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? theme_colors.AppColors.backgroundGradientDark
                : theme_colors.AppColors.backgroundGradientLight,
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: const BannerAdWidget(),
                    ),
                    Expanded(
                      child: Screenshot(
                        controller: _screenshotController,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5, // Limit to 50% of screen for display
                      child: _buildShareableContent(theme, currentDhikr),
                    ),
                  ),
                ),
                    SizedBox(height: 20.h),
                    _buildNavigationButtons(theme),
                  ],
                ),
              ),
              // Close button
              Positioned(
                top: 40.h,
                right: 20.w,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    size: 32.sp,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareableContent(ThemeData theme, Dhikr currentDhikr,
      {bool forCapture = false}) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: theme.cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo, app name, and share button at the top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo and app name on the left
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.r,
                    height: 40.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 32.r,
                      height: 32.r,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.mosque,
                        size: 24.sp,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'تطبيق أذكارك',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              // Share button on the right
              IconButton(
                onPressed: () {
                  // Show message when sharing
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('مشاركة الدعاء كصورة'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  // Then share the dhikr
                  _shareDhikr();
                },
                icon: Icon(Icons.share, size: 20.sp, color: Theme.of(context).colorScheme.primary),
                padding: EdgeInsets.all(8.r),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // Category name
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              widget.categoryName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Prayer text - Restricted within card with tap to expand
          GestureDetector(
            onTap: () {
              // Navigate to full screen view
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullDhikrViewPage(
                    dhikr: currentDhikr,
                    categoryName: widget.categoryName,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Container(
                  constraints: forCapture
                      ? null
                      : BoxConstraints(
                          maxHeight: 150.h, // Reduced height for card display
                        ),
                  child: Text(
                    currentDhikr.text,
                    textAlign: TextAlign.justify,
                    overflow: forCapture ? TextOverflow.visible : TextOverflow.ellipsis,
                    maxLines: forCapture ? null : 6,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16.sp,
                      height: 1.6,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                if (!forCapture && currentDhikr.text.length > 150) ...[
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.expand_more,
                        size: 14.sp,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'اضغط للعرض الكامل',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.sp,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.expand_more,
                        size: 14.sp,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCaptureWidget(ThemeData theme, Dhikr dhikr, double width) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: width,
              maxWidth: width,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildShareableContent(theme, dhikr, forCapture: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.touch_app, color: Theme.of(context).colorScheme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'العداد',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 150),
            child: GestureDetector(
              onTap: _incrementCounter,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow,
                      blurRadius: 8.r,
                      offset: Offset(0, 4.h),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_counter',
                    style: TextStyle(
                      fontSize: 32.sp,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                      shadows: [
                        Shadow(
                          color: Theme.of(context).colorScheme.shadow,
                          blurRadius: 4.r,
                          offset: Offset(0, 1.h),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _incrementCounter,
                icon: Icon(Icons.add_circle, size: 28.sp),
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'زيادة',
              ),
              SizedBox(width: 16.w),
              IconButton(
                onPressed: _resetCounter,
                icon: Icon(Icons.refresh, size: 28.sp),
                color: Theme.of(context).colorScheme.error,
                tooltip: 'إعادة',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإجراءات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _incrementCounter,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('زيادة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetCounter,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('إعادة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDhikrInfo(BuildContext context, Dhikr currentDhikr) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24.sp,
                ),
                const SizedBox(width: 12),
                Text(
                  'الذكر',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              currentDhikr.text,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20.sp,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'العدد الحالي: $_counter',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: theme.colorScheme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'التنقل بين الأذكار',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _goToPreviousDhikr,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('السابق'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _goToNextDhikr,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('التالي'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12.r),
      elevation: 4.r,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.12),
                blurRadius: 6.r,
                offset: Offset(0, 3.h),
              )
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16.sp,
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
