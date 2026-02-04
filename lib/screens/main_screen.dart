import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/navigation/deep_link.dart';
import '../core/theme/colors.dart' show AppColors;
import '../core/theme/theme.dart';
import '../features/prayer_times/presentation/prayer_times_page.dart';
import '../main.dart';
import '../models/category.dart';
import '../pages/mushaf_viewer_page.dart';
import '../features/quran/surah_list_page.dart';
import '../shared/utils/data_provider.dart';
import '../features/adhkar/adhkar_screen.dart';
import '../screens/adhkar/category_screen.dart';
import '../features/counter/zikr_list_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/utils/welcome_notification_service.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ValueNotifier<DeepLink?> deepLinkNotifier;

  const MainScreen({
    super.key,
    required this.toggleTheme,
    required this.deepLinkNotifier,
  });

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // ابدأ بصفحة القرآن
  final List<Widget> _screens = <Widget>[];
  late final VoidCallback _deepLinkListener;
  bool _handlingDeepLink = false;

  @override
  void initState() {
    super.initState();
    _screens.addAll(<Widget>[
      const SurahListPage(),
      AdhkarScreen(toggleTheme: widget.toggleTheme),
      PrayerTimesPage(toggleTheme: widget.toggleTheme),
      const ZikrListScreen(),
      SettingsScreen(toggleTheme: widget.toggleTheme),
    ]);
    _deepLinkListener = () {
      final DeepLink? link = widget.deepLinkNotifier.value;
      if (link != null) {
        handleDeepLink(link);
        widget.deepLinkNotifier.value = null;
      }
    };
    widget.deepLinkNotifier.addListener(_deepLinkListener);

    final DeepLink? pending = widget.deepLinkNotifier.value;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleDeepLink(pending);
      });
      widget.deepLinkNotifier.value = null;
    }

    // Show welcome notification after app is fully loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WelcomeNotificationService.instance.showWelcomeNotification();
    });
  }

  @override
  void dispose() {
    widget.deepLinkNotifier.removeListener(_deepLinkListener);
    super.dispose();
  }

  Future<void> handleDeepLink(DeepLink link) async {
    if (!mounted || _handlingDeepLink) {
      return;
    }
    _handlingDeepLink = true;
    try {
      switch (link.route) {
        case '/adhkar':
          await _openAdhkarByType(link['type']);
          break;
        case '/tasbih':
          if (_selectedIndex != 3) {
            setState(() => _selectedIndex = 3);
          }
          break;
        case '/quran':
          final int? page = int.tryParse(link['page'] ?? '');
          if (page != null) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MushafViewerPage(
                    surahName: '?????? ??????', startPage: page),
              ),
            );
          }
          break;
        default:
          break;
      }
    } finally {
      _handlingDeepLink = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80.h, // Same height as AppBar
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppColors.primaryGradientDark
            : AppColors.primaryGradientLight,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.onPrimary,
          unselectedItemColor:
              Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedFontSize: 12.sp,
          unselectedFontSize: 10.sp,
          items: <BottomNavigationBarItem>[
            _buildNavItem(Icons.menu_book_rounded, 'القرآن'),
            _buildNavItem(Icons.book, 'الأذكار'),
            _buildNavItem(Icons.mosque, 'مواقيت'),
            _buildNavItem(Icons.add, 'السبحة'),
            _buildNavItem(Icons.settings, 'الإعدادات'),
          ],
          onTap: (int index) => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Icon(icon, size: 28),
      ),
      label: label,
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Icon(
          icon,
          size: 28,
          color: AppColors.primaryColor,
        ),
      ),
    );
  }

  Future<void> _openAdhkarByType(String? type) async {
    if (_selectedIndex != 1) {
      setState(() => _selectedIndex = 1);
    }

    await Future.delayed(const Duration(milliseconds: 150));

    final int categoryId = _resolveCategoryId(type);
    final Category? category = await _loadCategory(categoryId);
    if (category == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryScreen(category: category),
      ),
    );
  }

  int _resolveCategoryId(String? type) {
    switch (type) {
      case 'post_prayer':
        return 27;
      case 'evening':
      case 'morning':
      default:
        return 1;
    }
  }

  Future<Category?> _loadCategory(int id) async {
    final DataProvider provider = DataProvider();
    final List<Category> categories = await provider.getCategories();
    for (final Category category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}
