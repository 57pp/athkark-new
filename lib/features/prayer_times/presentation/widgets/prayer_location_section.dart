import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/prayer_prefs.dart';
import '../../domain/prayer_times_service_fixed.dart';
import 'prayer_ui_components.dart';

class PrayerLocationSection extends StatefulWidget {
  final PrayerTimesState state;
  final PrayerTimesService service;
  final DateFormat timeFormat;

  const PrayerLocationSection({
    super.key,
    required this.state,
    required this.service,
    required this.timeFormat,
  });

  @override
  State<PrayerLocationSection> createState() => _PrayerLocationSectionState();
}

class _PrayerLocationSectionState extends State<PrayerLocationSection> {
  bool _isRefreshing = false;

  String _formatTime(DateTime time) => widget.timeFormat.format(time);

  Widget _buildLocationStatusNote(PrayerLocationStatus status) {
    String? message;
    IconData? icon;
    Color? color;

    switch (status) {
      case PrayerLocationStatus.permissionDenied:
        message = 'تم رفض إذن الموقع. لتحديث المواقيت بدقة، فعّل إذن الموقع من الإعدادات.';
        icon = Icons.location_off;
        color = Colors.red;
        break;
      case PrayerLocationStatus.serviceDisabled:
        message = 'خدمة الموقع معطلة. يرجى تفعيل GPS لتحديد الموقع بدقة.';
        icon = Icons.location_disabled;
        color = Colors.orange;
        break;
      case PrayerLocationStatus.ready:
        message = 'تم تحديد الموقع بنجاح. المواقيت دقيقة.';
        icon = Icons.location_on;
        color = Colors.green;
        break;
      case PrayerLocationStatus.loading:
        message = 'جارٍ تحديد الموقع...';
        icon = Icons.my_location;
        color = Colors.blue;
        break;
      case PrayerLocationStatus.idle:
        message = null;
        break;
    }

    if (message == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color!.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshLocation() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      await PrayerUIComponents.showEnhancedSnackBar(
        context,
        message: 'جارٍ تحديث الموقع...',
        duration: 2,
      );

      await widget.service.refreshLocation();

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
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastUpdatedLabel = _formatTime(widget.state.lastUpdated);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrayerUIComponents.buildSectionHeader(
          title: 'الموقع الحالي',
          icon: Icons.my_location,
          iconColor: theme.colorScheme.primary,
          onRefresh: widget.state.locationStatus == PrayerLocationStatus.ready ? _refreshLocation : null,
        ),
        PrayerUIComponents.buildEnhancedCard(
          context: context,
          backgroundColor: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات الموقع
              widget.state.placeName != null
                  ? _buildLocationInfo(theme)
                  : _buildCoordinatesInfo(theme),
              
              const SizedBox(height: 16),
              
              // معلومات إضافية
              _buildAdditionalInfo(theme, lastUpdatedLabel),
              
              const SizedBox(height: 12),
              
              // حالة الموقع
              _buildLocationStatusNote(widget.state.locationStatus),
              
              const SizedBox(height: 16),
              
              // زر تحديث الموقع
              _buildUpdateButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.location_on,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.state.placeName!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الموقع المحفوظ',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinatesInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gps_fixed,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الموقع الحالي',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الإحداثيات: ${widget.state.coordinates.latitude.toStringAsFixed(4)}, '
                    '${widget.state.coordinates.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'انقر "تحديث الموقع" لتحديد المدينة',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo(ThemeData theme, String lastUpdatedLabel) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildInfoChip(
          icon: Icons.wb_sunny,
          label: 'وقت الشروق ${_formatTime(widget.state.sunrise)}',
          color: theme.colorScheme.primary,
        ),
        _buildInfoChip(
          icon: Icons.update,
          label: 'آخر تحديث $lastUpdatedLabel',
          color: theme.colorScheme.secondary,
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isRefreshing ? null : _refreshLocation,
        icon: _isRefreshing 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location, size: 18),
        label: Text(
          _isRefreshing ? 'جارٍ التحديث...' : 'تحديث الموقع',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _isRefreshing ? 0 : 2,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
    );
  }
}