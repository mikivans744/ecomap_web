import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme => _buildLightTheme(useGoogleFonts: true);

  @visibleForTesting
  static ThemeData get offlineTheme => _buildLightTheme(useGoogleFonts: false);

  static ThemeData _buildLightTheme({required bool useGoogleFonts}) {
    final fontFamily = useGoogleFonts ? GoogleFonts.poppins().fontFamily : null;
    final baseTextTheme = useGoogleFonts
        ? GoogleFonts.poppinsTextTheme()
        : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onPrimary: Colors.white,
        onSecondary: AppColors.textPrimary,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      textTheme: baseTextTheme
          .copyWith(
            displayLarge: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 57,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            displayMedium: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 45,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            displaySmall: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            headlineMedium: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            headlineSmall: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            titleLarge: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.75,
            ),
            titleMedium: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            bodyLarge: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
            bodyMedium: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
            bodySmall: _fontStyle(
              useGoogleFonts: useGoogleFonts,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          )
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
        labelType: NavigationRailLabelType.all,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: _fontStyle(
          useGoogleFonts: useGoogleFonts,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
        hintStyle: _fontStyle(
          useGoogleFonts: useGoogleFonts,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );
  }

  static TextStyle _fontStyle({
    required bool useGoogleFonts,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? color,
  }) {
    if (useGoogleFonts) {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}
