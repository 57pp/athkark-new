import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/../core/theme/colors.dart' show AppColors, AppTextStyles;

class ReusableSearchDelegate<T> extends SearchDelegate<T> {
  final String searchHint;
  final List<T> items;
  final String Function(T item) getDisplayText;
  final String Function(T item) getSearchText;
  final Widget Function(T item, BuildContext context) buildResultItem;
  final VoidCallback? onSearchCleared;

  ReusableSearchDelegate({
    required this.searchHint,
    required this.items,
    required this.getDisplayText,
    required this.getSearchText,
    required this.buildResultItem,
    this.onSearchCleared,
  });

  @override
  String get searchFieldLabel => searchHint;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: query.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                key: const ValueKey('clear'),
                icon: const Icon(Icons.clear),
                onPressed: () {
                  query = '';
                  onSearchCleared?.call();
                },
              ),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null as T),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredItems = _filterItems(query);
    return _buildSearchResults(context, filteredItems);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredItems = _filterItems(query);
    return _buildSearchResults(context, filteredItems);
  }

  List<T> _filterItems(String query) {
    if (query.isEmpty) return items;

    final normalizedQuery = query.trim().toLowerCase();
    return items.where((item) {
      final searchText = getSearchText(item).toLowerCase();
      return searchText.contains(normalizedQuery);
    }).toList();
  }

  Widget _buildSearchResults(BuildContext context, List<T> filteredItems) {
    if (filteredItems.isEmpty) {
      return _buildEmptyState(context);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundGradientDark
            : AppColors.backgroundGradientLight,
      ),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: filteredItems.length,
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: buildResultItem(item, context),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundGradientDark
            : AppColors.backgroundGradientLight,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            SizedBox(height: 16.h),
            Text(
              'لا توجد نتائج',
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 18.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'جرب كلمات بحث مختلفة',
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onPrimary.withOpacity(0.7),
        ),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}