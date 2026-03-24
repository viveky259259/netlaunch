import 'package:flutter/material.dart';
import 'package:flutterkit/theme.dart';
import 'app_colors.dart';

ThemeData get netLaunchTheme {
  final base = lightTheme;

  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.teal,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      surface: AppColors.cardSurface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.cardBorder,
      outlineVariant: AppColors.cardBorder,
      error: AppColors.statusFailed,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: AppColors.cardSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg.withValues(alpha: 0.85),
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.teal,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
      hintStyle: const TextStyle(color: AppColors.dimText),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cardSurface,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.cardBorder),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
