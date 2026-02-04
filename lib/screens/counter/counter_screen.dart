import 'package:athkark/ads/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/custom_app_bar.dart';

class CounterScreen extends StatefulWidget {
  final String zikr;

  const CounterScreen({super.key, required this.zikr});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int _counter = 0;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadCounter();
  }

  Future<void> _loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _counter = prefs.getInt('counter_${widget.zikr}') ?? 0);
  }

  Future<void> _saveCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter_${widget.zikr}', _counter);
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
                    color: AppColors.secondaryColor,
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

  String get _truncatedZikr {
    final words = widget.zikr.split(' ');
    if (words.length <= 2) return widget.zikr;
    return '${words.take(2).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 32), // Add top padding for close button
            children: [
              _buildCounterCard(context),
              const SizedBox(height: 24),
              _buildActionButtons(context),
              const SizedBox(height: 16),
              _buildZikrInfo(context),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: const BannerAdWidget(),
              ),
            ],
          ),
          // Close button
          Positioned(
            top: 40.h,
            right: 20.w,
            child: IconButton(
              onPressed: () {
                _saveCounter();
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.close,
                size: 32.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 150),
              child: GestureDetector(
                onTap: _incrementCounter,
                child: Container(
                  width: 200.w,
                  height: 200.w,
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
                        blurRadius: 12.r,
                        offset: Offset(0, 6.h),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$_counter',
                          style: TextStyle(
                            fontSize: 56.sp,
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                            shadows: [
                              Shadow(
                                color: Theme.of(context).colorScheme.shadow,
                                blurRadius: 8.r,
                                offset: Offset(0, 2.h),
                              )
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16.h,
                        child: Container(
                          width: 200.w,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.touch_app_rounded,
                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
                            size: 40.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اضغط للعد',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
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

  Widget _buildZikrInfo(BuildContext context) {
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
              widget.zikr,
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
