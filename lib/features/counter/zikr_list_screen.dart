import 'package:athkark/ads/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/counter_category_card.dart';
import '../../shared/widgets/adhan_button.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import '../../main.dart';
import '../../screens/counter/counter_screen.dart';
import '../../shared/widgets/custom_app_bar.dart';

class ZikrListScreen extends StatefulWidget {
  const ZikrListScreen({super.key});

  @override
  State<ZikrListScreen> createState() => _ZikrListScreenState();
}

class _ZikrListScreenState extends State<ZikrListScreen> {
  final List<String> _defaultAzkar = [
    'ربي إني لما أنزلت إليّ من خيرٍ فقير',
    'سبحان الله',
    'الحمد لله',
    'الله أكبر',
    'سبحان الله وبحمده',
    'سبحان الله العظيم',
    'لا حول ولا قوة إلا بالله',
    'استغفر الله',
    'لا إله إلا الله',
  ];
  late final List<String> _azkar = [..._defaultAzkar];

  @override
  void initState() {
    super.initState();
    _loadSavedAzkar();
  }

  Future<void> _loadSavedAzkar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _azkar.addAll(prefs.getStringList('azkar') ?? []);
    });
  }

  Future<void> _saveAzkar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('azkar', _azkar.sublist(_defaultAzkar.length));
  }

  Future<void> _addZikr(String zikr) async {
    if (zikr.isEmpty) return;
    setState(() => _azkar.add(zikr));
    await _saveAzkar();
  }

  Future<void> _deleteZikr(int index) async {
    if (index < _defaultAzkar.length) return;
    setState(() => _azkar.removeAt(index));
    await _saveAzkar();
  }


  void _showAddZikrDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
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
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إضافة ذكر جديد',
                style: AppTextStyles.title.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20.sp,
                  shadows: [
                    Shadow(
                      blurRadius: 4.r,
                      color: Theme.of(context).colorScheme.shadow,
                    )
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              TextField(
                controller: controller,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16.sp,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surface.withOpacity(0.2),
                  hintText: 'أدخل الذكر هنا',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DialogButton(
                    text: 'إلغاء',
                    color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                    onPressed: () => Navigator.pop(context),
                  ),
                  _DialogButton(
                    text: 'إضافة',
                    color: AppColors.secondaryColor,
                    onPressed: () {
                      _addZikr(controller.text.trim());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'السبحة',
        showBackButton: false,
        useBottomNavBarStyle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.backgroundGradientDark
                    : AppColors.backgroundGradientLight,
              ),
              child: _azkar.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64.sp,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'لا توجد أذكار مضافة',
                            style: AppTextStyles.body.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontSize: 18.sp,
                            ),
                          ),
                          const BannerAdWidget(),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Other azkar in list like prayer times page
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.all(16.r),
                            itemCount: _azkar.length,
                            itemBuilder: (context, index) {
                              final zikr = _azkar[index];
                              final isDefault = index < _defaultAzkar.length;

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
                                    zikr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isDefault)
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                          onPressed: () => _deleteZikr(index),
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
                                  onTap: () => Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) =>
                                          CounterScreen(zikr: zikr),
                                      transitionsBuilder: (_, a, __, c) =>
                                          FadeTransition(opacity: a, child: c),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddZikrDialog,
        backgroundColor: AppColors.secondaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        elevation: 6.r,
        splashColor: AppColors.secondaryColor,
        child: Icon(
          Icons.add_rounded,
          color: Theme.of(context).primaryColor,
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
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
