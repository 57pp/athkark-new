import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/custom_app_bar.dart';
import '../domain/prayer_times_service_fixed.dart';
import '../domain/prayer_prefs.dart';
import 'utils/prayer_dialogs.dart';
import 'widgets/custom_prayers_section.dart';
import 'widgets/prayer_list_section.dart';
import 'widgets/prayer_ui_components.dart';

class PrayerTimesPage extends StatefulWidget {
  final VoidCallback? toggleTheme;

  const PrayerTimesPage({super.key, this.toggleTheme});

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  final PrayerTimesService _service = PrayerTimesService.instance;
  late final DateFormat _timeFormat;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();


  int _initializationAttempts = 0;
  static const int maxInitializationAttempts = 3;
  Timer? _loadingTimeoutTimer;
  bool _isLoadingTimeoutReached = false;

  @override
  void initState() {
    super.initState();
    _timeFormat = DateFormat.jm();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });

    // Set loading timeout (show error after 10 seconds)
    _loadingTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _service.state.value == null) {
        setState(() {
          _isLoadingTimeoutReached = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تستغرق عملية التحميل وقتاً أطول من المعتاد'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    });

    // Load custom prayers
    _service.loadCustomPrayers();
    
    // Initialize service with retry mechanism
    _initializeServiceWithRetry();
  }

  Future<void> _initializeServiceWithRetry() async {
    try {
      debugPrint('🔄 Initializing prayer times service (attempt ${_initializationAttempts + 1})');
      
      // Add a small delay to let the UI render first
      await Future.delayed(const Duration(milliseconds: 100));
      
      await _service.init(forceRefresh: true);
      
      debugPrint('✅ Prayer times service initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize service (attempt ${_initializationAttempts + 1}): $e');
      _initializationAttempts++;
      
      if (_initializationAttempts < maxInitializationAttempts) {
        // Retry with exponential backoff
        final delay = Duration(seconds: 2 * _initializationAttempts);
        debugPrint('🔄 Retrying in ${delay.inSeconds} seconds...');
        Timer(delay, () => _initializeServiceWithRetry());
      } else {
        debugPrint('❌ Failed to initialize service after $maxInitializationAttempts attempts');
        // Show user-friendly error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('فشل في تحميل مواقيت الصلاة. يرجى إعادة المحاولة أو التحقق من الاتصال.'),
              action: SnackBarAction(
                label: 'إعادة المحاولة',
                onPressed: () {
                  _initializationAttempts = 0;
                  _initializeServiceWithRetry();
                },
              ),
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: CustomAppBar(
        title: 'مواقيت الصلاة',
        showBackButton: false,
        useBottomNavBarStyle: true,
      ),
      body: ValueListenableBuilder<PrayerTimesState?>(
        valueListenable: _service.state,
        builder: (BuildContext context, PrayerTimesState? state, _) {
          // Cancel timeout timer once we have a state
          if (state != null) {
            _loadingTimeoutTimer?.cancel();
          }
          
          if (state == null) {
            if (_isLoadingTimeoutReached) {
              // Show retry UI after timeout
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'فشل في تحميل مواقيت الصلاة',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تحقق من الاتصال وإعدادات الموقع',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoadingTimeoutReached = false;
                        });
                        _initializationAttempts = 0;
                        _initializeServiceWithRetry();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            } else {
              // Show loading indicator
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جارٍ تحميل مواقيت الصلاة...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }
          }
          return RefreshIndicator(
            onRefresh: _service.refreshLocation,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: _buildHeroSection(state),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: PrayerListSection(
                      state: state,
                      service: _service,
                      timeFormat: _timeFormat,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: CustomPrayersSection(
                      service: _service,
                      timeFormat: _timeFormat,
                      onAddCustomPrayer: _showAddCustomPrayerDialog,
                      onDeleteCustomPrayer: _showDeleteCustomPrayerDialog,
                      onEditCustomPrayer: _showEditCustomPrayerDialog,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(PrayerTimesState state) {
    final theme = Theme.of(context);
    final nextPrayer = state.nextPrayer;
    DateTime? nextTime = nextPrayer != null ? state.times[nextPrayer]! : null;
    final sunrise = state.sunrise;

    final DateTime? targetNextTime = nextTime == null
        ? null
        : (nextTime.isAfter(_currentTime)
            ? nextTime
            : nextTime.add(const Duration(days: 1)));

    String _remaining() {
      debugPrint('⏰ Calculating remaining time...');
      
      if (targetNextTime == null) {
        debugPrint('⚠️ targetNextTime is null');
        return 'جارٍ التحديث';
      }
      
      final diff = targetNextTime.difference(_currentTime);
      debugPrint('⏱️ Time difference: $diff');
      
      // Handle case where prayer time has passed
      if (diff.isNegative) {
        debugPrint('⚠️ Prayer time has passed by ${diff.abs()}');
        // Check if it's very recent (within 5 minutes) - show "الآن" 
        if (diff.abs().inMinutes < 5) {
          debugPrint('✅ Showing "الآن" for recent prayer');
          return 'الآن';
        } 
        // If more than 5 minutes have passed, this shouldn't happen
        else {
          debugPrint('❌ Prayer time passed by more than 5 minutes - logic error');
          return 'جارٍ التحديث';
        }
      }
      
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      final s = diff.inSeconds.remainder(60);
      
      // Format the time difference
      String result;
      if (h > 0) {
        result = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      } else if (m > 0) {
        result = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      } else {
        result = '${s.toString().padLeft(2, '0')} ثانية';
      }
      
      debugPrint('✅ Final remaining time: $result');
      return result;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        gradient: PrayerUIComponents.buildHeroGradient(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: PrayerUIComponents.buildEnhancedShadows(context),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: PrayerUIComponents.buildLightInnerGradient(),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول - الوقت الحالي وزر التبديل
            _buildCurrentTimeRow(theme),
            const SizedBox(height: 12),
            
            // خط فاصل متدرج
            PrayerUIComponents.buildGradientDivider(),
            
            const SizedBox(height: 12),
            
            // الصف الثاني - الصلاة القادمة والمتبقي
            if (nextPrayer != null && targetNextTime != null)
              _buildNextPrayerSection(theme, nextPrayer, sunrise, _remaining(), state)
            else
              _buildLoadingNextPrayerState(theme),
          ],
        ),
      ),
    );
  }

  /// بناء صف الوقت الحالي (متصغر)
  Widget _buildCurrentTimeRow(ThemeData theme) {
    return Row(
      children: [
        PrayerUIComponents.buildIconContainer(
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, Colors.white.withOpacity(0.8)],
            ).createShader(bounds),
            child: const Icon(
              Icons.mosque,
              color: Colors.white,
              size: 24,
            ),
          ),
          size: 40,
          backgroundColor: Colors.white.withOpacity(0.2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الوقت الآن',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              PrayerUIComponents.buildTimeDisplay(
                context: context,
                time: DateFormat('hh:mm a').format(_currentTime),
                isHighlighted: true,
              ),
            ],
          ),
        ),
        PrayerUIComponents.buildThemeToggleButton(
          context: context,
          onPressed: widget.toggleTheme ?? () {},
          isDarkMode: theme.brightness == Brightness.dark,
        ),
      ],
    );
  }

  /// بناء قسم الصلاة القادمة مع الموقع (مدمج)
  Widget _buildNextPrayerSection(ThemeData theme, PrayerType nextPrayer, DateTime sunrise, String remainingTime, PrayerTimesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // صف الصلاة القادمة والوقت المتبقي
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الصلاة القادمة',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PrayerUIComponents.buildPrayerHighlightCard(
                    context: context,
                    prayerName: nextPrayer.displayName,
                  ),
                  const SizedBox(height: 6),
                  PrayerUIComponents.buildTimeInfoCard(
                    context: context,
                    timeText: remainingTime,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // بطاقة الشروق
            PrayerUIComponents.buildStatCard(
              context: context,
              icon: Icon(
                Icons.wb_sunny,
                size: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              label: 'الشروق',
              value: _timeFormat.format(sunrise),
              backgroundColor: Colors.white.withOpacity(0.18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // صف الموقع والوقت الحالي
        Row(
          children: [
            Expanded(
              child: _buildLocationAndTimeInfo(theme, state),
            ),
          ],
        ),
      ],
    );
  }

  /// بناء معلومات الموقع والوقت الحالي
  Widget _buildLocationAndTimeInfo(ThemeData theme, PrayerTimesState state) {
    final locationInfo = state.placeName ?? 'الموقع غير محدد';
    final currentTimeStr = DateFormat('hh:mm a').format(_currentTime);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 14,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationInfo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'الوقت الحالي: $currentTimeStr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة تحميل الصلاة القادمة
  Widget _buildLoadingNextPrayerState(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.schedule,
            size: 48,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'جارٍ حساب الصلاة القادمة',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يرجى تحديث الموقع للحصول على المواقيت',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _showAddCustomPrayerDialog() async {
    await PrayerDialogs.showAddCustomPrayerDialog(
        context, _service, _timeFormat);
  }

  Future<void> _refreshLocation() async {
    try {
      await PrayerUIComponents.showEnhancedSnackBar(
        context,
        message: 'جاري تحديث الموقع...',
        duration: 2,
      );
      
      await _service.refreshLocation();
      
      if (mounted) {
        await PrayerUIComponents.showEnhancedSnackBar(
          context,
          message: 'تم تحديث الموقع بنجاح',
          duration: 2,
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        await PrayerUIComponents.showEnhancedSnackBar(
          context,
          message: 'فشل في تحديث الموقع: $e',
          duration: 3,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _showDeleteCustomPrayerDialog(CustomPrayer prayer) async {
    await PrayerDialogs.showDeleteCustomPrayerDialog(context, prayer, _service);
  }

  Future<void> _showEditCustomPrayerDialog(CustomPrayer prayer) async {
    await PrayerDialogs.showEditCustomPrayerDialog(context, prayer, _service, _timeFormat);
  }

}
