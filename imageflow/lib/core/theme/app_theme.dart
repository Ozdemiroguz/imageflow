import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

abstract class AppTheme {
  static ThemeData get dark {
    final textTheme = ThemeData(brightness: Brightness.dark).textTheme;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.burrowingOwl,
      brightness: Brightness.dark,
      primary: AppColors.burrowingOwl,
      secondary: AppColors.greatHornedOwl,
      tertiary: AppColors.tawnyOwl,
      surface: AppColors.bgSecondary,
      surfaceContainerLowest: AppColors.bgPrimary,
      surfaceContainerLow: AppColors.bgSecondary,
      surfaceContainer: AppColors.bgElevated,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      extensions: const [AppTokens()],
    );
  }

}
