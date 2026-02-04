import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/category.dart';
import '../../core/theme/colors.dart' show AppColors, AppTextStyles;
import '../../screens/adhkar/category_screen.dart';

class AdhkarSearchDelegate extends SearchDelegate<Category?> {
  final Future<List<Category>> categoriesFuture;

  AdhkarSearchDelegate({required this.categoriesFuture});

  @override
  String get searchFieldLabel => 'البحث في الأذكار...';

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
                },
              ),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildSearchResults(context, _filterCategories(snapshot.data!, query));
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildSearchResults(context, _filterCategories(snapshot.data!, query));
      },
    );
  }

  List<Category> _filterCategories(List<Category> categories, String query) {
    if (query.isEmpty) return categories;

    final normalizedQuery = query.trim().toLowerCase();
    return categories.where((category) {
      final categoryName = category.category.toLowerCase();
      return categoryName.contains(normalizedQuery);
    }).toList();
  }

  Widget _buildSearchResults(BuildContext context, List<Category> filteredCategories) {
    if (filteredCategories.isEmpty) {
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
        itemCount: filteredCategories.length,
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: _buildCategoryCard(category, context),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(Category category, BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryColor,
          child: Text(
            '${category.id}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          category.category,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
          ),
        ),
        subtitle: Text(
          '${category.dhikrs.length} ذكر',
          style: TextStyle(
            fontSize: 14.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: AppColors.secondaryColor,
          size: 20.sp,
        ),
        onTap: () {
          // Navigate directly to category detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryScreen(category: category),
            ),
          ).then((_) => close(context, category));
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
