import 'package:flutter/material.dart';
import 'package:flutterkit/theme.dart';
import 'app_colors.dart';

ThemeData get netLaunchTheme {
  final base = lightTheme;

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.darkNavy,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      surface: AppColors.white,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.cardBorder,
      outlineVariant: AppColors.cardBorder,
      error: AppColors.statusFailed,
    ),
    scaffoldBackgroundColor: AppColors.lightGrayBg,
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: AppColors.white,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkNavy,
      foregroundColor: Colors.white,
    ),
  );
}
